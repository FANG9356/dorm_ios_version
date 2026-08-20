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
		db = getTenantDB(r, db)
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method == "GET" {
			rows, err := db.Query("SELECT log_id, action_type, details, timestamp FROM system_logs ORDER BY log_id DESC LIMIT 100")
			if err != nil {
				http.Error(w, "Database Error", http.StatusInternalServerError)
				return
			}
			defer rows.Close()
			logs := []models.SystemLog{}
			for rows.Next() {
				var l models.SystemLog
				rows.Scan(&l.ID, &l.Action, &l.Details, &l.Timestamp)
				logs = append(logs, l)
			}
			json.NewEncoder(w).Encode(logs)
		}
		if r.Method == "POST" {
			var l models.SystemLog
			if err := json.NewDecoder(r.Body).Decode(&l); err != nil {
				http.Error(w, "Invalid input", http.StatusBadRequest)
				return
			}
			if _, err := db.Exec("INSERT INTO system_logs (action_type, details, timestamp) VALUES (?, ?, ?)", l.Action, l.Details, time.Now().Format("2006-01-02 15:04:05")); err != nil {
				http.Error(w, "Database error", http.StatusInternalServerError)
				return
			}
			// Log Rotation: Keep only the latest 1000 logs to prevent database bloat
			db.Exec("DELETE FROM system_logs WHERE log_id NOT IN (SELECT log_id FROM system_logs ORDER BY log_id DESC LIMIT 1000)")
			
			w.WriteHeader(http.StatusCreated)
		}
	})
}
