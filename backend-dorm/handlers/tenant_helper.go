package handlers

import (
	"database/sql"
	"net/http"
)

// getTenantDB extracts the admin_id from the request context and returns
// the corresponding tenant database connection. If no admin_id is found
// or an error occurs, it returns the fallback (master) database.
func getTenantDB(r *http.Request, fallback *sql.DB) *sql.DB {
	adminID := r.Context().Value("admin_id")
	if adminID != nil {
		if id, ok := adminID.(int); ok {
			var superadminID int
			// ค้นหา ID ของ superadmin ที่มีอีเมลหลักตรงกับ user คนนี้
			err := fallback.QueryRow(`
				SELECT s.id 
				FROM admins a
				JOIN admins s ON a.email = s.email 
				WHERE a.id = ? AND s.role = 'superadmin' 
				LIMIT 1
			`, id).Scan(&superadminID)
			
			tenantIDToUse := id // Default to their own ID if something goes wrong
			if err == nil && superadminID > 0 {
				tenantIDToUse = superadminID
			}
			
			tDB, err := GetTenantDB(tenantIDToUse)
			if err == nil {
				return tDB
			}
		}
	}
	return fallback
}
