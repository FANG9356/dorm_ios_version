package handlers

import (
	"database/sql"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestPhase2ValidateLineSnapshotRejectsEmptyIDAndMismatchedAccount(t *testing.T) {
	emptyIDWithData := []byte(`{"snapshotID":"","accountID":5,"rooms":[{"id":"r1","roomNumber":"101","roomType":"Standard"}],"tenants":[],"payments":[],"maintenance":[],"roomTypes":[]}`)
	if err := validateLineSnapshotForPush(5, emptyIDWithData); err == nil || !strings.Contains(err.Error(), "snapshotID") {
		t.Fatalf("expected empty snapshotID error, got %v", err)
	}

	wrongAccount := []byte(`{"snapshotID":"snap-1","accountID":9,"rooms":[],"tenants":[],"payments":[],"maintenance":[],"roomTypes":[]}`)
	if err := validateLineSnapshotForPush(5, wrongAccount); err == nil || !strings.Contains(err.Error(), "account mismatch") {
		t.Fatalf("expected account mismatch error, got %v", err)
	}
}

func TestPhase2FlexBuildersEscapeQuotesAndSpecialChars(t *testing.T) {
	roomWithInjection := `101", "injected": true, "x": "`
	issueWithInjection := "แอร์เสีย \"รุ่นใหม่\"\nชั้น 2"

	receipt := buildSimpleReceiptFlexBubble("ใบเสร็จ", "RECEIPT", "REC-00001", roomWithInjection, "24/11/2026", "3500.00 บาท", "ok \"done\"", "#10B981")
	encoded, err := json.Marshal(receipt)
	if err != nil {
		t.Fatalf("marshal receipt flex: %v", err)
	}
	var decoded map[string]interface{}
	if err := json.Unmarshal(encoded, &decoded); err != nil {
		t.Fatalf("receipt flex produced invalid JSON: %v", err)
	}
	if strings.Contains(string(encoded), `"injected":true`) {
		t.Fatalf("JSON injection succeeded in receipt flex: %s", string(encoded))
	}

	noBalance := buildNoOutstandingBalanceFlexMessage(roomWithInjection)
	encodedNoBal, err := json.Marshal(noBalance)
	if err != nil {
		t.Fatalf("marshal no-balance flex: %v", err)
	}
	if strings.Contains(string(encodedNoBal), `"injected":true`) {
		t.Fatalf("JSON injection succeeded in no-balance flex: %s", string(encodedNoBal))
	}
	_ = issueWithInjection
}

func TestPhase2RejectsZeroByteWALAndJournalSidecars(t *testing.T) {
	root := t.TempDir()
	masterPath := filepath.Join(root, "master.db")
	createRestoreTestDatabase(t, masterPath, "live")
	tenantDir := filepath.Join(root, "dorm_data")
	if err := os.MkdirAll(tenantDir, 0700); err != nil {
		t.Fatal(err)
	}

	// Zero-byte -wal must be rejected
	if err := os.WriteFile(masterPath+"-wal", []byte{}, 0600); err != nil {
		t.Fatal(err)
	}
	if err := rejectActiveSQLiteSidecars(masterPath, tenantDir); err == nil {
		t.Fatalf("expected zero-byte -wal to be rejected")
	}
	_ = os.Remove(masterPath + "-wal")

	// -journal must be rejected
	if err := os.WriteFile(masterPath+"-journal", []byte("j"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := rejectActiveSQLiteSidecars(masterPath, tenantDir); err == nil {
		t.Fatalf("expected -journal to be rejected")
	}
}

func TestPhase2RollbackRestoreTargetsPreservesStagedDirectory(t *testing.T) {
	root := t.TempDir()
	live := filepath.Join(root, "live.db")
	staged := filepath.Join(root, "rollback_source.db")
	backup := filepath.Join(root, "failed_live.db")

	if err := os.WriteFile(live, []byte("current-live"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(staged, []byte("precious-rollback"), 0600); err != nil {
		t.Fatal(err)
	}

	targets := []*restoreTarget{{live: live, staged: staged, rollback: backup}}
	if err := swapRestoreTargets(targets); err != nil {
		t.Fatal(err)
	}
	if err := rollbackRestoreTargets(targets); err != nil {
		t.Fatal(err)
	}

	liveData, err := os.ReadFile(live)
	if err != nil || string(liveData) != "current-live" {
		t.Fatalf("live not recovered: %q, %v", liveData, err)
	}
	stagedData, err := os.ReadFile(staged)
	if err != nil || string(stagedData) != "precious-rollback" {
		t.Fatalf("rollback source was destroyed instead of preserved: %q, %v", stagedData, err)
	}
}

func TestPhase2OutboxReclaimsStaleProcessingLease(t *testing.T) {
	dbPath := filepath.Join(t.TempDir(), "master.db")
	db, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	_, err = db.Exec(`
		CREATE TABLE admins (id INTEGER PRIMARY KEY, promptpay_id TEXT);
		CREATE TABLE line_notification_outbox (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			event_key TEXT UNIQUE,
			account_id INTEGER,
			maintenance_record_id TEXT,
			line_user_id TEXT,
			room_number TEXT,
			issue TEXT,
			maintenance_status TEXT,
			cost REAL,
			reported_at TEXT,
			resolved_at TEXT,
			payment_method TEXT,
			maintenance_updated_at TEXT,
			status TEXT,
			attempts INTEGER DEFAULT 0,
			next_attempt_at TEXT,
			last_error TEXT,
			created_at TEXT,
			sent_at TEXT
		);
	`)
	if err != nil {
		t.Fatal(err)
	}
	staleTime := time.Now().UTC().Add(-5 * time.Minute).Format(time.RFC3339Nano)
	_, err = db.Exec(`INSERT INTO line_notification_outbox
		(event_key, account_id, maintenance_record_id, line_user_id, room_number, issue, maintenance_status, cost, reported_at, resolved_at, payment_method, maintenance_updated_at, status, attempts, next_attempt_at, created_at)
		VALUES ('evt-stale', 1, 'm-1', 'U123', '101', 'leak', 'กำลังซ่อม', 0, '', '', '', '', 'processing', 1, ?, ?)`,
		staleTime, staleTime)
	if err != nil {
		t.Fatal(err)
	}

	delivered := false
	processPendingLineNotifications(db, func(n maintenanceStatusNotification) error {
		if n.EventKey == "evt-stale" {
			delivered = true
		}
		return nil
	})
	if !delivered {
		t.Fatalf("expected stale processing lease to be reclaimed and delivered")
	}

	var status string
	if err := db.QueryRow(`SELECT status FROM line_notification_outbox WHERE event_key = 'evt-stale'`).Scan(&status); err != nil {
		t.Fatal(err)
	}
	if status != "sent" {
		t.Fatalf("expected reclaimed outbox row to become sent, got %q", status)
	}
}
