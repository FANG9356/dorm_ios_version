package handlers

import (
	"database/sql"
	"encoding/json"
	"strings"
	"testing"

	_ "github.com/mattn/go-sqlite3"
)

func TestLoadAndBuildLineInvoiceUsesResidentIdentityAndCompleteDetails(t *testing.T) {
	db, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	InitializeTenantDatabase(db)
	ensureLineTenantSchema(db)
	if _, err := db.Exec(`INSERT INTO users(user_id, full_name, room_number, status) VALUES
		(11, 'ลูกบ้านปัจจุบัน', '103', 'กำลังพักอาศัย'),
		(12, 'ลูกบ้านคนก่อน', '103', 'ย้ายออกแล้ว');
		INSERT INTO payments(payment_id, user_id, room_number, month, due_date, last_updated,
			payment_date, payment_status, installment_phase, rent_fee, deposit_fee, water_fee,
			electric_fee, common_fee, appliance_fee, late_fee, amount, paid_amount) VALUES
		(10, 11, '103', '2569-09', '2569-09-30', '2026-09-15T14:30:00Z',
			'2569-09-15', 'partial', 1, 3000, 0, 300, 400, 100, 0, 0, 3800, 800),
		(7, 11, '103', '2026-09', '2026-09-30', '2026-09-01T10:47:39Z',
			'', 'pending', 0, 3000, 0, 0, 0, 0, 0, 0, 3000, 0),
		(99, 12, '103', '2026-10', '2026-10-31', '2026-10-01T00:00:00Z',
			'', 'pending', 0, 9000, 0, 0, 0, 0, 0, 0, 9000, 0)`); err != nil {
		t.Fatal(err)
	}

	invoice, err := loadLatestOutstandingLineInvoice(db, 11, "103", "ลูกบ้านปัจจุบัน")
	if err != nil {
		t.Fatal(err)
	}
	if invoice.InvoiceNo != "INV-00010" || invoice.Total != 3800 || invoice.Paid != 800 ||
		invoice.Water != 300 || invoice.AdditionalBills != 1 {
		t.Fatalf("invoice = %+v", invoice)
	}
	encoded, err := json.Marshal(buildLineInvoiceBubble(invoice))
	if err != nil {
		t.Fatal(err)
	}
	message := string(encoded)
	for _, expected := range []string{
		"เลขที่บิล INV-00010", "กันยายน 2569", "30 ก.ย. 2569", "15 ก.ย. 2569 21:30 น.",
		"ค่าเช่าห้อง", "ค่าน้ำประปา", "ค่าไฟฟ้า", "ค่าส่วนกลาง", "ค่าปรับ",
		"ยอดบิล", "ชำระแล้ว", "ยอดคงเหลือ", "3,800.00 บาท", "3,000.00 บาท",
		"มีใบแจ้งหนี้ค้างอีก 1 ใบ",
	} {
		if !strings.Contains(message, expected) {
			t.Fatalf("Flex message missing %q: %s", expected, message)
		}
	}
	if strings.Contains(message, "3112") || strings.Contains(message, "#F59E0B") {
		t.Fatalf("Flex message retained an invalid year or legacy orange styling: %s", message)
	}
}

func TestLineInvoiceDateFormattingAcceptsGregorianAndBuddhistStorage(t *testing.T) {
	if first, second := formatLinePeriod("2026-09"), formatLinePeriod("2569-09"); first != "กันยายน 2569" || second != first {
		t.Fatalf("formatted periods = %q / %q", first, second)
	}
	if got := formatLineDate("2569-09-30"); got != "30 ก.ย. 2569" {
		t.Fatalf("formatted date = %q", got)
	}
}

func TestLineInvoiceFlexMessageIncludesQRWhenDue(t *testing.T) {
	masterDB, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatal(err)
	}
	defer masterDB.Close()
	masterDB.Exec(`CREATE TABLE admins (
		id INTEGER PRIMARY KEY,
		username TEXT,
		role TEXT,
		promptpay_id TEXT,
		account_name TEXT,
		payment_type TEXT,
		bank_account TEXT
	);
	INSERT INTO admins (id, username, role, promptpay_id, account_name, payment_type, bank_account)
	VALUES (1, 'FangA', 'superadmin', '0961950943', 'ภคพล สุขมี', 'promptpay', '1234567890');`)

	// Test invoice for current month (2026-11) with unpaid balance
	invoice := lineInvoiceFlexData{
		InvoiceNo: "INV-00105",
		Room:      "105",
		Name:      "นางสาวพลเกาะแก้ว",
		Period:    "2026-11",
		Status:    "pending",
		Total:     3500,
		Paid:      0,
		Rent:      3500,
	}

	flex := buildLineInvoiceFlexMessage(masterDB, 1, invoice)
	if flex["type"] != "carousel" {
		t.Fatalf("expected carousel for due invoice, got %v", flex["type"])
	}
	contents, ok := flex["contents"].([]interface{})
	if !ok || len(contents) != 2 {
		t.Fatalf("expected 2 bubbles in carousel, got %d", len(contents))
	}

	encoded, err := json.Marshal(flex)
	if err != nil {
		t.Fatal(err)
	}
	message := string(encoded)

	for _, expected := range []string{
		"ช่องทางชำระเงิน", "สแกน QR Code เพื่อชำระเงิน", "096-195-0943", "ภคพล สุขมี", "api.qrserver.com",
	} {
		if !strings.Contains(message, expected) {
			t.Fatalf("Flex carousel missing %q: %s", expected, message)
		}
	}

	// Test with Buddhist year format (2569-11)
	invoiceBuddhist := invoice
	invoiceBuddhist.Period = "2569-11"
	flexBuddhist := buildLineInvoiceFlexMessage(masterDB, 1, invoiceBuddhist)
	if flexBuddhist["type"] != "carousel" {
		t.Fatalf("expected carousel for buddhist due invoice, got %v", flexBuddhist["type"])
	}
}

func TestLineInvoiceFlexMessageExcludesQRWhenNotDue(t *testing.T) {
	masterDB, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatal(err)
	}
	defer masterDB.Close()
	masterDB.Exec(`CREATE TABLE admins (
		id INTEGER PRIMARY KEY,
		username TEXT,
		role TEXT,
		promptpay_id TEXT,
		account_name TEXT,
		payment_type TEXT,
		bank_account TEXT
	);
	INSERT INTO admins (id, username, role, promptpay_id, account_name, payment_type, bank_account)
	VALUES (1, 'FangA', 'superadmin', '0961950943', 'ภคพล สุขมี', 'promptpay', '1234567890');`)

	// 1. Future billing cycle (e.g. year 2099)
	futureInvoice := lineInvoiceFlexData{
		InvoiceNo: "INV-00105",
		Room:      "105",
		Name:      "นางสาวพลเกาะแก้ว",
		Period:    "2099-12",
		Status:    "pending",
		Total:     3500,
		Paid:      0,
	}
	flexFuture := buildLineInvoiceFlexMessage(masterDB, 1, futureInvoice)
	if flexFuture["type"] != "bubble" {
		t.Fatalf("expected single bubble for future billing cycle, got %v", flexFuture["type"])
	}

	// 2. Already paid bill
	paidInvoice := lineInvoiceFlexData{
		InvoiceNo: "INV-00105",
		Room:      "105",
		Name:      "นางสาวพลเกาะแก้ว",
		Period:    "2026-11",
		Status:    "paid",
		Total:     3500,
		Paid:      3500,
	}
	flexPaid := buildLineInvoiceFlexMessage(masterDB, 1, paidInvoice)
	if flexPaid["type"] != "bubble" {
		t.Fatalf("expected single bubble for paid bill, got %v", flexPaid["type"])
	}
}
