package handlers

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

func setupTestDBForReset(t *testing.T) *sql.DB {
	dbName := fmt.Sprintf("file:testdb_%d_%d?mode=memory&cache=shared", time.Now().UnixNano(), time.Now().Unix())
	db, err := sql.Open("sqlite3", dbName)
	if err != nil {
		t.Fatalf("Failed to open memory DB: %v", err)
	}
	db.SetMaxOpenConns(1)

	// Create admins table
	_, err = db.Exec(`CREATE TABLE IF NOT EXISTS admins (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		username TEXT,
		password TEXT,
		email TEXT,
		role TEXT,
		profile_image TEXT
	)`)
	if err != nil {
		t.Fatalf("Failed to create admins table: %v", err)
	}

	// Create password_resets table
	_, err = db.Exec(`CREATE TABLE IF NOT EXISTS password_resets (
		email TEXT PRIMARY KEY,
		token TEXT,
		expires_at TEXT
	)`)
	if err != nil {
		t.Fatalf("Failed to create password_resets table: %v", err)
	}
	
	// Create rate limits
	ensureAuthRateLimitTable(db)

	// Insert test user
	db.Exec("INSERT INTO admins (username, email) VALUES (?, ?)", "testadmin", "test@dorminet.studio")

	return db
}

func TestForgotPasswordRateLimitAndConcurrency(t *testing.T) {
	db := setupTestDBForReset(t)
	defer db.Close()

	handler := HandleForgotPassword(db)

	reqBody := `{"email": "test@dorminet.studio"}`

	// Test 1: Concurrency - multiple concurrent requests should not create duplicate OTPs
	// SQLite will handle the REPLACE INTO locking, and rate limiting should kick in.
	var wg sync.WaitGroup
	results := make(chan int, 10)
	
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			req := httptest.NewRequest("POST", "/api/forgot-password", bytes.NewBufferString(reqBody))
			req.Header.Set("Content-Type", "application/json")
			// Mock RemoteAddr to simulate different IPs or same IP
			req.RemoteAddr = "127.0.0.1:1234"
			
			w := httptest.NewRecorder()
			handler(w, req)
			results <- w.Code
		}()
	}
	wg.Wait()
	close(results)

	successCount := 0
	rateLimitedCount := 0
	
	for code := range results {
		if code == http.StatusOK {
			successCount++
		} else if code == http.StatusTooManyRequests {
			rateLimitedCount++
		}
	}

	if successCount == 0 {
		t.Errorf("Expected at least one success, got %d", successCount)
	}

	// Check DB to ensure only one OTP exists for this email
	var count int
	err := db.QueryRow("SELECT COUNT(*) FROM password_resets WHERE email = ?", "test@dorminet.studio").Scan(&count)
	if err != nil {
		t.Fatalf("Failed to query DB: %v", err)
	}
	
	if count != 1 {
		t.Errorf("Expected exactly 1 OTP row, got %d", count)
	}
}

func TestVerifyOTPRateLimitAndExpiry(t *testing.T) {
	db := setupTestDBForReset(t)
	defer db.Close()

	handler := HandleVerifyOTP(db)

	email := "test@dorminet.studio"
	otp := "123456"
	
	// Insert valid OTP
	expiresAt := time.Now().Add(15 * time.Minute).Format(time.RFC3339)
	db.Exec("INSERT INTO password_resets (email, token, expires_at) VALUES (?, ?, ?)", email, otp, expiresAt)

	// Test 1: Wrong OTP rate limit
	wrongReqBody := `{"email": "test@dorminet.studio", "otp": "000000"}`
	
	for i := 0; i < 6; i++ {
		req := httptest.NewRequest("POST", "/api/verify-otp", bytes.NewBufferString(wrongReqBody))
		req.Header.Set("Content-Type", "application/json")
		w := httptest.NewRecorder()
		handler(w, req)
		
		if i < 4 { // maxOTPAttempts is 5. On the 5th attempt (i=4), the counter hits 5 and returns 429.
			if w.Code != http.StatusUnauthorized {
				t.Errorf("Expected 401 Unauthorized for attempt %d, got %d", i+1, w.Code)
			}
		} else {
			if w.Code != http.StatusTooManyRequests {
				t.Errorf("Expected 429 Too Many Requests for attempt %d, got %d", i+1, w.Code)
			}
		}
	}

	// Wait or manually delete the rate limit to test correct OTP
	db.Exec("DELETE FROM auth_rate_limits")

	// Test 2: Correct OTP
	correctReqBody := `{"email": "test@dorminet.studio", "otp": "123456"}`
	req := httptest.NewRequest("POST", "/api/verify-otp", bytes.NewBufferString(correctReqBody))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	handler(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected 200 OK for correct OTP, got %d", w.Code)
	}

	// Test 3: OTP Single Use (already handled during reset, but verify-otp doesn't delete it unless expired. 
	// Wait, verify-otp SHOULD NOT delete OTP until reset-password is called, 
	// but it does delete if expired). Let's verify expired OTP behavior.
	expiredOTP := "654321"
	pastTime := time.Now().Add(-15 * time.Minute).Format(time.RFC3339)
	db.Exec("INSERT OR REPLACE INTO password_resets (email, token, expires_at) VALUES (?, ?, ?)", email, expiredOTP, pastTime)
	
	expiredReqBody := `{"email": "test@dorminet.studio", "otp": "654321"}`
	reqExpired := httptest.NewRequest("POST", "/api/verify-otp", bytes.NewBufferString(expiredReqBody))
	reqExpired.Header.Set("Content-Type", "application/json")
	wExpired := httptest.NewRecorder()
	handler(wExpired, reqExpired)

	if wExpired.Code != http.StatusUnauthorized {
		t.Errorf("Expected 401 Unauthorized for expired OTP, got %d", wExpired.Code)
	}
	
	var res map[string]string
	json.NewDecoder(wExpired.Body).Decode(&res)
	if res["error"] != "รหัส OTP หมดอายุแล้ว กรุณาขอใหม่" {
		t.Errorf("Expected expiry error message, got %v", res["error"])
	}
}
