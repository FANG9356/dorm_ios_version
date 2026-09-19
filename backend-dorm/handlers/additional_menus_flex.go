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
                "url": "https://images.unsplash.com/photo-1600891964092-4316c288032e?auto=format&fit=crop&w=800&q=80",
                "size": "full",
                "aspectRatio": "20:13",
                "aspectMode": "cover"
            },
            "body": {
                "type": "box",
                "layout": "vertical",
                "paddingAll": "20px",
                "contents": [
                    {
                        "type": "text",
                        "text": "สเต็ก นิวยอร์ก",
                        "weight": "bold",
                        "size": "xl",
                        "color": "#1f1f1f"
                    },
                    {
                        "type": "text",
                        "text": "STEAK NEW YORK (อุบลราชธานี)",
                        "size": "xs",
                        "color": "#aaaaaa",
                        "margin": "xs"
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
                        "spacing": "md",
                        "contents": [
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "text",
                                        "text": "เวลา",
                                        "color": "#aaaaaa",
                                        "size": "sm",
                                        "flex": 2
                                    },
                                    {
                                        "type": "text",
                                        "text": "11:00 - 21:00 น.",
                                        "color": "#333333",
                                        "size": "sm",
                                        "flex": 5,
                                        "weight": "bold"
                                    }
                                ]
                            },
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "text",
                                        "text": "ราคา",
                                        "color": "#aaaaaa",
                                        "size": "sm",
                                        "flex": 2
                                    },
                                    {
                                        "type": "text",
                                        "text": "เริ่มต้น 59 บาท",
                                        "color": "#333333",
                                        "size": "sm",
                                        "flex": 5,
                                        "weight": "bold"
                                    }
                                ]
                            },
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "text",
                                        "text": "ติดต่อ",
                                        "color": "#aaaaaa",
                                        "size": "sm",
                                        "flex": 2
                                    },
                                    {
                                        "type": "text",
                                        "text": "081-234-5678",
                                        "color": "#333333",
                                        "size": "sm",
                                        "flex": 5,
                                        "weight": "bold"
                                    }
                                ]
                            }
                        ]
                    },
                    {
                        "type": "box",
                        "layout": "vertical",
                        "margin": "lg",
                        "spacing": "sm",
                        "contents": [
                            {
                                "type": "text",
                                "text": "เมนูแนะนำ",
                                "color": "#1f1f1f",
                                "size": "sm",
                                "weight": "bold"
                            },
                            {
                                "type": "text",
                                "text": "• สเต็กเนื้อโคขุนพริกไทยดำ\n• สเต็กพอร์คชอปสูตรพิเศษ\n• สลัดผักออร์แกนิก",
                                "wrap": true,
                                "color": "#555555",
                                "size": "sm",
                                "margin": "sm"
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
                "paddingAll": "20px",
                "contents": [
                    {
                        "type": "text",
                        "text": "แผนที่การเดินทาง",
                        "weight": "bold",
                        "size": "lg",
                        "color": "#1f1f1f"
                    },
                    {
                        "type": "text",
                        "text": "จากหอพัก -> สเต็ก",
                        "size": "xs",
                        "color": "#aaaaaa",
                        "margin": "xs"
                    },
                    {
                        "type": "box",
                        "layout": "vertical",
                        "margin": "xl",
                        "spacing": "none",
                        "contents": [
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "width": "24px",
                                        "alignItems": "center",
                                        "contents": [
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "12px",
                                                "height": "12px",
                                                "cornerRadius": "6px",
                                                "backgroundColor": "#aaaaaa",
                                                "margin": "sm",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            },
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "2px",
                                                "flex": 1,
                                                "backgroundColor": "#dddddd",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            }
                                        ]
                                    },
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "flex": 1,
                                        "paddingBottom": "16px",
                                        "paddingTop": "2px",
                                        "contents": [
                                            {
                                                "type": "text",
                                                "text": "เริ่มจากหน้าหอพัก เลี้ยวซ้ายไปทางถนนสุขาสงเคราะห์ 2",
                                                "wrap": true,
                                                "size": "sm",
                                                "color": "#555555"
                                            }
                                        ]
                                    }
                                ]
                            },
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "width": "24px",
                                        "alignItems": "center",
                                        "contents": [
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "12px",
                                                "height": "12px",
                                                "cornerRadius": "6px",
                                                "backgroundColor": "#aaaaaa",
                                                "margin": "sm",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            },
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "2px",
                                                "flex": 1,
                                                "backgroundColor": "#dddddd",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            }
                                        ]
                                    },
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "flex": 1,
                                        "paddingBottom": "16px",
                                        "paddingTop": "0px",
                                        "contents": [
                                            {
                                                "type": "text",
                                                "text": "ตรงไปแล้วเลี้ยวขวาเข้าซอยธรรมวิถี 4",
                                                "wrap": true,
                                                "size": "sm",
                                                "color": "#555555"
                                            }
                                        ]
                                    }
                                ]
                            },
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "width": "24px",
                                        "alignItems": "center",
                                        "contents": [
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "16px",
                                                "height": "16px",
                                                "cornerRadius": "8px",
                                                "backgroundColor": "#007aff",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            }
                                        ]
                                    },
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "flex": 1,
                                        "contents": [
                                            {
                                                "type": "text",
                                                "text": "ร้านจะอยู่ทางซ้ายมือ",
                                                "wrap": true,
                                                "size": "sm",
                                                "color": "#111111",
                                                "weight": "bold"
                                            },
                                            {
                                                "type": "text",
                                                "text": "ระยะทาง 800 เมตร (เดิน 10 นาที)",
                                                "size": "xs",
                                                "color": "#888888",
                                                "margin": "xs"
                                            }
                                        ]
                                    }
                                ]
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
                "url": "https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=800&q=80",
                "size": "full",
                "aspectRatio": "20:13",
                "aspectMode": "cover"
            },
            "body": {
                "type": "box",
                "layout": "vertical",
                "paddingAll": "20px",
                "contents": [
                    {
                        "type": "text",
                        "text": "Café Amazon",
                        "weight": "bold",
                        "size": "xl",
                        "color": "#1f1f1f"
                    },
                    {
                        "type": "text",
                        "text": "สาขาตลาดหนองบัว (อุบลราชธานี)",
                        "size": "xs",
                        "color": "#aaaaaa",
                        "margin": "xs"
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
                        "spacing": "md",
                        "contents": [
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "text",
                                        "text": "เวลา",
                                        "color": "#aaaaaa",
                                        "size": "sm",
                                        "flex": 2
                                    },
                                    {
                                        "type": "text",
                                        "text": "06:00 - 20:00 น.",
                                        "color": "#333333",
                                        "size": "sm",
                                        "flex": 5,
                                        "weight": "bold"
                                    }
                                ]
                            },
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "text",
                                        "text": "ราคา",
                                        "color": "#aaaaaa",
                                        "size": "sm",
                                        "flex": 2
                                    },
                                    {
                                        "type": "text",
                                        "text": "เริ่มต้น 45 บาท",
                                        "color": "#333333",
                                        "size": "sm",
                                        "flex": 5,
                                        "weight": "bold"
                                    }
                                ]
                            },
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "text",
                                        "text": "ติดต่อ",
                                        "color": "#aaaaaa",
                                        "size": "sm",
                                        "flex": 2
                                    },
                                    {
                                        "type": "text",
                                        "text": "045-111-222",
                                        "color": "#333333",
                                        "size": "sm",
                                        "flex": 5,
                                        "weight": "bold"
                                    }
                                ]
                            }
                        ]
                    },
                    {
                        "type": "box",
                        "layout": "vertical",
                        "margin": "lg",
                        "spacing": "sm",
                        "contents": [
                            {
                                "type": "text",
                                "text": "เมนูแนะนำ",
                                "color": "#1f1f1f",
                                "size": "sm",
                                "weight": "bold"
                            },
                            {
                                "type": "text",
                                "text": "• อเมซอนเย็น (Amazon Cold)\n• แบล็คคอฟฟี่น้ำผึ้งมะนาว\n• ชาเขียวนมเย็น",
                                "wrap": true,
                                "color": "#555555",
                                "size": "sm",
                                "margin": "sm"
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
                "url": "https://files.catbox.moe/8rsaqm.png",
                "size": "full",
                "aspectRatio": "20:20",
                "aspectMode": "cover"
            },
            "body": {
                "type": "box",
                "layout": "vertical",
                "paddingAll": "20px",
                "contents": [
                    {
                        "type": "text",
                        "text": "แผนที่การเดินทาง",
                        "weight": "bold",
                        "size": "lg",
                        "color": "#1f1f1f"
                    },
                    {
                        "type": "text",
                        "text": "จากหอพัก -> Café",
                        "size": "xs",
                        "color": "#aaaaaa",
                        "margin": "xs"
                    },
                    {
                        "type": "box",
                        "layout": "vertical",
                        "margin": "xl",
                        "spacing": "none",
                        "contents": [
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "width": "24px",
                                        "alignItems": "center",
                                        "contents": [
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "12px",
                                                "height": "12px",
                                                "cornerRadius": "6px",
                                                "backgroundColor": "#aaaaaa",
                                                "margin": "sm",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            },
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "2px",
                                                "flex": 1,
                                                "backgroundColor": "#dddddd",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            }
                                        ]
                                    },
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "flex": 1,
                                        "paddingBottom": "16px",
                                        "paddingTop": "2px",
                                        "contents": [
                                            {
                                                "type": "text",
                                                "text": "เริ่มจากหน้าหอพัก เลี้ยวซ้ายไปตามถนนสุขาสงเคราะห์ 2",
                                                "wrap": true,
                                                "size": "sm",
                                                "color": "#555555"
                                            }
                                        ]
                                    }
                                ]
                            },
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "width": "24px",
                                        "alignItems": "center",
                                        "contents": [
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "12px",
                                                "height": "12px",
                                                "cornerRadius": "6px",
                                                "backgroundColor": "#aaaaaa",
                                                "margin": "sm",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            },
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "2px",
                                                "flex": 1,
                                                "backgroundColor": "#dddddd",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            }
                                        ]
                                    },
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "flex": 1,
                                        "paddingBottom": "16px",
                                        "paddingTop": "0px",
                                        "contents": [
                                            {
                                                "type": "text",
                                                "text": "เลี้ยวซ้ายตรงสี่แยกเข้าสู่ถนนชยางกูร",
                                                "wrap": true,
                                                "size": "sm",
                                                "color": "#555555"
                                            }
                                        ]
                                    }
                                ]
                            },
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "width": "24px",
                                        "alignItems": "center",
                                        "contents": [
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "16px",
                                                "height": "16px",
                                                "cornerRadius": "8px",
                                                "backgroundColor": "#007aff",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            }
                                        ]
                                    },
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "flex": 1,
                                        "contents": [
                                            {
                                                "type": "text",
                                                "text": "ร้านจะอยู่ขวามือหน้าตลาดหนองบัว",
                                                "wrap": true,
                                                "size": "sm",
                                                "color": "#111111",
                                                "weight": "bold"
                                            },
                                            {
                                                "type": "text",
                                                "text": "ระยะทาง 950 เมตร (เดิน 13 นาที)",
                                                "size": "xs",
                                                "color": "#888888",
                                                "margin": "xs"
                                            }
                                        ]
                                    }
                                ]
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
                "url": "https://images.unsplash.com/photo-1580913428706-c311e67898b3?auto=format&fit=crop&w=800&q=80",
                "size": "full",
                "aspectRatio": "20:13",
                "aspectMode": "cover"
            },
            "body": {
                "type": "box",
                "layout": "vertical",
                "paddingAll": "20px",
                "contents": [
                    {
                        "type": "text",
                        "text": "7-Eleven",
                        "weight": "bold",
                        "size": "xl",
                        "color": "#1f1f1f"
                    },
                    {
                        "type": "text",
                        "text": "สาขาสุขาสงเคราะห์ 2",
                        "size": "xs",
                        "color": "#aaaaaa",
                        "margin": "xs"
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
                        "spacing": "md",
                        "contents": [
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "text",
                                        "text": "เวลา",
                                        "color": "#aaaaaa",
                                        "size": "sm",
                                        "flex": 2
                                    },
                                    {
                                        "type": "text",
                                        "text": "เปิด 24 ชั่วโมง",
                                        "color": "#333333",
                                        "size": "sm",
                                        "flex": 5,
                                        "weight": "bold"
                                    }
                                ]
                            },
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "text",
                                        "text": "ราคา",
                                        "color": "#aaaaaa",
                                        "size": "sm",
                                        "flex": 2
                                    },
                                    {
                                        "type": "text",
                                        "text": "ตามป้าย",
                                        "color": "#333333",
                                        "size": "sm",
                                        "flex": 5,
                                        "weight": "bold"
                                    }
                                ]
                            },
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "text",
                                        "text": "ติดต่อ",
                                        "color": "#aaaaaa",
                                        "size": "sm",
                                        "flex": 2
                                    },
                                    {
                                        "type": "text",
                                        "text": "-",
                                        "color": "#333333",
                                        "size": "sm",
                                        "flex": 5,
                                        "weight": "bold"
                                    }
                                ]
                            }
                        ]
                    },
                    {
                        "type": "box",
                        "layout": "vertical",
                        "margin": "lg",
                        "spacing": "sm",
                        "contents": [
                            {
                                "type": "text",
                                "text": "บริการแนะนำ",
                                "color": "#1f1f1f",
                                "size": "sm",
                                "weight": "bold"
                            },
                            {
                                "type": "text",
                                "text": "• ตู้ ATM\n• เคาน์เตอร์เซอร์วิส\n• อาหารอุ่นร้อน 24 ชม.",
                                "wrap": true,
                                "color": "#555555",
                                "size": "sm",
                                "margin": "sm"
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
                "url": "https://files.catbox.moe/6eux98.png",
                "size": "full",
                "aspectRatio": "20:20",
                "aspectMode": "cover"
            },
            "body": {
                "type": "box",
                "layout": "vertical",
                "paddingAll": "20px",
                "contents": [
                    {
                        "type": "text",
                        "text": "แผนที่การเดินทาง",
                        "weight": "bold",
                        "size": "lg",
                        "color": "#1f1f1f"
                    },
                    {
                        "type": "text",
                        "text": "จากหอพัก -> 7-Eleven",
                        "size": "xs",
                        "color": "#aaaaaa",
                        "margin": "xs"
                    },
                    {
                        "type": "box",
                        "layout": "vertical",
                        "margin": "xl",
                        "spacing": "none",
                        "contents": [
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "width": "24px",
                                        "alignItems": "center",
                                        "contents": [
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "12px",
                                                "height": "12px",
                                                "cornerRadius": "6px",
                                                "backgroundColor": "#aaaaaa",
                                                "margin": "sm",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            },
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "2px",
                                                "flex": 1,
                                                "backgroundColor": "#dddddd",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            }
                                        ]
                                    },
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "flex": 1,
                                        "paddingBottom": "16px",
                                        "paddingTop": "2px",
                                        "contents": [
                                            {
                                                "type": "text",
                                                "text": "เริ่มจากหน้าหอพัก เลี้ยวขวา",
                                                "wrap": true,
                                                "size": "sm",
                                                "color": "#555555"
                                            }
                                        ]
                                    }
                                ]
                            },
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "width": "24px",
                                        "alignItems": "center",
                                        "contents": [
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "12px",
                                                "height": "12px",
                                                "cornerRadius": "6px",
                                                "backgroundColor": "#aaaaaa",
                                                "margin": "sm",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            },
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "2px",
                                                "flex": 1,
                                                "backgroundColor": "#dddddd",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            }
                                        ]
                                    },
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "flex": 1,
                                        "paddingBottom": "16px",
                                        "paddingTop": "0px",
                                        "contents": [
                                            {
                                                "type": "text",
                                                "text": "เดินตรงไปประมาณ 200 เมตร",
                                                "wrap": true,
                                                "size": "sm",
                                                "color": "#555555"
                                            }
                                        ]
                                    }
                                ]
                            },
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "width": "24px",
                                        "alignItems": "center",
                                        "contents": [
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "16px",
                                                "height": "16px",
                                                "cornerRadius": "8px",
                                                "backgroundColor": "#007aff",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            }
                                        ]
                                    },
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "flex": 1,
                                        "contents": [
                                            {
                                                "type": "text",
                                                "text": "เซเว่นจะอยู่ตรงปากซอยทางซ้ายมือ",
                                                "wrap": true,
                                                "size": "sm",
                                                "color": "#111111",
                                                "weight": "bold"
                                            },
                                            {
                                                "type": "text",
                                                "text": "ระยะทาง 200 เมตร (เดิน 3 นาที)",
                                                "size": "xs",
                                                "color": "#888888",
                                                "margin": "xs"
                                            }
                                        ]
                                    }
                                ]
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
                "url": "https://images.unsplash.com/photo-1545173168-9f1947eebb7f?auto=format&fit=crop&w=800&q=80",
                "size": "full",
                "aspectRatio": "20:13",
                "aspectMode": "cover"
            },
            "body": {
                "type": "box",
                "layout": "vertical",
                "paddingAll": "20px",
                "contents": [
                    {
                        "type": "text",
                        "text": "Wash & Dry",
                        "weight": "bold",
                        "size": "xl",
                        "color": "#1f1f1f"
                    },
                    {
                        "type": "text",
                        "text": "ร้านซักแห้ง / ซักรีด ใกล้หอพัก",
                        "size": "xs",
                        "color": "#aaaaaa",
                        "margin": "xs"
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
                        "spacing": "md",
                        "contents": [
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "text",
                                        "text": "เวลา",
                                        "color": "#aaaaaa",
                                        "size": "sm",
                                        "flex": 2
                                    },
                                    {
                                        "type": "text",
                                        "text": "08:00 - 20:00 น.",
                                        "color": "#333333",
                                        "size": "sm",
                                        "flex": 5,
                                        "weight": "bold"
                                    }
                                ]
                            },
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "text",
                                        "text": "ราคา",
                                        "color": "#aaaaaa",
                                        "size": "sm",
                                        "flex": 2
                                    },
                                    {
                                        "type": "text",
                                        "text": "เริ่มต้น 10 บาท/ชิ้น",
                                        "color": "#333333",
                                        "size": "sm",
                                        "flex": 5,
                                        "weight": "bold"
                                    }
                                ]
                            },
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "text",
                                        "text": "ติดต่อ",
                                        "color": "#aaaaaa",
                                        "size": "sm",
                                        "flex": 2
                                    },
                                    {
                                        "type": "text",
                                        "text": "089-999-8888",
                                        "color": "#333333",
                                        "size": "sm",
                                        "flex": 5,
                                        "weight": "bold"
                                    }
                                ]
                            }
                        ]
                    },
                    {
                        "type": "box",
                        "layout": "vertical",
                        "margin": "lg",
                        "spacing": "sm",
                        "contents": [
                            {
                                "type": "text",
                                "text": "บริการแนะนำ",
                                "color": "#1f1f1f",
                                "size": "sm",
                                "weight": "bold"
                            },
                            {
                                "type": "text",
                                "text": "• ซักรีดชุดนักศึกษา\n• ซักแห้งสูท\n• อบผ้าแห้งด่วน",
                                "wrap": true,
                                "color": "#555555",
                                "size": "sm",
                                "margin": "sm"
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
                "url": "https://files.catbox.moe/6eux98.png",
                "size": "full",
                "aspectRatio": "20:20",
                "aspectMode": "cover"
            },
            "body": {
                "type": "box",
                "layout": "vertical",
                "paddingAll": "20px",
                "contents": [
                    {
                        "type": "text",
                        "text": "แผนที่การเดินทาง",
                        "weight": "bold",
                        "size": "lg",
                        "color": "#1f1f1f"
                    },
                    {
                        "type": "text",
                        "text": "จากหอพัก -> Wash",
                        "size": "xs",
                        "color": "#aaaaaa",
                        "margin": "xs"
                    },
                    {
                        "type": "box",
                        "layout": "vertical",
                        "margin": "xl",
                        "spacing": "none",
                        "contents": [
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "width": "24px",
                                        "alignItems": "center",
                                        "contents": [
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "12px",
                                                "height": "12px",
                                                "cornerRadius": "6px",
                                                "backgroundColor": "#aaaaaa",
                                                "margin": "sm",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            },
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "2px",
                                                "flex": 1,
                                                "backgroundColor": "#dddddd",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            }
                                        ]
                                    },
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "flex": 1,
                                        "paddingBottom": "16px",
                                        "paddingTop": "2px",
                                        "contents": [
                                            {
                                                "type": "text",
                                                "text": "เดินออกจากหอพัก เลี้ยวซ้าย",
                                                "wrap": true,
                                                "size": "sm",
                                                "color": "#555555"
                                            }
                                        ]
                                    }
                                ]
                            },
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "width": "24px",
                                        "alignItems": "center",
                                        "contents": [
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "12px",
                                                "height": "12px",
                                                "cornerRadius": "6px",
                                                "backgroundColor": "#aaaaaa",
                                                "margin": "sm",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            },
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "2px",
                                                "flex": 1,
                                                "backgroundColor": "#dddddd",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            }
                                        ]
                                    },
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "flex": 1,
                                        "paddingBottom": "16px",
                                        "paddingTop": "0px",
                                        "contents": [
                                            {
                                                "type": "text",
                                                "text": "ข้ามถนนไปฝั่งตรงข้าม",
                                                "wrap": true,
                                                "size": "sm",
                                                "color": "#555555"
                                            }
                                        ]
                                    }
                                ]
                            },
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "width": "24px",
                                        "alignItems": "center",
                                        "contents": [
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "16px",
                                                "height": "16px",
                                                "cornerRadius": "8px",
                                                "backgroundColor": "#007aff",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            }
                                        ]
                                    },
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "flex": 1,
                                        "contents": [
                                            {
                                                "type": "text",
                                                "text": "ร้านอยู่ติดกับร้านขายยา",
                                                "wrap": true,
                                                "size": "sm",
                                                "color": "#111111",
                                                "weight": "bold"
                                            },
                                            {
                                                "type": "text",
                                                "text": "ระยะทาง 150 เมตร (เดิน 2 นาที)",
                                                "size": "xs",
                                                "color": "#888888",
                                                "margin": "xs"
                                            }
                                        ]
                                    }
                                ]
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
                "url": "https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?auto=format&fit=crop&w=800&q=80",
                "size": "full",
                "aspectRatio": "20:13",
                "aspectMode": "cover"
            },
            "body": {
                "type": "box",
                "layout": "vertical",
                "paddingAll": "20px",
                "contents": [
                    {
                        "type": "text",
                        "text": "ฟาร์มาซี เฮลท์แคร์",
                        "weight": "bold",
                        "size": "xl",
                        "color": "#1f1f1f"
                    },
                    {
                        "type": "text",
                        "text": "ร้านขายยาและเวชภัณฑ์",
                        "size": "xs",
                        "color": "#aaaaaa",
                        "margin": "xs"
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
                        "spacing": "md",
                        "contents": [
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "text",
                                        "text": "เวลา",
                                        "color": "#aaaaaa",
                                        "size": "sm",
                                        "flex": 2
                                    },
                                    {
                                        "type": "text",
                                        "text": "09:00 - 22:00 น.",
                                        "color": "#333333",
                                        "size": "sm",
                                        "flex": 5,
                                        "weight": "bold"
                                    }
                                ]
                            },
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "text",
                                        "text": "ราคา",
                                        "color": "#aaaaaa",
                                        "size": "sm",
                                        "flex": 2
                                    },
                                    {
                                        "type": "text",
                                        "text": "มาตรฐาน",
                                        "color": "#333333",
                                        "size": "sm",
                                        "flex": 5,
                                        "weight": "bold"
                                    }
                                ]
                            },
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "text",
                                        "text": "ติดต่อ",
                                        "color": "#aaaaaa",
                                        "size": "sm",
                                        "flex": 2
                                    },
                                    {
                                        "type": "text",
                                        "text": "045-333-444",
                                        "color": "#333333",
                                        "size": "sm",
                                        "flex": 5,
                                        "weight": "bold"
                                    }
                                ]
                            }
                        ]
                    },
                    {
                        "type": "box",
                        "layout": "vertical",
                        "margin": "lg",
                        "spacing": "sm",
                        "contents": [
                            {
                                "type": "text",
                                "text": "บริการแนะนำ",
                                "color": "#1f1f1f",
                                "size": "sm",
                                "weight": "bold"
                            },
                            {
                                "type": "text",
                                "text": "• ปรึกษาเภสัชกรฟรี\n• ยาสามัญประจำบ้าน\n• อุปกรณ์ทำแผล",
                                "wrap": true,
                                "color": "#555555",
                                "size": "sm",
                                "margin": "sm"
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
                "url": "https://files.catbox.moe/6eux98.png",
                "size": "full",
                "aspectRatio": "20:20",
                "aspectMode": "cover"
            },
            "body": {
                "type": "box",
                "layout": "vertical",
                "paddingAll": "20px",
                "contents": [
                    {
                        "type": "text",
                        "text": "แผนที่การเดินทาง",
                        "weight": "bold",
                        "size": "lg",
                        "color": "#1f1f1f"
                    },
                    {
                        "type": "text",
                        "text": "จากหอพัก -> ฟาร์มาซี",
                        "size": "xs",
                        "color": "#aaaaaa",
                        "margin": "xs"
                    },
                    {
                        "type": "box",
                        "layout": "vertical",
                        "margin": "xl",
                        "spacing": "none",
                        "contents": [
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "width": "24px",
                                        "alignItems": "center",
                                        "contents": [
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "12px",
                                                "height": "12px",
                                                "cornerRadius": "6px",
                                                "backgroundColor": "#aaaaaa",
                                                "margin": "sm",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            },
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "2px",
                                                "flex": 1,
                                                "backgroundColor": "#dddddd",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            }
                                        ]
                                    },
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "flex": 1,
                                        "paddingBottom": "16px",
                                        "paddingTop": "2px",
                                        "contents": [
                                            {
                                                "type": "text",
                                                "text": "เดินออกจากหอพัก เลี้ยวซ้าย",
                                                "wrap": true,
                                                "size": "sm",
                                                "color": "#555555"
                                            }
                                        ]
                                    }
                                ]
                            },
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "width": "24px",
                                        "alignItems": "center",
                                        "contents": [
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "12px",
                                                "height": "12px",
                                                "cornerRadius": "6px",
                                                "backgroundColor": "#aaaaaa",
                                                "margin": "sm",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            },
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "2px",
                                                "flex": 1,
                                                "backgroundColor": "#dddddd",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            }
                                        ]
                                    },
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "flex": 1,
                                        "paddingBottom": "16px",
                                        "paddingTop": "0px",
                                        "contents": [
                                            {
                                                "type": "text",
                                                "text": "ข้ามถนนไปฝั่งตรงข้าม",
                                                "wrap": true,
                                                "size": "sm",
                                                "color": "#555555"
                                            }
                                        ]
                                    }
                                ]
                            },
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "width": "24px",
                                        "alignItems": "center",
                                        "contents": [
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "16px",
                                                "height": "16px",
                                                "cornerRadius": "8px",
                                                "backgroundColor": "#007aff",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            }
                                        ]
                                    },
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "flex": 1,
                                        "contents": [
                                            {
                                                "type": "text",
                                                "text": "ร้านอยู่ติดกับร้านซักรีด",
                                                "wrap": true,
                                                "size": "sm",
                                                "color": "#111111",
                                                "weight": "bold"
                                            },
                                            {
                                                "type": "text",
                                                "text": "ระยะทาง 150 เมตร (เดิน 2 นาที)",
                                                "size": "xs",
                                                "color": "#888888",
                                                "margin": "xs"
                                            }
                                        ]
                                    }
                                ]
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
                "url": "https://images.unsplash.com/photo-1533900298318-6b8da08a523e?auto=format&fit=crop&w=800&q=80",
                "size": "full",
                "aspectRatio": "20:13",
                "aspectMode": "cover"
            },
            "body": {
                "type": "box",
                "layout": "vertical",
                "paddingAll": "20px",
                "contents": [
                    {
                        "type": "text",
                        "text": "ตลาดหนองบัว",
                        "weight": "bold",
                        "size": "xl",
                        "color": "#1f1f1f"
                    },
                    {
                        "type": "text",
                        "text": "ตลาดสดและสตรีทฟู้ด",
                        "size": "xs",
                        "color": "#aaaaaa",
                        "margin": "xs"
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
                        "spacing": "md",
                        "contents": [
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "text",
                                        "text": "เวลา",
                                        "color": "#aaaaaa",
                                        "size": "sm",
                                        "flex": 2
                                    },
                                    {
                                        "type": "text",
                                        "text": "05:00 - 20:00 น.",
                                        "color": "#333333",
                                        "size": "sm",
                                        "flex": 5,
                                        "weight": "bold"
                                    }
                                ]
                            },
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "text",
                                        "text": "ราคา",
                                        "color": "#aaaaaa",
                                        "size": "sm",
                                        "flex": 2
                                    },
                                    {
                                        "type": "text",
                                        "text": "ย่อมเยา",
                                        "color": "#333333",
                                        "size": "sm",
                                        "flex": 5,
                                        "weight": "bold"
                                    }
                                ]
                            },
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "text",
                                        "text": "ติดต่อ",
                                        "color": "#aaaaaa",
                                        "size": "sm",
                                        "flex": 2
                                    },
                                    {
                                        "type": "text",
                                        "text": "-",
                                        "color": "#333333",
                                        "size": "sm",
                                        "flex": 5,
                                        "weight": "bold"
                                    }
                                ]
                            }
                        ]
                    },
                    {
                        "type": "box",
                        "layout": "vertical",
                        "margin": "lg",
                        "spacing": "sm",
                        "contents": [
                            {
                                "type": "text",
                                "text": "ร้านแนะนำ",
                                "color": "#1f1f1f",
                                "size": "sm",
                                "weight": "bold"
                            },
                            {
                                "type": "text",
                                "text": "• ร้านหมูปิ้งเฮียอ้วน\n• น้ำเต้าหู้เจ๊ดา\n• ผลไม้สดตามฤดูกาล",
                                "wrap": true,
                                "color": "#555555",
                                "size": "sm",
                                "margin": "sm"
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
                "url": "https://files.catbox.moe/5jrdzx.png",
                "size": "full",
                "aspectRatio": "20:20",
                "aspectMode": "cover"
            },
            "body": {
                "type": "box",
                "layout": "vertical",
                "paddingAll": "20px",
                "contents": [
                    {
                        "type": "text",
                        "text": "แผนที่การเดินทาง",
                        "weight": "bold",
                        "size": "lg",
                        "color": "#1f1f1f"
                    },
                    {
                        "type": "text",
                        "text": "จากหอพัก -> ตลาดหนองบัว",
                        "size": "xs",
                        "color": "#aaaaaa",
                        "margin": "xs"
                    },
                    {
                        "type": "box",
                        "layout": "vertical",
                        "margin": "xl",
                        "spacing": "none",
                        "contents": [
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "width": "24px",
                                        "alignItems": "center",
                                        "contents": [
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "12px",
                                                "height": "12px",
                                                "cornerRadius": "6px",
                                                "backgroundColor": "#aaaaaa",
                                                "margin": "sm",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            },
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "2px",
                                                "flex": 1,
                                                "backgroundColor": "#dddddd",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            }
                                        ]
                                    },
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "flex": 1,
                                        "paddingBottom": "16px",
                                        "paddingTop": "2px",
                                        "contents": [
                                            {
                                                "type": "text",
                                                "text": "นั่งวินมอเตอร์ไซค์จากหน้าซอยหอพัก",
                                                "wrap": true,
                                                "size": "sm",
                                                "color": "#555555"
                                            }
                                        ]
                                    }
                                ]
                            },
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "width": "24px",
                                        "alignItems": "center",
                                        "contents": [
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "12px",
                                                "height": "12px",
                                                "cornerRadius": "6px",
                                                "backgroundColor": "#aaaaaa",
                                                "margin": "sm",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            },
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "2px",
                                                "flex": 1,
                                                "backgroundColor": "#dddddd",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            }
                                        ]
                                    },
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "flex": 1,
                                        "paddingBottom": "16px",
                                        "paddingTop": "0px",
                                        "contents": [
                                            {
                                                "type": "text",
                                                "text": "บอกวินว่าไป \"ตลาดหนองบัว\"",
                                                "wrap": true,
                                                "size": "sm",
                                                "color": "#555555"
                                            }
                                        ]
                                    }
                                ]
                            },
                            {
                                "type": "box",
                                "layout": "horizontal",
                                "contents": [
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "width": "24px",
                                        "alignItems": "center",
                                        "contents": [
                                            {
                                                "type": "box",
                                                "layout": "vertical",
                                                "width": "16px",
                                                "height": "16px",
                                                "cornerRadius": "8px",
                                                "backgroundColor": "#007aff",
                                                "contents": [
                                                    {
                                                        "type": "filler"
                                                    }
                                                ]
                                            }
                                        ]
                                    },
                                    {
                                        "type": "box",
                                        "layout": "vertical",
                                        "flex": 1,
                                        "contents": [
                                            {
                                                "type": "text",
                                                "text": "ตลาดอยู่ริมถนนใหญ่ชยางกูร",
                                                "wrap": true,
                                                "size": "sm",
                                                "color": "#111111",
                                                "weight": "bold"
                                            },
                                            {
                                                "type": "text",
                                                "text": "ระยะทาง 1.2 กิโลเมตร (นั่งวิน 3 นาที)",
                                                "size": "xs",
                                                "color": "#888888",
                                                "margin": "xs"
                                            }
                                        ]
                                    }
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
