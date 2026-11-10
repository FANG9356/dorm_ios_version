package handlers

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"golang.org/x/crypto/bcrypt"
)

func resetFixture(t *testing.T, expiry time.Time) (*sql.DB, string) {
	t.Helper()
	db, err := sql.Open("sqlite3", filepath.Join(t.TempDir(), "reset.db")+"?_busy_timeout=5000")
	if err != nil {
		t.Fatal(err)
	}
	email := strings.ToLower(t.Name()) + "@example.test"
	t.Cleanup(func() { db.Close() })
	for _, statement := range []string{
		"CREATE TABLE admins (id INTEGER PRIMARY KEY, email TEXT, password TEXT, must_change_password INTEGER)",
		"CREATE TABLE password_resets (id INTEGER PRIMARY KEY, email TEXT, token TEXT, expires_at TEXT)",
		"CREATE TABLE sessions (id INTEGER PRIMARY KEY, admin_id INTEGER, token TEXT)",
	} {
		if _, err = db.Exec(statement); err != nil {
			t.Fatal(err)
		}
	}
	if _, err = db.Exec("INSERT INTO admins VALUES (1, ?, 'old-hash', 1)", email); err != nil {
		t.Fatal(err)
	}
	if _, err = db.Exec("INSERT INTO password_resets VALUES (1, ?, '246810', ?)", email, expiry.UTC().Format(time.RFC3339)); err != nil {
		t.Fatal(err)
	}
	if _, err = db.Exec("INSERT INTO sessions VALUES (1, 1, 'old-session')"); err != nil {
		t.Fatal(err)
	}
	return db, email
}

func resetRequest(t *testing.T, db *sql.DB, email, otp, password string) int {
	t.Helper()
	body, err := json.Marshal(map[string]string{"email": email, "otp": otp, "new_password": password})
	if err != nil {
		t.Fatal(err)
	}
	recorder := httptest.NewRecorder()
	HandlePasswordReset(db)(recorder, httptest.NewRequest("POST", "/api/reset-password", bytes.NewReader(body)))
	return recorder.Code
}

func TestPasswordResetConsumesOTPOnlyOnce(t *testing.T) {
	db, email := resetFixture(t, time.Now().Add(time.Hour))
	if status := resetRequest(t, db, " "+strings.ToUpper(email)+" ", "246810", "NewPassword1!"); status != 200 {
		t.Fatalf("reset: %d", status)
	}
	var hash string
	if err := db.QueryRow("SELECT password FROM admins WHERE id = 1").Scan(&hash); err != nil {
		t.Fatal(err)
	}
	if err := bcrypt.CompareHashAndPassword([]byte(hash), []byte("NewPassword1!")); err != nil {
		t.Fatal(err)
	}
	if status := resetRequest(t, db, email, "246810", "AnotherPassword1!"); status != 401 {
		t.Fatalf("replay: %d", status)
	}
}

func TestPasswordResetRevokesExistingSessions(t *testing.T) {
	db, email := resetFixture(t, time.Now().Add(time.Hour))
	if status := resetRequest(t, db, email, "246810", "NewPassword1!"); status != 200 {
		t.Fatalf("reset: %d", status)
	}
	var count int
	if err := db.QueryRow("SELECT COUNT(*) FROM sessions WHERE admin_id = 1").Scan(&count); err != nil {
		t.Fatal(err)
	}
	if count != 0 {
		t.Fatalf("old sessions remain after reset: %d", count)
	}
}

func TestPasswordResetCannotBypassOTPLockout(t *testing.T) {
	db, email := resetFixture(t, time.Now().Add(time.Hour))
	for i := 0; i < 5; i++ {
		status := resetRequest(t, db, email, "000000", "NewPassword1!")
		if i < 4 && status != 401 || i == 4 && status != 429 {
			t.Fatalf("attempt %d: %d", i, status)
		}
	}
	if status := resetRequest(t, db, email, "246810", "NewPassword1!"); status != 429 {
		t.Fatalf("locked correct OTP: %d", status)
	}
	var hash string
	db.QueryRow("SELECT password FROM admins WHERE id = 1").Scan(&hash)
	if hash != "old-hash" {
		t.Fatal("locked request modified password")
	}
}

func TestPasswordResetExpiredOTPDoesNotChangePassword(t *testing.T) {
	db, email := resetFixture(t, time.Now().Add(-time.Minute))
	if status := resetRequest(t, db, email, "246810", "NewPassword1!"); status != 401 {
		t.Fatalf("expired: %d", status)
	}
	var hash string
	db.QueryRow("SELECT password FROM admins WHERE id = 1").Scan(&hash)
	if hash != "old-hash" {
		t.Fatal("expired OTP modified password")
	}
}

func TestPasswordResetRejectsWeakPasswordWithoutConsumingOTP(t *testing.T) {
	db, email := resetFixture(t, time.Now().Add(time.Hour))
	if status := resetRequest(t, db, email, "246810", "short"); status != 400 {
		t.Fatalf("weak password: %d", status)
	}
	if status := resetRequest(t, db, email, "246810", "NewPassword1!"); status != 200 {
		t.Fatalf("retry: %d", status)
	}
}

func TestPasswordResetRollsBackOTPIfUpdateFails(t *testing.T) {
	db, email := resetFixture(t, time.Now().Add(time.Hour))
	if _, err := db.Exec("CREATE TRIGGER deny_update BEFORE UPDATE ON admins BEGIN SELECT RAISE(ABORT, 'test failure'); END"); err != nil {
		t.Fatal(err)
	}
	if status := resetRequest(t, db, email, "246810", "NewPassword1!"); status != 500 {
		t.Fatalf("failed update: %d", status)
	}
	var count int
	db.QueryRow("SELECT COUNT(*) FROM password_resets").Scan(&count)
	if count != 1 {
		t.Fatal("OTP lost after rolled back password update")
	}
}

func TestPasswordResetWithStaffBackupEmail(t *testing.T) {
	db, _ := resetFixture(t, time.Now().Add(time.Hour))
	
	// Add backup_email column to match production schema
	if _, err := db.Exec("ALTER TABLE admins ADD COLUMN backup_email TEXT DEFAULT ''"); err != nil {
		t.Fatal(err)
	}

	// Insert staff with owner's email and unique backup_email
	staffBackupEmail := "staff_praewa@example.test"
	if _, err := db.Exec("INSERT INTO admins (id, email, backup_email, password, must_change_password) VALUES (2, 'owner@example.test', ?, 'old-hash', 1)", staffBackupEmail); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec("INSERT INTO password_resets VALUES (2, ?, '999888', ?)", staffBackupEmail, time.Now().Add(time.Hour).UTC().Format(time.RFC3339)); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec("INSERT INTO sessions VALUES (2, 2, 'staff-session')"); err != nil {
		t.Fatal(err)
	}

	// Reset using staff's backup email
	if status := resetRequest(t, db, staffBackupEmail, "999888", "StaffNewPass1!"); status != 200 {
		t.Fatalf("reset with backup_email failed with status: %d", status)
	}

	// Verify only staff's password was updated
	var staffPassword string
	if err := db.QueryRow("SELECT password FROM admins WHERE id = 2").Scan(&staffPassword); err != nil {
		t.Fatal(err)
	}
	if err := bcrypt.CompareHashAndPassword([]byte(staffPassword), []byte("StaffNewPass1!")); err != nil {
		t.Fatalf("staff password not updated: %v", err)
	}

	// Verify owner password was NOT changed
	var ownerPassword string
	if err := db.QueryRow("SELECT password FROM admins WHERE id = 1").Scan(&ownerPassword); err != nil {
		t.Fatal(err)
	}
	if ownerPassword != "old-hash" {
		t.Fatalf("owner password was unexpectedly changed: %s", ownerPassword)
	}

	// Verify staff session was revoked
	var sessionCount int
	if err := db.QueryRow("SELECT COUNT(*) FROM sessions WHERE admin_id = 2").Scan(&sessionCount); err != nil || sessionCount != 0 {
		t.Fatalf("staff session was not revoked: %d", sessionCount)
	}
}
