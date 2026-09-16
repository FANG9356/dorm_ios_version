package handlers

import (
	"database/sql"
	"testing"

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

	for _, fileName := range []string{"slip-a.jpg", "slip-b.jpg", "problem-a.jpg", "problem-b.jpg", "repair-slip.jpg", "booking.jpg"} {
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
