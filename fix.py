import os

file_path = 'lib/pages/carga_detalle.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Remove if (vehiculo.isNotEmpty) ...[
old_block1 = '''                  if (vehiculo.isNotEmpty) ...[
                      _labelText('DEPÓSITO CIRCULANTE DEL VEHÍCULO'),
                      const SizedBox(height: 10),
                      _depositoCard(_calcularInventarioCamion(_carga!["viaje_detalle"]), items),
                      const SizedBox(height: 24),
                    ],'''

new_block1 = '''                  _labelText('DEPÓSITO CIRCULANTE DEL VEHÍCULO'),
                  const SizedBox(height: 10),
                  _depositoCard(_calcularInventarioCamion(_carga!["viaje_detalle"]), items),
                  const SizedBox(height: 24),'''

old_block2 = '''            if (vehiculo.isNotEmpty) ...[
              _labelText('DEPÓSITO CIRCULANTE DEL VEHÍCULO'),
              const SizedBox(height: 10),
              _depositoCard(_calcularInventarioCamion(_carga!["viaje_detalle"]), items),
              const SizedBox(height: 20),
            ],'''

new_block2 = '''            _labelText('DEPÓSITO CIRCULANTE DEL VEHÍCULO'),
            const SizedBox(height: 10),
            _depositoCard(_calcularInventarioCamion(_carga!["viaje_detalle"]), items),
            const SizedBox(height: 20),'''

content = content.replace(old_block1, new_block1).replace(old_block2, new_block2)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Removed if vehiculo.isNotEmpty")
