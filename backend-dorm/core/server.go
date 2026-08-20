package core

import (
	"database/sql"
	"dorm_os/handlers"
	"dorm_os/utils"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"time"
	"dorm_os/p2p"
	"github.com/joho/godotenv"

	_ "github.com/mattn/go-sqlite3"
)

// Models moved to models.go

func RunServer() {
	defer func() {
		if r := recover(); r != nil {
			errStr := fmt.Sprintf("Panic in RunServer: %v", r)
			os.WriteFile("panic_log.txt", []byte(errStr), 0644)
		}
	}()
	_ = godotenv.Load()

	dbPath := os.Getenv("DB_PATH")
	if dbPath == "" {
		dbPath = "./dormitory.db"
	}

	db, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		log.Fatal(err)
	}

	// เปิด WAL mode และ Busy Timeout
	db.Exec("PRAGMA journal_mode=WAL;")
	db.Exec("PRAGMA busy_timeout=5000;")
	db.SetMaxOpenConns(25) // อนุญาตให้เชื่อมต่อหลายครั้งพร้อมกัน
	db.SetMaxIdleConns(25)
	db.SetConnMaxLifetime(5 * time.Minute)
	defer db.Close()

	// Start P2P Node
	if _, err := p2p.StartP2PNode(); err != nil {
		log.Printf("Failed to start P2P node: %v\n", err)
	}

	os.MkdirAll("./uploads", os.ModePerm)
	os.MkdirAll("./backups", os.ModePerm)
	os.MkdirAll("./backups_zip", os.ModePerm)
	http.Handle("/uploads/", http.StripPrefix("/uploads/", http.FileServer(http.Dir("./uploads"))))

	InitializeDatabase(db)
	handlers.InitAdminTable(db)
	handlers.SetupDormRoutes(db)

	http.HandleFunc("/api/login", handlers.LoginHandler(db))
	http.HandleFunc("/api/setup/status", handlers.CheckSetupStatus(db))
	http.HandleFunc("/api/setup", handlers.PerformSetup(db))
	http.HandleFunc("/api/system/ping", func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"online"}`))
	})
	http.HandleFunc("/api/change-password", handlers.ChangePasswordHandler(db))
	http.HandleFunc("/api/webhook/line", handlers.HandleLineWebhook(db))
	http.Handle("/api/admin/push-invoices", handlers.AuthMiddleware(db, handlers.HandlePushInvoices(db)))
	http.HandleFunc("/api/liff/rooms", handlers.HandleLiffRooms(db))
	http.HandleFunc("/api/liff/verify-tenant", handlers.HandleLiffVerify(db))
	http.HandleFunc("/api/liff/link", handlers.HandleLiffLink(db))

	http.HandleFunc("/api/admins", func(w http.ResponseWriter, r *http.Request) {
		if r.Method == "GET" || r.Method == "OPTIONS" {
			handlers.GetAdminsHandler(db)(w, r)
		} else if r.Method == "POST" {
			handlers.CreateAdminHandler(db)(w, r)
		} else {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	})
	http.HandleFunc("/api/admins/profile-image", handlers.UpdateProfileImageHandler(db))
	http.HandleFunc("/api/admins/", func(w http.ResponseWriter, r *http.Request) {
		if r.Method == "DELETE" || r.Method == "OPTIONS" {
			handlers.DeleteAdminHandler(db)(w, r)
		} else if r.Method == "PUT" {
			handlers.UpdateAdminHandler(db)(w, r)
		} else {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	})
	http.HandleFunc("/api/admins/ping", handlers.PingAdminHandler(db))
	http.HandleFunc("/api/logout", handlers.LogoutAdminHandler(db))
	
	http.Handle("/api/admins/invite/generate", handlers.AuthMiddleware(db, handlers.GenerateInviteTokenHandler(db)))
	http.HandleFunc("/api/admins/invite/register", handlers.RegisterWithInviteHandler(db))
	
	http.HandleFunc("/api/register", handlers.RegisterHandler(db))
	
	http.Handle("/api/admins/login-qr/generate", handlers.AuthMiddleware(db, handlers.GenerateLoginTokenHandler(db)))
	http.HandleFunc("/api/login/qr", handlers.LoginWithQRHandler(db))

	// [NEW] Setup Forgot Password routes
	handlers.SetupAuthResetRoutes(db)

	// Start daily backup scheduler at 10 PM
	go handlers.StartBackupScheduler(db, dbPath, "./uploads", "./backups")

	http.HandleFunc("/api/system/backup/auto", func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method == "POST" {
			go func() {
				_ = handlers.PerformZipBackup(db, "./backups_zip")
			}()
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
		}
	})

	http.HandleFunc("/api/system/backup/zip", func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method == "GET" {
			zipData, err := handlers.GenerateZipBackupData(db)
			if err != nil {
				http.Error(w, "Backup generation failed: "+err.Error(), http.StatusInternalServerError)
				return
			}

			// Also save a copy on the server in "backups_zip"
			backupZipDir := "./backups_zip"
			_ = os.MkdirAll(backupZipDir, os.ModePerm)
			fileName := fmt.Sprintf("backup_%s.zip", time.Now().Format("2006-01-02_15-04-05"))
			_ = os.WriteFile(filepath.Join(backupZipDir, fileName), zipData, 0644)

			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
		}
	})

	http.HandleFunc("/api/system/backups", func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method == "GET" {
			type BackupItem struct {
				Name      string    `json:"name"`
				Type      string    `json:"type"` // "zip"
				Size      int64     `json:"size"`
				CreatedAt time.Time `json:"created_at"`
			}
			var list []BackupItem

			zFiles, err := os.ReadDir("./backups_zip")
			if err == nil {
				for _, f := range zFiles {
					if !f.IsDir() && len(f.Name()) > 7 && f.Name()[:7] == "backup_" && filepath.Ext(f.Name()) == ".zip" {
						info, err := f.Info()
						if err == nil {
							list = append(list, BackupItem{
								Name:      f.Name(),
								Type:      "zip",
								Size:      info.Size(),
								CreatedAt: info.ModTime(),
							})
						}
					}
				}
			}

			sort.Slice(list, func(i, j int) bool {
				return list[i].CreatedAt.After(list[j].CreatedAt)
			})

			utils.WriteJSON(w, http.StatusOK, list)
			return
		}
		if r.Method == "DELETE" {
			name := r.URL.Query().Get("name")
			if name == "" {
				http.Error(w, "Missing name", http.StatusBadRequest)
				return
			}
			if !utils.IsSafeBackupName(name) {
				http.Error(w, "Invalid name", http.StatusBadRequest)
				return
			}
			targetPath := filepath.Join("./backups_zip", name)
			if _, err := os.Stat(targetPath); os.IsNotExist(err) {
				http.Error(w, "Backup not found", http.StatusNotFound)
				return
			}
			if err := os.Remove(targetPath); err != nil {
				http.Error(w, "Delete failed: "+err.Error(), http.StatusInternalServerError)
				return
			}
			db.Exec("INSERT INTO system_logs (action_type, details, timestamp) VALUES ('Backup Delete', ?, ?)", "ลบไฟล์สำรองข้อมูล (zip) "+name, time.Now().Format("2006-01-02 15:04:05"))
			w.WriteHeader(http.StatusOK)
			return
		}
	})

	http.HandleFunc("/api/system/backups/open-folder", func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method == "GET" {
			absPath, err := filepath.Abs("./backups_zip")
			if err != nil {
				http.Error(w, "Cannot get absolute path", http.StatusInternalServerError)
				return
			}

			var cmd *exec.Cmd
			switch runtime.GOOS {
			case "darwin":
				cmd = exec.Command("open", absPath)
			case "windows":
				cmd = exec.Command("explorer", absPath)
			default: // "linux", "freebsd", "openbsd", "netbsd"
				cmd = exec.Command("xdg-open", absPath)
			}

			if err := cmd.Start(); err != nil {
				http.Error(w, "Failed to open folder: "+err.Error(), http.StatusInternalServerError)
				return
			}

			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(map[string]string{"status": "ok", "path": absPath})
		}
	})

	http.HandleFunc("/api/system/backups/all", func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method == "DELETE" {
			os.RemoveAll("./backups_zip")
			os.MkdirAll("./backups_zip", os.ModePerm)

			db.Exec("INSERT INTO system_logs (action_type, details, timestamp) VALUES ('Backup Delete All', ?, ?)", "ลบไฟล์สำรองข้อมูลทั้งหมดในระบบ", time.Now().Format("2006-01-02 15:04:05"))
			w.WriteHeader(http.StatusOK)
		}
	})

	http.HandleFunc("/api/system/backups/download", func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method == "GET" {
			name := r.URL.Query().Get("name")
			if name == "" {
				http.Error(w, "Missing name", http.StatusBadRequest)
				return
			}
			if !utils.IsSafeBackupName(name) {
				http.Error(w, "Invalid name", http.StatusBadRequest)
				return
			}
			filePath := filepath.Join("./backups_zip", name)
			if _, err := os.Stat(filePath); os.IsNotExist(err) {
				http.Error(w, "Backup not found", http.StatusNotFound)
				return
			}
			w.Header().Set("Content-Type", "application/zip")
			w.Header().Set("Content-Disposition", "attachment; filename="+name)
			http.ServeFile(w, r, filePath)
		}
	})

	http.HandleFunc("/api/system/restore/zip", func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method != "POST" {
			return
		}
		// Parse multipart form (up to 1GB to support large backups)
		if err := r.ParseMultipartForm(1024 << 20); err != nil {
			http.Error(w, "Invalid upload", http.StatusBadRequest)
			return
		}
		file, _, err := r.FormFile("backup_file")
		if err != nil {
			http.Error(w, "Invalid file", http.StatusBadRequest)
			return
		}
		defer file.Close()
		// Save uploaded file to temp file to prevent memory exhaustion on large files
		tempFile, err := os.CreateTemp("", "restore-*.zip")
		if err != nil {
			http.Error(w, "Cannot create temp file", http.StatusInternalServerError)
			return
		}
		tempName := tempFile.Name()
		defer os.Remove(tempName)

		if _, err := io.Copy(tempFile, file); err != nil {
			tempFile.Close()
			http.Error(w, "Cannot write temp file", http.StatusInternalServerError)
			return
		}
		tempFile.Close()

		if err := handlers.PerformRestore(db, tempName); err != nil {
			http.Error(w, "Restore failed", http.StatusInternalServerError)
			return
		}
		w.WriteHeader(http.StatusOK)
	})

	http.HandleFunc("/api/system/backups/restore", func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method == "POST" {
			name := r.URL.Query().Get("name")
			if !utils.IsSafeBackupName(name) {
				http.Error(w, "Invalid name", http.StatusBadRequest)
				return
			}
			filePath := filepath.Join("./backups_zip", name)
			if err := handlers.PerformRestore(db, filePath); err != nil {
				http.Error(w, "Restore failed", http.StatusInternalServerError)
				return
			}
			w.WriteHeader(http.StatusOK)
		}
	})

	http.HandleFunc("/api/system/reset", func(w http.ResponseWriter, r *http.Request) {
		utils.EnableCORS(w)
		if r.Method == "OPTIONS" {
			return
		}
		if r.Method != "POST" {
			return
		}
		// Only services role can reset the entire system
		if !handlers.IsServicesRole(r) {
			http.Error(w, `{"error": "Unauthorized: Services role required"}`, http.StatusForbidden)
			return
		}
		tx, err := db.Begin()
		if err != nil {
			http.Error(w, "Database error", http.StatusInternalServerError)
			return
		}
		defer utils.RollbackOnErr(tx, &err)

		tables := []string{"payments", "users", "rooms", "room_types", "deposit_refunds", "room_conditions", "maintenances", "system_logs"}
		for _, table := range tables {
			if _, err = tx.Exec("DELETE FROM " + table); err != nil {
				http.Error(w, "Reset failed", http.StatusInternalServerError)
				return
			}
		}
		tx.Exec("DELETE FROM sqlite_sequence")
		if _, err = tx.Exec("INSERT INTO system_logs (action_type, details, timestamp) VALUES ('System Reset', 'ล้างข้อมูลโครงสร้างระบบทั้งหมด', ?)", time.Now().Format("2006-01-02 15:04:05")); err != nil {
			http.Error(w, "Reset failed", http.StatusInternalServerError)
			return
		}
		if err = tx.Commit(); err != nil {
			http.Error(w, "Reset failed", http.StatusInternalServerError)
			return
		}
		
		// Preserve admin profiles during reset
		err = os.Rename("./uploads/profiles", "./profiles_temp")
		
		os.RemoveAll("./uploads")
		os.MkdirAll("./uploads", os.ModePerm)
		
		if err == nil {
			os.MkdirAll("./uploads/profiles", os.ModePerm)
			os.Rename("./profiles_temp", "./uploads/profiles")
		}
		
		w.WriteHeader(http.StatusOK)
	})

	setupStaticHandler()

	// [เพิ่มใหม่] Reverse Proxy สำหรับส่งต่อคำสั่งเกี่ยวกับ WiFi ไปยัง backend-network (Port 8911) แบบซ่อนหลังบ้าน
	targetUrl, _ := url.Parse("http://127.0.0.1:8911")
	proxy := httputil.NewSingleHostReverseProxy(targetUrl)
	http.HandleFunc("/api/wifi/", func(w http.ResponseWriter, r *http.Request) {
		proxy.ServeHTTP(w, r)
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = "4282"
	}

	fmt.Println("DormiNet Server Online: Core Module Ready (HTTP: " + port + ")")

	handler := handlers.AuthMiddleware(db, http.DefaultServeMux)

	srv := &http.Server{Addr: ":" + port, Handler: handler, ReadTimeout: 15 * time.Second, WriteTimeout: 15 * time.Second, IdleTimeout: 60 * time.Second}

	if os.Getenv("ENABLE_HTTPS") == "true" {
		fmt.Println("[SECURITY] HTTPS is ENABLED. Booting secure server...")
		if err := utils.EnsureTLSCerts("cert.pem", "key.pem"); err != nil {
			log.Fatalf("Failed to initialize SSL certs: %v", err)
		}
		log.Fatal(srv.ListenAndServeTLS("cert.pem", "key.pem"))
	} else {
		log.Fatal(srv.ListenAndServe())
	}
}

func setupStaticHandler() {
	const distDir = "./dist"
	fileServer := http.FileServer(http.Dir(distDir))
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			http.NotFound(w, r)
			return
		}
		cleanPath := filepath.Clean(r.URL.Path)
		if cleanPath == "/" || cleanPath == "." {
			http.ServeFile(w, r, filepath.Join(distDir, "index.html"))
			return
		}
		rel := strings.TrimPrefix(cleanPath, "/")
		fullPath := filepath.Join(distDir, rel)
		if info, err := os.Stat(fullPath); err == nil && !info.IsDir() {
			fileServer.ServeHTTP(w, r)
			return
		}
		http.ServeFile(w, r, filepath.Join(distDir, "index.html"))
	})
}

func InitializeDatabase(db *sql.DB) {
	// Master Database: Only stores Auth (admins, password_resets, etc.)
	
	// [เพิ่มใหม่] ตารางสำหรับแอดมินและรีเซ็ตรหัสผ่าน
	db.Exec(`CREATE TABLE IF NOT EXISTS admins (id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT UNIQUE, password TEXT, role TEXT DEFAULT 'services', profile_image TEXT DEFAULT '')`)
	// Migrate existing admins table
	db.Exec(`ALTER TABLE admins ADD COLUMN profile_image TEXT DEFAULT ''`)
	db.Exec(`ALTER TABLE admins ADD COLUMN last_active DATETIME`)
	db.Exec(`ALTER TABLE admins ADD COLUMN role TEXT DEFAULT 'services'`)
	db.Exec(`ALTER TABLE admins ADD COLUMN email TEXT`)
	db.Exec(`ALTER TABLE admins ADD COLUMN must_change_password INTEGER DEFAULT 0`)
	db.Exec(`ALTER TABLE admins ADD COLUMN line_user_id TEXT DEFAULT ''`)

	db.Exec(`CREATE TABLE IF NOT EXISTS password_resets (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		email TEXT,
		token TEXT,
		expires_at DATETIME
	)`)

	db.Exec(`CREATE TABLE IF NOT EXISTS sessions (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		admin_id INTEGER,
		token TEXT UNIQUE,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP
	)`)
}

