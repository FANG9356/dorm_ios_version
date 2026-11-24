package handlers

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"

	_ "github.com/mattn/go-sqlite3"
	"golang.org/x/crypto/bcrypt"
)

func newPhase1MasterDB(t *testing.T) *sql.DB {
	t.Helper()
	db, err := sql.Open("sqlite3", filepath.Join(t.TempDir(), "master.db")+"?_busy_timeout=5000")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	for _, stmt := range []string{
		`CREATE TABLE admins (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			username TEXT UNIQUE,
			password TEXT,
			role TEXT DEFAULT 'services',
			email TEXT DEFAULT '',
			backup_email TEXT DEFAULT '',
			profile_image TEXT DEFAULT '',
			must_change_password INTEGER DEFAULT 0,
			last_active TEXT DEFAULT '',
			dorm_code TEXT DEFAULT '',
			promptpay_id TEXT DEFAULT '',
			payment_type TEXT DEFAULT 'promptpay',
			bank_account TEXT DEFAULT '',
			account_name TEXT DEFAULT ''
		)`,
		`CREATE TABLE sessions (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			admin_id INTEGER,
			token TEXT UNIQUE,
			created_at DATETIME DEFAULT CURRENT_TIMESTAMP
		)`,
		`CREATE TABLE password_resets (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			email TEXT UNIQUE,
			token TEXT,
			expires_at TEXT
		)`,
		`CREATE TABLE line_links (
			line_user_id TEXT PRIMARY KEY,
			account_id INTEGER NOT NULL,
			tenant_id TEXT NOT NULL,
			status TEXT NOT NULL,
			legacy_room TEXT DEFAULT '',
			linked_at TEXT DEFAULT '',
			updated_at TEXT DEFAULT ''
		)`,
	} {
		if _, err := db.Exec(stmt); err != nil {
			t.Fatal(err)
		}
	}
	return db
}

func TestGenerateLoginTokenCrossTenantBlockedAndSingleUse(t *testing.T) {
	t.Setenv("JWT_SECRET", "phase1-test-secret-0123456789abcdef")
	db := newPhase1MasterDB(t)
	hash, _ := bcrypt.GenerateFromPassword([]byte("Password123"), bcrypt.MinCost)

	// Tenant 1: owner1 + staff1; Tenant 2: owner2
	_, _ = db.Exec(`INSERT INTO admins (id, username, password, role, email) VALUES
		(1, 'owner1', ?, 'superadmin', 'owner1@dorm.test'),
		(2, 'staff1', ?, 'admin', 'owner1@dorm.test'),
		(3, 'owner2', ?, 'superadmin', 'owner2@dorm.test')`, string(hash), string(hash), string(hash))

	// 1. owner2 tries to mint QR login token for owner1 (cross-tenant) -> 403
	req := httptest.NewRequest(http.MethodPost, "/api/admins/login-qr/generate", bytes.NewBufferString(`{"target_username":"owner1"}`))
	req = req.WithContext(context.WithValue(context.WithValue(req.Context(), "admin_id", 3), "admin_role", "superadmin"))
	rec := httptest.NewRecorder()
	GenerateLoginTokenHandler(db)(rec, req)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("cross-tenant QR generate status = %d, want 403 (body=%s)", rec.Code, rec.Body.String())
	}

	// 2. owner1 mints QR login token for same-tenant staff1 -> 200
	req = httptest.NewRequest(http.MethodPost, "/api/admins/login-qr/generate", bytes.NewBufferString(`{"target_username":"staff1"}`))
	req = req.WithContext(context.WithValue(context.WithValue(req.Context(), "admin_id", 1), "admin_role", "superadmin"))
	rec = httptest.NewRecorder()
	GenerateLoginTokenHandler(db)(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("same-tenant QR generate status = %d, want 200 (body=%s)", rec.Code, rec.Body.String())
	}
	var genResp struct {
		LoginToken string `json:"login_token"`
	}
	if err := json.NewDecoder(rec.Body).Decode(&genResp); err != nil || genResp.LoginToken == "" {
		t.Fatalf("missing login_token: %v", err)
	}

	// 3. First redemption succeeds -> 200
	loginBody, _ := json.Marshal(map[string]string{"login_token": genResp.LoginToken})
	req1 := httptest.NewRequest(http.MethodPost, "/api/login/qr", bytes.NewReader(loginBody))
	req1.RemoteAddr = "198.51.100.11:1234"
	rec1 := httptest.NewRecorder()
	LoginWithQRHandler(db)(rec1, req1)
	if rec1.Code != http.StatusOK {
		t.Fatalf("first QR login status = %d, want 200 (body=%s)", rec1.Code, rec1.Body.String())
	}

	// 4. Second redemption (replay) must be rejected -> 401
	req2 := httptest.NewRequest(http.MethodPost, "/api/login/qr", bytes.NewReader(loginBody))
	req2.RemoteAddr = "198.51.100.11:1234"
	rec2 := httptest.NewRecorder()
	LoginWithQRHandler(db)(rec2, req2)
	if rec2.Code != http.StatusUnauthorized {
		t.Fatalf("replayed QR login status = %d, want 401 (body=%s)", rec2.Code, rec2.Body.String())
	}
}

func TestUpdateAdminDoesNotWipeEmailOnRename(t *testing.T) {
	db := newPhase1MasterDB(t)
	hash, _ := bcrypt.GenerateFromPassword([]byte("Password123"), bcrypt.MinCost)
	_, _ = db.Exec(`INSERT INTO admins (id, username, password, role, email, backup_email) VALUES
		(1, 'owner1', ?, 'superadmin', 'owner1@dorm.test', ''),
		(2, 'staff1', ?, 'admin', 'owner1@dorm.test', 'staff1@personal.test')`, string(hash), string(hash))

	req := httptest.NewRequest(http.MethodPut, "/api/admins/2", bytes.NewBufferString(`{"username":"staff1_renamed"}`))
	req = req.WithContext(context.WithValue(context.WithValue(req.Context(), "admin_id", 1), "admin_role", "superadmin"))
	rec := httptest.NewRecorder()
	UpdateAdminHandler(db)(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("UpdateAdminHandler status = %d, want 200 (body=%s)", rec.Code, rec.Body.String())
	}

	var username, email, backupEmail string
	if err := db.QueryRow("SELECT username, email, backup_email FROM admins WHERE id = 2").Scan(&username, &email, &backupEmail); err != nil {
		t.Fatal(err)
	}
	if username != "staff1_renamed" || email != "owner1@dorm.test" || backupEmail != "staff1@personal.test" {
		t.Fatalf("unexpected admin row after rename: username=%q email=%q backup_email=%q", username, email, backupEmail)
	}
}

func TestRequestTenantDBDoesNotFallbackToPrimaryOwner(t *testing.T) {
	db := newPhase1MasterDB(t)
	_, _ = db.Exec(`INSERT INTO admins (id, username, password, role, email) VALUES
		(1, 'owner1', 'h', 'superadmin', 'owner1@dorm.test'),
		(2, 'orphan_staff', 'h', 'dorm', '')`)

	req := httptest.NewRequest(http.MethodGet, "/api/rooms", nil)
	req = req.WithContext(context.WithValue(req.Context(), "admin_id", 2))
	if _, err := RequestTenantDB(req, db); err == nil {
		t.Fatal("RequestTenantDB unexpectedly fell back to Tenant #1 for orphan staff")
	}
}

func TestHandleLiffLinkDoesNotClearOtherResidents(t *testing.T) {
	tenantDB, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatal(err)
	}
	defer tenantDB.Close()
	InitializeTenantDatabase(tenantDB)
	_, _ = tenantDB.Exec(`INSERT INTO users (external_id, room_number, full_name, status, line_user_id) VALUES
		('tenant-A', '101', 'Resident A', 'กำลังพักอาศัย', 'LINE-A'),
		('tenant-B', '102', 'Resident B', 'กำลังพักอาศัย', '')`)

	if _, err := tenantDB.Exec(`UPDATE users SET line_user_id = CASE WHEN external_id = ? THEN ? ELSE '' END
		WHERE external_id = ? OR line_user_id = ?`, "tenant-B", "LINE-B", "tenant-B", "LINE-B"); err != nil {
		t.Fatal(err)
	}

	var lineA, lineB string
	_ = tenantDB.QueryRow("SELECT line_user_id FROM users WHERE external_id = 'tenant-A'").Scan(&lineA)
	_ = tenantDB.QueryRow("SELECT line_user_id FROM users WHERE external_id = 'tenant-B'").Scan(&lineB)
	if lineA != "LINE-A" || lineB != "LINE-B" {
		t.Fatalf("line_user_id corrupted: tenant-A=%q (want LINE-A), tenant-B=%q (want LINE-B)", lineA, lineB)
	}
}

func TestMediaOwnerIsolationAndDepositRefundRetention(t *testing.T) {
	master := newPhase1MasterDB(t)
	RecordMediaOwner(master, "/uploads/tenant1_secret.jpg", 1)

	ownedByOther, err := mediaOwnedByOtherTenant(master, "tenant1_secret.jpg", 2)
	if err != nil || !ownedByOther {
		t.Fatalf("expected tenant1_secret.jpg to be blocked for tenant 2 (ownedByOther=%v, err=%v)", ownedByOther, err)
	}
	ownedByOther, err = mediaOwnedByOtherTenant(master, "tenant1_secret.jpg", 1)
	if err != nil || ownedByOther {
		t.Fatalf("expected tenant1_secret.jpg to be allowed for tenant 1 (ownedByOther=%v, err=%v)", ownedByOther, err)
	}

	tenantDB, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatal(err)
	}
	defer tenantDB.Close()
	InitializeTenantDatabase(tenantDB)
	_, _ = tenantDB.Exec("ALTER TABLE deposit_refunds ADD COLUMN slip_path TEXT DEFAULT ''")
	_, _ = tenantDB.Exec("INSERT INTO deposit_refunds (user_id, room_number, original_deposit, cleaning_fee, damage_fee, net_refund, refund_date, slip_path) VALUES (1, '101', 3000, 0, 0, 3000, '2026-11-24', 'refund_slip_1.jpg')")

	ref, err := tenantReferencesMedia(tenantDB, "refund_slip_1.jpg")
	if err != nil || !ref {
		t.Fatalf("expected deposit_refunds.slip_path to be recognized as referenced (ref=%v, err=%v)", ref, err)
	}
}

func TestPasswordResetStoresHashedOTP(t *testing.T) {
	t.Setenv("JWT_SECRET", "phase1-test-secret-0123456789abcdef")
	db := newPhase1MasterDB(t)
	_, _ = db.Exec(`INSERT INTO admins (username, password, role, email) VALUES ('owner1', 'hash', 'superadmin', 'owner1@dorm.test')`)

	req := httptest.NewRequest(http.MethodPost, "/api/forgot-password", bytes.NewBufferString(`{"email":"owner1@dorm.test"}`))
	req.RemoteAddr = "198.51.100.22:1234"
	rec := httptest.NewRecorder()
	HandleForgotPassword(db)(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("HandleForgotPassword status = %d, want 200", rec.Code)
	}

	var storedToken string
	if err := db.QueryRow("SELECT token FROM password_resets WHERE email = 'owner1@dorm.test'").Scan(&storedToken); err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(storedToken, "sha256:") || len(storedToken) < 70 {
		t.Fatalf("OTP was not stored as sha256 digest: %q", storedToken)
	}
}
