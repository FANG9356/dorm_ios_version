package core

import (
	"database/sql"
	"path/filepath"
	"testing"
)

func TestInitializeDatabaseEnforcesOnePasswordResetPerEmail(t *testing.T) {
	db, err := sql.Open("sqlite3", filepath.Join(t.TempDir(), "master.db")+"?_busy_timeout=5000")
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	if _, err = db.Exec(`
		CREATE TABLE password_resets (id INTEGER PRIMARY KEY AUTOINCREMENT, email TEXT, token TEXT, expires_at DATETIME);
		INSERT INTO password_resets (email, token, expires_at) VALUES
			('PERSON@example.test', '111111', '2099-01-01T00:00:00Z'),
			('person@example.test', '222222', '2099-01-01T00:00:00Z');
	`); err != nil {
		t.Fatal(err)
	}

	InitializeDatabase(db)

	var count int
	if err = db.QueryRow("SELECT COUNT(*) FROM password_resets WHERE LOWER(email) = 'person@example.test'").Scan(&count); err != nil {
		t.Fatal(err)
	}
	if count != 1 {
		t.Fatalf("legacy duplicate count = %d, want 1", count)
	}
	if _, err = db.Exec("INSERT INTO password_resets (email, token, expires_at) VALUES ('Person@example.test', '333333', '2099-01-01T00:00:00Z')"); err == nil {
		t.Fatal("case-insensitive duplicate OTP was accepted")
	}
	if _, err = db.Exec("INSERT OR REPLACE INTO password_resets (email, token, expires_at) VALUES ('person@example.test', '444444', '2099-01-01T00:00:00Z')"); err != nil {
		t.Fatal(err)
	}
	if err = db.QueryRow("SELECT COUNT(*) FROM password_resets WHERE LOWER(email) = 'person@example.test'").Scan(&count); err != nil {
		t.Fatal(err)
	}
	if count != 1 {
		t.Fatalf("OTP count after replace = %d, want 1", count)
	}
}
