package handlers

import (
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
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

type SyncSnapshotRequest struct {
	Payload         json.RawMessage `json:"payload"`
	DeviceID        string          `json:"device_id,omitempty"`
	ClientUpdatedAt string          `json:"client_updated_at,omitempty"`
}

func resolveSyncAccount(db *sql.DB, r *http.Request) (int, int, string, error) {
	adminIDValue := r.Context().Value("admin_id")
	adminID, ok := adminIDValue.(int)
	if !ok || adminID <= 0 {
		return 0, 0, "", fmt.Errorf("missing admin id")
	}

	var email string
	if err := db.QueryRow("SELECT COALESCE(email, '') FROM admins WHERE id = ?", adminID).Scan(&email); err != nil {
		return 0, 0, "", err
	}

	email = strings.ToLower(strings.TrimSpace(email))
	accountID := adminID
	if email != "" {
		var ownerID int
		err := db.QueryRow("SELECT id FROM admins WHERE email = ? AND role = 'superadmin' ORDER BY id ASC LIMIT 1", email).Scan(&ownerID)
		if err == nil && ownerID > 0 {
			accountID = ownerID
		}
	}

	return adminID, accountID, email, nil
}

func writeLatestSnapshot(db *sql.DB, w http.ResponseWriter, accountID int, email string) {
	var snapshotID string
	var version int
	var payload string
	var checksum string
	var size int
	var deviceID string
	var createdAt string
	var createdBy int

	err := db.QueryRow(`
		SELECT snapshot_id, version, payload, checksum, size, COALESCE(device_id, ''), created_at, created_by_admin_id
		FROM sync_snapshots
		WHERE account_id = ?
		ORDER BY version DESC
		LIMIT 1
	`, accountID).Scan(&snapshotID, &version, &payload, &checksum, &size, &deviceID, &createdAt, &createdBy)
	if err == sql.ErrNoRows {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":       "empty",
			"has_snapshot": false,
			"account_id":   accountID,
			"email":        email,
		})
		return
	}
	if err != nil {
		http.Error(w, "Sync latest failed", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":              "success",
		"has_snapshot":        true,
		"snapshot_id":         snapshotID,
		"account_id":          accountID,
		"email":               email,
		"version":             version,
		"created_at":          createdAt,
		"created_by_admin_id": createdBy,
		"device_id":           deviceID,
		"checksum":            checksum,
		"size":                size,
		"payload":             json.RawMessage(payload),
	})
}

func writeLatestSnapshotMeta(db *sql.DB, w http.ResponseWriter, accountID int, email string) {
	var snapshotID string
	var version int
	var checksum string
	var size int
	var deviceID string
	var createdAt string
	var createdBy int

	err := db.QueryRow(`
		SELECT snapshot_id, version, checksum, size, COALESCE(device_id, ''), created_at, created_by_admin_id
		FROM sync_snapshots
		WHERE account_id = ?
		ORDER BY version DESC
		LIMIT 1
	`, accountID).Scan(&snapshotID, &version, &checksum, &size, &deviceID, &createdAt, &createdBy)
	if err == sql.ErrNoRows {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":       "empty",
			"has_snapshot": false,
			"account_id":   accountID,
			"email":        email,
		})
		return
	}
	if err != nil {
		http.Error(w, "Sync meta failed", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":              "success",
		"has_snapshot":        true,
		"snapshot_id":         snapshotID,
		"account_id":          accountID,
		"email":               email,
		"version":             version,
		"created_at":          createdAt,
		"created_by_admin_id": createdBy,
		"device_id":           deviceID,
		"checksum":            checksum,
		"size":                size,
	})
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
			primaryEmail = strings.ToLower(strings.TrimSpace(req.Email))
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
			"status":   "success",
			"email":    req.Email,
			"name":     username,
			"role":     role,
			"admin_id": adminID,
			"token":    tokenString,
		})
	})

	// ตัวอย่าง API สำหรับให้ Swift App ดึงข้อมูลล่าสุดไปอัพเดทในเครื่อง
	latestHandler := func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
			return
		}

		_, accountID, email, err := resolveSyncAccount(db, r)
		if err != nil {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		writeLatestSnapshot(db, w, accountID, email)
	}

	http.HandleFunc("/api/sync/latest", latestHandler)
	http.HandleFunc("/api/sync/pull", latestHandler)
	http.HandleFunc("/api/sync/meta", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
			return
		}

		_, accountID, email, err := resolveSyncAccount(db, r)
		if err != nil {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		writeLatestSnapshotMeta(db, w, accountID, email)
	})

	http.HandleFunc("/api/sync/push", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
			return
		}

		adminID, accountID, email, err := resolveSyncAccount(db, r)
		if err != nil {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		var req SyncSnapshotRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Bad Request", http.StatusBadRequest)
			return
		}
		if len(req.Payload) == 0 || string(req.Payload) == "null" || !json.Valid(req.Payload) {
			http.Error(w, "Invalid payload", http.StatusBadRequest)
			return
		}

		var nextVersion int
		if err := db.QueryRow("SELECT COALESCE(MAX(version), 0) + 1 FROM sync_snapshots WHERE account_id = ?", accountID).Scan(&nextVersion); err != nil {
			http.Error(w, "Sync push failed", http.StatusInternalServerError)
			return
		}

		var canonicalPayload interface{}
		if err := json.Unmarshal(req.Payload, &canonicalPayload); err != nil {
			http.Error(w, "Invalid payload", http.StatusBadRequest)
			return
		}
		canonicalBytes, err := json.Marshal(canonicalPayload)
		if err != nil {
			http.Error(w, "Invalid payload", http.StatusBadRequest)
			return
		}

		payload := string(canonicalBytes)
		sum := sha256.Sum256(canonicalBytes)
		checksum := hex.EncodeToString(sum[:])
		createdAt := time.Now().UTC().Format(time.RFC3339Nano)
		snapshotID := fmt.Sprintf("acct-%d-v%d-%s", accountID, nextVersion, checksum[:12])

		_, err = db.Exec(`
			INSERT INTO sync_snapshots (snapshot_id, account_id, version, payload, checksum, size, device_id, created_at, created_by_admin_id)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
		`, snapshotID, accountID, nextVersion, payload, checksum, len(canonicalBytes), req.DeviceID, createdAt, adminID)
		if err != nil {
			http.Error(w, "Sync push failed", http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":      "success",
			"snapshot_id": snapshotID,
			"account_id":  accountID,
			"email":       email,
			"version":     nextVersion,
			"created_at":  createdAt,
			"checksum":    checksum,
			"size":        len(canonicalBytes),
		})
	})
}
