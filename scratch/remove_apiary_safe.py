import os

files_to_check = [
    'lib/pages/agregar_pesaje.dart',
    'lib/pages/homepage.dart',
    'lib/pages/pesajesitem.dart',
    'lib/pages/registro_pesaje_premium.dart',
    'lib/pages/remito_registro.dart',
    'lib/widgets/geo_sidebar.dart',
]

def remove_apiary(content):
    lines = content.split('\n')
    new_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if "'APIARY LOGISTICS'" in line and "Text(" in lines[i-1] if i > 0 else False:
            # We found the block
            # Skip lines until the next '),' that matches the Text widget
            # Actually, let's just count parentheses
            # To be safe, just replace the exact line if it's single line
            pass
        i += 1
    return content

# Better approach: find "Text(" that has "'APIARY LOGISTICS'" in the next line.
# Actually, the block is exactly:
exact_block = """                          Text(
                            'APIARY LOGISTICS',
                            style: TextStyle(
                              fontFamily: 'Work Sans',
                              fontWeight: FontWeight.w600,
                              fontSize: 8,
                              color: Colors.white.withOpacity(0.4),
                              letterSpacing: 1.2,
                            ),
                          ),"""

exact_block_2 = """                        Text(
                          'APIARY LOGISTICS',
                          style: TextStyle(
                            fontFamily: 'Work Sans',
                            fontWeight: FontWeight.w600,
                            fontSize: 8,
                            color: Colors.white.withOpacity(0.4),
                            letterSpacing: 1.2,
                          ),
                        ),"""

exact_block_3 = """            Text('APIARY LOGISTICS', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, letterSpacing: 1)),"""

for file_path in files_to_check:
    if not os.path.exists(file_path):
        continue
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    content = content.replace(exact_block, '')
    content = content.replace(exact_block_2, '')
    content = content.replace(exact_block_3, '')
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

print("Done")
