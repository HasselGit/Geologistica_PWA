import os
import re

files_to_check = [
    'lib/pages/viaje_detalle.dart',
    'lib/pages/paradadetalle.dart',
    'lib/pages/viajes_page.dart',
    'lib/pages/homepage.dart',
    'lib/pages/gerentehome.dart',
    'lib/widgets/geo_sidebar.dart'
]

# Regex to find BorderRadius.circular(X) inside ElevatedButton.styleFrom or similar button styles.
# It's tricky to do multi-line regex for the whole block, but we can do a simpler replace.
for fpath in files_to_check:
    if not os.path.exists(fpath): continue
    with open(fpath, 'r', encoding='utf-8') as f:
        content = f.read()
        
    # Replace in style: ElevatedButton.styleFrom(...)
    # We can match 'ElevatedButton.styleFrom(' and then replace circular(\d+) within its parens.
    def replacer(match):
        inner = match.group(1)
        new_inner = re.sub(r'BorderRadius\.circular\(\d+\)', 'BorderRadius.circular(8)', inner)
        return 'ElevatedButton.styleFrom(' + new_inner + ')'

    content = re.sub(r'ElevatedButton\.styleFrom\((.*?)\)', replacer, content, flags=re.DOTALL)
    
    # Also in geo_sidebar.dart, there's borderRadius for the ListTile.
    if 'geo_sidebar.dart' in fpath:
        content = re.sub(r'BorderRadius\.circular\(10\)', 'BorderRadius.circular(8)', content)

    with open(fpath, 'w', encoding='utf-8') as f:
        f.write(content)

print('Done')
