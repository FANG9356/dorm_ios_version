package handlers

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math"
	"net/http"
	"os"
	"strings"
	"time"
	"net/url"

	"dorm_os/utils"
)

var lineChannelAccessToken string
var lineChannelSecret string

func getLineToken() string {
	if lineChannelAccessToken == "" {
		lineChannelAccessToken = os.Getenv("LINE_CHANNEL_ACCESS_TOKEN")
	}
	return lineChannelAccessToken
}

func getLineSecret() string {
	if lineChannelSecret == "" {
		lineChannelSecret = os.Getenv("LINE_CHANNEL_SECRET")
	}
	return lineChannelSecret
}

// LineWebhookRequest represents the incoming webhook from LINE
type LineWebhookRequest struct {
	Events []struct {
		Type       string `json:"type"`
		ReplyToken string `json:"replyToken"`
		Source     struct {
			UserID string `json:"userId"`
		} `json:"source"`
		Message struct {
			ID   string `json:"id"`
			Type string `json:"type"`
			Text string `json:"text"`
		} `json:"message"`
		Postback struct {
			Data string `json:"data"`
		} `json:"postback"`
	} `json:"events"`
}

type lineInvoiceFlexData struct {
	InvoiceNo       string
	Name            string
	Room            string
	Period          string
	DueDate         string
	UpdatedAt       string
	PaymentDate     string
	Status          string
	Installment     int
	Rent            float64
	Deposit         float64
	Water           float64
	Electric        float64
	Common          float64
	Appliance       float64
	Late            float64
	Other           float64
	Total           float64
	Paid            float64
	AdditionalBills int
}

// verifySignature checks if the webhook request actually came from LINE
func verifySignature(body []byte, signature, secret string) bool {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(body)
	expectedSignature := base64.StdEncoding.EncodeToString(mac.Sum(nil))
	return hmac.Equal([]byte(signature), []byte(expectedSignature))
}

// HandleLineWebhook handles POST /api/webhook/line
func HandleLineWebhook(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		// Read body for signature verification
		bodyBytes, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "Error reading body", http.StatusBadRequest)
			return
		}

		// Verify signature
		secret := getLineSecret()
		if secret == "" {
			http.Error(w, "LINE integration is not configured", http.StatusServiceUnavailable)
			return
		}
		signature := r.Header.Get("X-Line-Signature")
		if !verifySignature(bodyBytes, signature, secret) {
			http.Error(w, "Invalid signature", http.StatusUnauthorized)
			return
		}

		// Restore body for json decoding
		r.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))

		var req LineWebhookRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Bad request", http.StatusBadRequest)
			return
		}

		for _, event := range req.Events {
			lineUserID := event.Source.UserID
			if lineUserID == "" {
				continue
			}

			if event.Type == "message" {
				tenantDB, accountID, _, linkErr := resolveLineTenantDB(db, lineUserID)
				if linkErr != nil {
					replyToLine(event.ReplyToken, "บัญชี LINE นี้ยังไม่ได้เชื่อมกับลูกบ้านในระบบใหม่ กรุณากดปุ่ม 'ผูกบัญชี' ที่เมนูด้านล่างแล้วเลือกห้องอีกครั้งค่ะ")
					continue
				}
				if event.Message.Type == "text" {
					scheme := "http://"
					if r.TLS != nil || r.Header.Get("X-Forwarded-Proto") == "https" {
						scheme = "https://"
					}
					serverURL := scheme + r.Host
					handleTextMessage(db, tenantDB, accountID, event.ReplyToken, lineUserID, event.Message.Text, serverURL)
				} else if event.Message.Type == "image" {
					handleImageMessage(db, tenantDB, accountID, event.ReplyToken, lineUserID, event.Message.ID)
				}
			} else if event.Type == "postback" {
				tenantDB, accountID, _, linkErr := resolveLineTenantDB(db, lineUserID)
				if linkErr != nil {
					replyToLine(event.ReplyToken, "กรุณาผูกบัญชี LINE กับห้องพักในระบบใหม่ก่อนทำรายการค่ะ")
					continue
				}
				handlePostbackEvent(db, tenantDB, accountID, event.ReplyToken, lineUserID, event.Postback.Data)
			} else if event.Type == "follow" {
				welcomeMsg := "สวัสดีค่ะ! ยินดีต้อนรับสู่บริการหอพัก DormiNet นะคะ\n\nหากคุณเป็นลูกบ้านของเรา กรุณากดปุ่ม 'ผูกบัญชี' ที่เมนูด้านล่าง เพื่อรับข้อมูลบิลค่าเช่าและการแจ้งเตือนต่างๆ ได้เลยค่ะ"
				replyToLine(event.ReplyToken, welcomeMsg)
			}
		}

		w.WriteHeader(http.StatusOK)
	}
}

func handleTextMessage(master, db *sql.DB, accountID int, replyToken, lineUserID, text, serverURL string) {
	text = strings.TrimSpace(text)

	// Command: ผูกบัญชี [เลขบัตรประชาชน] [เบอร์โทร] (Deprecated for security reasons)
	if strings.HasPrefix(text, "ผูกบัญชี") {
		replyToLine(replyToken, "เพื่อความปลอดภัยสูงสุด ระบบยกเลิกการผูกบัญชีผ่านการพิมพ์แล้วค่ะ\n\nรบกวนลูกบ้านกดที่ปุ่ม 'ผูกบัญชี' ที่เมนูหลักด้านล่าง เพื่อดำเนินการแทนนะคะ")
		return
	}

	if text == "การเงิน" {
		var userID int
		var roomNumber, fullName string
		err := db.QueryRow("SELECT user_id, room_number, full_name FROM users WHERE line_user_id = ?", lineUserID).
			Scan(&userID, &roomNumber, &fullName)
		if err != nil {
			replyToLine(replyToken, "คุณยังไม่ได้ผูกบัญชีห้องพักค่ะ โปรดกดปุ่ม 'ผูกบัญชี' จากเมนูด้านล่าง")
			return
		}

		invoice, err := loadLatestOutstandingLineInvoice(db, userID, roomNumber, fullName)
		if err == nil {
			if invoice.Status == "pending" || invoice.Status == "partial" {
				db.Exec("UPDATE users SET bot_state = 'slip' WHERE line_user_id = ?", lineUserID)
			}
			replyToLineWithFlexMessage(replyToken, lineInvoiceAltText(invoice), buildLineInvoiceBubble(invoice))
		} else if err == sql.ErrNoRows {
			replyToLine(replyToken, fmt.Sprintf("ห้อง %s ไม่มียอดค้างชำระในระบบขณะนี้ค่ะ ขอบคุณค่ะ", roomNumber))
		} else {
			replyToLine(replyToken, "อ่านข้อมูลใบแจ้งหนี้ไม่สำเร็จ กรุณาลองใหม่อีกครั้งค่ะ")
		}
		return
	}

	if text == "ติดต่อ" || text == "ติดต่อนิติบุคคล" {
		replyToLineWithFlexMessage(replyToken, "ช่องทางการติดต่อ", buildContactMenuFlexMessage())
		return
	}
	
	if text == "wifi" || text == "ไวไฟ" || text == "อินเทอร์เน็ต" || text == "รหัสไวไฟ" {
		replyToLineWithFlexMessage(replyToken, "รหัสอินเทอร์เน็ต (Wi-Fi)", buildWifiFlexMessage())
		return
	}

	if text == "บริการ" || text == "บริการรอบหอพัก" {
		replyToLineWithFlexMessage(replyToken, "บริการรอบหอพัก", buildServicesFlexMessage())
		return
	}
	
	if text == "ฝากข้อความถึงแอดมิน" {
		replyToLine(replyToken, "สามารถพิมพ์ข้อความหรือคำถามทิ้งไว้ได้เลยค่ะ แอดมินจะเข้ามาตอบกลับให้เร็วที่สุดนะคะ")
		return
	}

	var roomNumber, botState string
	err := db.QueryRow("SELECT room_number, bot_state FROM users WHERE line_user_id = ?", lineUserID).Scan(&roomNumber, &botState)
	if err != nil {
		roomNumber = ""
		botState = "none"
	}

	if text == "แจ้งซ่อม" {
		if roomNumber == "" {
			replyToLine(replyToken, "คุณยังไม่ได้ผูกบัญชีห้องพักค่ะ โปรดกดปุ่ม 'ผูกบัญชี' จากเมนูด้านล่าง")
			return
		}
		db.Exec("UPDATE users SET bot_state = 'maintenance' WHERE line_user_id = ?", lineUserID)
		replyToLine(replyToken, "กรุณาแจ้งปัญหาที่พบ ลูกบ้านสามารถพิมพ์รายละเอียด หรือส่งภาพปัญหาเข้ามาได้เลยค่ะ")
		return
	}

	if botState == "maintenance" {
		if text != "เมนู" && text != "การเงิน" && text != "แจ้งซ่อม" && !strings.HasPrefix(text, "ผูกบัญชี") {
			issue := strings.TrimSpace(text)
			if issue == "" {
				replyToLine(replyToken, "กรุณาระบุรายละเอียดสิ่งที่ต้องการซ่อมด้วยค่ะ")
				return
			}

			now := time.Now()
			_, err = db.Exec("INSERT INTO maintenances (room_number, issue, status, reported_at, last_updated) VALUES (?, ?, 'รอดำเนินการ', ?, ?)", roomNumber, issue, now.Format("2006-01-02 15:04:05"), now.UTC().Format(time.RFC3339Nano))
			if err != nil {
				replyToLine(replyToken, "เกิดข้อผิดพลาดในการบันทึกข้อมูล กรุณาลองใหม่อีกครั้งค่ะ")
				return
			}
			publishLineChanges(master, db, accountID)

			db.Exec("UPDATE users SET bot_state = 'maintenance_wait_image' WHERE line_user_id = ?", lineUserID)
			replyToLineWithQuickReply(replyToken, "บันทึกรายละเอียดเรียบร้อยค่ะ หากมีรูปภาพปัญหาประกอบสามารถส่งรูปมาได้เลยนะคะ (หากไม่มี กด 'ข้าม')", []string{"ข้าม"})
			return
		}
	} else if botState == "maintenance_wait_image" {
		if text == "ข้าม" {
			db.Exec("UPDATE users SET bot_state = 'none' WHERE line_user_id = ?", lineUserID)
			replyToLine(replyToken, "รับเรื่องแจ้งซ่อมเรียบร้อยแล้วค่ะ แอดมินจะรีบตรวจสอบและส่งช่างเข้าไปดำเนินการให้นะคะ")
			return
		} else if text != "เมนู" && text != "การเงิน" && text != "แจ้งซ่อม" && !strings.HasPrefix(text, "ผูกบัญชี") {
			db.Exec("UPDATE users SET bot_state = 'none' WHERE line_user_id = ?", lineUserID)
			replyToLine(replyToken, "รับเรื่องแจ้งซ่อมเรียบร้อยแล้วค่ะ แอดมินจะรีบตรวจสอบและส่งช่างเข้าไปดำเนินการให้นะคะ")
			return
		}
	} else if botState == "maintenance_wait_text" {
		if text != "เมนู" && text != "การเงิน" && text != "แจ้งซ่อม" && !strings.HasPrefix(text, "ผูกบัญชี") {
			if text != "ข้าม" {
				db.Exec("UPDATE maintenances SET issue = ?, last_updated = ? WHERE id = (SELECT id FROM maintenances WHERE room_number = ? AND status = 'รอดำเนินการ' ORDER BY id DESC LIMIT 1)", strings.TrimSpace(text), time.Now().UTC().Format(time.RFC3339Nano), roomNumber)
				publishLineChanges(master, db, accountID)
				replyToLine(replyToken, "บันทึกรายละเอียดเพิ่มเติมเรียบร้อยค่ะ แอดมินจะรีบตรวจสอบและดำเนินการให้นะคะ")
			} else {
				db.Exec("UPDATE maintenances SET issue = 'แจ้งซ่อมผ่านรูปภาพ', last_updated = ? WHERE id = (SELECT id FROM maintenances WHERE room_number = ? AND status = 'รอดำเนินการ' ORDER BY id DESC LIMIT 1)", time.Now().UTC().Format(time.RFC3339Nano), roomNumber)
				publishLineChanges(master, db, accountID)
				replyToLine(replyToken, "รับเรื่องแจ้งซ่อมเรียบร้อยแล้วค่ะ แอดมินจะรีบตรวจสอบและส่งช่างเข้าไปดำเนินการให้นะคะ")
			}
			db.Exec("UPDATE users SET bot_state = 'none' WHERE line_user_id = ?", lineUserID)
			return
		}
	}

	if !strings.HasPrefix(text, "ผูกบัญชี") && text != "เมนู" && text != "การเงิน" && text != "แจ้งซ่อม" {
		db.Exec("UPDATE users SET bot_state = 'none' WHERE line_user_id = ?", lineUserID)
	}

	replyToLine(replyToken, "สวัสดีค่ะ\nยินดีต้อนรับสู่บริการผู้ช่วยหอพัก\nคุณสามารถกดเลือกเมนูด้านล่างเพื่อทำรายการได้เลยค่ะ")
}

func handleImageMessage(master, db *sql.DB, accountID int, replyToken, lineUserID, messageID string) {
	var roomNumber, botState string
	var userID int
	err := db.QueryRow("SELECT user_id, room_number, bot_state FROM users WHERE line_user_id = ?", lineUserID).Scan(&userID, &roomNumber, &botState)
	if err != nil {
		replyToLine(replyToken, "คุณยังไม่ได้ผูกบัญชีห้องพักค่ะ โปรดกดปุ่ม 'ผูกบัญชี' จากเมนูด้านล่าง")
		return
	}

	if botState == "none" || botState == "" {
		var rentID int
		var rentAmount float64
		errRent := db.QueryRow("SELECT payment_id, amount FROM payments WHERE user_id = ? AND payment_status IN ('pending', 'partial') ORDER BY month DESC, installment_phase DESC, payment_id DESC LIMIT 1", userID).Scan(&rentID, &rentAmount)

		var maintID int
		var maintAmount float64
		errMaint := db.QueryRow("SELECT id, cost FROM maintenances WHERE room_number = ? AND status = 'รอตรวจสอบชำระเงิน' AND cost > 0 ORDER BY id DESC LIMIT 1", roomNumber).Scan(&maintID, &maintAmount)

		if errRent == nil && errMaint != nil {
			botState = "slip"
		} else if errMaint == nil && errRent != nil {
			botState = fmt.Sprintf("pay_maint_%d", maintID)
		} else if errRent == nil && errMaint == nil {
			replyToLine(replyToken, "คุณมียอดค้างชำระทั้งค่าเช่าและค่าแจ้งซ่อม กรุณาเลือกทำรายการผ่านเมนู 'การเงิน' ด้านล่างเพื่อให้ระบบบันทึกยอดได้ถูกต้องค่ะ")
			return
		}
	}

	// Bug Fix: ถ้า bot_state เป็น "maintenance" แต่มีเคสซ่อมที่รอชำระเงินอยู่
	// หมายความว่าผู้ใช้อาจตั้งใจส่งสลิปชำระค่าซ่อม ไม่ใช่แจ้งซ่อมใหม่
	// เปลี่ยน bot_state เป็น pay_maint_* เพื่อให้รับสลิปได้อย่างถูกต้อง
	if botState == "maintenance" {
		var pendingMaintID int
		errPending := db.QueryRow(
			"SELECT id FROM maintenances WHERE room_number = ? AND status = 'รอตรวจสอบชำระเงิน' AND cost > 0 ORDER BY id DESC LIMIT 1",
			roomNumber).Scan(&pendingMaintID)
		if errPending == nil {
			// มีเคสรอชำระอยู่ — เปลี่ยนเป็นโหมดชำระค่าซ่อมแทน
			db.Exec("UPDATE users SET bot_state = ? WHERE line_user_id = ?", fmt.Sprintf("pay_maint_%d", pendingMaintID), lineUserID)
			botState = fmt.Sprintf("pay_maint_%d", pendingMaintID)
		}
		// ถ้าไม่มีเคสรอชำระ ให้ดำเนินการแจ้งซ่อมปกติต่อไป
	}

	if botState != "slip" && botState != "maintenance" && botState != "maintenance_wait_image" && botState != "maintenance_wait_text" && !strings.HasPrefix(botState, "pay_maint_") {
		replyToLine(replyToken, "กรุณากดเลือกเมนู 'การเงิน' หรือ 'แจ้งซ่อม' ด้านล่างก่อนส่งรูปภาพนะคะ เพื่อให้ระบบจัดเก็บข้อมูลได้อย่างถูกต้องค่ะ")
		return
	}


	token := getLineToken()
	if token == "" {
		fmt.Println("[LINE] Token not configured")
		return
	}

	req, _ := http.NewRequest("GET", fmt.Sprintf("https://api-data.line.me/v2/bot/message/%s/content", messageID), nil)
	req.Header.Set("Authorization", "Bearer "+token)
	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil || resp.StatusCode != 200 {
		replyToLine(replyToken, "เกิดข้อผิดพลาดในการบันทึกรูปภาพ กรุณาลองใหม่อีกครั้งค่ะ")
		return
	}
	defer resp.Body.Close()

	newFileName := fmt.Sprintf("%d_%s_img_%s.jpg", time.Now().Unix(), roomNumber, messageID)
	filepath := "./uploads/" + newFileName
	outFile, err := os.Create(filepath)
	if err != nil {
		replyToLine(replyToken, "เกิดข้อผิดพลาดในระบบเซิร์ฟเวอร์")
		return
	}
	io.Copy(outFile, resp.Body)
	outFile.Close()

	if botState == "slip" {
		var paymentID int
		var amount float64
		err = db.QueryRow("SELECT payment_id, amount FROM payments WHERE user_id = ? AND payment_status IN ('pending', 'partial') ORDER BY month DESC, installment_phase DESC, payment_id DESC LIMIT 1", userID).Scan(&paymentID, &amount)
		if err != nil {
			replyToLine(replyToken, "คุณไม่มียอดค้างชำระในขณะนี้ หรือบิลได้รับการชำระเรียบร้อยแล้วค่ะ")
			db.Exec("UPDATE users SET bot_state = 'none' WHERE line_user_id = ?", lineUserID)
			return
		}

		isValid, verifyReason := utils.VerifySlip(filepath, amount)
		newStatus := "checking"
		var replyMessage string

		if isValid {
			newStatus = "paid"
			replyMessage = fmt.Sprintf("ยืนยันการชำระเงินเรียบร้อย ระบบตรวจสอบสลิปอัตโนมัติพบยอดเงิน %.2f บาทเข้าบัญชีแล้วค่ะ", amount)
		} else {
			replyMessage = fmt.Sprintf("ไม่สามารถตรวจสอบสลิปอัตโนมัติได้ (%s) ระบบได้รับสลิปแล้ว แอดมินจะตรวจสอบให้อีกครั้งนะคะ", verifyReason)
		}

		slipArrayJSON := fmt.Sprintf(`["%s"]`, newFileName)
		res, err := db.Exec("UPDATE payments SET payment_status = ?, slip_path = ?, slip_path_array = ?, payment_date = ?, last_updated = ? WHERE payment_id = ? AND payment_status != 'paid'", newStatus, newFileName, slipArrayJSON, time.Now().Format("2006-01-02"), time.Now().UTC().Format(time.RFC3339Nano), paymentID)
		if err != nil {
			replyToLine(replyToken, "เกิดข้อผิดพลาดในการอัปเดตข้อมูล")
			return
		}
		affected, _ := res.RowsAffected()
		if affected == 0 {
			replyToLine(replyToken, "บิลนี้ได้รับการชำระเรียบร้อยแล้ว หรือมีผู้อื่นกำลังทำรายการค่ะ")
			db.Exec("UPDATE users SET bot_state = 'none' WHERE line_user_id = ?", lineUserID)
			return
		}
		
		logAction := "Auto Slip Check Failed"
		if isValid {
			logAction = "Auto Slip Verified"
		}
		db.Exec("INSERT INTO system_logs (action_type, details, timestamp) VALUES (?, ?, ?)", logAction, fmt.Sprintf("Slip for Room %s: %s", roomNumber, verifyReason), time.Now().Format("2006-01-02 15:04:05"))
		publishLineChanges(master, db, accountID)

		dateStr := time.Now().Format("02/01/2006 15:04")
		receiptNo := fmt.Sprintf("REC-%05d", paymentID)

		flexJSON := fmt.Sprintf(`{
			"type": "bubble",
			"header": { "type": "box", "layout": "vertical", "contents": [ { "type": "text", "text": "ใบเสร็จรับเงิน", "weight": "bold", "color": "#4F46E5", "size": "xl" }, { "type": "text", "text": "RECEIPT", "size": "sm", "color": "#818CF8", "margin": "sm" } ] },
			"body": {
				"type": "box", "layout": "vertical",
				"contents": [
					{
						"type": "box", "layout": "vertical", "margin": "md", "spacing": "sm",
						"contents": [
							{ "type": "box", "layout": "baseline", "spacing": "sm", "contents": [ {"type": "text", "text": "เลขที่", "color": "#aaaaaa", "size": "sm", "flex": 1}, {"type": "text", "text": "%s", "wrap": true, "color": "#666666", "size": "sm", "flex": 3} ] },
							{ "type": "box", "layout": "baseline", "spacing": "sm", "contents": [ {"type": "text", "text": "ห้อง", "color": "#aaaaaa", "size": "sm", "flex": 1}, {"type": "text", "text": "%s", "wrap": true, "color": "#666666", "size": "sm", "flex": 3} ] },
							{ "type": "box", "layout": "baseline", "spacing": "sm", "contents": [ {"type": "text", "text": "วันที่", "color": "#aaaaaa", "size": "sm", "flex": 1}, {"type": "text", "text": "%s", "wrap": true, "color": "#666666", "size": "sm", "flex": 3} ] }
						]
					},
					{ "type": "separator", "margin": "lg" },
					{
						"type": "box", "layout": "vertical", "margin": "lg",
						"contents": [
							{ "type": "box", "layout": "horizontal", "contents": [ {"type": "text", "text": "ยอดรับชำระ", "size": "md", "color": "#111111", "flex": 2, "weight": "bold"}, {"type": "text", "text": "%.2f บาท", "size": "md", "color": "#4F46E5", "align": "end", "flex": 2, "weight": "bold"} ] }
						]
					},
					{
						"type": "box", "layout": "vertical", "margin": "lg",
						"contents": [
							{ "type": "text", "text": "%s", "size": "xs", "color": "#888888", "align": "center", "wrap": true }
						]
					}
				]
			}
		}`, receiptNo, roomNumber, dateStr, amount, replyMessage)

		var contents map[string]interface{}
		json.Unmarshal([]byte(flexJSON), &contents)
		replyToLineWithFlexMessage(replyToken, replyMessage, contents)

		db.Exec("UPDATE users SET bot_state = 'none' WHERE line_user_id = ?", lineUserID)

	} else if botState == "maintenance" {
		now := time.Now()
		_, err = db.Exec("INSERT INTO maintenances (room_number, issue, status, reported_at, issue_image, last_updated) VALUES (?, ?, 'รอดำเนินการ', ?, ?, ?)", roomNumber, "รอรายละเอียดเพิ่มเติม", now.Format("2006-01-02 15:04:05"), "/uploads/"+newFileName, now.UTC().Format(time.RFC3339Nano))
		if err != nil {
			replyToLine(replyToken, "เกิดข้อผิดพลาดในการบันทึกข้อมูลแจ้งซ่อม กรุณาลองใหม่อีกครั้งค่ะ")
			return
		}
		publishLineChanges(master, db, accountID)
		replyToLineWithQuickReply(replyToken, "ได้รับรูปภาพแล้วค่ะ กรุณาพิมพ์รายละเอียดปัญหาเพิ่มเติม หรือส่งรูปเพิ่มเข้ามาได้เลยนะคะ (หากไม่มี กด 'ข้าม')", []string{"ข้าม"})
		db.Exec("UPDATE users SET bot_state = 'maintenance_wait_text' WHERE line_user_id = ?", lineUserID)
	} else if botState == "maintenance_wait_image" {
		var currentImages string
		db.QueryRow("SELECT issue_image FROM maintenances WHERE room_number = ? AND status = 'รอดำเนินการ' ORDER BY id DESC LIMIT 1", roomNumber).Scan(&currentImages)
		newImages := currentImages
		if newImages != "" {
			newImages += ","
		}
		newImages += "/uploads/" + newFileName

		_, err = db.Exec("UPDATE maintenances SET issue_image = ?, last_updated = ? WHERE id = (SELECT id FROM maintenances WHERE room_number = ? AND status = 'รอดำเนินการ' ORDER BY id DESC LIMIT 1)", newImages, time.Now().UTC().Format(time.RFC3339Nano), roomNumber)
		if err != nil {
			replyToLine(replyToken, "เกิดข้อผิดพลาดในการบันทึกรูปภาพ กรุณาลองใหม่อีกครั้งค่ะ")
			return
		}
		publishLineChanges(master, db, accountID)

		if currentImages == "" {
			// ส่งกลับเฉพาะรูปแรก เพื่อไม่ให้ส่งข้อความซ้ำซ้อนเมื่อลูกบ้านส่งหลายรูปพร้อมกัน
			replyToLineWithQuickReply(replyToken, "เพิ่มรูปภาพประกอบเรียบร้อยค่ะ (หากมีอีกสามารถส่งเพิ่มได้เลย หรือกด 'เสร็จสิ้น' เพื่อจบการแจ้งซ่อม)", []string{"เสร็จสิ้น"})
		}
	} else if botState == "maintenance_wait_text" {
		var currentImages string
		db.QueryRow("SELECT issue_image FROM maintenances WHERE room_number = ? AND status = 'รอดำเนินการ' ORDER BY id DESC LIMIT 1", roomNumber).Scan(&currentImages)
		newImages := currentImages
		if newImages != "" {
			newImages += ","
		}
		newImages += "/uploads/" + newFileName

		_, err = db.Exec("UPDATE maintenances SET issue_image = ?, last_updated = ? WHERE id = (SELECT id FROM maintenances WHERE room_number = ? AND status = 'รอดำเนินการ' ORDER BY id DESC LIMIT 1)", newImages, time.Now().UTC().Format(time.RFC3339Nano), roomNumber)
		publishLineChanges(master, db, accountID)

		if currentImages == "" {
			replyToLineWithQuickReply(replyToken, "เพิ่มรูปภาพประกอบเรียบร้อยค่ะ กรุณาพิมพ์รายละเอียดปัญหา หรือส่งรูปภาพเพิ่มเติมนะคะ (หากไม่มี กด 'ข้าม')", []string{"ข้าม"})
		}

	} else if strings.HasPrefix(botState, "pay_maint_") {
		maintID := strings.TrimPrefix(botState, "pay_maint_")

		var cost float64
		err = db.QueryRow(`SELECT m.cost FROM maintenances m
			JOIN users u ON u.room_number = m.room_number
			WHERE m.id = ? AND m.status = 'รอตรวจสอบชำระเงิน' AND m.cost > 0
			AND u.line_user_id = ? AND u.status IN ('กำลังพักอาศัย','จอง')
			LIMIT 1`, maintID, lineUserID).Scan(&cost)
		if err != nil || cost <= 0 {
			replyToLine(replyToken, "ไม่พบข้อมูลบิลค่าซ่อมแซมนี้ หรือบิลนี้ถูกยกเลิกไปแล้วค่ะ")
			db.Exec("UPDATE users SET bot_state = 'none' WHERE line_user_id = ?", lineUserID)
			return
		}

		isValid, verifyReason := utils.VerifySlip(filepath, cost)
		newStatus := "รอตรวจสอบชำระเงิน"
		var replyMsg string
		if isValid {
			newStatus = "รอตรวจสอบชำระเงิน"
			replyMsg = fmt.Sprintf("ระบบตรวจสอบสลิปอัตโนมัติ: ยืนยันการชำระเงินค่าซ่อมแซมสำเร็จ ยอด %.2f บาท เรียบร้อยแล้วค่ะ", cost)
		} else {
			replyMsg = fmt.Sprintf("ไม่สามารถตรวจสอบสลิปอัตโนมัติได้ (%s) ระบบได้รับสลิปค่าซ่อมแซมเรียบร้อยแล้ว แอดมินจะตรวจสอบและยืนยันให้อีกครั้งค่ะ", verifyReason)
		}

		_, err = db.Exec("UPDATE maintenances SET slip_path = ?, status = ?, last_updated = ? WHERE id = ?", newFileName, newStatus, time.Now().UTC().Format(time.RFC3339Nano), maintID)
		if err != nil {
			replyToLine(replyToken, "เกิดข้อผิดพลาดในการอัปเดตข้อมูล")
			return
		}
		
		logAction := "Auto Slip Check Failed"
		if isValid {
			logAction = "Auto Slip Verified"
		}
		db.Exec("INSERT INTO system_logs (action_type, details, timestamp) VALUES (?, ?, ?)", logAction, fmt.Sprintf("Maintenance Slip for Room %s: %s", roomNumber, verifyReason), time.Now().Format("2006-01-02 15:04:05"))
		publishLineChanges(master, db, accountID)

		db.Exec("UPDATE users SET bot_state = 'none' WHERE line_user_id = ?", lineUserID)

		if isValid {
			dateStr := time.Now().Format("02/01/2006 15:04")
			receiptNo := fmt.Sprintf("M-REC-%05s", maintID)
			
			flexJSON := fmt.Sprintf(`{
				"type": "bubble",
				"header": { "type": "box", "layout": "vertical", "contents": [ { "type": "text", "text": "ใบเสร็จรับเงิน (ค่าซ่อมแซม)", "weight": "bold", "color": "#4F46E5", "size": "xl" }, { "type": "text", "text": "MAINTENANCE RECEIPT", "size": "sm", "color": "#818CF8", "margin": "sm" } ] },
				"body": {
					"type": "box", "layout": "vertical",
					"contents": [
						{
							"type": "box", "layout": "vertical", "margin": "md", "spacing": "sm",
							"contents": [
								{ "type": "box", "layout": "baseline", "spacing": "sm", "contents": [ {"type": "text", "text": "เลขที่", "color": "#aaaaaa", "size": "sm", "flex": 1}, {"type": "text", "text": "%s", "wrap": true, "color": "#666666", "size": "sm", "flex": 3} ] },
								{ "type": "box", "layout": "baseline", "spacing": "sm", "contents": [ {"type": "text", "text": "ห้อง", "color": "#aaaaaa", "size": "sm", "flex": 1}, {"type": "text", "text": "%s", "wrap": true, "color": "#666666", "size": "sm", "flex": 3} ] },
								{ "type": "box", "layout": "baseline", "spacing": "sm", "contents": [ {"type": "text", "text": "วันที่", "color": "#aaaaaa", "size": "sm", "flex": 1}, {"type": "text", "text": "%s", "wrap": true, "color": "#666666", "size": "sm", "flex": 3} ] }
							]
						},
						{ "type": "separator", "margin": "lg" },
						{
							"type": "box", "layout": "vertical", "margin": "lg",
							"contents": [
								{ "type": "box", "layout": "horizontal", "contents": [ {"type": "text", "text": "ยอดรับชำระ", "size": "md", "color": "#111111", "flex": 2, "weight": "bold"}, {"type": "text", "text": "%.2f บาท", "size": "md", "color": "#4F46E5", "align": "end", "flex": 2, "weight": "bold"} ] }
							]
						},
						{
							"type": "box", "layout": "vertical", "margin": "lg",
							"contents": [
								{ "type": "text", "text": "%s", "size": "xs", "color": "#888888", "align": "center", "wrap": true }
							]
						}
					]
				}
			}`, receiptNo, roomNumber, dateStr, cost, replyMsg)
	
			var contents map[string]interface{}
			json.Unmarshal([]byte(flexJSON), &contents)
			replyToLineWithFlexMessage(replyToken, replyMsg, contents)
		} else {
			replyToLine(replyToken, replyMsg)
		}
	}
}

func publishLineChanges(master, tenantDB *sql.DB, accountID int) {
	if err := PublishLineTenantChanges(master, tenantDB, accountID); err != nil {
		log.Printf("[LINE] publish tenant changes for account %d failed: %v", accountID, err)
	}
}

func replyToLine(replyToken, text string) {
	token := getLineToken()
	if token == "" {
		return
	}

	url := "https://api.line.me/v2/bot/message/reply"
	body := map[string]interface{}{
		"replyToken": replyToken,
		"messages": []map[string]string{
			{"type": "text", "text": text},
		},
	}
	jsonBody, _ := json.Marshal(body)

	req, _ := http.NewRequest("POST", url, bytes.NewBuffer(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)

	client := &http.Client{Timeout: 10 * time.Second}
	client.Do(req)
}

// PushLineMessage sends a direct message to a user
func PushLineMessage(lineUserID, text string) {
	token := getLineToken()
	if token == "" || lineUserID == "" {
		return
	}

	url := "https://api.line.me/v2/bot/message/push"
	body := map[string]interface{}{
		"to": lineUserID,
		"messages": []map[string]string{
			{"type": "text", "text": text},
		},
	}
	jsonBody, _ := json.Marshal(body)

	req, _ := http.NewRequest("POST", url, bytes.NewBuffer(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)

	client := &http.Client{Timeout: 10 * time.Second}
	client.Do(req)
}

func replyToLineWithImage(replyToken, text, imageURL string) {
	token := getLineToken()
	if token == "" {
		return
	}

	url := "https://api.line.me/v2/bot/message/reply"
	messages := []map[string]interface{}{
		{
			"type": "text",
			"text": text,
		},
	}
	if imageURL != "" {
		messages = append(messages, map[string]interface{}{
			"type":               "image",
			"originalContentUrl": imageURL,
			"previewImageUrl":    imageURL,
		})
	}
	body := map[string]interface{}{
		"replyToken": replyToken,
		"messages":   messages,
	}
	jsonBody, _ := json.Marshal(body)

	req, _ := http.NewRequest("POST", url, bytes.NewBuffer(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)

	client := &http.Client{Timeout: 10 * time.Second}
	client.Do(req)
}

func replyToLineWithFlexMessage(replyToken, altText string, contents interface{}) {
	token := getLineToken()
	if token == "" {
		return
	}

	url := "https://api.line.me/v2/bot/message/reply"
	body := map[string]interface{}{
		"replyToken": replyToken,
		"messages": []map[string]interface{}{
			{
				"type":     "flex",
				"altText":  altText,
				"contents": contents,
			},
		},
	}
	jsonBody, _ := json.Marshal(body)

	req, _ := http.NewRequest("POST", url, bytes.NewBuffer(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		fmt.Println("Error sending flex message:", err)
		return
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		respBody, _ := io.ReadAll(resp.Body)
		fmt.Printf("LINE API Error (Flex): %s - %s\n", resp.Status, string(respBody))
	}
}

func replyToLineWithFlexAndText(replyToken, altText string, contents interface{}, followUpText string) {
	token := getLineToken()
	if token == "" {
		return
	}

	url := "https://api.line.me/v2/bot/message/reply"
	body := map[string]interface{}{
		"replyToken": replyToken,
		"messages": []map[string]interface{}{
			{
				"type":     "flex",
				"altText":  altText,
				"contents": contents,
			},
			{
				"type": "text",
				"text": followUpText,
			},
		},
	}
	jsonBody, _ := json.Marshal(body)

	req, _ := http.NewRequest("POST", url, bytes.NewBuffer(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)

	client := &http.Client{Timeout: 10 * time.Second}
	client.Do(req)
}

func loadLatestOutstandingLineInvoice(db *sql.DB, userID int, room, name string) (lineInvoiceFlexData, error) {
	var paymentID int
	var invoice lineInvoiceFlexData
	err := db.QueryRow(`SELECT payment_id, COALESCE(month, ''), COALESCE(due_date, ''),
		COALESCE(last_updated, ''), COALESCE(payment_date, ''), COALESCE(NULLIF(payment_status, ''), 'pending'),
		COALESCE(installment_phase, 0), COALESCE(rent_fee, 0), COALESCE(deposit_fee, 0),
		COALESCE(water_fee, 0), COALESCE(electric_fee, 0), COALESCE(common_fee, 0),
		COALESCE(appliance_fee, 0), COALESCE(late_fee, 0), COALESCE(amount, 0), COALESCE(paid_amount, 0)
		FROM payments WHERE user_id = ? AND COALESCE(payment_status, 'pending') != 'paid'
		AND amount > COALESCE(paid_amount, 0)
		ORDER BY month DESC, installment_phase DESC, payment_id DESC LIMIT 1`, userID).Scan(
		&paymentID, &invoice.Period, &invoice.DueDate, &invoice.UpdatedAt, &invoice.PaymentDate,
		&invoice.Status, &invoice.Installment, &invoice.Rent, &invoice.Deposit, &invoice.Water,
		&invoice.Electric, &invoice.Common, &invoice.Appliance, &invoice.Late, &invoice.Total, &invoice.Paid,
	)
	if err != nil {
		return lineInvoiceFlexData{}, err
	}
	invoice.InvoiceNo = fmt.Sprintf("INV-%05d", paymentID)
	invoice.Room = room
	invoice.Name = name
	knownTotal := invoice.Rent + invoice.Deposit + invoice.Water + invoice.Electric + invoice.Common + invoice.Appliance + invoice.Late
	if difference := invoice.Total - knownTotal; math.Abs(difference) >= 0.01 {
		invoice.Other = difference
	}
	_ = db.QueryRow(`SELECT CASE WHEN COUNT(*) > 0 THEN COUNT(*) - 1 ELSE 0 END FROM payments
		WHERE user_id = ? AND COALESCE(payment_status, 'pending') != 'paid'
		AND amount > COALESCE(paid_amount, 0)`, userID).Scan(&invoice.AdditionalBills)
	return invoice, nil
}

func lineInvoiceAltText(invoice lineInvoiceFlexData) string {
	return fmt.Sprintf("%s ห้อง %s ยอดคงเหลือ %s", invoice.InvoiceNo, invoice.Room, formatLineMoney(invoiceBalance(invoice)))
}

func invoiceBalance(invoice lineInvoiceFlexData) float64 {
	return math.Max(invoice.Total-invoice.Paid, 0)
}

func formatLineMoney(value float64) string {
	negative := value < 0
	if negative {
		value = -value
	}
	parts := strings.Split(fmt.Sprintf("%.2f", value), ".")
	integer := parts[0]
	for index := len(integer) - 3; index > 0; index -= 3 {
		integer = integer[:index] + "," + integer[index:]
	}
	prefix := ""
	if negative {
		prefix = "-"
	}
	return prefix + integer + "." + parts[1] + " บาท"
}

var thaiFullMonths = []string{"", "มกราคม", "กุมภาพันธ์", "มีนาคม", "เมษายน", "พฤษภาคม", "มิถุนายน", "กรกฎาคม", "สิงหาคม", "กันยายน", "ตุลาคม", "พฤศจิกายน", "ธันวาคม"}
var thaiShortMonths = []string{"", "ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.", "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค."}

func buddhistDisplayYear(year int) int {
	if year > 2400 {
		return year
	}
	return year + 543
}

func formatLinePeriod(value string) string {
	var year, month int
	if _, err := fmt.Sscanf(strings.TrimSpace(value), "%d-%d", &year, &month); err != nil || month < 1 || month > 12 {
		return blankAsDash(value)
	}
	return fmt.Sprintf("%s %d", thaiFullMonths[month], buddhistDisplayYear(year))
}

func formatLineDate(value string) string {
	var year, month, day int
	if _, err := fmt.Sscanf(strings.TrimSpace(value), "%d-%d-%d", &year, &month, &day); err != nil || month < 1 || month > 12 || day < 1 || day > 31 {
		return blankAsDash(value)
	}
	return fmt.Sprintf("%d %s %d", day, thaiShortMonths[month], buddhistDisplayYear(year))
}

func formatLineDateTime(value string) string {
	if strings.TrimSpace(value) == "" {
		return "-"
	}
	parsed, err := time.Parse(time.RFC3339Nano, value)
	if err != nil {
		return formatLineDate(value)
	}
	location, locationErr := time.LoadLocation("Asia/Bangkok")
	if locationErr == nil {
		parsed = parsed.In(location)
	}
	return fmt.Sprintf("%d %s %d %02d:%02d น.", parsed.Day(), thaiShortMonths[int(parsed.Month())], buddhistDisplayYear(parsed.Year()), parsed.Hour(), parsed.Minute())
}

func linePaymentStatusLabel(status string) string {
	switch status {
	case "paid":
		return "ชำระแล้ว"
	case "partial":
		return "ชำระบางส่วน"
	case "checking":
		return "รอตรวจสอบ"
	default:
		return "รอชำระ"
	}
}

func lineInvoiceMoneyRow(label string, value float64) map[string]interface{} {
	return map[string]interface{}{"type": "box", "layout": "horizontal", "spacing": "md", "contents": []map[string]interface{}{
		{"type": "text", "text": label, "size": "sm", "color": "#4B5563", "flex": 3, "wrap": true},
		{"type": "text", "text": formatLineMoney(value), "size": "sm", "color": "#111827", "align": "end", "flex": 2, "wrap": true},
	}}
}

func buildLineInvoiceBubble(invoice lineInvoiceFlexData) map[string]interface{} {
	items := []map[string]interface{}{
		lineInvoiceMoneyRow("ค่าเช่าห้อง", invoice.Rent),
		lineInvoiceMoneyRow("ค่าน้ำประปา", invoice.Water),
		lineInvoiceMoneyRow("ค่าไฟฟ้า", invoice.Electric),
		lineInvoiceMoneyRow("ค่าส่วนกลาง", invoice.Common),
		lineInvoiceMoneyRow("ค่าปรับ", invoice.Late),
	}
	if math.Abs(invoice.Deposit) >= 0.01 {
		items = append(items, lineInvoiceMoneyRow("ค่ามัดจำ", invoice.Deposit))
	}
	if math.Abs(invoice.Appliance) >= 0.01 {
		items = append(items, lineInvoiceMoneyRow("ค่าอุปกรณ์เพิ่มเติม", invoice.Appliance))
	}
	if math.Abs(invoice.Other) >= 0.01 {
		items = append(items, lineInvoiceMoneyRow("รายการอื่น ๆ", invoice.Other))
	}

	periodStatus := map[string]interface{}{"type": "box", "layout": "horizontal", "margin": "lg", "contents": []map[string]interface{}{
		{"type": "box", "layout": "vertical", "flex": 3, "contents": []map[string]interface{}{
			{"type": "text", "text": "รอบบิล", "size": "xs", "color": "#9CA3AF"},
			{"type": "text", "text": formatLinePeriod(invoice.Period), "size": "sm", "weight": "bold", "color": "#374151", "margin": "xs", "wrap": true},
		}},
		{"type": "box", "layout": "vertical", "flex": 2, "alignItems": "flex-end", "contents": []map[string]interface{}{
			{"type": "text", "text": "สถานะ", "size": "xs", "color": "#9CA3AF", "align": "end"},
			{"type": "text", "text": linePaymentStatusLabel(invoice.Status), "size": "sm", "weight": "bold", "color": "#374151", "margin": "xs", "align": "end", "wrap": true},
		}},
	}}

	info := []map[string]interface{}{
		lineInfoRow("ห้อง", invoice.Room),
		lineInfoRow("ชื่อลูกบ้าน", invoice.Name),
		lineInfoRow("กำหนดชำระ", formatLineDate(invoice.DueDate)),
		lineInfoRow("อัปเดตล่าสุด", formatLineDateTime(invoice.UpdatedAt)),
	}
	if invoice.Installment > 0 {
		info = append(info, lineInfoRow("งวดที่", fmt.Sprintf("%d", invoice.Installment)))
	}
	if invoice.PaymentDate != "" {
		info = append(info, lineInfoRow("วันที่รับชำระ", formatLineDate(invoice.PaymentDate)))
	}

	body := []interface{}{
		map[string]interface{}{"type": "text", "text": "ยอดคงเหลือ", "size": "xs", "color": "#6B7280"},
		map[string]interface{}{"type": "text", "text": formatLineMoney(invoiceBalance(invoice)), "size": "xxl", "weight": "bold", "color": "#111827", "margin": "xs", "wrap": true},
		periodStatus,
		map[string]interface{}{"type": "separator", "margin": "lg"},
	}
	for _, row := range info {
		body = append(body, row)
	}
	body = append(body,
		map[string]interface{}{"type": "text", "text": "รายละเอียดค่าใช้จ่าย", "size": "sm", "weight": "bold", "color": "#374151", "margin": "lg"},
		map[string]interface{}{"type": "box", "layout": "vertical", "spacing": "sm", "margin": "md", "contents": items},
		map[string]interface{}{"type": "separator", "margin": "lg"},
		map[string]interface{}{"type": "box", "layout": "vertical", "spacing": "sm", "margin": "md", "contents": []map[string]interface{}{
			lineInvoiceMoneyRow("ยอดบิล", invoice.Total),
			lineInvoiceMoneyRow("ชำระแล้ว", invoice.Paid),
		}},
	)
	if invoice.AdditionalBills > 0 {
		body = append(body, map[string]interface{}{"type": "text", "text": fmt.Sprintf("มีใบแจ้งหนี้ค้างอีก %d ใบ · ดูทั้งหมดได้จากเมนูผูกบัญชี", invoice.AdditionalBills), "size": "xs", "color": "#7C8796", "wrap": true, "margin": "lg"})
	}

	return map[string]interface{}{
		"type": "bubble", "size": "mega",
		"header": map[string]interface{}{"type": "box", "layout": "vertical", "paddingBottom": "10px", "contents": []map[string]interface{}{
			{"type": "text", "text": "ใบแจ้งหนี้", "weight": "bold", "size": "lg", "color": "#111827"},
			{"type": "text", "text": "เลขที่บิล " + invoice.InvoiceNo, "size": "xs", "color": "#6B7280", "margin": "xs"},
		}},
		"body": map[string]interface{}{"type": "box", "layout": "vertical", "paddingTop": "10px", "spacing": "sm", "contents": body},
		"footer": map[string]interface{}{"type": "box", "layout": "vertical", "contents": []map[string]interface{}{
			{"type": "text", "text": lineInvoiceFooter(invoice.Status), "size": "xs", "color": "#6B7280", "align": "center", "wrap": true},
		}},
	}
}
func lineInvoiceFooter(status string) string {
	switch status {
	case "checking":
		return "กำลังรอผู้ดูแลตรวจสอบหลักฐานการชำระเงิน"
	case "partial":
		return "ยอดชำระยังไม่ครบ กรุณาตรวจสอบยอดคงเหลือ"
	case "paid":
		return "ชำระใบแจ้งหนี้นี้เรียบร้อยแล้ว"
	default:
		return "ส่งสลิปในแชทนี้หลังชำระเงิน"
	}
}

func PushInvoiceFlexMessage(lineUserID string, invoice lineInvoiceFlexData) {
	if getLineToken() == "" || lineUserID == "" {
		return
	}
	message := map[string]interface{}{
		"type": "flex", "altText": lineInvoiceAltText(invoice), "contents": buildLineInvoiceBubble(invoice),
	}
	_ = pushLinePayload(lineUserID, message)
}
func HandlePushInvoices(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		if r.Method != "POST" {
			http.Error(w, `{"error": "Method not allowed"}`, http.StatusMethodNotAllowed)
			return
		}
		tenantDB := getTenantDB(r, db)

		// ค้นหาบิลทั้งหมดที่ค้างชำระ (pending) และห้องนั้นมีการผูก LINE (line_user_id) แล้ว
		rows, err := tenantDB.Query(`
			SELECT p.payment_id, p.room_number, p.amount, p.month, COALESCE(p.due_date, ''),
			       COALESCE(p.last_updated, ''), COALESCE(p.payment_date, ''), COALESCE(p.payment_status, 'pending'),
			       COALESCE(p.installment_phase, 0), p.rent_fee, COALESCE(p.deposit_fee, 0),
			       p.water_fee, p.electric_fee, p.common_fee, COALESCE(p.appliance_fee, 0), p.late_fee,
			       COALESCE(p.paid_amount, 0),
			       u.full_name, u.line_user_id 
			FROM payments p 
			JOIN users u ON p.user_id = u.user_id 
			WHERE p.payment_status = 'pending' AND u.line_user_id IS NOT NULL AND u.line_user_id != '' AND (u.status = 'กำลังพักอาศัย' OR u.status = 'จอง')
		`)
		if err != nil {
			http.Error(w, `{"error": "Database error"}`, http.StatusInternalServerError)
			return
		}
		defer rows.Close()

		count := 0
		for rows.Next() {
			var paymentID int
			var invoice lineInvoiceFlexData
			var lineUserID string

			if err := rows.Scan(&paymentID, &invoice.Room, &invoice.Total, &invoice.Period, &invoice.DueDate,
				&invoice.UpdatedAt, &invoice.PaymentDate, &invoice.Status, &invoice.Installment,
				&invoice.Rent, &invoice.Deposit, &invoice.Water, &invoice.Electric, &invoice.Common,
				&invoice.Appliance, &invoice.Late, &invoice.Paid, &invoice.Name, &lineUserID); err == nil {
				invoice.InvoiceNo = fmt.Sprintf("INV-%05d", paymentID)
				knownTotal := invoice.Rent + invoice.Deposit + invoice.Water + invoice.Electric + invoice.Common + invoice.Appliance + invoice.Late
				if difference := invoice.Total - knownTotal; math.Abs(difference) >= 0.01 {
					invoice.Other = difference
				}
				PushInvoiceFlexMessage(lineUserID, invoice)
				count++
			}
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"message":      "success",
			"pushed_count": count,
		})
	}
}

func PushReceiptFlexMessage(lineUserID, paymentIDStr, roomNumber, dateStr string, amount float64, imageURL string) {
	token := getLineToken()
	if token == "" || lineUserID == "" {
		return
	}

	receiptNo := fmt.Sprintf("REC-%05s", paymentIDStr)

	flexJSON := fmt.Sprintf(`{
		"type": "bubble",
		"size": "kilo",
		"header": {
			"type": "box",
			"layout": "vertical",
			"contents": [
				{
					"type": "text",
					"text": "ใบเสร็จรับเงิน",
					"weight": "bold",
					"color": "#4F46E5",
					"size": "xl"
				},
				{
					"type": "text",
					"text": "RECEIPT",
					"size": "sm",
					"color": "#818CF8",
					"margin": "sm"
				}
			]
		},
		"body": {
			"type": "box",
			"layout": "vertical",
			"contents": [
				{
					"type": "box",
					"layout": "vertical",
					"margin": "md",
					"spacing": "sm",
					"contents": [
						{
							"type": "box",
							"layout": "baseline",
							"spacing": "sm",
							"contents": [
								{"type": "text", "text": "เลขที่", "color": "#aaaaaa", "size": "sm", "flex": 1},
								{"type": "text", "text": "%s", "wrap": true, "color": "#666666", "size": "sm", "flex": 3}
							]
						},
						{
							"type": "box",
							"layout": "baseline",
							"spacing": "sm",
							"contents": [
								{"type": "text", "text": "ห้อง", "color": "#aaaaaa", "size": "sm", "flex": 1},
								{"type": "text", "text": "%s", "wrap": true, "color": "#666666", "size": "sm", "flex": 3}
							]
						},
						{
							"type": "box",
							"layout": "baseline",
							"spacing": "sm",
							"contents": [
								{"type": "text", "text": "วันที่", "color": "#aaaaaa", "size": "sm", "flex": 1},
								{"type": "text", "text": "%s", "wrap": true, "color": "#666666", "size": "sm", "flex": 3}
							]
						}
					]
				},
				{
					"type": "separator",
					"margin": "lg"
				},
				{
					"type": "box",
					"layout": "vertical",
					"margin": "lg",
					"contents": [
						{
							"type": "box",
							"layout": "horizontal",
							"contents": [
								{"type": "text", "text": "ยอดรับชำระ", "size": "md", "color": "#111111", "flex": 1, "weight": "bold"},
								{"type": "text", "text": "฿%.2f", "size": "md", "color": "#4F46E5", "align": "end", "flex": 0, "weight": "bold", "wrap": true}
							]
						}
					]
				},
				{
					"type": "box",
					"layout": "vertical",
					"margin": "lg",
					"contents": [
						{
							"type": "text",
							"text": "สถานะ: การชำระเงินเสร็จสิ้น",
							"size": "xs",
							"color": "#10B981",
							"align": "center",
							"wrap": true
						}
					]
				}
			]
		}
	}`, receiptNo, roomNumber, dateStr, amount)

	var contents map[string]interface{}
	json.Unmarshal([]byte(flexJSON), &contents)

	if imageURL != "" && strings.HasPrefix(imageURL, "https://") {
		if body, ok := contents["body"].(map[string]interface{}); ok {
			if bodyContents, ok := body["contents"].([]interface{}); ok {
				buttonBox := map[string]interface{}{
					"type":   "box",
					"layout": "vertical",
					"margin": "md",
					"contents": []interface{}{
						map[string]interface{}{
							"type":   "button",
							"style":  "primary",
							"color":  "#4F46E5",
							"height": "sm",
							"action": map[string]interface{}{
								"type":  "uri",
								"label": "ดูรูปสลิป",
								"uri":   imageURL,
							},
						},
					},
				}
				body["contents"] = append(bodyContents, buttonBox)
			}
		}
	}

	altText := fmt.Sprintf("ใบเสร็จรับเงินห้อง %s (ยอด %.2f บาท)", roomNumber, amount)

	messages := []map[string]interface{}{
		{
			"type":     "flex",
			"altText":  altText,
			"contents": contents,
		},
	}

	url := "https://api.line.me/v2/bot/message/push"
	body := map[string]interface{}{
		"to":       lineUserID,
		"messages": messages,
	}
	jsonBody, _ := json.Marshal(body)

	req, _ := http.NewRequest("POST", url, bytes.NewBuffer(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		fmt.Println("Error sending receipt to LINE:", err)
		return
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	fmt.Println("LINE Push Receipt response:", resp.Status, string(respBody))
}

func handlePostbackEvent(master, db *sql.DB, accountID int, replyToken, lineUserID, data string) {
	if strings.HasPrefix(data, "action=maintenance_quote_approve&id=") {
		handleMaintenanceQuoteDecision(master, db, accountID, replyToken, lineUserID,
			strings.TrimPrefix(data, "action=maintenance_quote_approve&id="), true)
		return
	}
	if strings.HasPrefix(data, "action=maintenance_quote_reject&id=") {
		handleMaintenanceQuoteDecision(master, db, accountID, replyToken, lineUserID,
			strings.TrimPrefix(data, "action=maintenance_quote_reject&id="), false)
		return
	}
	if strings.HasPrefix(data, "action=pay_maint&id=") {
		maintID := strings.TrimPrefix(data, "action=pay_maint&id=")
		var count int
		_ = db.QueryRow(`SELECT COUNT(*) FROM maintenances m JOIN users u ON u.room_number = m.room_number
			WHERE m.id = ? AND u.line_user_id = ? AND u.status IN ('กำลังพักอาศัย','จอง')
			AND m.status = 'รอตรวจสอบชำระเงิน' AND m.cost > 0`, maintID, lineUserID).Scan(&count)
		if count == 0 {
			replyToLine(replyToken, "บิลนี้ไม่พร้อมรับชำระ หรือสถานะถูกเปลี่ยนไปแล้วค่ะ")
			return
		}
		db.Exec("UPDATE users SET bot_state = ? WHERE line_user_id = ?", "pay_maint_"+maintID, lineUserID)
		replyToLine(replyToken, "กรุณาอัปโหลดสลิปชำระเงินค่าซ่อมแซมเข้ามาในแชทนี้ได้เลยค่ะ")
	}
}

func handleMaintenanceQuoteDecision(master, db *sql.DB, accountID int, replyToken, lineUserID, maintenanceID string, approved bool) {
	maintenanceID = strings.TrimSpace(maintenanceID)
	var notification maintenanceStatusNotification
	var quoteApprovedAt string
	err := db.QueryRow(`SELECT m.status, m.cost, m.room_number, m.issue,
		COALESCE(m.reported_at, ''), COALESCE(m.resolved_at, ''), COALESCE(m.payment_method, ''),
		COALESCE(m.quote_approved_at, '') FROM maintenances m
		JOIN users u ON u.room_number = m.room_number
		WHERE m.id = ? AND u.line_user_id = ? AND u.status IN ('กำลังพักอาศัย','จอง')
		LIMIT 1`, maintenanceID, lineUserID).Scan(
		&notification.Status, &notification.Cost, &notification.RoomNumber, &notification.Issue,
		&notification.ReportedAt, &notification.ResolvedAt, &notification.PaymentMethod, &quoteApprovedAt,
	)
	if err != nil {
		replyToLine(replyToken, "ไม่พบใบเสนอราคานี้ หรือบัญชีไม่มีสิทธิ์ทำรายการค่ะ")
		return
	}
	if notification.Status != "รออนุมัติค่าใช้จ่าย" {
		if approved && notification.Status == "รอตรวจสอบชำระเงิน" {
			replyToLine(replyToken, "ใบเสนอราคานี้อนุมัติแล้วค่ะ รอการตรวจสอบการชำระเงินอยู่ค่ะ")
			return
		}
		replyToLine(replyToken, "ใบเสนอราคานี้ถูกตอบกลับแล้วค่ะ")
		return
	}
	if notification.Cost <= 0 {
		replyToLine(replyToken, "ยอดในใบเสนอราคาไม่ถูกต้อง กรุณาติดต่อผู้ดูแลค่ะ")
		return
	}

	// เมื่ออนุมัติ: เปลี่ยนสถานะเป็น "รอตรวจสอบชำระเงิน" แทน "กำลังติดต่อช่าง"
	// เพื่อให้ลูกบ้านชำระเงินก่อนที่ช่างจะมาซ่อม
	nextStatus := "ปฏิเสธค่าใช้จ่าย"
	approvedAt := ""
	if approved {
		nextStatus = "รอตรวจสอบชำระเงิน"
		approvedAt = time.Now().UTC().Format(time.RFC3339Nano)
	}
	now := time.Now().UTC().Format(time.RFC3339Nano)
	result, err := db.Exec(`UPDATE maintenances SET status = ?, quote_approved_at = ?, last_updated = ?
		WHERE id = ? AND status = 'รออนุมัติค่าใช้จ่าย'`, nextStatus, approvedAt, now, maintenanceID)
	if err != nil {
		replyToLine(replyToken, "ระบบบันทึกคำตอบไม่สำเร็จ กรุณาลองใหม่อีกครั้งค่ะ")
		return
	}
	changed, _ := result.RowsAffected()
	if changed != 1 {
		replyToLine(replyToken, "ใบเสนอราคานี้ถูกตอบกลับไปแล้วค่ะ")
		return
	}

	actionName := "rejected"
	if approved {
		actionName = "approved"
	}
	notification.EventKey = fmt.Sprintf("maintenance-quote-%s:%d:%s:%s", actionName, accountID, maintenanceID, now)
	notification.MaintenanceID = maintenanceID
	notification.LineUserID = lineUserID
	notification.Status = nextStatus
	notification.LastUpdated = now
	queued := true
	if err := EnqueueMaintenanceStatusNotification(master, accountID, notification); err != nil {
		queued = false
		log.Printf("[LINE] queue %s maintenance status failed (account=%d maintenance=%s): %v", actionName, accountID, maintenanceID, err)
		// A plain-text reply is only a delivery fallback. On the normal path the
		// queued Flex card is the single confirmation, so LINE does not show the
		// same approval or rejection twice.
		replyToLine(replyToken, "บันทึกผลการพิจารณาแล้วค่ะ กรุณาตรวจสอบสถานะงานซ่อมอีกครั้ง")
	}

	publishLineChanges(master, db, accountID)
	if queued {
		go ProcessPendingLineNotifications(master)
	}
}

func PushMaintenanceBillFlexMessage(lineUserID, maintID, roomNumber, issue string, cost float64) {
	token := getLineToken()
	if token == "" || lineUserID == "" {
		return
	}

	dateStr := time.Now().Format("02/01/2006")

	buttonLabel := "ชำระเงินค่าซ่อม"
	buttonColor := "#F59E0B"
	headerColor := "#F59E0B"
	subHeaderColor := "#FCD34D"
	amountColor := "#F59E0B"
	actionData := fmt.Sprintf("action=pay_maint&id=%s", maintID)

	if cost <= 0 {
		buttonLabel = "ไม่มีค่าใช้จ่าย"
		buttonColor = "#d1d5db"
		actionData = "action=ignore"

		// Indigo Theme for No Cost
		headerColor = "#4338CA"    // Indigo-700
		subHeaderColor = "#818CF8" // Indigo-400
		amountColor = "#4338CA"
	}

	flexJSON := fmt.Sprintf(`{
		"type": "bubble",
		"header": { "type": "box", "layout": "vertical", "contents": [ { "type": "text", "text": "ใบแจ้งหนี้ค่าซ่อมแซม", "weight": "bold", "color": "%s", "size": "xl" }, { "type": "text", "text": "MAINTENANCE BILL", "size": "sm", "color": "%s", "margin": "sm" } ] },
		"body": {
			"type": "box", "layout": "vertical",
			"contents": [
				{
					"type": "box", "layout": "vertical", "margin": "md", "spacing": "sm",
					"contents": [
						{ "type": "box", "layout": "baseline", "spacing": "sm", "contents": [ {"type": "text", "text": "ห้อง", "color": "#aaaaaa", "size": "sm", "flex": 1}, {"type": "text", "text": "%s", "wrap": true, "color": "#666666", "size": "sm", "flex": 3} ] },
						{ "type": "box", "layout": "baseline", "spacing": "sm", "contents": [ {"type": "text", "text": "วันที่", "color": "#aaaaaa", "size": "sm", "flex": 1}, {"type": "text", "text": "%s", "wrap": true, "color": "#666666", "size": "sm", "flex": 3} ] },
						{ "type": "box", "layout": "baseline", "spacing": "sm", "contents": [ {"type": "text", "text": "รายการ", "color": "#aaaaaa", "size": "sm", "flex": 1}, {"type": "text", "text": "%s", "wrap": true, "color": "#666666", "size": "sm", "flex": 3} ] }
					]
				},
				{ "type": "separator", "margin": "lg" },
				{
					"type": "box", "layout": "vertical", "margin": "lg",
					"contents": [
						{ "type": "box", "layout": "horizontal", "contents": [ {"type": "text", "text": "ยอดรวม", "size": "md", "color": "#111111", "flex": 2, "weight": "bold"}, {"type": "text", "text": "฿%.2f", "size": "md", "color": "%s", "align": "end", "flex": 1, "weight": "bold"} ] }
					]
				}
			]
		},
		"footer": {
			"type": "box", "layout": "vertical", "spacing": "sm",
			"contents": [
				{
					"type": "button",
					"style": "primary",
					"color": "%s",
					"action": {
						"type": "postback",
						"label": "%s",
						"data": "%s"
					}
				}
			]
		}
	}`, headerColor, subHeaderColor, roomNumber, dateStr, issue, cost, amountColor, buttonColor, buttonLabel, actionData)

	var contents map[string]interface{}
	json.Unmarshal([]byte(flexJSON), &contents)

	url := "https://api.line.me/v2/bot/message/push"
	body := map[string]interface{}{
		"to": lineUserID,
		"messages": []map[string]interface{}{
			{
				"type":     "flex",
				"altText":  fmt.Sprintf("ใบแจ้งหนี้ค่าซ่อมแซมห้อง %s (ยอด %.2f บาท)", roomNumber, cost),
				"contents": contents,
			},
		},
	}
	jsonBody, _ := json.Marshal(body)
	req, _ := http.NewRequest("POST", url, bytes.NewBuffer(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)

	client := &http.Client{Timeout: 10 * time.Second}
	client.Do(req)
}

func PushMaintenanceStatusFlexMessage(lineUserID, roomNumber, issue, status string) {
	if err := sendMaintenanceStatusFlexMessage(maintenanceStatusNotification{
		LineUserID: lineUserID, RoomNumber: roomNumber, Issue: issue, Status: status,
		LastUpdated: time.Now().UTC().Format(time.RFC3339Nano),
	}); err != nil {
		fmt.Println("Error sending maintenance status flex message:", err)
	}
}

func sendMaintenanceStatusFlexMessage(notification maintenanceStatusNotification) error {
	token := getLineToken()
	if token == "" {
		return fmt.Errorf("LINE token is not configured")
	}
	if strings.TrimSpace(notification.LineUserID) == "" {
		return fmt.Errorf("LINE user id is empty")
	}
	message, err := buildMaintenanceStatusFlexMessage(notification, time.Now())
	if err != nil {
		return err
	}
	if strings.HasPrefix(notification.EventKey, "maintenance-quote-approved:") || (strings.TrimSpace(notification.Status) == "รอตรวจสอบชำระเงิน" && notification.Cost > 0) {
		textMsg := map[string]interface{}{
			"type": "text",
			"text": "เมื่อชำระเงินเรียบร้อยแล้ว สามารถส่งรูปสลิปเข้ามาในแชทนี้ได้เลยนะคะ ระบบจะตรวจสอบและตัดยอดให้อัตโนมัติค่ะ",
		}
		return pushLinePayload(notification.LineUserID, message, textMsg)
	}
	return pushLinePayload(notification.LineUserID, message)
}

func buildMaintenanceStatusFlexMessage(notification maintenanceStatusNotification, fallbackTime time.Time) (map[string]interface{}, error) {
	roomNumber := strings.TrimSpace(notification.RoomNumber)
	issue := strings.TrimSpace(notification.Issue)
	status := strings.TrimSpace(notification.Status)
	if roomNumber == "" || issue == "" || status == "" {
		return nil, fmt.Errorf("maintenance Flex message is missing required detail")
	}
	if strings.HasPrefix(notification.EventKey, "maintenance-quote-approved:") {
		return buildMaintenanceQuoteApprovedFlexMessage(notification, fallbackTime)
	}
	if status == "รออนุมัติค่าใช้จ่าย" {
		return buildMaintenanceQuoteFlexMessage(notification, fallbackTime)
	}
	if status == "รอตรวจสอบชำระเงิน" && notification.Cost > 0 {
		return buildMaintenancePaymentFlexMessage(notification, fallbackTime)
	}
	if status == "ปฏิเสธค่าใช้จ่าย" {
		return buildMaintenanceRejectFlexMessage(notification, fallbackTime)
	}

	step := maintenanceStatusStep(status)
	updatedAt := formatThaiMaintenanceDateTime(notification.LastUpdated, fallbackTime, true)
	reportedAt := formatThaiMaintenanceDateTime(notification.ReportedAt, time.Time{}, false)
	const stepCount = 6
	progressContents := make([]interface{}, 0, stepCount)
	for index := 0; index < stepCount; index++ {
		color := "#D1D5DB"
		if index <= step {
			color = "#374151"
		}
		progressContents = append(progressContents, map[string]interface{}{
			"type": "box", "layout": "vertical", "flex": 1, "height": "4px",
			"backgroundColor": color, "cornerRadius": "2px",
			"contents": []interface{}{map[string]interface{}{"type": "filler"}},
		})
	}

	detailRows := []interface{}{
		maintenanceFlexDetailRow("แจ้งเมื่อ", reportedAt),
		maintenanceFlexDetailRow("อัปเดตล่าสุด", updatedAt),
	}
	if notification.Cost > 0 {
		detailRows = append(detailRows, maintenanceFlexDetailRow("ค่าใช้จ่าย", formatLineMoney(notification.Cost)))
	}
	if method := strings.TrimSpace(notification.PaymentMethod); method != "" {
		detailRows = append(detailRows, maintenanceFlexDetailRow("ช่องทางชำระ", method))
	}
	if status == "เสร็จสิ้น" && strings.TrimSpace(notification.ResolvedAt) != "" {
		detailRows = append(detailRows, maintenanceFlexDetailRow("เสร็จเมื่อ", formatThaiMaintenanceDateTime(notification.ResolvedAt, fallbackTime, true)))
	}

	contents := map[string]interface{}{
		"type": "bubble", "size": "mega",
		"body": map[string]interface{}{
			"type": "box", "layout": "vertical", "paddingAll": "18px", "spacing": "md",
			"contents": []interface{}{
				map[string]interface{}{
					"type": "box", "layout": "horizontal", "alignItems": "center",
					"contents": []interface{}{
						map[string]interface{}{"type": "text", "text": "แจ้งซ่อม", "size": "lg", "color": "#111827", "weight": "bold", "flex": 3},
						map[string]interface{}{"type": "text", "text": "ห้อง " + roomNumber, "size": "sm", "color": "#6B7280", "weight": "bold", "align": "end", "flex": 2},
					},
				},
				map[string]interface{}{"type": "text", "text": issue, "size": "md", "color": "#111827", "weight": "bold", "wrap": true},
				map[string]interface{}{"type": "separator", "color": "#E5E7EB"},
				map[string]interface{}{"type": "box", "layout": "vertical", "spacing": "sm", "contents": detailRows},
				map[string]interface{}{
					"type": "box", "layout": "vertical", "backgroundColor": "#F3F4F6", "cornerRadius": "12px", "paddingAll": "12px", "spacing": "sm",
					"contents": []interface{}{
						map[string]interface{}{
							"type": "box", "layout": "horizontal", "alignItems": "center",
							"contents": []interface{}{
								map[string]interface{}{"type": "text", "text": status, "size": "sm", "color": "#111827", "weight": "bold", "wrap": true, "flex": 4},
								map[string]interface{}{"type": "text", "text": fmt.Sprintf("%d/%d", step+1, stepCount), "size": "xs", "color": "#6B7280", "align": "end", "flex": 1},
							},
						},
						map[string]interface{}{"type": "box", "layout": "horizontal", "spacing": "xs", "contents": progressContents},
					},
				},
			},
		},
	}

	return map[string]interface{}{
		"type":     "flex",
		"altText":  fmt.Sprintf("แจ้งซ่อมห้อง %s • %s • %s", roomNumber, status, updatedAt),
		"contents": contents,
	}, nil
}

func buildMaintenanceQuoteApprovedFlexMessage(notification maintenanceStatusNotification, fallbackTime time.Time) (map[string]interface{}, error) {
	roomNumber := strings.TrimSpace(notification.RoomNumber)
	issue := strings.TrimSpace(notification.Issue)
	updatedAt := formatThaiMaintenanceDateTime(notification.LastUpdated, fallbackTime, true)
	reportedAt := formatThaiMaintenanceDateTime(notification.ReportedAt, time.Time{}, false)
	costStr := formatLineMoney(notification.Cost)

	promptPayID := os.Getenv("PROMPTPAY_ID")
	if promptPayID == "" {
		promptPayID = "0961950943" // Use actual number for testing if env is not set
	}
	payload := utils.GeneratePromptPayPayload(promptPayID, notification.Cost)
	qrURL := "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=" + url.QueryEscape(payload)

	detailRows := []interface{}{
		maintenanceFlexDetailRow("แจ้งเมื่อ", reportedAt),
		maintenanceFlexDetailRow("อัปเดตล่าสุด", updatedAt),
		maintenanceFlexDetailRow("ค่าใช้จ่าย", costStr),
	}

	const stepCount = 6
	step := 2 // 0=รอดำเนินการ, 1=กำลังติดต่อช่าง, 2=รออนุมัติ/อนุมัติ
	progressContents := make([]interface{}, 0, stepCount)
	for index := 0; index < stepCount; index++ {
		color := "#D1D5DB"
		if index <= step {
			color = "#374151"
		}
		progressContents = append(progressContents, map[string]interface{}{
			"type": "box", "layout": "vertical", "flex": 1, "height": "4px",
			"backgroundColor": color, "cornerRadius": "2px",
			"contents": []interface{}{map[string]interface{}{"type": "filler"}},
		})
	}

	bubble1 := map[string]interface{}{
		"type": "bubble", "size": "mega",
		"body": map[string]interface{}{
			"type": "box", "layout": "vertical", "paddingAll": "20px", "justifyContent": "space-between",
			"contents": []interface{}{
				map[string]interface{}{
					"type": "box", "layout": "vertical",
					"contents": []interface{}{
						map[string]interface{}{
							"type": "box", "layout": "horizontal", "alignItems": "center",
							"contents": []interface{}{
								map[string]interface{}{"type": "text", "text": "แจ้งซ่อม", "size": "lg", "color": "#111827", "weight": "bold", "flex": 4},
								map[string]interface{}{"type": "text", "text": "ห้อง " + roomNumber, "size": "sm", "color": "#6B7280", "weight": "bold", "align": "end", "flex": 2},
							},
						},
						map[string]interface{}{"type": "text", "text": issue, "size": "md", "color": "#111827", "weight": "bold", "margin": "sm", "wrap": true},
						map[string]interface{}{"type": "separator", "color": "#E5E7EB", "margin": "md"},
						map[string]interface{}{
							"type": "box", "layout": "vertical", "margin": "md", "spacing": "sm",
							"contents": detailRows,
						},
						map[string]interface{}{"type": "separator", "color": "#E5E7EB", "margin": "md"},
						map[string]interface{}{
							"type": "box", "layout": "vertical", "margin": "md", "spacing": "xs",
							"contents": []interface{}{
								map[string]interface{}{"type": "text", "text": "หมายเหตุ:", "size": "sm", "color": "#374151", "weight": "bold"},
								map[string]interface{}{"type": "text", "text": "• กรุณาชำระเงินตามช่องทางด้านข้าง", "size": "xs", "color": "#6B7280"},
								map[string]interface{}{"type": "text", "text": "• ช่างจะเข้าดำเนินการหลังตรวจสอบยอด", "size": "xs", "color": "#6B7280"},
								map[string]interface{}{"type": "text", "text": "• หากมีข้อสงสัย โปรดติดต่อแอดมิน", "size": "xs", "color": "#6B7280"},
							},
						},
					},
				},
				map[string]interface{}{
					"type": "box", "layout": "vertical", "margin": "lg", "paddingAll": "12px", "backgroundColor": "#F3F4F6", "cornerRadius": "12px", "spacing": "sm",
					"contents": []interface{}{
						map[string]interface{}{
							"type": "box", "layout": "horizontal", "alignItems": "center",
							"contents": []interface{}{
								map[string]interface{}{"type": "text", "text": "อนุมัติใบเสนอราคา", "size": "sm", "color": "#111827", "wrap": true, "weight": "bold", "flex": 4},
								map[string]interface{}{"type": "text", "text": fmt.Sprintf("%d/%d", step+1, stepCount), "size": "xs", "color": "#6B7280", "align": "end", "flex": 1},
							},
						},
						map[string]interface{}{"type": "box", "layout": "horizontal", "spacing": "xs", "contents": progressContents},
						map[string]interface{}{"type": "text", "text": "กรุณาชำระเงินตามช่องทางที่ระบุด้านข้าง", "size": "xs", "color": "#6B7280", "wrap": true, "margin": "sm"},
					},
				},
			},
		},
	}
	
	bubble2 := map[string]interface{}{
		"type": "bubble", "size": "mega",
		"header": map[string]interface{}{
			"type": "box", "layout": "vertical", "paddingBottom": "none",
			"contents": []interface{}{
				map[string]interface{}{"type": "text", "text": "ช่องทางชำระเงิน", "weight": "bold", "size": "lg", "color": "#111827", "align": "center"},
				map[string]interface{}{"type": "text", "text": "ยอดที่ต้องชำระ " + costStr, "size": "sm", "color": "#374151", "margin": "xs", "weight": "bold", "align": "center"},
			},
		},
		"body": map[string]interface{}{
			"type": "box", "layout": "vertical", "spacing": "sm",
			"contents": []interface{}{
				map[string]interface{}{
					"type": "box", "layout": "vertical", "paddingStart": "20px", "paddingEnd": "20px", "paddingBottom": "10px", "paddingTop": "10px",
					"contents": []interface{}{
						map[string]interface{}{
							"type": "image",
							"url": qrURL,
							"size": "full",
							"aspectRatio": "1:1",
							"aspectMode": "cover",
						},
					},
				},
				map[string]interface{}{"type": "text", "text": "สแกน QR Code เพื่อชำระเงิน", "size": "sm", "color": "#111827", "align": "center", "weight": "bold", "margin": "md"},
				map[string]interface{}{"type": "text", "text": "รองรับการสแกนผ่านทุกแอปธนาคาร", "size": "xs", "color": "#6B7280", "align": "center", "wrap": true},
			},
		},
	}

	return map[string]interface{}{
		"type":     "flex",
		"altText":  "อนุมัติใบเสนอราคา - กรุณาชำระเงิน",
		"contents": map[string]interface{}{
			"type": "carousel",
			"contents": []interface{}{bubble1, bubble2},
		},
	}, nil
}

func buildMaintenanceRejectFlexMessage(notification maintenanceStatusNotification, fallbackTime time.Time) (map[string]interface{}, error) {
	roomNumber := strings.TrimSpace(notification.RoomNumber)
	issue := strings.TrimSpace(notification.Issue)
	updatedAt := formatThaiMaintenanceDateTime(notification.LastUpdated, fallbackTime, true)

	return map[string]interface{}{
		"type": "flex", "altText": "ผลการพิจารณาใบเสนอราคางานซ่อม",
		"contents": map[string]interface{}{
			"type": "bubble", "size": "mega",
			"body": map[string]interface{}{
				"type": "box", "layout": "vertical", "paddingAll": "20px",
				"contents": []interface{}{
					map[string]interface{}{
						"type": "box", "layout": "horizontal", "alignItems": "center",
						"contents": []interface{}{
							map[string]interface{}{"type": "text", "text": "แจ้งซ่อม", "size": "lg", "color": "#111827", "weight": "bold", "flex": 4},
							map[string]interface{}{"type": "text", "text": "ห้อง " + roomNumber, "size": "sm", "color": "#6B7280", "weight": "bold", "align": "end", "flex": 2},
						},
					},
					map[string]interface{}{
						"type": "text", "text": issue, "size": "md", "color": "#111827", "weight": "bold", "margin": "sm", "wrap": true,
					},
					map[string]interface{}{"type": "separator", "color": "#E5E7EB", "margin": "md"},
					map[string]interface{}{
						"type": "box", "layout": "vertical", "margin": "md", "spacing": "sm",
						"contents": []interface{}{
							maintenanceFlexDetailRow("อัปเดตล่าสุด", updatedAt),
						},
					},
					map[string]interface{}{
						"type": "box", "layout": "vertical", "margin": "lg", "paddingAll": "12px", "backgroundColor": "#F3F4F6", "cornerRadius": "12px", "spacing": "xs",
						"contents": []interface{}{
							map[string]interface{}{
								"type": "text", "text": "ผลการพิจารณา", "size": "xs", "color": "#9CA3AF", "wrap": true,
							},
							map[string]interface{}{
								"type": "text", "text": "ไม่อนุมัติใบเสนอราคา", "size": "md", "color": "#111827", "wrap": true, "weight": "bold",
							},
							map[string]interface{}{
								"type": "text", "text": "ระบบจะยกเลิกรายการนี้ภายใน 24 ชั่วโมง", "size": "xs", "color": "#6B7280", "wrap": true,
							},
						},
					},
				},
			},
		},
	}, nil
}

func maintenanceFlexDetailRow(label, value string) map[string]interface{} {
	if strings.TrimSpace(value) == "" {
		value = "ไม่ระบุ"
	}
	return map[string]interface{}{
		"type": "box", "layout": "baseline", "spacing": "md",
		"contents": []interface{}{
			map[string]interface{}{"type": "text", "text": label, "size": "sm", "color": "#9CA3AF", "flex": 2},
			map[string]interface{}{"type": "text", "text": value, "size": "sm", "color": "#374151", "flex": 4, "align": "end", "wrap": true},
		},
	}
}

func buildMaintenanceQuoteFlexMessage(notification maintenanceStatusNotification, fallbackTime time.Time) (map[string]interface{}, error) {
	maintenanceID := strings.TrimSpace(notification.MaintenanceID)
	if maintenanceID == "" || notification.Cost <= 0 {
		return nil, fmt.Errorf("maintenance quote is missing id or cost")
	}
	updatedAt := formatThaiMaintenanceDateTime(notification.LastUpdated, fallbackTime, true)
	body := []interface{}{
		maintenanceFlexCompactHeader("ใบเสนอราคางานซ่อม", notification.RoomNumber),
		map[string]interface{}{"type": "text", "text": strings.TrimSpace(notification.Issue), "size": "md", "color": "#111827", "weight": "bold", "wrap": true},
		map[string]interface{}{"type": "separator", "color": "#E5E7EB"},
		map[string]interface{}{
			"type": "box", "layout": "baseline",
			"contents": []interface{}{
				map[string]interface{}{"type": "text", "text": "ยอดที่ขออนุมัติ", "size": "sm", "color": "#6B7280", "flex": 2},
				map[string]interface{}{"type": "text", "text": formatLineMoney(notification.Cost), "size": "xl", "color": "#111827", "weight": "bold", "align": "end", "flex": 3},
			},
		},
		map[string]interface{}{"type": "text", "text": "งานจะเริ่มหลังจากคุณอนุมัติเท่านั้น", "size": "xs", "color": "#6B7280", "wrap": true},
		maintenanceFlexDetailRow("อัปเดต", updatedAt),
	}
	contents := map[string]interface{}{
		"type": "bubble", "size": "mega",
		"body": map[string]interface{}{"type": "box", "layout": "vertical", "paddingAll": "18px", "spacing": "md", "contents": body},
		"footer": map[string]interface{}{
			"type": "box", "layout": "horizontal", "spacing": "sm", "paddingAll": "14px",
			"contents": []interface{}{
				map[string]interface{}{"type": "button", "style": "secondary", "height": "sm", "action": map[string]interface{}{"type": "postback", "label": "ไม่อนุมัติ", "data": "action=maintenance_quote_reject&id=" + maintenanceID}},
				map[string]interface{}{"type": "button", "style": "primary", "color": "#111827", "height": "sm", "action": map[string]interface{}{"type": "postback", "label": "อนุมัติ", "data": "action=maintenance_quote_approve&id=" + maintenanceID}},
			},
		},
	}
	return map[string]interface{}{
		"type": "flex", "altText": fmt.Sprintf("ขออนุมัติค่าซ่อมห้อง %s • %s", notification.RoomNumber, formatLineMoney(notification.Cost)),
		"contents": contents,
	}, nil
}

func buildMaintenancePaymentFlexMessage(notification maintenanceStatusNotification, fallbackTime time.Time) (map[string]interface{}, error) {
	maintenanceID := strings.TrimSpace(notification.MaintenanceID)
	if maintenanceID == "" || notification.Cost <= 0 {
		return nil, fmt.Errorf("maintenance payment request is missing id or cost")
	}
	updatedAt := formatThaiMaintenanceDateTime(notification.LastUpdated, fallbackTime, true)
	contents := map[string]interface{}{
		"type": "bubble", "size": "mega",
		"body": map[string]interface{}{
			"type": "box", "layout": "vertical", "paddingAll": "18px", "spacing": "md",
			"contents": []interface{}{
				maintenanceFlexCompactHeader("ค่าซ่อมที่อนุมัติแล้ว", notification.RoomNumber),
				map[string]interface{}{"type": "text", "text": strings.TrimSpace(notification.Issue), "size": "md", "color": "#111827", "weight": "bold", "wrap": true},
				map[string]interface{}{"type": "separator", "color": "#E5E7EB"},
				map[string]interface{}{
					"type": "box", "layout": "baseline",
					"contents": []interface{}{
						map[string]interface{}{"type": "text", "text": "ยอดชำระ", "size": "sm", "color": "#6B7280", "flex": 2},
						map[string]interface{}{"type": "text", "text": formatLineMoney(notification.Cost), "size": "xl", "color": "#111827", "weight": "bold", "align": "end", "flex": 3},
					},
				},
				maintenanceFlexDetailRow("อัปเดต", updatedAt),
				map[string]interface{}{"type": "text", "text": "รองรับการสแกนผ่านทุกแอปธนาคาร", "size": "xs", "color": "#6B7280", "align": "center", "wrap": true, "margin": "lg"},
			},
		},
	}
	return map[string]interface{}{
		"type": "flex", "altText": fmt.Sprintf("ค่าซ่อมห้อง %s • %s", notification.RoomNumber, formatLineMoney(notification.Cost)),
		"contents": contents,
	}, nil
}

func maintenanceFlexCompactHeader(title, roomNumber string) map[string]interface{} {
	return map[string]interface{}{
		"type": "box", "layout": "horizontal", "alignItems": "center",
		"contents": []interface{}{
			map[string]interface{}{"type": "text", "text": title, "size": "lg", "color": "#111827", "weight": "bold", "flex": 4, "wrap": true},
			map[string]interface{}{"type": "text", "text": "ห้อง " + strings.TrimSpace(roomNumber), "size": "sm", "color": "#6B7280", "weight": "bold", "align": "end", "flex": 2},
		},
	}
}

func maintenanceStatusStep(status string) int {
	switch strings.TrimSpace(status) {
	case "กำลังติดต่อช่าง":
		return 1
	case "รออนุมัติค่าใช้จ่าย":
		return 2
	case "ปฏิเสธค่าใช้จ่าย":
		return 2
	case "กำลังซ่อม":
		return 3
	case "รอตรวจสอบชำระเงิน":
		return 4
	case "เสร็จสิ้น":
		return 5
	default:
		return 0
	}
}

func formatThaiMaintenanceDateTime(raw string, fallback time.Time, includeTime bool) string {
	parsed, ok := parseMaintenanceTime(raw)
	if !ok {
		if fallback.IsZero() {
			return "ไม่ระบุ"
		}
		parsed = fallback
	}
	location, err := time.LoadLocation("Asia/Bangkok")
	if err != nil {
		location = time.FixedZone("Asia/Bangkok", 7*60*60)
	}
	parsed = parsed.In(location)
	date := fmt.Sprintf("%d %s %d", parsed.Day(), thaiShortMonths[int(parsed.Month())], buddhistDisplayYear(parsed.Year()))
	if includeTime {
		return fmt.Sprintf("%s • %02d:%02d น.", date, parsed.Hour(), parsed.Minute())
	}
	return date
}

func parseMaintenanceTime(raw string) (time.Time, bool) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return time.Time{}, false
	}
	for _, layout := range []string{time.RFC3339Nano, time.RFC3339} {
		if parsed, err := time.Parse(layout, raw); err == nil {
			return parsed, true
		}
	}
	location, err := time.LoadLocation("Asia/Bangkok")
	if err != nil {
		location = time.FixedZone("Asia/Bangkok", 7*60*60)
	}
	for _, layout := range []string{"2006-01-02 15:04:05", "2006-01-02 15:04", "2006-01-02"} {
		if parsed, err := time.ParseInLocation(layout, raw, location); err == nil {
			return parsed, true
		}
	}
	return time.Time{}, false
}

func replyToLineWithQuickReply(replyToken, text string, options []string) {
	token := getLineToken()
	if token == "" {
		return
	}

	url := "https://api.line.me/v2/bot/message/reply"

	var items []map[string]interface{}
	for _, opt := range options {
		items = append(items, map[string]interface{}{
			"type": "action",
			"action": map[string]interface{}{
				"type":  "message",
				"label": opt,
				"text":  opt,
			},
		})
	}

	body := map[string]interface{}{
		"replyToken": replyToken,
		"messages": []map[string]interface{}{
			{
				"type": "text",
				"text": text,
				"quickReply": map[string]interface{}{
					"items": items,
				},
			},
		},
	}
	jsonBody, _ := json.Marshal(body)

	req, _ := http.NewRequest("POST", url, bytes.NewBuffer(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)

	client := &http.Client{Timeout: 10 * time.Second}
	client.Do(req)
}
