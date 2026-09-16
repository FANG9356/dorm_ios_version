package handlers

import (
	"archive/zip"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

const (
	maxRestoreFileSize = int64(2 << 30)
	maxRestoreTotal    = int64(20 << 30)
)

var tenantBackupName = regexp.MustCompile(`^tenant_[0-9]+\.db$`)

type ServerRestoreOptions struct {
	ArchivePath  string
	MasterPath   string
	TenantDir    string
	UploadsDir   string
	RollbackBase string
	VerifyOnly   bool
}

type ServerRestoreResult struct {
	Verified      bool   `json:"verified"`
	RollbackPath  string `json:"rollback_path,omitempty"`
	DatabaseCount int    `json:"database_count"`
	MediaCount    int    `json:"media_count"`
}

type ServerRollbackOptions struct {
	RollbackPath string
	MasterPath   string
	TenantDir    string
	UploadsDir   string
	FailedBase   string
}

type ServerRollbackResult struct {
	FailedRestorePath string `json:"failed_restore_path"`
}

type restoreTarget struct {
	live     string
	staged   string
	rollback string
	existed  bool
	movedOld bool
	movedNew bool
}

// RestoreServerBackup restores a multi-tenant archive created by
// PerformServerBackup. The caller must stop the server first and explicitly
// enter maintenance mode. Every archive entry is verified before any live
// path is touched. Live data is retained in RollbackPath after success.
func RestoreServerBackup(options ServerRestoreOptions) (ServerRestoreResult, error) {
	var result ServerRestoreResult
	if strings.TrimSpace(options.ArchivePath) == "" {
		return result, fmt.Errorf("backup archive is required")
	}
	paths, err := normalizeRestorePaths(options)
	if err != nil {
		return result, err
	}
	parent := filepath.Dir(paths.MasterPath)
	stagingRoot, err := os.MkdirTemp(parent, ".dorminet-restore-staging-*")
	if err != nil {
		return result, fmt.Errorf("create restore staging directory: %w", err)
	}
	defer os.RemoveAll(stagingRoot)
	if err = os.Chmod(stagingRoot, 0700); err != nil {
		return result, fmt.Errorf("protect restore staging directory: %w", err)
	}

	stagedMaster := filepath.Join(stagingRoot, "master.db")
	stagedTenants := filepath.Join(stagingRoot, "tenants")
	stagedUploads := filepath.Join(stagingRoot, "uploads")
	if err = os.MkdirAll(stagedTenants, 0700); err != nil {
		return result, fmt.Errorf("create staged tenant directory: %w", err)
	}
	if err = os.MkdirAll(stagedUploads, 0700); err != nil {
		return result, fmt.Errorf("create staged media directory: %w", err)
	}

	result.DatabaseCount, result.MediaCount, err = extractVerifiedServerBackup(
		paths.ArchivePath,
		stagedMaster,
		stagedTenants,
		stagedUploads,
	)
	if err != nil {
		return ServerRestoreResult{}, err
	}
	if err = validateRestoredDatabases(stagedMaster, stagedTenants); err != nil {
		return ServerRestoreResult{}, err
	}
	result.Verified = true
	if paths.VerifyOnly {
		return result, nil
	}
	if err = rejectActiveSQLiteSidecars(paths.MasterPath, paths.TenantDir); err != nil {
		return ServerRestoreResult{}, err
	}

	rollbackRoot, err := createRollbackDirectory(paths.RollbackBase)
	if err != nil {
		return ServerRestoreResult{}, err
	}
	result.RollbackPath = rollbackRoot
	targets := []*restoreTarget{
		{live: paths.MasterPath, staged: stagedMaster, rollback: filepath.Join(rollbackRoot, "master.db")},
		{live: paths.TenantDir, staged: stagedTenants, rollback: filepath.Join(rollbackRoot, "tenants")},
		{live: paths.UploadsDir, staged: stagedUploads, rollback: filepath.Join(rollbackRoot, "uploads")},
	}

	if err = swapRestoreTargets(targets); err != nil {
		rollbackErr := rollbackRestoreTargets(targets)
		if rollbackErr != nil {
			return ServerRestoreResult{}, fmt.Errorf("restore swap failed: %v; rollback also failed: %w", err, rollbackErr)
		}
		return ServerRestoreResult{}, fmt.Errorf("restore swap failed and was rolled back: %w", err)
	}
	if err = validateRestoredDatabases(paths.MasterPath, paths.TenantDir); err != nil {
		rollbackErr := rollbackRestoreTargets(targets)
		if rollbackErr != nil {
			return ServerRestoreResult{}, fmt.Errorf("post-restore validation failed: %v; rollback also failed: %w", err, rollbackErr)
		}
		return ServerRestoreResult{}, fmt.Errorf("post-restore validation failed and was rolled back: %w", err)
	}
	if err = syncDirectory(parent); err != nil {
		return ServerRestoreResult{}, fmt.Errorf("sync restored paths: %w", err)
	}
	return result, nil
}

// RollbackServerRestore reactivates the pre-restore data retained by
// RestoreServerBackup. The replaced restore is preserved as another recovery
// set instead of being deleted.
func RollbackServerRestore(options ServerRollbackOptions) (ServerRollbackResult, error) {
	var result ServerRollbackResult
	if strings.TrimSpace(options.RollbackPath) == "" {
		return result, fmt.Errorf("rollback path is required")
	}
	rollbackPath, err := filepath.Abs(filepath.Clean(options.RollbackPath))
	if err != nil {
		return result, fmt.Errorf("resolve rollback path: %w", err)
	}
	paths, err := normalizeRestorePaths(ServerRestoreOptions{
		ArchivePath:  filepath.Join(rollbackPath, "rollback-source"),
		MasterPath:   options.MasterPath,
		TenantDir:    options.TenantDir,
		UploadsDir:   options.UploadsDir,
		RollbackBase: options.FailedBase,
	})
	if err != nil {
		return result, err
	}
	rollbackMaster := filepath.Join(rollbackPath, "master.db")
	rollbackTenants := filepath.Join(rollbackPath, "tenants")
	rollbackUploads := filepath.Join(rollbackPath, "uploads")
	if err = validateRestoredDatabases(rollbackMaster, rollbackTenants); err != nil {
		return result, fmt.Errorf("validate rollback set: %w", err)
	}
	if info, statErr := os.Stat(rollbackUploads); statErr != nil || !info.IsDir() {
		return result, fmt.Errorf("rollback media directory is missing")
	}
	if err = rejectActiveSQLiteSidecars(paths.MasterPath, paths.TenantDir); err != nil {
		return result, err
	}
	failedRoot, err := createNamedRecoveryDirectory(paths.RollbackBase, "failed_restore_")
	if err != nil {
		return result, err
	}
	result.FailedRestorePath = failedRoot
	targets := []*restoreTarget{
		{live: paths.MasterPath, staged: rollbackMaster, rollback: filepath.Join(failedRoot, "master.db")},
		{live: paths.TenantDir, staged: rollbackTenants, rollback: filepath.Join(failedRoot, "tenants")},
		{live: paths.UploadsDir, staged: rollbackUploads, rollback: filepath.Join(failedRoot, "uploads")},
	}
	if err = swapRestoreTargets(targets); err != nil {
		recoveryErr := rollbackRestoreTargets(targets)
		if recoveryErr != nil {
			return ServerRollbackResult{}, fmt.Errorf("rollback activation failed: %v; recovery also failed: %w", err, recoveryErr)
		}
		return ServerRollbackResult{}, fmt.Errorf("rollback activation failed and current data was recovered: %w", err)
	}
	if err = validateRestoredDatabases(paths.MasterPath, paths.TenantDir); err != nil {
		recoveryErr := rollbackRestoreTargets(targets)
		if recoveryErr != nil {
			return ServerRollbackResult{}, fmt.Errorf("rollback validation failed: %v; recovery also failed: %w", err, recoveryErr)
		}
		return ServerRollbackResult{}, fmt.Errorf("rollback validation failed and current data was recovered: %w", err)
	}
	if err = syncDirectory(filepath.Dir(paths.MasterPath)); err != nil {
		return ServerRollbackResult{}, fmt.Errorf("sync rolled-back paths: %w", err)
	}
	return result, nil
}

func normalizeRestorePaths(options ServerRestoreOptions) (ServerRestoreOptions, error) {
	var err error
	for name, value := range map[string]*string{
		"archive":  &options.ArchivePath,
		"master":   &options.MasterPath,
		"tenants":  &options.TenantDir,
		"uploads":  &options.UploadsDir,
		"rollback": &options.RollbackBase,
	} {
		if strings.TrimSpace(*value) == "" {
			return options, fmt.Errorf("%s path is required", name)
		}
		*value, err = filepath.Abs(filepath.Clean(*value))
		if err != nil {
			return options, fmt.Errorf("resolve %s path: %w", name, err)
		}
	}
	parent := filepath.Dir(options.MasterPath)
	if filepath.Dir(options.TenantDir) != parent || filepath.Dir(options.UploadsDir) != parent {
		return options, fmt.Errorf("master, tenant, and uploads paths must share one parent for atomic rename")
	}
	for _, live := range []string{options.MasterPath, options.TenantDir, options.UploadsDir} {
		if live == options.RollbackBase || strings.HasPrefix(options.RollbackBase+string(os.PathSeparator), live+string(os.PathSeparator)) {
			return options, fmt.Errorf("rollback directory must be outside live data paths")
		}
	}
	return options, nil
}

func rejectActiveSQLiteSidecars(masterPath, tenantDir string) error {
	databasePaths := []string{masterPath}
	entries, err := os.ReadDir(tenantDir)
	if err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("inspect tenant directory: %w", err)
	}
	for _, entry := range entries {
		if !entry.IsDir() && tenantBackupName.MatchString(entry.Name()) {
			databasePaths = append(databasePaths, filepath.Join(tenantDir, entry.Name()))
		}
	}
	for _, databasePath := range databasePaths {
		for _, suffix := range []string{"-wal", "-shm"} {
			info, statErr := os.Stat(databasePath + suffix)
			if statErr == nil && info.Size() > 0 {
				return fmt.Errorf("active SQLite sidecar %s found; stop the server and checkpoint the database first", filepath.Base(databasePath+suffix))
			}
			if statErr != nil && !os.IsNotExist(statErr) {
				return fmt.Errorf("inspect SQLite sidecar: %w", statErr)
			}
		}
	}
	return nil
}

func extractVerifiedServerBackup(archivePath, masterPath, tenantDir, uploadsDir string) (int, int, error) {
	reader, err := zip.OpenReader(archivePath)
	if err != nil {
		return 0, 0, fmt.Errorf("open backup archive: %w", err)
	}
	defer reader.Close()

	entries := make(map[string]*zip.File, len(reader.File))
	var manifestData []byte
	for _, entry := range reader.File {
		name := filepath.ToSlash(filepath.Clean(entry.Name))
		if name != entry.Name || strings.HasPrefix(name, "../") || strings.HasPrefix(name, "/") || name == "." {
			return 0, 0, fmt.Errorf("unsafe archive entry %q", entry.Name)
		}
		if _, duplicate := entries[name]; duplicate {
			return 0, 0, fmt.Errorf("duplicate archive entry %q", name)
		}
		entries[name] = entry
		if name == "manifest.json" {
			manifestData, err = readZipEntry(entry, 1<<20)
			if err != nil {
				return 0, 0, fmt.Errorf("read backup manifest: %w", err)
			}
		}
	}
	if len(manifestData) == 0 {
		return 0, 0, fmt.Errorf("backup manifest is missing")
	}
	var manifest serverBackupManifest
	if err = json.Unmarshal(manifestData, &manifest); err != nil {
		return 0, 0, fmt.Errorf("decode backup manifest: %w", err)
	}
	if manifest.FormatVersion != 1 {
		return 0, 0, fmt.Errorf("unsupported backup format version %d", manifest.FormatVersion)
	}

	listed := make(map[string]struct{}, len(manifest.Files))
	var totalSize int64
	databaseCount, mediaCount := 0, 0
	foundMaster := false
	for _, item := range manifest.Files {
		name := filepath.ToSlash(filepath.Clean(item.Path))
		if name != item.Path || item.Size < 0 || item.Size > maxRestoreFileSize {
			return 0, 0, fmt.Errorf("invalid manifest entry %q", item.Path)
		}
		if _, duplicate := listed[name]; duplicate {
			return 0, 0, fmt.Errorf("duplicate manifest entry %q", name)
		}
		listed[name] = struct{}{}
		totalSize += item.Size
		if totalSize > maxRestoreTotal {
			return 0, 0, fmt.Errorf("backup expands beyond restore limit")
		}
		entry, ok := entries[name]
		if !ok {
			return 0, 0, fmt.Errorf("manifest entry %q is missing from archive", name)
		}
		if !entry.Mode().IsRegular() {
			return 0, 0, fmt.Errorf("archive entry %q is not a regular file", name)
		}

		var destination string
		switch {
		case name == "databases/master.db":
			destination = masterPath
			foundMaster = true
			databaseCount++
		case strings.HasPrefix(name, "databases/") && tenantBackupName.MatchString(strings.TrimPrefix(name, "databases/")):
			destination = filepath.Join(tenantDir, filepath.Base(name))
			databaseCount++
		case strings.HasPrefix(name, "uploads/") && name != "uploads/":
			relative := strings.TrimPrefix(name, "uploads/")
			destination = filepath.Join(uploadsDir, filepath.FromSlash(relative))
			if !pathWithin(uploadsDir, destination) {
				return 0, 0, fmt.Errorf("unsafe media path %q", name)
			}
			mediaCount++
		default:
			return 0, 0, fmt.Errorf("unsupported backup entry %q", name)
		}
		if err = extractAndVerifyEntry(entry, destination, item); err != nil {
			return 0, 0, err
		}
	}
	if !foundMaster {
		return 0, 0, fmt.Errorf("backup does not contain databases/master.db")
	}
	for name := range entries {
		if name == "manifest.json" {
			continue
		}
		if _, ok := listed[name]; !ok {
			return 0, 0, fmt.Errorf("archive contains unlisted entry %q", name)
		}
	}
	return databaseCount, mediaCount, nil
}

func readZipEntry(entry *zip.File, limit int64) ([]byte, error) {
	if int64(entry.UncompressedSize64) > limit {
		return nil, fmt.Errorf("entry exceeds size limit")
	}
	stream, err := entry.Open()
	if err != nil {
		return nil, err
	}
	defer stream.Close()
	data, err := io.ReadAll(io.LimitReader(stream, limit+1))
	if err != nil {
		return nil, err
	}
	if int64(len(data)) > limit {
		return nil, fmt.Errorf("entry exceeds size limit")
	}
	return data, nil
}

func extractAndVerifyEntry(entry *zip.File, destination string, expected serverBackupFile) error {
	if int64(entry.UncompressedSize64) != expected.Size {
		return fmt.Errorf("size mismatch for %s", expected.Path)
	}
	if err := os.MkdirAll(filepath.Dir(destination), 0700); err != nil {
		return fmt.Errorf("create restore directory for %s: %w", expected.Path, err)
	}
	input, err := entry.Open()
	if err != nil {
		return fmt.Errorf("open restore entry %s: %w", expected.Path, err)
	}
	defer input.Close()
	output, err := os.OpenFile(destination, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		return fmt.Errorf("create staged file for %s: %w", expected.Path, err)
	}
	hash := sha256.New()
	written, copyErr := io.Copy(io.MultiWriter(output, hash), io.LimitReader(input, expected.Size+1))
	syncErr := output.Sync()
	closeErr := output.Close()
	if copyErr != nil {
		return fmt.Errorf("extract %s: %w", expected.Path, copyErr)
	}
	if syncErr != nil {
		return fmt.Errorf("sync %s: %w", expected.Path, syncErr)
	}
	if closeErr != nil {
		return fmt.Errorf("close %s: %w", expected.Path, closeErr)
	}
	if written != expected.Size {
		return fmt.Errorf("size mismatch for %s", expected.Path)
	}
	actualHash := hex.EncodeToString(hash.Sum(nil))
	if !strings.EqualFold(actualHash, expected.SHA256) {
		return fmt.Errorf("checksum mismatch for %s", expected.Path)
	}
	return nil
}

func validateRestoredDatabases(masterPath, tenantDir string) error {
	if err := quickCheckSQLite(masterPath); err != nil {
		return fmt.Errorf("validate master database: %w", err)
	}
	entries, err := os.ReadDir(tenantDir)
	if err != nil {
		return fmt.Errorf("list restored tenant databases: %w", err)
	}
	for _, entry := range entries {
		if entry.IsDir() || !tenantBackupName.MatchString(entry.Name()) {
			return fmt.Errorf("unexpected file in tenant restore directory: %s", entry.Name())
		}
		if err = quickCheckSQLite(filepath.Join(tenantDir, entry.Name())); err != nil {
			return fmt.Errorf("validate tenant database %s: %w", entry.Name(), err)
		}
	}
	return nil
}

func quickCheckSQLite(path string) error {
	db, err := sql.Open("sqlite3", "file:"+filepath.ToSlash(path)+"?mode=ro&immutable=1")
	if err != nil {
		return err
	}
	defer db.Close()
	var result string
	if err = db.QueryRow("PRAGMA quick_check").Scan(&result); err != nil {
		return err
	}
	if result != "ok" {
		return fmt.Errorf("SQLite integrity check failed: %s", result)
	}
	return nil
}

func createRollbackDirectory(base string) (string, error) {
	return createNamedRecoveryDirectory(base, "restore_rollback_")
}

func createNamedRecoveryDirectory(base, prefix string) (string, error) {
	if err := os.MkdirAll(base, 0700); err != nil {
		return "", fmt.Errorf("create rollback base: %w", err)
	}
	if err := os.Chmod(base, 0700); err != nil {
		return "", fmt.Errorf("protect rollback base: %w", err)
	}
	path := filepath.Join(base, prefix+time.Now().UTC().Format("20060102T150405.000000000Z"))
	if err := os.Mkdir(path, 0700); err != nil {
		return "", fmt.Errorf("create rollback directory: %w", err)
	}
	return path, nil
}

func swapRestoreTargets(targets []*restoreTarget) error {
	for _, target := range targets {
		_, err := os.Stat(target.live)
		target.existed = err == nil
		if err != nil && !os.IsNotExist(err) {
			return err
		}
		if target.existed {
			if err = os.Rename(target.live, target.rollback); err != nil {
				return fmt.Errorf("move live %s to rollback: %w", filepath.Base(target.live), err)
			}
			target.movedOld = true
		}
		if err = os.Rename(target.staged, target.live); err != nil {
			return fmt.Errorf("activate restored %s: %w", filepath.Base(target.live), err)
		}
		target.movedNew = true
	}
	return nil
}

func rollbackRestoreTargets(targets []*restoreTarget) error {
	var failures []string
	for index := len(targets) - 1; index >= 0; index-- {
		target := targets[index]
		if target.movedNew {
			if err := os.RemoveAll(target.live); err != nil {
				failures = append(failures, err.Error())
				continue
			}
			target.movedNew = false
		}
		if target.movedOld {
			if err := os.Rename(target.rollback, target.live); err != nil {
				failures = append(failures, err.Error())
				continue
			}
			target.movedOld = false
		}
	}
	if len(failures) > 0 {
		return fmt.Errorf("%s", strings.Join(failures, "; "))
	}
	return nil
}

func pathWithin(root, candidate string) bool {
	relative, err := filepath.Rel(root, candidate)
	return err == nil && relative != ".." && !strings.HasPrefix(relative, ".."+string(os.PathSeparator))
}

func syncDirectory(path string) error {
	directory, err := os.Open(path)
	if err != nil {
		return err
	}
	defer directory.Close()
	return directory.Sync()
}
