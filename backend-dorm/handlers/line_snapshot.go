package handlers

import (
	"bytes"
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"net/http"
	"reflect"
	"strconv"
	"strings"
	"time"
)

type lineSyncEnvelope struct {
	SnapshotID  string                    `json:"snapshotID"`
	AccountID   int                       `json:"accountID"`
	Rooms       []lineRoomSnapshot        `json:"rooms"`
	Tenants     []lineTenantSnapshot      `json:"tenants"`
	Payments    []linePaymentSnapshot     `json:"payments"`
	Maintenance []lineMaintenanceSnapshot `json:"maintenance"`
	RoomTypes   []lineRoomTypeSnapshot    `json:"roomTypes"`
}

type lineRoomSnapshot struct {
	ID         string `json:"id"`
	RoomNumber string `json:"roomNumber"`
	RoomType   string `json:"roomType"`
}

type lineTenantSnapshot struct {
	ID                     string   `json:"id"`
	ServerID               *int     `json:"serverId"`
	Prefix                 string   `json:"prefix"`
	FirstName              string   `json:"firstName"`
	LastName               string   `json:"lastName"`
	RoomNumber             string   `json:"roomNumber"`
	Status                 string   `json:"status"`
	NationalID             string   `json:"nationalID"`
	Phone                  string   `json:"phone"`
	Address                string   `json:"address"`
	MoveInDate             string   `json:"moveInDate"`
	ContractEndDate        string   `json:"contractEndDate"`
	Deposit                float64  `json:"deposit"`
	BookingStatus          string   `json:"bookingStatus"`
	PaymentMethod          string   `json:"paymentMethod"`
	IndefiniteContract     int      `json:"indefiniteContract"`
	BookingSlips           []string `json:"bookingSlips"`
	AdditionalAppliances   string   `json:"additionalAppliances"`
	AdditionalApplianceFee float64  `json:"additionalApplianceFee"`
	AdditionalDetails      string   `json:"additionalDetails"`
}

type linePaymentSnapshot struct {
	ID               string   `json:"id"`
	UserID           int      `json:"userId"`
	RoomNumber       string   `json:"roomNumber"`
	RentFee          float64  `json:"rentFee"`
	DepositFee       float64  `json:"depositFee"`
	WaterFee         float64  `json:"waterFee"`
	ElectricFee      float64  `json:"electricFee"`
	CommonFee        float64  `json:"commonFee"`
	LateFee          float64  `json:"lateFee"`
	ApplianceFee     float64  `json:"applianceFee"`
	Amount           float64  `json:"amount"`
	Month            string   `json:"month"`
	PaymentDate      string   `json:"paymentDate"`
	Method           string   `json:"method"`
	SlipPath         string   `json:"slipPath"`
	PaymentPlan      string   `json:"paymentPlan"`
	InstallmentPhase int      `json:"installmentPhase"`
	DueDate          string   `json:"dueDate"`
	PaymentStatus    string   `json:"paymentStatus"`
	SlipPathArray    []string `json:"slipPathArray"`
	PaidAmount       float64  `json:"paidAmount"`
	LastUpdated      string   `json:"lastUpdated"`
}

type lineMaintenanceSnapshot struct {
	ID              string  `json:"id"`
	RoomNumber      string  `json:"roomNumber"`
	Issue           string  `json:"issue"`
	Status          string  `json:"status"`
	Cost            float64 `json:"cost"`
	ReportedAt      string  `json:"reportedAt"`
	ResolvedAt      string  `json:"resolvedAt"`
	PaymentMethod   string  `json:"paymentMethod"`
	SlipPath        string  `json:"slipPath"`
	IssueImage      string  `json:"issueImage"`
	QuoteApprovedAt string  `json:"quoteApprovedAt,omitempty"`
	LastUpdated     string  `json:"lastUpdated"`
}

type maintenanceStatusNotification struct {
	EventKey      string
	MaintenanceID string
	LineUserID    string
	RoomNumber    string
	Issue         string
	Status        string
	Cost          float64
	ReportedAt    string
	ResolvedAt    string
	PaymentMethod string
	LastUpdated   string
}

type maintenanceStatusNotifier func(notification maintenanceStatusNotification) error

type maintenanceStatusChange struct {
	EventKey      string
	MaintenanceID string
	RoomNumber    string
	Issue         string
	Status        string
	Cost          float64
	ReportedAt    string
	ResolvedAt    string
	PaymentMethod string
	LastUpdated   string
}

type lineRoomTypeSnapshot struct {
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	Price       float64 `json:"price"`
	WaterFee    float64 `json:"waterFee"`
	ElectricFee float64 `json:"electricFee"`
	CommonFee   float64 `json:"commonFee"`
	LateFee     float64 `json:"lateFee"`
}

func InitializeLineIntegration(db *sql.DB) {
	db.Exec(`CREATE TABLE IF NOT EXISTS line_links (
		line_user_id TEXT PRIMARY KEY,
		account_id INTEGER NOT NULL,
		tenant_id TEXT NOT NULL DEFAULT '',
		status TEXT NOT NULL DEFAULT 'linked',
		legacy_room TEXT NOT NULL DEFAULT '',
		linked_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
		updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
	)`)
	db.Exec(`CREATE UNIQUE INDEX IF NOT EXISTS idx_line_links_tenant
		ON line_links(account_id, tenant_id) WHERE status = 'linked' AND tenant_id != ''`)
	db.Exec(`CREATE INDEX IF NOT EXISTS idx_line_links_account ON line_links(account_id, status)`)
	db.Exec(`CREATE TABLE IF NOT EXISTS line_delivery_logs (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		account_id INTEGER NOT NULL,
		tenant_id TEXT NOT NULL,
		payment_id TEXT NOT NULL,
		status TEXT NOT NULL,
		detail TEXT NOT NULL DEFAULT '',
		created_at TEXT NOT NULL
	)`)
	db.Exec(`CREATE TABLE IF NOT EXISTS line_notification_outbox (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		event_key TEXT NOT NULL UNIQUE,
		account_id INTEGER NOT NULL,
		line_user_id TEXT NOT NULL,
		room_number TEXT NOT NULL,
		issue TEXT NOT NULL,
		maintenance_status TEXT NOT NULL,
		status TEXT NOT NULL DEFAULT 'pending',
		attempts INTEGER NOT NULL DEFAULT 0,
		next_attempt_at TEXT NOT NULL,
		last_error TEXT NOT NULL DEFAULT '',
		created_at TEXT NOT NULL,
		sent_at TEXT NOT NULL DEFAULT ''
	)`)
	// Keep event timestamps and financial context in the outbox so a delayed
	// retry renders the original maintenance event, not the worker retry time.
	db.Exec(`ALTER TABLE line_notification_outbox ADD COLUMN cost REAL NOT NULL DEFAULT 0`)
	db.Exec(`ALTER TABLE line_notification_outbox ADD COLUMN reported_at TEXT NOT NULL DEFAULT ''`)
	db.Exec(`ALTER TABLE line_notification_outbox ADD COLUMN resolved_at TEXT NOT NULL DEFAULT ''`)
	db.Exec(`ALTER TABLE line_notification_outbox ADD COLUMN payment_method TEXT NOT NULL DEFAULT ''`)
	db.Exec(`ALTER TABLE line_notification_outbox ADD COLUMN maintenance_updated_at TEXT NOT NULL DEFAULT ''`)
	db.Exec(`ALTER TABLE line_notification_outbox ADD COLUMN maintenance_record_id TEXT NOT NULL DEFAULT ''`)
	db.Exec(`CREATE INDEX IF NOT EXISTS idx_line_notification_outbox_pending
		ON line_notification_outbox(status, next_attempt_at)`)
	// A process may stop after claiming a row but before sending it. Recover the
	// row at startup so the notification is not permanently stranded.
	db.Exec(`UPDATE line_notification_outbox SET status = 'pending' WHERE status = 'processing'`)
}

func ensureLineTenantSchema(db *sql.DB) {
	InitializeTenantDatabase(db)
	db.Exec(`ALTER TABLE users ADD COLUMN external_id TEXT DEFAULT ''`)
	db.Exec(`ALTER TABLE payments ADD COLUMN external_id TEXT DEFAULT ''`)
	db.Exec(`ALTER TABLE payments ADD COLUMN deposit_fee REAL DEFAULT 0`)
	db.Exec(`ALTER TABLE maintenances ADD COLUMN external_id TEXT DEFAULT ''`)
	db.Exec(`ALTER TABLE maintenances ADD COLUMN last_updated TEXT DEFAULT ''`)
	db.Exec(`ALTER TABLE maintenances ADD COLUMN quote_approved_at TEXT DEFAULT ''`)
	db.Exec(`ALTER TABLE rooms ADD COLUMN external_id TEXT DEFAULT ''`)
	db.Exec(`ALTER TABLE room_types ADD COLUMN external_id TEXT DEFAULT ''`)
	db.Exec(`CREATE UNIQUE INDEX IF NOT EXISTS idx_users_external_id ON users(external_id) WHERE external_id != ''`)
	db.Exec(`CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_external_id ON payments(external_id) WHERE external_id != ''`)
	db.Exec(`CREATE UNIQUE INDEX IF NOT EXISTS idx_maintenance_external_id ON maintenances(external_id) WHERE external_id != ''`)
}

func MaterializeLatestLineSnapshots(master *sql.DB) error {
	rows, err := master.Query(`SELECT DISTINCT account_id FROM sync_snapshots`)
	if err != nil {
		return err
	}
	defer rows.Close()

	var accountIDs []int
	for rows.Next() {
		var accountID int
		if err := rows.Scan(&accountID); err != nil {
			return err
		}
		accountIDs = append(accountIDs, accountID)
	}
	for _, accountID := range accountIDs {
		var payload string
		if err := master.QueryRow(`SELECT payload FROM sync_snapshots WHERE account_id = ? ORDER BY version DESC LIMIT 1`, accountID).Scan(&payload); err != nil {
			return err
		}
		if err := MaterializeLineSnapshot(master, accountID, []byte(payload)); err != nil {
			return fmt.Errorf("materialize LINE account %d: %w", accountID, err)
		}
	}
	return nil
}

func MaterializeLineSnapshot(master *sql.DB, accountID int, payload []byte) error {
	return materializeLineSnapshotPayload(master, accountID, payload, nil)
}

// MaterializeLineSnapshotAndNotify is used only for a newly accepted app push.
// Startup reconciliation uses MaterializeLineSnapshot so it cannot resend old
// LINE notifications after every server restart.
func MaterializeLineSnapshotAndNotify(master *sql.DB, accountID int, payload []byte) error {
	err := materializeLineSnapshotPayload(master, accountID, payload, func(notification maintenanceStatusNotification) error {
		return EnqueueMaintenanceStatusNotification(master, accountID, notification)
	})
	if err == nil {
		go ProcessPendingLineNotifications(master)
	}
	return err
}

// validateLineSnapshotForPush applies the workflow checks that can be decided
// without mutating tenant data. It must run before sync_snapshots INSERT so an
// invalid stale app state cannot become the latest immutable snapshot.
func validateLineSnapshotForPush(accountID int, payload []byte) error {
	var snapshot lineSyncEnvelope
	if err := json.Unmarshal(payload, &snapshot); err != nil {
		return err
	}
	if snapshot.SnapshotID == "" {
		return nil
	}
	if snapshot.AccountID != accountID {
		return errors.New("snapshot account mismatch")
	}
	snapshot.Maintenance = normalizeMaintenanceSnapshots(snapshot.Maintenance)
	tenantDB, err := GetTenantDB(accountID)
	if err != nil {
		return err
	}
	return validateMaintenanceSnapshotAgainstTenant(tenantDB, snapshot.Maintenance)
}

func validateMaintenanceSnapshotAgainstTenant(tenantDB *sql.DB, maintenanceItems []lineMaintenanceSnapshot) error {
	for _, maintenance := range maintenanceItems {
		maintenanceID := strings.TrimSpace(maintenance.ID)
		if maintenanceID == "" {
			continue
		}
		var previousStatus, quoteApprovedAt string
		var previousCost float64
		err := tenantDB.QueryRow(`SELECT COALESCE(status, ''), COALESCE(cost, 0), COALESCE(quote_approved_at, '')
			FROM maintenances WHERE external_id = ?`, maintenanceID).Scan(&previousStatus, &previousCost, &quoteApprovedAt)
		if errors.Is(err, sql.ErrNoRows) {
			continue
		}
		if err != nil {
			return fmt.Errorf("read previous maintenance status: %w", err)
		}
		if err := validateMaintenanceCostChange(previousStatus, maintenance.Status, previousCost, maintenance.Cost, quoteApprovedAt != ""); err != nil {
			return fmt.Errorf("maintenance %s cost change: %w", maintenanceID, err)
		}
		if strings.TrimSpace(previousStatus) == strings.TrimSpace(maintenance.Status) {
			continue
		}
		if err := validateMaintenanceAppTransition(previousStatus, maintenance.Status, maintenance.Cost, quoteApprovedAt != ""); err != nil {
			return fmt.Errorf("maintenance %s transition: %w", maintenanceID, err)
		}
		if maintenance.Status == "รออนุมัติค่าใช้จ่าย" {
			var linkedResidents int
			if err := tenantDB.QueryRow(`SELECT COUNT(*) FROM users WHERE room_number = ?
				AND line_user_id != '' AND status IN ('กำลังพักอาศัย','จอง')`, maintenance.RoomNumber).Scan(&linkedResidents); err != nil {
				return fmt.Errorf("check maintenance quote recipient: %w", err)
			}
			if linkedResidents == 0 {
				return errors.New("maintenance quote requires a linked LINE resident")
			}
		}
	}
	return nil
}

func materializeLineSnapshotPayload(master *sql.DB, accountID int, payload []byte, notifier maintenanceStatusNotifier) error {
	var snapshot lineSyncEnvelope
	if err := json.Unmarshal(payload, &snapshot); err != nil {
		return err
	}
	snapshot.Maintenance = normalizeMaintenanceSnapshots(snapshot.Maintenance)
	if snapshot.SnapshotID == "" {
		return nil
	}
	if snapshot.AccountID != accountID {
		return errors.New("snapshot account mismatch")
	}
	tenantDB, err := GetTenantDB(accountID)
	if err != nil {
		return err
	}
	return materializeLineSnapshotIntoWithNotifier(master, tenantDB, accountID, snapshot, notifier)
}

func materializeLineSnapshotInto(master, tenantDB *sql.DB, accountID int, snapshot lineSyncEnvelope) error {
	return materializeLineSnapshotIntoWithNotifier(master, tenantDB, accountID, snapshot, nil)
}

func materializeLineSnapshotIntoWithNotifier(master, tenantDB *sql.DB, accountID int, snapshot lineSyncEnvelope, notifier maintenanceStatusNotifier) error {
	ensureLineTenantSchema(tenantDB)
	snapshot.Maintenance = normalizeMaintenanceSnapshots(snapshot.Maintenance)
	tx, err := tenantDB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	activeTenantIDs := make(map[string]bool, len(snapshot.Tenants))
	for _, tenant := range snapshot.Tenants {
		if strings.TrimSpace(tenant.ID) == "" {
			continue
		}
		userID := stableSnapshotUserID(tenant)
		fullName := strings.TrimSpace(tenant.Prefix + tenant.FirstName + " " + tenant.LastName)
		bookingSlips, _ := json.Marshal(tenant.BookingSlips)
		_, err = tx.Exec(`INSERT INTO users
			(user_id, prefix, first_name, last_name, full_name, room_number, status, national_id, phone, address,
			 move_in_date, contract_end_date, deposit, booking_status, payment_method, indefinite_contract,
			 booking_slips, additional_appliances, additional_appliance_fee, additional_details, external_id)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
			ON CONFLICT(user_id) DO UPDATE SET
			 prefix=excluded.prefix, first_name=excluded.first_name, last_name=excluded.last_name,
			 full_name=excluded.full_name, room_number=excluded.room_number, status=excluded.status,
			 national_id=excluded.national_id, phone=excluded.phone, address=excluded.address,
			 move_in_date=excluded.move_in_date, contract_end_date=excluded.contract_end_date,
			 deposit=excluded.deposit, booking_status=excluded.booking_status, payment_method=excluded.payment_method,
			 indefinite_contract=excluded.indefinite_contract, booking_slips=excluded.booking_slips,
			 additional_appliances=excluded.additional_appliances,
			 additional_appliance_fee=excluded.additional_appliance_fee,
			 additional_details=excluded.additional_details, external_id=excluded.external_id`,
			userID, tenant.Prefix, tenant.FirstName, tenant.LastName, fullName, tenant.RoomNumber, tenant.Status,
			tenant.NationalID, tenant.Phone, tenant.Address, tenant.MoveInDate, tenant.ContractEndDate,
			tenant.Deposit, tenant.BookingStatus, tenant.PaymentMethod, tenant.IndefiniteContract,
			string(bookingSlips), tenant.AdditionalAppliances, tenant.AdditionalApplianceFee,
			tenant.AdditionalDetails, tenant.ID)
		if err != nil {
			return fmt.Errorf("upsert tenant: %w", err)
		}
		activeTenantIDs[tenant.ID] = true
	}

	rows, err := tx.Query(`SELECT external_id FROM users WHERE external_id != ''`)
	if err != nil {
		return err
	}
	var staleTenantIDs []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			return err
		}
		if !activeTenantIDs[id] {
			staleTenantIDs = append(staleTenantIDs, id)
		}
	}
	rows.Close()
	for _, id := range staleTenantIDs {
		if _, err := tx.Exec(`UPDATE users SET status = 'ย้ายออกแล้ว', line_user_id = '', bot_state = 'none' WHERE external_id = ?`, id); err != nil {
			return err
		}
	}

	activeRoomIDs := make(map[string]bool, len(snapshot.Rooms))
	for _, room := range snapshot.Rooms {
		if strings.TrimSpace(room.ID) != "" {
			activeRoomIDs[room.ID] = true
		}
		_, err = tx.Exec(`INSERT INTO rooms(room_number, room_type, external_id) VALUES (?, ?, ?)
			ON CONFLICT(room_number) DO UPDATE SET room_type=excluded.room_type, external_id=excluded.external_id`,
			room.RoomNumber, room.RoomType, room.ID)
		if err != nil {
			return fmt.Errorf("upsert room: %w", err)
		}
	}
	activeRoomTypeIDs := make(map[string]bool, len(snapshot.RoomTypes))
	for _, roomType := range snapshot.RoomTypes {
		if strings.TrimSpace(roomType.ID) != "" {
			activeRoomTypeIDs[roomType.ID] = true
		}
		_, err = tx.Exec(`INSERT INTO room_types(name, price, water_fee_default, electric_fee_default, common_fee_default, late_fee_default, external_id)
			VALUES (?, ?, ?, ?, ?, ?, ?)
			ON CONFLICT(name) DO UPDATE SET price=excluded.price, water_fee_default=excluded.water_fee_default,
			 electric_fee_default=excluded.electric_fee_default, common_fee_default=excluded.common_fee_default,
			 late_fee_default=excluded.late_fee_default, external_id=excluded.external_id`,
			roomType.Name, roomType.Price, roomType.WaterFee, roomType.ElectricFee, roomType.CommonFee, roomType.LateFee, roomType.ID)
		if err != nil {
			return fmt.Errorf("upsert room type: %w", err)
		}
	}
	activePaymentIDs := make(map[string]bool, len(snapshot.Payments))
	for _, payment := range snapshot.Payments {
		if strings.TrimSpace(payment.ID) != "" {
			activePaymentIDs[payment.ID] = true
		}
		slips, _ := json.Marshal(payment.SlipPathArray)
		_, err = tx.Exec(`INSERT INTO payments
			(user_id, room_number, rent_fee, deposit_fee, water_fee, electric_fee, common_fee, late_fee,
			 appliance_fee, amount, month, payment_date, method, slip_path, payment_plan, installment_phase,
			 due_date, payment_status, slip_path_array, paid_amount, last_updated, external_id)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
			ON CONFLICT(external_id) WHERE external_id != '' DO UPDATE SET user_id=excluded.user_id, room_number=excluded.room_number,
			 rent_fee=excluded.rent_fee, deposit_fee=excluded.deposit_fee, water_fee=excluded.water_fee,
			 electric_fee=excluded.electric_fee, common_fee=excluded.common_fee, late_fee=excluded.late_fee,
			 appliance_fee=excluded.appliance_fee, amount=excluded.amount, month=excluded.month,
			 payment_date=excluded.payment_date, method=excluded.method, slip_path=excluded.slip_path,
			 payment_plan=excluded.payment_plan, installment_phase=excluded.installment_phase,
			 due_date=excluded.due_date, payment_status=excluded.payment_status,
			 slip_path_array=excluded.slip_path_array, paid_amount=excluded.paid_amount,
			 last_updated=excluded.last_updated
			WHERE excluded.last_updated > payments.last_updated`,
			payment.UserID, payment.RoomNumber, payment.RentFee, payment.DepositFee, payment.WaterFee,
			payment.ElectricFee, payment.CommonFee, payment.LateFee, payment.ApplianceFee, payment.Amount,
			payment.Month, payment.PaymentDate, payment.Method, payment.SlipPath, payment.PaymentPlan,
			payment.InstallmentPhase, payment.DueDate, payment.PaymentStatus, string(slips), payment.PaidAmount,
			payment.LastUpdated, payment.ID)
		if err != nil {
			return fmt.Errorf("upsert payment: %w", err)
		}
	}
	statusChanges := make([]maintenanceStatusChange, 0)
	activeMaintenanceIDs := make(map[string]bool, len(snapshot.Maintenance))
	for _, maintenance := range snapshot.Maintenance {
		if strings.TrimSpace(maintenance.ID) != "" {
			activeMaintenanceIDs[maintenance.ID] = true
		}
		var previousStatus, quoteApprovedAt string
		var previousCost float64
		hadExistingMaintenance := false
		if strings.TrimSpace(maintenance.ID) != "" {
			err = tx.QueryRow(`SELECT COALESCE(status, ''), COALESCE(cost, 0), COALESCE(quote_approved_at, '')
				FROM maintenances WHERE external_id = ?`, maintenance.ID).Scan(&previousStatus, &previousCost, &quoteApprovedAt)
			switch {
			case err == nil:
				hadExistingMaintenance = true
			case errors.Is(err, sql.ErrNoRows):
				err = nil
			default:
				return fmt.Errorf("read previous maintenance status: %w", err)
			}
		}
		if hadExistingMaintenance {
			if err := validateMaintenanceCostChange(previousStatus, maintenance.Status, previousCost, maintenance.Cost, quoteApprovedAt != ""); err != nil {
				return fmt.Errorf("maintenance %s cost change: %w", maintenance.ID, err)
			}
		}
		if hadExistingMaintenance && strings.TrimSpace(previousStatus) != strings.TrimSpace(maintenance.Status) {
			if err := validateMaintenanceAppTransition(previousStatus, maintenance.Status, maintenance.Cost, quoteApprovedAt != ""); err != nil {
				return fmt.Errorf("maintenance %s transition: %w", maintenance.ID, err)
			}
			if maintenance.Status == "รออนุมัติค่าใช้จ่าย" {
				var linkedResidents int
				if err := tx.QueryRow(`SELECT COUNT(*) FROM users WHERE room_number = ?
					AND line_user_id != '' AND status IN ('กำลังพักอาศัย','จอง')`, maintenance.RoomNumber).Scan(&linkedResidents); err != nil {
					return fmt.Errorf("check maintenance quote recipient: %w", err)
				}
				if linkedResidents == 0 {
					return fmt.Errorf("maintenance quote requires a linked LINE resident")
				}
			}
		}
		_, err = tx.Exec(`INSERT INTO maintenances
			(room_number, issue, status, cost, reported_at, resolved_at, payment_method, slip_path, issue_image, last_updated, external_id)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
			ON CONFLICT(external_id) WHERE external_id != '' DO UPDATE SET room_number=excluded.room_number, issue=excluded.issue,
			 status=excluded.status, cost=excluded.cost, reported_at=excluded.reported_at,
			 resolved_at=excluded.resolved_at, payment_method=excluded.payment_method,
			 slip_path=excluded.slip_path, issue_image=excluded.issue_image, last_updated=excluded.last_updated
			WHERE excluded.last_updated > maintenances.last_updated`,
			maintenance.RoomNumber, maintenance.Issue, maintenance.Status, maintenance.Cost,
			maintenance.ReportedAt, maintenance.ResolvedAt, maintenance.PaymentMethod,
			maintenance.SlipPath, maintenance.IssueImage, maintenance.LastUpdated, maintenance.ID)
		if err != nil {
			return fmt.Errorf("upsert maintenance: %w", err)
		}
		if hadExistingMaintenance && maintenance.Status == "รออนุมัติค่าใช้จ่าย" && previousStatus != maintenance.Status {
			if _, err := tx.Exec(`UPDATE maintenances SET quote_approved_at = '' WHERE external_id = ?`, maintenance.ID); err != nil {
				return fmt.Errorf("reset maintenance quote approval: %w", err)
			}
		}
		if hadExistingMaintenance && strings.TrimSpace(previousStatus) != strings.TrimSpace(maintenance.Status) {
			var maintenanceRecordID int64
			if err := tx.QueryRow(`SELECT id FROM maintenances WHERE external_id = ?`, maintenance.ID).Scan(&maintenanceRecordID); err != nil {
				return fmt.Errorf("read maintenance record id: %w", err)
			}
			statusChanges = append(statusChanges, maintenanceStatusChange{
				EventKey:      fmt.Sprintf("maintenance:%d:%s:%s:%s", accountID, maintenance.ID, maintenance.LastUpdated, maintenance.Status),
				MaintenanceID: strconv.FormatInt(maintenanceRecordID, 10),
				RoomNumber:    maintenance.RoomNumber,
				Issue:         maintenance.Issue,
				Status:        maintenance.Status,
				Cost:          maintenance.Cost,
				ReportedAt:    maintenance.ReportedAt,
				ResolvedAt:    maintenance.ResolvedAt,
				PaymentMethod: maintenance.PaymentMethod,
				LastUpdated:   maintenance.LastUpdated,
			})
		}
	}

	if err := deleteStaleRecords(tx, "rooms", activeRoomIDs); err != nil {
		return err
	}
	if err := deleteStaleRecords(tx, "room_types", activeRoomTypeIDs); err != nil {
		return err
	}
	if err := deleteStaleRecords(tx, "payments", activePaymentIDs); err != nil {
		return err
	}
	if err := deleteStaleRecords(tx, "maintenances", activeMaintenanceIDs); err != nil {
		return err
	}

	if _, err := tx.Exec(`UPDATE users SET line_user_id = '' WHERE external_id != ''`); err != nil {
		return err
	}
	links, err := master.Query(`SELECT line_user_id, tenant_id FROM line_links WHERE account_id = ? AND status = 'linked'`, accountID)
	if err != nil {
		return err
	}
	defer links.Close()
	for links.Next() {
		var lineUserID, tenantID string
		if err := links.Scan(&lineUserID, &tenantID); err != nil {
			return err
		}
		if _, err := tx.Exec(`UPDATE users SET line_user_id = ? WHERE external_id = ?`, lineUserID, tenantID); err != nil {
			return err
		}
	}
	if err := tx.Commit(); err != nil {
		return err
	}
	if notifier == nil {
		return nil
	}
	for _, change := range statusChanges {
		var lineUserID string
		err := tenantDB.QueryRow(`SELECT COALESCE(line_user_id, '') FROM users
			WHERE room_number = ? AND line_user_id != ''
				AND status IN ('กำลังพักอาศัย', 'จอง')
			ORDER BY CASE status WHEN 'กำลังพักอาศัย' THEN 0 ELSE 1 END
			LIMIT 1`, change.RoomNumber).Scan(&lineUserID)
		if err == nil && lineUserID != "" {
			if err := notifier(maintenanceStatusNotification{
				EventKey: change.EventKey, MaintenanceID: change.MaintenanceID,
				LineUserID: lineUserID, RoomNumber: change.RoomNumber,
				Issue: change.Issue, Status: change.Status, Cost: change.Cost,
				ReportedAt: change.ReportedAt, ResolvedAt: change.ResolvedAt,
				PaymentMethod: change.PaymentMethod, LastUpdated: change.LastUpdated,
			}); err != nil {
				return fmt.Errorf("queue maintenance status notification: %w", err)
			}
		} else if err != nil && !errors.Is(err, sql.ErrNoRows) {
			return fmt.Errorf("resolve LINE recipient for maintenance status: %w", err)
		}
	}
	return nil
}

func validateMaintenanceCostChange(previousStatus, nextStatus string, previousCost, nextCost float64, quoteApproved bool) error {
	if math.Abs(previousCost-nextCost) < 0.005 {
		return nil
	}
	if quoteApproved && previousStatus == "กำลังติดต่อช่าง" {
		if nextStatus == "รออนุมัติค่าใช้จ่าย" {
			return nil
		}
		return fmt.Errorf("approved quote cost is locked; issue a replacement quote")
	}
	quoteIndex := 2
	previousIndex := maintenanceStatusIndex(previousStatus)
	nextIndex := maintenanceStatusIndex(nextStatus)
	if previousIndex < quoteIndex {
		return nil
	}
	// A changed amount is safe only while returning to pre-quote work or while
	// explicitly issuing a replacement quote. It must never mutate an amount
	// already shown in LINE while the approved workflow continues.
	if nextIndex < quoteIndex || (nextIndex == quoteIndex && previousIndex != quoteIndex) {
		return nil
	}
	return fmt.Errorf("approved or pending quote cost is locked; issue a replacement quote")
}

func maintenanceStatusIndex(value string) int {
	// ลำดับใหม่: ชำระเงินก่อนซ่อม
	statuses := []string{"รอดำเนินการ", "กำลังติดต่อช่าง", "รออนุมัติค่าใช้จ่าย", "รอตรวจสอบชำระเงิน", "กำลังซ่อม", "เสร็จสิ้น"}
	for index, status := range statuses {
		if strings.TrimSpace(value) == status {
			return index
		}
	}
	return -1
}

// validateMaintenanceAppTransition enforces the new pay-before-repair workflow:
//
//	รอดำเนินการ → กำลังติดต่อช่าง → รออนุมัติค่าใช้จ่าย → รอตรวจสอบชำระเงิน → กำลังซ่อม → เสร็จสิ้น
//
// For cost=0 jobs, payment step is skipped:
//
//	ติดต่อช่าง → กำลังซ่อม → เสร็จสิ้น
func validateMaintenanceAppTransition(previousStatus, nextStatus string, cost float64, quoteApproved bool) error {
	previousStatus = strings.TrimSpace(previousStatus)
	nextStatus = strings.TrimSpace(nextStatus)
	const rejectedStatus = "ปฏิเสธค่าใช้จ่าย"
	if previousStatus == nextStatus {
		return nil
	}
	// Quote rejection is a terminal branch. Accept both safe predecessors.
	if nextStatus == rejectedStatus {
		if previousStatus == "กำลังติดต่อช่าง" || previousStatus == "รออนุมัติค่าใช้จ่าย" {
			return nil
		}
		return fmt.Errorf("quote can only be rejected while contacting or awaiting approval")
	}
	if previousStatus == rejectedStatus {
		return fmt.Errorf("rejected quote is terminal; issue a replacement quote")
	}

	// --- กฎ flow ใหม่: ชำระก่อนซ่อม ---

	// ติดต่อช่าง → รออนุมัติค่าใช้จ่าย: ต้องมีค่าใช้จ่าย
	if previousStatus == "กำลังติดต่อช่าง" && nextStatus == "รออนุมัติค่าใช้จ่าย" {
		if cost <= 0 {
			return fmt.Errorf("quote cost must be greater than zero")
		}
		return nil
	}
	// ติดต่อช่าง → กำลังซ่อม: อนุญาตเฉพาะเมื่อไม่มีค่าใช้จ่าย
	if previousStatus == "กำลังติดต่อช่าง" && nextStatus == "กำลังซ่อม" {
		if cost <= 0 {
			return nil
		}
		return fmt.Errorf("chargeable repairs must go through quote approval and payment before repair")
	}
	// รออนุมัติค่าใช้จ่าย → กำลังติดต่อช่าง: ถอยกลับได้
	if previousStatus == "รออนุมัติค่าใช้จ่าย" && nextStatus == "กำลังติดต่อช่าง" {
		return nil
	}
	// รออนุมัติค่าใช้จ่าย → กำลังซ่อม: ไม่อนุญาต ต้องผ่านชำระก่อน
	if previousStatus == "รออนุมัติค่าใช้จ่าย" && nextStatus == "กำลังซ่อม" {
		return fmt.Errorf("payment must be verified before starting repair")
	}
	// รอตรวจสอบชำระเงิน → กำลังซ่อม: admin ยืนยันรับเงินแล้ว เริ่มซ่อมได้
	if previousStatus == "รอตรวจสอบชำระเงิน" && nextStatus == "กำลังซ่อม" {
		return nil
	}
	// กำลังซ่อม → เสร็จสิ้น: ซ่อมเสร็จ ชำระเงินเรียบร้อยแล้วก่อนหน้า
	if previousStatus == "กำลังซ่อม" && nextStatus == "เสร็จสิ้น" {
		return nil
	}

	// กฎทั่วไป: ห้ามกระโดดข้ามขั้น
	previousIndex := maintenanceStatusIndex(previousStatus)
	nextIndex := maintenanceStatusIndex(nextStatus)
	if previousIndex < 0 || nextIndex < 0 {
		return fmt.Errorf("unknown status")
	}
	if nextIndex-previousIndex > 1 || previousIndex-nextIndex > 1 {
		return fmt.Errorf("status must move one step at a time")
	}
	return nil
}

// ReconcileLineTenantChanges publishes operational changes made through LINE
// before the latest app snapshot is materialized. This prevents a restart from
// replacing a newly uploaded slip or maintenance request with an older snapshot.
func ReconcileLineTenantChanges(master *sql.DB) error {
	rows, err := master.Query(`SELECT DISTINCT account_id FROM sync_snapshots ORDER BY account_id`)
	if err != nil {
		return err
	}
	defer rows.Close()
	var accountIDs []int
	for rows.Next() {
		var accountID int
		if err := rows.Scan(&accountID); err != nil {
			return err
		}
		accountIDs = append(accountIDs, accountID)
	}
	for _, accountID := range accountIDs {
		tenantDB, err := GetTenantDB(accountID)
		if err != nil {
			return err
		}
		if err := PublishLineTenantChanges(master, tenantDB, accountID); err != nil && err != sql.ErrNoRows {
			return fmt.Errorf("publish LINE changes for account %d: %w", accountID, err)
		}
	}
	return nil
}

// PublishLineTenantChanges creates a new immutable sync snapshot containing
// payment and maintenance changes accepted by the LINE webhook. The conditional
// INSERT uses the same optimistic version rule as an app push, so a concurrent
// device write cannot be overwritten.
func PublishLineTenantChanges(master, tenantDB *sql.DB, accountID int) error {
	if accountID <= 0 {
		return errors.New("invalid account id")
	}
	ensureLineTenantSchema(tenantDB)
	if err := ensureMaintenanceExternalIDs(tenantDB); err != nil {
		return err
	}

	for attempt := 0; attempt < 5; attempt++ {
		var baseVersion int
		var rawPayload string
		err := master.QueryRow(`SELECT version, payload FROM sync_snapshots
			WHERE account_id = ? ORDER BY version DESC LIMIT 1`, accountID).Scan(&baseVersion, &rawPayload)
		if err != nil {
			return err
		}
		var payload map[string]interface{}
		if err := json.Unmarshal([]byte(rawPayload), &payload); err != nil {
			return fmt.Errorf("decode latest snapshot: %w", err)
		}
		changed, err := mergeTenantOperationalState(tenantDB, payload)
		if err != nil {
			return err
		}
		if !changed {
			return nil
		}

		nextVersion := baseVersion + 1
		now := time.Now().UTC()
		payload["snapshotID"] = "line-" + newLineSnapshotUUID()
		payload["accountID"] = accountID
		payload["version"] = nextVersion
		payload["createdAt"] = now.Format(time.RFC3339Nano)
		payload["deviceID"] = "line-bot"
		encoded, err := json.Marshal(payload)
		if err != nil {
			return err
		}
		sum := sha256.Sum256(encoded)
		checksum := hex.EncodeToString(sum[:])
		snapshotID, _ := payload["snapshotID"].(string)
		result, err := master.Exec(`INSERT INTO sync_snapshots
			(snapshot_id, account_id, version, payload, checksum, size, device_id, created_at, created_by_admin_id)
			SELECT ?, ?, ?, ?, ?, ?, 'line-bot', ?, ?
			WHERE (SELECT COALESCE(MAX(version), 0) FROM sync_snapshots WHERE account_id = ?) = ?`,
			snapshotID, accountID, nextVersion, string(encoded), checksum, len(encoded),
			now.Format(time.RFC3339), accountID, accountID, baseVersion)
		if err != nil {
			return err
		}
		affected, err := result.RowsAffected()
		if err != nil {
			return err
		}
		if affected == 1 {
			return nil
		}
	}
	return errors.New("snapshot changed repeatedly while publishing LINE data")
}

func ensureMaintenanceExternalIDs(db *sql.DB) error {
	rows, err := db.Query(`SELECT id FROM maintenances WHERE COALESCE(external_id, '') = '' ORDER BY id`)
	if err != nil {
		return err
	}
	var ids []int
	for rows.Next() {
		var id int
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			return err
		}
		ids = append(ids, id)
	}
	rows.Close()
	for _, id := range ids {
		if _, err := db.Exec(`UPDATE maintenances SET external_id = ?,
			last_updated = CASE WHEN COALESCE(last_updated, '') = '' THEN ? ELSE last_updated END
			WHERE id = ? AND COALESCE(external_id, '') = ''`, newLineSnapshotUUID(), time.Now().UTC().Format(time.RFC3339Nano), id); err != nil {
			return err
		}
	}
	return nil
}

func mergeTenantOperationalState(db *sql.DB, payload map[string]interface{}) (bool, error) {
	changed := false
	paymentObjects := snapshotObjectsByID(payload["payments"])
	rows, err := db.Query(`SELECT external_id, COALESCE(payment_date, ''), COALESCE(method, ''),
		COALESCE(slip_path, ''), COALESCE(payment_status, 'pending'), COALESCE(slip_path_array, '[]'),
		COALESCE(paid_amount, 0), COALESCE(last_updated, '')
		FROM payments WHERE COALESCE(external_id, '') != ''`)
	if err != nil {
		return false, err
	}
	for rows.Next() {
		var id, paymentDate, method, slipPath, status, slipJSON, lastUpdated string
		var paidAmount float64
		if err := rows.Scan(&id, &paymentDate, &method, &slipPath, &status, &slipJSON, &paidAmount, &lastUpdated); err != nil {
			rows.Close()
			return false, err
		}
		item := paymentObjects[id]
		if item == nil {
			continue
		}
		var slips []interface{}
		if json.Unmarshal([]byte(slipJSON), &slips) != nil {
			slips = []interface{}{}
		}
		changed = setSnapshotField(item, "paymentDate", paymentDate) || changed
		changed = setSnapshotField(item, "method", method) || changed
		changed = setSnapshotField(item, "slipPath", slipPath) || changed
		changed = setSnapshotField(item, "paymentStatus", status) || changed
		changed = setSnapshotField(item, "slipPathArray", slips) || changed
		changed = setSnapshotField(item, "paidAmount", paidAmount) || changed
		if lastUpdated != "" {
			changed = setSnapshotField(item, "lastUpdated", lastUpdated) || changed
		}
	}
	rows.Close()

	maintenance, deduplicated := normalizeMaintenancePayload(payload["maintenance"])
	changed = deduplicated || changed
	maintenanceObjects := snapshotObjectsByID(maintenance)
	rows, err = db.Query(`SELECT id, external_id, room_number, issue, status, COALESCE(cost, 0),
		COALESCE(reported_at, ''), COALESCE(resolved_at, ''), COALESCE(payment_method, ''),
		COALESCE(slip_path, ''), COALESCE(issue_image, ''), COALESCE(quote_approved_at, ''), COALESCE(last_updated, '')
		FROM maintenances WHERE COALESCE(external_id, '') != '' ORDER BY id`)
	if err != nil {
		return false, err
	}
	for rows.Next() {
		var serverID int
		var id, room, issue, status, reportedAt, resolvedAt, paymentMethod, slipPath, issueImage, quoteApprovedAt, lastUpdated string
		var cost float64
		if err := rows.Scan(&serverID, &id, &room, &issue, &status, &cost, &reportedAt, &resolvedAt,
			&paymentMethod, &slipPath, &issueImage, &quoteApprovedAt, &lastUpdated); err != nil {
			rows.Close()
			return false, err
		}
		id = strings.ToLower(strings.TrimSpace(id))
		item := maintenanceObjects[id]
		if item == nil {
			item = map[string]interface{}{"id": id}
			maintenance = append(maintenance, item)
			maintenanceObjects[id] = item
			changed = true
		}
		fields := map[string]interface{}{
			"serverId": float64(serverID), "roomNumber": room, "issue": issue, "status": status, "cost": cost,
			"reportedAt": reportedAt, "resolvedAt": resolvedAt, "paymentMethod": paymentMethod,
			"slipPath": slipPath, "issueImage": issueImage, "quoteApprovedAt": quoteApprovedAt, "lastUpdated": lastUpdated,
		}
		for key, value := range fields {
			changed = setSnapshotField(item, key, value) || changed
		}
	}
	rows.Close()
	payload["maintenance"] = maintenance
	return changed, nil
}

func snapshotObjectsByID(value interface{}) map[string]map[string]interface{} {
	result := map[string]map[string]interface{}{}
	items, _ := value.([]interface{})
	for _, raw := range items {
		item, _ := raw.(map[string]interface{})
		id, _ := item["id"].(string)
		if id != "" {
			result[id] = item
		}
	}
	return result
}

func normalizeMaintenanceSnapshots(items []lineMaintenanceSnapshot) []lineMaintenanceSnapshot {
	result := make([]lineMaintenanceSnapshot, 0, len(items))
	indexes := make(map[string]int, len(items))
	for _, item := range items {
		id := strings.ToLower(strings.TrimSpace(item.ID))
		item.ID = id
		if id == "" {
			result = append(result, item)
			continue
		}
		if index, exists := indexes[id]; exists {
			if maintenanceTimestamp(item.LastUpdated).After(maintenanceTimestamp(result[index].LastUpdated)) {
				result[index] = item
			}
			continue
		}
		indexes[id] = len(result)
		result = append(result, item)
	}
	return result
}

func normalizeMaintenancePayload(value interface{}) ([]interface{}, bool) {
	items, _ := value.([]interface{})
	result := make([]interface{}, 0, len(items))
	indexes := make(map[string]int, len(items))
	changed := false
	for _, raw := range items {
		item, ok := raw.(map[string]interface{})
		if !ok {
			result = append(result, raw)
			continue
		}
		originalID, _ := item["id"].(string)
		id := strings.ToLower(strings.TrimSpace(originalID))
		if id == "" {
			result = append(result, item)
			continue
		}
		if originalID != id {
			item["id"] = id
			changed = true
		}
		if index, exists := indexes[id]; exists {
			changed = true
			current, _ := result[index].(map[string]interface{})
			if maintenanceTimestamp(snapshotString(item, "lastUpdated")).After(maintenanceTimestamp(snapshotString(current, "lastUpdated"))) {
				result[index] = item
			}
			continue
		}
		indexes[id] = len(result)
		result = append(result, item)
	}
	return result, changed
}

func snapshotString(item map[string]interface{}, key string) string {
	value, _ := item[key].(string)
	return value
}

func maintenanceTimestamp(value string) time.Time {
	parsed, err := time.Parse(time.RFC3339Nano, strings.TrimSpace(value))
	if err != nil {
		return time.Time{}
	}
	return parsed
}

func setSnapshotField(item map[string]interface{}, key string, value interface{}) bool {
	if reflect.DeepEqual(item[key], value) {
		return false
	}
	item[key] = value
	return true
}

func newLineSnapshotUUID() string {
	value := make([]byte, 16)
	if _, err := rand.Read(value); err != nil {
		return fmt.Sprintf("%d-0000-4000-8000-000000000000", time.Now().UnixNano())
	}
	value[6] = (value[6] & 0x0f) | 0x40
	value[8] = (value[8] & 0x3f) | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", value[0:4], value[4:6], value[6:8], value[8:10], value[10:16])
}

func stableSnapshotUserID(tenant lineTenantSnapshot) int {
	if tenant.ServerID != nil && *tenant.ServerID > 0 {
		return *tenant.ServerID
	}
	var value int32 = 17
	for _, scalar := range strings.ToUpper(tenant.ID) {
		value = value*31 + int32(scalar)
	}
	result := int64(value)
	if result < 0 {
		result = -result
	}
	if result <= 0 || result > math.MaxInt32 {
		return 1
	}
	return int(result)
}

func resolveLineTenantDB(master *sql.DB, lineUserID string) (*sql.DB, int, string, error) {
	var accountID int
	var tenantID string
	err := master.QueryRow(`SELECT account_id, tenant_id FROM line_links
		WHERE line_user_id = ? AND status = 'linked' AND tenant_id != ''`, lineUserID).Scan(&accountID, &tenantID)
	if err != nil {
		return nil, 0, "", err
	}
	tenantDB, err := GetTenantDB(accountID)
	return tenantDB, accountID, tenantID, err
}

type lineInvoiceSendRequest struct {
	PaymentID string `json:"payment_id"`
}

func HandleSendLineInvoice(master *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
			return
		}
		_, accountID, _, err := resolveSyncAccount(master, r)
		if err != nil {
			http.Error(w, `{"error":"Unauthorized"}`, http.StatusUnauthorized)
			return
		}
		var request lineInvoiceSendRequest
		decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 32<<10))
		if err := decoder.Decode(&request); err != nil || strings.TrimSpace(request.PaymentID) == "" {
			http.Error(w, `{"error":"กรุณาระบุบิลที่ต้องการส่ง"}`, http.StatusBadRequest)
			return
		}
		tenantDB, err := GetTenantDB(accountID)
		if err != nil {
			http.Error(w, `{"error":"เปิดข้อมูลหอพักไม่สำเร็จ"}`, http.StatusInternalServerError)
			return
		}

		var paymentID int
		var tenantID, lineUserID string
		var invoice lineInvoiceFlexData
		err = tenantDB.QueryRow(`SELECT p.payment_id, u.external_id, COALESCE(u.line_user_id, ''), p.room_number, p.month,
			COALESCE(u.full_name, ''), COALESCE(p.due_date, ''), COALESCE(p.last_updated, ''),
			COALESCE(p.payment_date, ''), COALESCE(NULLIF(p.payment_status, ''), 'pending'),
			COALESCE(p.installment_phase, 0), p.rent_fee, COALESCE(p.deposit_fee, 0),
			p.water_fee, p.electric_fee, p.common_fee, p.late_fee, COALESCE(p.appliance_fee, 0),
			p.amount, COALESCE(p.paid_amount, 0)
			FROM payments p JOIN users u ON p.user_id = u.user_id WHERE p.external_id = ?`,
			request.PaymentID).Scan(&paymentID, &tenantID, &lineUserID, &invoice.Room, &invoice.Period,
			&invoice.Name, &invoice.DueDate, &invoice.UpdatedAt, &invoice.PaymentDate, &invoice.Status,
			&invoice.Installment, &invoice.Rent, &invoice.Deposit, &invoice.Water, &invoice.Electric,
			&invoice.Common, &invoice.Late, &invoice.Appliance, &invoice.Total, &invoice.Paid)
		if err == sql.ErrNoRows {
			http.Error(w, `{"error":"ไม่พบบิลนี้ในข้อมูลล่าสุด กรุณาซิงก์แล้วลองใหม่"}`, http.StatusNotFound)
			return
		}
		if err != nil {
			http.Error(w, `{"error":"อ่านข้อมูลบิลไม่สำเร็จ"}`, http.StatusInternalServerError)
			return
		}
		if lineUserID == "" {
			err = master.QueryRow(`SELECT line_user_id FROM line_links WHERE account_id = ? AND tenant_id = ? AND status = 'linked'`,
				accountID, tenantID).Scan(&lineUserID)
		}
		if err != nil || lineUserID == "" {
			http.Error(w, `{"error":"ลูกบ้านรายนี้ยังไม่ได้ผูกบัญชี LINE"}`, http.StatusConflict)
			return
		}

		invoice.InvoiceNo = fmt.Sprintf("INV-%05d", paymentID)
		knownTotal := invoice.Rent + invoice.Deposit + invoice.Water + invoice.Electric + invoice.Common + invoice.Appliance + invoice.Late
		if difference := invoice.Total - knownTotal; math.Abs(difference) >= 0.01 {
			invoice.Other = difference
		}
		if err := sendLineInvoice(lineUserID, invoice); err != nil {
			master.Exec(`INSERT INTO line_delivery_logs(account_id, tenant_id, payment_id, status, detail, created_at)
				VALUES (?, ?, ?, 'failed', ?, ?)`, accountID, tenantID, request.PaymentID, err.Error(), time.Now().UTC().Format(time.RFC3339))
			http.Error(w, `{"error":"LINE ไม่รับข้อความ กรุณาตรวจสอบการเชื่อมต่อแล้วลองใหม่"}`, http.StatusBadGateway)
			return
		}
		master.Exec(`INSERT INTO line_delivery_logs(account_id, tenant_id, payment_id, status, detail, created_at)
			VALUES (?, ?, ?, 'sent', '', ?)`, accountID, tenantID, request.PaymentID, time.Now().UTC().Format(time.RFC3339))
		writeLineJSON(w, http.StatusOK, map[string]string{"status": "success", "message": "ส่งบิลไปยัง LINE ของลูกบ้านแล้ว"})
	}
}

func sendLineInvoice(lineUserID string, invoice lineInvoiceFlexData) error {
	if getLineToken() == "" {
		return errors.New("LINE token is not configured")
	}
	message := map[string]interface{}{
		"type": "flex", "altText": lineInvoiceAltText(invoice), "contents": buildLineInvoiceBubble(invoice),
	}
	return pushLinePayload(lineUserID, message)
}
func lineInfoRow(label, value string) map[string]interface{} {
	return map[string]interface{}{"type": "box", "layout": "baseline", "spacing": "sm", "contents": []map[string]interface{}{
		{"type": "text", "text": label, "size": "xs", "color": "#9CA3AF", "flex": 2, "wrap": true},
		{"type": "text", "text": blankAsDash(value), "size": "sm", "color": "#374151", "wrap": true, "flex": 4},
	}}
}

func blankAsDash(value string) string {
	if strings.TrimSpace(value) == "" {
		return "-"
	}
	return value
}

func pushLinePayload(lineUserID string, messages ...map[string]interface{}) error {
	var msgs []interface{}
	for _, m := range messages {
		msgs = append(msgs, m)
	}
	body, err := json.Marshal(map[string]interface{}{"to": lineUserID, "messages": msgs})
	if err != nil {
		return err
	}
	req, err := http.NewRequest(http.MethodPost, "https://api.line.me/v2/bot/message/push", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+getLineToken())
	req.Header.Set("Content-Type", "application/json")
	resp, err := (&http.Client{Timeout: 12 * time.Second}).Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		detail, readErr := io.ReadAll(io.LimitReader(resp.Body, 4096))
		if readErr == nil && strings.TrimSpace(string(detail)) != "" {
			return fmt.Errorf("LINE API status %d: %s", resp.StatusCode, strings.TrimSpace(string(detail)))
		}
		return fmt.Errorf("LINE API status %d", resp.StatusCode)
	}
	return nil
}

func writeLineJSON(w http.ResponseWriter, status int, value interface{}) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(value)
}

func deleteStaleRecords(tx *sql.Tx, tableName string, activeIDs map[string]bool) error {
	query := fmt.Sprintf(`SELECT external_id FROM %s WHERE external_id != ''`, tableName)
	rows, err := tx.Query(query)
	if err != nil {
		return err
	}
	var staleIDs []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			return err
		}
		if !activeIDs[id] {
			staleIDs = append(staleIDs, id)
		}
	}
	rows.Close()
	for _, id := range staleIDs {
		deleteQuery := fmt.Sprintf(`DELETE FROM %s WHERE external_id = ?`, tableName)
		if _, err := tx.Exec(deleteQuery, id); err != nil {
			return err
		}
	}
	return nil
}
