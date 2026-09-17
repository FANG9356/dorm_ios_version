package handlers

import (
	"database/sql"
	"fmt"
	"log"
	"strings"
	"sync"
	"time"
)

var lineNotificationWorkerMu sync.Mutex

// EnqueueMaintenanceStatusNotification persists the intent before delivery.
// eventKey makes a retried snapshot idempotent while still allowing a later
// status transition for the same maintenance item to generate a new message.
func EnqueueMaintenanceStatusNotification(db *sql.DB, accountID int, notification maintenanceStatusNotification) error {
	notification.EventKey = strings.TrimSpace(notification.EventKey)
	notification.LineUserID = strings.TrimSpace(notification.LineUserID)
	if notification.EventKey == "" || notification.LineUserID == "" {
		return fmt.Errorf("missing notification identity")
	}
	now := time.Now().UTC().Format(time.RFC3339Nano)
	_, err := db.Exec(`INSERT INTO line_notification_outbox
		(event_key, account_id, line_user_id, room_number, issue, maintenance_status,
		 cost, reported_at, resolved_at, payment_method, maintenance_updated_at,
		 status, next_attempt_at, created_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?)
		ON CONFLICT(event_key) DO NOTHING`,
		notification.EventKey, accountID, notification.LineUserID, notification.RoomNumber,
		notification.Issue, notification.Status, notification.Cost, notification.ReportedAt,
		notification.ResolvedAt, notification.PaymentMethod, notification.LastUpdated, now, now)
	return err
}

// StartLineNotificationWorker retries transient LINE delivery failures. The
// immediate call handles normal updates quickly; the ticker recovers outages.
func StartLineNotificationWorker(db *sql.DB) {
	go func() {
		ProcessPendingLineNotifications(db)
		ticker := time.NewTicker(30 * time.Second)
		defer ticker.Stop()
		for range ticker.C {
			ProcessPendingLineNotifications(db)
		}
	}()
}

func ProcessPendingLineNotifications(db *sql.DB) {
	processPendingLineNotifications(db, sendMaintenanceStatusFlexMessage)
}

func processPendingLineNotifications(db *sql.DB, sender func(notification maintenanceStatusNotification) error) {
	lineNotificationWorkerMu.Lock()
	defer lineNotificationWorkerMu.Unlock()

	for processed := 0; processed < 20; processed++ {
		var id int64
		var notification maintenanceStatusNotification
		now := time.Now().UTC().Format(time.RFC3339Nano)
		err := db.QueryRow(`SELECT id, event_key, line_user_id, room_number, issue, maintenance_status,
			cost, reported_at, resolved_at, payment_method, maintenance_updated_at
			FROM line_notification_outbox
			WHERE status = 'pending' AND next_attempt_at <= ?
			ORDER BY id LIMIT 1`, now).Scan(
			&id, &notification.EventKey, &notification.LineUserID, &notification.RoomNumber,
			&notification.Issue, &notification.Status, &notification.Cost, &notification.ReportedAt,
			&notification.ResolvedAt, &notification.PaymentMethod, &notification.LastUpdated,
		)
		if err == sql.ErrNoRows {
			return
		}
		if err != nil {
			log.Printf("LINE notification outbox read failed: %v", err)
			return
		}
		result, err := db.Exec(`UPDATE line_notification_outbox SET status = 'processing'
			WHERE id = ? AND status = 'pending'`, id)
		if err != nil {
			log.Printf("LINE notification outbox claim failed: %v", err)
			return
		}
		claimed, _ := result.RowsAffected()
		if claimed == 0 {
			continue
		}

		err = sender(notification)
		if err == nil {
			_, updateErr := db.Exec(`UPDATE line_notification_outbox
				SET status = 'sent', sent_at = ?, last_error = '' WHERE id = ?`, now, id)
			if updateErr != nil {
				log.Printf("LINE notification outbox completion failed: %v", updateErr)
			}
			continue
		}

		var attempts int
		_ = db.QueryRow(`SELECT attempts FROM line_notification_outbox WHERE id = ?`, id).Scan(&attempts)
		attempts++
		delayMinutes := 1 << min(attempts-1, 6)
		nextAttempt := time.Now().UTC().Add(time.Duration(delayMinutes) * time.Minute).Format(time.RFC3339Nano)
		newStatus := "pending"
		if attempts >= 8 {
			newStatus = "failed"
		}
		_, updateErr := db.Exec(`UPDATE line_notification_outbox
			SET status = ?, attempts = ?, next_attempt_at = ?, last_error = ? WHERE id = ?`,
			newStatus, attempts, nextAttempt, err.Error(), id)
		if updateErr != nil {
			log.Printf("LINE notification outbox retry update failed: %v", updateErr)
		}
		log.Printf("LINE maintenance notification delivery failed (outbox_id=%d attempt=%d): %v", id, attempts, err)
	}
}
