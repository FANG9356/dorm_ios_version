package handlers

import (
	"encoding/json"
)

func buildContactMenuFlexMessage() map[string]interface{} {
	flexJSON := `{
		"type": "bubble",
		"size": "mega",
		"header": {
			"type": "box",
			"layout": "vertical",
			"contents": [
				{
					"type": "text",
					"text": "ช่องทางการติดต่อ",
					"weight": "bold",
					"size": "xl",
					"color": "#111111"
				},
				{
					"type": "text",
					"text": "CONTACT & EMERGENCY",
					"size": "xs",
					"color": "#888888"
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
					"margin": "lg",
					"spacing": "sm",
					"contents": [
						{
							"type": "text",
							"text": "ติดต่อนิติบุคคล",
							"weight": "bold",
							"size": "sm",
							"color": "#111111"
						},
						{
							"type": "box",
							"layout": "baseline",
							"spacing": "sm",
							"contents": [
								{ "type": "text", "text": "เวลาทำการ", "color": "#888888", "size": "xs", "flex": 3 },
								{ "type": "text", "text": "จ.-ส. 08:00-20:00 น.", "color": "#111111", "size": "xs", "flex": 5, "wrap": true }
							]
						},
						{
							"type": "button",
							"style": "secondary",
							"height": "sm",
							"action": {
								"type": "uri",
								"label": "โทรติดต่อ: 081-234-5678",
								"uri": "tel:0812345678"
							},
							"color": "#f1f5f9"
						},
						{
							"type": "button",
							"style": "secondary",
							"height": "sm",
							"action": {
								"type": "message",
								"label": "ส่งข้อความถึงนิติบุคคล",
								"text": "ฝากข้อความถึงแอดมิน"
							},
							"color": "#f1f5f9"
						}
					]
				},
				{
					"type": "separator",
					"margin": "lg",
					"color": "#eeeeee"
				},
				{
					"type": "box",
					"layout": "vertical",
					"margin": "lg",
					"spacing": "sm",
					"contents": [
						{
							"type": "text",
							"text": "หมายเลขโทรศัพท์ฉุกเฉิน",
							"weight": "bold",
							"size": "sm",
							"color": "#111111"
						},
						{
							"type": "button",
							"style": "secondary",
							"height": "sm",
							"action": {
								"type": "uri",
								"label": "สถาบันการแพทย์ฉุกเฉิน (1669)",
								"uri": "tel:1669"
							},
							"color": "#f1f5f9"
						},
						{
							"type": "text",
							"text": "ใช้เมื่อเจ็บป่วยหรือได้รับบาดเจ็บ",
							"size": "xs",
							"color": "#aaaaaa",
							"margin": "xs"
						},
						{
							"type": "button",
							"style": "secondary",
							"height": "sm",
							"action": {
								"type": "uri",
								"label": "แจ้งเหตุเพลิงไหม้ (199)",
								"uri": "tel:199"
							},
							"color": "#f1f5f9"
						},
						{
							"type": "text",
							"text": "ใช้เมื่อเกิดเพลิงไหม้หรือควันไฟ",
							"size": "xs",
							"color": "#aaaaaa",
							"margin": "xs"
						},
						{
							"type": "button",
							"style": "secondary",
							"height": "sm",
							"action": {
								"type": "uri",
								"label": "เหตุด่วนเหตุร้าย (191)",
								"uri": "tel:191"
							},
							"color": "#f1f5f9"
						},
						{
							"type": "text",
							"text": "ใช้เมื่อเกิดเหตุการณ์อาชญากรรมหรือเหตุด่วน",
							"size": "xs",
							"color": "#aaaaaa",
							"margin": "xs",
							"wrap": true
						}
					]
				}
			]
		}
	}`

	var contents map[string]interface{}
	json.Unmarshal([]byte(flexJSON), &contents)
	return contents
}
