package handlers

import (
	"database/sql"
	"path/filepath"
	"sync"
	"testing"
	"time"
)

func openRateLimitTestDB(t *testing.T, path string) *sql.DB {
	t.Helper()
	db, err := sql.Open("sqlite3", path+"?_busy_timeout=5000&_journal_mode=WAL")
	if err != nil {
		t.Fatal(err)
	}
	db.SetMaxOpenConns(10)
	return db
}

func TestAuthRateLimitPersistsAcrossConnectionsAndExpires(t *testing.T) {
	path := filepath.Join(t.TempDir(), "rate-limit.db")
	first := openRateLimitTestDB(t, path)
	for attempt := 1; attempt <= maxOTPAttempts; attempt++ {
		got, err := recordAuthRateLimit(first, "otp_failure", "person@example.test", time.Hour)
		if err != nil {
			t.Fatal(err)
		}
		if got != attempt {
			t.Fatalf("attempt = %d, want %d", got, attempt)
		}
	}
	if err := first.Close(); err != nil {
		t.Fatal(err)
	}

	second := openRateLimitTestDB(t, path)
	defer second.Close()
	locked, err := authRateLimitLocked(second, "otp_failure", "person@example.test", maxOTPAttempts)
	if err != nil {
		t.Fatal(err)
	}
	if !locked {
		t.Fatal("rate limit did not survive reopening the database")
	}
	if _, err = second.Exec("UPDATE auth_rate_limits SET expires_at = ?", time.Now().UTC().Add(-time.Minute).Format(time.RFC3339Nano)); err != nil {
		t.Fatal(err)
	}
	attempts, err := recordAuthRateLimit(second, "otp_failure", "person@example.test", time.Hour)
	if err != nil {
		t.Fatal(err)
	}
	if attempts != 1 {
		t.Fatalf("attempts after expiry = %d, want 1", attempts)
	}
}

func TestAuthRateLimitConcurrentUpdatesAreNotLost(t *testing.T) {
	db := openRateLimitTestDB(t, filepath.Join(t.TempDir(), "rate-limit.db"))
	defer db.Close()
	if err := ensureAuthRateLimitTable(db); err != nil {
		t.Fatal(err)
	}

	const workers = 20
	var wait sync.WaitGroup
	errors := make(chan error, workers)
	for i := 0; i < workers; i++ {
		wait.Add(1)
		go func() {
			defer wait.Done()
			_, err := recordAuthRateLimit(db, "otp_request", "person@example.test", time.Hour)
			errors <- err
		}()
	}
	wait.Wait()
	close(errors)
	for err := range errors {
		if err != nil {
			t.Fatal(err)
		}
	}

	var attempts int
	if err := db.QueryRow("SELECT attempts FROM auth_rate_limits WHERE scope = 'otp_request' AND identifier = 'person@example.test'").Scan(&attempts); err != nil {
		t.Fatal(err)
	}
	if attempts != workers {
		t.Fatalf("attempts = %d, want %d", attempts, workers)
	}
}
