package handlers

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"
)

type LiffLinkRequest struct {
	AccessToken string `json:"access_token"`
	RoomNumber  string `json:"room_number"`
	Phone       string `json:"phone"`
}

func HandleLiffRooms(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		db := getTenantDB(r, db)
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		if r.Method != "GET" {
			http.Error(w, `{"error": "Method not allowed"}`, http.StatusMethodNotAllowed)
			return
		}
		rows, err := db.Query("SELECT room_number, full_name FROM users WHERE (line_user_id IS NULL OR line_user_id = '') AND (status = 'active' OR status = 'กำลังพักอาศัย')")
		if err != nil {
			http.Error(w, `{"error": "Database error"}`, http.StatusInternalServerError)
			return
		}
		defer rows.Close()

		type RoomInfo struct {
			RoomNumber string `json:"room_number"`
			MaskedName string `json:"masked_name"`
		}
		var rooms []RoomInfo

		for rows.Next() {
			var room, name string
			if err := rows.Scan(&room, &name); err == nil {
				rooms = append(rooms, RoomInfo{
					RoomNumber: room,
					MaskedName: "", // ซ่อนชื่อไว้ก่อนจนกว่าจะยืนยันเบอร์โทร
				})
			}
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(rooms)
	}
}

type LiffVerifyRequest struct {
	RoomNumber string `json:"room_number"`
	Phone      string `json:"phone"`
}

func HandleLiffVerify(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		db := getTenantDB(r, db)
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		if r.Method != "POST" {
			http.Error(w, `{"error": "Method not allowed"}`, http.StatusMethodNotAllowed)
			return
		}

		var req LiffVerifyRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"error": "ข้อมูลไม่ถูกต้อง"}`, http.StatusBadRequest)
			return
		}

		req.RoomNumber = strings.TrimSpace(req.RoomNumber)
		req.Phone = strings.TrimSpace(req.Phone)

		if req.RoomNumber == "" || req.Phone == "" {
			http.Error(w, `{"error": "กรุณากรอกข้อมูลให้ครบถ้วน"}`, http.StatusBadRequest)
			return
		}

		// ดึงข้อมูลลูกบ้าน
		var name, phone string
		err := db.QueryRow("SELECT full_name, phone FROM users WHERE room_number = ? AND (status = 'active' OR status = 'กำลังพักอาศัย') AND (line_user_id IS NULL OR line_user_id = '')", req.RoomNumber).Scan(&name, &phone)
		if err != nil {
			http.Error(w, `{"error": "ไม่พบห้องนี้ หรือถูกผูกบัญชีไปแล้ว"}`, http.StatusNotFound)
			return
		}

		// ทำความสะอาดเบอร์โทร
		cleanPhone := strings.ReplaceAll(phone, "-", "")
		cleanPhone = strings.ReplaceAll(cleanPhone, " ", "")
		inputPhone := strings.ReplaceAll(req.Phone, "-", "")
		inputPhone = strings.ReplaceAll(inputPhone, " ", "")

		if cleanPhone != inputPhone {
			http.Error(w, `{"error": "เบอร์โทรศัพท์ไม่ถูกต้อง"}`, http.StatusUnauthorized)
			return
		}

		// ตัดนามสกุลออกเพื่อความปลอดภัย
		name = strings.TrimSpace(name)
		prefixes := []string{"นาย", "นางสาว", "นาง", "น.ส.", "ด.ช.", "ด.ญ.", "Mr.", "Mrs.", "Ms."}
		for _, p := range prefixes {
			if strings.HasPrefix(name, p) {
				name = strings.TrimSpace(strings.TrimPrefix(name, p))
				break
			}
		}
		parts := strings.Fields(name)
		masked := name
		if len(parts) > 0 {
			masked = parts[0]
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"masked_name": masked})
	}
}

func HandleLiffLink(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		db := getTenantDB(r, db)
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		if r.Method != "POST" {
			http.Error(w, `{"error": "Method not allowed"}`, http.StatusMethodNotAllowed)
			return
		}

		var req LiffLinkRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"error": "ข้อมูลไม่ถูกต้อง"}`, http.StatusBadRequest)
			return
		}

		req.RoomNumber = strings.TrimSpace(req.RoomNumber)
		req.Phone = strings.TrimSpace(req.Phone)

		if req.AccessToken == "" || req.RoomNumber == "" || req.Phone == "" {
			http.Error(w, `{"error": "กรุณาเลือกห้อง, กรอกเบอร์โทร และให้สิทธิ์ LINE"}`, http.StatusBadRequest)
			return
		}

		// Verify Access Token via LINE API
		verifyURL := fmt.Sprintf("https://api.line.me/oauth2/v2.1/verify?access_token=%s", req.AccessToken)
		resp, err := http.Get(verifyURL)
		if err != nil || resp.StatusCode != 200 {
			http.Error(w, `{"error": "การยืนยันตัวตนกับ LINE ล้มเหลว"}`, http.StatusUnauthorized)
			return
		}
		if resp != nil && resp.Body != nil {
			resp.Body.Close()
		}

		// Get User Profile from LINE API
		reqProfile, _ := http.NewRequest("GET", "https://api.line.me/v2/profile", nil)
		reqProfile.Header.Set("Authorization", "Bearer "+req.AccessToken)
		client := &http.Client{Timeout: 10 * time.Second}
		respProfile, err := client.Do(reqProfile)
		if err != nil || respProfile.StatusCode != 200 {
			http.Error(w, `{"error": "ไม่สามารถดึงข้อมูลโปรไฟล์จาก LINE ได้"}`, http.StatusUnauthorized)
			return
		}
		defer respProfile.Body.Close()

		var profile struct {
			UserId string `json:"userId"`
		}
		if err := json.NewDecoder(respProfile.Body).Decode(&profile); err != nil || profile.UserId == "" {
			http.Error(w, `{"error": "ไม่พบข้อมูล LINE ID"}`, http.StatusInternalServerError)
			return
		}

		lineUserID := profile.UserId

		var userID int
		var phone string
		err = db.QueryRow("SELECT user_id, phone FROM users WHERE room_number = ? AND (status = 'active' OR status = 'กำลังพักอาศัย') AND (line_user_id IS NULL OR line_user_id = '')", req.RoomNumber).Scan(&userID, &phone)
		if err != nil {
			http.Error(w, `{"error": "ไม่พบห้องนี้ หรือห้องนี้ถูกผูกบัญชีไปแล้ว"}`, http.StatusNotFound)
			return
		}

		// ทำความสะอาดเบอร์โทร
		cleanPhone := strings.ReplaceAll(phone, "-", "")
		cleanPhone = strings.ReplaceAll(cleanPhone, " ", "")
		inputPhone := strings.ReplaceAll(req.Phone, "-", "")
		inputPhone = strings.ReplaceAll(inputPhone, " ", "")

		if cleanPhone != inputPhone {
			http.Error(w, `{"error": "เบอร์โทรศัพท์ไม่ถูกต้อง"}`, http.StatusUnauthorized)
			return
		}

		// Update database
		// First, clear this line_user_id from any other rooms to prevent duplicate linking
		db.Exec("UPDATE users SET line_user_id = '' WHERE line_user_id = ?", lineUserID)

		// Then, link it to the selected room
		_, err = db.Exec("UPDATE users SET line_user_id = ? WHERE user_id = ?", lineUserID, userID)
		if err != nil {
			http.Error(w, `{"error": "เกิดข้อผิดพลาดในการอัปเดตข้อมูล"}`, http.StatusInternalServerError)
			return
		}

		msg := fmt.Sprintf("ผูกบัญชี LINE กับห้อง %s สำเร็จเรียบร้อยค่ะ\nต่อไปนี้ระบบจะแจ้งเตือนบิลและรับสลิปผ่านแชทนี้ค่ะ", req.RoomNumber)
		go PushLineMessage(lineUserID, msg)

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"message": "success", "room_number": req.RoomNumber})
	}
}
