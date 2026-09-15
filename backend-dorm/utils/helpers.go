package utils

import (
	"database/sql"
	"encoding/json"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

var allowedUploadExts = map[string]bool{
	".jpg": true, ".jpeg": true, ".png": true, ".pdf": true,
	".webp": true, ".mp4": true, ".mov": true,
}

func IsAllowedUploadExt(filename string) bool {
	ext := strings.ToLower(filepath.Ext(filename))
	return allowedUploadExts[ext]
}

func IsSafeBackupName(name string) bool {
	if name == "" || filepath.Base(name) != name {
		return false
	}
	if strings.ToLower(filepath.Ext(name)) != ".zip" {
		return false
	}
	return strings.HasPrefix(name, "backup_") || strings.HasPrefix(name, "server_backup_")
}

func IsSafeZipEntry(name string) (string, bool) {
	clean := filepath.ToSlash(filepath.Clean(name))
	if clean == ".." || strings.HasPrefix(clean, "../") || strings.Contains(clean, "/../") {
		return "", false
	}
	if clean == "data.json" {
		return clean, true
	}
	if strings.HasPrefix(clean, "uploads/") {
		return clean, true
	}
	return "", false
}

func EnableCORS(w http.ResponseWriter) {
	origin := "*"
	w.Header().Set("Access-Control-Allow-Origin", origin)
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
	w.Header().Set("Cache-Control", "no-store, no-cache, must-revalidate, post-check=0, pre-check=0")
	w.Header().Set("Pragma", "no-cache")
	w.Header().Set("Expires", "0")
}

func WriteJSON(w http.ResponseWriter, status int, v interface{}) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func RollbackOnErr(tx *sql.Tx, err *error) {
	if *err != nil {
		tx.Rollback()
	}
}

func SaveUploadedFile(file multipart.File, destPath string) error {
	dst, err := os.Create(destPath)
	if err != nil {
		return err
	}
	defer dst.Close()

	if _, err := io.Copy(dst, file); err != nil {
		// Attempt to remove the partially written file on error
		os.Remove(destPath)
		return err
	}
	return nil
}
