package handlers

import (
	"database/sql"
	"dorm_os/models"
	"dorm_os/utils"
	"encoding/json"
	"net/http"
	"time"
)

func SetupLogRoutes(db *sql.DB) {
	http.HandleFunc("/api/logs", func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if !IsServicesRole(r) {
			http.Error(w, "Forbidden", http.StatusForbidden)
			return
		}
		tenantDB, err := RequestTenantDB(r, db)
		if err != nil {
			http.Error(w, "Tenant unavailable", http.StatusForbidden)
			return
		}
		if r.Method == "GET" {
			rows, err := tenantDB.Query("SELECT log_id, action_type, details, timestamp FROM system_logs ORDER BY log_id DESC LIMIT 100")
			if err != nil {
				http.Error(w, "Database Error", http.StatusInternalServerError)
				return
			}
			defer rows.Close()
			logs := []models.SystemLog{}
			for rows.Next() {
				var l models.SystemLog
				if err := rows.Scan(&l.ID, &l.Action, &l.Details, &l.Timestamp); err == nil {
					logs = append(logs, l)
				}
			}
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(logs)
			return
		}
		if r.Method == "POST" {
			r.Body = http.MaxBytesReader(w, r.Body, 8192)
			var l models.SystemLog
			if err := json.NewDecoder(r.Body).Decode(&l); err != nil {
				http.Error(w, "Invalid input", http.StatusBadRequest)
				return
			}
			if len(l.Action) == 0 || len(l.Action) > 120 || len(l.Details) > 2000 {
				http.Error(w, "Invalid log payload", http.StatusBadRequest)
				return
			}
			if _, err := tenantDB.Exec("INSERT INTO system_logs (action_type, details, timestamp) VALUES (?, ?, ?)", l.Action, l.Details, time.Now().Format("2006-01-02 15:04:05")); err != nil {
				http.Error(w, "Database error", http.StatusInternalServerError)
				return
			}
			w.WriteHeader(http.StatusCreated)
			return
		}
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
	})
}
