package utils

import (
	"fmt"
	"strings"

	"github.com/sigurn/crc16"
)

// GeneratePromptPayPayload generates an EMVCo standard string for PromptPay.
// targetID can be a phone number (10 digits starting with 0) or a National/Tax ID (13 digits).
func GeneratePromptPayPayload(targetID string, amount float64) string {
	// Remove any dashes or spaces
	targetID = strings.ReplaceAll(targetID, "-", "")
	targetID = strings.ReplaceAll(targetID, " ", "")

	if targetID == "" {
		return ""
	}

	var subTag string
	if len(targetID) == 10 && strings.HasPrefix(targetID, "0") {
		// Phone Number format: 0066 + 9 digits
		formattedPhone := "0066" + targetID[1:]
		subTag = fmt.Sprintf("01%02d%s", len(formattedPhone), formattedPhone)
	} else if len(targetID) >= 13 {
		// National ID / Tax ID format
		subTag = fmt.Sprintf("02%02d%s", len(targetID), targetID)
	} else {
		// Fallback to phone number format if unknown
		subTag = fmt.Sprintf("01%02d%s", len(targetID), targetID)
	}

	// Tag 29: Merchant Account Information
	subTag00 := "0016A000000677010111" // Application ID for PromptPay
	tag29Val := subTag00 + subTag
	tag29 := fmt.Sprintf("29%02d%s", len(tag29Val), tag29Val)

	// Tag 54: Transaction Amount
	amountStr := fmt.Sprintf("%.2f", amount)
	tag54 := fmt.Sprintf("54%02d%s", len(amountStr), amountStr)

	// Build the payload string before CRC
	// 00 = Payload Format Indicator (01)
	// 01 = Point of Initiation Method (12 = Static/Dynamic without amount, but we include amount anyway. 11 = Dynamic)
	// Let's use 12 for PromptPay standard.
	// 58 = Country Code (TH)
	// 53 = Currency Code (764 for THB)
	payload := "000201010212" + tag29 + "5802TH5303764" + tag54 + "6304"

	// Calculate CRC16-CCITT
	table := crc16.MakeTable(crc16.CRC16_CCITT_FALSE)
	crc := crc16.Checksum([]byte(payload), table)

	// Append CRC (4 hex characters)
	return fmt.Sprintf("%s%04X", payload, crc)
}
