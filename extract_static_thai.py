import os
import re
import json

swift_dir = "/Volumes/FangB/dorm_project/DormAppSwift_Sources/DormiNetX/DormiNetX"

thai_pattern = re.compile(r'"([^"\\]*[\u0E00-\u0E7F]+[^"\\]*)"')

all_static_thai_strings = set()

for root, dirs, files in os.walk(swift_dir):
    for file in files:
        if file.endswith(".swift"):
            with open(os.path.join(root, file), "r", encoding="utf-8") as f:
                content = f.read()
                matches = thai_pattern.findall(content)
                for match in matches:
                    if "\\(" not in match: # No interpolation
                        all_static_thai_strings.add(match)

with open("/Volumes/FangB/dorm_project/DormAppSwift_Sources/DormiNetX/DormiNetX/Localizable.xcstrings", "r", encoding="utf-8") as f:
    catalog = json.load(f)

strings = catalog.setdefault("strings", {})

missing = []
for s in all_static_thai_strings:
    if s not in strings:
        missing.append(s)

print(f"Total static Thai strings found in code: {len(all_static_thai_strings)}")
print(f"Missing in catalog: {len(missing)}")

with open("/Volumes/FangB/dorm_project/missing_static_thai.json", "w", encoding="utf-8") as f:
    json.dump(missing, f, ensure_ascii=False, indent=2)
