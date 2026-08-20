package handlers

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"time"

	"dorm_os/utils"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

type SyncAuthRequest struct {
	Name     string `json:"name,omitempty"`
	Email    string `json:"email"`
	Password string `json:"password"`
	Role     string `json:"role,omitempty"`
}

func SetupSyncRoutes(db *sql.DB) {
	http.HandleFunc("/api/auth/register", func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		if r.Method != http.MethodPost {
			http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
			return
		}

		var req SyncAuthRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Bad Request", http.StatusBadRequest)
			return
		}

		if req.Email == "" || req.Password == "" || req.Name == "" {
			http.Error(w, "Name, Email and Password are required", http.StatusBadRequest)
			return
		}

		// Check for existing username
		var count int
		err := db.QueryRow("SELECT COUNT(*) FROM admins WHERE username = ?", req.Name).Scan(&count)
		if err == nil && count > 0 {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusConflict)
			json.NewEncoder(w).Encode(map[string]interface{}{
				"status":  "error",
				"message": "ชื่อผู้ใช้นี้ถูกใช้งานแล้ว",
			})
			return
		}

		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		if err != nil {
			http.Error(w, "Failed to hash password", http.StatusInternalServerError)
			return
		}

		// Check for Authorization header to determine if it's an internal staff creation
		authHeader := r.Header.Get("Authorization")
		var isInternalCreation bool
		var superadminEmail string
		var superadminID int

		if authHeader != "" {
			// Internal staff creation!
			tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
			secret := getJWTSecret()
			token, err := jwt.Parse(tokenStr, func(token *jwt.Token) (interface{}, error) {
				return secret, nil
			})
			if err == nil && token.Valid {
				if claims, ok := token.Claims.(jwt.MapClaims); ok {
					if idFloat, ok := claims["admin_id"].(float64); ok {
						superadminID = int(idFloat)
						// Fetch the superadmin's email
						err = db.QueryRow("SELECT email FROM admins WHERE id = ? AND role = 'superadmin'", superadminID).Scan(&superadminEmail)
						if err == nil && superadminEmail != "" {
							isInternalCreation = true
						}
					}
				}
			}
		}

		var roleToInsert string
		var primaryEmail string
		var backupEmail string

		if isInternalCreation {
			// Option A (Staff): Primary email is superadmin's email, backup email is staff's email
			roleToInsert = req.Role
			if roleToInsert == "" {
				roleToInsert = "admin" // Default staff role
			}
			primaryEmail = superadminEmail
			backupEmail = req.Email // The email sent from AddAdminSheet

			// Check: staff email must not be the same as superadmin's email
			if strings.EqualFold(req.Email, superadminEmail) {
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusConflict)
				json.NewEncoder(w).Encode(map[string]interface{}{
					"status":  "error",
					"message": "ไม่สามารถใช้อีเมลเดียวกับเจ้าของหอพักได้ กรุณาใช้อีเมลอื่น",
				})
				return
			}

			// Check: staff email must not already be used by another admin
			var backupExists bool
			db.QueryRow("SELECT EXISTS(SELECT 1 FROM admins WHERE backup_email = ? OR email = ?)", req.Email, req.Email).Scan(&backupExists)
			if backupExists {
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusConflict)
				json.NewEncoder(w).Encode(map[string]interface{}{
					"status":  "error",
					"message": "อีเมลนี้ถูกใช้งานแล้ว กรุณาใช้อีเมลอื่น",
				})
				return
			}
		} else {
			// Option A (Public Signup): New Superadmin and New Dorm
			roleToInsert = "superadmin"
			primaryEmail = req.Email
			backupEmail = ""
			
			// Ensure primary email doesn't already exist for any admin
			var emailExists bool
			db.QueryRow("SELECT EXISTS(SELECT 1 FROM admins WHERE email = ? OR backup_email = ?)", primaryEmail, primaryEmail).Scan(&emailExists)
			if emailExists {
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusConflict)
				json.NewEncoder(w).Encode(map[string]interface{}{
					"status":  "error",
					"message": "อีเมลนี้ถูกใช้งานแล้ว กรุณาใช้อีเมลอื่น",
				})
				return
			}
		}

		result, err := db.Exec("INSERT INTO admins (username, email, backup_email, password, role) VALUES (?, ?, ?, ?, ?)", req.Name, primaryEmail, backupEmail, string(hashedPassword), roleToInsert)
		if err != nil {
			log.Printf("Registration INSERT error: %v", err)
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusConflict)
			json.NewEncoder(w).Encode(map[string]interface{}{
				"status":  "error",
				"message": "ไม่สามารถสร้างบัญชีได้ หรือข้อมูลซ้ำซ้อน: " + err.Error(),
			})
			return
		}

		adminID, _ := result.LastInsertId()

		if !isInternalCreation {
			// Auto-initialize tenant DB ONLY for new superadmins
			_, _ = GetTenantDB(int(adminID))
		}

		// Generate JWT Token
		secret := getJWTSecret()
		token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
			"admin_id": int(adminID),
			"username": req.Name,
			"role":     roleToInsert,
			"exp":      time.Now().Add(time.Hour * 24 * 365).Unix(), // 1 year expiry for app
		})
		tokenString, _ := token.SignedString(secret)

		// Insert session into database
		_, err = db.Exec("INSERT INTO sessions (admin_id, token) VALUES (?, ?)", int(adminID), tokenString)
		if err != nil {
			log.Printf("Failed to insert session: %v", err)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status": "success",
			"email":  req.Email,
			"name":   req.Name,
			"role":   roleToInsert,
			"token":  tokenString,
		})
	})

	http.HandleFunc("/api/auth/login", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
			return
		}

		var req SyncAuthRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Bad Request", http.StatusBadRequest)
			return
		}

		if req.Email == "" || req.Password == "" {
			http.Error(w, "Email and Password are required", http.StatusBadRequest)
			return
		}

		var adminID int
		var dbPassword string
		var username string
		var role string
		err := db.QueryRow("SELECT id, password, username, COALESCE(NULLIF(role, ''), 'superadmin') FROM admins WHERE email = ? OR username = ? OR backup_email = ?", req.Email, req.Email, req.Email).Scan(&adminID, &dbPassword, &username, &role)
		
		if err != nil {
			http.Error(w, "Invalid email or password", http.StatusUnauthorized)
			return
		}

		if bcrypt.CompareHashAndPassword([]byte(dbPassword), []byte(req.Password)) != nil {
			http.Error(w, "Invalid email or password", http.StatusUnauthorized)
			return
		}

		// Generate JWT Token
		secret := getJWTSecret()
		token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
			"admin_id": adminID,
			"username": username,
			"role":     role,
			"exp":      time.Now().Add(time.Hour * 24 * 365).Unix(),
		})
		tokenString, _ := token.SignedString(secret)

		// Insert session into database
		_, err = db.Exec("INSERT INTO sessions (admin_id, token) VALUES (?, ?)", adminID, tokenString)
		if err != nil {
			log.Printf("Failed to insert session: %v", err)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status": "success",
			"email":  req.Email,
			"name":   username,
			"role":   role,
			"admin_id": adminID,
			"token":  tokenString,
		})
	})

	// ตัวอย่าง API สำหรับให้ Swift App ดึงข้อมูลล่าสุดไปอัพเดทในเครื่อง
	http.HandleFunc("/api/sync/pull", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
			return
		}

		// TODO: Query ฐานข้อมูล (เช่นตาราง users, rooms) แล้วส่งกลับเป็น JSON
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"rooms": []interface{}{},
			"users": []interface{}{},
		})
	})

	// ตัวอย่าง API สำหรับรับข้อมูลจาก Swift App (Push) มาบันทึกลงฐานข้อมูล
	http.HandleFunc("/api/sync/push", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
			return
		}

		// TODO: รับ JSON จาก Swift App แล้ว UPDATE ลงฐานข้อมูล
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"status": "synced successfully",
		})
	})
}
