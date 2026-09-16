package handlers

import (
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"testing"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

func TestTenantReferencesMediaIsAccountScoped(t *testing.T) {
	db, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	InitializeTenantDatabase(db)
	if _, err := db.Exec(`INSERT INTO payments(slip_path, slip_path_array) VALUES ('slip-a.jpg', '["slip-b.jpg"]')`); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(`INSERT INTO maintenances(issue_image, slip_path) VALUES ('/uploads/problem-a.jpg,/uploads/problem-b.jpg', 'repair-slip.jpg')`); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(`INSERT INTO users(booking_slips) VALUES ('["booking.jpg"]')`); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(`INSERT INTO room_conditions(image_path) VALUES ('condition.jpg')`); err != nil {
		t.Fatal(err)
	}

	for _, fileName := range []string{"slip-a.jpg", "slip-b.jpg", "problem-a.jpg", "problem-b.jpg", "repair-slip.jpg", "booking.jpg", "condition.jpg"} {
		allowed, err := tenantReferencesMedia(db, fileName)
		if err != nil || !allowed {
			t.Fatalf("tenantReferencesMedia(%q) = %v, %v; want true, nil", fileName, allowed, err)
		}
	}
	allowed, err := tenantReferencesMedia(db, "other-tenant.jpg")
	if err != nil || allowed {
		t.Fatalf("unreferenced media = %v, %v; want false, nil", allowed, err)
	}
}

func TestSignedLineMediaURLAndHandler(t *testing.T) {
	originalSecret := jwtSecretKey
	jwtSecretKey = []byte("test-signing-secret-with-at-least-32-bytes")
	t.Cleanup(func() { jwtSecretKey = originalSecret })

	tempDir := t.TempDir()
	originalWorkingDirectory, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tempDir); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chdir(originalWorkingDirectory) })
	if err := os.Mkdir("uploads", 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join("uploads", "receipt.jpg"), []byte("private-receipt"), 0600); err != nil {
		t.Fatal(err)
	}

	now := time.Now()
	signedURL, err := SignedLineMediaURL("https://api.example.test/", "/uploads/receipt.jpg", now)
	if err != nil {
		t.Fatal(err)
	}
	parsed, err := url.Parse(signedURL)
	if err != nil {
		t.Fatal(err)
	}
	req := httptest.NewRequest(http.MethodGet, parsed.RequestURI(), nil)
	recorder := httptest.NewRecorder()
	HandleSignedLineMedia()(recorder, req)
	if recorder.Code != http.StatusOK || recorder.Body.String() != "private-receipt" {
		t.Fatalf("valid signed media response = %d %q", recorder.Code, recorder.Body.String())
	}
	wantDigest := sha256.Sum256([]byte("private-receipt"))
	if got := recorder.Header().Get("X-Content-SHA256"); got != hex.EncodeToString(wantDigest[:]) {
		t.Fatalf("media digest = %q; want %q", got, hex.EncodeToString(wantDigest[:]))
	}

	tampered := *parsed
	query := tampered.Query()
	query.Set("sig", "00")
	tampered.RawQuery = query.Encode()
	recorder = httptest.NewRecorder()
	HandleSignedLineMedia()(recorder, httptest.NewRequest(http.MethodGet, tampered.RequestURI(), nil))
	if recorder.Code != http.StatusNotFound {
		t.Fatalf("tampered signature status = %d; want 404", recorder.Code)
	}

	expiredURL, err := SignedLineMediaURL("https://api.example.test", "receipt.jpg", now.Add(-25*time.Hour))
	if err != nil {
		t.Fatal(err)
	}
	expired, _ := url.Parse(expiredURL)
	recorder = httptest.NewRecorder()
	HandleSignedLineMedia()(recorder, httptest.NewRequest(http.MethodGet, expired.RequestURI(), nil))
	if recorder.Code != http.StatusNotFound {
		t.Fatalf("expired signature status = %d; want 404", recorder.Code)
	}

	if _, err := SignedLineMediaURL("https://api.example.test", "../secret", now); err == nil {
		t.Fatal("path traversal unexpectedly produced a signed URL")
	}
}

func TestLegacyPublicUploadsAreDisabled(t *testing.T) {
	recorder := httptest.NewRecorder()
	HandleLegacyPublicUploadsDisabled(recorder, httptest.NewRequest(http.MethodGet, "/uploads/receipt.jpg", nil))
	if recorder.Code != http.StatusNotFound {
		t.Fatalf("legacy public upload status = %d; want 404", recorder.Code)
	}
}
