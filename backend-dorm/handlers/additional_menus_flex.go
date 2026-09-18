package handlers

import (
	"encoding/json"
)

func buildWifiFlexMessage() map[string]interface{} {
	flexJSON := `{
		"type": "bubble",
		"size": "kilo",
		"header": {
			"type": "box",
			"layout": "vertical",
			"paddingBottom": "none",
			"contents": [
				{
					"type": "text",
					"text": "Wi-Fi & Internet",
					"weight": "bold",
					"size": "lg",
					"color": "#111111",
					"align": "center"
				}
			]
		},
		"body": {
			"type": "box",
			"layout": "vertical",
			"contents": [
				{
					"type": "image",
					"url": "https://quickchart.io/qr?text=WIFI%3AT%3AWPA%3BS%3ADorminet%3BP%3A999999999%3B%3B&size=300",
					"size": "xl",
					"aspectRatio": "1:1",
					"aspectMode": "cover",
					"align": "center"
				},
				{
					"type": "text",
					"text": "สแกน QR Code เพื่อเชื่อมต่อ",
					"size": "xxs",
					"color": "#aaaaaa",
					"align": "center",
					"margin": "sm"
				},
				{
					"type": "box",
					"layout": "vertical",
					"margin": "lg",
					"spacing": "sm",
					"contents": [
						{
							"type": "box",
							"layout": "horizontal",
							"contents": [
								{ "type": "text", "text": "Network :", "color": "#888888", "size": "sm", "flex": 3, "align": "end" },
								{ "type": "filler" },
								{ "type": "text", "text": "Dorminet", "wrap": true, "color": "#111111", "size": "sm", "flex": 5, "weight": "bold" }
							]
						},
						{
							"type": "box",
							"layout": "horizontal",
							"contents": [
								{ "type": "text", "text": "Password :", "color": "#888888", "size": "sm", "flex": 3, "align": "end" },
								{ "type": "filler" },
								{ "type": "text", "text": "999999999", "wrap": true, "color": "#111111", "size": "sm", "flex": 5, "weight": "bold" }
							]
						}
					]
				}
			]
		},
		"footer": {
			"type": "box",
			"layout": "vertical",
			"paddingTop": "none",
			"contents": [
				{
					"type": "text",
					"text": "พบปัญหาการใช้งาน แจ้งผ่านเมนู 'แจ้งซ่อม'",
					"wrap": true,
					"size": "xxs",
					"color": "#bbbbbb",
					"align": "center"
				}
			]
		}
	}`

	var contents map[string]interface{}
	json.Unmarshal([]byte(flexJSON), &contents)
	return contents
}

func buildServicesFlexMessage() map[string]interface{} {
	carouselJSON := `{
		"type": "carousel",
		"contents": [
			{
				"type": "bubble",
				"size": "mega",
				"hero": {
					"type": "image",
					"url": "https://images.unsplash.com/photo-1546833999-b9f581a1996d?auto=format&fit=crop&w=600&q=80",
					"size": "full",
					"aspectRatio": "20:13",
					"aspectMode": "cover"
				},
				"body": {
					"type": "box",
					"layout": "vertical",
					"contents": [
						{
							"type": "text",
							"text": "สเต็ก นิวยอร์ก",
							"weight": "bold",
							"size": "xl"
						},
						{
							"type": "text",
							"text": "STEAK NEW YORK (อุบลราชธานี)",
							"size": "xs",
							"color": "#888888",
							"margin": "xs"
						},
						{
							"type": "separator",
							"margin": "lg"
						},
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
										{ "type": "text", "text": "เวลา", "color": "#888888", "size": "sm", "flex": 2 },
										{ "type": "text", "text": "11:00 - 21:00 น.", "wrap": true, "color": "#111111", "size": "sm", "flex": 5 }
									]
								},
								{
									"type": "box",
									"layout": "baseline",
									"spacing": "sm",
									"contents": [
										{ "type": "text", "text": "ราคา", "color": "#888888", "size": "sm", "flex": 2 },
										{ "type": "text", "text": "เริ่มต้น 59 บาท", "wrap": true, "color": "#111111", "size": "sm", "flex": 5 }
									]
								},
								{
									"type": "box",
									"layout": "baseline",
									"spacing": "sm",
									"contents": [
										{ "type": "text", "text": "ระยะทาง", "color": "#888888", "size": "sm", "flex": 2 },
										{ "type": "text", "text": "800 เมตร (เดิน 10 นาที)", "wrap": true, "color": "#111111", "size": "sm", "flex": 5 }
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
							"margin": "md",
							"contents": [
								{
									"type": "text",
									"text": "เลื่อนขวาเพื่อดูแผนที่เส้นทาง >",
									"color": "#007aff",
									"size": "xs",
									"align": "center",
									"weight": "bold"
								}
							]
						}
					]
				}
			},
			{
				"type": "bubble",
				"size": "mega",
				"hero": {
					"type": "image",
					"url": "https://files.catbox.moe/rtclws.png",
					"size": "full",
					"aspectRatio": "20:20",
					"aspectMode": "cover"
				},
				"body": {
					"type": "box",
					"layout": "vertical",
					"contents": [
						{
							"type": "text",
							"text": "แผนที่การเดินทาง",
							"weight": "bold",
							"size": "lg",
							"color": "#111111"
						},
						{
							"type": "text",
							"text": "เส้นทางจากหอพัก นิสิตาเพลส ไป สเต็กนิวยอร์ก",
							"size": "xs",
							"color": "#888888",
							"margin": "xs"
						},
						{
							"type": "box",
							"layout": "vertical",
							"margin": "lg",
							"spacing": "sm",
							"contents": [
								{
									"type": "box",
									"layout": "horizontal",
									"contents": [
										{ "type": "text", "text": "1.", "size": "sm", "flex": 1, "color": "#111111", "weight": "bold" },
										{ "type": "text", "text": "เริ่มจากหน้าหอพัก เลี้ยวซ้ายไปทางถนนสุขาสงเคราะห์ 2", "wrap": true, "size": "sm", "flex": 8, "color": "#555555" }
									]
								},
								{
									"type": "box",
									"layout": "horizontal",
									"contents": [
										{ "type": "text", "text": "2.", "size": "sm", "flex": 1, "color": "#111111", "weight": "bold" },
										{ "type": "text", "text": "ตรงไปแล้วเลี้ยวขวาเข้าซอยธรรมวิถี 4", "wrap": true, "size": "sm", "flex": 8, "color": "#555555" }
									]
								},
								{
									"type": "box",
									"layout": "horizontal",
									"contents": [
										{ "type": "text", "text": "3.", "size": "sm", "flex": 1, "color": "#111111", "weight": "bold" },
										{ "type": "text", "text": "ร้านจะอยู่ทางซ้ายมือ", "wrap": true, "size": "sm", "flex": 8, "color": "#111111", "weight": "bold" }
									]
								}
							]
						}
					]
				}
			}
		]
	}`

	var contents map[string]interface{}
	json.Unmarshal([]byte(carouselJSON), &contents)
	return contents
}
