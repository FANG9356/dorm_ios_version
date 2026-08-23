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
	"sync"
	"time"

	"github.com/resend/resend-go/v3"
	"golang.org/x/crypto/bcrypt"
)

// Rate limiter for OTP brute-force protection
var (
	otpAttempts   = make(map[string]int)
	otpLockUntil  = make(map[string]time.Time)
	otpAttemptsMu sync.Mutex
)

const maxOTPAttempts = 5
const otpLockDuration = 15 * time.Minute

// Rate limiter for OTP request flood protection (ป้องกันการขอ OTP รัวๆ)
var (
	otpRequestCount = make(map[string]int)
	otpRequestLock  = make(map[string]time.Time)
	otpRequestMu    sync.Mutex
)

const maxOTPRequests = 3
const otpRequestCooldown = 15 * time.Minute

func checkOTPRequestLimit(email string) bool {
	otpRequestMu.Lock()
	defer otpRequestMu.Unlock()
	if lockTime, ok := otpRequestLock[email]; ok && time.Now().Before(lockTime) {
		return false
	}
	// Reset if cooldown expired
	if lockTime, ok := otpRequestLock[email]; ok && time.Now().After(lockTime) {
		delete(otpRequestCount, email)
		delete(otpRequestLock, email)
	}
	return true
}

func recordOTPRequest(email string) bool {
	otpRequestMu.Lock()
	defer otpRequestMu.Unlock()
	otpRequestCount[email]++
	if otpRequestCount[email] >= maxOTPRequests {
		otpRequestLock[email] = time.Now().Add(otpRequestCooldown)
		otpRequestCount[email] = 0
		return true // locked
	}
	return false
}

func checkOTPRateLimit(email string) bool {
	otpAttemptsMu.Lock()
	defer otpAttemptsMu.Unlock()
	if lockTime, ok := otpLockUntil[email]; ok && time.Now().Before(lockTime) {
		return false // still locked
	}
	return true
}

func recordOTPFailure(email string) bool {
	otpAttemptsMu.Lock()
	defer otpAttemptsMu.Unlock()
	otpAttempts[email]++
	if otpAttempts[email] >= maxOTPAttempts {
		otpLockUntil[email] = time.Now().Add(otpLockDuration)
		otpAttempts[email] = 0
		return true // locked now
	}
	return false
}

func clearOTPAttempts(email string) {
	otpAttemptsMu.Lock()
	defer otpAttemptsMu.Unlock()
	delete(otpAttempts, email)
	delete(otpLockUntil, email)
}

// generateOTP creates a random 6-digit string
func generateOTP() string {
	max := big.NewInt(1000000)
	n, err := rand.Int(rand.Reader, max)
	if err != nil {
		return "123456" // fallback if crypto rand fails
	}
	return fmt.Sprintf("%06d", n.Int64())
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
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Email == "" {
			http.Error(w, `{"error": "กรุณาระบุอีเมล"}`, http.StatusBadRequest)
			return
		}

		// Rate limit: ป้องกันการขอ OTP รัวๆ (สูงสุด 3 ครั้ง / 15 นาที)
		if !checkOTPRequestLimit(req.Email) {
			http.Error(w, `{"error": "คุณขอรหัส OTP บ่อยเกินไป กรุณารอ 15 นาทีแล้วลองใหม่"}`, http.StatusTooManyRequests)
			return
		}

		// ตอบกลับข้อความเดียวกันทุกกรณี เพื่อป้องกัน User Enumeration
		successMsg := "หากอีเมลนี้อยู่ในระบบ คุณจะได้รับรหัส OTP ภายใน 5 นาที"

		// Check if email exists in admins table
		var id int
		err := db.QueryRow("SELECT id FROM admins WHERE email = ?", req.Email).Scan(&id)
		if err != nil {
			// Email not found — but respond with same message to prevent enumeration
			recordOTPRequest(req.Email)
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(map[string]string{"message": successMsg})
			return
		}

		recordOTPRequest(req.Email)

		otp := generateOTP()
		expiresAt := time.Now().Add(15 * time.Minute).Format(time.RFC3339)

		// Delete old OTPs for this email to prevent spam
		db.Exec("DELETE FROM password_resets WHERE email = ?", req.Email)

		// Insert new OTP
		_, err = db.Exec("INSERT INTO password_resets (email, token, expires_at) VALUES (?, ?, ?)", req.Email, otp, expiresAt)
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
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Email == "" || req.OTP == "" {
			http.Error(w, `{"error": "ข้อมูลไม่ครบถ้วน"}`, http.StatusBadRequest)
			return
		}

		// Rate limit check
		if !checkOTPRateLimit(req.Email) {
			http.Error(w, `{"error": "กรอกผิดเกินจำนวนครั้งที่กำหนด กรุณารอ 15 นาทีแล้วลองใหม่"}`, http.StatusTooManyRequests)
			return
		}

		// Verify OTP
		var expiresAtStr string
		err := db.QueryRow("SELECT expires_at FROM password_resets WHERE email = ? AND token = ?", req.Email, req.OTP).Scan(&expiresAtStr)
		if err != nil {
			if recordOTPFailure(req.Email) {
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

		clearOTPAttempts(req.Email)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"message": "รหัส OTP ถูกต้อง"})
	})

	http.HandleFunc("/api/reset-password", func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method != "POST" {
			http.Error(w, `{"error": "Method not allowed"}`, http.StatusMethodNotAllowed)
			return
		}

		var req struct {
			Email       string `json:"email"`
			OTP         string `json:"otp"`
			NewPassword string `json:"new_password"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Email == "" || req.OTP == "" || req.NewPassword == "" {
			http.Error(w, `{"error": "ข้อมูลไม่ครบถ้วน"}`, http.StatusBadRequest)
			return
		}

		// Verify OTP again just to be safe
		var expiresAtStr string
		err := db.QueryRow("SELECT expires_at FROM password_resets WHERE email = ? AND token = ?", req.Email, req.OTP).Scan(&expiresAtStr)
		if err != nil {
			http.Error(w, `{"error": "รหัส OTP ไม่ถูกต้อง"}`, http.StatusUnauthorized)
			return
		}

		expiresAt, _ := time.Parse(time.RFC3339, expiresAtStr)

		if time.Now().After(expiresAt) {
			db.Exec("DELETE FROM password_resets WHERE email = ? AND token = ?", req.Email, req.OTP)
			http.Error(w, `{"error": "รหัส OTP หมดอายุแล้ว กรุณาขอใหม่"}`, http.StatusUnauthorized)
			return
		}

		// Valid OTP, update password
		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
		if err != nil {
			http.Error(w, `{"error": "ระบบขัดข้องในการเข้ารหัสผ่าน"}`, http.StatusInternalServerError)
			return
		}

		_, err = db.Exec("UPDATE admins SET password = ?, must_change_password = 0 WHERE email = ?", string(hashedPassword), req.Email)
		if err != nil {
			http.Error(w, `{"error": "ไม่สามารถอัปเดตรหัสผ่านได้"}`, http.StatusInternalServerError)
			return
		}

		// Clean up used OTP
		db.Exec("DELETE FROM password_resets WHERE email = ?", req.Email)

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"message": "รีเซ็ตรหัสผ่านสำเร็จ คุณสามารถเข้าสู่ระบบด้วยรหัสใหม่ได้ทันที"})
	})
}
