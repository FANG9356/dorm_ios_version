package handlers

import (
	"database/sql"
	"errors"
	"testing"

	_ "github.com/mattn/go-sqlite3"
)

func TestMaintenanceNotificationOutboxIsIdempotent(t *testing.T) {
	db, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	InitializeLineIntegration(db)

	for i := 0; i < 2; i++ {
		if err := EnqueueMaintenanceStatusNotification(db, 7, "maintenance:7:item:updated:status", "line-one", "103", "ไฟดับ", "กำลังซ่อม"); err != nil {
			t.Fatal(err)
		}
	}
	var count int
	if err := db.QueryRow(`SELECT COUNT(*) FROM line_notification_outbox`).Scan(&count); err != nil {
		t.Fatal(err)
	}
	if count != 1 {
		t.Fatalf("outbox rows = %d, want 1", count)
	}
}

func TestProcessMaintenanceNotificationMarksSent(t *testing.T) {
	db, _ := sql.Open("sqlite3", ":memory:")
	defer db.Close()
	InitializeLineIntegration(db)
	if err := EnqueueMaintenanceStatusNotification(db, 7, "sent-event", "line-one", "103", "ไฟดับ", "กำลังซ่อม"); err != nil {
		t.Fatal(err)
	}
	called := 0
	processPendingLineNotifications(db, func(lineUserID, roomNumber, issue, status string) error {
		called++
		if lineUserID != "line-one" || roomNumber != "103" || issue != "ไฟดับ" || status != "กำลังซ่อม" {
			t.Fatalf("unexpected notification: %q %q %q %q", lineUserID, roomNumber, issue, status)
		}
		return nil
	})
	var deliveryStatus, sentAt string
	if err := db.QueryRow(`SELECT status, sent_at FROM line_notification_outbox WHERE event_key = 'sent-event'`).Scan(&deliveryStatus, &sentAt); err != nil {
		t.Fatal(err)
	}
	if called != 1 || deliveryStatus != "sent" || sentAt == "" {
		t.Fatalf("called=%d status=%q sent_at=%q", called, deliveryStatus, sentAt)
	}
}

func TestProcessMaintenanceNotificationSchedulesRetry(t *testing.T) {
	db, _ := sql.Open("sqlite3", ":memory:")
	defer db.Close()
	InitializeLineIntegration(db)
	if err := EnqueueMaintenanceStatusNotification(db, 7, "retry-event", "line-one", "103", "ไฟดับ", "กำลังซ่อม"); err != nil {
		t.Fatal(err)
	}
	processPendingLineNotifications(db, func(_, _, _, _ string) error {
		return errors.New("temporary LINE failure")
	})
	var deliveryStatus, lastError string
	var attempts int
	if err := db.QueryRow(`SELECT status, attempts, last_error FROM line_notification_outbox WHERE event_key = 'retry-event'`).Scan(&deliveryStatus, &attempts, &lastError); err != nil {
		t.Fatal(err)
	}
	if deliveryStatus != "pending" || attempts != 1 || lastError != "temporary LINE failure" {
		t.Fatalf("status=%q attempts=%d error=%q", deliveryStatus, attempts, lastError)
	}
}

func TestInitializeLineIntegrationRecoversClaimedNotification(t *testing.T) {
	db, _ := sql.Open("sqlite3", ":memory:")
	defer db.Close()
	InitializeLineIntegration(db)
	if err := EnqueueMaintenanceStatusNotification(db, 7, "event", "line-one", "103", "ไฟดับ", "กำลังซ่อม"); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(`UPDATE line_notification_outbox SET status = 'processing'`); err != nil {
		t.Fatal(err)
	}

	InitializeLineIntegration(db)
	var status string
	if err := db.QueryRow(`SELECT status FROM line_notification_outbox WHERE event_key = 'event'`).Scan(&status); err != nil {
		t.Fatal(err)
	}
	if status != "pending" {
		t.Fatalf("status = %q, want pending", status)
	}
}
