package handlers

import (
	"encoding/json"
)

func buildWifiFlexMessage() map[string]interface{} {
	flexJSON := `{
		"type": "bubble",
		"size": "mega",
		"header": {
			"type": "box",
			"layout": "vertical",
			"contents": [
				{
					"type": "text",
					"text": "รหัสอินเทอร์เน็ต (Wi-Fi)",
					"weight": "bold",
					"size": "xl",
					"color": "#111111"
				},
				{
					"type": "text",
					"text": "DORMITORY WI-FI",
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
							"type": "box",
							"layout": "baseline",
							"spacing": "sm",
							"contents": [
								{ "type": "text", "text": "Network", "color": "#aaaaaa", "size": "sm", "flex": 2 },
								{ "type": "text", "text": "DormiNet_5G", "wrap": true, "color": "#111111", "size": "md", "flex": 4, "weight": "bold" }
							]
						},
						{
							"type": "box",
							"layout": "baseline",
							"spacing": "sm",
							"contents": [
								{ "type": "text", "text": "Password", "color": "#aaaaaa", "size": "sm", "flex": 2 },
								{ "type": "text", "text": "dorminet2026", "wrap": true, "color": "#ef4444", "size": "md", "flex": 4, "weight": "bold" }
							]
						}
					]
				},
				{ "type": "separator", "margin": "lg" },
				{
					"type": "box",
					"layout": "vertical",
					"margin": "lg",
					"spacing": "sm",
					"contents": [
						{ "type": "text", "text": "พบปัญหาการใช้งานอินเทอร์เน็ต สามารถแจ้งผ่านเมนู 'แจ้งซ่อม' ได้เลยค่ะ", "wrap": true, "size": "xs", "color": "#888888" }
					]
				}
			]
		}
	}`

	var contents map[string]interface{}
	json.Unmarshal([]byte(flexJSON), &contents)
	return contents
}

func buildServicesFlexMessage() map[string]interface{} {
	flexJSON := `{
		"type": "bubble",
		"size": "mega",
		"header": {
			"type": "box",
			"layout": "vertical",
			"contents": [
				{
					"type": "text",
					"text": "บริการรอบหอพัก",
					"weight": "bold",
					"size": "xl",
					"color": "#111111"
				},
				{
					"type": "text",
					"text": "NEARBY SERVICES",
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
					"margin": "md",
					"spacing": "sm",
					"contents": [
						{ "type": "text", "text": "บริการน้ำดื่มส่งถึงห้อง", "weight": "bold", "size": "sm", "color": "#3b82f6" },
						{ "type": "text", "text": "ร้านน้ำดื่มสะอาด โทร: 081-000-0001", "size": "xs", "color": "#666666", "wrap": true },
						{ "type": "text", "text": "ส่งฟรีถึงหน้าห้อง!", "size": "xs", "color": "#888888" }
					]
				},
				{ "type": "separator", "margin": "lg" },
				{
					"type": "box",
					"layout": "vertical",
					"margin": "lg",
					"spacing": "sm",
					"contents": [
						{ "type": "text", "text": "ร้านซักรีด (มีบริการรับ-ส่ง)", "weight": "bold", "size": "sm", "color": "#ec4899" },
						{ "type": "text", "text": "ร้านป้าแจ๋วซักอบรีด โทร: 081-000-0002", "size": "xs", "color": "#666666", "wrap": true },
						{ "type": "text", "text": "ราคาเริ่มต้น 15 บาท/ชิ้น", "size": "xs", "color": "#888888" }
					]
				},
				{ "type": "separator", "margin": "lg" },
				{
					"type": "box",
					"layout": "vertical",
					"margin": "lg",
					"spacing": "sm",
					"contents": [
						{ "type": "text", "text": "วินมอเตอร์ไซค์หน้าปากซอย", "weight": "bold", "size": "sm", "color": "#f59e0b" },
						{ "type": "text", "text": "โทรเรียก: 081-000-0003", "size": "xs", "color": "#666666", "wrap": true }
					]
				}
			]
		}
	}`

	var contents map[string]interface{}
	json.Unmarshal([]byte(flexJSON), &contents)
	return contents
}
