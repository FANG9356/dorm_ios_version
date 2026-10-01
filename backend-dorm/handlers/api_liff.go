package handlers

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"math"
	"net"
	"net/http"
	"net/url"
	"os"
	"strconv"
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
	DormCode    string `json:"dorm_code"`
	AccessToken string `json:"access_token"`
	RoomNumber  string `json:"room_number"`
	Phone       string `json:"phone"`
}

type LiffVerifyRequest struct {
	DormCode   string `json:"dorm_code"`
	RoomNumber string `json:"room_number"`
	Phone      string `json:"phone"`
}

type LiffStatusRequest struct {
	AccessToken string `json:"access_token"`
}

type liffTokenVerifier func(string) (string, error)
type liffTenantDBOpener func(int) (*sql.DB, error)

type LiffResidentSummary struct {
	FullName           string `json:"full_name"`
	RoomNumber         string `json:"room_number"`
	RoomType           string `json:"room_type"`
	Status             string `json:"status"`
	MoveInDate         string `json:"move_in_date"`
	ContractEndDate    string `json:"contract_end_date"`
	IndefiniteContract bool   `json:"indefinite_contract"`
}

type LiffBillingSummary struct {
	OutstandingCount  int                  `json:"outstanding_count"`
	OutstandingAmount float64              `json:"outstanding_amount"`
	ProjectedBill     float64              `json:"projected_bill"`
	Invoices          []LiffInvoiceSummary `json:"invoices"`
}

type LiffInvoiceSummary struct {
	InvoiceNumber    string  `json:"invoice_number"`
	Period           string  `json:"period"`
	DueDate          string  `json:"due_date"`
	UpdatedAt        string  `json:"updated_at"`
	PaymentDate      string  `json:"payment_date"`
	Status           string  `json:"status"`
	InstallmentPhase int     `json:"installment_phase"`
	RentFee          float64 `json:"rent_fee"`
	DepositFee       float64 `json:"deposit_fee"`
	WaterFee         float64 `json:"water_fee"`
	ElectricFee      float64 `json:"electric_fee"`
	CommonFee        float64 `json:"common_fee"`
	ApplianceFee     float64 `json:"appliance_fee"`
	LateFee          float64 `json:"late_fee"`
	OtherFee         float64 `json:"other_fee"`
	Amount           float64 `json:"amount"`
	PaidAmount       float64 `json:"paid_amount"`
	Balance          float64 `json:"balance"`
	Outstanding      bool    `json:"outstanding"`
}

type LiffLinkedSummary struct {
	Resident LiffResidentSummary `json:"resident"`
	Billing  LiffBillingSummary  `json:"billing"`
}

func resolveTenantDBFromCode(master *sql.DB, code string) (*sql.DB, int, error) {
	code = strings.TrimSpace(code)
	if code == "" {
		return nil, 0, fmt.Errorf("กรุณากรอกรหัสหอพัก")
	}

	// Tenant databases are owned by superadmin accounts. Validate against the
	// master database before opening one so a guessed code cannot create an
	// empty tenant database on disk.
	var ownerID int
	if err := master.QueryRow(`SELECT id FROM admins WHERE dorm_code = ? AND role = 'superadmin'`, code).Scan(&ownerID); err != nil {
		if err == sql.ErrNoRows {
			// Fallback for legacy numerical ID in case it hasn't migrated or users are still using it during transition
			accountID, errAtoi := strconv.Atoi(code)
			if errAtoi == nil {
				if err := master.QueryRow(`SELECT id FROM admins WHERE id = ? AND role = 'superadmin'`, accountID).Scan(&ownerID); err == nil {
					goto found
				}
			}
			return nil, 0, fmt.Errorf("ไม่พบข้อมูลหอพักรหัสนี้")
		}
		return nil, 0, fmt.Errorf("ตรวจสอบรหัสหอพักไม่สำเร็จ")
	}
found:

	tenantDB, err := GetTenantDB(ownerID)
	if err != nil {
		return nil, 0, fmt.Errorf("ไม่พบข้อมูลหอพักรหัสนี้")
	}
	return tenantDB, ownerID, nil
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

func HandleLiffStatus(master *sql.DB) http.HandlerFunc {
	return handleLiffStatus(master, verifiedLineUserID, GetTenantDB)
}

func handleLiffStatus(master *sql.DB, verifyToken liffTokenVerifier, openTenantDB liffTenantDBOpener) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}
		if r.Method != http.MethodPost {
			http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
			return
		}
		if !allowRequestAttempt(r, "liff-status", 60, 5*time.Minute) {
			http.Error(w, `{"error":"ตรวจสอบสถานะบ่อยเกินไป กรุณาลองใหม่ภายหลัง"}`, http.StatusTooManyRequests)
			return
		}

		var request LiffStatusRequest
		decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 16<<10))
		if decoder.Decode(&request) != nil || strings.TrimSpace(request.AccessToken) == "" {
			http.Error(w, `{"error":"ไม่พบข้อมูลยืนยันตัวตนจาก LINE"}`, http.StatusBadRequest)
			return
		}
		lineUserID, err := verifyToken(strings.TrimSpace(request.AccessToken))
		if err != nil {
			http.Error(w, `{"error":"การยืนยันตัวตนกับ LINE ล้มเหลว"}`, http.StatusUnauthorized)
			return
		}

		summary, err := lookupLinkedResident(master, openTenantDB, lineUserID)
		if err == sql.ErrNoRows {
			writeLineJSON(w, http.StatusOK, map[string]interface{}{"linked": false})
			return
		}
		if err != nil {
			http.Error(w, `{"error":"ตรวจสอบสถานะการเชื่อมต่อไม่สำเร็จ"}`, http.StatusInternalServerError)
			return
		}
		writeLineJSON(w, http.StatusOK, map[string]interface{}{
			"linked":      true,
			"room_number": summary.Resident.RoomNumber,
			"resident":    summary.Resident,
			"billing":     summary.Billing,
		})
	}
}

func lookupLinkedResident(master *sql.DB, openTenantDB liffTenantDBOpener, lineUserID string) (LiffLinkedSummary, error) {
	var summary LiffLinkedSummary
	var accountID int
	var tenantID string
	if err := master.QueryRow(`SELECT account_id, tenant_id FROM line_links
		WHERE line_user_id = ? AND status = 'linked' AND tenant_id != ''`, lineUserID).Scan(&accountID, &tenantID); err != nil {
		return summary, err
	}
	tenantDB, err := openTenantDB(accountID)
	if err != nil {
		return summary, err
	}
	var userID int
	var indefiniteContract int
	err = tenantDB.QueryRow(`SELECT u.user_id, COALESCE(u.full_name, ''), u.room_number,
		COALESCE(r.room_type, ''), COALESCE(u.status, ''), COALESCE(u.move_in_date, ''),
		COALESCE(u.contract_end_date, ''), COALESCE(u.indefinite_contract, 0)
		FROM users u LEFT JOIN rooms r ON r.room_number = u.room_number
		WHERE u.external_id = ? AND u.line_user_id = ?
		AND u.status IN ('active', 'กำลังพักอาศัย', 'จอง')`, tenantID, lineUserID).Scan(
		&userID, &summary.Resident.FullName, &summary.Resident.RoomNumber, &summary.Resident.RoomType,
		&summary.Resident.Status, &summary.Resident.MoveInDate, &summary.Resident.ContractEndDate,
		&indefiniteContract,
	)
	if err != nil || strings.TrimSpace(summary.Resident.RoomNumber) == "" {
		if err == nil {
			err = sql.ErrNoRows
		}
		return summary, err
	}
	summary.Resident.FullName = strings.TrimSpace(summary.Resident.FullName)
	summary.Resident.RoomNumber = strings.TrimSpace(summary.Resident.RoomNumber)
	summary.Resident.RoomType = strings.TrimSpace(summary.Resident.RoomType)
	summary.Resident.IndefiniteContract = indefiniteContract != 0

	if err := tenantDB.QueryRow(`SELECT COUNT(*), COALESCE(SUM(
		CASE WHEN amount > COALESCE(paid_amount, 0) THEN amount - COALESCE(paid_amount, 0) ELSE 0 END
	), 0) FROM payments WHERE user_id = ? AND COALESCE(payment_status, 'pending') != 'paid'
	AND amount > COALESCE(paid_amount, 0)`, userID).Scan(
		&summary.Billing.OutstandingCount, &summary.Billing.OutstandingAmount,
	); err != nil {
		return LiffLinkedSummary{}, err
	}

	_ = tenantDB.QueryRow(`SELECT COALESCE(rt.price, 0) + COALESCE(u.additional_appliance_fee, 0)
		FROM users u 
		LEFT JOIN rooms r ON u.room_number = r.room_number
		LEFT JOIN room_types rt ON r.room_type = rt.name
		WHERE u.user_id = ?`, userID).Scan(&summary.Billing.ProjectedBill)

	summary.Billing.Invoices, err = loadLiffInvoices(tenantDB, userID)
	if err != nil {
		return LiffLinkedSummary{}, err
	}
	return summary, nil
}

func loadLiffInvoices(db *sql.DB, userID int) ([]LiffInvoiceSummary, error) {
	query := `SELECT payment_id, COALESCE(month, ''), COALESCE(due_date, ''),
		COALESCE(last_updated, ''), COALESCE(payment_date, ''),
		COALESCE(NULLIF(payment_status, ''), 'pending'), COALESCE(installment_phase, 0),
		COALESCE(rent_fee, 0), COALESCE(deposit_fee, 0), COALESCE(water_fee, 0),
		COALESCE(electric_fee, 0), COALESCE(common_fee, 0), COALESCE(appliance_fee, 0),
		COALESCE(late_fee, 0), COALESCE(amount, 0), COALESCE(paid_amount, 0)
		FROM payments WHERE user_id = ?
		ORDER BY month DESC, installment_phase DESC, payment_id DESC LIMIT 24`

	rows, err := db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	invoices := make([]LiffInvoiceSummary, 0)
	for rows.Next() {
		var paymentID int
		var invoice LiffInvoiceSummary
		if err := rows.Scan(
			&paymentID, &invoice.Period, &invoice.DueDate, &invoice.UpdatedAt, &invoice.PaymentDate,
			&invoice.Status, &invoice.InstallmentPhase, &invoice.RentFee, &invoice.DepositFee,
			&invoice.WaterFee, &invoice.ElectricFee, &invoice.CommonFee, &invoice.ApplianceFee,
			&invoice.LateFee, &invoice.Amount, &invoice.PaidAmount,
		); err != nil {
			return nil, err
		}
		invoice.InvoiceNumber = fmt.Sprintf("INV-%05d", paymentID)
		invoice.Balance = math.Max(invoice.Amount-invoice.PaidAmount, 0)
		invoice.Outstanding = invoice.Status != "paid" && invoice.Balance > 0
		knownTotal := invoice.RentFee + invoice.DepositFee + invoice.WaterFee + invoice.ElectricFee +
			invoice.CommonFee + invoice.ApplianceFee + invoice.LateFee
		if difference := invoice.Amount - knownTotal; math.Abs(difference) >= 0.01 {
			invoice.OtherFee = difference
		}
		invoices = append(invoices, invoice)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return invoices, nil
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
		db, _, err := resolveTenantDBFromCode(master, request.DormCode)
		if err != nil {
			writeLineJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
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
		tenantDB, accountID, err := resolveTenantDBFromCode(master, request.DormCode)
		if err != nil {
			writeLineJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
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
