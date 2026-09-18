package handlers

import (
	"database/sql"
	"log"
	"os"
	"path/filepath"
	"time"
)

// RunMediaCleanup removes orphaned media files in the uploads directory that are
// older than 24 hours and not referenced in the master DB or any tenant DB.
func RunMediaCleanup(masterDB *sql.DB, uploadsDir string) {
	log.Println("[Media Cleanup] Starting media cleanup job...")
	
	entries, err := os.ReadDir(uploadsDir)
	if err != nil {
		if !os.IsNotExist(err) {
			log.Printf("[Media Cleanup] Error reading uploads directory: %v", err)
		}
		return
	}

	now := time.Now()
	cutoff := now.Add(-24 * time.Hour)

	var deletedCount int
	var errorCount int
	var skippedCount int
	var keptCount int

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}

		info, err := entry.Info()
		if err != nil {
			continue
		}

		// Only check files older than 24 hours
		if info.ModTime().After(cutoff) {
			skippedCount++
			continue
		}

		fileName := entry.Name()
		referenced := false

		// 1. Check if referenced by admins in masterDB
		referenced, err = adminReferencesMedia(masterDB, fileName)
		if err != nil {
			log.Printf("[Media Cleanup] Error checking master DB for %s: %v", fileName, err)
			continue
		}

		// 2. Check tenant DBs if not referenced in masterDB
		if !referenced {
			rows, err := masterDB.Query("SELECT id FROM admins WHERE role = 'superadmin'")
			if err != nil {
				log.Printf("[Media Cleanup] Error querying superadmins: %v", err)
				continue // Skip this file if we can't query reliably
			}
			
			for rows.Next() {
				var adminID int
				if err := rows.Scan(&adminID); err != nil {
					continue
				}
				
				tenantDB, err := GetTenantDB(adminID)
				if err != nil {
					continue
				}
				
				ref, err := tenantReferencesMedia(tenantDB, fileName)
				if err != nil {
					// Assume error means we can't be sure, so don't delete
					referenced = true
					break
				}
				if ref {
					referenced = true
					break
				}
			}
			rows.Close()
		}

		// If still not referenced, delete the file
		if !referenced {
			filePath := filepath.Join(uploadsDir, fileName)
			if err := os.Remove(filePath); err != nil {
				log.Printf("[Media Cleanup] Failed to delete orphaned file %s: %v", fileName, err)
				errorCount++
			} else {
				log.Printf("[Media Cleanup] Deleted orphaned file: %s", fileName)
				deletedCount++
			}
		} else {
			keptCount++
		}
	}

	log.Printf("[Media Cleanup] Finished. Deleted: %d, Kept (Referenced): %d, Skipped (Newer than 24h): %d, Errors: %d", deletedCount, keptCount, skippedCount, errorCount)
}

func adminReferencesMedia(db *sql.DB, fileName string) (bool, error) {
	withUploadPrefix := "/uploads/" + fileName
	var allowed bool
	err := db.QueryRow(`SELECT EXISTS(
		SELECT 1 FROM admins 
		WHERE profile_image IN (?, ?)
	)`, fileName, withUploadPrefix).Scan(&allowed)
	return allowed, err
}

// StartMediaCleanupScheduler runs the media cleanup job every day at 3 AM.
func StartMediaCleanupScheduler(db *sql.DB, uploadsDir string) {
	for {
		now := time.Now()
		// Get next 3 AM (03:00:00)
		nextCleanupTime := time.Date(now.Year(), now.Month(), now.Day(), 3, 0, 0, 0, now.Location())
		if now.After(nextCleanupTime) {
			// If 3 AM today has already passed, schedule for 3 AM tomorrow
			nextCleanupTime = nextCleanupTime.Add(24 * time.Hour)
		}

		duration := time.Until(nextCleanupTime)
		log.Printf("[Media Cleanup Scheduler] Next automatic cleanup scheduled at %s (in %s)", nextCleanupTime.Format("2006-01-02 15:04:05"), duration)

		time.Sleep(duration)
		RunMediaCleanup(db, uploadsDir)
	}
}
