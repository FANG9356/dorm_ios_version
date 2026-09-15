package handlers

import (
	"database/sql"
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
