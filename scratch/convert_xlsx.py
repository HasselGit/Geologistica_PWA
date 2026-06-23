import openpyxl
import json

try:
    wb = openpyxl.load_workbook(r'C:\Users\Usuario\Desktop\Geologistica\windows\Tabla Productos.xlsx')
    sheet = wb.active
    rows = list(sheet.iter_rows(values_only=True))
    header = rows[0]
    products = []
    for row in rows[1:]:
        products.append(dict(zip(header, row)))
    
    with open(r'C:\Users\Usuario\Desktop\Geologistica\scratch\master_catalog.json', 'w', encoding='utf-8') as f:
        json.dump(products, f, indent=2, ensure_ascii=False)
    print("SUCCESS: JSON created")
except Exception as e:
    print(f"ERROR: {e}")
