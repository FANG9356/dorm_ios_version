package handlers

import (
	"database/sql"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

// HandleTenantMedia serves payment and maintenance images only when the
// authenticated account's tenant database references the requested file.
func HandleTenantMedia(master *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
			return
		}
		fileName := strings.TrimSpace(strings.TrimPrefix(r.URL.Path, "/api/media/"))
		if fileName == "" || filepath.Base(fileName) != fileName || fileName == "." {
			http.Error(w, "Invalid media path", http.StatusBadRequest)
			return
		}
		tenantDB, err := RequestTenantDB(r, master)
		if err != nil {
			http.Error(w, "Tenant unavailable", http.StatusForbidden)
			return
		}
		allowed, err := tenantReferencesMedia(tenantDB, fileName)
		if err != nil {
			http.Error(w, "Media lookup failed", http.StatusInternalServerError)
			return
		}
		if !allowed {
			http.Error(w, "Media not found", http.StatusNotFound)
			return
		}
		file, err := os.Open(filepath.Join("uploads", fileName))
		if err != nil {
			http.Error(w, "Media not found", http.StatusNotFound)
			return
		}
		defer file.Close()
		info, err := file.Stat()
		if err != nil || !info.Mode().IsRegular() {
			http.Error(w, "Media not found", http.StatusNotFound)
			return
		}
		w.Header().Set("Cache-Control", "private, max-age=300")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		http.ServeContent(w, r, fileName, info.ModTime(), file)
	}
}

func tenantReferencesMedia(db *sql.DB, fileName string) (bool, error) {
	withUploadPrefix := "/uploads/" + fileName
	var allowed bool
	err := db.QueryRow(`SELECT EXISTS(
		SELECT 1 FROM payments p
		WHERE p.slip_path IN (?, ?)
		   OR EXISTS (SELECT 1 FROM json_each(CASE WHEN json_valid(p.slip_path_array) THEN p.slip_path_array ELSE '[]' END)
		              WHERE value IN (?, ?))
		UNION ALL
		SELECT 1 FROM maintenances m
		WHERE m.slip_path IN (?, ?)
		   OR instr(',' || REPLACE(COALESCE(m.issue_image, ''), '/uploads/', '') || ',', ',' || ? || ',') > 0
		UNION ALL
		SELECT 1 FROM users u
		WHERE EXISTS (SELECT 1 FROM json_each(CASE WHEN json_valid(u.booking_slips) THEN u.booking_slips ELSE '[]' END)
		              WHERE value IN (?, ?))
	)`, fileName, withUploadPrefix, fileName, withUploadPrefix,
		fileName, withUploadPrefix, fileName, fileName, withUploadPrefix).Scan(&allowed)
	return allowed, err
}
