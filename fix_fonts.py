import os
import re

weight_map = {
    'bold': 'Bold',
    'semibold': 'SemiBold',
    'medium': 'Medium',
    'light': 'Light',
    'regular': 'Text'
}

def fix_fonts_in_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Match .font(.system(size: X, weight: .Y))
    pattern_with_weight = r'\.font\(\.system\(size:\s*([0-9\.]+)\s*,\s*weight:\s*\.([a-z]+)\)\)'
    
    def repl_with_weight(match):
        size = match.group(1)
        weight = match.group(2)
        custom_weight = weight_map.get(weight, 'Medium')
        return f'.font(.custom("SukhumvitSet-{custom_weight}", size: {size}))'
    
    new_content = re.sub(pattern_with_weight, repl_with_weight, content)
    
    # Match .font(.system(size: X))
    pattern_without_weight = r'\.font\(\.system\(size:\s*([0-9\.]+)\)\)'
    
    def repl_without_weight(match):
        size = match.group(1)
        return f'.font(.custom("SukhumvitSet-Medium", size: {size}))'
    
    new_content = re.sub(pattern_without_weight, repl_without_weight, new_content)
    
    if content != new_content:
        with open(filepath, 'w') as f:
            f.write(new_content)
        print(f"Fixed fonts in {filepath}")

views_dir = '/Volumes/FangB/dorm_project/DormAppSwift_Sources/DormiNetX/DormiNetX/Views'
for root, dirs, files in os.walk(views_dir):
    for file in files:
        if file.endswith('.swift'):
            fix_fonts_in_file(os.path.join(root, file))
