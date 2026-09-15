package handlers

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	_ "github.com/mattn/go-sqlite3"
)

func newLiffLookupTestDB(t *testing.T) *sql.DB {
	t.Helper()
	db, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	if _, err := db.Exec(`CREATE TABLE users (
		full_name TEXT NOT NULL,
		room_number TEXT NOT NULL,
		status TEXT NOT NULL,
		phone TEXT
	)`); err != nil {
		t.Fatal(err)
	}
	return db
}

func TestFindLineTenantByPhoneReturnsUniqueActiveRoom(t *testing.T) {
	db := newLiffLookupTestDB(t)
	if _, err := db.Exec(`INSERT INTO users(full_name, room_number, status, phone) VALUES
		('นาย สมชาย ใจดี', '102', 'active', '081-234-5678'),
		('นางสาว คนเดิม', '205', 'ย้ายออก', '089-111-2222')`); err != nil {
		t.Fatal(err)
	}

	room, name, err := findLineTenantByPhone(db, "081 234 5678")
	if err != nil {
		t.Fatalf("findLineTenantByPhone() error = %v", err)
	}
	if room != "102" || name != "นาย สมชาย ใจดี" {
		t.Fatalf("findLineTenantByPhone() = room %q, name %q", room, name)
	}
}

func TestFindLineTenantByPhoneIgnoresInactiveResident(t *testing.T) {
	db := newLiffLookupTestDB(t)
	if _, err := db.Exec(`INSERT INTO users(full_name, room_number, status, phone)
		VALUES ('ผู้เช่าเดิม', '205', 'ย้ายออก', '0891112222')`); err != nil {
		t.Fatal(err)
	}

	_, _, err := findLineTenantByPhone(db, "0891112222")
	if !errors.Is(err, sql.ErrNoRows) {
		t.Fatalf("findLineTenantByPhone() error = %v, want sql.ErrNoRows", err)
	}
}

func TestFindLineTenantByPhoneRejectsDuplicateActivePhone(t *testing.T) {
	db := newLiffLookupTestDB(t)
	if _, err := db.Exec(`INSERT INTO users(full_name, room_number, status, phone) VALUES
		('ผู้เช่าหนึ่ง', '101', 'active', '0812345678'),
		('ผู้เช่าสอง', '202', 'กำลังพักอาศัย', '081-234-5678')`); err != nil {
		t.Fatal(err)
	}

	_, _, err := findLineTenantByPhone(db, "0812345678")
	if !errors.Is(err, sql.ErrNoRows) {
		t.Fatalf("findLineTenantByPhone() error = %v, want sql.ErrNoRows", err)
	}
}

func TestFindLineTenantByPhoneRejectsBlankPhone(t *testing.T) {
	db := newLiffLookupTestDB(t)
	_, _, err := findLineTenantByPhone(db, "  ")
	if !errors.Is(err, sql.ErrNoRows) {
		t.Fatalf("findLineTenantByPhone() error = %v, want sql.ErrNoRows", err)
	}
}

func TestLiffRoomsNoLongerExposesRoomInventory(t *testing.T) {
	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/api/liff/rooms", nil)
	HandleLiffRooms(nil).ServeHTTP(recorder, request)

	if recorder.Code != http.StatusGone {
		t.Fatalf("GET /api/liff/rooms status = %d, want %d", recorder.Code, http.StatusGone)
	}
	if body := recorder.Body.String(); body == "" || body == "[]" {
		t.Fatalf("GET /api/liff/rooms returned an unexpected body %q", body)
	}
}

func TestLiffStatusReturnsCurrentLinkedRoom(t *testing.T) {
	master, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatal(err)
	}
	master.SetMaxOpenConns(1)
	defer master.Close()
	if _, err := master.Exec(`CREATE TABLE line_links (
		line_user_id TEXT PRIMARY KEY, account_id INTEGER NOT NULL,
		tenant_id TEXT NOT NULL, status TEXT NOT NULL
	); INSERT INTO line_links VALUES ('line-user-1', 7, 'tenant-1', 'linked')`); err != nil {
		t.Fatal(err)
	}

	tenant, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatal(err)
	}
	tenant.SetMaxOpenConns(1)
	defer tenant.Close()
	if _, err := tenant.Exec(`CREATE TABLE users (
		user_id INTEGER PRIMARY KEY, external_id TEXT, line_user_id TEXT, full_name TEXT,
		room_number TEXT, status TEXT, move_in_date TEXT, contract_end_date TEXT,
		indefinite_contract INTEGER
	); CREATE TABLE rooms (room_number TEXT, room_type TEXT);
	CREATE TABLE payments (
		payment_id INTEGER PRIMARY KEY, user_id INTEGER, month TEXT, due_date TEXT,
		last_updated TEXT, payment_date TEXT, payment_status TEXT, installment_phase INTEGER,
		rent_fee REAL, deposit_fee REAL, water_fee REAL, electric_fee REAL, common_fee REAL,
		appliance_fee REAL, late_fee REAL, amount REAL, paid_amount REAL
	); INSERT INTO users VALUES (11, 'tenant-1', 'line-user-1', 'นาย สมชาย มั่นคง',
		'103', 'active', '2026-01-10', '2027-01-09', 0);
	INSERT INTO rooms VALUES ('103', 'ห้องแอร์');
	INSERT INTO payments VALUES (10, 11, '2569-09', '2569-09-30', '2026-09-15T14:30:00Z',
		'2569-09-15', 'partial', 1, 3000, 0, 300, 400, 100, 0, 0, 3800, 800);
	INSERT INTO payments VALUES (9, 11, '2569-08', '2569-08-31', '2026-08-31T08:15:00Z',
		'', 'pending', 0, 3000, 0, 0, 0, 0, 0, 0, 3000, 0)`); err != nil {
		t.Fatal(err)
	}

	handler := handleLiffStatus(master,
		func(token string) (string, error) {
			if token != "valid-token" {
				t.Fatalf("token = %q", token)
			}
			return "line-user-1", nil
		},
		func(accountID int) (*sql.DB, error) {
			if accountID != 7 {
				t.Fatalf("accountID = %d", accountID)
			}
			return tenant, nil
		},
	)
	body := bytes.NewBufferString(`{"access_token":"valid-token"}`)
	request := httptest.NewRequest(http.MethodPost, "/api/liff/status", body)
	request.RemoteAddr = "198.51.100.81:1234"
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("POST /api/liff/status status = %d, body = %s", recorder.Code, recorder.Body.String())
	}
	var response struct {
		Linked     bool                `json:"linked"`
		RoomNumber string              `json:"room_number"`
		Resident   LiffResidentSummary `json:"resident"`
		Billing    LiffBillingSummary  `json:"billing"`
	}
	if err := json.NewDecoder(recorder.Body).Decode(&response); err != nil {
		t.Fatal(err)
	}
	if !response.Linked || response.RoomNumber != "103" || response.Resident.FullName != "นาย สมชาย มั่นคง" ||
		response.Resident.RoomType != "ห้องแอร์" || response.Billing.OutstandingAmount != 6000 ||
		response.Billing.OutstandingCount != 2 || len(response.Billing.Invoices) != 2 ||
		response.Billing.Invoices[0].InvoiceNumber != "INV-00010" ||
		response.Billing.Invoices[0].UpdatedAt != "2026-09-15T14:30:00Z" ||
		response.Billing.Invoices[0].Balance != 3000 || response.Billing.Invoices[0].WaterFee != 300 {
		t.Fatalf("status response = %+v", response)
	}
}

func TestLookupLinkedLineRoomRejectsStaleTenant(t *testing.T) {
	master, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatal(err)
	}
	defer master.Close()
	if _, err := master.Exec(`CREATE TABLE line_links (
		line_user_id TEXT PRIMARY KEY, account_id INTEGER NOT NULL,
		tenant_id TEXT NOT NULL, status TEXT NOT NULL
	); INSERT INTO line_links VALUES ('line-user-1', 7, 'tenant-1', 'linked')`); err != nil {
		t.Fatal(err)
	}
	tenant, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatal(err)
	}
	defer tenant.Close()
	if _, err := tenant.Exec(`CREATE TABLE users (
		user_id INTEGER PRIMARY KEY, external_id TEXT, line_user_id TEXT, full_name TEXT,
		room_number TEXT, status TEXT, move_in_date TEXT, contract_end_date TEXT,
		indefinite_contract INTEGER
	); CREATE TABLE rooms (room_number TEXT, room_type TEXT);
	INSERT INTO users VALUES (11, 'tenant-1', '', 'ผู้เช่าเดิม', '103', 'ย้ายออกแล้ว', '', '', 0)`); err != nil {
		t.Fatal(err)
	}

	_, err = lookupLinkedResident(master, func(int) (*sql.DB, error) { return tenant, nil }, "line-user-1")
	if !errors.Is(err, sql.ErrNoRows) {
		t.Fatalf("lookupLinkedLineRoom() error = %v, want sql.ErrNoRows", err)
	}
}
