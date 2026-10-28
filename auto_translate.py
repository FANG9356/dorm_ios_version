import json
import urllib.request
import urllib.parse
import time

def translate(text, tl):
    if not text.strip(): return text
    if "%@" in text or "%lld" in text or "%.0f" in text:
        pass
        
    url = f'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl={tl}&dt=t&q=' + urllib.parse.quote(text)
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        response = urllib.request.urlopen(req)
        result = json.loads(response.read().decode('utf-8'))
        trans = ''.join([part[0] for part in result[0]])
        trans = trans.replace("% @", "%@").replace("% lld", "%lld").replace(" %", "%")
        return trans
    except Exception as e:
        print('Error translating:', text, e)
        return text

with open("DormAppSwift_Sources/DormiNetX/DormiNetX/Localizable.xcstrings", "r") as f:
    catalog = json.load(f)

count = 0
for k, v in catalog["strings"].items():
    if "localizations" not in v:
        v["localizations"] = {}
        
    # Translate to English
    en = v["localizations"].get("en", {})
    if not en or en.get("stringUnit", {}).get("state") != "translated":
        translated_text = translate(k, "en")
        print(f"[EN] '{k}' -> '{translated_text}'")
        v["localizations"]["en"] = {
            "stringUnit": {
                "state": "translated",
                "value": translated_text
            }
        }
        count += 1
        time.sleep(0.1)
        
    # Translate to Thai
    th = v["localizations"].get("th", {})
    if not th or th.get("stringUnit", {}).get("state") != "translated":
        translated_text_th = translate(k, "th")
        print(f"[TH] '{k}' -> '{translated_text_th}'")
        v["localizations"]["th"] = {
            "stringUnit": {
                "state": "translated",
                "value": translated_text_th
            }
        }
        count += 1
        time.sleep(0.1)

with open("DormAppSwift_Sources/DormiNetX/DormiNetX/Localizable.xcstrings", "w") as f:
    json.dump(catalog, f, ensure_ascii=False, indent=2)

print(f"Translated {count} strings.")
