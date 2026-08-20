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
	"time"
)

func SetupRoomRoutes(db *sql.DB) {
	http.HandleFunc("/api/rooms", func(w http.ResponseWriter, r *http.Request) {
		db = getTenantDB(r, db)
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method == "GET" {
			rows, err := db.Query("SELECT room_id, room_number, room_type FROM rooms ORDER BY room_number")
			if err != nil {
				http.Error(w, "Database Error", http.StatusInternalServerError)
				return
			}
			defer rows.Close()
			rooms := []models.Room{}
			for rows.Next() {
				var rm models.Room
				rows.Scan(&rm.ID, &rm.RoomNumber, &rm.RoomType)
				rooms = append(rooms, rm)
			}
			json.NewEncoder(w).Encode(rooms)
		}
		if r.Method == "POST" {
			var rm models.Room
			if err := json.NewDecoder(r.Body).Decode(&rm); err != nil {
				http.Error(w, "Invalid input", http.StatusBadRequest)
				return
			}
			if rm.RoomNumber == "" {
				http.Error(w, "Room number is required", 400)
				return
			}
			_, err := db.Exec("INSERT INTO rooms (room_number, room_type) VALUES (?, ?)", rm.RoomNumber, rm.RoomType)
			if err != nil {
				http.Error(w, "เกิดข้อผิดพลาดของระบบ", 500)
				return
			}
			w.WriteHeader(http.StatusCreated)
		}
		if r.Method == "PUT" {
			var rm models.Room
			if err := json.NewDecoder(r.Body).Decode(&rm); err != nil {
				http.Error(w, "Invalid input", http.StatusBadRequest)
				return
			}
			if rm.RoomNumber == "" {
				http.Error(w, "Room number is required", 400)
				return
			}

			var oldRoomNumber string
			err := db.QueryRow("SELECT room_number FROM rooms WHERE room_id=?", rm.ID).Scan(&oldRoomNumber)
			if err != nil {
				http.Error(w, "models.Room not found", 404)
				return
			}

			tx, err := db.Begin()
			if err != nil {
				http.Error(w, "เกิดข้อผิดพลาดของระบบ", 500)
				return
			}

			_, err = tx.Exec("UPDATE rooms SET room_number=?, room_type=? WHERE room_id=?", rm.RoomNumber, rm.RoomType, rm.ID)
			if err != nil {
				tx.Rollback()
				http.Error(w, "เกิดข้อผิดพลาดของระบบ", 500)
				return
			}

			if oldRoomNumber != rm.RoomNumber && oldRoomNumber != "" {
				tables := []string{"users", "payments", "deposit_refunds", "room_conditions", "maintenances"}
				for _, table := range tables {
					_, err = tx.Exec(fmt.Sprintf("UPDATE %s SET room_number=? WHERE room_number=?", table), rm.RoomNumber, oldRoomNumber)
					if err != nil {
						tx.Rollback()
						http.Error(w, "เกิดข้อผิดพลาดในการอัปเดตข้อมูลที่เกี่ยวข้อง", 500)
						return
					}
				}
			}

			err = tx.Commit()
			if err != nil {
				http.Error(w, "เกิดข้อผิดพลาดของระบบ", 500)
				return
			}
			w.WriteHeader(http.StatusOK)
		}
		if r.Method == "DELETE" {
			roomID := r.URL.Query().Get("id")
			var rn string
			if err := db.QueryRow("SELECT room_number FROM rooms WHERE room_id=?", roomID).Scan(&rn); err == nil {
				var count int
				db.QueryRow("SELECT COUNT(*) FROM users WHERE room_number=? AND (status='กำลังพักอาศัย' OR status='จอง')", rn).Scan(&count)
				if count > 0 {
					http.Error(w, "ไม่สามารถลบห้องพักที่มีลูกบ้านกำลังพักอาศัยหรือจองอยู่ได้", 400)
					return
				}
			}
			_, err := db.Exec("DELETE FROM rooms WHERE room_id=?", roomID)
			if err != nil {
				http.Error(w, "เกิดข้อผิดพลาดของระบบ", 500)
				return
			}
			w.WriteHeader(http.StatusOK)
		}
	})

	http.HandleFunc("/api/rooms/available", func(w http.ResponseWriter, r *http.Request) {
		db = getTenantDB(r, db)
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		rows, err := db.Query("SELECT r.room_id, r.room_number, r.room_type FROM rooms r LEFT JOIN users u ON r.room_number = u.room_number AND u.status = 'กำลังพักอาศัย' WHERE u.user_id IS NULL ORDER BY r.room_number")
		if err != nil {
			http.Error(w, "Database Error", http.StatusInternalServerError)
			return
		}
		defer rows.Close()
		rooms := []models.Room{}
		for rows.Next() {
			var rm models.Room
			rows.Scan(&rm.ID, &rm.RoomNumber, &rm.RoomType)
			rooms = append(rooms, rm)
		}
		json.NewEncoder(w).Encode(rooms)
	})

	http.HandleFunc("/api/room-types", func(w http.ResponseWriter, r *http.Request) {
		db = getTenantDB(r, db)
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method == "GET" {
			rows, err := db.Query("SELECT id, name, price, COALESCE(water_fee_default, 0), COALESCE(electric_fee_default, 0), COALESCE(common_fee_default, 0), COALESCE(late_fee_default, 0) FROM room_types ORDER BY id")
			if err != nil {
				http.Error(w, "Database Error", http.StatusInternalServerError)
				return
			}
			defer rows.Close()
			types := []models.RoomTypeDef{}
			for rows.Next() {
				var rt models.RoomTypeDef
				rows.Scan(&rt.ID, &rt.Name, &rt.Price, &rt.WaterFee, &rt.ElectricFee, &rt.CommonFee, &rt.LateFee)
				types = append(types, rt)
			}
			json.NewEncoder(w).Encode(types)
		}
		if r.Method == "POST" {
			var rt models.RoomTypeDef
			if err := json.NewDecoder(r.Body).Decode(&rt); err != nil {
				http.Error(w, "Invalid input", http.StatusBadRequest)
				return
			}
			if rt.Price < 0 {
				http.Error(w, "ราคาห้ามติดลบ", 400)
				return
			}
			_, err := db.Exec("INSERT INTO room_types (name, price, water_fee_default, electric_fee_default, common_fee_default, late_fee_default) VALUES (?, ?, ?, ?, ?, ?)", rt.Name, rt.Price, rt.WaterFee, rt.ElectricFee, rt.CommonFee, rt.LateFee)
			if err != nil {
				http.Error(w, "เกิดข้อผิดพลาดของระบบ", 500)
				return
			}
			w.WriteHeader(http.StatusCreated)
		}
		if r.Method == "PUT" {
			var rt models.RoomTypeDef
			if err := json.NewDecoder(r.Body).Decode(&rt); err != nil {
				http.Error(w, "Invalid input", http.StatusBadRequest)
				return
			}
			if rt.Price < 0 {
				http.Error(w, "ราคาห้ามติดลบ", 400)
				return
			}

			var oldName string
			err := db.QueryRow("SELECT name FROM room_types WHERE id=?", rt.ID).Scan(&oldName)
			if err != nil {
				http.Error(w, "models.Room type not found", 404)
				return
			}

			tx, err := db.Begin()
			if err != nil {
				http.Error(w, "เกิดข้อผิดพลาดของระบบ", 500)
				return
			}

			_, err = tx.Exec("UPDATE room_types SET name=?, price=?, water_fee_default=?, electric_fee_default=?, common_fee_default=?, late_fee_default=? WHERE id=?", rt.Name, rt.Price, rt.WaterFee, rt.ElectricFee, rt.CommonFee, rt.LateFee, rt.ID)
			if err != nil {
				tx.Rollback()
				http.Error(w, "เกิดข้อผิดพลาดของระบบ", 500)
				return
			}

			if oldName != rt.Name && oldName != "" {
				_, err = tx.Exec("UPDATE rooms SET room_type=? WHERE room_type=?", rt.Name, oldName)
				if err != nil {
					tx.Rollback()
					http.Error(w, "เกิดข้อผิดพลาดในการอัปเดตข้อมูลที่เกี่ยวข้อง", 500)
					return
				}
			}

			err = tx.Commit()
			if err != nil {
				http.Error(w, "เกิดข้อผิดพลาดของระบบ", 500)
				return
			}

			w.WriteHeader(http.StatusOK)
		}
		if r.Method == "DELETE" {
			id := r.URL.Query().Get("id")
			var typeName string
			err := db.QueryRow("SELECT name FROM room_types WHERE id=?", id).Scan(&typeName)
			if err != nil {
				http.Error(w, "ไม่พบประเภทห้องพัก หรือเกิดข้อผิดพลาดของระบบ", 400)
				return
			}
			var count int
			db.QueryRow("SELECT COUNT(*) FROM rooms WHERE room_type=?", typeName).Scan(&count)
			if count > 0 {
				http.Error(w, "ไม่สามารถลบประเภทห้องพักที่มีห้องพักใช้งานอยู่ได้", 400)
				return
			}
			_, err = db.Exec("DELETE FROM room_types WHERE id=?", id)
			if err != nil {
				http.Error(w, "เกิดข้อผิดพลาดในการลบ", 500)
				return
			}
			w.WriteHeader(http.StatusOK)
		}
	})

	http.HandleFunc("/api/evidence/room-conditions", func(w http.ResponseWriter, r *http.Request) {
		db = getTenantDB(r, db)
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method == "GET" {
			userID := r.URL.Query().Get("user_id")
			rows, err := db.Query("SELECT id, user_id, room_number, image_path, uploaded_at FROM room_conditions WHERE user_id = ? ORDER BY id DESC", userID)
			if err != nil {
				http.Error(w, "Database error", http.StatusInternalServerError)
				return
			}
			defer rows.Close()
			var conditions []models.RoomCondition
			for rows.Next() {
				var c models.RoomCondition
				rows.Scan(&c.ID, &c.UserID, &c.RoomNumber, &c.ImagePath, &c.UploadedAt)
				conditions = append(conditions, c)
			}
			json.NewEncoder(w).Encode(conditions)
			return
		}
		if r.Method == "POST" {
			err := r.ParseMultipartForm(50 << 20)
			if err != nil {
				http.Error(w, "File too large (Max 50MB)", 400)
				return
			}

			userID := r.FormValue("user_id")
			roomNumber := r.FormValue("room_number")

			files := r.MultipartForm.File["files"]
			if len(files) == 0 {
				http.Error(w, "No files uploaded", 400)
				return
			}

			tx, err := db.Begin()
			if err != nil {
				http.Error(w, "Database error", http.StatusInternalServerError)
				return
			}
			uploaded := 0
			for i, fileHeader := range files {
				if !utils.IsAllowedUploadExt(filepath.Base(fileHeader.Filename)) {
					continue
				}
				file, err := fileHeader.Open()
				if err != nil {
					continue
				}
				filename := fmt.Sprintf("cond_%d_%d_%s", time.Now().Unix(), i, filepath.Base(fileHeader.Filename))
				if err := utils.SaveUploadedFile(file, filepath.Join("./uploads", filename)); err == nil {
					if _, err = tx.Exec("INSERT INTO room_conditions (user_id, room_number, image_path, uploaded_at) VALUES (?, ?, ?, ?)", userID, roomNumber, filename, time.Now().Format("2006-01-02 15:04:05")); err != nil {
						http.Error(w, "Database error", http.StatusInternalServerError)
						tx.Rollback()
						return
					}
					uploaded++
				}
				file.Close()
			}
			if uploaded == 0 {
				tx.Rollback()
				http.Error(w, "No valid files uploaded", http.StatusBadRequest)
				return
			}
			tx.Exec("INSERT INTO system_logs (action_type, details, timestamp) VALUES ('Create', 'อัปโหลดหลักฐานสภาพห้องจำนวน ' || ? || ' ไฟล์ ห้อง ' || ?, ?)", uploaded, roomNumber, time.Now().Format("2006-01-02 15:04:05"))
			if err := tx.Commit(); err != nil {
				http.Error(w, "Save failed", http.StatusInternalServerError)
				return
			}
			w.WriteHeader(http.StatusOK)
		}
		if r.Method == "DELETE" {
			id := r.URL.Query().Get("id")
			if id == "" {
				http.Error(w, "Missing id", 400)
				return
			}
			var imagePath string
			err := db.QueryRow("SELECT image_path FROM room_conditions WHERE id = ?", id).Scan(&imagePath)
			if err == nil && imagePath != "" {
				os.Remove(filepath.Join("./uploads", imagePath))
			}
			_, err = db.Exec("DELETE FROM room_conditions WHERE id = ?", id)
			if err != nil {
				http.Error(w, "Delete failed", 500)
				return
			}
			w.WriteHeader(http.StatusOK)
		}
	})
}
