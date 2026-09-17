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
		"ขั้นที่ 3 จาก 5",
		"เวลาในประเทศไทย (UTC+7)",
	} {
		if !strings.Contains(text, expected) {
			t.Fatalf("Flex payload does not contain %q: %s", expected, text)
		}
	}
	if strings.Contains(text, "1 ม.ค. 2573") {
		t.Fatal("Flex payload used retry time instead of maintenance event time")
	}
}

func TestMaintenanceFlexRejectsIncompleteDetail(t *testing.T) {
	_, err := buildMaintenanceStatusFlexMessage(maintenanceStatusNotification{RoomNumber: "103"}, time.Now())
	if err == nil {
		t.Fatal("expected missing detail error")
	}
}

func TestMaintenanceTimeParsesLegacyBangkokValue(t *testing.T) {
	got := formatThaiMaintenanceDateTime("2026-09-17 09:45:00", time.Time{}, true)
	if got != "17 ก.ย. 2569 • 09:45 น." {
		t.Fatalf("formatted time = %q", got)
	}
}
