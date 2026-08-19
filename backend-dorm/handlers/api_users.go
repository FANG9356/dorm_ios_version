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
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"
)

func SetupUserRoutes(db *sql.DB) {
	http.HandleFunc("/api/users", func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method == "GET" {
			rows, err := db.Query("SELECT user_id, COALESCE(prefix, 'นาย'), COALESCE(first_name, ''), COALESCE(last_name, ''), COALESCE(room_number, ''), COALESCE(status, 'กำลังพักอาศัย'), COALESCE(national_id, ''), COALESCE(phone, '-'), COALESCE(address, ''), COALESCE(move_in_date, ''), COALESCE(contract_end_date, ''), COALESCE(deposit, 0), COALESCE(booking_status, ''), COALESCE(payment_method, ''), COALESCE(indefinite_contract, 0), COALESCE(booking_slips, ''), COALESCE(additional_appliances, ''), COALESCE(additional_appliance_fee, 0), COALESCE(additional_details, '') FROM users")
			if err != nil {
				http.Error(w, "Database Error", http.StatusInternalServerError)
				return
			}
			defer rows.Close()
			users := []models.User{}
			for rows.Next() {
				var u models.User
				var slipsStr string
				rows.Scan(&u.ID, &u.Prefix, &u.FirstName, &u.LastName, &u.RoomNumber, &u.Status, &u.NationalID, &u.Phone, &u.Address, &u.MoveInDate, &u.ContractEndDate, &u.Deposit, &u.BookingStatus, &u.PaymentMethod, &u.IndefiniteContract, &slipsStr, &u.AdditionalAppliances, &u.AdditionalApplianceFee, &u.AdditionalDetails)
				if slipsStr != "" {
					json.Unmarshal([]byte(slipsStr), &u.BookingSlips)
				}
				
				// Mask National ID for PDPA compliance on frontend delivery
				if len(u.NationalID) >= 13 {
					u.NationalID = "X-XXXX-XXXXX-" + u.NationalID[len(u.NationalID)-3:]
				} else if len(u.NationalID) > 4 {
					u.NationalID = strings.Repeat("X", len(u.NationalID)-4) + u.NationalID[len(u.NationalID)-4:]
				} else if len(u.NationalID) > 0 {
					u.NationalID = "X"
				}

				users = append(users, u)
			}
			json.NewEncoder(w).Encode(users)
		}
		if r.Method == "POST" || r.Method == "PUT" {
			var u models.User
			var slipsJSON string

			if len(r.Header.Get("Content-Type")) >= 19 && r.Header.Get("Content-Type")[:19] == "multipart/form-data" {
				err := r.ParseMultipartForm(50 << 20)
				if err != nil && err != http.ErrNotMultipart {
					http.Error(w, "ไฟล์ขนาดใหญ่เกินไป หรือข้อมูลไม่ถูกต้อง", http.StatusBadRequest)
					return
				}
				dataStr := r.FormValue("data")
				if err := json.Unmarshal([]byte(dataStr), &u); err != nil {
					http.Error(w, "ข้อมูลไม่ถูกต้อง", http.StatusBadRequest)
					return
				}

				var uploadedSlips []string
				var files []*multipart.FileHeader
				if r.MultipartForm != nil && r.MultipartForm.File != nil {
					files = r.MultipartForm.File["slips"]
				}
				for i, fileHeader := range files {
					if !utils.IsAllowedUploadExt(filepath.Base(fileHeader.Filename)) {
						continue
					}
					file, err := fileHeader.Open()
					if err != nil {
						continue
					}
					filename := fmt.Sprintf("slip_%d_%d_%s", time.Now().Unix(), i, filepath.Base(fileHeader.Filename))
					if err := utils.SaveUploadedFile(file, filepath.Join("./uploads", filename)); err == nil {
						uploadedSlips = append(uploadedSlips, filename)
					}
					file.Close()
				}
				if len(uploadedSlips) > 0 {
					u.BookingSlips = append(u.BookingSlips, uploadedSlips...)
					slipsBytes, _ := json.Marshal(u.BookingSlips)
					slipsJSON = string(slipsBytes)
				} else {
					slipsBytes, _ := json.Marshal(u.BookingSlips)
					slipsJSON = string(slipsBytes)
				}
			} else {
				if err := json.NewDecoder(r.Body).Decode(&u); err != nil {
					http.Error(w, "ข้อมูลไม่ถูกต้อง", http.StatusBadRequest)
					return
				}
				slipsBytes, _ := json.Marshal(u.BookingSlips)
				slipsJSON = string(slipsBytes)
			}

			fullName := u.FirstName + " " + u.LastName
			if u.RoomNumber == "" {
				http.Error(w, "models.Room number is required", 400)
				return
			}
			if u.Deposit < 0 || u.AdditionalApplianceFee < 0 {
				http.Error(w, "จำนวนเงินห้ามติดลบ", 400)
				return
			}
			
			// Remove masking string from ID if it wasn't edited, by retrieving original ID
			if r.Method == "PUT" && strings.Contains(strings.ToUpper(u.NationalID), "X") {
				var originalID string
				db.QueryRow("SELECT national_id FROM users WHERE user_id = ?", u.ID).Scan(&originalID)
				u.NationalID = originalID
			}

			if r.Method == "POST" {
				// [เพิ่มใหม่] เช็คว่ามีคนอยู่ในห้องนี้แล้วหรือยัง (ป้องกันการเพิ่มผู้เช่าซ้ำ)
				if u.Status == "กำลังพักอาศัย" || u.Status == "จอง" {
					var count int
					db.QueryRow("SELECT COUNT(*) FROM users WHERE room_number = ? AND (status = 'กำลังพักอาศัย' OR status = 'จอง')", u.RoomNumber).Scan(&count)
					if count > 0 {
						http.Error(w, "ห้องพักนี้มีผู้เช่าหรือถูกจองแล้ว ไม่สามารถเพิ่มผู้เช่าซ้ำได้", http.StatusConflict)
						return
					}
				}

				res, err := db.Exec("INSERT INTO users (prefix, first_name, last_name, full_name, room_number, status, national_id, phone, address, move_in_date, contract_end_date, deposit, booking_status, payment_method, indefinite_contract, booking_slips, additional_appliances, additional_appliance_fee, additional_details) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", u.Prefix, u.FirstName, u.LastName, fullName, u.RoomNumber, u.Status, u.NationalID, u.Phone, u.Address, u.MoveInDate, u.ContractEndDate, u.Deposit, u.BookingStatus, u.PaymentMethod, u.IndefiniteContract, slipsJSON, u.AdditionalAppliances, u.AdditionalApplianceFee, u.AdditionalDetails)
				if err != nil && strings.Contains(err.Error(), "UNIQUE constraint failed") {
					http.Error(w, "ห้องพักนี้มีผู้เช่าหรือถูกจองแล้ว ไม่สามารถเพิ่มผู้เช่าซ้ำได้", http.StatusConflict)
					return
				}
				if err != nil {
					res, err = db.Exec("INSERT INTO users (prefix, first_name, last_name, room_number, status, national_id, phone, address, move_in_date, contract_end_date, deposit, booking_status, payment_method, indefinite_contract, booking_slips, additional_appliances, additional_appliance_fee, additional_details) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", u.Prefix, u.FirstName, u.LastName, u.RoomNumber, u.Status, u.NationalID, u.Phone, u.Address, u.MoveInDate, u.ContractEndDate, u.Deposit, u.BookingStatus, u.PaymentMethod, u.IndefiniteContract, slipsJSON, u.AdditionalAppliances, u.AdditionalApplianceFee, u.AdditionalDetails)
				}
				if err != nil && strings.Contains(err.Error(), "UNIQUE constraint failed") {
					http.Error(w, "ห้องพักนี้มีผู้เช่าหรือถูกจองแล้ว ไม่สามารถเพิ่มผู้เช่าซ้ำได้", http.StatusConflict)
					return
				}
				if err != nil {
					http.Error(w, "เซฟไม่ได้", http.StatusInternalServerError)
					return
				}
				id, err := res.LastInsertId()
				if err != nil {
					w.WriteHeader(http.StatusCreated)
					return
				}
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusCreated)
				json.NewEncoder(w).Encode(map[string]interface{}{"id": id})
			} else {
				// [เพิ่มใหม่] เช็คว่ามีคนอยู่ในห้องนี้แล้วหรือยังตอนแก้ไขข้อมูล
				if u.Status == "กำลังพักอาศัย" || u.Status == "จอง" {
					var count int
					db.QueryRow("SELECT COUNT(*) FROM users WHERE room_number = ? AND (status = 'กำลังพักอาศัย' OR status = 'จอง') AND user_id != ?", u.RoomNumber, u.ID).Scan(&count)
					if count > 0 {
						http.Error(w, "ห้องพักนี้มีผู้เช่าหรือถูกจองแล้ว ไม่สามารถย้ายผู้เช่าไปห้องนี้ได้", http.StatusConflict)
						return
					}
				}

				_, err := db.Exec("UPDATE users SET prefix=?, first_name=?, last_name=?, full_name=?, room_number=?, status=?, national_id=?, phone=?, address=?, move_in_date=?, contract_end_date=?, deposit=?, booking_status=?, payment_method=?, indefinite_contract=?, booking_slips=?, additional_appliances=?, additional_appliance_fee=?, additional_details=? WHERE user_id=?", u.Prefix, u.FirstName, u.LastName, fullName, u.RoomNumber, u.Status, u.NationalID, u.Phone, u.Address, u.MoveInDate, u.ContractEndDate, u.Deposit, u.BookingStatus, u.PaymentMethod, u.IndefiniteContract, slipsJSON, u.AdditionalAppliances, u.AdditionalApplianceFee, u.AdditionalDetails, u.ID)
				if err != nil && strings.Contains(err.Error(), "UNIQUE constraint failed") {
					http.Error(w, "ห้องพักนี้มีผู้เช่าหรือถูกจองแล้ว ไม่สามารถย้ายผู้เช่าไปห้องนี้ได้", http.StatusConflict)
					return
				}
				if err != nil {
					_, err = db.Exec("UPDATE users SET prefix=?, first_name=?, last_name=?, room_number=?, status=?, national_id=?, phone=?, address=?, move_in_date=?, contract_end_date=?, deposit=?, booking_status=?, payment_method=?, indefinite_contract=?, booking_slips=?, additional_appliances=?, additional_appliance_fee=?, additional_details=? WHERE user_id=?", u.Prefix, u.FirstName, u.LastName, u.RoomNumber, u.Status, u.NationalID, u.Phone, u.Address, u.MoveInDate, u.ContractEndDate, u.Deposit, u.BookingStatus, u.PaymentMethod, u.IndefiniteContract, slipsJSON, u.AdditionalAppliances, u.AdditionalApplianceFee, u.AdditionalDetails, u.ID)
				}
				if err != nil && strings.Contains(err.Error(), "UNIQUE constraint failed") {
					http.Error(w, "ห้องพักนี้มีผู้เช่าหรือถูกจองแล้ว ไม่สามารถย้ายผู้เช่าไปห้องนี้ได้", http.StatusConflict)
					return
				}
				if err != nil {
					http.Error(w, "อัปเดตไม่ได้", http.StatusInternalServerError)
					return
				}
				w.WriteHeader(http.StatusOK)
			}
		}
		if r.Method == "DELETE" {
			userID := r.URL.Query().Get("id")
			if userID == "all_moved_out" {
				tx, err := db.Begin()
				if err != nil {
					http.Error(w, "Database error", http.StatusInternalServerError)
					return
				}
				defer utils.RollbackOnErr(tx, &err)
				rows, err := tx.Query("SELECT user_id, room_number FROM users WHERE status = 'ย้ายออกแล้ว'")
				if err != nil {
					http.Error(w, "Delete failed", http.StatusInternalServerError)
					return
				}
				var ids []string
				for rows.Next() {
					var id string
					var rm string
					rows.Scan(&id, &rm)
					ids = append(ids, id)
					if _, err = tx.Exec("DELETE FROM room_conditions WHERE user_id = ?", id); err != nil {
						rows.Close()
						http.Error(w, "Delete failed", http.StatusInternalServerError)
						return
					}
					var depositSlipPath string
					tx.QueryRow("SELECT COALESCE(slip_path, '') FROM deposit_refunds WHERE user_id = ?", id).Scan(&depositSlipPath)
					if depositSlipPath != "" {
						os.Remove(filepath.Join("./uploads", filepath.Base(depositSlipPath)))
					}
					if _, err = tx.Exec("DELETE FROM deposit_refunds WHERE user_id = ?", id); err != nil {
						rows.Close()
						http.Error(w, "Delete failed", http.StatusInternalServerError)
						return
					}
				}
				rows.Close()
				if _, err = tx.Exec("DELETE FROM users WHERE status = 'ย้ายออกแล้ว'"); err != nil {
					http.Error(w, "Delete failed", http.StatusInternalServerError)
					return
				}
				if _, err = tx.Exec("INSERT INTO system_logs (action_type, details, timestamp) VALUES ('Delete', 'ลบลูกบ้านที่ย้ายออกแล้วทั้งหมด จำนวน ' || ? || ' รายการ', ?)", len(ids), time.Now().Format("2006-01-02 15:04:05")); err != nil {
					http.Error(w, "Delete failed", http.StatusInternalServerError)
					return
				}
				if err = tx.Commit(); err != nil {
					http.Error(w, "Delete failed", http.StatusInternalServerError)
					return
				}
				w.WriteHeader(http.StatusOK)
				return
			}

			var status string
			err := db.QueryRow("SELECT status FROM users WHERE user_id = ?", userID).Scan(&status)
			if err != nil || status != "ย้ายออกแล้ว" {
				http.Error(w, "ลบได้เฉพาะลูกบ้านที่ย้ายออกแล้ว", http.StatusForbidden)
				return
			}
			tx, err := db.Begin()
			if err != nil {
				http.Error(w, "Database error", http.StatusInternalServerError)
				return
			}
			defer utils.RollbackOnErr(tx, &err)
			rows, errCond := tx.Query("SELECT COALESCE(image_path, '') FROM room_conditions WHERE user_id = ?", userID)
			if errCond == nil {
				for rows.Next() {
					var p string
					if err := rows.Scan(&p); err == nil && p != "" {
						os.Remove(filepath.Join("./uploads", filepath.Base(p)))
					}
				}
				rows.Close()
			}
			if _, err = tx.Exec("DELETE FROM room_conditions WHERE user_id = ?", userID); err != nil {
				http.Error(w, "Delete failed", http.StatusInternalServerError)
				return
			}
			var depositSlipPath string
			tx.QueryRow("SELECT COALESCE(slip_path, '') FROM deposit_refunds WHERE user_id = ?", userID).Scan(&depositSlipPath)
			if depositSlipPath != "" {
				os.Remove(filepath.Join("./uploads", filepath.Base(depositSlipPath)))
			}
			if _, err = tx.Exec("DELETE FROM deposit_refunds WHERE user_id = ?", userID); err != nil {
				http.Error(w, "Delete failed", http.StatusInternalServerError)
				return
			}
			var bookingSlips string
			tx.QueryRow("SELECT COALESCE(booking_slips, '') FROM users WHERE user_id = ?", userID).Scan(&bookingSlips)
			if bookingSlips != "" && bookingSlips != "[]" {
				var bSlips []string
				json.Unmarshal([]byte(bookingSlips), &bSlips)
				for _, s := range bSlips {
					os.Remove(filepath.Join("./uploads", filepath.Base(s)))
				}
			}
			if _, err = tx.Exec("DELETE FROM users WHERE user_id = ?", userID); err != nil {
				http.Error(w, "Delete failed", http.StatusInternalServerError)
				return
			}
			if _, err = tx.Exec("INSERT INTO system_logs (action_type, details, timestamp) VALUES ('Delete', 'ลบลูกบ้านห้อง ' || ? || ' (ย้ายออกแล้ว)', ?)", r.URL.Query().Get("room_number"), time.Now().Format("2006-01-02 15:04:05")); err != nil {
				http.Error(w, "Delete failed", http.StatusInternalServerError)
				return
			}
			if err = tx.Commit(); err != nil {
				http.Error(w, "Delete failed", http.StatusInternalServerError)
				return
			}
			w.WriteHeader(http.StatusOK)
		}
	})

	http.HandleFunc("/api/move-out", func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method == "POST" {
			var req struct {
				UserID          int     `json:"user_id"`
				RoomNumber      string  `json:"room_number"`
				OriginalDeposit float64 `json:"original_deposit"`
				CleaningFee     float64 `json:"cleaning_fee"`
				DamageFee       float64 `json:"damage_fee"`
				NetRefund       float64 `json:"net_refund"`
			}
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				http.Error(w, "ข้อมูลไม่ถูกต้อง", http.StatusBadRequest)
				return
			}
			if req.CleaningFee < 0 || req.DamageFee < 0 || req.OriginalDeposit < 0 {
				http.Error(w, "จำนวนเงินห้ามติดลบ", http.StatusBadRequest)
				return
			}
			tx, err := db.Begin()
			if err != nil {
				http.Error(w, "ไม่สามารถเริ่ม Transaction ได้", http.StatusInternalServerError)
				return
			}
			refundDate := time.Now().Format("2006-01-02 15:04:05")
			_, err = tx.Exec("INSERT INTO deposit_refunds (user_id, room_number, original_deposit, cleaning_fee, damage_fee, net_refund, refund_date) VALUES (?, ?, ?, ?, ?, ?, ?)", req.UserID, req.RoomNumber, req.OriginalDeposit, req.CleaningFee, req.DamageFee, req.NetRefund, refundDate)
			if err != nil {
				tx.Rollback()
				http.Error(w, "บันทึกยอดเงินคืนไม่สำเร็จ", http.StatusInternalServerError)
				return
			}
			_, err = tx.Exec("UPDATE users SET status = 'ย้ายออกแล้ว', line_user_id = '', bot_state = 'none' WHERE user_id = ?", req.UserID)
			if err != nil {
				tx.Rollback()
				http.Error(w, "อัปเดตสถานะลูกบ้านไม่สำเร็จ", http.StatusInternalServerError)
				return
			}
			tx.Commit()
			w.WriteHeader(http.StatusOK)
		}
	})

	http.HandleFunc("/api/users/unmask-id", func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method == "POST" {
			var req struct {
				UserID   int    `json:"user_id"`
				Password string `json:"password"`
			}
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				http.Error(w, "ข้อมูลไม่ถูกต้อง", http.StatusBadRequest)
				return
			}

			rows, err := db.Query("SELECT password FROM admins")
			if err != nil {
				http.Error(w, "เกิดข้อผิดพลาดของฐานข้อมูล", http.StatusInternalServerError)
				return
			}
			defer rows.Close()

			valid := false
			for rows.Next() {
				var hash string
				rows.Scan(&hash)
				if bcrypt.CompareHashAndPassword([]byte(hash), []byte(req.Password)) == nil {
					valid = true
					break
				}
			}

			if !valid {
				http.Error(w, "รหัสผ่านไม่ถูกต้อง", http.StatusUnauthorized)
				return
			}

			var realID string
			err = db.QueryRow("SELECT national_id FROM users WHERE user_id = ?", req.UserID).Scan(&realID)
			if err != nil {
				http.Error(w, "ไม่พบข้อมูลลูกบ้าน", http.StatusNotFound)
				return
			}

			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(map[string]string{"national_id": realID})
		}
	})
}
