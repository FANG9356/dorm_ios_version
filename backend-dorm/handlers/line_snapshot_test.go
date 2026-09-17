package handlers

import (
	"database/sql"
	"testing"

	_ "github.com/mattn/go-sqlite3"
)

func TestMaterializeLineSnapshotKeepsIdentityAcrossRoomMove(t *testing.T) {
	master, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatal(err)
	}
	defer master.Close()
	InitializeLineIntegration(master)
	if _, err := master.Exec(`INSERT INTO line_links(line_user_id, account_id, tenant_id, status)
		VALUES ('line-one', 7, 'tenant-one', 'linked')`); err != nil {
		t.Fatal(err)
	}
	tenantDB, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatal(err)
	}
	defer tenantDB.Close()

	snapshot := lineSyncEnvelope{
		SnapshotID: "snapshot-1",
		AccountID:  7,
		Tenants: []lineTenantSnapshot{{
			ID: "tenant-one", ServerID: intPointer(44), FirstName: "หนึ่ง", RoomNumber: "101",
			Status: "กำลังพักอาศัย", Phone: "0800000000",
		}},
		Payments: []linePaymentSnapshot{{
			ID: "payment-one", UserID: 44, RoomNumber: "101", Month: "2026-09",
			RentFee: 1500, DepositFee: 75, Amount: 1575, PaymentStatus: "pending",
			LastUpdated: "2026-09-15T14:30:00Z",
		}},
	}
	if err := materializeLineSnapshotInto(master, tenantDB, 7, snapshot); err != nil {
		t.Fatal(err)
	}

	var room, lineUserID string
	if err := tenantDB.QueryRow(`SELECT room_number, line_user_id FROM users WHERE external_id='tenant-one'`).Scan(&room, &lineUserID); err != nil {
		t.Fatal(err)
	}
	if room != "101" || lineUserID != "line-one" {
		t.Fatalf("initial room/link = %q/%q", room, lineUserID)
	}
	var deposit float64
	var lastUpdated string
	if err := tenantDB.QueryRow(`SELECT deposit_fee, last_updated FROM payments WHERE external_id='payment-one'`).Scan(&deposit, &lastUpdated); err != nil {
		t.Fatal(err)
	}
	if deposit != 75 {
		t.Fatalf("deposit = %v", deposit)
	}
	if lastUpdated != "2026-09-15T14:30:00Z" {
		t.Fatalf("last_updated = %q", lastUpdated)
	}

	snapshot.SnapshotID = "snapshot-2"
	snapshot.Tenants[0].RoomNumber = "205"
	if err := materializeLineSnapshotInto(master, tenantDB, 7, snapshot); err != nil {
		t.Fatal(err)
	}
	if err := tenantDB.QueryRow(`SELECT room_number, line_user_id FROM users WHERE external_id='tenant-one'`).Scan(&room, &lineUserID); err != nil {
		t.Fatal(err)
	}
	if room != "205" || lineUserID != "line-one" {
		t.Fatalf("moved room/link = %q/%q", room, lineUserID)
	}
}

func TestMaterializeLineSnapshotMarksRemovedTenantUnlinked(t *testing.T) {
	master, _ := sql.Open("sqlite3", ":memory:")
	defer master.Close()
	InitializeLineIntegration(master)
	tenantDB, _ := sql.Open("sqlite3", ":memory:")
	defer tenantDB.Close()

	first := lineSyncEnvelope{SnapshotID: "one", AccountID: 1, Tenants: []lineTenantSnapshot{{
		ID: "removed", ServerID: intPointer(55), RoomNumber: "103", Status: "กำลังพักอาศัย",
	}}}
	if err := materializeLineSnapshotInto(master, tenantDB, 1, first); err != nil {
		t.Fatal(err)
	}
	if err := materializeLineSnapshotInto(master, tenantDB, 1, lineSyncEnvelope{SnapshotID: "two", AccountID: 1}); err != nil {
		t.Fatal(err)
	}
	var status, lineUserID string
	if err := tenantDB.QueryRow(`SELECT status, line_user_id FROM users WHERE external_id='removed'`).Scan(&status, &lineUserID); err != nil {
		t.Fatal(err)
	}
	if status != "ย้ายออกแล้ว" || lineUserID != "" {
		t.Fatalf("removed tenant = %q/%q", status, lineUserID)
	}
}

func TestMaterializeLineSnapshotNotifiesOnlyChangedMaintenanceStatus(t *testing.T) {
	master, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatal(err)
	}
	defer master.Close()
	InitializeLineIntegration(master)
	if _, err := master.Exec(`INSERT INTO line_links(line_user_id, account_id, tenant_id, status)
		VALUES ('line-one', 7, 'tenant-one', 'linked')`); err != nil {
		t.Fatal(err)
	}
	tenantDB, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatal(err)
	}
	defer tenantDB.Close()

	snapshot := lineSyncEnvelope{
		SnapshotID: "snapshot-1",
		AccountID:  7,
		Tenants: []lineTenantSnapshot{{
			ID: "tenant-one", ServerID: intPointer(44), FirstName: "หนึ่ง", RoomNumber: "103",
			Status: "กำลังพักอาศัย",
		}},
		Maintenance: []lineMaintenanceSnapshot{{
			ID: "maintenance-one", RoomNumber: "103", Issue: "ไฟดับ", Status: "รอดำเนินการ",
		}},
	}

	var notifications []maintenanceStatusChange
	notifier := func(eventKey, lineUserID, roomNumber, issue, status string) error {
		if lineUserID != "line-one" {
			t.Fatalf("line user = %q", lineUserID)
		}
		if eventKey == "" {
			t.Fatal("empty notification event key")
		}
		notifications = append(notifications, maintenanceStatusChange{RoomNumber: roomNumber, Issue: issue, Status: status})
		return nil
	}
	if err := materializeLineSnapshotIntoWithNotifier(master, tenantDB, 7, snapshot, notifier); err != nil {
		t.Fatal(err)
	}
	if len(notifications) != 0 {
		t.Fatalf("new maintenance sent %d notifications", len(notifications))
	}

	snapshot.SnapshotID = "snapshot-2"
	snapshot.Maintenance[0].Status = "กำลังติดต่อช่าง"
	if err := materializeLineSnapshotIntoWithNotifier(master, tenantDB, 7, snapshot, notifier); err != nil {
		t.Fatal(err)
	}
	if len(notifications) != 1 {
		t.Fatalf("changed maintenance sent %d notifications", len(notifications))
	}
	got := notifications[0]
	if got.RoomNumber != "103" || got.Issue != "ไฟดับ" || got.Status != "กำลังติดต่อช่าง" {
		t.Fatalf("notification = %+v", got)
	}

	snapshot.SnapshotID = "snapshot-3"
	if err := materializeLineSnapshotIntoWithNotifier(master, tenantDB, 7, snapshot, notifier); err != nil {
		t.Fatal(err)
	}
	if len(notifications) != 1 {
		t.Fatalf("unchanged maintenance resent notification: %d", len(notifications))
	}
}

func TestSingleLineAccountRejectsAmbiguousAccounts(t *testing.T) {
	db, _ := sql.Open("sqlite3", ":memory:")
	defer db.Close()
	db.Exec(`CREATE TABLE sync_snapshots(account_id INTEGER)`)
	db.Exec(`INSERT INTO sync_snapshots VALUES (1), (1)`)
	accountID, err := singleLineAccount(db)
	if err != nil || accountID != 1 {
		t.Fatalf("single account = %d, %v", accountID, err)
	}
	db.Exec(`INSERT INTO sync_snapshots VALUES (2)`)
	if _, err := singleLineAccount(db); err == nil {
		t.Fatal("expected ambiguous account error")
	}
}

func TestNormalizeMaintenanceSnapshotsDeduplicatesUUIDCaseAndKeepsNewest(t *testing.T) {
	idLower := "5f5a483f-af16-4237-ae54-c3c0a82330cf"
	idUpper := "5F5A483F-AF16-4237-AE54-C3C0A82330CF"
	items := normalizeMaintenanceSnapshots([]lineMaintenanceSnapshot{
		{ID: idLower, Status: "รอดำเนินการ", LastUpdated: "2026-09-16T03:06:16.996Z"},
		{ID: idUpper, Status: "เสร็จสิ้น", LastUpdated: "2026-09-16T13:54:08Z"},
		{ID: "27f6ec6e-8096-42fc-89e0-acc06e35af92", Status: "รอดำเนินการ", LastUpdated: "2026-09-17T01:37:41Z"},
	})
	if len(items) != 2 {
		t.Fatalf("maintenance count = %d, want 2", len(items))
	}
	if items[0].ID != idLower || items[0].Status != "เสร็จสิ้น" {
		t.Fatalf("deduplicated maintenance = %+v", items[0])
	}
}

func TestNormalizeMaintenancePayloadRemovesCaseDuplicate(t *testing.T) {
	payload := []interface{}{
		map[string]interface{}{"id": "ABCDEF00-0000-4000-8000-000000000000", "status": "เก่า", "lastUpdated": "2026-09-16T01:00:00Z"},
		map[string]interface{}{"id": "abcdef00-0000-4000-8000-000000000000", "status": "ใหม่", "lastUpdated": "2026-09-17T01:00:00Z"},
	}
	normalized, changed := normalizeMaintenancePayload(payload)
	if !changed || len(normalized) != 1 {
		t.Fatalf("changed=%v count=%d", changed, len(normalized))
	}
	item := normalized[0].(map[string]interface{})
	if item["id"] != "abcdef00-0000-4000-8000-000000000000" || item["status"] != "ใหม่" {
		t.Fatalf("normalized payload = %+v", item)
	}
}

func intPointer(value int) *int { return &value }
