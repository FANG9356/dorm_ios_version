package utils

import (
	"bytes"
	"encoding/json"
	"fmt"
	"image"
	_ "image/jpeg"
	_ "image/png"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/qrcode"
)

type SlipOkResponse struct {
	Success bool `json:"success"`
	Code    int  `json:"code"`
	Message string `json:"message"`
	Data    struct {
		Success  bool    `json:"success"`
		Amount   float64 `json:"amount"`
		Receiver struct {
			Proxy struct {
				Value *string `json:"value"`
			} `json:"proxy"`
			Account struct {
				Value *string `json:"value"`
			} `json:"account"`
		} `json:"receiver"`
	} `json:"data"`
}

// VerifySlip checks if the uploaded slip is valid and matches the expected amount.
// It uses SlipOK API if EASYSLIP_API_KEY is set, otherwise falls back to a Mock Verification (decodes QR locally).
func VerifySlip(filePath string, expectedAmount float64, expectedReceiver string) (isValid bool, reason string, payload string) {
	file, err := os.Open(filePath)
	if err != nil {
		return false, "Could not open slip image", ""
	}
	defer file.Close()

	// Extract QR Payload to prevent Replay Attacks
	img, _, err := image.Decode(file)
	if err == nil {
		bmp, err := gozxing.NewBinaryBitmapFromImage(img)
		if err == nil {
			qrReader := qrcode.NewQRCodeReader()
			result, err := qrReader.Decode(bmp, nil)
			if err == nil {
				payload = result.GetText()
			}
		}
	}
	file.Seek(0, 0) // Reset file pointer

	// Fail closed if no QR code is found on the slip (Replay protection requires QR)
	if payload == "" {
		return false, "ไม่พบ QR Code บนสลิป หรือสลิปไม่ชัดเจน", ""
	}

	apiKey := os.Getenv("EASYSLIP_API_KEY")
	apiUrl := os.Getenv("EASYSLIP_API")

	if apiKey != "" && apiUrl != "" {
		v, r := verifyWithSlipOK(file, apiUrl, apiKey, expectedAmount, expectedReceiver)
		return v, r, payload
	}

	v, r := verifyMock(file, expectedAmount, payload, expectedReceiver)
	return v, r, payload
}

func verifyWithSlipOK(file *os.File, apiUrl, apiKey string, expectedAmount float64, expectedReceiver string) (bool, string) {
	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)

	part, err := writer.CreateFormFile("files", "slip.jpg")
	if err != nil {
		return false, "Internal error preparing API request"
	}

	_, err = io.Copy(part, file)
	if err != nil {
		return false, "Internal error copying file"
	}
	_ = writer.WriteField("log", "true")
	writer.Close()

	req, err := http.NewRequest("POST", apiUrl, body)
	if err != nil {
		return false, "Internal error creating request"
	}
	req.Header.Set("x-authorization", apiKey)
	req.Header.Set("Content-Type", writer.FormDataContentType())

	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return false, "API request failed"
	}
	defer resp.Body.Close()

	var result SlipOkResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return false, "Invalid API response"
	}

	// 400 Bad Request or API business logic failure
	if !result.Success {
		if result.Message != "" {
			return false, fmt.Sprintf("ตรวจสอบสลิปไม่ผ่าน: %s", result.Message)
		}
		return false, "สลิปไม่ถูกต้อง หรือไม่สามารถตรวจสอบได้"
	}

	if !result.Data.Success {
		return false, "ตรวจสอบสลิปไม่ผ่าน"
	}

	// Check amount
	if result.Data.Amount < expectedAmount-0.01 || result.Data.Amount > expectedAmount+0.01 {
		return false, fmt.Sprintf("ยอดเงินในสลิป (%.2f) ไม่ตรงกับยอดที่เรียกเก็บ (%.2f)", result.Data.Amount, expectedAmount)
	}

	// Check receiver if expectedReceiver is provided
	if expectedReceiver != "" {
		var accountStr string
		if result.Data.Receiver.Proxy.Value != nil {
			accountStr = strings.ReplaceAll(*result.Data.Receiver.Proxy.Value, "-", "")
		} else if result.Data.Receiver.Account.Value != nil {
			accountStr = strings.ReplaceAll(*result.Data.Receiver.Account.Value, "-", "")
		}
		
		accountStr = strings.ReplaceAll(accountStr, "x", "")
		accountStr = strings.ReplaceAll(accountStr, "X", "")

		if len(accountStr) >= 4 {
			// support format like "0812345678_1234567890" or "0812345678/1234567890"
			parts := strings.FieldsFunc(expectedReceiver, func(r rune) bool {
				return r == '_' || r == '/' || r == '|' || r == ' '
			})
			
			matched := false
			for _, p := range parts {
				expectedStr := strings.ReplaceAll(p, "-", "")
				if len(expectedStr) >= 4 && strings.HasSuffix(accountStr, expectedStr[len(expectedStr)-4:]) {
					matched = true
					break
				}
			}
			
			if !matched {
				return false, "ชื่อหรือบัญชีผู้รับโอนเงินไม่ถูกต้อง กรุณาโอนเงินเข้าบัญชีหอพักเท่านั้น"
			}
		}
	}

	return true, "Verified automatically via API"
}

func verifyMock(file *os.File, expectedAmount float64, payload string, expectedReceiver string) (bool, string) {
	// Fallback to basic QR code decoding if OCR bot is down
	if strings.Contains(payload, "00410006000001") || len(payload) > 20 {
		return false, "พบ QR Code แต่ไม่สามารถตรวจสอบยอดเงินอัตโนมัติได้ กรุณารอแอดมินยืนยัน"
	}
	return false, "QR code is not a valid transfer slip."
}
