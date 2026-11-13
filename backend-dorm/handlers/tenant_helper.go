package handlers

import (
	"database/sql"
	"fmt"
	"net/http"
	"strings"
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
			var role, email string
			err := master.QueryRow(`
				SELECT COALESCE(role, 'services'), COALESCE(email, '')
				FROM admins
				WHERE id = ?
			`, id).Scan(&role, &email)
			if err != nil {
				return nil, fmt.Errorf("resolve admin: %w", err)
			}

			if role == "superadmin" {
				return GetTenantDB(id)
			}

			var superadminID int
			email = strings.ToLower(strings.TrimSpace(email))
			if email != "" {
				err = master.QueryRow(`
					SELECT id 
					FROM admins 
					WHERE LOWER(email) = ? AND role = 'superadmin' 
					ORDER BY id ASC
					LIMIT 1
				`, email).Scan(&superadminID)
			}

			if err != nil || superadminID <= 0 {
				// Fallback to primary owner (superadmin) in single-dorm deployment
				var defaultOwnerID int
				if fallbackErr := master.QueryRow(`
					SELECT id FROM admins WHERE role = 'superadmin' ORDER BY id ASC LIMIT 1
				`).Scan(&defaultOwnerID); fallbackErr == nil && defaultOwnerID > 0 {
					superadminID = defaultOwnerID
				} else {
					return nil, fmt.Errorf("resolve tenant owner: %w", err)
				}
			}

			return GetTenantDB(superadminID)
		}
	}
	return nil, fmt.Errorf("missing authenticated admin id")
}
