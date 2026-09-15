package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"dorm_os/utils"
	"golang.org/x/crypto/bcrypt"
)

func HandlePasswordReset(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == http.MethodOptions {
			return
		}
		if r.Method != http.MethodPost {
			http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
			return
		}
		var req struct {
			Email       string `json:"email"`
			OTP         string `json:"otp"`
			NewPassword string `json:"new_password"`
		}
		r.Body = http.MaxBytesReader(w, r.Body, 8192)
		if json.NewDecoder(r.Body).Decode(&req) != nil {
			http.Error(w, `{"error":"ข้อมูลไม่ถูกต้อง"}`, http.StatusBadRequest)
			return
		}
		req.Email = strings.ToLower(strings.TrimSpace(req.Email))
		if !isValidEmail(req.Email) || len(req.OTP) != 6 || !isValidPassword(req.NewPassword) {
			http.Error(w, `{"error":"กรุณาระบุอีเมล รหัสยืนยัน 6 หลัก และรหัสผ่านใหม่ 8 ถึง 72 ไบต์"}`, http.StatusBadRequest)
			return
		}
		locked, rateErr := authRateLimitLocked(db, "otp_failure", req.Email, maxOTPAttempts)
		if rateErr != nil {
			http.Error(w, `{"error":"ระบบขัดข้อง กรุณาลองใหม่"}`, http.StatusInternalServerError)
			return
		}
		if locked {
			http.Error(w, `{"error":"กรอกผิดเกินจำนวนครั้งที่กำหนด กรุณารอ 15 นาที"}`, http.StatusTooManyRequests)
			return
		}
		var expires string
		err := db.QueryRow("SELECT expires_at FROM password_resets WHERE email = ? AND token = ?", req.Email, req.OTP).Scan(&expires)
		if err == sql.ErrNoRows {
			status := http.StatusUnauthorized
			attempts, rateErr := recordAuthRateLimit(db, "otp_failure", req.Email, otpLockDuration)
			if rateErr != nil {
				http.Error(w, `{"error":"ระบบขัดข้อง กรุณาลองใหม่"}`, http.StatusInternalServerError)
			} else if attempts >= maxOTPAttempts {
				status = http.StatusTooManyRequests
			}
			http.Error(w, `{"error":"รหัสยืนยันไม่ถูกต้องหรือกรอกผิดเกินจำนวนครั้งที่กำหนด"}`, status)
			return
		}
		if err != nil {
			http.Error(w, `{"error":"ระบบขัดข้อง กรุณาลองใหม่"}`, http.StatusInternalServerError)
			return
		}
		deadline, err := time.Parse(time.RFC3339, expires)
		if err != nil || !deadline.After(time.Now()) {
			http.Error(w, `{"error":"รหัสยืนยันหมดอายุ กรุณาขอใหม่"}`, http.StatusUnauthorized)
			return
		}
		hash, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
		if err != nil {
			http.Error(w, `{"error":"บันทึกรหัสผ่านไม่สำเร็จ"}`, http.StatusInternalServerError)
			return
		}
		tx, err := db.Begin()
		if err != nil {
			http.Error(w, `{"error":"ระบบขัดข้อง กรุณาลองใหม่"}`, http.StatusInternalServerError)
			return
		}
		defer tx.Rollback()
		// Consume the exact OTP in the same transaction as the password update.
		result, err := tx.Exec("DELETE FROM password_resets WHERE email = ? AND token = ? AND expires_at = ?", req.Email, req.OTP, expires)
		if err != nil {
			http.Error(w, `{"error":"บันทึกรหัสผ่านไม่สำเร็จ"}`, http.StatusInternalServerError)
			return
		}
		consumed, err := result.RowsAffected()
		if err != nil || consumed == 0 || !deadline.After(time.Now()) {
			http.Error(w, `{"error":"รหัสยืนยันถูกใช้ไปแล้วหรือหมดอายุ"}`, http.StatusUnauthorized)
			return
		}
		result, err = tx.Exec("UPDATE admins SET password = ?, must_change_password = 0 WHERE email = ?", string(hash), req.Email)
		if err != nil {
			http.Error(w, `{"error":"บันทึกรหัสผ่านไม่สำเร็จ"}`, http.StatusInternalServerError)
			return
		}
		updated, err := result.RowsAffected()
		if err != nil || updated == 0 {
			http.Error(w, `{"error":"ไม่พบบัญชีที่ต้องการเปลี่ยนรหัสผ่าน"}`, http.StatusUnauthorized)
			return
		}
		// Password reset is an account-recovery boundary. Revoke every
		// previously issued session in the same transaction so a token copied
		// from another device cannot remain valid after the password changes.
		if _, err = tx.Exec("DELETE FROM sessions WHERE admin_id IN (SELECT id FROM admins WHERE email = ?)", req.Email); err != nil {
			http.Error(w, `{"error":"บันทึกรหัสผ่านไม่สำเร็จ"}`, http.StatusInternalServerError)
			return
		}
		if err := tx.Commit(); err != nil {
			http.Error(w, `{"error":"บันทึกรหัสผ่านไม่สำเร็จ"}`, http.StatusInternalServerError)
			return
		}
		// Password and OTP consumption are already committed. Cleanup is
		// best-effort so a transient cleanup error cannot report a false failure.
		_ = clearOTPAttempts(db, req.Email)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"message": "รีเซ็ตรหัสผ่านสำเร็จ กรุณาเข้าสู่ระบบด้วยรหัสใหม่"})
	}
}
