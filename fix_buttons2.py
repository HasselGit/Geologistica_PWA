import os
import re

files_to_check = [
    'lib/pages/viaje_detalle.dart',
    'lib/pages/paradadetalle.dart'
]

# We will match ElevatedButton.styleFrom(...) taking nested parentheses into account, but since that's hard, 
# we'll just find all ElevatedButton.styleFrom( and then replace BorderRadius.circular(...) inside it.
def replace_button_styles(filepath):
    if not os.path.exists(filepath): return
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    in_button_style = False
    parens_depth = 0
    
    for i in range(len(lines)):
        if 'ElevatedButton.styleFrom(' in lines[i]:
            in_button_style = True
            
        if in_button_style:
            # count parens
            parens_depth += lines[i].count('(') - lines[i].count(')')
            
            # replace circular
            lines[i] = re.sub(r'BorderRadius\.circular\(\d+\)', 'BorderRadius.circular(8)', lines[i])
            
            if parens_depth <= 0:
                in_button_style = False
                parens_depth = 0
                
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(lines)

for fpath in files_to_check:
    replace_button_styles(fpath)

print('Done')
