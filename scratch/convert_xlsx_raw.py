import zipfile
import xml.etree.ElementTree as ET
import json

def extract_xlsx(file_path):
    try:
        with zipfile.ZipFile(file_path, 'r') as z:
            # Read shared strings
            shared_strings = []
            if 'xl/sharedStrings.xml' in z.namelist():
                with z.open('xl/sharedStrings.xml') as f:
                    tree = ET.parse(f)
                    root = tree.getroot()
                    # Namespaces can vary, but usually it's {http://schemas.openxmlformats.org/spreadsheetml/2006/main}
                    ns = {'ns': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
                    for si in root.findall('ns:si', ns):
                        t = si.find('ns:t', ns)
                        if t is not None:
                            shared_strings.append(t.text)
                        else:
                            # Handle cases with multiple 'r' (rich text)
                            text_parts = []
                            for r in si.findall('ns:r', ns):
                                rt = r.find('ns:t', ns)
                                if rt is not None:
                                    text_parts.append(rt.text)
                            shared_strings.append("".join(text_parts))

            # Read sheet1
            with z.open('xl/worksheets/sheet1.xml') as f:
                tree = ET.parse(f)
                root = tree.getroot()
                ns = {'ns': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
                
                rows = []
                for row in root.findall('.//ns:row', ns):
                    cells = []
                    for c in row.findall('ns:c', ns):
                        v = c.find('ns:v', ns)
                        if v is not None:
                            val = v.text
                            t = c.get('t')
                            if t == 's': # Shared string
                                cells.append(shared_strings[int(val)])
                            else:
                                cells.append(val)
                        else:
                            cells.append(None)
                    rows.append(cells)
                
                if not rows:
                    return "No rows found"
                
                header = rows[0]
                data = []
                for row in rows[1:]:
                    data.append(dict(zip(header, row)))
                
                return data
    except Exception as e:
        return f"Error: {e}"

result = extract_xlsx(r'C:\Users\Usuario\Desktop\Geologistica\windows\Tabla Productos.xlsx')
with open(r'C:\Users\Usuario\Desktop\Geologistica\scratch\master_catalog.json', 'w', encoding='utf-8') as f:
    json.dump(result, f, indent=2, ensure_ascii=False)
print("SUCCESS")
