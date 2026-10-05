import json

with open("/Volumes/FangB/dorm_project/DormAppSwift_Sources/DormiNetX/DormiNetX/Localizable.xcstrings", "r", encoding="utf-8") as f:
    catalog = json.load(f)

strings = catalog.get("strings", {})

keys_to_delete = [
    " น.",
    " ฿",
    " เวลา ",
    ")) จริงหรือไม่?",
    ") จริงหรือไม่?",
    ")",
    " (",
    " - ",
    " %",
    "บาท"
]

# Let's also find keys that are just the same as another key but with leading/trailing spaces
# and delete the one with leading/trailing spaces if both exist.
# Or if it's a known fragment.

for k in list(strings.keys()):
    if k in keys_to_delete:
        del strings[k]
        continue
    
    stripped = k.strip()
    if stripped != k and stripped in strings:
        # Conflict! Delete the one with spaces
        print(f"Deleting conflicting key with spaces: '{k}' (keeps '{stripped}')")
        del strings[k]

with open("/Volumes/FangB/dorm_project/DormAppSwift_Sources/DormiNetX/DormiNetX/Localizable.xcstrings", "w", encoding="utf-8") as f:
    json.dump(catalog, f, ensure_ascii=False, indent=2)

print("Conflicts resolved.")
