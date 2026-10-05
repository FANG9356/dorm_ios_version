import json
import os

with open("/Volumes/FangB/dorm_project/missing_static_thai.json", "r", encoding="utf-8") as f:
    missing_strings = json.load(f)

with open("/Volumes/FangB/dorm_project/DormAppSwift_Sources/DormiNetX/DormiNetX/Localizable.xcstrings", "r", encoding="utf-8") as f:
    catalog = json.load(f)

strings = catalog.setdefault("strings", {})

# Known translations from screenshots and common UI
known_translations = {
    "อัตราการเข้าพัก": "Occupancy Rate",
    "ห้องว่าง": "Available Rooms",
    "เงินสดรับเดือนนี้": "Cash Received This Month",
    "ยอดเก็บรอบบิลนี้": "Billed This Cycle",
    "มัดจำแรกเข้า": "Initial Deposit",
    "บิลค้างชำระ": "Unpaid Bills",
    "เข้าสู่ระบบไม่สำเร็จ กรุณาตรวจสอบอีเมลและรหัสผ่าน": "Login failed. Please check your email and password.",
    "ภาพรวมระบบ": "Overview",
    "จัดการลูกบ้าน": "Tenants",
    "การเงินและชำระเงิน": "Finance",
    "บิลค่าใช้จ่าย (เข้า-ออก)": "Bills (In-Out)",
    "จัดการห้องพัก": "Rooms",
    "ตั้งค่าราคา": "Pricing",
    "หลักฐานการโอน": "Transfers",
    "แจ้งซ่อม": "Maintenance",
    "จัดการผู้ดูแลระบบ": "Admin Management",
    "ข้อมูลผู้ดูแลระบบ": "Admin Info",
    "ตั้งค่าพื้นหลัง": "Background Settings",
    "ไอคอนแอพ": "App Icon",
    "ออกจากระบบ...": "Logging out...",
    "ภาษาของระบบ": "System Language",
    "ตั้งค่าแอพพลิเคชัน": "App Settings",
    "เกี่ยวกับ": "About",
    "เวอร์ชัน": "Version"
}

added_count = 0
for s in missing_strings:
    if s not in strings:
        strings[s] = {
            "extractionState": "manual",
            "localizations": {}
        }
        
        if s in known_translations:
            strings[s]["localizations"]["en"] = {
                "stringUnit": {
                    "state": "translated",
                    "value": known_translations[s]
                }
            }
        
        added_count += 1

with open("/Volumes/FangB/dorm_project/DormAppSwift_Sources/DormiNetX/DormiNetX/Localizable.xcstrings", "w", encoding="utf-8") as f:
    json.dump(catalog, f, ensure_ascii=False, indent=2)

print(f"Added {added_count} strings to Localizable.xcstrings.")
