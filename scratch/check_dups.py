import re
with open('lib/main.dart', 'r', encoding='utf-8') as f:
    text = f.read()

names = re.findall(r"name:\s*['\"]([^'\"]+)['\"]", text)
from collections import Counter
counts = Counter(names)
dups = {k: v for k, v in counts.items() if v > 1}
print('Duplicate names:', dups)
