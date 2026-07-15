import os
import re

file_path = 'lib/pages/carga_detalle.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Pattern for mobile
p1 = r'if\s*\(vehiculo\.isNotEmpty\)\s*\.\.\.\[\s*_labelText\([\'"]DEP[^C]+CIRCULANTE DEL VEH[^C]+CULO[\'"]\),\s*const SizedBox\(height:\s*10\),\s*_depositoCard\(_calcularInventarioCamion\(_carga!\["viaje_detalle"\]\),\s*items\),\s*const SizedBox\(height:\s*20\),\s*\],'
r1 = r'''_labelText('DEPÓSITO CIRCULANTE DEL VEHÍCULO'),
              const SizedBox(height: 10),
              _depositoCard(_calcularInventarioCamion(_carga!["viaje_detalle"]), items),
              const SizedBox(height: 20),'''

# Pattern for desktop
p2 = r'if\s*\(vehiculo\.isNotEmpty\)\s*\.\.\.\[\s*_labelText\([\'"]DEP[^C]+CIRCULANTE DEL VEH[^C]+CULO[\'"]\),\s*const SizedBox\(height:\s*10\),\s*_depositoCard\(_calcularInventarioCamion\(_carga!\["viaje_detalle"\]\),\s*items\),\s*const SizedBox\(height:\s*24\),\s*\],'
r2 = r'''_labelText('DEPÓSITO CIRCULANTE DEL VEHÍCULO'),
                      const SizedBox(height: 10),
                      _depositoCard(_calcularInventarioCamion(_carga!["viaje_detalle"]), items),
                      const SizedBox(height: 24),'''

content = re.sub(p1, r1, content)
content = re.sub(p2, r2, content)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Removed with regex")
