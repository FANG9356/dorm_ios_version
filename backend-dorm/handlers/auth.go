package handlers

import (
	"context"
	"crypto/rand"
	"database/sql"
	"dorm_os/utils"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"math/big"
	"net"
	"net/http"
	"net/mail"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

type Admin struct {
	ID           int    `json:"id"`
	Username     string `json:"username"`
	Password     string `json:"-"`
	Role         string `json:"role"`
	Email        string `json:"email"`
	ProfileImage string `json:"profile_image"`
	PromptPayID  string `json:"promptpay_id"`
	DormCode     string `json:"dorm_code"`
}

var jwtSecretKey []byte

type sessionTokenClaims struct {
	AdminID  int    `json:"admin_id"`
	Username string `json:"username"`
	Role     string `json:"role"`
	jwt.RegisteredClaims
}

func issueSessionToken(db *sql.DB, adminID int, username, role string, lifetime time.Duration) (string, error) {
	nonce := make([]byte, 16)
	if _, err := rand.Read(nonce); err != nil {
		return "", err
	}
	now := time.Now()
	claims := sessionTokenClaims{
		AdminID:  adminID,
		Username: username,
		Role:     role,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(now.Add(lifetime)),
			IssuedAt:  jwt.NewNumericDate(now),
			ID:        hex.EncodeToString(nonce),
		},
	}
	tokenString, err := jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(getJWTSecret())
	if err != nil {
		return "", err
	}
	if _, err = db.Exec("INSERT INTO sessions (admin_id, token) VALUES (?, ?)", adminID, tokenString); err != nil {
		return "", err
	}
	return tokenString, nil
}

func parseSessionToken(tokenString string) (*sessionTokenClaims, error) {
	claims := &sessionTokenClaims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		if token.Method.Alg() != jwt.SigningMethodHS256.Alg() {
			return nil, fmt.Errorf("unexpected signing method: %s", token.Method.Alg())
		}
		return getJWTSecret(), nil
	}, jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Alg()}))
	if err != nil || !token.Valid || claims.AdminID <= 0 || claims.Username == "" {
		return nil, fmt.Errorf("invalid session token")
	}
	return claims, nil
}

func parsePurposeToken(tokenString, purpose string) (jwt.MapClaims, error) {
	claims := jwt.MapClaims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		if token.Method.Alg() != jwt.SigningMethodHS256.Alg() {
			return nil, fmt.Errorf("unexpected signing method: %s", token.Method.Alg())
		}
		return getJWTSecret(), nil
	}, jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Alg()}))
	role, _ := claims["role"].(string)
	if err != nil || !token.Valid || role != purpose {
		return nil, fmt.Errorf("invalid %s token", purpose)
	}
	return claims, nil
}

func authenticateSession(db *sql.DB, tokenString string) (*sessionTokenClaims, string, error) {
	claims, err := parseSessionToken(tokenString)
	if err != nil {
		return nil, "", err
	}
	var currentRole string
	if err = db.QueryRow("SELECT COALESCE(NULLIF(role, ''), 'services') FROM admins WHERE id = ?", claims.AdminID).Scan(&currentRole); err != nil {
		return nil, "", err
	}
	var exists int
	if err = db.QueryRow("SELECT 1 FROM sessions WHERE admin_id = ? AND token = ?", claims.AdminID, tokenString).Scan(&exists); err != nil || exists != 1 {
		return nil, "", fmt.Errorf("session revoked")
	}
	return claims, currentRole, nil
}

func getJWTSecret() []byte {
	if len(jwtSecretKey) > 0 {
		return jwtSecretKey
	}
	secret := strings.TrimSpace(os.Getenv("JWT_SECRET"))
	if len(secret) < 32 {
		panic("JWT_SECRET must be set and contain at least 32 characters")
	}
	jwtSecretKey = []byte(secret)
	return jwtSecretKey
}

// InitializeJWTSecret validates configuration before the HTTP listener starts.
// Authentication must fail closed instead of silently replacing the signing
// key and invalidating every existing session.
func InitializeJWTSecret() error {
	secret := strings.TrimSpace(os.Getenv("JWT_SECRET"))
	if len(secret) < 32 {
		return fmt.Errorf("JWT_SECRET must be set and contain at least 32 characters")
	}
	jwtSecretKey = []byte(secret)
	return nil
}

func InitAdminTable(db *sql.DB) {
	db.Exec(`ALTER TABLE admins ADD COLUMN line_user_id TEXT DEFAULT ''`)
	db.Exec(`ALTER TABLE admins ADD COLUMN backup_email TEXT DEFAULT ''`)
}

// isLocalIP checks if an IP string is a loopback or private network IP.
func isLocalIP(ipStr string) bool {
	ip := net.ParseIP(ipStr)
	if ip == nil {
		return false
	}
	if ip.IsLoopback() || ip.IsPrivate() || ip.IsLinkLocalUnicast() || ip.IsLinkLocalMulticast() {
		return true
	}
	return false
}

func CheckSetupStatus(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}

		var count int
		err := db.QueryRow("SELECT COUNT(*) FROM admins").Scan(&count)
		if err != nil {
			http.Error(w, `{"error": "Database error"}`, http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]bool{"needsSetup": count == 0})
	}
}

func PerformSetup(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}
		if !allowRequestAttempt(r, "initial-setup", 3, time.Hour) {
			http.Error(w, `{"error":"Too many setup attempts"}`, http.StatusTooManyRequests)
			return
		}

		var req struct {
			Username string `json:"username"`
			Password string `json:"password"`
			Email    string `json:"email"`
		}

		r.Body = http.MaxBytesReader(w, r.Body, 8192)
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"error": "Invalid request body"}`, http.StatusBadRequest)
			return
		}

		req.Username = strings.TrimSpace(req.Username)
		req.Email = strings.ToLower(strings.TrimSpace(req.Email))
		if len(req.Username) < 4 || !isValidPassword(req.Password) || !isValidEmail(req.Email) {
			http.Error(w, `{"error":"Username, email, and a password of 8-72 characters containing letters and numbers are required"}`, http.StatusBadRequest)
			return
		}

		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		if err != nil {
			http.Error(w, `{"error": "Failed to hash password"}`, http.StatusInternalServerError)
			return
		}

		result, err := db.Exec(`
			INSERT INTO admins (username, password, role, email, profile_image)
			SELECT ?, ?, 'superadmin', ?, ''
			WHERE NOT EXISTS (SELECT 1 FROM admins)
		`, req.Username, string(hashedPassword), req.Email)
		if err != nil {
			http.Error(w, `{"error": "Failed to create admin account"}`, http.StatusInternalServerError)
			return
		}
		inserted, err := result.RowsAffected()
		if err != nil || inserted != 1 {
			http.Error(w, `{"error":"Setup already completed"}`, http.StatusForbidden)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"message": "Setup completed successfully"})
	}
}

func isValidPassword(p string) bool {
	if len(p) < 8 || len(p) > 72 {
		return false
	}
	hasLetter := regexp.MustCompile(`[a-zA-Z]`).MatchString(p)
	hasNumber := regexp.MustCompile(`[0-9]`).MatchString(p)
	return hasLetter && hasNumber
}

func isValidEmail(value string) bool {
	value = strings.ToLower(strings.TrimSpace(value))
	address, err := mail.ParseAddress(value)
	return err == nil && strings.EqualFold(address.Address, value) && strings.Contains(value, "@")
}

func LoginHandler(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var creds struct {
			Username string `json:"username"`
			Email    string `json:"email"`
			Password string `json:"password"`
		}

		if err := json.NewDecoder(r.Body).Decode(&creds); err != nil {
			http.Error(w, `{"error": "Invalid request"}`, http.StatusBadRequest)
			return
		}

		var admin struct {
			ID                 int
			Username           string
			Password           string
			Role               string
			Email              string
			ProfileImage       string
			MustChangePassword int
		}

		loginIdentifier := creds.Username
		if loginIdentifier == "" {
			loginIdentifier = creds.Email
		}
		loginIdentifier = strings.TrimSpace(loginIdentifier)
		if !allowRequestAttempt(r, "login-ip", 30, 15*time.Minute) ||
			!allowRequestAttempt(r, "login-account:"+strings.ToLower(loginIdentifier), 10, 15*time.Minute) {
			http.Error(w, `{"error": "เข้าสู่ระบบบ่อยเกินไป กรุณารอ 15 นาที"}`, http.StatusTooManyRequests)
			return
		}

		err := db.QueryRow("SELECT id, username, password, COALESCE(role, 'services'), COALESCE(email, ''), COALESCE(profile_image, ''), COALESCE(must_change_password, 0) FROM admins WHERE username = ? OR email = ? OR backup_email = ?", loginIdentifier, loginIdentifier, loginIdentifier).Scan(&admin.ID, &admin.Username, &admin.Password, &admin.Role, &admin.Email, &admin.ProfileImage, &admin.MustChangePassword)
		if err != nil || bcrypt.CompareHashAndPassword([]byte(admin.Password), []byte(creds.Password)) != nil {
			w.WriteHeader(http.StatusUnauthorized)
			w.Write([]byte(`{"error": "ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง"}`))
			return
		}

		if admin.MustChangePassword == 1 || creds.Password == "admin" {
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(map[string]interface{}{
				"id":                      admin.ID,
				"require_password_change": true,
				"username":                admin.Username,
				"role":                    admin.Role,
				"email":                   admin.Email,
				"profile_image":           admin.ProfileImage,
			})
			return
		}

		tokenString, err := issueSessionToken(db, admin.ID, admin.Username, admin.Role, 24*time.Hour)
		if err != nil {
			http.Error(w, `{"error": "Could not generate token"}`, http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"id":            admin.ID,
			"token":         tokenString,
			"username":      admin.Username,
			"role":          admin.Role,
			"email":         admin.Email,
			"profile_image": admin.ProfileImage,
		})
	}
}

func AuthMiddleware(db *sql.DB, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		path := r.URL.Path

		if !strings.HasPrefix(path, "/api/") {
			next.ServeHTTP(w, r)
			return
		}

		// ป้องกันเซิร์ฟเวอร์ล่มจากการยิงไฟล์ขนาดใหญ่ (DoS Disk Exhaustion)
		r.Body = http.MaxBytesReader(w, r.Body, 50<<20) // จำกัดขนาดที่ 50MB ต่อ 1 Request

		if path == "/api/login" || path == "/api/login/qr" || path == "/api/register" || path == "/api/change-password" || path == "/api/forgot-password" || path == "/api/verify-otp" || path == "/api/reset-password" || path == "/api/webhook/line" || path == "/api/liff/link" || path == "/api/liff/rooms" || path == "/api/liff/status" || path == "/api/liff/verify-tenant" || path == "/api/setup/status" || path == "/api/setup" || path == "/api/system/ping" || path == "/api/auth/register" || path == "/api/auth/login" {
			next.ServeHTTP(w, r)
			return
		}

		authHeader := r.Header.Get("Authorization")
		tokenStr := ""

		if authHeader != "" {
			parts := strings.Split(authHeader, " ")
			if len(parts) == 2 && parts[0] == "Bearer" {
				tokenStr = parts[1]
			}
		}

		if tokenStr == "" {
			http.Error(w, `{"error": "Unauthorized: Missing Token"}`, http.StatusUnauthorized)
			return
		}
		claims, currentRole, err := authenticateSession(db, tokenStr)
		if err != nil {
			http.Error(w, `{"error": "Unauthorized: Invalid or Expired Token"}`, http.StatusUnauthorized)
			return
		}

		ctx := context.WithValue(r.Context(), "admin_id", claims.AdminID)
		ctx = context.WithValue(ctx, "admin_role", currentRole)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func IsServicesRole(r *http.Request) bool {
	role, _ := r.Context().Value("admin_role").(string)
	return role == "superadmin" || role == "admin" || role == "services"
}

func IsSuperadmin(r *http.Request) bool {
	role, _ := r.Context().Value("admin_role").(string)
	return role == "superadmin"
}

func IsSystemOperator(r *http.Request) bool {
	if !IsSuperadmin(r) {
		return false
	}
	configuredID, err := strconv.Atoi(strings.TrimSpace(os.Getenv("SYSTEM_OPERATOR_ADMIN_ID")))
	adminID, ok := r.Context().Value("admin_id").(int)
	return err == nil && configuredID > 0 && ok && adminID == configuredID
}

func currentAdminScope(db *sql.DB, r *http.Request) (int, string, string, error) {
	adminID, ok := r.Context().Value("admin_id").(int)
	if !ok || adminID <= 0 {
		return 0, "", "", fmt.Errorf("missing admin scope")
	}
	var role, email string
	if err := db.QueryRow(`SELECT COALESCE(NULLIF(role, ''), 'dorm'), LOWER(TRIM(COALESCE(email, '')))
		FROM admins WHERE id = ?`, adminID).Scan(&role, &email); err != nil || email == "" {
		return 0, "", "", fmt.Errorf("invalid admin scope")
	}
	return adminID, role, email, nil
}

func targetAdminScope(db *sql.DB, targetID int) (string, string, error) {
	var role, email string
	if err := db.QueryRow(`SELECT COALESCE(NULLIF(role, ''), 'dorm'), LOWER(TRIM(COALESCE(email, '')))
		FROM admins WHERE id = ?`, targetID).Scan(&role, &email); err != nil || email == "" {
		return "", "", fmt.Errorf("target account unavailable")
	}
	return role, email, nil
}

func validStaffRole(role string) bool {
	switch role {
	case "admin", "services", "dorm":
		return true
	default:
		return false
	}
}

func ChangePasswordHandler(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var req struct {
			Username    string `json:"username"`
			OldPassword string `json:"old_password"`
			NewUsername string `json:"new_username"`
			NewPassword string `json:"new_password"`
		}

		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"error": "Invalid request"}`, http.StatusBadRequest)
			return
		}
		if !allowRequestAttempt(r, "change-password:"+strings.ToLower(strings.TrimSpace(req.Username)), 10, 15*time.Minute) {
			http.Error(w, `{"error": "ลองเปลี่ยนรหัสผ่านบ่อยเกินไป กรุณารอ 15 นาที"}`, http.StatusTooManyRequests)
			return
		}

		var admin Admin
		err := db.QueryRow("SELECT id, username, password FROM admins WHERE username = ?", req.Username).Scan(&admin.ID, &admin.Username, &admin.Password)
		if err != nil {
			w.WriteHeader(http.StatusUnauthorized)
			w.Write([]byte(`{"error": "ไม่พบผู้ใช้นี้"}`))
			return
		}

		// Check if authenticated via token (e.g., from QR login) or via old password
		authHeader := r.Header.Get("Authorization")
		tokenStr := ""
		if authHeader != "" {
			parts := strings.Split(authHeader, " ")
			if len(parts) == 2 && parts[0] == "Bearer" {
				tokenStr = parts[1]
			}
		}

		authenticated := false
		if tokenStr != "" {
			claims, _, err := authenticateSession(db, tokenStr)
			if err == nil && claims.Username == req.Username {
				authenticated = true
			}
		}

		if !authenticated {
			if req.OldPassword == "" || bcrypt.CompareHashAndPassword([]byte(admin.Password), []byte(req.OldPassword)) != nil {
				w.WriteHeader(http.StatusUnauthorized)
				w.Write([]byte(`{"error": "ชื่อผู้ใช้หรือรหัสผ่านเดิมไม่ถูกต้อง"}`))
				return
			}
		}

		if !isValidPassword(req.NewPassword) {
			http.Error(w, `{"error": "รหัสผ่านต้องมีความยาวอย่างน้อย 8 ตัวอักษร และประกอบด้วยตัวอักษรและตัวเลข"}`, http.StatusBadRequest)
			return
		}

		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
		if err != nil {
			http.Error(w, `{"error": "เกิดข้อผิดพลาดในการสร้างรหัสผ่านใหม่"}`, http.StatusInternalServerError)
			return
		}

		newUsername := req.NewUsername
		if newUsername == "" {
			newUsername = admin.Username
		}

		tx, err := db.Begin()
		if err != nil {
			http.Error(w, `{"error": "ไม่สามารถอัปเดตข้อมูลได้"}`, http.StatusInternalServerError)
			return
		}
		defer tx.Rollback()
		_, err = tx.Exec("UPDATE admins SET username = ?, password = ?, must_change_password = 0 WHERE id = ?", newUsername, string(hashedPassword), admin.ID)
		if err != nil {
			http.Error(w, `{"error": "ไม่สามารถอัปเดตข้อมูลได้ ชื่อผู้ใช้นี้อาจมีคนใช้แล้ว"}`, http.StatusInternalServerError)
			return
		}
		if _, err = tx.Exec("DELETE FROM sessions WHERE admin_id = ?", admin.ID); err != nil {
			http.Error(w, `{"error": "ไม่สามารถยกเลิกเซสชันเดิมได้"}`, http.StatusInternalServerError)
			return
		}
		if err = tx.Commit(); err != nil {
			http.Error(w, `{"error": "ไม่สามารถอัปเดตข้อมูลได้"}`, http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"message": "เปลี่ยนข้อมูลผู้ใช้สำเร็จ",
		})
	}
}

func GetAdminsHandler(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method != "GET" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		adminID, ok := r.Context().Value("admin_id").(int)
		if !ok || adminID <= 0 {
			http.Error(w, `{"error": "Unauthorized"}`, http.StatusUnauthorized)
			return
		}
		var filterEmail string
		if err := db.QueryRow("SELECT COALESCE(email, '') FROM admins WHERE id = ?", adminID).Scan(&filterEmail); err != nil || strings.TrimSpace(filterEmail) == "" {
			http.Error(w, `{"error": "Account scope unavailable"}`, http.StatusForbidden)
			return
		}

		rows, err := db.Query("SELECT id, username, last_active, COALESCE(role, 'admin'), COALESCE(email, ''), COALESCE(profile_image, ''), COALESCE(backup_email, ''), COALESCE(promptpay_id, ''), COALESCE(dorm_code, ''), COALESCE(payment_type, 'promptpay'), COALESCE(bank_account, ''), COALESCE(account_name, '') FROM admins WHERE email = ? ORDER BY id ASC", strings.ToLower(strings.TrimSpace(filterEmail)))
		if err != nil {
			http.Error(w, `{"error": "Database error"}`, http.StatusInternalServerError)
			return
		}
		defer rows.Close()

		var admins []map[string]interface{}
		for rows.Next() {
			var id int
			var username string
			var lastActive sql.NullString
			var role string
			var email string
			var profileImage string
			var backupEmail string
			var promptPayID string
			var dormCode string
			var paymentType string
			var bankAccount string
			var accountName string
			if err := rows.Scan(&id, &username, &lastActive, &role, &email, &profileImage, &backupEmail, &promptPayID, &dormCode, &paymentType, &bankAccount, &accountName); err != nil {
				continue
			}
			admins = append(admins, map[string]interface{}{
				"id":            id,
				"username":      username,
				"last_active":   lastActive.String,
				"role":          role,
				"email":         email,
				"profile_image": profileImage,
				"backup_email":  backupEmail,
				"promptpay_id":  promptPayID,
				"dorm_code":     dormCode,
				"payment_type":  paymentType,
				"bank_account":  bankAccount,
				"account_name":  accountName,
			})
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(admins)
	}
}

func CreateAdminHandler(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		_, requesterRole, requesterEmail, err := currentAdminScope(db, r)
		if err != nil || requesterRole != "superadmin" {
			http.Error(w, `{"error": "Unauthorized: Superadmin role required"}`, http.StatusForbidden)
			return
		}

		var req struct {
			Username string `json:"username"`
			Role     string `json:"role"`
			Email    string `json:"email"`
			Password string `json:"password"`
		}

		r.Body = http.MaxBytesReader(w, r.Body, 8192)
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || strings.TrimSpace(req.Username) == "" {
			http.Error(w, `{"error": "Invalid request"}`, http.StatusBadRequest)
			return
		}

		req.Username = strings.TrimSpace(req.Username)
		req.Email = strings.TrimSpace(req.Email)

		// Check if username already exists
		var userExists bool
		err = db.QueryRow("SELECT EXISTS(SELECT 1 FROM admins WHERE LOWER(username) = LOWER(?))", req.Username).Scan(&userExists)
		if err == nil && userExists {
			http.Error(w, `{"error": "ชื่อผู้ใช้นี้มีอยู่ในระบบแล้ว กรุณาใช้ชื่ออื่น"}`, http.StatusConflict)
			return
		}

		role := strings.ToLower(strings.TrimSpace(req.Role))
		if role == "" {
			role = "admin"
		}
		if !validStaffRole(role) {
			http.Error(w, `{"error": "Invalid staff role"}`, http.StatusBadRequest)
			return
		}
		req.Email = strings.ToLower(strings.TrimSpace(req.Email))
		if !isValidEmail(req.Email) || strings.EqualFold(req.Email, requesterEmail) {
			http.Error(w, `{"error": "Staff recovery email is required and must differ from the owner email"}`, http.StatusBadRequest)
			return
		}
		if !isValidPassword(req.Password) {
			http.Error(w, `{"error":"Temporary password must contain 8-72 characters with letters and numbers"}`, http.StatusBadRequest)
			return
		}
		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		if err != nil {
			http.Error(w, `{"error":"Failed to generate password"}`, http.StatusInternalServerError)
			return
		}

		_, err = db.Exec("INSERT INTO admins (username, password, role, email, backup_email, must_change_password) VALUES (?, ?, ?, ?, ?, 1)", req.Username, string(hashedPassword), role, requesterEmail, strings.ToLower(req.Email))
		if err != nil {
			http.Error(w, `{"error": "ไม่สามารถสร้างบัญชีผู้ใช้ได้ ชื่อผู้ใช้หรืออีเมลอาจซ้ำกัน"}`, http.StatusConflict)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"message": "สร้างผู้ใช้สำเร็จ",
		})
	}
}

func DeleteAdminHandler(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method != "DELETE" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		requesterID, requesterRole, requesterEmail, err := currentAdminScope(db, r)
		if err != nil || requesterRole != "superadmin" {
			http.Error(w, `{"error": "Unauthorized: Superadmin role required"}`, http.StatusForbidden)
			return
		}

		// Extract ID from URL
		parts := strings.Split(r.URL.Path, "/")
		if len(parts) < 4 {
			http.Error(w, `{"error": "Invalid URL"}`, http.StatusBadRequest)
			return
		}
		id, err := strconv.Atoi(parts[3])
		if err != nil || id <= 0 {
			http.Error(w, `{"error": "Invalid admin ID"}`, http.StatusBadRequest)
			return
		}
		if id == requesterID {
			http.Error(w, `{"error": "ไม่สามารถลบบัญชีที่กำลังใช้งานได้"}`, http.StatusForbidden)
			return
		}

		targetRole, targetEmail, err := targetAdminScope(db, id)
		if err != nil {
			http.Error(w, `{"error": "ไม่พบบัญชีผู้ใช้"}`, http.StatusNotFound)
			return
		}
		if targetEmail != requesterEmail {
			http.Error(w, `{"error": "ไม่สามารถจัดการบัญชีต่างหอพักได้"}`, http.StatusForbidden)
			return
		}
		if targetRole == "superadmin" {
			http.Error(w, `{"error": "ไม่สามารถลบบัญชี Super Admin ได้"}`, http.StatusForbidden)
			return
		}

		tx, err := db.Begin()
		if err != nil {
			http.Error(w, `{"error": "ไม่สามารถลบข้อมูลได้"}`, http.StatusInternalServerError)
			return
		}
		defer tx.Rollback()
		if _, err = tx.Exec("DELETE FROM sessions WHERE admin_id = ?", id); err == nil {
			_, err = tx.Exec("DELETE FROM admins WHERE id = ? AND LOWER(TRIM(email)) = ? AND role != 'superadmin'", id, requesterEmail)
		}
		if err != nil || tx.Commit() != nil {
			http.Error(w, `{"error": "ไม่สามารถลบข้อมูลได้"}`, http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"message": "ลบผู้ใช้สำเร็จ",
		})
	}
}

func UpdateAdminHandler(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method != "PUT" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		parts := strings.Split(r.URL.Path, "/")
		if len(parts) < 4 {
			http.Error(w, `{"error": "Invalid URL"}`, http.StatusBadRequest)
			return
		}

		id, err := strconv.Atoi(parts[3])
		if err != nil {
			http.Error(w, `{"error": "Invalid ID"}`, http.StatusBadRequest)
			return
		}
		requesterID, requesterRole, requesterEmail, err := currentAdminScope(db, r)
		if err != nil {
			http.Error(w, `{"error": "Unauthorized"}`, http.StatusUnauthorized)
			return
		}
		targetRole, targetEmail, err := targetAdminScope(db, id)
		if err != nil {
			http.Error(w, `{"error": "ไม่พบบัญชีผู้ใช้"}`, http.StatusNotFound)
			return
		}
		if targetEmail != requesterEmail || (id != requesterID && requesterRole != "superadmin") {
			http.Error(w, `{"error": "ไม่สามารถจัดการบัญชีนี้ได้"}`, http.StatusForbidden)
			return
		}

		var req struct {
			Username    string  `json:"username"`
			OldPassword string  `json:"old_password"`
			NewPassword string  `json:"new_password"`
			Role        string  `json:"role"`
			Email       string  `json:"email"`
			BackupEmail string  `json:"backup_email"`
			PromptPayID *string `json:"promptpay_id"`
			PaymentType *string `json:"payment_type"`
			BankAccount *string `json:"bank_account"`
			AccountName *string `json:"account_name"`
		}

		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"error": "Invalid request"}`, http.StatusBadRequest)
			return
		}
		if req.Email != "" && req.BackupEmail != "" && strings.EqualFold(strings.TrimSpace(req.Email), strings.TrimSpace(req.BackupEmail)) {
			http.Error(w, `{"error": "อีเมลสำรองต้องไม่ตรงกับอีเมลหลัก"}`, http.StatusBadRequest)
			return
		}
		if req.Email != "" && !strings.EqualFold(strings.TrimSpace(req.Email), targetEmail) {
			http.Error(w, `{"error": "การเปลี่ยนอีเมลหลักต้องใช้ขั้นตอนย้าย account โดยเฉพาะ"}`, http.StatusBadRequest)
			return
		}
		if req.Role != "" {
			req.Role = strings.ToLower(strings.TrimSpace(req.Role))
			if requesterRole != "superadmin" || targetRole == "superadmin" || !validStaffRole(req.Role) {
				http.Error(w, `{"error": "ไม่อนุญาตให้เปลี่ยนสิทธิ์นี้"}`, http.StatusForbidden)
				return
			}
		}

		if req.BackupEmail != "" {
			var count int
			err := db.QueryRow("SELECT COUNT(*) FROM admins WHERE LOWER(backup_email) = LOWER(?) AND id != ?", req.BackupEmail, id).Scan(&count)
			if err == nil && count > 0 {
				http.Error(w, `{"error": "อีเมลสำรองนี้ถูกใช้งานโดยพนักงานอื่นแล้ว"}`, http.StatusBadRequest)
				return
			}
		}

		// Dynamically build the UPDATE query
		query := "UPDATE admins SET "
		var args []interface{}

		if req.Username != "" {
			query += "username = ?, "
			args = append(args, req.Username)
		}
		if req.NewPassword != "" {
			// A superadmin may reset staff passwords. Everyone changing their own
			// password must prove knowledge of the current password.
			if id == requesterID {
				if req.OldPassword == "" {
					http.Error(w, `{"error": "ต้องระบุรหัสผ่านเดิมเพื่อเปลี่ยนรหัสผ่านใหม่"}`, http.StatusBadRequest)
					return
				}
				var currentHashedPassword string
				if err := db.QueryRow("SELECT password FROM admins WHERE id = ?", id).Scan(&currentHashedPassword); err != nil {
					http.Error(w, `{"error": "ไม่พบผู้ใช้นี้"}`, http.StatusNotFound)
					return
				}
				if err := bcrypt.CompareHashAndPassword([]byte(currentHashedPassword), []byte(req.OldPassword)); err != nil {
					http.Error(w, `{"error": "รหัสผ่านเดิมไม่ถูกต้อง"}`, http.StatusUnauthorized)
					return
				}
			}

			if !isValidPassword(req.NewPassword) {
				http.Error(w, `{"error": "รหัสผ่านต้องมีความยาวอย่างน้อย 8 ตัวอักษร และประกอบด้วยตัวอักษรและตัวเลข"}`, http.StatusBadRequest)
				return
			}
			hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
			if err != nil {
				http.Error(w, `{"error": "Failed to generate password"}`, http.StatusInternalServerError)
				return
			}
			query += "password = ?, "
			args = append(args, string(hashedPassword))
		}
		if req.Role != "" {
			query += "role = ?, "
			args = append(args, req.Role)
		}

		// Let's use a map to decode instead to know exactly what was sent
		// json.NewDecoder(r.Body) // Oops, we already decoded.
		// Just rely on the struct fields and update them if they are not empty.
		// Wait! If they want to remove their email, req.Email is "". We can't tell if it was sent as "" or omitted.
		// Let's just update email if it was sent. But since we already decoded into `req`, we can just check if Username is present (rename request), we also update Email.

		if req.Username != "" {
			query += "email = ?, "
			args = append(args, req.Email)
			query += "backup_email = ?, "
			args = append(args, req.BackupEmail)
		}
		if req.PromptPayID != nil {
			query += "promptpay_id = ?, "
			args = append(args, strings.TrimSpace(*req.PromptPayID))
		}
		if req.PaymentType != nil {
			query += "payment_type = ?, "
			args = append(args, strings.TrimSpace(*req.PaymentType))
		}
		if req.BankAccount != nil {
			query += "bank_account = ?, "
			args = append(args, strings.TrimSpace(*req.BankAccount))
		}
		if req.AccountName != nil {
			query += "account_name = ?, "
			args = append(args, strings.TrimSpace(*req.AccountName))
		}

		// If nothing to update, return success
		if len(args) == 0 {
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(map[string]string{
				"message": "อัปเดตข้อมูลสำเร็จ",
			})
			return
		}

		// Remove trailing comma and space
		query = strings.TrimSuffix(query, ", ")
		query += " WHERE id = ?"
		args = append(args, id)

		tx, err := db.Begin()
		if err != nil {
			http.Error(w, `{"error": "ไม่สามารถอัปเดตข้อมูลได้"}`, http.StatusInternalServerError)
			return
		}
		defer tx.Rollback()
		if _, err = tx.Exec(query, args...); err == nil && (req.NewPassword != "" || req.Role != "") {
			_, err = tx.Exec("DELETE FROM sessions WHERE admin_id = ?", id)
		}
		if err != nil || tx.Commit() != nil {
			http.Error(w, `{"error": "ไม่สามารถอัปเดตข้อมูลได้ ชื่อผู้ใช้หรืออีเมลอาจซ้ำกัน"}`, http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"message": "อัปเดตข้อมูลสำเร็จ",
		})
	}
}

func PingAdminHandler(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		adminID, ok := r.Context().Value("admin_id").(int)
		if !ok || adminID <= 0 {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}
		if _, err := db.Exec("UPDATE admins SET last_active = CURRENT_TIMESTAMP WHERE id = ?", adminID); err != nil {
			http.Error(w, "Database error", http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"message": "pong"})
	}
}

func LogoutAdminHandler(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		adminID, ok := r.Context().Value("admin_id").(int)
		authHeader := r.Header.Get("Authorization")
		parts := strings.Fields(authHeader)
		if !ok || adminID <= 0 || len(parts) != 2 || parts[0] != "Bearer" {
			http.Error(w, "Missing Authorization header", http.StatusUnauthorized)
			return
		}
		tokenString := parts[1]
		// Set last_active to an old date to instantly show as Offline
		if _, err := db.Exec("UPDATE admins SET last_active = '2000-01-01 00:00:00' WHERE id = ?", adminID); err != nil {
			http.Error(w, "Database error", http.StatusInternalServerError)
			return
		}

		// Remove session to force remote kick
		if _, err := db.Exec("DELETE FROM sessions WHERE admin_id = ? AND token = ?", adminID, tokenString); err != nil {
			http.Error(w, "Database error", http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"message": "logged out"})
	}
}

func UpdateProfileImageHandler(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		targetID, err := strconv.Atoi(r.URL.Query().Get("id"))
		if err != nil || targetID <= 0 {
			http.Error(w, `{"error": "Missing admin ID"}`, http.StatusBadRequest)
			return
		}
		requesterID, requesterRole, requesterEmail, err := currentAdminScope(db, r)
		if err != nil {
			http.Error(w, `{"error": "Unauthorized"}`, http.StatusUnauthorized)
			return
		}
		_, targetEmail, err := targetAdminScope(db, targetID)
		if err != nil {
			http.Error(w, `{"error": "Admin not found"}`, http.StatusNotFound)
			return
		}
		if targetEmail != requesterEmail || (targetID != requesterID && requesterRole != "superadmin") {
			http.Error(w, `{"error": "ไม่สามารถจัดการบัญชีนี้ได้"}`, http.StatusForbidden)
			return
		}

		r.Body = http.MaxBytesReader(w, r.Body, 10<<20)
		err = r.ParseMultipartForm(10 << 20)
		if err != nil {
			http.Error(w, `{"error": "Unable to parse form"}`, http.StatusBadRequest)
			return
		}

		file, _, err := r.FormFile("profile_image")
		if err != nil {
			http.Error(w, `{"error": "Error retrieving the file"}`, http.StatusBadRequest)
			return
		}
		defer file.Close()

		buffer := make([]byte, 512)
		read, readErr := file.Read(buffer)
		if readErr != nil && readErr != io.EOF {
			http.Error(w, `{"error": "Error reading image"}`, http.StatusBadRequest)
			return
		}
		if _, err := file.Seek(0, io.SeekStart); err != nil {
			http.Error(w, `{"error": "Error reading image"}`, http.StatusBadRequest)
			return
		}
		contentType := http.DetectContentType(buffer[:read])
		extensions := map[string]string{"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}
		ext, allowed := extensions[contentType]
		if !allowed {
			http.Error(w, `{"error": "Only JPEG, PNG or WebP images are allowed"}`, http.StatusBadRequest)
			return
		}

		// Ensure directory exists
		uploadDir := "./uploads/profiles"
		if err := os.MkdirAll(uploadDir, 0700); err != nil {
			http.Error(w, `{"error": "Error preparing upload directory"}`, http.StatusInternalServerError)
			return
		}

		// Create unique filename
		fileName := fmt.Sprintf("admin_%d_%d%s", targetID, time.Now().UnixNano(), ext)
		filePath := filepath.Join(uploadDir, fileName)

		dst, err := os.OpenFile(filePath, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
		if err != nil {
			http.Error(w, `{"error": "Error saving the file"}`, http.StatusInternalServerError)
			return
		}
		if _, err := io.Copy(dst, file); err != nil {
			dst.Close()
			os.Remove(filePath)
			http.Error(w, `{"error": "Error writing the file"}`, http.StatusInternalServerError)
			return
		}
		if err := dst.Close(); err != nil {
			os.Remove(filePath)
			http.Error(w, `{"error": "Error writing the file"}`, http.StatusInternalServerError)
			return
		}

		// Update database
		imageURL := "/uploads/profiles/" + fileName
		_, err = db.Exec("UPDATE admins SET profile_image = ? WHERE id = ? AND LOWER(TRIM(email)) = ?", imageURL, targetID, requesterEmail)
		if err != nil {
			os.Remove(filePath)
			http.Error(w, `{"error": "Database error"}`, http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"message":       "Profile image updated successfully",
			"profile_image": imageURL,
		})
	}
}

func generateUniqueDormCode(db *sql.DB) string {
	max := big.NewInt(1000000)
	for {
		n, err := rand.Int(rand.Reader, max)
		if err != nil {
			continue
		}
		code := fmt.Sprintf("%06d", n.Int64())
		var exists bool
		if err := db.QueryRow("SELECT EXISTS(SELECT 1 FROM admins WHERE dorm_code = ?)", code).Scan(&exists); err == nil && !exists {
			return code
		}
	}
}

func RegisterHandler(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var req struct {
			Name     string `json:"name"`
			Email    string `json:"email"`
			Password string `json:"password"`
		}

		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"status": "error", "message": "ข้อมูลไม่ถูกต้อง"}`, http.StatusBadRequest)
			return
		}
		req.Name = strings.TrimSpace(req.Name)
		req.Email = strings.ToLower(strings.TrimSpace(req.Email))
		if !allowRequestAttempt(r, "register", 5, time.Hour) {
			http.Error(w, `{"status": "error", "message": "สมัครบัญชีบ่อยเกินไป กรุณาลองใหม่ภายหลัง"}`, http.StatusTooManyRequests)
			return
		}

		if len(req.Name) < 3 || !isValidPassword(req.Password) || !isValidEmail(req.Email) {
			http.Error(w, `{"status": "error", "message": "กรุณาระบุชื่อ อีเมล และรหัสผ่าน 8-72 ตัวที่มีตัวอักษรกับตัวเลข"}`, http.StatusBadRequest)
			return
		}

		// Check if email already exists
		var exists bool
		err := db.QueryRow("SELECT EXISTS(SELECT 1 FROM admins WHERE email = ?)", req.Email).Scan(&exists)
		if err != nil {
			http.Error(w, `{"status": "error", "message": "เกิดข้อผิดพลาดกับฐานข้อมูล"}`, http.StatusInternalServerError)
			return
		}
		if exists {
			http.Error(w, `{"status": "error", "message": "อีเมลนี้ถูกใช้งานแล้ว"}`, http.StatusConflict)
			return
		}

		// Check if username (name) already exists just in case
		err = db.QueryRow("SELECT EXISTS(SELECT 1 FROM admins WHERE username = ?)", req.Name).Scan(&exists)
		if err != nil {
			http.Error(w, `{"status": "error", "message": "เกิดข้อผิดพลาดกับฐานข้อมูล"}`, http.StatusInternalServerError)
			return
		}
		if exists {
			http.Error(w, `{"status": "error", "message": "ชื่อผู้ใช้นี้ถูกใช้งานแล้ว"}`, http.StatusConflict)
			return
		}

		// Hash password and insert
		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		if err != nil {
			http.Error(w, `{"status": "error", "message": "ไม่สามารถเข้ารหัสรหัสผ่านได้"}`, http.StatusInternalServerError)
			return
		}

		// Create as superadmin for their own new dorm
		dormCode := generateUniqueDormCode(db)
		result, err := db.Exec("INSERT INTO admins (username, password, role, email, dorm_code) VALUES (?, ?, 'superadmin', ?, ?)", req.Name, hashedPassword, req.Email, dormCode)
		if err != nil {
			http.Error(w, `{"status": "error", "message": "ไม่สามารถสร้างบัญชีได้"}`, http.StatusInternalServerError)
			return
		}

		adminID, _ := result.LastInsertId()

		// Immediately provision their new tenant DB
		_, err = GetTenantDB(int(adminID))
		if err != nil {
			// Don't block registration if DB creation fails, they can retry on login
			fmt.Println("Warning: Failed to create tenant DB on register:", err)
		}

		// Generate a revocable session so the token works with AuthMiddleware.
		tokenString, err := issueSessionToken(db, int(adminID), req.Name, "superadmin", 24*time.Hour)
		if err != nil {
			http.Error(w, `{"status": "error", "message": "สร้าง Token ล้มเหลว"}`, http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":   "success",
			"message":  "สมัครสมาชิกสำเร็จ",
			"token":    tokenString,
			"name":     req.Name,
			"admin_id": int(adminID),
			"role":     "superadmin",
		})
	}
}

func GenerateInviteTokenHandler(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		// Ensure the user requesting this has services (admin) role
		if !IsServicesRole(r) {
			http.Error(w, `{"error": "Unauthorized"}`, http.StatusForbidden)
			return
		}

		// Generate a token valid for 5 minutes
		expirationTime := time.Now().Add(5 * time.Minute)
		claims := jwt.MapClaims{
			"username": "invite",
			"role":     "invite",
			"exp":      expirationTime.Unix(),
		}

		token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
		tokenString, err := token.SignedString(getJWTSecret())
		if err != nil {
			http.Error(w, `{"error": "Could not generate token"}`, http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"invite_token": tokenString,
			"expires_in":   "300",
		})
	}
}

// RegisterOpenLocalHandler allows registration ONLY if the client is on the local subnet.
func RegisterOpenLocalHandler(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		// Security Check: Ensure client is on local subnet
		ipStr, _, err := net.SplitHostPort(r.RemoteAddr)
		if err != nil {
			ipStr = r.RemoteAddr
		}
		if !isLocalIP(ipStr) {
			http.Error(w, `{"error": "ไม่อนุญาตให้สมัครสมาชิกจากภายนอกเครือข่าย"}`, http.StatusForbidden)
			return
		}

		var req struct {
			Username string `json:"username"`
			Password string `json:"password"`
		}

		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"error": "Invalid request"}`, http.StatusBadRequest)
			return
		}

		if len(req.Username) < 4 || len(req.Password) < 4 {
			http.Error(w, `{"error": "Username and password must be at least 4 characters"}`, http.StatusBadRequest)
			return
		}

		// Check if username exists
		var exists bool
		err = db.QueryRow("SELECT EXISTS(SELECT 1 FROM admins WHERE username = ?)", req.Username).Scan(&exists)
		if err != nil {
			http.Error(w, `{"error": "Database error"}`, http.StatusInternalServerError)
			return
		}
		if exists {
			http.Error(w, `{"error": "ชื่อผู้ใช้นี้ถูกใช้งานแล้ว"}`, http.StatusConflict)
			return
		}

		// Hash password and insert
		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		if err != nil {
			http.Error(w, `{"error": "Failed to hash password"}`, http.StatusInternalServerError)
			return
		}

		_, err = db.Exec("INSERT INTO admins (username, password, role) VALUES (?, ?, 'services')", req.Username, hashedPassword)
		if err != nil {
			http.Error(w, `{"error": "Failed to create user"}`, http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"message": "สมัครสมาชิกสำเร็จ สามารถเข้าสู่ระบบได้ทันที",
		})
	}
}

func RegisterWithInviteHandler(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var req struct {
			InviteToken string `json:"invite_token"`
			Username    string `json:"username"`
			Password    string `json:"password"`
		}

		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"error": "Invalid request"}`, http.StatusBadRequest)
			return
		}

		if _, err := parsePurposeToken(req.InviteToken, "invite"); err != nil {
			http.Error(w, `{"error": "QR Code หมดอายุหรือไม่ถูกต้อง กรุณาให้เครื่องแม่สร้างใหม่"}`, http.StatusUnauthorized)
			return
		}

		// Basic Validation
		if req.Username == "" || req.Password == "" {
			http.Error(w, `{"error": "กรุณากรอกข้อมูลให้ครบถ้วน"}`, http.StatusBadRequest)
			return
		}
		if !isValidPassword(req.Password) {
			http.Error(w, `{"error": "รหัสผ่านต้องมีความยาวอย่างน้อย 8 ตัวอักษร และประกอบด้วยตัวอักษรและตัวเลข"}`, http.StatusBadRequest)
			return
		}

		// Hash password
		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		if err != nil {
			http.Error(w, `{"error": "Failed to hash password"}`, http.StatusInternalServerError)
			return
		}

		// Insert into DB with default role 'dorm'
		_, err = db.Exec("INSERT INTO admins (username, password, role) VALUES (?, ?, ?)", req.Username, string(hashedPassword), "dorm")
		if err != nil {
			if strings.Contains(err.Error(), "UNIQUE constraint failed") {
				http.Error(w, `{"error": "ชื่อผู้ใช้นี้ถูกใช้งานแล้ว"}`, http.StatusConflict)
				return
			}
			http.Error(w, `{"error": "Failed to create user"}`, http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"message": "สมัครสมาชิกสำเร็จ",
		})
	}
}

// GenerateLoginTokenHandler generates a short-lived token for an existing user to login via QR code
func GenerateLoginTokenHandler(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		// Only admins can generate login tokens for others
		if !IsServicesRole(r) {
			http.Error(w, `{"error": "Unauthorized"}`, http.StatusForbidden)
			return
		}

		var req struct {
			TargetUsername string `json:"target_username"`
		}

		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"error": "Invalid request"}`, http.StatusBadRequest)
			return
		}

		if req.TargetUsername == "" {
			http.Error(w, `{"error": "Target username is required"}`, http.StatusBadRequest)
			return
		}

		// Verify that the user exists
		var exists bool
		err := db.QueryRow("SELECT EXISTS(SELECT 1 FROM admins WHERE username = ?)", req.TargetUsername).Scan(&exists)
		if err != nil || !exists {
			http.Error(w, `{"error": "User not found"}`, http.StatusNotFound)
			return
		}

		// Generate a token valid for 1 minute
		expirationTime := time.Now().Add(1 * time.Minute)
		claims := jwt.MapClaims{
			"username": req.TargetUsername,
			"role":     "login_qr", // specific role for QR login
			"exp":      expirationTime.Unix(),
		}

		token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
		tokenString, err := token.SignedString(getJWTSecret())
		if err != nil {
			http.Error(w, `{"error": "Could not generate token"}`, http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"login_token": tokenString,
			"expires_in":  "60",
		})
	}
}

// LoginWithQRHandler logs a user in using a valid login_token
func LoginWithQRHandler(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var req struct {
			LoginToken string `json:"login_token"`
		}

		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"error": "Invalid request"}`, http.StatusBadRequest)
			return
		}
		if !allowRequestAttempt(r, "qr-login", 10, 15*time.Minute) {
			http.Error(w, `{"error": "ลองเข้าสู่ระบบบ่อยเกินไป กรุณารอ 15 นาที"}`, http.StatusTooManyRequests)
			return
		}

		claims, err := parsePurposeToken(req.LoginToken, "login_qr")
		if err != nil {
			http.Error(w, `{"error": "QR Code หมดอายุหรือไม่ถูกต้อง กรุณาสร้างใหม่"}`, http.StatusUnauthorized)
			return
		}

		username, _ := claims["username"].(string)
		if username == "" {
			http.Error(w, `{"error": "QR Code ไม่สมบูรณ์"}`, http.StatusBadRequest)
			return
		}

		// Check if user still exists and get their info
		var id int
		var userRole, profileImage string
		var mustChangePassword int
		err = db.QueryRow("SELECT id, role, COALESCE(profile_image, ''), COALESCE(must_change_password, 0) FROM admins WHERE username = ?", username).Scan(&id, &userRole, &profileImage, &mustChangePassword)
		if err != nil {
			http.Error(w, `{"error": "ไม่พบบัญชีผู้ใช้นี้ในระบบ"}`, http.StatusUnauthorized)
			return
		}

		// Generate the real revocable session token.
		tokenString, err := issueSessionToken(db, id, username, userRole, 24*time.Hour)
		if err != nil {
			http.Error(w, `{"error": "Could not generate session token"}`, http.StatusInternalServerError)
			return
		}

		// Update last_active
		_, _ = db.Exec("UPDATE admins SET last_active = ? WHERE id = ?", time.Now().Format("2006-01-02 15:04:05"), id)

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"token":                tokenString,
			"username":             username,
			"role":                 userRole,
			"profile_image":        profileImage,
			"must_change_password": mustChangePassword == 1,
		})
	}
}
