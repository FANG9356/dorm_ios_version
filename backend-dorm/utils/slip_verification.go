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
	"path/filepath"
	"strings"
	"time"

	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/qrcode"
)

type EasySlipResponse struct {
	Status int `json:"status"`
	Data   struct {
		Payload string `json:"payload"`
		Amount  struct {
			Amount float64 `json:"amount"`
		} `json:"amount"`
		Receiver struct {
			Proxy struct {
				Account string `json:"account"`
			} `json:"proxy"`
		} `json:"receiver"`
	} `json:"data"`
	Message string `json:"message"`
}

// VerifySlip checks if the uploaded slip is valid and matches the expected amount.
// It uses EasySlip API if EASYSLIP_TOKEN is set, otherwise falls back to a Mock Verification (decodes QR locally).
func VerifySlip(filePath string, expectedAmount float64) (isValid bool, reason string, payload string) {
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

	token := os.Getenv("EASYSLIP_TOKEN")
	if token != "" {
		v, r := verifyWithEasySlip(file, token, expectedAmount)
		return v, r, payload
	}

	v, r := verifyMock(file, expectedAmount, payload)
	return v, r, payload
}

func verifyWithEasySlip(file *os.File, token string, expectedAmount float64) (bool, string) {
	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)

	part, err := writer.CreateFormFile("file", "slip.jpg")
	if err != nil {
		return false, "Internal error preparing API request"
	}

	_, err = io.Copy(part, file)
	if err != nil {
		return false, "Internal error copying file"
	}
	writer.Close()

	req, err := http.NewRequest("POST", "https://developer.easyslip.com/api/v1/verify", body)
	if err != nil {
		return false, "Internal error creating request"
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", writer.FormDataContentType())

	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return false, "API request failed"
	}
	defer resp.Body.Close()

	var result EasySlipResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return false, "Invalid API response"
	}

	if result.Status != 200 {
		if result.Message != "" {
			return false, fmt.Sprintf("Slip verification failed: %s", result.Message)
		}
		return false, "Slip verification failed (Invalid slip)"
	}

	// Optionally check amount
	if result.Data.Amount.Amount < expectedAmount-0.01 { // Allow slight float tolerance
		return false, fmt.Sprintf("Amount mismatch. Expected %.2f but found %.2f", expectedAmount, result.Data.Amount.Amount)
	}

	return true, "Verified automatically via API"
}

func verifyMock(file *os.File, expectedAmount float64, payload string) (bool, string) {
	// First, try to call the Python OCR Bot
	absPath, err := filepath.Abs(file.Name())
	if err == nil {
		reqBody, _ := json.Marshal(map[string]interface{}{
			"filepath": absPath,
			"amount":   expectedAmount,
		})
		
		client := &http.Client{Timeout: 15 * time.Second}
		resp, err := client.Post("http://127.0.0.1:5001/verify", "application/json", bytes.NewBuffer(reqBody))
		
		if err == nil {
			defer resp.Body.Close()
			if resp.StatusCode == 200 {
				var ocrResult struct {
					Valid  bool   `json:"valid"`
					Reason string `json:"reason"`
				}
				if json.NewDecoder(resp.Body).Decode(&ocrResult) == nil {
					return ocrResult.Valid, ocrResult.Reason
				}
			}
		}
	}

	// Fallback to basic QR code decoding if OCR bot is down
	// We already extracted the payload in VerifySlip.
	
	if strings.Contains(payload, "00410006000001") || len(payload) > 20 {
		return false, "พบ QR Code แต่ไม่สามารถตรวจสอบยอดเงินอัตโนมัติได้ กรุณารอแอดมินยืนยัน"
	}

	return false, "QR code is not a valid transfer slip."
}
