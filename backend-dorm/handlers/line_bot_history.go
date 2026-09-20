package handlers

import (
	"database/sql"
	"fmt"
)

func loadPaymentHistoryLineInvoices(db *sql.DB, userID int, room, name string) ([]lineInvoiceFlexData, error) {
	rows, err := db.Query(`SELECT payment_id, COALESCE(month, ''), COALESCE(due_date, ''),
		COALESCE(last_updated, ''), COALESCE(payment_date, ''), COALESCE(NULLIF(payment_status, ''), 'pending'),
		COALESCE(installment_phase, 0), COALESCE(rent_fee, 0), COALESCE(deposit_fee, 0),
		COALESCE(water_fee, 0), COALESCE(electric_fee, 0), COALESCE(common_fee, 0),
		COALESCE(appliance_fee, 0), COALESCE(late_fee, 0), COALESCE(amount, 0), COALESCE(paid_amount, 0)
		FROM payments WHERE user_id = ?
		ORDER BY month DESC, installment_phase DESC, payment_id DESC LIMIT 5`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var invoices []lineInvoiceFlexData
	for rows.Next() {
		var paymentID int
		var invoice lineInvoiceFlexData
		if err := rows.Scan(
			&paymentID, &invoice.Period, &invoice.DueDate, &invoice.UpdatedAt, &invoice.PaymentDate,
			&invoice.Status, &invoice.Installment, &invoice.Rent, &invoice.Deposit, &invoice.Water,
			&invoice.Electric, &invoice.Common, &invoice.Appliance, &invoice.Late, &invoice.Total, &invoice.Paid,
		); err != nil {
			return nil, err
		}
		invoice.InvoiceNo = fmt.Sprintf("INV-%05d", paymentID)
		invoice.Room = room
		invoice.Name = name
		invoice.Other = invoice.Total - invoice.Rent - invoice.Deposit - invoice.Water - invoice.Electric - invoice.Common - invoice.Appliance - invoice.Late
		if invoice.Other < 0 {
			invoice.Other = 0
		}
		invoices = append(invoices, invoice)
	}
	return invoices, nil
}
