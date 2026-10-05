package handlers

import (
	"bytes"
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"sync"
	"testing"

	_ "github.com/mattn/go-sqlite3"
)

func syncTestDB(t *testing.T) *sql.DB {
	t.Helper()
	db, err := sql.Open("sqlite3", filepath.Join(t.TempDir(), "sync.db")+"?_busy_timeout=5000")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	_, err = db.Exec(`CREATE TABLE admins (id INTEGER PRIMARY KEY, email TEXT, role TEXT);
		INSERT INTO admins VALUES (1, 'one@example.test', 'superadmin'), (2, 'two@example.test', 'superadmin'), (3, 'one@example.test', 'admin');
		CREATE TABLE sync_snapshots (snapshot_id TEXT PRIMARY KEY, account_id INTEGER, version INTEGER,
		payload TEXT, checksum TEXT, size INTEGER, device_id TEXT, created_at TEXT, created_by_admin_id INTEGER,
		UNIQUE(account_id, version));`)
	if err != nil {
		t.Fatal(err)
	}
	return db
}

func pushTestRequest(db *sql.DB, adminID int, device string, base *int, payload []byte) *httptest.ResponseRecorder {
	body, _ := json.Marshal(SyncSnapshotRequest{PayloadBase64: base64.StdEncoding.EncodeToString(payload), DeviceID: device, BaseVersion: base})
	req := httptest.NewRequest(http.MethodPost, "/api/sync/push", bytes.NewReader(body))
	req = req.WithContext(context.WithValue(req.Context(), "admin_id", adminID))
	w := httptest.NewRecorder()
	HandleSyncPush(db)(w, req)
	return w
}

func TestSyncConflictIsolationAndExactRetry(t *testing.T) {
	db := syncTestDB(t)
	zero := 0
	payload := []byte(`{"accountID":1,"amount":12.50,"name":"ภาษาไทย <>&","url":"file:///slip.jpg"}`)
	for i := 0; i < 2; i++ {
		w := pushTestRequest(db, 1, "A", &zero, payload)
		if w.Code != http.StatusOK {
			t.Fatalf("write/retry: %d %s", w.Code, w.Body.String())
		}
	}
	if w := pushTestRequest(db, 1, "B", &zero, []byte(`{"accountID":1,"amount":99}`)); w.Code != http.StatusConflict {
		t.Fatalf("stale write: %d", w.Code)
	}
	if w := pushTestRequest(db, 2, "B", &zero, []byte(`{"accountID":2}`)); w.Code != http.StatusOK {
		t.Fatalf("second account: %d", w.Code)
	}
	var count int
	db.QueryRow("SELECT COUNT(*) FROM sync_snapshots WHERE account_id=1").Scan(&count)
	if count != 1 {
		t.Fatalf("duplicate snapshot: %d", count)
	}
	w := httptest.NewRecorder()
	writeLatestSnapshot(db, w, 1, "one@example.test")
	var reply struct {
		Raw      string `json:"payload_base64"`
		Checksum string `json:"checksum"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &reply); err != nil {
		t.Fatal(err)
	}
	raw, err := base64.StdEncoding.DecodeString(reply.Raw)
	if err != nil || !bytes.Equal(raw, payload) {
		t.Fatal("snapshot bytes changed during round trip")
	}
	hash := sha256.Sum256(raw)
	if reply.Checksum != hex.EncodeToString(hash[:]) {
		t.Fatal("checksum mismatch")
	}
}

func TestSyncRejectsInvalidAndUnauthenticatedWrites(t *testing.T) {
	db := syncTestDB(t)
	zero, negative := 0, -1
	tests := []struct {
		name    string
		admin   int
		base    *int
		payload string
		status  int
	}{
		{"missing session", 0, &zero, `{"accountID":1}`, 401},
		{"unknown session", 99, &zero, `{"accountID":1}`, 401},
		{"old client", 1, nil, `{"accountID":1}`, 428},
		{"negative version", 1, &negative, `{"accountID":1}`, 400},
		{"other account", 1, &zero, `{"accountID":2}`, 400},
		{"null", 1, &zero, `null`, 400},
		{"array", 1, &zero, `[]`, 400},
		{"invalid json", 1, &zero, `{`, 400},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			w := pushTestRequest(db, tt.admin, "A", tt.base, []byte(tt.payload))
			if w.Code != tt.status {
				t.Fatalf("got %d want %d", w.Code, tt.status)
			}
		})
	}
}

func TestSyncStaffUsesOwnerAccount(t *testing.T) {
	db := syncTestDB(t)
	zero := 0
	if w := pushTestRequest(db, 3, "staff", &zero, []byte(`{"accountID":3}`)); w.Code != 200 {
		t.Fatal(w.Code)
	}
	var owner, author int
	if err := db.QueryRow("SELECT account_id, created_by_admin_id FROM sync_snapshots").Scan(&owner, &author); err != nil {
		t.Fatal(err)
	}
	if owner != 1 || author != 3 {
		t.Fatalf("owner=%d author=%d", owner, author)
	}
}

func TestSyncConcurrentWritersCannotOverwrite(t *testing.T) {
	db := syncTestDB(t)
	zero := 0
	results := make(chan int, 2)
	var wg sync.WaitGroup
	for _, device := range []string{"A", "B"} {
		wg.Add(1)
		go func(device string) {
			defer wg.Done()
			results <- pushTestRequest(db, 1, device, &zero, []byte(`{"accountID":1}`)).Code
		}(device)
	}
	wg.Wait()
	close(results)
	counts := map[int]int{}
	for status := range results {
		counts[status]++
	}
	if counts[200] != 1 || counts[409] != 1 {
		t.Fatalf("statuses: %v", counts)
	}
}

func TestLegacySyncRejectsWithoutBaseVersion(t *testing.T) {
	db := syncTestDB(t)
	if w := pushTestRequest(db, 1, "legacy", nil, []byte(`{"accountID":1,"revision":1}`)); w.Code != http.StatusPreconditionRequired {
		t.Fatalf("expected 428 Precondition Required, got %d", w.Code)
	}
}
