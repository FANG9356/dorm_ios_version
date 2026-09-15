package handlers

import (
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"dorm_os/utils"
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
	PayloadBase64   string          `json:"payload_base64,omitempty"`
	BaseVersion     *int            `json:"base_version"`
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
		"payload_base64":      base64.StdEncoding.EncodeToString([]byte(payload)),
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
			"sync_protocol": 2,
			"status":        "empty",
			"has_snapshot":  false,
			"account_id":    accountID,
			"email":         email,
		})
		return
	}
	if err != nil {
		http.Error(w, "Sync meta failed", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"sync_protocol":       2,
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
		if !allowRequestAttempt(r, "sync-register", 5, time.Hour) {
			http.Error(w, "Too many registration attempts", http.StatusTooManyRequests)
			return
		}
		req.Name = strings.TrimSpace(req.Name)
		req.Email = strings.ToLower(strings.TrimSpace(req.Email))

		if req.Name == "" || !isValidEmail(req.Email) || !isValidPassword(req.Password) {
			http.Error(w, "Valid name, email and 8-72 character password with letters and numbers are required", http.StatusBadRequest)
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
			parts := strings.Fields(authHeader)
			if len(parts) == 2 && parts[0] == "Bearer" {
				claims, currentRole, authErr := authenticateSession(db, parts[1])
				if authErr == nil && currentRole == "superadmin" {
					superadminID = claims.AdminID
					err = db.QueryRow("SELECT COALESCE(email, '') FROM admins WHERE id = ?", superadminID).Scan(&superadminEmail)
					if err == nil && strings.TrimSpace(superadminEmail) != "" {
						isInternalCreation = true
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
			roleToInsert = strings.ToLower(strings.TrimSpace(roleToInsert))
			if !validStaffRole(roleToInsert) {
				http.Error(w, "Invalid staff role", http.StatusBadRequest)
				return
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

		tokenString, err := issueSessionToken(db, int(adminID), req.Name, roleToInsert, 365*24*time.Hour)
		if err != nil {
			log.Printf("Failed to create session: %v", err)
			http.Error(w, "Failed to create session", http.StatusInternalServerError)
			return
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
		loginIdentifier := strings.ToLower(strings.TrimSpace(req.Email))
		if !allowRequestAttempt(r, "sync-login-ip", 30, 15*time.Minute) ||
			!allowRequestAttempt(r, "sync-login-account:"+loginIdentifier, 10, 15*time.Minute) {
			http.Error(w, "Too many login attempts", http.StatusTooManyRequests)
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

		tokenString, err := issueSessionToken(db, adminID, username, role, 365*24*time.Hour)
		if err != nil {
			log.Printf("Failed to create session: %v", err)
			http.Error(w, "Failed to create session", http.StatusInternalServerError)
			return
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

	http.HandleFunc("/api/sync/push", HandleSyncPush(db))
}
