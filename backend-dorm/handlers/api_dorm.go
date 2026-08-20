package handlers

import (
	"database/sql"
)

// SetupDormRoutes initializes all HTTP routes for the dorm management backend.
func SetupDormRoutes(db *sql.DB) {
	SetupDashboardRoutes(db)
	SetupLogRoutes(db)
	SetupPaymentRoutes(db)
	SetupRoomRoutes(db)
	SetupUserRoutes(db)
	SetupMaintenanceRoutes(db) 
	SetupSyncRoutes(db)
}
 