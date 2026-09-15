package handlers

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"
)

type requestRateWindow struct {
	Count   int
	ResetAt time.Time
}

var (
	requestRateMu      sync.Mutex
	requestRateWindows = make(map[string]requestRateWindow)
)

func requestClientIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		host = r.RemoteAddr
	}
	remote := net.ParseIP(strings.TrimSpace(host))
	if remote != nil && (remote.IsLoopback() || remote.IsPrivate()) {
		if forwarded := net.ParseIP(strings.TrimSpace(r.Header.Get("CF-Connecting-IP"))); forwarded != nil {
			return forwarded.String()
		}
	}
	if remote != nil {
		return remote.String()
	}
	return "unknown"
}

func allowRequestAttempt(r *http.Request, action string, limit int, window time.Duration) bool {
	now := time.Now()
	key := action + ":" + requestClientIP(r)
	requestRateMu.Lock()
	defer requestRateMu.Unlock()
	if len(requestRateWindows) > 4096 {
		for existingKey, existing := range requestRateWindows {
			if !now.Before(existing.ResetAt) {
				delete(requestRateWindows, existingKey)
			}
		}
	}
	entry := requestRateWindows[key]
	if entry.ResetAt.IsZero() || !now.Before(entry.ResetAt) {
		requestRateWindows[key] = requestRateWindow{Count: 1, ResetAt: now.Add(window)}
		return true
	}
	if entry.Count >= limit {
		return false
	}
	entry.Count++
	requestRateWindows[key] = entry
	return true
}

type LiffLinkRequest struct {
	AccessToken string `json:"access_token"`
	RoomNumber  string `json:"room_number"`
	Phone       string `json:"phone"`
}

type LiffVerifyRequest struct {
	RoomNumber string `json:"room_number"`
	Phone      string `json:"phone"`
}

func singleLineAccount(master *sql.DB) (int, error) {
	rows, err := master.Query(`SELECT account_id FROM sync_snapshots GROUP BY account_id ORDER BY account_id LIMIT 2`)
	if err != nil {
		return 0, err
	}
	defer rows.Close()
	var accounts []int
	for rows.Next() {
		var accountID int
		if err := rows.Scan(&accountID); err != nil {
			return 0, err
		}
		accounts = append(accounts, accountID)
	}
	if len(accounts) != 1 {
		return 0, fmt.Errorf("LINE linking needs exactly one active account, found %d", len(accounts))
	}
	return accounts[0], nil
}

func lineLinkTenantDB(master *sql.DB) (*sql.DB, int, error) {
	accountID, err := singleLineAccount(master)
	if err != nil {
		return nil, 0, err
	}
	tenantDB, err := GetTenantDB(accountID)
	return tenantDB, accountID, err
}

func HandleLiffRooms(_ *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}
		if r.Method != http.MethodGet {
			http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
			return
		}
		// Keep the route so stale clients receive an explicit response, but never
		// expose the dorm's room inventory. The current LIFF flow discovers one
		// exact room only after verifying the resident's phone number.
		http.Error(w, `{"error":"กรุณากรอกเบอร์โทรศัพท์เพื่อค้นหาห้อง"}`, http.StatusGone)
	}
}

func HandleLiffVerify(master *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}
		if r.Method != http.MethodPost {
			http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
			return
		}
		if !allowRequestAttempt(r, "liff-verify", 8, 15*time.Minute) {
			http.Error(w, `{"error":"ตรวจสอบข้อมูลบ่อยเกินไป กรุณารอ 15 นาที"}`, http.StatusTooManyRequests)
			return
		}
		var request LiffVerifyRequest
		if json.NewDecoder(r.Body).Decode(&request) != nil {
			http.Error(w, `{"error":"ข้อมูลไม่ถูกต้อง"}`, http.StatusBadRequest)
			return
		}
		request.RoomNumber = strings.TrimSpace(request.RoomNumber)
		request.Phone = strings.TrimSpace(request.Phone)
		if normalizePhone(request.Phone) == "" {
			http.Error(w, `{"error":"กรุณากรอกเบอร์โทรศัพท์ที่แจ้งกับหอพัก"}`, http.StatusBadRequest)
			return
		}
		db, _, err := lineLinkTenantDB(master)
		if err != nil {
			http.Error(w, `{"error":"ยังไม่พร้อมเชื่อมบัญชี LINE กรุณาติดต่อผู้ดูแลหอพัก"}`, http.StatusServiceUnavailable)
			return
		}

		var name, roomNumber string
		if request.RoomNumber == "" {
			roomNumber, name, err = findLineTenantByPhone(db, request.Phone)
		} else {
			// Keep accepting room_number for older LIFF clients while the current UI
			// discovers the room from the phone number instead.
			name, err = verifyLineTenant(db, request.RoomNumber, request.Phone)
			roomNumber = request.RoomNumber
		}
		if err != nil {
			http.Error(w, `{"error":"ไม่พบข้อมูลที่ตรงกับเบอร์นี้ กรุณาตรวจสอบเบอร์หรือติดต่อผู้ดูแลหอพัก"}`, http.StatusUnauthorized)
			return
		}
		writeLineJSON(w, http.StatusOK, map[string]string{
			"masked_name": firstNameOnly(name),
			"room_number": roomNumber,
		})
	}
}

func HandleLiffLink(master *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}
		if r.Method != http.MethodPost {
			http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
			return
		}
		if !allowRequestAttempt(r, "liff-link", 8, 15*time.Minute) {
			http.Error(w, `{"error":"เชื่อมบัญชีบ่อยเกินไป กรุณารอ 15 นาที"}`, http.StatusTooManyRequests)
			return
		}
		var request LiffLinkRequest
		if json.NewDecoder(r.Body).Decode(&request) != nil {
			http.Error(w, `{"error":"ข้อมูลไม่ถูกต้อง"}`, http.StatusBadRequest)
			return
		}
		request.AccessToken = strings.TrimSpace(request.AccessToken)
		request.RoomNumber = strings.TrimSpace(request.RoomNumber)
		request.Phone = strings.TrimSpace(request.Phone)
		if request.AccessToken == "" || request.RoomNumber == "" || request.Phone == "" {
			http.Error(w, `{"error":"กรุณาเลือกห้อง กรอกเบอร์โทร และอนุญาตการเชื่อมต่อ LINE"}`, http.StatusBadRequest)
			return
		}

		lineUserID, err := verifiedLineUserID(request.AccessToken)
		if err != nil {
			http.Error(w, `{"error":"การยืนยันตัวตนกับ LINE ล้มเหลว"}`, http.StatusUnauthorized)
			return
		}
		tenantDB, accountID, err := lineLinkTenantDB(master)
		if err != nil {
			http.Error(w, `{"error":"ยังไม่พร้อมเชื่อมบัญชี LINE กรุณาติดต่อผู้ดูแลหอพัก"}`, http.StatusServiceUnavailable)
			return
		}
		if _, err := verifyLineTenant(tenantDB, request.RoomNumber, request.Phone); err != nil {
			http.Error(w, `{"error":"เลขห้องหรือเบอร์โทรศัพท์ไม่ถูกต้อง"}`, http.StatusUnauthorized)
			return
		}
		var tenantID string
		if err := tenantDB.QueryRow(`SELECT external_id FROM users WHERE room_number = ?
			AND status IN ('active', 'กำลังพักอาศัย', 'จอง')`, request.RoomNumber).Scan(&tenantID); err != nil || tenantID == "" {
			http.Error(w, `{"error":"ไม่พบลูกบ้านของห้องนี้ในข้อมูลล่าสุด"}`, http.StatusNotFound)
			return
		}

		tx, err := master.Begin()
		if err != nil {
			http.Error(w, `{"error":"บันทึกการเชื่อมต่อไม่สำเร็จ"}`, http.StatusInternalServerError)
			return
		}
		defer tx.Rollback()
		now := time.Now().UTC().Format(time.RFC3339)
		if _, err = tx.Exec(`DELETE FROM line_links WHERE account_id = ? AND tenant_id = ?`, accountID, tenantID); err == nil {
			_, err = tx.Exec(`INSERT INTO line_links(line_user_id, account_id, tenant_id, status, legacy_room, linked_at, updated_at)
				VALUES (?, ?, ?, 'linked', '', ?, ?)
				ON CONFLICT(line_user_id) DO UPDATE SET account_id=excluded.account_id, tenant_id=excluded.tenant_id,
				status='linked', legacy_room='', linked_at=excluded.linked_at, updated_at=excluded.updated_at`,
				lineUserID, accountID, tenantID, now, now)
		}
		if err != nil || tx.Commit() != nil {
			http.Error(w, `{"error":"บันทึกการเชื่อมต่อไม่สำเร็จ"}`, http.StatusInternalServerError)
			return
		}
		if _, err := tenantDB.Exec(`UPDATE users SET line_user_id = CASE WHEN external_id = ? THEN ? ELSE '' END
			WHERE external_id != ''`, tenantID, lineUserID); err != nil {
			master.Exec(`UPDATE line_links SET status = 'pending_relink', updated_at = ? WHERE line_user_id = ?`, now, lineUserID)
			http.Error(w, `{"error":"เชื่อม LINE แล้วแต่ปรับข้อมูลห้องไม่สำเร็จ กรุณาลองใหม่"}`, http.StatusInternalServerError)
			return
		}

		go PushLineMessage(lineUserID, fmt.Sprintf("ผูกบัญชี LINE กับห้อง %s สำเร็จแล้วค่ะ ระบบจะส่งบิลและการแจ้งเตือนของคุณผ่านแชทนี้", request.RoomNumber))
		writeLineJSON(w, http.StatusOK, map[string]string{"message": "success", "room_number": request.RoomNumber})
	}
}

func verifyLineTenant(db *sql.DB, roomNumber, inputPhone string) (string, error) {
	roomNumber = strings.TrimSpace(roomNumber)
	inputPhone = normalizePhone(inputPhone)
	if roomNumber == "" || inputPhone == "" {
		return "", sql.ErrNoRows
	}
	var name, storedPhone string
	err := db.QueryRow(`SELECT full_name, phone FROM users WHERE room_number = ?
		AND status IN ('active', 'กำลังพักอาศัย', 'จอง')`, roomNumber).Scan(&name, &storedPhone)
	if err != nil || normalizePhone(storedPhone) != inputPhone {
		return "", sql.ErrNoRows
	}
	return name, nil
}

func findLineTenantByPhone(db *sql.DB, inputPhone string) (string, string, error) {
	inputPhone = normalizePhone(inputPhone)
	if inputPhone == "" {
		return "", "", sql.ErrNoRows
	}

	rows, err := db.Query(`SELECT room_number, full_name, COALESCE(phone, '') FROM users
		WHERE status IN ('active', 'กำลังพักอาศัย', 'จอง')`)
	if err != nil {
		return "", "", err
	}
	defer rows.Close()

	var matchedRoom, matchedName string
	matches := 0
	for rows.Next() {
		var roomNumber, name, storedPhone string
		if err := rows.Scan(&roomNumber, &name, &storedPhone); err != nil {
			return "", "", err
		}
		if normalizePhone(storedPhone) != inputPhone {
			continue
		}
		matches++
		matchedRoom = strings.TrimSpace(roomNumber)
		matchedName = name
		if matches > 1 {
			// A shared or duplicated phone number must never select a room
			// implicitly. The resident has to contact the dorm administrator.
			return "", "", sql.ErrNoRows
		}
	}
	if err := rows.Err(); err != nil {
		return "", "", err
	}
	if matches != 1 || matchedRoom == "" {
		return "", "", sql.ErrNoRows
	}
	return matchedRoom, matchedName, nil
}

func normalizePhone(value string) string {
	replacer := strings.NewReplacer("-", "", " ", "", "(", "", ")", "")
	return replacer.Replace(strings.TrimSpace(value))
}

func firstNameOnly(name string) string {
	name = strings.TrimSpace(name)
	for _, prefix := range []string{"นาย", "นางสาว", "นาง", "น.ส.", "ด.ช.", "ด.ญ.", "Mr.", "Mrs.", "Ms."} {
		name = strings.TrimSpace(strings.TrimPrefix(name, prefix))
	}
	if parts := strings.Fields(name); len(parts) > 0 {
		return parts[0]
	}
	return name
}

func verifiedLineUserID(accessToken string) (string, error) {
	client := &http.Client{Timeout: 10 * time.Second}
	verifyURL := "https://api.line.me/oauth2/v2.1/verify?access_token=" + url.QueryEscape(accessToken)
	response, err := client.Get(verifyURL)
	if err != nil {
		return "", err
	}
	if response.StatusCode != http.StatusOK {
		response.Body.Close()
		return "", fmt.Errorf("LINE verify status %d", response.StatusCode)
	}
	var verification struct {
		ClientID  string `json:"client_id"`
		ExpiresIn int64  `json:"expires_in"`
	}
	if err := json.NewDecoder(response.Body).Decode(&verification); err != nil {
		response.Body.Close()
		return "", fmt.Errorf("decode LINE verification: %w", err)
	}
	response.Body.Close()
	expectedClientID := strings.TrimSpace(os.Getenv("LINE_LIFF_CHANNEL_ID"))
	if expectedClientID == "" || verification.ClientID != expectedClientID || verification.ExpiresIn <= 0 {
		return "", fmt.Errorf("LINE access token is not valid for this LIFF channel")
	}
	request, err := http.NewRequest(http.MethodGet, "https://api.line.me/v2/profile", nil)
	if err != nil {
		return "", err
	}
	request.Header.Set("Authorization", "Bearer "+accessToken)
	response, err = client.Do(request)
	if err != nil {
		return "", err
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return "", fmt.Errorf("LINE profile status %d", response.StatusCode)
	}
	var profile struct {
		UserID string `json:"userId"`
	}
	if json.NewDecoder(response.Body).Decode(&profile) != nil || profile.UserID == "" {
		return "", fmt.Errorf("LINE profile has no user id")
	}
	return profile.UserID, nil
}
