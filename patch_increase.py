import json

with open("DormAppSwift_Sources/DormiNetX/DormiNetX/Localizable.xcstrings", "r", encoding="utf-8") as f:
    catalog = json.load(f)

strings = catalog.get("strings", {})
if "เพิ่ม" in strings and "localizations" in strings["เพิ่ม"] and "en" in strings["เพิ่ม"]["localizations"]:
    strings["เพิ่ม"]["localizations"]["en"]["stringUnit"]["value"] = "Add"
    
if "จัดการลูกบ้าน" in strings and "localizations" in strings["จัดการลูกบ้าน"] and "en" in strings["จัดการลูกบ้าน"]["localizations"]:
    strings["จัดการลูกบ้าน"]["localizations"]["en"]["stringUnit"]["value"] = "Tenants"
    
if "ภาพรวมระบบ" in strings and "localizations" in strings["ภาพรวมระบบ"] and "en" in strings["ภาพรวมระบบ"]["localizations"]:
    strings["ภาพรวมระบบ"]["localizations"]["en"]["stringUnit"]["value"] = "Overview"

if "ตั้งค่าราคา" in strings and "localizations" in strings["ตั้งค่าราคา"] and "en" in strings["ตั้งค่าราคา"]["localizations"]:
    strings["ตั้งค่าราคา"]["localizations"]["en"]["stringUnit"]["value"] = "Pricing"

if "แจ้งซ่อม" in strings and "localizations" in strings["แจ้งซ่อม"] and "en" in strings["แจ้งซ่อม"]["localizations"]:
    strings["แจ้งซ่อม"]["localizations"]["en"]["stringUnit"]["value"] = "Maintenance"

if "หลักฐานการโอน" in strings and "localizations" in strings["หลักฐานการโอน"] and "en" in strings["หลักฐานการโอน"]["localizations"]:
    strings["หลักฐานการโอน"]["localizations"]["en"]["stringUnit"]["value"] = "Transfers"

if "จัดการผู้ดูแลระบบ" in strings and "localizations" in strings["จัดการผู้ดูแลระบบ"] and "en" in strings["จัดการผู้ดูแลระบบ"]["localizations"]:
    strings["จัดการผู้ดูแลระบบ"]["localizations"]["en"]["stringUnit"]["value"] = "Admin Management"
    
if "ข้อมูลผู้ดูแลระบบ" in strings and "localizations" in strings["ข้อมูลผู้ดูแลระบบ"] and "en" in strings["ข้อมูลผู้ดูแลระบบ"]["localizations"]:
    strings["ข้อมูลผู้ดูแลระบบ"]["localizations"]["en"]["stringUnit"]["value"] = "Admin Info"

with open("DormAppSwift_Sources/DormiNetX/DormiNetX/Localizable.xcstrings", "w", encoding="utf-8") as f:
    json.dump(catalog, f, ensure_ascii=False, indent=2)

print("Patch complete")
