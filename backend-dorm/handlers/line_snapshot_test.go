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

func intPointer(value int) *int { return &value }
