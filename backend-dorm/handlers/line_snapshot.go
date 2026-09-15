package handlers

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"net/http"
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
}

type lineMaintenanceSnapshot struct {
	ID            string  `json:"id"`
	RoomNumber    string  `json:"roomNumber"`
	Issue         string  `json:"issue"`
	Status        string  `json:"status"`
	Cost          float64 `json:"cost"`
	ReportedAt    string  `json:"reportedAt"`
	ResolvedAt    string  `json:"resolvedAt"`
	PaymentMethod string  `json:"paymentMethod"`
	SlipPath      string  `json:"slipPath"`
	IssueImage    string  `json:"issueImage"`
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
}

func ensureLineTenantSchema(db *sql.DB) {
	InitializeTenantDatabase(db)
	db.Exec(`ALTER TABLE users ADD COLUMN external_id TEXT DEFAULT ''`)
	db.Exec(`ALTER TABLE payments ADD COLUMN external_id TEXT DEFAULT ''`)
	db.Exec(`ALTER TABLE payments ADD COLUMN deposit_fee REAL DEFAULT 0`)
	db.Exec(`ALTER TABLE maintenances ADD COLUMN external_id TEXT DEFAULT ''`)
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
	tenantDB, err := GetTenantDB(accountID)
	if err != nil {
		return err
	}
	return materializeLineSnapshotInto(master, tenantDB, accountID, snapshot)
}

func materializeLineSnapshotInto(master, tenantDB *sql.DB, accountID int, snapshot lineSyncEnvelope) error {
	ensureLineTenantSchema(tenantDB)
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

	for _, room := range snapshot.Rooms {
		_, err = tx.Exec(`INSERT INTO rooms(room_number, room_type, external_id) VALUES (?, ?, ?)
			ON CONFLICT(room_number) DO UPDATE SET room_type=excluded.room_type, external_id=excluded.external_id`,
			room.RoomNumber, room.RoomType, room.ID)
		if err != nil {
			return fmt.Errorf("upsert room: %w", err)
		}
	}
	for _, roomType := range snapshot.RoomTypes {
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
	for _, payment := range snapshot.Payments {
		slips, _ := json.Marshal(payment.SlipPathArray)
		_, err = tx.Exec(`INSERT INTO payments
			(user_id, room_number, rent_fee, deposit_fee, water_fee, electric_fee, common_fee, late_fee,
			 appliance_fee, amount, month, payment_date, method, slip_path, payment_plan, installment_phase,
			 due_date, payment_status, slip_path_array, paid_amount, external_id)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
			ON CONFLICT(external_id) WHERE external_id != '' DO UPDATE SET user_id=excluded.user_id, room_number=excluded.room_number,
			 rent_fee=excluded.rent_fee, deposit_fee=excluded.deposit_fee, water_fee=excluded.water_fee,
			 electric_fee=excluded.electric_fee, common_fee=excluded.common_fee, late_fee=excluded.late_fee,
			 appliance_fee=excluded.appliance_fee, amount=excluded.amount, month=excluded.month,
			 payment_date=excluded.payment_date, method=excluded.method, slip_path=excluded.slip_path,
			 payment_plan=excluded.payment_plan, installment_phase=excluded.installment_phase,
			 due_date=excluded.due_date, payment_status=excluded.payment_status,
			 slip_path_array=excluded.slip_path_array, paid_amount=excluded.paid_amount`,
			payment.UserID, payment.RoomNumber, payment.RentFee, payment.DepositFee, payment.WaterFee,
			payment.ElectricFee, payment.CommonFee, payment.LateFee, payment.ApplianceFee, payment.Amount,
			payment.Month, payment.PaymentDate, payment.Method, payment.SlipPath, payment.PaymentPlan,
			payment.InstallmentPhase, payment.DueDate, payment.PaymentStatus, string(slips), payment.PaidAmount,
			payment.ID)
		if err != nil {
			return fmt.Errorf("upsert payment: %w", err)
		}
	}
	for _, maintenance := range snapshot.Maintenance {
		_, err = tx.Exec(`INSERT INTO maintenances
			(room_number, issue, status, cost, reported_at, resolved_at, payment_method, slip_path, issue_image, external_id)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
			ON CONFLICT(external_id) WHERE external_id != '' DO UPDATE SET room_number=excluded.room_number, issue=excluded.issue,
			 status=excluded.status, cost=excluded.cost, reported_at=excluded.reported_at,
			 resolved_at=excluded.resolved_at, payment_method=excluded.payment_method,
			 slip_path=excluded.slip_path, issue_image=excluded.issue_image`,
			maintenance.RoomNumber, maintenance.Issue, maintenance.Status, maintenance.Cost,
			maintenance.ReportedAt, maintenance.ResolvedAt, maintenance.PaymentMethod,
			maintenance.SlipPath, maintenance.IssueImage, maintenance.ID)
		if err != nil {
			return fmt.Errorf("upsert maintenance: %w", err)
		}
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
	return tx.Commit()
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

		var tenantID, lineUserID, room, period, name, dueDate string
		var rent, deposit, water, electric, common, late, appliance, total float64
		err = tenantDB.QueryRow(`SELECT u.external_id, COALESCE(u.line_user_id, ''), p.room_number, p.month,
			COALESCE(u.full_name, ''), COALESCE(p.due_date, ''), p.rent_fee, COALESCE(p.deposit_fee, 0),
			p.water_fee, p.electric_fee, p.common_fee, p.late_fee, COALESCE(p.appliance_fee, 0), p.amount
			FROM payments p JOIN users u ON p.user_id = u.user_id WHERE p.external_id = ?`,
			request.PaymentID).Scan(&tenantID, &lineUserID, &room, &period, &name, &dueDate,
			&rent, &deposit, &water, &electric, &common, &late, &appliance, &total)
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

		invoiceKey := strings.ToUpper(strings.ReplaceAll(request.PaymentID, "-", ""))
		if len(invoiceKey) > 8 {
			invoiceKey = invoiceKey[:8]
		}
		invoiceNo := "INV-" + invoiceKey
		items := []lineInvoiceItem{
			{"ค่าเช่าห้องพัก", rent}, {"เงินมัดจำ", deposit}, {"ค่าน้ำประปา", water},
			{"ค่าไฟฟ้า", electric}, {"ค่าส่วนกลาง", common}, {"ค่าอุปกรณ์เสริม", appliance}, {"ค่าปรับล่าช้า", late},
		}
		if err := sendLineInvoice(lineUserID, invoiceNo, name, room, period, dueDate, items, total); err != nil {
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

type lineInvoiceItem struct {
	Label  string
	Amount float64
}

func sendLineInvoice(lineUserID, invoiceNo, name, room, period, dueDate string, items []lineInvoiceItem, total float64) error {
	if getLineToken() == "" {
		return errors.New("LINE token is not configured")
	}
	rows := make([]map[string]interface{}, 0, len(items)+2)
	for _, item := range items {
		if item.Amount == 0 {
			continue
		}
		rows = append(rows, map[string]interface{}{
			"type": "box", "layout": "horizontal",
			"contents": []map[string]interface{}{
				{"type": "text", "text": item.Label, "size": "sm", "color": "#555555", "flex": 2},
				{"type": "text", "text": fmt.Sprintf("%.2f บาท", item.Amount), "size": "sm", "color": "#111111", "align": "end", "flex": 1},
			},
		})
	}
	if len(rows) == 0 {
		rows = append(rows, map[string]interface{}{"type": "text", "text": "ไม่มีรายการค่าใช้จ่าย", "size": "sm", "color": "#777777"})
	}
	message := map[string]interface{}{
		"type": "flex", "altText": fmt.Sprintf("บิลห้อง %s ยอด %.2f บาท", room, total),
		"contents": map[string]interface{}{
			"type": "bubble", "size": "kilo",
			"header": map[string]interface{}{"type": "box", "layout": "vertical", "contents": []map[string]interface{}{
				{"type": "text", "text": "ใบแจ้งหนี้", "weight": "bold", "size": "xl", "color": "#111111"},
				{"type": "text", "text": "DormiNet", "size": "sm", "color": "#777777", "margin": "sm"},
			}},
			"body": map[string]interface{}{"type": "box", "layout": "vertical", "spacing": "sm", "contents": []interface{}{
				lineInfoRow("เลขที่", invoiceNo), lineInfoRow("ห้อง", room), lineInfoRow("ชื่อ", name),
				lineInfoRow("รอบบิล", period), lineInfoRow("ครบกำหนด", blankAsDash(dueDate)),
				map[string]interface{}{"type": "separator", "margin": "md"},
				map[string]interface{}{"type": "box", "layout": "vertical", "spacing": "sm", "margin": "md", "contents": rows},
				map[string]interface{}{"type": "separator", "margin": "md"},
				map[string]interface{}{"type": "box", "layout": "horizontal", "margin": "md", "contents": []map[string]interface{}{
					{"type": "text", "text": "ยอดที่ต้องชำระ", "weight": "bold", "flex": 2},
					{"type": "text", "text": fmt.Sprintf("%.2f บาท", total), "weight": "bold", "align": "end", "flex": 1},
				}},
			}},
			"footer": map[string]interface{}{"type": "box", "layout": "vertical", "contents": []map[string]interface{}{
				{"type": "text", "text": "ส่งสลิปในแชทนี้หลังชำระเงิน", "size": "xs", "color": "#777777", "align": "center"},
			}},
		},
	}
	return pushLinePayload(lineUserID, message)
}

func lineInfoRow(label, value string) map[string]interface{} {
	return map[string]interface{}{"type": "box", "layout": "baseline", "spacing": "sm", "contents": []map[string]interface{}{
		{"type": "text", "text": label, "size": "sm", "color": "#999999", "flex": 1},
		{"type": "text", "text": blankAsDash(value), "size": "sm", "color": "#333333", "wrap": true, "flex": 3},
	}}
}

func blankAsDash(value string) string {
	if strings.TrimSpace(value) == "" {
		return "-"
	}
	return value
}

func pushLinePayload(lineUserID string, message map[string]interface{}) error {
	body, err := json.Marshal(map[string]interface{}{"to": lineUserID, "messages": []interface{}{message}})
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
		return fmt.Errorf("LINE API status %d", resp.StatusCode)
	}
	return nil
}

func writeLineJSON(w http.ResponseWriter, status int, value interface{}) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(value)
}
