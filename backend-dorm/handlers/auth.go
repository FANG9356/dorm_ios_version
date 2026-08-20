package handlers

import (
	"context"
	"crypto/rand"
	"database/sql"
	"dorm_os/utils"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"
	"io"
	"path/filepath"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

type Admin struct {
	ID       int    `json:"id"`
	Username string `json:"username"`
	Password string `json:"-"`
	Role         string `json:"role"`
	Email        string `json:"email"`
	ProfileImage string `json:"profile_image"`
}

var jwtSecretKey []byte

func getJWTSecret() []byte {
	if len(jwtSecretKey) > 0 {
		return jwtSecretKey
	}
	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		log.Println("[WARNING] JWT_SECRET is not set! Generating and saving a new secret to .env")
		key := make([]byte, 32)
		rand.Read(key)
		secret = fmt.Sprintf("%x", key)

		f, err := os.OpenFile(".env", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
		if err == nil {
			f.WriteString(fmt.Sprintf("\nJWT_SECRET=%s\n", secret))
			f.Close()
		} else {
			log.Println("[ERROR] Failed to write JWT_SECRET to .env")
		}
	}
	jwtSecretKey = []byte(secret)
	return jwtSecretKey
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

		var count int
		db.QueryRow("SELECT COUNT(*) FROM admins").Scan(&count)
		if count > 0 {
			http.Error(w, `{"error": "Setup already completed"}`, http.StatusForbidden)
			return
		}

		var req struct {
			Username string `json:"username"`
			Password string `json:"password"`
			Email    string `json:"email"`
		}

		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"error": "Invalid request body"}`, http.StatusBadRequest)
			return
		}

		if len(req.Username) < 4 || len(req.Password) < 4 {
			http.Error(w, `{"error": "Username and password must be at least 4 characters"}`, http.StatusBadRequest)
			return
		}

		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		if err != nil {
			http.Error(w, `{"error": "Failed to hash password"}`, http.StatusInternalServerError)
			return
		}

		_, err = db.Exec("INSERT INTO admins (username, password, role, email, profile_image) VALUES (?, ?, ?, ?, '')", req.Username, string(hashedPassword), "services", req.Email)
		if err != nil {
			http.Error(w, `{"error": "Failed to create admin account"}`, http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"message": "Setup completed successfully"})
	}
}

func isValidPassword(p string) bool {
	if len(p) < 8 {
		return false
	}
	hasLetter := regexp.MustCompile(`[a-zA-Z]`).MatchString(p)
	hasNumber := regexp.MustCompile(`[0-9]`).MatchString(p)
	return hasLetter && hasNumber
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

		secret := getJWTSecret()

		token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
			"admin_id": admin.ID,
			"username": admin.Username,
			"role":     admin.Role,
			"exp":      time.Now().Add(time.Hour * 24).Unix(),
		})

		tokenString, err := token.SignedString(secret)
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

		if path == "/api/login" || path == "/api/login/qr" || path == "/api/register" || path == "/api/change-password" || path == "/api/forgot-password" || path == "/api/verify-otp" || path == "/api/reset-password" || path == "/api/webhook/line" || path == "/api/liff/link" || path == "/api/liff/rooms" || path == "/api/liff/verify-tenant" || path == "/api/setup/status" || path == "/api/setup" || path == "/api/system/ping" || path == "/api/auth/register" || path == "/api/auth/login" {
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
		} else {
			tokenStr = r.URL.Query().Get("token")
		}

		if tokenStr == "" {
			http.Error(w, `{"error": "Unauthorized: Missing Token"}`, http.StatusUnauthorized)
			return
		}
		secret := getJWTSecret()

		token, err := jwt.Parse(tokenStr, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
			}
			return secret, nil
		})

		if err != nil || !token.Valid {
			http.Error(w, `{"error": "Unauthorized: Invalid or Expired Token"}`, http.StatusUnauthorized)
			return
		}

		// ตรวจสอบกับ Database ว่าแอดมินคนนี้ยังคงมีตัวตนอยู่หรือไม่ (ป้องกันบัญชีถูกลบแต่ยังเข้าสู่ระบบได้)
		if claims, ok := token.Claims.(jwt.MapClaims); ok {
			var exists int
			adminID := int(claims["admin_id"].(float64)) // JWT numbers are float64
			err := db.QueryRow("SELECT 1 FROM admins WHERE id = ?", adminID).Scan(&exists)
			if err != nil || exists == 0 {
				http.Error(w, `{"error": "Unauthorized: Account no longer exists"}`, http.StatusUnauthorized)
				return
			}
			
			// Check if session exists in DB (for remote logout/kick)
			var sessionExists int
			err = db.QueryRow("SELECT 1 FROM sessions WHERE admin_id = ? AND token = ?", adminID, tokenStr).Scan(&sessionExists)
			if err != nil || sessionExists == 0 {
				http.Error(w, `{"error": "Unauthorized: Session expired or logged out"}`, http.StatusUnauthorized)
				return
			}

			// Inject admin_id into context
			ctx := context.WithValue(r.Context(), "admin_id", adminID)
			next.ServeHTTP(w, r.WithContext(ctx))
			return
		} else {
			http.Error(w, `{"error": "Unauthorized: Invalid Token Claims"}`, http.StatusUnauthorized)
			return
		}
	})
}

func IsServicesRole(r *http.Request) bool {
	authHeader := r.Header.Get("Authorization")
	tokenStr := ""
	if authHeader != "" {
		parts := strings.Split(authHeader, " ")
		if len(parts) == 2 && parts[0] == "Bearer" {
			tokenStr = parts[1]
		}
	} else {
		tokenStr = r.URL.Query().Get("token")
	}

	if tokenStr == "" {
		return false
	}

	secret := getJWTSecret()
	token, err := jwt.Parse(tokenStr, func(token *jwt.Token) (interface{}, error) {
		return secret, nil
	})

	if err == nil && token.Valid {
		if claims, ok := token.Claims.(jwt.MapClaims); ok {
			role, _ := claims["role"].(string)
			return role == "superadmin" || role == "admin" || role == "services"
		}
	}
	return false
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
		debugInfo := ""
		if tokenStr != "" {
			token, err := jwt.Parse(tokenStr, func(token *jwt.Token) (interface{}, error) {
				if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
					return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
				}
				return getJWTSecret(), nil
			})
			debugInfo += fmt.Sprintf("err=%v, valid=%v, ", err, token != nil && token.Valid)
			if err == nil && token.Valid {
				if claims, ok := token.Claims.(jwt.MapClaims); ok {
					username, okStr := claims["username"].(string)
					debugInfo += fmt.Sprintf("claim_uname=%s, req_uname=%s, ", username, req.Username)
					if okStr && username == req.Username {
						authenticated = true
					}
				} else {
					debugInfo += "claims_fail, "
				}
			}
		} else {
			debugInfo += "token_empty, "
		}

		if !authenticated {
			if req.OldPassword == "" || bcrypt.CompareHashAndPassword([]byte(admin.Password), []byte(req.OldPassword)) != nil {
				w.WriteHeader(http.StatusUnauthorized)
				w.Write([]byte(fmt.Sprintf(`{"error": "ชื่อผู้ใช้หรือรหัสผ่านเดิมไม่ถูกต้อง (DEBUG: %s)"}`, debugInfo)))
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

		_, err = db.Exec("UPDATE admins SET username = ?, password = ?, must_change_password = 0 WHERE id = ?", newUsername, string(hashedPassword), admin.ID)
		if err != nil {
			http.Error(w, `{"error": "ไม่สามารถอัปเดตข้อมูลได้ ชื่อผู้ใช้นี้อาจมีคนใช้แล้ว"}`, http.StatusInternalServerError)
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

		// Extract admin_id from JWT to filter by tenant (same primary email)
		var filterEmail string
		authHeader := r.Header.Get("Authorization")
		if authHeader != "" {
			tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
			secret := getJWTSecret()
			token, err := jwt.Parse(tokenStr, func(token *jwt.Token) (interface{}, error) {
				return secret, nil
			})
			if err == nil && token.Valid {
				if claims, ok := token.Claims.(jwt.MapClaims); ok {
					if idFloat, ok := claims["admin_id"].(float64); ok {
						adminID := int(idFloat)
						// Get the primary email of this admin
						db.QueryRow("SELECT email FROM admins WHERE id = ?", adminID).Scan(&filterEmail)
					}
				}
			}
		}

		var rows *sql.Rows
		var err error
		if filterEmail != "" {
			// Multi-tenant: only show admins with the same primary email (= same dorm)
			rows, err = db.Query("SELECT id, username, last_active, COALESCE(role, 'admin'), COALESCE(email, ''), COALESCE(profile_image, ''), COALESCE(backup_email, '') FROM admins WHERE email = ? ORDER BY id ASC", filterEmail)
		} else {
			// Fallback: no token, show all (for backwards compatibility)
			rows, err = db.Query("SELECT id, username, last_active, COALESCE(role, 'admin'), COALESCE(email, ''), COALESCE(profile_image, ''), COALESCE(backup_email, '') FROM admins ORDER BY id ASC")
		}
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
			if err := rows.Scan(&id, &username, &lastActive, &role, &email, &profileImage, &backupEmail); err != nil {
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

		if !IsServicesRole(r) {
			http.Error(w, `{"error": "Unauthorized: Services role required"}`, http.StatusForbidden)
			return
		}

		var req struct {
			Username string `json:"username"`
			Role     string `json:"role"`
			Email    string `json:"email"`
		}

		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || strings.TrimSpace(req.Username) == "" {
			http.Error(w, `{"error": "Invalid request"}`, http.StatusBadRequest)
			return
		}

		req.Username = strings.TrimSpace(req.Username)
		req.Email = strings.TrimSpace(req.Email)

		// Check if username already exists
		var userExists bool
		err := db.QueryRow("SELECT EXISTS(SELECT 1 FROM admins WHERE LOWER(username) = LOWER(?))", req.Username).Scan(&userExists)
		if err == nil && userExists {
			http.Error(w, `{"error": "ชื่อผู้ใช้นี้มีอยู่ในระบบแล้ว กรุณาใช้ชื่ออื่น"}`, http.StatusConflict)
			return
		}

		hashedPassword, err := bcrypt.GenerateFromPassword([]byte("admin"), bcrypt.DefaultCost)
		if err != nil {
			http.Error(w, `{"error": "Failed to generate password"}`, http.StatusInternalServerError)
			return
		}

		role := req.Role
		if role == "" {
			role = "admin"
		}

		_, err = db.Exec("INSERT INTO admins (username, password, role, email, must_change_password) VALUES (?, ?, ?, ?, 1)", req.Username, string(hashedPassword), role, req.Email)
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

		if !IsServicesRole(r) {
			http.Error(w, `{"error": "Unauthorized: Services role required"}`, http.StatusForbidden)
			return
		}

		// Extract ID from URL
		parts := strings.Split(r.URL.Path, "/")
		if len(parts) < 4 {
			http.Error(w, `{"error": "Invalid URL"}`, http.StatusBadRequest)
			return
		}
		id := parts[3]

		// Prevent deleting superadmin account
		var targetRole string
		err := db.QueryRow("SELECT role FROM admins WHERE id = ?", id).Scan(&targetRole)
		if err == nil && targetRole == "superadmin" {
			http.Error(w, `{"error": "ไม่สามารถลบบัญชี Super Admin ได้"}`, http.StatusForbidden)
			return
		}

		// Delete active sessions for this admin first
		db.Exec("DELETE FROM sessions WHERE admin_id = ?", id)

		_, err = db.Exec("DELETE FROM admins WHERE id = ?", id)
		if err != nil {
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

		var req struct {
			Username    string `json:"username"`
			OldPassword string `json:"old_password"`
			NewPassword string `json:"new_password"`
			Role        string `json:"role"`
			Email       string `json:"email"`
			BackupEmail string `json:"backup_email"`
		}

		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"error": "Invalid request"}`, http.StatusBadRequest)
			return
		}

		if req.Email != "" && req.BackupEmail != "" && strings.EqualFold(strings.TrimSpace(req.Email), strings.TrimSpace(req.BackupEmail)) {
			http.Error(w, `{"error": "อีเมลสำรองต้องไม่ตรงกับอีเมลหลัก"}`, http.StatusBadRequest)
			return
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
			// Require old password if not superadmin
			requesterID, ok := r.Context().Value("admin_id").(float64)
			if ok {
				var requesterRole string
				db.QueryRow("SELECT role FROM admins WHERE id = ?", int(requesterID)).Scan(&requesterRole)
				
				// If they are not superadmin, they must provide the correct old password
				if requesterRole != "superadmin" {
					if req.OldPassword == "" {
						http.Error(w, `{"error": "ต้องระบุรหัสผ่านเดิมเพื่อเปลี่ยนรหัสผ่านใหม่"}`, http.StatusBadRequest)
						return
					}
					
					var currentHashedPassword string
					err := db.QueryRow("SELECT password FROM admins WHERE id = ?", id).Scan(&currentHashedPassword)
					if err != nil {
						http.Error(w, `{"error": "ไม่พบผู้ใช้นี้"}`, http.StatusNotFound)
						return
					}
					
					if err := bcrypt.CompareHashAndPassword([]byte(currentHashedPassword), []byte(req.OldPassword)); err != nil {
						http.Error(w, `{"error": "รหัสผ่านเดิมไม่ถูกต้อง"}`, http.StatusUnauthorized)
						return
					}
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

		_, err = db.Exec(query, args...)
		if err != nil {
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

		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			http.Error(w, "Missing Authorization header", http.StatusUnauthorized)
			return
		}
		tokenString := strings.TrimPrefix(authHeader, "Bearer ")
		claims := jwt.MapClaims{}
		token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
			return getJWTSecret(), nil
		})
		if err != nil || !token.Valid {
			http.Error(w, "Invalid token", http.StatusUnauthorized)
			return
		}

		username, _ := claims["username"].(string)
		db.Exec("UPDATE admins SET last_active = CURRENT_TIMESTAMP WHERE username = ?", username)

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

		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			http.Error(w, "Missing Authorization header", http.StatusUnauthorized)
			return
		}
		tokenString := strings.TrimPrefix(authHeader, "Bearer ")
		claims := jwt.MapClaims{}
		token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
			return getJWTSecret(), nil
		})
		if err != nil || !token.Valid {
			http.Error(w, "Invalid token", http.StatusUnauthorized)
			return
		}

		username, _ := claims["username"].(string)
		// Set last_active to an old date to instantly show as Offline
		db.Exec("UPDATE admins SET last_active = '2000-01-01 00:00:00' WHERE username = ?", username)
		
		// Remove session to force remote kick
		db.Exec("DELETE FROM sessions WHERE token = ?", tokenString)

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

		adminID := r.URL.Query().Get("id")
		if adminID == "" {
			http.Error(w, `{"error": "Missing admin ID"}`, http.StatusBadRequest)
			return
		}

		err := r.ParseMultipartForm(10 << 20) // 10 MB limit
		if err != nil {
			http.Error(w, `{"error": "Unable to parse form"}`, http.StatusBadRequest)
			return
		}

		file, handler, err := r.FormFile("profile_image")
		if err != nil {
			http.Error(w, `{"error": "Error retrieving the file"}`, http.StatusBadRequest)
			return
		}
		defer file.Close()

		// Ensure directory exists
		uploadDir := "./uploads/profiles"
		os.MkdirAll(uploadDir, os.ModePerm)

		// Create unique filename
		ext := filepath.Ext(handler.Filename)
		if ext == "" {
			ext = ".jpg" // default
		}
		fileName := fmt.Sprintf("admin_%s_%d%s", adminID, time.Now().Unix(), ext)
			filePath := filepath.Join(uploadDir, fileName)

		dst, err := os.Create(filePath)
		if err != nil {
			http.Error(w, `{"error": "Error saving the file"}`, http.StatusInternalServerError)
			return
		}
		defer dst.Close()

		if _, err := io.Copy(dst, file); err != nil {
			http.Error(w, `{"error": "Error writing the file"}`, http.StatusInternalServerError)
			return
		}

		// Update database
		imageURL := "/uploads/profiles/" + fileName
		_, err = db.Exec("UPDATE admins SET profile_image = ? WHERE id = ?", imageURL, adminID)
		if err != nil {
			http.Error(w, `{"error": "Database error"}`, http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"message": "Profile image updated successfully",
			"profile_image": imageURL,
		})
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

		if len(req.Name) < 3 || len(req.Password) < 4 || len(req.Email) < 5 {
			http.Error(w, `{"status": "error", "message": "ชื่อ, อีเมล และรหัสผ่าน ต้องมีความยาวที่เหมาะสม"}`, http.StatusBadRequest)
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
		result, err := db.Exec("INSERT INTO admins (username, password, role, email) VALUES (?, ?, 'superadmin', ?)", req.Name, hashedPassword, req.Email)
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

		// Generate JWT Token so they can login immediately
		claims := jwt.MapClaims{
			"username": req.Name,
			"role":     "superadmin",
			"admin_id": int(adminID),
			"exp":      time.Now().Add(24 * time.Hour).Unix(),
		}
		token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
		tokenString, err := token.SignedString(getJWTSecret())
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
			"expires_in": "300",
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

		// Verify Token
		claims := jwt.MapClaims{}
		token, err := jwt.ParseWithClaims(req.InviteToken, claims, func(token *jwt.Token) (interface{}, error) {
			return getJWTSecret(), nil
		})

		role, _ := claims["role"].(string)

		if err != nil || !token.Valid || role != "invite" {
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

		// Verify Token
		claims := jwt.MapClaims{}
		token, err := jwt.ParseWithClaims(req.LoginToken, claims, func(token *jwt.Token) (interface{}, error) {
			return getJWTSecret(), nil
		})

		if err != nil || !token.Valid {
			http.Error(w, `{"error": "QR Code หมดอายุหรือไม่ถูกต้อง กรุณาสร้างใหม่"}`, http.StatusUnauthorized)
			return
		}

		role, _ := claims["role"].(string)
		if role != "login_qr" {
			http.Error(w, `{"error": "QR Code ไม่ใช่สำหรับการเข้าสู่ระบบ"}`, http.StatusUnauthorized)
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

		// Generate the real dorminet_token (session token)
		expirationTime := time.Now().Add(24 * time.Hour)
		sessionClaims := jwt.MapClaims{
			"admin_id": id,
			"username": username,
			"role":     userRole,
			"exp":      expirationTime.Unix(),
		}

		sessionToken := jwt.NewWithClaims(jwt.SigningMethodHS256, sessionClaims)
		tokenString, err := sessionToken.SignedString(getJWTSecret())
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
