import json
import urllib.request
import urllib.parse
import time
import sys

def translate_th_en(text):
    if not text:
        return ""
    try:
        url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=th&tl=en&dt=t&q=" + urllib.parse.quote(text)
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=5) as response:
            result = json.loads(response.read().decode('utf-8'))
            return "".join([x[0] for x in result[0]])
    except Exception as e:
        print(f"Error translating '{text}': {e}", file=sys.stderr)
        return text

# Load keys
with open("keys_to_translate.json", "r", encoding="utf-8") as f:
    keys = json.load(f)

print(f"Starting translation of {len(keys)} items...")
translations = {}
for i, key in enumerate(keys):
    # Some hardcoded overrides for perfect context
    if key == "พร้อมเพย์":
        translations[key] = "PromptPay"
    elif key == "ชื่อ":
        translations[key] = "First Name"
    elif key == "นามสกุล":
        translations[key] = "Last Name"
    elif key == "เลขห้อง":
        translations[key] = "Room Number"
    elif key == "เงินมัดจำ":
        translations[key] = "Deposit"
    elif key == "ค่าเช่า":
        translations[key] = "Rent"
    elif key == "งานซ่อม":
        translations[key] = "Maintenance"
    elif key == "รอดำเนินการ":
        translations[key] = "Pending"
    elif key == "รอตรวจสอบชำระเงิน":
        translations[key] = "Pending Payment"
    elif key == "รหัสผ่าน":
        translations[key] = "Password"
    elif key == "ตั้งค่า":
        translations[key] = "Settings"
    elif key == "ออกจากระบบ":
        translations[key] = "Logout"
    elif "%" in key or "@" in key:
        # Avoid breaking format strings, just translate parts or keep as is
        # Actually Google Translate might mess up format strings, so we handle it carefully
        # Simple string replace for %@ and %lld
        clean_key = key.replace("%@", "XSTRX").replace("%lld", "XNUMX")
        res = translate_th_en(clean_key)
        translations[key] = res.replace("XSTRX", "%@").replace("XNUMX", "%lld").replace("xstrx", "%@").replace("xnumx", "%lld")
    else:
        translations[key] = translate_th_en(key)
    
    if i % 20 == 0:
        print(f"Translated {i}/{len(keys)}...")
    time.sleep(0.1) # Be nice to the API

print("Translation done. Patching Localizable.xcstrings...")

# Patch the catalog
with open("DormAppSwift_Sources/DormiNetX/DormiNetX/Localizable.xcstrings", "r", encoding="utf-8") as f:
    catalog = json.load(f)

strings = catalog.get("strings", {})
for k, v in translations.items():
    if k in strings:
        if "localizations" not in strings[k]:
            strings[k]["localizations"] = {}
        strings[k]["localizations"]["en"] = {
            "stringUnit": {
                "state": "translated",
                "value": v
            }
        }
        # Also ensure 'th' is set explicitly so Thai falls back to itself instead of English if needed
        # But 'en' is the target we care about right now.

with open("DormAppSwift_Sources/DormiNetX/DormiNetX/Localizable.xcstrings", "w", encoding="utf-8") as f:
    json.dump(catalog, f, ensure_ascii=False, indent=2)

print("Patch complete!")
