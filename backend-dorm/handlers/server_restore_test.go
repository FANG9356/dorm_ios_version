package handlers

import (
	"archive/zip"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestRestoreServerBackupSwapsAllDataAndKeepsRollback(t *testing.T) {
	root := t.TempDir()
	masterPath := filepath.Join(root, "master.db")
	tenantDir := filepath.Join(root, "dorm_data")
	uploadsDir := filepath.Join(root, "uploads")
	backupDir := filepath.Join(root, "backups")
	rollbackDir := filepath.Join(root, "rollbacks")
	createRestoreTestDatabase(t, masterPath, "old-master")
	if err := os.MkdirAll(tenantDir, 0700); err != nil {
		t.Fatal(err)
	}
	createRestoreTestDatabase(t, filepath.Join(tenantDir, "tenant_1.db"), "old-tenant")
	if err := os.MkdirAll(uploadsDir, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(uploadsDir, "old.jpg"), []byte("old-media"), 0600); err != nil {
		t.Fatal(err)
	}

	sourceRoot := t.TempDir()
	sourceMasterPath := filepath.Join(sourceRoot, "master.db")
	sourceTenantDir := filepath.Join(sourceRoot, "dorm_data")
	sourceUploadsDir := filepath.Join(sourceRoot, "uploads")
	createRestoreTestDatabase(t, sourceMasterPath, "new-master")
	if err := os.MkdirAll(sourceTenantDir, 0700); err != nil {
		t.Fatal(err)
	}
	createRestoreTestDatabase(t, filepath.Join(sourceTenantDir, "tenant_1.db"), "new-tenant")
	if err := os.MkdirAll(sourceUploadsDir, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(sourceUploadsDir, "new.jpg"), []byte("new-media"), 0600); err != nil {
		t.Fatal(err)
	}
	sourceMaster, err := sql.Open("sqlite3", sourceMasterPath)
	if err != nil {
		t.Fatal(err)
	}
	archivePath, err := PerformServerBackup(sourceMaster, sourceMasterPath, sourceTenantDir, sourceUploadsDir, backupDir)
	sourceMaster.Close()
	if err != nil {
		t.Fatal(err)
	}

	result, err := RestoreServerBackup(ServerRestoreOptions{
		ArchivePath:  archivePath,
		MasterPath:   masterPath,
		TenantDir:    tenantDir,
		UploadsDir:   uploadsDir,
		RollbackBase: rollbackDir,
	})
	if err != nil {
		t.Fatal(err)
	}
	if result.DatabaseCount != 2 || result.MediaCount != 1 {
		t.Fatalf("unexpected result: %+v", result)
	}
	assertRestoreTestValue(t, masterPath, "new-master")
	assertRestoreTestValue(t, filepath.Join(tenantDir, "tenant_1.db"), "new-tenant")
	assertRestoreTestValue(t, filepath.Join(result.RollbackPath, "master.db"), "old-master")
	assertRestoreTestValue(t, filepath.Join(result.RollbackPath, "tenants", "tenant_1.db"), "old-tenant")
	if data, err := os.ReadFile(filepath.Join(uploadsDir, "new.jpg")); err != nil || string(data) != "new-media" {
		t.Fatalf("restored media = %q, %v", data, err)
	}
	if data, err := os.ReadFile(filepath.Join(result.RollbackPath, "uploads", "old.jpg")); err != nil || string(data) != "old-media" {
		t.Fatalf("rollback media = %q, %v", data, err)
	}

	rollbackResult, err := RollbackServerRestore(ServerRollbackOptions{
		RollbackPath: result.RollbackPath,
		MasterPath:   masterPath,
		TenantDir:    tenantDir,
		UploadsDir:   uploadsDir,
		FailedBase:   rollbackDir,
	})
	if err != nil {
		t.Fatal(err)
	}
	assertRestoreTestValue(t, masterPath, "old-master")
	assertRestoreTestValue(t, filepath.Join(tenantDir, "tenant_1.db"), "old-tenant")
	assertRestoreTestValue(t, filepath.Join(rollbackResult.FailedRestorePath, "master.db"), "new-master")
	if data, err := os.ReadFile(filepath.Join(uploadsDir, "old.jpg")); err != nil || string(data) != "old-media" {
		t.Fatalf("rolled-back media = %q, %v", data, err)
	}
}

func TestRestoreServerBackupRejectsTamperedArchiveBeforeSwap(t *testing.T) {
	root := t.TempDir()
	masterPath := filepath.Join(root, "master.db")
	tenantDir := filepath.Join(root, "dorm_data")
	uploadsDir := filepath.Join(root, "uploads")
	createRestoreTestDatabase(t, masterPath, "old-master")
	if err := os.MkdirAll(tenantDir, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(uploadsDir, 0700); err != nil {
		t.Fatal(err)
	}

	archivePath := filepath.Join(root, "tampered.zip")
	createTamperedRestoreArchive(t, archivePath)
	_, err := RestoreServerBackup(ServerRestoreOptions{
		ArchivePath:  archivePath,
		MasterPath:   masterPath,
		TenantDir:    tenantDir,
		UploadsDir:   uploadsDir,
		RollbackBase: filepath.Join(root, "rollbacks"),
	})
	if err == nil || !strings.Contains(err.Error(), "checksum mismatch") {
		t.Fatalf("error = %v", err)
	}
	assertRestoreTestValue(t, masterPath, "old-master")
}

func TestRestoreServerBackupRejectsActiveWAL(t *testing.T) {
	root := t.TempDir()
	masterPath := filepath.Join(root, "master.db")
	createRestoreTestDatabase(t, masterPath, "old-master")
	if err := os.WriteFile(masterPath+"-wal", []byte("active"), 0600); err != nil {
		t.Fatal(err)
	}
	sourceRoot := t.TempDir()
	sourceMasterPath := filepath.Join(sourceRoot, "master.db")
	createRestoreTestDatabase(t, sourceMasterPath, "backup-master")
	sourceMaster, err := sql.Open("sqlite3", sourceMasterPath)
	if err != nil {
		t.Fatal(err)
	}
	archivePath, err := PerformServerBackup(sourceMaster, sourceMasterPath, filepath.Join(sourceRoot, "missing-tenants"), filepath.Join(sourceRoot, "missing-uploads"), filepath.Join(root, "backups"))
	sourceMaster.Close()
	if err != nil {
		t.Fatal(err)
	}
	_, err = RestoreServerBackup(ServerRestoreOptions{
		ArchivePath:  archivePath,
		MasterPath:   masterPath,
		TenantDir:    filepath.Join(root, "dorm_data"),
		UploadsDir:   filepath.Join(root, "uploads"),
		RollbackBase: filepath.Join(root, "rollbacks"),
	})
	if err == nil || !strings.Contains(err.Error(), "stop the server") {
		t.Fatalf("error = %v", err)
	}
}

func TestRestoreServerBackupVerifyOnlyDoesNotTouchLiveData(t *testing.T) {
	root := t.TempDir()
	masterPath := filepath.Join(root, "master.db")
	tenantDir := filepath.Join(root, "dorm_data")
	uploadsDir := filepath.Join(root, "uploads")
	backupDir := filepath.Join(root, "backups")
	createRestoreTestDatabase(t, masterPath, "live-master")
	if err := os.MkdirAll(tenantDir, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(uploadsDir, 0700); err != nil {
		t.Fatal(err)
	}

	sourceRoot := t.TempDir()
	sourceMasterPath := filepath.Join(sourceRoot, "master.db")
	createRestoreTestDatabase(t, sourceMasterPath, "backup-master")
	sourceMaster, err := sql.Open("sqlite3", sourceMasterPath)
	if err != nil {
		t.Fatal(err)
	}
	archivePath, err := PerformServerBackup(sourceMaster, sourceMasterPath, filepath.Join(sourceRoot, "missing-tenants"), filepath.Join(sourceRoot, "missing-uploads"), backupDir)
	sourceMaster.Close()
	if err != nil {
		t.Fatal(err)
	}

	result, err := RestoreServerBackup(ServerRestoreOptions{
		ArchivePath:  archivePath,
		MasterPath:   masterPath,
		TenantDir:    tenantDir,
		UploadsDir:   uploadsDir,
		RollbackBase: filepath.Join(root, "rollbacks"),
		VerifyOnly:   true,
	})
	if err != nil {
		t.Fatal(err)
	}
	if !result.Verified || result.RollbackPath != "" || result.DatabaseCount != 1 {
		t.Fatalf("unexpected result: %+v", result)
	}
	assertRestoreTestValue(t, masterPath, "live-master")
}

func createRestoreTestDatabase(t *testing.T, path, value string) {
	t.Helper()
	db, err := sql.Open("sqlite3", path)
	if err != nil {
		t.Fatal(err)
	}
	if _, err = db.Exec("CREATE TABLE state (value TEXT); INSERT INTO state VALUES (?)", value); err != nil {
		db.Close()
		t.Fatal(err)
	}
	if err = db.Close(); err != nil {
		t.Fatal(err)
	}
}

func assertRestoreTestValue(t *testing.T, path, expected string) {
	t.Helper()
	db, err := sql.Open("sqlite3", path+"?mode=ro")
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	var value string
	if err = db.QueryRow("SELECT value FROM state").Scan(&value); err != nil {
		t.Fatal(err)
	}
	if value != expected {
		t.Fatalf("value in %s = %q, want %q", path, value, expected)
	}
}

func createTamperedRestoreArchive(t *testing.T, path string) {
	t.Helper()
	file, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	writer := zip.NewWriter(file)
	content := []byte("not-a-database")
	entry, err := writer.Create("databases/master.db")
	if err != nil {
		t.Fatal(err)
	}
	if _, err = entry.Write(content); err != nil {
		t.Fatal(err)
	}
	hash := sha256.Sum256([]byte("different-content"))
	manifest := serverBackupManifest{FormatVersion: 1, Files: []serverBackupFile{{Path: "databases/master.db", SHA256: hex.EncodeToString(hash[:]), Size: int64(len(content))}}}
	manifestData, err := json.Marshal(manifest)
	if err != nil {
		t.Fatal(err)
	}
	manifestEntry, err := writer.Create("manifest.json")
	if err != nil {
		t.Fatal(err)
	}
	if _, err = manifestEntry.Write(manifestData); err != nil {
		t.Fatal(err)
	}
	if err = writer.Close(); err != nil {
		t.Fatal(err)
	}
	if err = file.Close(); err != nil {
		t.Fatal(err)
	}
}
