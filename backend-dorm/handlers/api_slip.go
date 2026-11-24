package handlers

import (
	"database/sql"
	"log"
)

// VerifySlipMock is disabled in production builds (fail-closed) so slips can
// never be auto-approved without real provider verification.
func VerifySlipMock(_ *sql.DB, paymentID int, _ string, isMaintenance bool) {
	log.Printf("[Security] VerifySlipMock disabled (fail-closed): paymentID=%d isMaintenance=%v", paymentID, isMaintenance)
}
