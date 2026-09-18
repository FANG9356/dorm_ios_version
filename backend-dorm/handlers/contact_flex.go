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
					"color": "#aaaaaa"
				}
			],
			"backgroundColor": "#f8f9fa"
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
							"text": "ติดต่อแอดมินหอพัก",
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
								"label": "📞 โทร: 081-234-5678",
								"uri": "tel:0812345678"
							},
							"color": "#e0e7ff"
						},
						{
							"type": "button",
							"style": "link",
							"height": "sm",
							"action": {
								"type": "message",
								"label": "💬 แชทกับแอดมิน (ฝากข้อความ)",
								"text": "ฝากข้อความถึงแอดมิน"
							}
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
							"text": "สายด่วนฉุกเฉิน",
							"weight": "bold",
							"size": "sm",
							"color": "#ef4444"
						},
						{
							"type": "button",
							"style": "secondary",
							"height": "sm",
							"action": {
								"type": "uri",
								"label": "🚑 เจ็บป่วยฉุกเฉิน (1669)",
								"uri": "tel:1669"
							}
						},
						{
							"type": "button",
							"style": "secondary",
							"height": "sm",
							"action": {
								"type": "uri",
								"label": "🚒 แจ้งเหตุเพลิงไหม้ (199)",
								"uri": "tel:199"
							}
						},
						{
							"type": "button",
							"style": "secondary",
							"height": "sm",
							"action": {
								"type": "uri",
								"label": "🚓 เหตุด่วนเหตุร้าย (191)",
								"uri": "tel:191"
							}
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
