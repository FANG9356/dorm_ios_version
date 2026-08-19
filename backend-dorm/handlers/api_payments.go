package handlers

import (
	"database/sql"
	"dorm_os/models"
	"dorm_os/utils"
	"encoding/json"
	"fmt"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

func isNegative(s string) bool {
	if s == "" {
		return false
	}
	v, err := strconv.ParseFloat(s, 64)
	if err != nil {
		return false
	}
	return v < 0
}

func SetupPaymentRoutes(db *sql.DB) {
	http.HandleFunc("/api/payments", func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method == "POST" {
			if isNegative(r.FormValue("amount")) || isNegative(r.FormValue("rent_fee")) || isNegative(r.FormValue("water_fee")) || isNegative(r.FormValue("electric_fee")) || isNegative(r.FormValue("common_fee")) || isNegative(r.FormValue("late_fee")) || isNegative(r.FormValue("appliance_fee")) || isNegative(r.FormValue("paid_amount")) {
				http.Error(w, "จำนวนเงินห้ามติดลบ", http.StatusBadRequest)
				return
			}
			err := r.ParseMultipartForm(10 << 20) // จำกัด 10MB
			if err != nil && err != http.ErrNotMultipart {
				http.Error(w, "ไฟล์ขนาดใหญ่เกินไป หรือข้อมูลไม่ถูกต้อง", http.StatusBadRequest)
				return
			}
			userID := r.FormValue("user_id")
			safeUserID := filepath.Base(filepath.Clean(userID))
			if safeUserID == "." || safeUserID == "/" || safeUserID == "\\" {
				safeUserID = "unknown"
			}
			month := r.FormValue("month")
			installmentPhase := r.FormValue("installment_phase")

			var existingID int
			var existingSlipArrayStr string
			var queryErr error
			if installmentPhase != "" && installmentPhase != "0" {
				queryErr = db.QueryRow("SELECT payment_id, COALESCE(slip_path_array,'[]') FROM payments WHERE user_id = ? AND month = ? AND installment_phase = ?", userID, month, installmentPhase).Scan(&existingID, &existingSlipArrayStr)
			} else {
				queryErr = db.QueryRow("SELECT payment_id, COALESCE(slip_path_array,'[]') FROM payments WHERE user_id = ? AND month = ? AND (installment_phase IS NULL OR installment_phase = 0 OR installment_phase = '')", userID, month).Scan(&existingID, &existingSlipArrayStr)
			}

			if queryErr == nil {
				// Record exists! Let's append the slips to it and update.
				var savedFiles []string
				if existingSlipArrayStr != "" && existingSlipArrayStr != "[]" {
					json.Unmarshal([]byte(existingSlipArrayStr), &savedFiles)
				}

				var firstFileName string
				if len(savedFiles) > 0 {
					firstFileName = savedFiles[0]
				}

				var files []*multipart.FileHeader
				if r.MultipartForm != nil && r.MultipartForm.File != nil {
					files = r.MultipartForm.File["slips"]
					if len(files) == 0 {
						files = r.MultipartForm.File["slip"]
					}
				}

				for i, fileHeader := range files {
					if !utils.IsAllowedUploadExt(filepath.Base(fileHeader.Filename)) {
						continue
					}
					file, err := fileHeader.Open()
					if err != nil {
						continue
					}
					fn := fmt.Sprintf("%d_%d_%s_%s", time.Now().UnixNano(), i, safeUserID, filepath.Base(fileHeader.Filename))
					if err := utils.SaveUploadedFile(file, filepath.Join("./uploads", fn)); err == nil {
						savedFiles = append(savedFiles, fn)
						if firstFileName == "" {
							firstFileName = fn
						}
					}
					file.Close()
				}

				slipPathArrayBytes, _ := json.Marshal(savedFiles)
				slipPathArrayStr := string(slipPathArrayBytes)

				amountVal := r.FormValue("amount")
				if amountVal == "" || amountVal == "0" {
					_, err = db.Exec("UPDATE payments SET slip_path=?, slip_path_array=?, payment_status='paid' WHERE payment_id=?", firstFileName, slipPathArrayStr, existingID)
				} else {
					_, err = db.Exec("UPDATE payments SET amount=?, slip_path=?, slip_path_array=?, payment_status='paid' WHERE payment_id=?", amountVal, firstFileName, slipPathArrayStr, existingID)
				}
				
				if err != nil {
					http.Error(w, "เกิดข้อผิดพลาดในการอัปเดตข้อมูล", http.StatusInternalServerError)
					return
				}
				w.WriteHeader(http.StatusOK)
				return
			}

			// รองรับการอัปโหลดไฟล์พร้อมกันหลายไฟล์จากคีย์ "slips" หรือ "slip"
			var savedFiles []string
			var firstFileName string

			var files []*multipart.FileHeader
			if r.MultipartForm != nil && r.MultipartForm.File != nil {
				files = r.MultipartForm.File["slips"]
				if len(files) == 0 {
					files = r.MultipartForm.File["slip"]
				}
			}

			for i, fileHeader := range files {
				if !utils.IsAllowedUploadExt(filepath.Base(fileHeader.Filename)) {
					continue
				}
				file, err := fileHeader.Open()
				if err != nil {
					continue
				}
				fn := fmt.Sprintf("%d_%d_%s_%s", time.Now().UnixNano(), i, safeUserID, filepath.Base(fileHeader.Filename))
				if err := utils.SaveUploadedFile(file, filepath.Join("./uploads", fn)); err == nil {
					savedFiles = append(savedFiles, fn)
					if firstFileName == "" {
						firstFileName = fn
					}
				}
				file.Close()
			}

			slipPathArrayBytes, _ := json.Marshal(savedFiles)
			slipPathArrayStr := string(slipPathArrayBytes)
			if len(savedFiles) == 0 {
				slipPathArrayStr = "[]"
			}

			// บันทึกข้อมูลและสลิปทั้งหมด
			_, err = db.Exec(`INSERT INTO payments 
				(user_id, room_number, rent_fee, water_fee, electric_fee, common_fee, late_fee, appliance_fee, amount, month, payment_date, method, slip_path, water_meter_prev, water_meter_curr, electric_meter_prev, electric_meter_curr, payment_plan, installment_phase, due_date, payment_status, slip_path_array, paid_amount) 
				VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
				userID, r.FormValue("room_number"), r.FormValue("rent_fee"), r.FormValue("water_fee"), r.FormValue("electric_fee"), r.FormValue("common_fee"), r.FormValue("late_fee"), r.FormValue("appliance_fee"), r.FormValue("amount"), month, r.FormValue("date"), r.FormValue("method"), firstFileName, r.FormValue("water_meter_prev"), r.FormValue("water_meter_curr"), r.FormValue("electric_meter_prev"), r.FormValue("electric_meter_curr"), r.FormValue("payment_plan"), r.FormValue("installment_phase"), r.FormValue("due_date"), r.FormValue("payment_status"), slipPathArrayStr, r.FormValue("paid_amount"))
			
			if err != nil {
				if strings.Contains(err.Error(), "UNIQUE constraint failed") {
					http.Error(w, "มีบิลของเดือนนี้สำหรับผู้เช่าท่านนี้อยู่แล้ว ไม่สามารถสร้างซ้ำได้", http.StatusConflict)
				} else {
					http.Error(w, "เกิดข้อผิดพลาดในการสร้างบิล", http.StatusInternalServerError)
				}
				return
			}

			w.WriteHeader(http.StatusCreated)
			return
		}
		if r.Method == "GET" {
			// ดึงเลขมิเตอร์กลับไปแสดงผล
			rows, err := db.Query("SELECT payment_id, user_id, room_number, COALESCE(CAST(NULLIF(rent_fee,'') AS REAL),0), COALESCE(CAST(NULLIF(water_fee,'') AS REAL),0), COALESCE(CAST(NULLIF(electric_fee,'') AS REAL),0), COALESCE(CAST(NULLIF(common_fee,'') AS REAL),0), COALESCE(CAST(NULLIF(late_fee,'') AS REAL),0), COALESCE(CAST(NULLIF(appliance_fee,'') AS REAL),0), COALESCE(CAST(NULLIF(amount,'') AS REAL),0), month, payment_date, method, slip_path, COALESCE(CAST(NULLIF(water_meter_prev,'') AS REAL),0), COALESCE(CAST(NULLIF(water_meter_curr,'') AS REAL),0), COALESCE(CAST(NULLIF(electric_meter_prev,'') AS REAL),0), COALESCE(CAST(NULLIF(electric_meter_curr,'') AS REAL),0), COALESCE(payment_plan,''), CAST(COALESCE(NULLIF(installment_phase,''),0) AS INTEGER), COALESCE(due_date,''), COALESCE(payment_status,'pending'), COALESCE(slip_path_array,''), COALESCE(CAST(NULLIF(paid_amount,'') AS REAL),0) FROM payments ORDER BY payment_id DESC")
			if err != nil {
				http.Error(w, "Database Error", http.StatusInternalServerError)
				return
			}
			defer rows.Close()
			payments := []models.Payment{}
			for rows.Next() {
				var p models.Payment
				var slipPathArray string
				err := rows.Scan(&p.ID, &p.UserID, &p.RoomNumber, &p.RentFee, &p.WaterFee, &p.ElectricFee, &p.CommonFee, &p.LateFee, &p.ApplianceFee, &p.Amount, &p.Month, &p.PaymentDate, &p.Method, &p.SlipPath, &p.WaterMeterPrev, &p.WaterMeterCurr, &p.ElectricMeterPrev, &p.ElectricMeterCurr, &p.PaymentPlan, &p.InstallmentPhase, &p.DueDate, &p.PaymentStatus, &slipPathArray, &p.PaidAmount)
				if err != nil {
					fmt.Println("Scan error:", err)
				}
				if slipPathArray != "" && slipPathArray != "[]" {
					err = json.Unmarshal([]byte(slipPathArray), &p.SlipPathArray)
					if err != nil {
						fmt.Println("Unmarshal error:", err)
					}
				}
				payments = append(payments, p)
			}
			json.NewEncoder(w).Encode(payments)
		}
		if r.Method == "PUT" {
			if isNegative(r.FormValue("amount")) || isNegative(r.FormValue("rent_fee")) || isNegative(r.FormValue("water_fee")) || isNegative(r.FormValue("electric_fee")) || isNegative(r.FormValue("common_fee")) || isNegative(r.FormValue("late_fee")) || isNegative(r.FormValue("appliance_fee")) || isNegative(r.FormValue("paid_amount")) {
				http.Error(w, "จำนวนเงินห้ามติดลบ", http.StatusBadRequest)
				return
			}
			err := r.ParseMultipartForm(10 << 20)
			if err != nil && err != http.ErrNotMultipart {
				http.Error(w, "ไฟล์ขนาดใหญ่เกินไป หรือข้อมูลไม่ถูกต้อง", http.StatusBadRequest)
				return
			}
			paymentID := r.FormValue("payment_id")
			userID := r.FormValue("user_id")
			safeUserID := filepath.Base(filepath.Clean(userID))
			if safeUserID == "." || safeUserID == "/" || safeUserID == "\\" {
				safeUserID = "unknown"
			}

			if paymentID == "" {
				http.Error(w, "Missing payment_id", http.StatusBadRequest)
				return
			}

			// Get existing slips
			var existingSlipArrayStr string
			err = db.QueryRow("SELECT COALESCE(slip_path_array,'[]') FROM payments WHERE payment_id = ?", paymentID).Scan(&existingSlipArrayStr)
			if err != nil {
				http.Error(w, "models.Payment not found", http.StatusNotFound)
				return
			}

			var savedFiles []string
			if existingSlipArrayStr != "" && existingSlipArrayStr != "[]" {
				json.Unmarshal([]byte(existingSlipArrayStr), &savedFiles)
			}

			var firstFileName string
			if len(savedFiles) > 0 {
				firstFileName = savedFiles[0]
			}

			var files []*multipart.FileHeader
			if r.MultipartForm != nil && r.MultipartForm.File != nil {
				files = r.MultipartForm.File["slips"]
				if len(files) == 0 {
					files = r.MultipartForm.File["slip"]
				}
			}

			for i, fileHeader := range files {
				if !utils.IsAllowedUploadExt(filepath.Base(fileHeader.Filename)) {
					continue
				}
				file, err := fileHeader.Open()
				if err != nil {
					continue
				}
				fn := fmt.Sprintf("%d_%d_%s_%s", time.Now().UnixNano(), i, safeUserID, filepath.Base(fileHeader.Filename))
				if err := utils.SaveUploadedFile(file, filepath.Join("./uploads", fn)); err == nil {
					savedFiles = append(savedFiles, fn)
					if firstFileName == "" {
						firstFileName = fn
					}
				}
				file.Close()
			}

			slipPathArrayBytes, _ := json.Marshal(savedFiles)
			slipPathArrayStr := string(slipPathArrayBytes)
			if len(savedFiles) == 0 {
				slipPathArrayStr = "[]"
			}

			// Update data
			_, err = db.Exec(`UPDATE payments SET
				rent_fee=?, water_fee=?, electric_fee=?, common_fee=?, late_fee=?, appliance_fee=?, amount=?, payment_date=?, method=?, slip_path=?, water_meter_prev=?, water_meter_curr=?, electric_meter_prev=?, electric_meter_curr=?, slip_path_array=?, payment_status=?, paid_amount=?
				WHERE payment_id=?`,
				r.FormValue("rent_fee"), r.FormValue("water_fee"), r.FormValue("electric_fee"), r.FormValue("common_fee"), r.FormValue("late_fee"), r.FormValue("appliance_fee"), r.FormValue("amount"), r.FormValue("date"), r.FormValue("method"), firstFileName, r.FormValue("water_meter_prev"), r.FormValue("water_meter_curr"), r.FormValue("electric_meter_prev"), r.FormValue("electric_meter_curr"), slipPathArrayStr, r.FormValue("payment_status"), r.FormValue("paid_amount"), paymentID)

			if err != nil {
				http.Error(w, "Database error: ", http.StatusInternalServerError)
				return
			}

			if r.FormValue("payment_status") == "paid" {
				var roomNumber, monthStr, lineUserID, slipPathStr string
				var amount float64
				errScan := db.QueryRow("SELECT COALESCE(p.room_number, ''), COALESCE(p.month, ''), COALESCE(p.amount, 0), COALESCE(p.slip_path, ''), COALESCE(u.line_user_id, '') FROM payments p LEFT JOIN users u ON p.room_number = u.room_number WHERE p.payment_id = ?", paymentID).Scan(&roomNumber, &monthStr, &amount, &slipPathStr, &lineUserID)
				if errScan == nil && lineUserID != "" {
					dateStr := time.Now().Format("02/01/2006 15:04")
					imageURL := ""
					if slipPathStr != "" {
						baseURL := GetBaseURLFromWebhook()
						if baseURL == "" {
							baseURL = "https://" + r.Host // Fallback
						}
						imageURL = fmt.Sprintf("%s/uploads/%s", baseURL, slipPathStr)
					}
					go PushReceiptFlexMessage(lineUserID, paymentID, roomNumber, dateStr, amount, imageURL)
				}
			}

			w.WriteHeader(http.StatusOK)
		}
		if r.Method == "DELETE" {
			paymentID := r.URL.Query().Get("payment_id")
			filename := r.URL.Query().Get("filename")
			if paymentID == "" {
				http.Error(w, "Missing payment_id", http.StatusBadRequest)
				return
			}

			// ถ้ามี filename คือลบไฟล์รูปภาพสลิปอย่างเดียว
			if filename != "" {
				var slipPathArrayStr string
				err := db.QueryRow("SELECT COALESCE(slip_path_array,'[]') FROM payments WHERE payment_id = ?", paymentID).Scan(&slipPathArrayStr)
				if err != nil {
					http.Error(w, "models.Payment not found", http.StatusNotFound)
					return
				}
				var savedFiles []string
				if slipPathArrayStr != "" && slipPathArrayStr != "[]" {
					json.Unmarshal([]byte(slipPathArrayStr), &savedFiles)
				}
				var updatedFiles []string
				for _, fn := range savedFiles {
					if fn != filename {
						updatedFiles = append(updatedFiles, fn)
					} else {
						os.Remove(filepath.Join("./uploads", filepath.Base(fn)))
					}
				}
				var firstFileName string
				if len(updatedFiles) > 0 {
					firstFileName = updatedFiles[0]
				}
				slipPathArrayBytes, _ := json.Marshal(updatedFiles)
				newSlipPathArrayStr := string(slipPathArrayBytes)
				if len(updatedFiles) == 0 {
					newSlipPathArrayStr = "[]"
				}
				_, err = db.Exec("UPDATE payments SET slip_path = ?, slip_path_array = ? WHERE payment_id = ?", firstFileName, newSlipPathArrayStr, paymentID)
				if err != nil {
					http.Error(w, "Delete slip failed", http.StatusInternalServerError)
					return
				}
				w.WriteHeader(http.StatusOK)
				return
			}

			// ถ้าไม่มี filename คือลบบิลการเงินทั้งหมด
			var roomNumber, status string
			var amount float64
			db.QueryRow("SELECT room_number, amount, COALESCE(payment_status, 'pending') FROM payments WHERE payment_id = ?", paymentID).Scan(&roomNumber, &amount, &status)

			// Allow deleting paid bills based on user request

			_, err := db.Exec("DELETE FROM payments WHERE payment_id = ?", paymentID)
			if err != nil {
				http.Error(w, "Delete failed", http.StatusInternalServerError)
				return
			}
			db.Exec("INSERT INTO system_logs (action_type, details, timestamp) VALUES ('Delete Payment', 'ลบบิลห้อง ' || ? || ' ยอด ' || ? || ' บาท', ?)", roomNumber, amount, time.Now().Format("2006-01-02 15:04:05"))
			w.WriteHeader(http.StatusOK)
		}
		if r.Method == "PATCH" {
			var payload struct {
				PaymentID     int     `json:"payment_id"`
				Amount        float64 `json:"amount"`
				PaymentStatus string  `json:"payment_status"`
			}
			if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
				http.Error(w, "Invalid data", http.StatusBadRequest)
				return
			}
			
			if payload.PaymentStatus == "paid" {
				currentDate := time.Now().Format("2006-01-02")
				_, err := db.Exec("UPDATE payments SET payment_status = 'paid', payment_date = ? WHERE payment_id = ?", currentDate, payload.PaymentID)
				if err != nil {
					http.Error(w, "Update failed", http.StatusInternalServerError)
					return
				}
				
				var roomNumber, monthStr, lineUserID, slipPathStr string
				var amount float64
				errScan := db.QueryRow("SELECT COALESCE(p.room_number, ''), COALESCE(p.month, ''), COALESCE(p.amount, 0), COALESCE(p.slip_path, ''), COALESCE(u.line_user_id, '') FROM payments p LEFT JOIN users u ON p.room_number = u.room_number WHERE p.payment_id = ?", payload.PaymentID).Scan(&roomNumber, &monthStr, &amount, &slipPathStr, &lineUserID)
				if errScan == nil && lineUserID != "" {
					dateStr := time.Now().Format("02/01/2006 15:04")
					imageURL := ""
					if slipPathStr != "" {
						baseURL := GetBaseURLFromWebhook()
						if baseURL == "" {
							baseURL = "https://" + r.Host // Fallback
						}
						imageURL = fmt.Sprintf("%s/uploads/%s", baseURL, slipPathStr)
					}
					fmt.Println("Generated Image URL for LINE:", imageURL)
					db.Exec("INSERT INTO system_logs (action_type, details, timestamp) VALUES ('DEBUG_URL', ?, ?)", imageURL, time.Now().Format("2006-01-02 15:04:05"))
					go PushReceiptFlexMessage(lineUserID, fmt.Sprintf("%d", payload.PaymentID), roomNumber, dateStr, amount, imageURL)
				} else {
					fmt.Println("Error scanning user or empty lineUserID:", errScan, "lineUserID:", lineUserID)
				}
				db.Exec("INSERT INTO system_logs (action_type, details, timestamp) VALUES ('Confirm Payment', 'ยืนยันรับชำระเงินบิล ' || ?, ?)", payload.PaymentID, time.Now().Format("2006-01-02 15:04:05"))
			} else if payload.PaymentStatus == "rejected" {
				// Change status back to pending, remove slip_path
				_, err := db.Exec("UPDATE payments SET payment_status = 'pending', slip_path = NULL WHERE payment_id = ?", payload.PaymentID)
				if err != nil {
					http.Error(w, "Update failed", http.StatusInternalServerError)
					return
				}
				
				var roomNumber, lineUserID string
				errScan := db.QueryRow("SELECT COALESCE(p.room_number, ''), COALESCE(u.line_user_id, '') FROM payments p LEFT JOIN users u ON p.room_number = u.room_number WHERE p.payment_id = ?", payload.PaymentID).Scan(&roomNumber, &lineUserID)
				
				if errScan == nil && lineUserID != "" {
					msg := fmt.Sprintf("สลิปโอนเงินสำหรับบิลห้อง %s ไม่ถูกต้องค่ะ\nกรุณากดเมนู 'การเงิน' เพื่อตรวจสอบบิล และอัปโหลดรูปสลิปที่ถูกต้องเข้ามาใหม่อีกครั้งนะคะ", roomNumber)
					go PushLineMessage(lineUserID, msg)
				}
				
				db.Exec("INSERT INTO system_logs (action_type, details, timestamp) VALUES ('Reject Slip', 'ปฏิเสธสลิปบิล ' || ?, ?)", payload.PaymentID, time.Now().Format("2006-01-02 15:04:05"))
			} else {
				if payload.Amount < 0 {
					http.Error(w, "จำนวนเงินห้ามติดลบ", http.StatusBadRequest)
					return
				}
				_, err := db.Exec("UPDATE payments SET amount = ? WHERE payment_id = ?", payload.Amount, payload.PaymentID)
				if err != nil {
					http.Error(w, "Update failed", http.StatusInternalServerError)
					return
				}
				db.Exec("INSERT INTO system_logs (action_type, details, timestamp) VALUES ('Update Payment', 'แก้ไขยอดบิลเป็น ' || ? || ' บาท', ?)", payload.Amount, time.Now().Format("2006-01-02 15:04:05"))
			}
			w.WriteHeader(http.StatusOK)
		}
	})
}
