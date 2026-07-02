import os
import re

files_to_check = [
    'lib/pages/agregar_pesaje.dart',
    'lib/pages/homepage.dart',
    'lib/pages/pesajesitem.dart',
    'lib/pages/registro_pesaje_premium.dart',
    'lib/pages/remito_registro.dart',
    'lib/widgets/geo_sidebar.dart',
]

def remove_apiary_logistics(content):
    # This matches Text('APIARY LOGISTICS' ...) down to the closing parenthesis
    # and handles nested parentheses
    pattern = r"Text\(\s*'APIARY LOGISTICS',\s*style:\s*TextStyle\([^)]*\)[^)]*\),\s*\),?"
    # Since the regex didn't work, let's just use string replacement for the exact block
    
    # Actually, a simple regex is safer: match from Text( up to the next ),\s*\)
    pattern = r"Text\(\s*'APIARY LOGISTICS'[\s\S]*?,\s*\),"
    return re.sub(pattern, '', content)

for file_path in files_to_check:
    if not os.path.exists(file_path):
        continue
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    new_content = remove_apiary_logistics(content)
    
    if new_content != content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {file_path}")

print("Done removing APIARY LOGISTICS")
