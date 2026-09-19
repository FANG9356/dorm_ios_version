import re

clean_text = "จำนวน2.00บาทค่าธรรมเนียม0.00บาทเลขที่รายการ:0462615o969p4t3l60o"
expected_amount = 60.00
amount_int = int(float(expected_amount))
amount_exact = f"{float(expected_amount):.2f}"

pattern = rf"(?<![\dA-Za-z])({amount_int}|{amount_exact})(?![\dA-Za-z])"
print(f"Pattern: {pattern}")
match = re.search(pattern, clean_text)
if match:
    print(f"Found: {match.group(0)}")
else:
    print("Not found")

# Test with 2.00
expected_amount2 = 2.00
pattern2 = rf"(?<!\d)({int(expected_amount2)}|{expected_amount2:.2f})(?!\d)"
print(f"Pattern2: {pattern2}")
match2 = re.search(pattern2, clean_text)
if match2:
    print(f"Found2: {match2.group(0)}")
else:
    print("Not found 2")
