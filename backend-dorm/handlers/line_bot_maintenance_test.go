package handlers

import (
	"encoding/json"
	"strings"
	"testing"
	"time"
)

func TestMaintenanceFlexUsesSourceTimestampInBangkokTimezone(t *testing.T) {
	notification := maintenanceStatusNotification{
		LineUserID: "line-one", RoomNumber: "103", Issue: `น้ำไม่ไหล "ชั้นบน"`,
		Status: "กำลังซ่อม", Cost: 450.50, ReportedAt: "2026-09-16",
		PaymentMethod: "โอนผ่านธนาคาร", LastUpdated: "2026-09-17T02:30:00Z",
	}
	message, err := buildMaintenanceStatusFlexMessage(notification, time.Date(2030, 1, 1, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatal(err)
	}
	payload, err := json.Marshal(message)
	if err != nil {
		t.Fatal(err)
	}
	text := string(payload)
	for _, expected := range []string{
		"17 ก.ย. 2569 • 09:30 น.",
		"16 ก.ย. 2569",
		`น้ำไม่ไหล \"ชั้นบน\"`,
		"450.50 บาท",
		"โอนผ่านธนาคาร",
		"4/6",
	} {
		if !strings.Contains(text, expected) {
			t.Fatalf("Flex payload does not contain %q: %s", expected, text)
		}
	}
	if strings.Contains(text, "1 ม.ค. 2573") {
		t.Fatal("Flex payload used retry time instead of maintenance event time")
	}
	for _, forbidden := range []string{"\"backgroundColor\":\"#111827\"", "#7C3AED", "#0284C7", "#D97706", "#059669", "\"footer\""} {
		if strings.Contains(text, forbidden) {
			t.Fatalf("compact monochrome Flex payload contains legacy styling %q: %s", forbidden, text)
		}
	}
}

func TestMaintenanceFlexRejectsIncompleteDetail(t *testing.T) {
	_, err := buildMaintenanceStatusFlexMessage(maintenanceStatusNotification{RoomNumber: "103"}, time.Now())
	if err == nil {
		t.Fatal("expected missing detail error")
	}
}

func TestMaintenanceQuoteFlexRequiresApprovalBeforeRepair(t *testing.T) {
	notification := maintenanceStatusNotification{
		MaintenanceID: "44", LineUserID: "line-one", RoomNumber: "103",
		Issue: "เครื่องซักผ้าเสีย", Status: "รออนุมัติค่าใช้จ่าย", Cost: 2750,
		LastUpdated: "2026-09-17T07:15:00Z",
	}
	message, err := buildMaintenanceStatusFlexMessage(notification, time.Time{})
	if err != nil {
		t.Fatal(err)
	}
	payload, err := json.Marshal(message)
	if err != nil {
		t.Fatal(err)
	}
	text := string(payload)
	for _, expected := range []string{
		"ใบเสนอราคางานซ่อม", "2,750.00 บาท", "งานจะเริ่มหลังจากคุณอนุมัติเท่านั้น",
		`action=maintenance_quote_reject\u0026id=44`, `action=maintenance_quote_approve\u0026id=44`,
	} {
		if !strings.Contains(text, expected) {
			t.Fatalf("quote Flex payload does not contain %q: %s", expected, text)
		}
	}
	if strings.Contains(text, `"alignItems":"baseline"`) {
		t.Fatalf("quote Flex payload contains unsupported LINE alignment: %s", text)
	}
}

func TestMaintenancePaymentFlexContainsSlipAction(t *testing.T) {
	notification := maintenanceStatusNotification{
		MaintenanceID: "44", LineUserID: "line-one", RoomNumber: "103",
		Issue: "เครื่องซักผ้าเสีย", Status: "รอตรวจสอบชำระเงิน", Cost: 2750,
		LastUpdated: "2026-09-17T07:15:00Z",
	}
	message, err := buildMaintenanceStatusFlexMessage(notification, time.Time{})
	if err != nil {
		t.Fatal(err)
	}
	payload, err := json.Marshal(message)
	if err != nil {
		t.Fatal(err)
	}
	text := string(payload)
	for _, expected := range []string{"ค่าซ่อมที่อนุมัติแล้ว", "2,750.00 บาท", `action=pay_maint\u0026id=44`} {
		if !strings.Contains(text, expected) {
			t.Fatalf("payment Flex payload does not contain %q: %s", expected, text)
		}
	}
	if strings.Contains(text, `"alignItems":"baseline"`) {
		t.Fatalf("payment Flex payload contains unsupported LINE alignment: %s", text)
	}
}

func TestMaintenanceQuoteAndPaymentFlexRejectMissingRecordID(t *testing.T) {
	for _, status := range []string{"รออนุมัติค่าใช้จ่าย", "รอตรวจสอบชำระเงิน"} {
		_, err := buildMaintenanceStatusFlexMessage(maintenanceStatusNotification{
			RoomNumber: "103", Issue: "น้ำไม่ไหล", Status: status, Cost: 20,
		}, time.Now())
		if err == nil {
			t.Fatalf("status %q should require maintenance id", status)
		}
	}
}

func TestMaintenanceRejectFlexUsesCompactMonochromeStyle(t *testing.T) {
	notification := maintenanceStatusNotification{
		MaintenanceID: "44", LineUserID: "line-one", RoomNumber: "103",
		Issue: "น้ำไม่ไหล", Status: "ปฏิเสธค่าใช้จ่าย",
		LastUpdated: "2026-09-17T14:26:48Z",
	}
	message, err := buildMaintenanceStatusFlexMessage(notification, time.Time{})
	if err != nil {
		t.Fatal(err)
	}
	payload, err := json.Marshal(message)
	if err != nil {
		t.Fatal(err)
	}
	text := string(payload)
	for _, expected := range []string{
		"แจ้งซ่อม", "ผลการพิจารณา", "ไม่อนุมัติใบเสนอราคา",
		"ระบบจะยกเลิกรายการนี้ภายใน 24 ชั่วโมง", "17 ก.ย. 2569 • 21:26 น.",
		`"backgroundColor":"#F3F4F6"`,
	} {
		if !strings.Contains(text, expected) {
			t.Fatalf("reject Flex payload does not contain %q: %s", expected, text)
		}
	}
	for _, forbidden := range []string{"#DC2626", "#B91C1C", "#FEE2E2", "ระบบจะดำเนินการยกเลิกงานแจ้งซ่อมนี้"} {
		if strings.Contains(text, forbidden) {
			t.Fatalf("reject Flex payload contains legacy red styling %q: %s", forbidden, text)
		}
	}
}

func TestMaintenanceTimeParsesLegacyBangkokValue(t *testing.T) {
	got := formatThaiMaintenanceDateTime("2026-09-17 09:45:00", time.Time{}, true)
	if got != "17 ก.ย. 2569 • 09:45 น." {
		t.Fatalf("formatted time = %q", got)
	}
}
