package handlers

import (
	"crypto/rand"
	"database/sql"
	"dorm_os/utils"
	"encoding/json"
	"fmt"
	"math/big"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/resend/resend-go/v3"
)

const maxOTPAttempts = 5
const otpLockDuration = 15 * time.Minute
const maxOTPRequests = 3
const otpRequestCooldown = 15 * time.Minute

func ensureAuthRateLimitTable(db *sql.DB) error {
	_, err := db.Exec(`CREATE TABLE IF NOT EXISTS auth_rate_limits (
		scope TEXT NOT NULL,
		identifier TEXT NOT NULL,
		attempts INTEGER NOT NULL,
		expires_at TEXT NOT NULL,
		PRIMARY KEY (scope, identifier)
	)`)
	return err
}

// recordAuthRateLimit uses a single SQLite upsert so limits survive restarts
// and are shared by every process using the same master database.
func recordAuthRateLimit(db *sql.DB, scope, identifier string, window time.Duration) (int, error) {
	if err := ensureAuthRateLimitTable(db); err != nil {
		return 0, err
	}
	now := time.Now().UTC().Format(time.RFC3339Nano)
	expiresAt := time.Now().UTC().Add(window).Format(time.RFC3339Nano)
	if _, err := db.Exec("DELETE FROM auth_rate_limits WHERE expires_at <= ?", now); err != nil {
		return 0, err
	}
	var attempts int
	err := db.QueryRow(`
		INSERT INTO auth_rate_limits (scope, identifier, attempts, expires_at)
		VALUES (?, ?, 1, ?)
		ON CONFLICT(scope, identifier) DO UPDATE SET
			attempts = CASE WHEN auth_rate_limits.expires_at <= ? THEN 1 ELSE auth_rate_limits.attempts + 1 END,
			expires_at = CASE WHEN auth_rate_limits.expires_at <= ? THEN excluded.expires_at ELSE auth_rate_limits.expires_at END
		RETURNING attempts
	`, scope, identifier, expiresAt, now, now).Scan(&attempts)
	return attempts, err
}

func authRateLimitLocked(db *sql.DB, scope, identifier string, threshold int) (bool, error) {
	if err := ensureAuthRateLimitTable(db); err != nil {
		return false, err
	}
	var attempts int
	err := db.QueryRow(`
		SELECT attempts FROM auth_rate_limits
		WHERE scope = ? AND identifier = ? AND expires_at > ?
	`, scope, identifier, time.Now().UTC().Format(time.RFC3339Nano)).Scan(&attempts)
	if err == sql.ErrNoRows {
		return false, nil
	}
	return attempts >= threshold, err
}

func clearOTPAttempts(db *sql.DB, email string) error {
	if err := ensureAuthRateLimitTable(db); err != nil {
		return err
	}
	_, err := db.Exec("DELETE FROM auth_rate_limits WHERE scope = 'otp_failure' AND identifier = ?", email)
	return err
}

// generateOTP creates a random 6-digit string
func generateOTP() (string, error) {
	max := big.NewInt(1000000)
	n, err := rand.Int(rand.Reader, max)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%06d", n.Int64()), nil
}

// sendEmailOTP sends an email using Resend API
func sendEmailOTP(toEmail string, otp string, refCode string) error {
	apiKey := os.Getenv("RESEND_API_KEY")
	if apiKey == "" {
		return fmt.Errorf("RESEND_API_KEY is not set in .env")
	}
	client := resend.NewClient(apiKey)

	now := time.Now().In(time.FixedZone("ICT", 7*3600))
	monthsTh := []string{"มกราคม", "กุมภาพันธ์", "มีนาคม", "เมษายน", "พฤษภาคม", "มิถุนายน", "กรกฎาคม", "สิงหาคม", "กันยายน", "ตุลาคม", "พฤศจิกายน", "ธันวาคม"}
	timeStr := fmt.Sprintf("%d %s %d, %02d:%02d น.", now.Day(), monthsTh[now.Month()-1], now.Year(), now.Hour(), now.Minute())


	htmlContent := fmt.Sprintf(`
		<!DOCTYPE html>
		<html lang="th">
		<head>
			<meta charset="UTF-8">
			<meta name="viewport" content="width=device-width, initial-scale=1.0">
			<meta name="color-scheme" content="light dark">
			<meta name="supported-color-schemes" content="light dark">
			<title>รหัส OTP สำหรับรีเซ็ตรหัสผ่าน</title>
			<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
			<style>
				body { margin: 0; padding: 0; background-color: #f4f5f7; font-family: 'Inter', -apple-system, sans-serif; color: #111827; -webkit-text-size-adjust: 100%%; }
				table { border-collapse: collapse; width: 100%%; }
				
				.wrapper { padding: 40px 20px; }
				.card { max-width: 560px; margin: 0 auto; background-color: #ffffff; border: 1px solid #e5e7eb; border-radius: 8px; box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05); }
				.header { padding: 32px 40px; border-bottom: 1px solid #e5e7eb; text-align: center; }
				.content { padding: 40px; }
				
				h1, h2, h3, p { margin: 0; }
				.brand { font-size: 26px; font-weight: 700; color: #111827; letter-spacing: -0.5px; }
				.brand span { color: #4f46e5; }
				
				.greeting { font-size: 18px; font-weight: 700; color: #111827; margin-bottom: 16px; }
				.message { font-size: 15px; color: #4b5563; line-height: 1.6; margin-bottom: 32px; }
				
				.otp-container { background-color: #f9fafb; border: 1px solid #e5e7eb; border-radius: 8px; padding: 32px; text-align: center; margin-bottom: 32px; }
				.otp-label { font-size: 13px; font-weight: 600; color: #6b7280; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 12px; }
				.otp-number { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: 42px; font-weight: 700; color: #4f46e5; letter-spacing: 12px; margin-right: -12px; }
				.otp-warning { margin-top: 16px; font-size: 13px; color: #4b5563; }
				
				.section-title { font-size: 14px; font-weight: 700; color: #111827; margin-bottom: 16px; border-left: 3px solid #4f46e5; padding-left: 10px; }
				
				.details-table { background-color: #ffffff; border-radius: 6px; margin-bottom: 32px; border: 1px solid #e5e7eb; }
				.details-table td { padding: 14px 16px; border-bottom: 1px solid #e5e7eb; font-size: 14px; line-height: 1.4; }
				.details-table tr:last-child td { border-bottom: none; }
				.key { color: #6b7280; width: 35%%; font-weight: 500; }
				.value { color: #111827; font-weight: 600; text-align: right; }
				
				.tips-box { background-color: #f9fafb; border: 1px solid #e5e7eb; border-radius: 6px; padding: 20px; }
				.tip-title { font-size: 13px; font-weight: 700; color: #111827; margin-bottom: 6px; }
				.tip-desc { font-size: 13px; color: #6b7280; line-height: 1.5; margin-bottom: 16px; }
				.tip-desc:last-child { margin-bottom: 0; }
				
				.footer { background-color: #ffffff; padding: 32px 40px; text-align: center; border-top: 1px solid #e5e7eb; border-radius: 0 0 8px 8px; }
				.footer-links { margin-bottom: 16px; }
				.footer-links a { color: #4f46e5; text-decoration: none; font-size: 13px; font-weight: 500; margin: 0 10px; display: inline-block; white-space: nowrap; }
				.footer-text { font-size: 12px; color: #9ca3af; line-height: 1.6; }

				@media (prefers-color-scheme: dark) {
					body { background-color: #0f1115 !important; color: #f9fafb !important; }
					.card { background-color: #1a1d24 !important; border-color: #2a2e37 !important; box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2); }
					.header { border-bottom-color: #2a2e37 !important; }
					.brand { color: #f9fafb !important; }
					.brand span { color: #818cf8 !important; }
					
					.greeting { color: #f9fafb !important; }
					.message { color: #9ca3af !important; }
					
					.otp-container { background-color: #14161b !important; border-color: #2a2e37 !important; }
					.otp-label { color: #6b7280 !important; }
					.otp-number { color: #818cf8 !important; }
					.otp-warning { color: #9ca3af !important; }
					
					.section-title { color: #f9fafb !important; border-left-color: #818cf8 !important; }
					
					.details-table { background-color: #14161b !important; border-color: #2a2e37 !important; }
					.details-table td { border-bottom-color: #2a2e37 !important; }
					.key { color: #9ca3af !important; }
					.value { color: #f9fafb !important; }
					
					.tips-box { background-color: #14161b !important; border-color: #2a2e37 !important; }
					.tip-title { color: #f9fafb !important; }
					.tip-desc { color: #9ca3af !important; }
					
					.footer { background-color: #1a1d24 !important; border-top-color: #2a2e37 !important; }
					.footer-links a { color: #818cf8 !important; }
					.footer-text { color: #6b7280 !important; }
				}
			</style>
		</head>
		<body>
			<table class="wrapper">
				<tr>
					<td align="center">
						<table class="card" cellspacing="0" cellpadding="0">
							<!-- Header -->
							<tr>
								<td class="header">
									<div class="brand">Dormi<span>Net</span></div>
								</td>
							</tr>
							
							<!-- Content -->
							<tr>
								<td class="content">
									<h2 class="greeting">เรียน ผู้ใช้งานระบบ</h2>
									<p class="message">
										เราได้รับการร้องขอให้ตั้งรหัสผ่านใหม่สำหรับบัญชีของท่าน (<b>%s</b>) ผ่านแอปพลิเคชัน หากท่านเป็นผู้ทำรายการ โปรดใช้รหัสยืนยันตัวตน (OTP) ด้านล่างนี้เพื่อดำเนินการต่อ
									</p>

									<!-- OTP -->
									<div class="otp-container">
										<div class="otp-label">รหัสยืนยันตัวตน (OTP)</div>
										<div class="otp-number">%s</div>
										<div class="otp-warning">รหัสผ่านชั่วคราวนี้จะหมดอายุภายใน 15 นาที</div>
									</div>

									<!-- Details -->
									<h3 class="section-title">ข้อมูลการทำรายการ</h3>
									<table class="details-table" cellspacing="0" cellpadding="0">
										<tr>
											<td class="key">หมายเลขอ้างอิง</td>
											<td class="value">%s</td>
										</tr>
										<tr>
											<td class="key">บัญชีผู้ใช้</td>
											<td class="value">%s</td>
										</tr>
										<tr>
											<td class="key">เวลาที่บันทึก</td>
											<td class="value">%s</td>
										</tr>
										<tr>
											<td class="key">สถานะ</td>
											<td class="value">รอการยืนยันรหัส OTP</td>
										</tr>
									</table>

									<!-- Security Tips -->
									<h3 class="section-title">ข้อแนะนำด้านความปลอดภัย</h3>
									<div class="tips-box">
										<div class="tip-title">หากท่านไม่ได้ทำรายการนี้</div>
										<div class="tip-desc">โปรดเพิกเฉยต่ออีเมลฉบับนี้ บัญชีของท่านยังคงปลอดภัยตราบใดที่ไม่มีผู้ใดทราบรหัส OTP ห้ามเปิดเผยรหัสนี้แก่บุคคลอื่นโดยเด็ดขาด รวมถึงเจ้าหน้าที่ของ DormiNet</div>
										
										<div class="tip-title">การตั้งรหัสผ่านใหม่</div>
										<div class="tip-desc">รหัสผ่านควรมีความยาวอย่างน้อย 8 ตัวอักษร ประกอบด้วยตัวอักษรพิมพ์เล็ก พิมพ์ใหญ่ และตัวเลข ไม่ควรใช้ข้อมูลส่วนตัวที่คาดเดาได้ง่าย</div>
									</div>

								</td>
							</tr>
							
							<!-- Footer -->
							<tr>
								<td class="footer">
									<div class="footer-links">
										<a href="https://dorminet.studio/contact">ติดต่อผู้ดูแลระบบ</a>
										<a href="https://dorminet.studio/privacy">นโยบายความเป็นส่วนตัว</a>
										<a href="https://dorminet.studio/terms">ข้อกำหนดการใช้งาน</a>
									</div>
									<p class="footer-text">
										ข้อมูลนี้ถูกส่งโดยระบบอัตโนมัติ กรุณาอย่าตอบกลับอีเมลฉบับนี้<br>
										สงวนลิขสิทธิ์ &copy; 2026 DormiNet System<br>
										อาคารหอพัก DormiNet, อุบลราชธานี, ประเทศไทย
									</p>
								</td>
							</tr>
						</table>
					</td>
				</tr>
			</table>
		</body>
		</html>
	`, toEmail, otp, refCode, toEmail, timeStr)

	params := &resend.SendEmailRequest{
		From:    "DormiNet <noreply@dorminet.studio>",
		To:      []string{toEmail},
		Subject: "รหัส OTP สำหรับรีเซ็ตรหัสผ่าน (DormiNet)",
		Html:    htmlContent,
	}

	sent, err := client.Emails.Send(params)
	if err != nil {
		fmt.Printf("failed to send email via resend: %v\n", err)
		return err
	}

	fmt.Printf("email sent: %s\n", sent.Id)
	return nil
}

func HandleForgotPassword(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method != "POST" {
			http.Error(w, `{"error": "Method not allowed"}`, http.StatusMethodNotAllowed)
			return
		}

		var req struct {
			Email string `json:"email"`
		}
		r.Body = http.MaxBytesReader(w, r.Body, 8192)
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Email == "" {
			http.Error(w, `{"error": "กรุณาระบุอีเมล"}`, http.StatusBadRequest)
			return
		}
		req.Email = strings.ToLower(strings.TrimSpace(req.Email))
		if !isValidEmail(req.Email) {
			http.Error(w, `{"error":"กรุณาระบุอีเมล"}`, http.StatusBadRequest)
			return
		}

		if !allowRequestAttempt(r, "forgot-password-ip", 20, time.Hour) {
			http.Error(w, `{"error": "คุณขอรหัส OTP บ่อยเกินไป กรุณารอ 15 นาทีแล้วลองใหม่"}`, http.StatusTooManyRequests)
			return
		}
		attempts, err := recordAuthRateLimit(db, "otp_request", req.Email, otpRequestCooldown)
		if err != nil {
			http.Error(w, `{"error":"ระบบขัดข้อง กรุณาลองใหม่"}`, http.StatusInternalServerError)
			return
		}
		if attempts > maxOTPRequests {
			http.Error(w, `{"error": "คุณขอรหัส OTP บ่อยเกินไป กรุณารอ 15 นาทีแล้วลองใหม่"}`, http.StatusTooManyRequests)
			return
		}

		// ตอบกลับข้อความเดียวกันทุกกรณี เพื่อป้องกัน User Enumeration
		successMsg := "หากอีเมลนี้อยู่ในระบบ คุณจะได้รับรหัส OTP ภายใน 5 นาที"

		// Generate RefCode here so it can be returned
		now := time.Now().In(time.FixedZone("ICT", 7*3600))
		b := make([]byte, 2)
		rand.Read(b)
		refCode := fmt.Sprintf("REQ-%s-%X", now.Format("20060102"), b)

		// Check if email exists in admins table
		var id int
		err = db.QueryRow("SELECT id FROM admins WHERE email = ?", req.Email).Scan(&id)
		if err != nil {
			// Email not found — but respond with same message to prevent enumeration
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(map[string]string{"message": successMsg, "ref_code": refCode})
			return
		}

		otp, err := generateOTP()
		if err != nil {
			http.Error(w, `{"error":"สร้างรหัสยืนยันไม่สำเร็จ กรุณาลองใหม่"}`, http.StatusInternalServerError)
			return
		}
		expiresAt := time.Now().Add(15 * time.Minute).Format(time.RFC3339)

		// The unique email index plus one statement guarantees that concurrent
		// requests leave exactly one active OTP for the account.
		_, err = db.Exec("INSERT OR REPLACE INTO password_resets (email, token, expires_at) VALUES (?, ?, ?)", req.Email, otp, expiresAt)
		if err != nil {
			http.Error(w, `{"error": "ระบบขัดข้อง กรุณาลองใหม่"}`, http.StatusInternalServerError)
			return
		}

		// Send Email
		if err := sendEmailOTP(req.Email, otp, refCode); err != nil {
			fmt.Println("Error sending email:", err)
			// ยังคงตอบกลับ success เพื่อไม่ให้รู้ว่าส่งไม่ได้
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"message": successMsg, "ref_code": refCode})
	}
}

func HandleVerifyOTP(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method != "POST" {
			http.Error(w, `{"error": "Method not allowed"}`, http.StatusMethodNotAllowed)
			return
		}

		var req struct {
			Email string `json:"email"`
			OTP   string `json:"otp"`
		}
		r.Body = http.MaxBytesReader(w, r.Body, 8192)
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Email == "" || req.OTP == "" {
			http.Error(w, `{"error": "ข้อมูลไม่ครบถ้วน"}`, http.StatusBadRequest)
			return
		}
		req.Email = strings.ToLower(strings.TrimSpace(req.Email))
		if !isValidEmail(req.Email) || len(req.OTP) != 6 {
			http.Error(w, `{"error":"ข้อมูลไม่ถูกต้อง"}`, http.StatusBadRequest)
			return
		}

		// Rate limit check
		locked, err := authRateLimitLocked(db, "otp_failure", req.Email, maxOTPAttempts)
		if err != nil {
			http.Error(w, `{"error":"ระบบขัดข้อง กรุณาลองใหม่"}`, http.StatusInternalServerError)
			return
		}
		if locked {
			http.Error(w, `{"error": "กรอกผิดเกินจำนวนครั้งที่กำหนด กรุณารอ 15 นาทีแล้วลองใหม่"}`, http.StatusTooManyRequests)
			return
		}

		// Verify OTP
		var expiresAtStr string
		err = db.QueryRow("SELECT expires_at FROM password_resets WHERE email = ? AND token = ?", req.Email, req.OTP).Scan(&expiresAtStr)
		if err != nil {
			attempts, rateErr := recordAuthRateLimit(db, "otp_failure", req.Email, otpLockDuration)
			if rateErr != nil {
				http.Error(w, `{"error":"ระบบขัดข้อง กรุณาลองใหม่"}`, http.StatusInternalServerError)
			} else if attempts >= maxOTPAttempts {
				http.Error(w, `{"error": "กรอกผิดเกินจำนวนครั้งที่กำหนด กรุณารอ 15 นาทีแล้วลองใหม่"}`, http.StatusTooManyRequests)
			} else {
				http.Error(w, `{"error": "รหัส OTP ไม่ถูกต้อง"}`, http.StatusUnauthorized)
			}
			return
		}

		expiresAt, _ := time.Parse(time.RFC3339, expiresAtStr)

		if time.Now().After(expiresAt) {
			db.Exec("DELETE FROM password_resets WHERE email = ? AND token = ?", req.Email, req.OTP)
			http.Error(w, `{"error": "รหัส OTP หมดอายุแล้ว กรุณาขอใหม่"}`, http.StatusUnauthorized)
			return
		}

		if err := clearOTPAttempts(db, req.Email); err != nil {
			http.Error(w, `{"error":"ระบบขัดข้อง กรุณาลองใหม่"}`, http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"message": "รหัส OTP ถูกต้อง"})
	}
}

func SetupAuthResetRoutes(db *sql.DB) {
	http.HandleFunc("/api/forgot-password", HandleForgotPassword(db))
	http.HandleFunc("/api/verify-otp", HandleVerifyOTP(db))
	http.HandleFunc("/api/reset-password", HandlePasswordReset(db))
}
