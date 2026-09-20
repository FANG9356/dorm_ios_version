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
func sendEmailOTP(toEmail string, otp string) error {
	apiKey := os.Getenv("RESEND_API_KEY")
	if apiKey == "" {
		return fmt.Errorf("RESEND_API_KEY is not set in .env")
	}
	client := resend.NewClient(apiKey)

	htmlContent := fmt.Sprintf(`
		<!DOCTYPE html>
		<html lang="th">
		<head>
			<meta charset="UTF-8">
			<meta name="viewport" content="width=device-width, initial-scale=1.0">
			<meta name="color-scheme" content="light dark">
			<meta name="supported-color-schemes" content="light dark">
			<title>รหัส OTP สำหรับรีเซ็ตรหัสผ่าน</title>
			<style>
				/* Base resets */
				body { margin: 0; padding: 0; -webkit-text-size-adjust: 100%%; }
				table { border-collapse: collapse; }
				
				/* Dark Mode Variables & Styles */
				@media (prefers-color-scheme: dark) {
					.bg-body { background-color: #000000 !important; }
					.bg-card { background-color: #1c1c1e !important; }
					.border-card { border-color: #2c2c2e !important; }
					.text-primary { color: #ffffff !important; }
					.text-secondary { color: #98989d !important; }
					.bg-otp { background-color: #2c2c2e !important; border-color: #3a3a3c !important; }
					.text-otp { color: #ffffff !important; }
					.bg-footer { background-color: #121212 !important; border-color: #2c2c2e !important; }
					.text-brand { color: #5e5ce6 !important; }
					.bg-warning { background-color: rgba(255, 69, 58, 0.15) !important; }
					.text-warning { color: #ff453a !important; }
				}
			</style>
		</head>
		<body class="bg-body" style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f2f2f7;">
			<table width="100%%" border="0" cellspacing="0" cellpadding="0" class="bg-body" style="background-color: #f2f2f7; padding: 40px 20px;">
				<tr>
					<td align="center">
						<table border="0" cellspacing="0" cellpadding="0" class="bg-card border-card" style="width: 100%%; max-width: 500px; background-color: #ffffff; border-radius: 16px; border: 1px solid #e5e5ea; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.04);">
							<!-- Header -->
							<tr>
								<td align="center" style="padding: 40px 40px 20px 40px;">
									<h1 class="text-primary" style="margin: 0; font-size: 28px; font-weight: 800; color: #1c1c1e; letter-spacing: -0.5px;">Dormi<span class="text-brand" style="color: #4f46e5;">Net</span></h1>
								</td>
							</tr>
							<!-- Body -->
							<tr>
								<td align="center" style="padding: 0 40px 40px 40px;">
									<h2 class="text-primary" style="margin: 0 0 12px 0; font-size: 20px; font-weight: 600; color: #1c1c1e;">รหัสยืนยันตัวตน (OTP)</h2>
									<p class="text-secondary" style="margin: 0 0 32px 0; font-size: 15px; color: #3a3a3c; line-height: 1.6;">
										คุณได้ทำการร้องขอเพื่อรีเซ็ตรหัสผ่านสำหรับบัญชีของคุณ<br>
										กรุณานำรหัส 6 หลักด้านล่างนี้กรอกในระบบเพื่อดำเนินการต่อ
									</p>
									<!-- OTP Box -->
									<table border="0" cellspacing="0" cellpadding="0" style="margin: 0 auto 24px auto;">
										<tr>
											<td class="bg-otp" align="center" style="background-color: #f2f2f7; border: 1px solid #e5e5ea; border-radius: 12px; padding: 20px 32px;">
												<div class="text-otp" style="margin: 0; font-size: 40px; font-weight: 700; color: #1c1c1e; letter-spacing: 12px; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; text-indent: 12px;">%s</div>
											</td>
										</tr>
									</table>
									<!-- Warning -->
									<table border="0" cellspacing="0" cellpadding="0">
										<tr>
											<td class="bg-warning text-warning" style="background-color: #fef2f2; color: #dc2626; font-size: 13px; font-weight: 600; padding: 8px 16px; border-radius: 20px;">
												รหัสนี้จะหมดอายุภายใน 15 นาที
											</td>
										</tr>
									</table>
								</td>
							</tr>
							<!-- Footer -->
							<tr>
								<td class="bg-footer border-card" align="center" style="background-color: #fafafa; border-top: 1px solid #e5e5ea; padding: 24px 40px;">
									<p class="text-secondary" style="margin: 0 0 8px 0; font-size: 13px; color: #8e8e93; line-height: 1.5;">
										หากคุณไม่ได้เป็นผู้ทำรายการนี้ กรุณาเพิกเฉยต่ออีเมลฉบับนี้ หรือเปลี่ยนรหัสผ่านเพื่อความปลอดภัย
									</p>
									<p class="text-secondary" style="margin: 0; font-size: 12px; color: #aeaeb2;">
										&copy; 2026 DormiNet System. All rights reserved.
									</p>
								</td>
							</tr>
						</table>
					</td>
				</tr>
			</table>
		</body>
		</html>
	`, otp)

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

func SetupAuthResetRoutes(db *sql.DB) {
	http.HandleFunc("/api/forgot-password", func(w http.ResponseWriter, r *http.Request) {
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

		// Check if email exists in admins table
		var id int
		err = db.QueryRow("SELECT id FROM admins WHERE email = ?", req.Email).Scan(&id)
		if err != nil {
			// Email not found — but respond with same message to prevent enumeration
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(map[string]string{"message": successMsg})
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
		if err := sendEmailOTP(req.Email, otp); err != nil {
			fmt.Println("Error sending email:", err)
			// ยังคงตอบกลับ success เพื่อไม่ให้รู้ว่าส่งไม่ได้
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"message": successMsg})
	})

	http.HandleFunc("/api/verify-otp", func(w http.ResponseWriter, r *http.Request) {
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
	})

	http.HandleFunc("/api/reset-password", HandlePasswordReset(db))
}
