package handlers

import (
	"database/sql"
	"dorm_os/models"
	"dorm_os/utils"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

func SetupMaintenanceRoutes(db *sql.DB) {
	http.HandleFunc("/api/maintenances", func(w http.ResponseWriter, r *http.Request) {
		db := getTenantDB(r, db)
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method == "GET" {
			rows, err := db.Query("SELECT id, room_number, issue, status, cost, reported_at, COALESCE(resolved_at, ''), COALESCE(payment_method, ''), COALESCE(slip_path, ''), COALESCE(issue_image, '') FROM maintenances ORDER BY CASE status WHEN 'รอดำเนินการ' THEN 1 WHEN 'กำลังซ่อม' THEN 2 ELSE 3 END, id DESC")
			if err != nil {
				http.Error(w, "Database error", http.StatusInternalServerError)
				return
			}
			defer rows.Close()
			var list []models.Maintenance
			for rows.Next() {
				var m models.Maintenance
				rows.Scan(&m.ID, &m.RoomNumber, &m.Issue, &m.Status, &m.Cost, &m.ReportedAt, &m.ResolvedAt, &m.PaymentMethod, &m.SlipPath, &m.IssueImage)
				list = append(list, m)
			}
			json.NewEncoder(w).Encode(list)
		}
		if r.Method == "POST" {
			var m models.Maintenance
			if err := json.NewDecoder(r.Body).Decode(&m); err != nil {
				http.Error(w, "Invalid input", http.StatusBadRequest)
				return
			}
			if _, err := db.Exec("INSERT INTO maintenances (room_number, issue, reported_at) VALUES (?, ?, ?)", m.RoomNumber, m.Issue, time.Now().Format("2006-01-02 15:04:05")); err != nil {
				http.Error(w, "Database error", http.StatusInternalServerError)
				return
			}
			db.Exec("INSERT INTO system_logs (action_type, details, timestamp) VALUES ('Create', 'รับแจ้งซ่อมห้อง ' || ? || ' (' || ? || ')', ?)", m.RoomNumber, m.Issue, time.Now().Format("2006-01-02 15:04:05"))

			// Push to all admins
			go func() {
				rows, _ := db.Query("SELECT line_user_id FROM admins WHERE line_user_id != ''")
				if rows != nil {
					defer rows.Close()
					for rows.Next() {
						var adminLineID string
						rows.Scan(&adminLineID)
						msg := fmt.Sprintf("🛠️ แจ้งซ่อมใหม่!\nห้อง: %s\nปัญหา: %s", m.RoomNumber, m.Issue)
						PushLineMessage(adminLineID, msg)
					}
				}
			}()

			w.WriteHeader(http.StatusCreated)
		}
		if r.Method == "PUT" {
			err := r.ParseMultipartForm(10 << 20)
			if err != nil {
				var m models.Maintenance
				if err := json.NewDecoder(r.Body).Decode(&m); err != nil {
					http.Error(w, "Invalid input", http.StatusBadRequest)
					return
				}
				var prevCost float64
				var prevStatus string
				db.QueryRow("SELECT cost, status FROM maintenances WHERE id=?", m.ID).Scan(&prevCost, &prevStatus)

				if m.Status == "เสร็จสิ้น" {
					if _, err := db.Exec("UPDATE maintenances SET status=?, cost=?, resolved_at=? WHERE id=?", m.Status, m.Cost, time.Now().Format("2006-01-02 15:04:05"), m.ID); err != nil {
						http.Error(w, "Database error", http.StatusInternalServerError)
						return
					}
				} else {
					if _, err := db.Exec("UPDATE maintenances SET status=?, cost=? WHERE id=?", m.Status, m.Cost, m.ID); err != nil {
						http.Error(w, "Database error", http.StatusInternalServerError)
						return
					}
				}

				if m.Status == "เสร็จสิ้น" && prevStatus != "เสร็จสิ้น" && prevStatus != "รอตรวจสอบชำระเงิน" {
					go func() {
						// แจ้งเตือนสถานะซ่อมเสร็จก่อน
						notifyMaintenanceStatus(db, fmt.Sprintf("%v", m.ID), m.Status)

						// ตามด้วยส่งบิล
						var roomNumber, issue, lineUserID string
						db.QueryRow("SELECT m.room_number, m.issue, u.line_user_id FROM maintenances m LEFT JOIN users u ON m.room_number = u.room_number WHERE m.id = ?", m.ID).Scan(&roomNumber, &issue, &lineUserID)
						if lineUserID != "" {
							PushMaintenanceBillFlexMessage(lineUserID, fmt.Sprintf("%v", m.ID), roomNumber, issue, m.Cost)
						}
					}()
				} else {
					go notifyMaintenanceStatus(db, fmt.Sprintf("%v", m.ID), m.Status)
				}
				w.WriteHeader(http.StatusOK)
			} else {
				id := r.FormValue("id")
				status := r.FormValue("status")
				costStr := r.FormValue("cost")
				paymentMethod := r.FormValue("payment_method")
				cost, _ := strconv.ParseFloat(costStr, 64)

				slipPath := ""
				file, header, err := r.FormFile("slip")
				if err == nil {
					defer file.Close()
					if utils.IsAllowedUploadExt(filepath.Base(header.Filename)) {
						ext := filepath.Ext(header.Filename)
						fileName := fmt.Sprintf("maint_%d_%d%s", time.Now().Unix(), time.Now().Nanosecond(), ext)
						if err := utils.SaveUploadedFile(file, filepath.Join("uploads", fileName)); err == nil {
							slipPath = fileName
						}
					}
				}

				var prevCost float64
				var prevStatus string
				db.QueryRow("SELECT cost, status FROM maintenances WHERE id=?", id).Scan(&prevCost, &prevStatus)

				if status == "เสร็จสิ้น" {
					if slipPath != "" {
						_, err = db.Exec("UPDATE maintenances SET status=?, cost=?, resolved_at=?, payment_method=?, slip_path=? WHERE id=?", status, cost, time.Now().Format("2006-01-02 15:04:05"), paymentMethod, slipPath, id)
					} else {
						_, err = db.Exec("UPDATE maintenances SET status=?, cost=?, resolved_at=?, payment_method=? WHERE id=?", status, cost, time.Now().Format("2006-01-02 15:04:05"), paymentMethod, id)
					}
				} else {
					_, err = db.Exec("UPDATE maintenances SET status=?, cost=? WHERE id=?", status, cost, id)
				}
				if err != nil {
					http.Error(w, "Database error", http.StatusInternalServerError)
					return
				}

				if status == "เสร็จสิ้น" && prevStatus != "เสร็จสิ้น" && prevStatus != "รอตรวจสอบชำระเงิน" {
					go func() {
						// แจ้งเตือนสถานะซ่อมเสร็จก่อน
						notifyMaintenanceStatus(db, fmt.Sprintf("%v", id), status)

						// ตามด้วยส่งบิล
						var roomNumber, issue, lineUserID string
						db.QueryRow("SELECT m.room_number, m.issue, u.line_user_id FROM maintenances m LEFT JOIN users u ON m.room_number = u.room_number WHERE m.id = ?", id).Scan(&roomNumber, &issue, &lineUserID)
						if lineUserID != "" {
							PushMaintenanceBillFlexMessage(lineUserID, fmt.Sprintf("%v", id), roomNumber, issue, cost)
						}
					}()
				} else if prevStatus == "รอตรวจสอบชำระเงิน" && status == "เสร็จสิ้น" && paymentMethod == "โอนเงิน" {
					go func() {
						var roomNumber, lineUserID string
						db.QueryRow("SELECT m.room_number, COALESCE(u.line_user_id, '') FROM maintenances m LEFT JOIN users u ON m.room_number = u.room_number WHERE m.id=?", id).Scan(&roomNumber, &lineUserID)
						if lineUserID != "" {
							dateStr := time.Now().Format("02/01/2006 15:04")
							var dbSlipPath string
							db.QueryRow("SELECT COALESCE(slip_path, '') FROM maintenances WHERE id=?", id).Scan(&dbSlipPath)
							imageURL := ""
							if dbSlipPath != "" {
								baseURL := GetBaseURLFromWebhook()
								if baseURL == "" {
									baseURL = "https://" + r.Host
								}
								imageURL = fmt.Sprintf("%s/uploads/%s", baseURL, dbSlipPath)
							}
							PushReceiptFlexMessage(lineUserID, fmt.Sprintf("%v", id), roomNumber, dateStr, cost, imageURL)
						}
					}()
				} else {
					go notifyMaintenanceStatus(db, id, status)
				}

				w.WriteHeader(http.StatusOK)
			}
		}
		if r.Method == "DELETE" {
			id := r.URL.Query().Get("id")
			filename := r.URL.Query().Get("filename")

			// ดึงชื่อไฟล์จาก DB เพื่อป้องกัน IDOR และ Path Traversal
			var expectedFilename string
			db.QueryRow("SELECT COALESCE(slip_path, '') FROM maintenances WHERE id = ?", id).Scan(&expectedFilename)

			if filename != "" {
				// ลบเฉพาะรูปภาพ
				if expectedFilename != "" && expectedFilename == filename {
					os.Remove(filepath.Join("uploads", filepath.Base(expectedFilename)))
					if _, err := db.Exec("UPDATE maintenances SET slip_path = '' WHERE id = ?", id); err != nil {
						http.Error(w, "Database error", http.StatusInternalServerError)
						return
					}
				} else {
					http.Error(w, "Filename mismatch", http.StatusBadRequest)
					return
				}
			} else {
				// ลบรายการแจ้งซ่อมทั้งหมด (ต้องลบไฟล์ภาพทิ้งด้วยถ้ามี)
				if expectedFilename != "" {
					os.Remove(filepath.Join("uploads", filepath.Base(expectedFilename)))
				}
				var issueImage string
				db.QueryRow("SELECT COALESCE(issue_image, '') FROM maintenances WHERE id = ?", id).Scan(&issueImage)
				if issueImage != "" {
					images := strings.Split(issueImage, ",")
					for _, img := range images {
						os.Remove(filepath.Join("uploads", filepath.Base(img)))
					}
				}
				if _, err := db.Exec("DELETE FROM maintenances WHERE id = ?", id); err != nil {
					http.Error(w, "Database error", http.StatusInternalServerError)
					return
				}
			}
			w.WriteHeader(http.StatusOK)
		}
	})
}

// [เพิ่มใหม่] ฟังก์ชันสำหรับแจ้งเตือนลูกบ้านเมื่อสถานะแจ้งซ่อมเปลี่ยน
func notifyMaintenanceStatus(db *sql.DB, maintID string, status string) {
	if status == "รอดำเนินการ" {
		return // ไม่ต้องแจ้งถ้าเพิ่งกลับมารอดำเนินการ (หรือแจ้งก็ได้ แต่ปกติจะแจ้งแค่ตอนกำลังทำกับเสร็จ)
	}
	var roomNumber, issue string
	err := db.QueryRow("SELECT room_number, issue FROM maintenances WHERE id = ?", maintID).Scan(&roomNumber, &issue)
	if err != nil {
		return
	}

	var lineUserID string
	err = db.QueryRow("SELECT line_user_id FROM users WHERE room_number = ? AND status = 'กำลังพักอาศัย' AND line_user_id IS NOT NULL AND line_user_id != ''", roomNumber).Scan(&lineUserID)
	if err == nil && lineUserID != "" {
		PushMaintenanceStatusFlexMessage(lineUserID, roomNumber, issue, status)
	}
}
