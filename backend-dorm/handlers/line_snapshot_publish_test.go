package handlers

import (
	"database/sql"
	"encoding/json"
	"regexp"
	"testing"

	_ "github.com/mattn/go-sqlite3"
)

func TestPublishLineTenantChangesCreatesAppSnapshot(t *testing.T) {
	master, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatal(err)
	}
	defer master.Close()
	if _, err := master.Exec(`CREATE TABLE sync_snapshots (
		snapshot_id TEXT PRIMARY KEY, account_id INTEGER, version INTEGER, payload TEXT,
		checksum TEXT, size INTEGER, device_id TEXT, created_at TEXT, created_by_admin_id INTEGER,
		UNIQUE(account_id, version)
	)`); err != nil {
		t.Fatal(err)
	}

	tenant, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatal(err)
	}
	defer tenant.Close()
	InitializeTenantDatabase(tenant)
	ensureLineTenantSchema(tenant)

	paymentID := "4D73ACED-B1A5-46AF-86E7-ED19061F5877"
	if _, err := tenant.Exec(`INSERT INTO payments
		(user_id, room_number, amount, month, payment_date, method, slip_path, payment_status,
		 slip_path_array, paid_amount, last_updated, external_id)
		VALUES (10, '103', 3000, '2569-09', '2026-09-15', '', 'line-slip.jpg', 'checking',
		 '["line-slip.jpg"]', 0, '2026-09-15T09:02:15Z', ?)`, paymentID); err != nil {
		t.Fatal(err)
	}
	if _, err := tenant.Exec(`INSERT INTO maintenances
		(room_number, issue, status, cost, reported_at, issue_image)
		VALUES ('103', 'ไฟดับ', 'รอดำเนินการ', 0, '2026-09-15 08:59:54', '/uploads/problem.jpg')`); err != nil {
		t.Fatal(err)
	}

	payload := map[string]interface{}{
		"snapshotID": "device-snapshot", "accountID": 1, "version": 1,
		"createdAt": "2026-09-01T00:00:00Z", "deviceID": "ios-device",
		"rooms": []interface{}{}, "tenants": []interface{}{}, "maintenance": []interface{}{},
		"roomTypes": []interface{}{}, "logs": []interface{}{},
		"payments": []interface{}{map[string]interface{}{
			"id": paymentID, "paymentStatus": "pending", "paymentDate": "", "method": "",
			"slipPath": "", "slipPathArray": []interface{}{}, "paidAmount": float64(0),
			"lastUpdated": "2026-09-01T00:00:00Z",
		}},
	}
	raw, _ := json.Marshal(payload)
	if _, err := master.Exec(`INSERT INTO sync_snapshots
		(snapshot_id, account_id, version, payload, checksum, size, device_id, created_at, created_by_admin_id)
		VALUES ('device-snapshot', 1, 1, ?, '', ?, 'ios-device', '2026-09-01T00:00:00Z', 1)`, string(raw), len(raw)); err != nil {
		t.Fatal(err)
	}

	if err := PublishLineTenantChanges(master, tenant, 1); err != nil {
		t.Fatal(err)
	}
	var version int
	var deviceID, updatedPayload string
	if err := master.QueryRow(`SELECT version, device_id, payload FROM sync_snapshots
		WHERE account_id = 1 ORDER BY version DESC LIMIT 1`).Scan(&version, &deviceID, &updatedPayload); err != nil {
		t.Fatal(err)
	}
	if version != 2 || deviceID != "line-bot" {
		t.Fatalf("latest snapshot version/device = %d/%q, want 2/line-bot", version, deviceID)
	}
	var updated map[string]interface{}
	if err := json.Unmarshal([]byte(updatedPayload), &updated); err != nil {
		t.Fatal(err)
	}
	payments := snapshotObjectsByID(updated["payments"])
	if payments[paymentID]["paymentStatus"] != "checking" || payments[paymentID]["slipPath"] != "line-slip.jpg" {
		t.Fatalf("payment was not updated from LINE: %#v", payments[paymentID])
	}
	maintenance, ok := updated["maintenance"].([]interface{})
	if !ok || len(maintenance) != 1 {
		t.Fatalf("maintenance count = %d, want 1", len(maintenance))
	}
	item := maintenance[0].(map[string]interface{})
	id, _ := item["id"].(string)
	if !regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`).MatchString(id) {
		t.Fatalf("maintenance id %q is not a UUID", id)
	}
	if item["issue"] != "ไฟดับ" || item["issueImage"] != "/uploads/problem.jpg" {
		t.Fatalf("maintenance was not copied from LINE: %#v", item)
	}

	// Publishing the exact same tenant state must not generate endless versions.
	if err := PublishLineTenantChanges(master, tenant, 1); err != nil {
		t.Fatal(err)
	}
	if err := master.QueryRow(`SELECT MAX(version) FROM sync_snapshots WHERE account_id = 1`).Scan(&version); err != nil {
		t.Fatal(err)
	}
	if version != 2 {
		t.Fatalf("unchanged LINE state created snapshot version %d, want 2", version)
	}
}
