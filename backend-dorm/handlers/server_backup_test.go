package handlers

import (
	"archive/zip"
	"database/sql"
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"testing"
)

func TestPerformServerBackupIncludesConsistentMasterTenantAndUploads(t *testing.T) {
	root := t.TempDir()
	masterPath := filepath.Join(root, "master.db")
	master, err := sql.Open("sqlite3", masterPath)
	if err != nil {
		t.Fatal(err)
	}
	defer master.Close()
	if _, err = master.Exec("CREATE TABLE snapshots (id INTEGER PRIMARY KEY, value TEXT); INSERT INTO snapshots VALUES (1, 'master')"); err != nil {
		t.Fatal(err)
	}

	tenantDir := filepath.Join(root, "dorm_data")
	if err = os.MkdirAll(tenantDir, 0700); err != nil {
		t.Fatal(err)
	}
	tenant, err := sql.Open("sqlite3", filepath.Join(tenantDir, "tenant_1.db"))
	if err != nil {
		t.Fatal(err)
	}
	if _, err = tenant.Exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT); INSERT INTO users VALUES (1, 'tenant')"); err != nil {
		t.Fatal(err)
	}
	if err = tenant.Close(); err != nil {
		t.Fatal(err)
	}

	uploadsDir := filepath.Join(root, "uploads")
	if err = os.MkdirAll(filepath.Join(uploadsDir, "slips"), 0700); err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(uploadsDir, "slips", "evidence.jpg"), []byte("test-image"), 0600); err != nil {
		t.Fatal(err)
	}

	backupDir := filepath.Join(root, "backups")
	if err = os.MkdirAll(backupDir, 0755); err != nil {
		t.Fatal(err)
	}
	archivePath, err := PerformServerBackup(master, masterPath, tenantDir, uploadsDir, backupDir)
	if err != nil {
		t.Fatal(err)
	}
	info, err := os.Stat(archivePath)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0600 {
		t.Fatalf("backup mode = %o, want 600", info.Mode().Perm())
	}
	directoryInfo, err := os.Stat(backupDir)
	if err != nil {
		t.Fatal(err)
	}
	if directoryInfo.Mode().Perm() != 0700 {
		t.Fatalf("backup directory mode = %o, want 700", directoryInfo.Mode().Perm())
	}

	reader, err := zip.OpenReader(archivePath)
	if err != nil {
		t.Fatal(err)
	}
	defer reader.Close()
	entries := make(map[string][]byte)
	for _, file := range reader.File {
		stream, openErr := file.Open()
		if openErr != nil {
			t.Fatal(openErr)
		}
		content, readErr := io.ReadAll(stream)
		stream.Close()
		if readErr != nil {
			t.Fatal(readErr)
		}
		entries[file.Name] = content
	}
	for _, expected := range []string{"databases/master.db", "databases/tenant_1.db", "uploads/slips/evidence.jpg", "manifest.json"} {
		if _, ok := entries[expected]; !ok {
			t.Errorf("backup missing %s", expected)
		}
	}
	var manifest serverBackupManifest
	if err = json.Unmarshal(entries["manifest.json"], &manifest); err != nil {
		t.Fatal(err)
	}
	if manifest.FormatVersion != 1 || len(manifest.Files) != 3 {
		t.Fatalf("unexpected manifest: %+v", manifest)
	}

	restoredMaster := filepath.Join(root, "restored-master.db")
	if err = os.WriteFile(restoredMaster, entries["databases/master.db"], 0600); err != nil {
		t.Fatal(err)
	}
	check, err := sql.Open("sqlite3", restoredMaster+"?mode=ro")
	if err != nil {
		t.Fatal(err)
	}
	defer check.Close()
	var value string
	if err = check.QueryRow("SELECT value FROM snapshots WHERE id = 1").Scan(&value); err != nil {
		t.Fatal(err)
	}
	if value != "master" {
		t.Fatalf("restored master value = %q", value)
	}
}
