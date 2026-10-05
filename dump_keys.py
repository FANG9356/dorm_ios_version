import json

with open("DormAppSwift_Sources/DormiNetX/DormiNetX/Localizable.xcstrings", "r", encoding="utf-8") as f:
    data = json.load(f)

strings = data.get("strings", {})
keys = []
for k, v in strings.items():
    locs = v.get("localizations", {})
    # if it's not translated to 'en' (or if we just want to translate everything that looks like Thai)
    if "en" not in locs or locs["en"].get("stringUnit", {}).get("state") != "translated":
        if any("\u0E00" <= c <= "\u0E7F" for c in k): # Has Thai characters
            keys.append(k)

with open("keys_to_translate.json", "w", encoding="utf-8") as f:
    json.dump(keys, f, ensure_ascii=False, indent=2)

print(f"Extracted {len(keys)} Thai keys.")
