package handlers

import (
	"database/sql"
	"fmt"
	"os"
	"sync"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

var (
	tenantDBs = make(map[int]*sql.DB)
	dbMutex   sync.RWMutex
)

// GetTenantDB returns the *sql.DB for the given adminID.
// It opens a new connection if one doesn't exist, and ensures the database is initialized.
func GetTenantDB(adminID int) (*sql.DB, error) {
	dbMutex.RLock()
	db, exists := tenantDBs[adminID]
	dbMutex.RUnlock()

	if exists {
		return db, nil
	}

	dbMutex.Lock()
	defer dbMutex.Unlock()

	// Double-check after acquiring write lock
	if db, exists := tenantDBs[adminID]; exists {
		return db, nil
	}

	// Create directory if not exists
	err := os.MkdirAll("./dorm_data", os.ModePerm)
	if err != nil {
		return nil, fmt.Errorf("failed to create dorm_data directory: %w", err)
	}

	dbPath := fmt.Sprintf("./dorm_data/tenant_%d.db", adminID)
	newDB, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open tenant DB: %w", err)
	}

	newDB.Exec("PRAGMA journal_mode=WAL;")
	newDB.Exec("PRAGMA busy_timeout=5000;")
	newDB.SetMaxOpenConns(10)
	newDB.SetMaxIdleConns(5)
	newDB.SetConnMaxLifetime(5 * time.Minute)

	// Initialize tables for this tenant
	InitializeTenantDatabase(newDB)

	tenantDBs[adminID] = newDB
	return newDB, nil
}

// CloseAllTenantDBs cleanly closes all cached tenant DB connections.
func CloseAllTenantDBs() {
	dbMutex.Lock()
	defer dbMutex.Unlock()
	for id, db := range tenantDBs {
		db.Close()
		delete(tenantDBs, id)
	}
}

// InitializeTenantDatabase creates the tables required for a tenant.
func InitializeTenantDatabase(db *sql.DB) {
	db.Exec(`CREATE TABLE IF NOT EXISTS users (user_id INTEGER PRIMARY KEY AUTOINCREMENT, prefix TEXT, first_name TEXT, last_name TEXT, full_name TEXT, room_number TEXT, status TEXT, national_id TEXT, phone TEXT, address TEXT, move_in_date TEXT, contract_end_date TEXT, deposit REAL DEFAULT 0)`)
	db.Exec(`CREATE UNIQUE INDEX IF NOT EXISTS idx_users_active_room ON users (room_number) WHERE status = 'กำลังพักอาศัย' OR status = 'จอง'`)

	db.Exec(`CREATE TABLE IF NOT EXISTS room_types (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE, price REAL DEFAULT 0)`)
	db.Exec(`ALTER TABLE room_types ADD COLUMN water_fee_default REAL DEFAULT 0`)
	db.Exec(`ALTER TABLE room_types ADD COLUMN electric_fee_default REAL DEFAULT 0`)
	db.Exec(`ALTER TABLE room_types ADD COLUMN common_fee_default REAL DEFAULT 0`)
	db.Exec(`ALTER TABLE room_types ADD COLUMN late_fee_default REAL DEFAULT 0`)

	db.Exec(`CREATE TABLE IF NOT EXISTS rooms (room_id INTEGER PRIMARY KEY AUTOINCREMENT, room_number TEXT UNIQUE, room_type TEXT)`)

	db.Exec(`CREATE TABLE IF NOT EXISTS payments (payment_id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER, room_number TEXT, rent_fee REAL, water_fee REAL, electric_fee REAL, common_fee REAL, late_fee REAL, amount REAL, month TEXT, payment_date TEXT, method TEXT, slip_path TEXT, water_meter_prev REAL DEFAULT 0, water_meter_curr REAL DEFAULT 0, electric_meter_prev REAL DEFAULT 0, electric_meter_curr REAL DEFAULT 0)`)
	db.Exec(`CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_unique ON payments (user_id, month, COALESCE(installment_phase, '0'))`)

	db.Exec(`CREATE TABLE IF NOT EXISTS system_logs (log_id INTEGER PRIMARY KEY AUTOINCREMENT, action_type TEXT, details TEXT, timestamp TEXT)`)

	db.Exec(`CREATE TABLE IF NOT EXISTS deposit_refunds (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER, room_number TEXT, original_deposit REAL, cleaning_fee REAL, damage_fee REAL, net_refund REAL, refund_date TEXT)`)

	db.Exec(`CREATE TABLE IF NOT EXISTS room_conditions (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER, room_number TEXT, image_path TEXT, uploaded_at TEXT)`)

	db.Exec(`CREATE TABLE IF NOT EXISTS maintenances (id INTEGER PRIMARY KEY AUTOINCREMENT, room_number TEXT, issue TEXT, status TEXT DEFAULT 'รอดำเนินการ', cost REAL DEFAULT 0, reported_at TEXT, resolved_at TEXT, payment_method TEXT DEFAULT '', slip_path TEXT DEFAULT '')`)
	db.Exec(`ALTER TABLE maintenances ADD COLUMN issue_image TEXT DEFAULT ''`)
	db.Exec(`ALTER TABLE maintenances ADD COLUMN last_updated TEXT DEFAULT ''`)
	db.Exec(`ALTER TABLE maintenances ADD COLUMN quote_approved_at TEXT DEFAULT ''`)

	db.Exec(`ALTER TABLE users ADD COLUMN booking_status TEXT`)
	db.Exec(`ALTER TABLE users ADD COLUMN payment_method TEXT`)
	db.Exec(`ALTER TABLE users ADD COLUMN indefinite_contract INTEGER DEFAULT 0`)
	db.Exec(`ALTER TABLE users ADD COLUMN booking_slips TEXT`)

	db.Exec(`ALTER TABLE payments ADD COLUMN payment_plan TEXT`)
	db.Exec(`ALTER TABLE payments ADD COLUMN installment_phase INTEGER`)
	db.Exec(`ALTER TABLE payments ADD COLUMN due_date TEXT`)
	db.Exec(`ALTER TABLE payments ADD COLUMN payment_status TEXT DEFAULT 'pending'`)
	db.Exec(`ALTER TABLE payments ADD COLUMN slip_path_array TEXT`)
	db.Exec(`ALTER TABLE payments ADD COLUMN paid_amount REAL DEFAULT 0`)
	db.Exec(`ALTER TABLE payments ADD COLUMN last_updated TEXT DEFAULT ''`)

	db.Exec(`ALTER TABLE users ADD COLUMN additional_appliances TEXT`)
	db.Exec(`ALTER TABLE users ADD COLUMN additional_appliance_fee REAL DEFAULT 0`)

	db.Exec(`ALTER TABLE users ADD COLUMN line_user_id TEXT DEFAULT ''`)
	db.Exec(`ALTER TABLE users ADD COLUMN additional_details TEXT`)
	db.Exec(`ALTER TABLE users ADD COLUMN bot_state TEXT DEFAULT 'none'`)
	db.Exec(`ALTER TABLE payments ADD COLUMN appliance_fee REAL DEFAULT 0`)
	db.Exec(`ALTER TABLE users ADD COLUMN external_id TEXT DEFAULT ''`)
	db.Exec(`ALTER TABLE payments ADD COLUMN external_id TEXT DEFAULT ''`)
	db.Exec(`ALTER TABLE payments ADD COLUMN deposit_fee REAL DEFAULT 0`)
	db.Exec(`ALTER TABLE maintenances ADD COLUMN external_id TEXT DEFAULT ''`)
	db.Exec(`ALTER TABLE rooms ADD COLUMN external_id TEXT DEFAULT ''`)
	db.Exec(`ALTER TABLE room_types ADD COLUMN external_id TEXT DEFAULT ''`)
	db.Exec(`CREATE UNIQUE INDEX IF NOT EXISTS idx_users_external_id ON users(external_id) WHERE external_id != ''`)
	db.Exec(`CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_external_id ON payments(external_id) WHERE external_id != ''`)
	db.Exec(`CREATE UNIQUE INDEX IF NOT EXISTS idx_maintenance_external_id ON maintenances(external_id) WHERE external_id != ''`)
	
	// Replay Protection for slips
	db.Exec(`ALTER TABLE payments ADD COLUMN slip_payload TEXT DEFAULT ''`)
	db.Exec(`ALTER TABLE maintenances ADD COLUMN slip_payload TEXT DEFAULT ''`)
	db.Exec(`CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_slip_payload ON payments(slip_payload) WHERE slip_payload != '' AND slip_payload IS NOT NULL`)
	db.Exec(`CREATE UNIQUE INDEX IF NOT EXISTS idx_maintenances_slip_payload ON maintenances(slip_payload) WHERE slip_payload != '' AND slip_payload IS NOT NULL`)
}
