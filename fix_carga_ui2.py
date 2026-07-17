import re

with open('lib/pages/carga_detalle.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Fix margins in _buildDetalleDesktop
# Find: padding: const EdgeInsets.fromLTRB(120, 48, 40, 64),
# Replace with: padding: const EdgeInsets.fromLTRB(120, 0, 40, 0),\n              child: Padding(\n                padding: const EdgeInsets.only(top: 48, bottom: 64),
content = content.replace(
    'padding: const EdgeInsets.fromLTRB(120, 48, 40, 64),\n              child: Row(',
    'padding: const EdgeInsets.fromLTRB(120, 0, 40, 0),\n              child: Padding(\n                padding: const EdgeInsets.only(top: 48, bottom: 64),\n                child: Row('
)
# And add the closing parenthesis for the new Padding widget. 
# Search for: 
#                   ),
#                 ],
#               ),
#             ),
#           ),
#         ],
#       ),
#     );
#   }
# 
end_pattern = r'                  \),\n                \],\n              \),\n            \),\n          \),\n        \],\n      \),\n    \);\n  \}'
new_end = '                  ),\n                ],\n              ),\n            ),\n            ),\n          ),\n        ],\n      ),\n    );\n  }'
content = re.sub(end_pattern, new_end, content, count=1)


# 2. Fix _buildNewCargaDesktop
# We will just replace the entire method to be safe and perfect!
old_new_carga_method = r'  Widget _buildNewCargaDesktop\(\) \{.*?(?=  Widget _buildNewCarga\(\) \{)'

new_carga_method = '''  Widget _buildNewCargaDesktop() {
    if (_isChofer) return _buildNewCarga();

    return Scaffold(
      backgroundColor: DesignTokens.surfaceLow,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GeoSidebar(userRole: _userRole ?? '', userEmail: _userEmail ?? '', displayName: _userEmail ?? ''),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(120, 0, 40, 0),
              child: Padding(
                padding: const EdgeInsets.only(top: 48, bottom: 64),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // COLUMNA IZQUIERDA
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPremiumHeader('Nueva Carga'),
                          _labelText('1. SELECCIONAR VIAJE'),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: DesignTokens.primary.withOpacity(0.06)),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                hint: const Text('Seleccionar viaje...', style: TextStyle(color: Colors.black38)),
                                value: _selectedViajeId,
                                items: _viajes.map((v) => DropdownMenuItem<String>(
                                  value: v['id'].toString(),
                                  child: Text('${v['viaje_codigo'] ?? 'S/C'} - ${v['vehiculo_codigo'] ?? 'S/V'} [${v['estado'] ?? ''}]'),
                                )).toList(),
                                onChanged: (v) => setState(() {
                                  _selectedViajeId = v;
                                  _selectedViaje = _viajes.firstWhere((x) => x['id'].toString() == v);
                                  final vEstado = AppStates.normalize(_selectedViaje!['estado'] ?? '');
                                  if (vEstado == AppStates.enCurso) {
                                    _selectedDeposito = 'Depósito Huinca';
                                    _depositoBloqueado = true;
                                  } else {
                                    _selectedDeposito = 'Parque Industrial';
                                    _depositoBloqueado = false;
                                  }
                                }),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _labelText('2. DEPÓSITO DE ORIGEN'),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: _depositoBloqueado ? DesignTokens.surfaceLow : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _depositoBloqueado
                                ? DesignTokens.secondary.withOpacity(0.4)
                                : DesignTokens.primary.withOpacity(0.06)),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
                            ),
                            child: _depositoBloqueado
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Row(children: [
                                      const Icon(Icons.warehouse_rounded, size: 18, color: DesignTokens.primary),
                                      const SizedBox(width: 10),
                                      Text(_selectedDeposito,
                                          style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700,
                                              fontSize: 14, color: DesignTokens.primary)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: DesignTokens.secondary.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8)),
                                        child: const Text('FIJO', style: TextStyle(fontFamily: 'Work Sans',
                                            fontWeight: FontWeight.w800, fontSize: 9, color: DesignTokens.primary)),
                                      ),
                                    ]),
                                  )
                                : DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      value: _selectedDeposito,
                                      items: ['Parque Industrial', 'Depósito Huinca'].map((d) => DropdownMenuItem<String>(
                                        value: d,
                                        child: Text(d),
                                      )).toList(),
                                      onChanged: (v) => setState(() {
                                        if (v != null) _selectedDeposito = v;
                                      }),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 40),
                          SizedBox(
                            width: double.infinity, height: 56,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _crearCarga,
                              style: DesignTokens.primaryButtonStyle,
                              child: _saving
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text('CREAR Y COMENZAR CARGA', style: TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                    // COLUMNA DERECHA
                    Expanded(
                      flex: 6,
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: DesignTokens.primary.withOpacity(0.04)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _labelText('ÍTEMS DE LA CARGA'),
                            const SizedBox(height: 24),
                            _actionButton(
                              label: 'AGREGAR ÍTEM',
                              icon: Icons.add_circle_outline_rounded,
                              color: DesignTokens.primary,
                              onPressed: _saving
                                  ? null
                                  : () {
                                      _showItemDialog();
                                    },
                            ),
                            const SizedBox(height: 24),
                            _buildItemsTable(items, isNew: true, onRemove: !_saving ? (idx) => _removeItem(idx) : null),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
'''

content = re.sub(old_new_carga_method, new_carga_method, content, flags=re.DOTALL)

with open('lib/pages/carga_detalle.dart', 'w', encoding='utf-8') as f:
    f.write(content)
