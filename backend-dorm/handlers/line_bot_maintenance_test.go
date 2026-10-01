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

func TestMaintenancePaymentFlexUsesAutomaticSlipInstructions(t *testing.T) {
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
	for _, expected := range []string{"ค่าซ่อมที่อนุมัติแล้ว", "2,750.00 บาท", "รองรับการสแกนผ่านทุกแอปธนาคาร"} {
		if !strings.Contains(text, expected) {
			t.Fatalf("payment Flex payload does not contain %q: %s", expected, text)
		}
	}
	if strings.Contains(text, `action=pay_maint`) {
		t.Fatalf("payment Flex payload still contains the removed manual slip action: %s", text)
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

// TestMaintenanceFreeJobFlexHasNoQuoteButton ตรวจว่า flow ฟรี (cost=0) ไม่สร้าง Flex
// ใบเสนอราคา (รออนุมัติค่าใช้จ่าย ที่ถูกต้องต้องมี cost>0) และสามารถสร้าง Flex
// สถานะกำลังซ่อมได้โดยไม่ต้องการ MaintenanceID
func TestMaintenanceFreeJobFlexHasNoQuoteButton(t *testing.T) {
	// กำลังซ่อม cost=0 คือ free-job ต้องสร้าง Flex สถานะปกติได้โดยไม่ต้องการ id
	notification := maintenanceStatusNotification{
		LineUserID:  "line-free",
		RoomNumber:  "201",
		Issue:       "หลอดไฟขาด",
		Status:      "กำลังซ่อม",
		Cost:        0,
		LastUpdated: "2026-09-18T03:00:00Z",
	}
	message, err := buildMaintenanceStatusFlexMessage(notification, time.Time{})
	if err != nil {
		t.Fatalf("free-job กำลังซ่อม should not require maintenance ID: %v", err)
	}
	payload, _ := message["contents"].(map[string]interface{})
	if payload == nil {
		t.Fatal("missing contents in Flex message")
	}
	// ต้องไม่มีปุ่ม approve/reject
	raw, _ := marshalJSONTest(message)
	if strings.Contains(raw, "maintenance_quote_approve") || strings.Contains(raw, "maintenance_quote_reject") {
		t.Fatal("free-job Flex should not contain quote approve/reject actions")
	}
}

// TestMaintenanceQuoteFlexRejectsZeroCost ตรวจว่า รออนุมัติค่าใช้จ่าย ที่มี cost=0
// ไม่สร้าง Flex ใบเสนอราคา (ต้องมียอดก่อนส่ง quote)
func TestMaintenanceQuoteFlexRejectsZeroCost(t *testing.T) {
	notification := maintenanceStatusNotification{
		MaintenanceID: "99",
		LineUserID:    "line-one",
		RoomNumber:    "103",
		Issue:         "น้ำไม่ไหล",
		Status:        "รออนุมัติค่าใช้จ่าย",
		Cost:          0, // ยอด 0 บาท
		LastUpdated:   "2026-09-18T03:00:00Z",
	}
	message, err := buildMaintenanceStatusFlexMessage(notification, time.Time{})
	if err != nil {
		// zero-cost quote falls back to the generic status card (not an error from buildMaintenanceStatusFlexMessage)
		// ถ้า error ให้ตรวจว่าไม่ใช่ error จากข้อมูลขาด แต่จาก cost=0
		t.Logf("zero-cost quote returned error (acceptable): %v", err)
		return
	}
	// ถ้า build สำเร็จ ต้องไม่มีปุ่ม approve/reject เพราะ cost=0 ไม่ผ่านเงื่อนไขใบเสนอราคา
	raw, _ := marshalJSONTest(message)
	if strings.Contains(raw, "maintenance_quote_approve") {
		t.Fatal("zero-cost quote Flex should not contain approve action")
	}
}

// TestMaintenanceStaleApproveDetection ตรวจว่า handleMaintenanceQuoteDecision logic
// จะปฏิเสธ action ที่ซ้ำหลังจากอนุมัติ/ปฏิเสธแล้ว โดยตรวจที่ระดับ Flex payload
// (การทดสอบ DB-level ต้องการ integration test แยก)
func TestMaintenanceStaleApproveDetection(t *testing.T) {
	// ตรวจว่า buildMaintenanceStatusFlexMessage สำหรับ "กำลังติดต่อช่าง" หลังอนุมัติ
	// ไม่มีปุ่ม approve/reject (เพราะ approved แล้ว ไม่ควรมีปุ่มเหล่านั้น)
	notification := maintenanceStatusNotification{
		MaintenanceID: "44",
		LineUserID:    "line-one",
		RoomNumber:    "103",
		Issue:         "เครื่องซักผ้าเสีย",
		Status:        "กำลังติดต่อช่าง", // หลังอนุมัติจะกลับมา state นี้
		Cost:          2750,
		LastUpdated:   "2026-09-18T06:00:00Z",
	}
	message, err := buildMaintenanceStatusFlexMessage(notification, time.Time{})
	if err != nil {
		t.Fatal(err)
	}
	raw, _ := marshalJSONTest(message)
	// หลังอนุมัติแล้ว card สถานะ "กำลังติดต่อช่าง" ต้องไม่มีปุ่ม approve/reject
	if strings.Contains(raw, "maintenance_quote_approve") || strings.Contains(raw, "maintenance_quote_reject") {
		t.Fatal("post-approval status card should not contain quote decision buttons")
	}
	// ต้องมีชื่อสถานะ
	if !strings.Contains(raw, "กำลังติดต่อช่าง") {
		t.Fatal("status card should display current status")
	}
}

// TestMaintenanceNonQuoteStatusDoesNotRequireID ตรวจว่าสถานะ non-quote/payment
// สร้าง Flex ได้โดยไม่ต้องการ MaintenanceID
func TestMaintenanceNonQuoteStatusDoesNotRequireID(t *testing.T) {
	statuses := []string{"รอดำเนินการ", "กำลังติดต่อช่าง", "กำลังซ่อม", "เสร็จสิ้น"}
	for _, status := range statuses {
		t.Run(status, func(t *testing.T) {
			notification := maintenanceStatusNotification{
				// ไม่มี MaintenanceID
				LineUserID:  "line-one",
				RoomNumber:  "103",
				Issue:       "น้ำไม่ไหล",
				Status:      status,
				LastUpdated: "2026-09-18T03:00:00Z",
			}
			_, err := buildMaintenanceStatusFlexMessage(notification, time.Time{})
			if err != nil {
				t.Fatalf("status %q without MaintenanceID should not fail: %v", status, err)
			}
		})
	}
}

// TestMaintenanceQuoteApprovedFlexMessage ตรวจว่า EventKey ของการอนุมัติใบเสนอราคา
// จะสร้าง Flex message แบบ Carousel ที่มี 2 Bubble (การ์ดอนุมัติ และ QR)
func TestMaintenanceQuoteApprovedFlexMessage(t *testing.T) {
	notification := maintenanceStatusNotification{
		EventKey:      "maintenance-quote-approved:1:55:2026-09-18T12:00:00Z",
		MaintenanceID: "55",
		LineUserID:    "line-user",
		RoomNumber:    "103",
		Issue:         "ก๊อกน้ำรั่ว",
		Status:        "กำลังติดต่อช่าง", // Status จะเป็นแบบนี้เมื่ออนุมัติ
		Cost:          500,
		LastUpdated:   "2026-09-18T12:00:00Z",
		PromptPayID:   "0961950943",
	}

	message, err := buildMaintenanceStatusFlexMessage(notification, time.Time{})
	if err != nil {
		t.Fatalf("quote approved flex failed: %v", err)
	}

	contents, ok := message["contents"].(map[string]interface{})
	if !ok {
		t.Fatal("expected contents to be a map")
	}

	// ต้องเป็น Carousel
	if contents["type"] != "carousel" {
		t.Fatalf("expected type carousel, got %v", contents["type"])
	}

	bubbles, ok := contents["contents"].([]interface{})
	if !ok || len(bubbles) != 2 {
		t.Fatalf("expected carousel to have 2 bubbles, got %v", bubbles)
	}

	raw, _ := marshalJSONTest(message)
	if !strings.Contains(raw, "อนุมัติใบเสนอราคา") {
		t.Error("missing approval message")
	}
	if !strings.Contains(raw, "ช่องทางชำระเงิน") {
		t.Error("missing payment channel header")
	}
	if !strings.Contains(raw, "500") {
		t.Error("missing cost in payment channel")
	}
}

// marshalJSONTest เป็น helper สำหรับ test เพื่อ marshal Flex message เป็น string
func marshalJSONTest(v interface{}) (string, error) {
	b, err := json.Marshal(v)
	return string(b), err
}
