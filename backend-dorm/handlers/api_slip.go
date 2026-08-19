package handlers

import (
	"database/sql"
	"fmt"
	"time"
)

// VerifySlipMock simulates calling a 3rd party slip verification API (e.g. SlipOK)
func VerifySlipMock(db *sql.DB, paymentID int, slipPath string, isMaintenance bool) {
	// Simulate API delay
	time.Sleep(3 * time.Second)

	// Mock Logic: We assume the slip is valid for now.
	// In reality, we'd make an HTTP POST to SlipOK with the image.
	// If SlipOK returns success and amount matches, we approve.

	isValid := true // Mocking a successful validation

	if isValid {
		if !isMaintenance {
			// Update payment to paid
			db.Exec("UPDATE payments SET payment_status = 'paid' WHERE payment_id = ?", paymentID)
			
			// Find user to notify
			var lineUserID, roomNumber string
			var amount float64
			err := db.QueryRow(`
				SELECT u.line_user_id, p.room_number, p.amount 
				FROM payments p 
				JOIN users u ON p.user_id = u.id 
				WHERE p.payment_id = ?`, paymentID).Scan(&lineUserID, &roomNumber, &amount)
			
			if err == nil && lineUserID != "" {
				msg := fmt.Sprintf("✅ ระบบตรวจสอบสลิปอัตโนมัติ: ยืนยันสลิปสำเร็จ! ชำระเงินค่าเช่าห้อง %s ยอด %.2f บาท เรียบร้อยแล้วค่ะ ขอบคุณค่ะ", roomNumber, amount)
				PushLineMessage(lineUserID, msg)
			}
			
			db.Exec("INSERT INTO system_logs (action_type, details, timestamp) VALUES (?, ?, ?)", 
				"Auto Slip Verified", fmt.Sprintf("Slip for Payment ID %d verified automatically", paymentID), time.Now().Format("2006-01-02 15:04:05"))
				
		} else {
			// Update maintenance to paid
			db.Exec("UPDATE maintenances SET status = 'เสร็จสิ้น' WHERE id = ?", paymentID)
			
			// Find user to notify
			var roomNumber string
			var cost float64
			err := db.QueryRow("SELECT room_number, cost FROM maintenances WHERE id = ?", paymentID).Scan(&roomNumber, &cost)
			
			var lineUserID string
			if err == nil {
				db.QueryRow("SELECT line_user_id FROM users WHERE room_number = ?", roomNumber).Scan(&lineUserID)
				if lineUserID != "" {
					msg := fmt.Sprintf("✅ ระบบตรวจสอบสลิปอัตโนมัติ: ยืนยันสลิปค่าซ่อมแซมสำเร็จ! ยอด %.2f บาท เรียบร้อยแล้วค่ะ", cost)
					PushLineMessage(lineUserID, msg)
				}
			}
			
			db.Exec("INSERT INTO system_logs (action_type, details, timestamp) VALUES (?, ?, ?)", 
				"Auto Slip Verified", fmt.Sprintf("Slip for Maintenance ID %d verified automatically", paymentID), time.Now().Format("2006-01-02 15:04:05"))
		}
	} else {
		// If fake or duplicate
		if !isMaintenance {
			db.Exec("UPDATE payments SET payment_status = 'pending' WHERE payment_id = ?", paymentID)
			// Notify failure...
		} else {
			db.Exec("UPDATE maintenances SET status = 'รอตรวจสอบชำระเงิน' WHERE id = ?", paymentID)
		}
	}
}
