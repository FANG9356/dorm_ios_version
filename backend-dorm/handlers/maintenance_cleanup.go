package handlers

import (
	"database/sql"
	"log"
	"time"
)

// RunMaintenanceCleanup deletes maintenances that have status 'ปฏิเสธค่าใช้จ่าย' and are older than 24 hours.
func RunMaintenanceCleanup(masterDB *sql.DB) {
	log.Println("[Maintenance Cleanup] Starting cleanup job for rejected quotes...")

	rows, err := masterDB.Query("SELECT id FROM admins WHERE role = 'superadmin'")
	if err != nil {
		log.Printf("[Maintenance Cleanup] Error querying superadmins: %v", err)
		return
	}
	defer rows.Close()

	now := time.Now().UTC()
	cutoff := now.Add(-24 * time.Hour).Format(time.RFC3339Nano)

	var totalDeleted int
	var totalErrors int

	for rows.Next() {
		var adminID int
		if err := rows.Scan(&adminID); err != nil {
			continue
		}

		tenantDB, err := GetTenantDB(adminID)
		if err != nil {
			log.Printf("[Maintenance Cleanup] Error getting tenant DB for admin %d: %v", adminID, err)
			continue
		}

		// Delete maintenances older than cutoff
		result, err := tenantDB.Exec("DELETE FROM maintenances WHERE status = 'ปฏิเสธค่าใช้จ่าย' AND last_updated < ?", cutoff)
		if err != nil {
			log.Printf("[Maintenance Cleanup] Error deleting from tenant %d: %v", adminID, err)
			totalErrors++
			continue
		}

		deleted, _ := result.RowsAffected()
		if deleted > 0 {
			totalDeleted += int(deleted)
			// Trigger publish for this tenant so app syncs the deletion
			publishLineChanges(masterDB, tenantDB, adminID)
		}
	}

	log.Printf("[Maintenance Cleanup] Finished. Deleted: %d, Errors: %d", totalDeleted, totalErrors)
}

// StartMaintenanceCleanupScheduler runs the maintenance cleanup job every hour.
func StartMaintenanceCleanupScheduler(db *sql.DB) {
	for {
		now := time.Now()
		// Get next hour start
		nextCleanupTime := now.Truncate(time.Hour).Add(time.Hour)
		duration := time.Until(nextCleanupTime)
		
		log.Printf("[Maintenance Cleanup Scheduler] Next automatic cleanup scheduled at %s (in %s)", nextCleanupTime.Format("2006-01-02 15:04:05"), duration)

		time.Sleep(duration)
		RunMaintenanceCleanup(db)
	}
}
