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
			<meta name="color-scheme" content="light dark">
			<meta name="supported-color-schemes" content="light dark">
			<title>รหัส OTP สำหรับรีเซ็ตรหัสผ่าน</title>
		</head>
		<body style="margin: 0; padding: 20px; font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; background-color: #f3f4f6;">
			<table width="100%%" border="0" cellspacing="0" cellpadding="0" style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.05);">
				<!-- Header -->
				<tr>
					<td align="center" style="background-color: #0f172a; padding: 40px 20px;">
						<img src="https://ui-avatars.com/api/?name=DormiNet&background=4f46e5&color=fff&size=120&rounded=true&bold=true" width="80" height="80" alt="DormiNet Logo" style="display: block; border-radius: 50%%; border: 3px solid #6366f1; margin-bottom: 15px;">
						<h1 style="color: #ffffff; margin: 0; font-size: 26px; font-weight: bold; letter-spacing: 1px;">DormiNet</h1>
					</td>
				</tr>
				<!-- Body -->
				<tr>
					<td style="padding: 40px 30px; text-align: center;">
						<h2 style="color: #1e293b; margin: 0 0 20px 0; font-size: 22px;">รหัสยืนยันตัวตน (OTP)</h2>
						<p style="color: #475569; font-size: 16px; line-height: 1.6; margin: 0 0 30px 0;">
							คุณได้ทำการร้องขอเพื่อรีเซ็ตรหัสผ่านสำหรับบัญชีของคุณ<br>
							กรุณานำรหัส 6 หลักด้านล่างนี้กรอกในระบบเพื่อดำเนินการต่อ
						</p>
						
						<!-- OTP Box -->
						<table width="100%%" border="0" cellspacing="0" cellpadding="0" style="margin-bottom: 30px;">
							<tr>
								<td align="center">
									<div style="background-color: #f8fafc; border: 2px dashed #cbd5e1; border-radius: 12px; padding: 25px; display: inline-block; min-width: 250px;">
										<span style="font-size: 40px; font-weight: bold; color: #4338ca; letter-spacing: 10px; font-family: 'Courier New', Courier, monospace;">%s</span>
									</div>
								</td>
							</tr>
						</table>

						<p style="color: #dc2626; font-size: 14px; font-weight: bold; margin: 0; padding: 10px; background-color: #fef2f2; border-radius: 6px; display: inline-block;">
							รหัสนี้จะหมดอายุภายใน 15 นาที
						</p>
					</td>
				</tr>
				<!-- Footer -->
				<tr>
					<td style="background-color: #f8fafc; padding: 20px 30px; text-align: center; border-top: 1px solid #e2e8f0;">
						<p style="color: #64748b; font-size: 13px; margin: 0 0 10px 0; line-height: 1.5;">
							หากคุณไม่ได้เป็นผู้ทำรายการนี้ กรุณาเพิกเฉยต่ออีเมลฉบับนี้
						</p>
						<p style="color: #94a3b8; font-size: 12px; margin: 0;">
							&copy; 2026 DormiNet System. All rights reserved.
						</p>
					</td>
				</tr>
			</table>
		</body>
		</html>
	`, otp)

	params := &resend.SendEmailRequest{
		From:    "DormiNet <noreply@dorminet.me>",
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
