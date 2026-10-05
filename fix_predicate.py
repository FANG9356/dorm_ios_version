import re

with open("DormAppSwift_Sources/DormiNetX/DormiNetX/Services/SyncManager.swift", "r") as f:
    content = f.read()

# Replace $0.property == true with $0.property
content = re.sub(r'\{\s*\$0\.([a-zA-Z0-9_]+)\s*==\s*true\s*\}', r'{ $0.\1 }', content)

with open("DormAppSwift_Sources/DormiNetX/DormiNetX/Services/SyncManager.swift", "w") as f:
    f.write(content)

print("Predicates fixed")
