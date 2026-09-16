package main

import (
	"dorm_os/core"
	"dorm_os/handlers"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strings"
)

func main() {
	if len(os.Args) > 1 && os.Args[1] == "restore-server-backup" {
		if err := runServerRestore(os.Args[2:]); err != nil {
			fmt.Fprintln(os.Stderr, "restore failed:", err)
			os.Exit(1)
		}
		return
	}
	if len(os.Args) > 1 && os.Args[1] == "rollback-server-restore" {
		if err := runServerRollback(os.Args[2:]); err != nil {
			fmt.Fprintln(os.Stderr, "rollback failed:", err)
			os.Exit(1)
		}
		return
	}
	core.RunServer()
}

func runServerRestore(arguments []string) error {
	flags := flag.NewFlagSet("restore-server-backup", flag.ContinueOnError)
	archive := flags.String("archive", "", "server backup ZIP to restore")
	master := flags.String("master", envOrDefault("DB_PATH", "./dormitory.db"), "master SQLite path")
	tenants := flags.String("tenants", "./dorm_data", "tenant database directory")
	uploads := flags.String("uploads", "./uploads", "compatibility media directory")
	rollbacks := flags.String("rollbacks", "./restore_rollbacks", "directory that retains pre-restore data")
	verifyOnly := flags.Bool("verify-only", false, "verify and stage the archive without changing live data")
	if err := flags.Parse(arguments); err != nil {
		return err
	}
	if flags.NArg() != 0 {
		return fmt.Errorf("unexpected positional arguments")
	}
	if !*verifyOnly && !strings.EqualFold(strings.TrimSpace(os.Getenv("DORMINET_MAINTENANCE_MODE")), "true") {
		return fmt.Errorf("set DORMINET_MAINTENANCE_MODE=true after stopping the server")
	}
	result, err := handlers.RestoreServerBackup(handlers.ServerRestoreOptions{
		ArchivePath:  *archive,
		MasterPath:   *master,
		TenantDir:    *tenants,
		UploadsDir:   *uploads,
		RollbackBase: *rollbacks,
		VerifyOnly:   *verifyOnly,
	})
	if err != nil {
		return err
	}
	encoded, err := json.Marshal(result)
	if err != nil {
		return err
	}
	fmt.Println(string(encoded))
	return nil
}

func envOrDefault(name, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(name)); value != "" {
		return value
	}
	return fallback
}

func runServerRollback(arguments []string) error {
	if !strings.EqualFold(strings.TrimSpace(os.Getenv("DORMINET_MAINTENANCE_MODE")), "true") {
		return fmt.Errorf("set DORMINET_MAINTENANCE_MODE=true after stopping the server")
	}
	flags := flag.NewFlagSet("rollback-server-restore", flag.ContinueOnError)
	rollbackPath := flags.String("rollback", "", "rollback directory returned by restore-server-backup")
	master := flags.String("master", envOrDefault("DB_PATH", "./dormitory.db"), "master SQLite path")
	tenants := flags.String("tenants", "./dorm_data", "tenant database directory")
	uploads := flags.String("uploads", "./uploads", "compatibility media directory")
	failedBase := flags.String("failed-restores", "./restore_rollbacks", "directory that retains the failed restore")
	if err := flags.Parse(arguments); err != nil {
		return err
	}
	if flags.NArg() != 0 {
		return fmt.Errorf("unexpected positional arguments")
	}
	result, err := handlers.RollbackServerRestore(handlers.ServerRollbackOptions{
		RollbackPath: *rollbackPath,
		MasterPath:   *master,
		TenantDir:    *tenants,
		UploadsDir:   *uploads,
		FailedBase:   *failedBase,
	})
	if err != nil {
		return err
	}
	encoded, err := json.Marshal(result)
	if err != nil {
		return err
	}
	fmt.Println(string(encoded))
	return nil
}
