package handlers

import (
	"database/sql"
	"os"
	"path/filepath"
	"testing"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

func TestRunMediaCleanup(t *testing.T) {
	// Create a temporary directory for uploads and DBs
	tempDir, err := os.MkdirTemp("", "dorminet_media_cleanup_test_*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tempDir)
	
	uploadsDir := filepath.Join(tempDir, "uploads")
	os.MkdirAll(uploadsDir, os.ModePerm)

	// Create a temporary master DB
	dbPath := filepath.Join(tempDir, "master.db")
	masterDB, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		t.Fatalf("Failed to open master DB: %v", err)
	}
	defer masterDB.Close()

	// Initialize master DB tables
	masterDB.Exec("CREATE TABLE admins (id INTEGER PRIMARY KEY, role TEXT, profile_image TEXT)")
	masterDB.Exec("INSERT INTO admins (id, role, profile_image) VALUES (1, 'superadmin', 'admin_pic.jpg')")

	// Set dorm_data directory to tempDir so GetTenantDB will create it there
	os.Chdir(tempDir) // Change working directory for this test so GetTenantDB puts things in tempDir

	// Initialize tenant DB for admin 1
	tenantDB, err := GetTenantDB(1)
	if err != nil {
		t.Fatalf("Failed to open tenant DB: %v", err)
	}
	// We don't need to manually create tables, GetTenantDB calls InitializeTenantDatabase
	
	// Add a payment with slip to tenant DB
	tenantDB.Exec("INSERT INTO payments (payment_id, slip_path) VALUES (1, 'slip_1.jpg')")
	tenantDB.Exec("INSERT INTO maintenances (id, issue_image) VALUES (1, 'maintenance_1.jpg')")

	// Helper to create a file with a specific age
	createFile := func(name string, ageHours time.Duration) {
		path := filepath.Join(uploadsDir, name)
		os.WriteFile(path, []byte("test data"), 0644)
		
		oldTime := time.Now().Add(-ageHours)
		os.Chtimes(path, oldTime, oldTime)
	}

	// 1. Referenced by admin (old) -> KEEP
	createFile("admin_pic.jpg", 48*time.Hour)
	// 2. Referenced by tenant payment (old) -> KEEP
	createFile("slip_1.jpg", 48*time.Hour)
	// 3. Referenced by tenant maintenance (old) -> KEEP
	createFile("maintenance_1.jpg", 48*time.Hour)
	// 4. Not referenced, but new (younger than 24h) -> KEEP
	createFile("recent_garbage.jpg", 2*time.Hour)
	// 5. Not referenced, old (older than 24h) -> DELETE
	createFile("old_garbage.jpg", 48*time.Hour)
	// 6. Not referenced, exactly 24h+1s old -> DELETE
	createFile("old_garbage2.jpg", 24*time.Hour+time.Second)

	// Run cleanup
	RunMediaCleanup(masterDB, uploadsDir)

	// Verify results
	assertFileExists := func(name string, expected bool) {
		path := filepath.Join(uploadsDir, name)
		_, err := os.Stat(path)
		exists := !os.IsNotExist(err)
		
		if exists != expected {
			t.Errorf("File %s existence expected: %v, got: %v", name, expected, exists)
		}
	}

	assertFileExists("admin_pic.jpg", true)
	assertFileExists("slip_1.jpg", true)
	assertFileExists("maintenance_1.jpg", true)
	assertFileExists("recent_garbage.jpg", true)
	assertFileExists("old_garbage.jpg", false)
	assertFileExists("old_garbage2.jpg", false)
}
