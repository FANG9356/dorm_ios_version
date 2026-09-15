package handlers

import (
	"database/sql"
	"fmt"
	"net/http"
)

// getTenantDB extracts the admin_id from the request context and returns
// the corresponding tenant database connection. If no admin_id is found
// or an error occurs, it returns the fallback (master) database.
func getTenantDB(r *http.Request, fallback *sql.DB) *sql.DB {
	tenant, err := RequestTenantDB(r, fallback)
	if err == nil {
		return tenant
	}
	return fallback
}

// RequestTenantDB resolves the authenticated admin to the owner database for
// that account. Security-sensitive callers use this error-returning variant so
// a lookup failure can never fall back to the master database.
func RequestTenantDB(r *http.Request, master *sql.DB) (*sql.DB, error) {
	adminID := r.Context().Value("admin_id")
	if adminID != nil {
		if id, ok := adminID.(int); ok {
			var superadminID int
			// ค้นหา ID ของ superadmin ที่มีอีเมลหลักตรงกับ user คนนี้
			err := master.QueryRow(`
				SELECT s.id 
				FROM admins a
				JOIN admins s ON a.email = s.email 
				WHERE a.id = ? AND s.role = 'superadmin' 
				LIMIT 1
			`, id).Scan(&superadminID)

			if err != nil || superadminID <= 0 {
				return nil, fmt.Errorf("resolve tenant owner: %w", err)
			}

			return GetTenantDB(superadminID)
		}
	}
	return nil, fmt.Errorf("missing authenticated admin id")
}
