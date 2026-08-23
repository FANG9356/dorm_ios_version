package handlers

import (
	"database/sql"
	"dorm_os/models"
	"dorm_os/utils"
	"encoding/json"
	"net/http"
	"time"
)

func SetupDashboardRoutes(db *sql.DB) {
	http.HandleFunc("/api/dashboard-stats", func(w http.ResponseWriter, r *http.Request) {
		db := getTenantDB(r, db)
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method == "GET" {
			var stats models.DashboardStats
			currentMonth := time.Now().Format("2006-01")
			db.QueryRow("SELECT COUNT(*) FROM users WHERE status = 'กำลังพักอาศัย'").Scan(&stats.TotalResidents)
			db.QueryRow("SELECT COUNT(*) FROM rooms r LEFT JOIN users u ON r.room_number = u.room_number AND u.status = 'กำลังพักอาศัย' WHERE u.user_id IS NULL").Scan(&stats.EmptyRooms)
			db.QueryRow("SELECT COALESCE(SUM(amount), 0) FROM payments WHERE payment_date LIKE ? AND payment_status = 'paid'", currentMonth+"%").Scan(&stats.IncomeThisMonth)
			db.QueryRow("SELECT COALESCE(SUM(amount), 0) FROM payments WHERE month = ? AND payment_status = 'paid'", currentMonth).Scan(&stats.BillingCycleIncome)
			db.QueryRow("SELECT COUNT(*) FROM payments WHERE month = ? AND payment_status IN ('pending', 'checking')", currentMonth).Scan(&stats.PendingBills)
			json.NewEncoder(w).Encode(stats)
		}
	})
}
