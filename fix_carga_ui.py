import re

with open('lib/pages/carga_detalle.dart', 'r', encoding='utf-8') as f:
    content = f.read()

new_desktop = '''  Widget _buildDetalleDesktop() {
    final estado = _carga!['estado'] ?? AppStates.pendiente;
    final viaje = _carga!['viaje'] as Map<String, dynamic>? ?? {};
    final chofer = _carga!['chofer'] as Map<String, dynamic>? ?? {};
    final vehiculo = _carga!['vehiculo'] as Map<String, dynamic>? ?? {};
    final items = List<Map<String, dynamic>>.from(_carga!['carga_items'] ?? []);
    final codigo = _carga!['carga_codigo'] ?? 'S/C';
    final viajeCode = viaje['viaje_codigo'] ?? 'S/V';
    final vehiculoCode = viaje['vehiculo_codigo'] ?? 'S/V';
    final choferNombre = chofer.isNotEmpty
        ? '${chofer['nombre'] ?? ''} ${chofer['apellido'] ?? ''}'.trim()
        : 'Sin chofer';

    final capKg = (vehiculo['capacidad_kg'] as num?)?.toDouble() ?? 0;
    final capTamb = (vehiculo['capacidad_tambores'] as num?)?.toInt() ?? 0;
    final cargaActualKg = (vehiculo['carga_actual_kg'] as num?)?.toDouble() ?? 0;
    final cargaActualTamb = (vehiculo['carga_actual_tambores'] as num?)?.toInt() ?? 0;

    double estaCargaKg = 0;
    int estaCargaTamb = 0;
    for (final it in items) {
      final qty = (it['cantidad'] as num?)?.toDouble() ?? 0;
      final prod = (it['producto_codigo'] ?? '').toString().toUpperCase();
      if (prod == 'TCM' || prod.contains('TAMBOR')) {
        estaCargaKg += qty * 330; // Fijado a 330 kg por tambor promedio
        estaCargaTamb += qty.round();
      } else if ((prod.startsWith('T') && prod != 'TV' && prod != 'TE') ||
          prod.contains('VACIO') ||
          prod.contains('VAC?O') || prod.contains('VACÍO')) {
        estaCargaKg += qty * 20;
        estaCargaTamb += qty.round();
      } else if (prod == 'AZ') {
        estaCargaKg += qty * 50;
      } else {
        estaCargaKg += qty;
      }
    }

    final proyectadoKg = cargaActualKg + estaCargaKg;
    final excede = capKg > 0 && proyectadoKg > capKg;

    return Scaffold(
      backgroundColor: DesignTokens.surfaceLow,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GeoSidebar(userRole: _userRole ?? '', userEmail: _userEmail ?? '', displayName: _userEmail ?? ''),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(120, 48, 40, 64),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // COLUMNA IZQUIERDA (Detalles y Acciones)
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPremiumHeader(codigo),
                        _sectionHeader(codigo, estado, viajeCode, vehiculoCode, choferNombre),
                        const SizedBox(height: 32),
                        _labelText('DEPÓSITO CIRCULANTE (PROYECTADO)'),
                        const SizedBox(height: 16),
                        _depositoCard(_calcularInventarioCamion(_carga!["viaje_detalle"]), items),
                        const SizedBox(height: 32),
                        // BOTONES
                        if ((_isDeposito || _isChoferDepositoHuinca) && _canChangeEstado) ...[
                          if (estado == AppStates.pendiente)
                            _actionButton(
                              label: 'INICIAR CARGA',
                              icon: Icons.play_circle_outline_rounded,
                              color: const Color(0xFF1565C0),
                              onPressed: _saving ? null : () => _cambiarEstado(AppStates.enCurso),
                            ),
                          if (estado == AppStates.enCurso)
                            _actionButton(
                              label: 'CONFIRMAR CARGA TERMINADA',
                              icon: Icons.check_circle_outline_rounded,
                              color: excede ? Colors.orange : const Color(0xFF1A6B43),
                              onPressed: _saving ? null : () => _confirmarTerminar(excede),
                            ),
                          const SizedBox(height: 16),
                        ],
                        if (_isManagement && estado == AppStates.pendiente) ...[
                          _actionButton(
                            label: 'ELIMINAR CARGA',
                            icon: Icons.delete_forever_rounded,
                            color: Colors.redAccent,
                            onPressed: _saving ? null : () => _confirmarEliminarCarga(),
                          ),
                        ],
                        if (estado == AppStates.terminado) ...[
                          Container(
                            width: double.infinity, padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: const Color(0xFFD4F0E1), borderRadius: BorderRadius.circular(12)),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded, color: Color(0xFF1A6B43)),
                                SizedBox(width: 10),
                                Text('Carga completada',
                                    style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700,
                                        color: Color(0xFF1A6B43))),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                  // COLUMNA DERECHA (Items en Bento Box)
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
                          if (estado == AppStates.pendiente) ...[
                            _actionButton(
                              label: 'AGREGAR NUEVO ÍTEM',
                              icon: Icons.add_circle_outline_rounded,
                              color: DesignTokens.primary,
                              onPressed: _saving
                                  ? null
                                  : () {
                                      _showItemDialog();
                                    },
                            ),
                            const SizedBox(height: 24),
                          ],
                          _buildItemsTable(items, isNew: false, onRemove: estado == AppStates.pendiente && !_saving ? (idx) => _removeItem(idx) : null),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }'''

desktop_pattern = r'Widget _buildDetalleDesktop\(\) \{.*?(?=  // ─── NUEVA CARGA|$)'
content = re.sub(desktop_pattern, new_desktop + '\n\n', content, flags=re.DOTALL)

new_header = '''  Widget _sectionHeader(String codigo, String estado, String viajeCode,
      String vehiculoCode, String choferNombre) {
    final bgColor = Color(AppStates.stateBgColor(estado));
    final textColor = Color(AppStates.stateTextColor(estado));

    // Datos del creador
    final creador = _carga?['creador'] as Map<String, dynamic>?;
    String creadorNombre = 'Desconocido';
    if (creador != null) {
      final nombre = '${creador['nombre'] ?? ''} ${creador['apellido'] ?? ''}'.trim();
      final puesto = creador['puesto']?.toString() ?? '';
      creadorNombre = puesto.isNotEmpty ? '$nombre ($puesto)' : nombre;
    }

    // Depósito de origen
    final depositoOrigen = _carga?['deposito_origen']?.toString() ?? 'No especificado';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DesignTokens.primary.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Datos Generales',
                  style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 16, color: DesignTokens.primary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
                child: Text(estado.toUpperCase(),
                    style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 11, color: textColor)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 24,
            runSpacing: 20,
            children: [
              SizedBox(width: 140, child: _detailCol(Icons.local_shipping_rounded, 'Viaje', viajeCode)),
              SizedBox(width: 140, child: _detailCol(Icons.directions_car_rounded, 'Vehículo', vehiculoCode)),
              SizedBox(width: 140, child: _detailCol(Icons.person_rounded, 'Chofer', choferNombre)),
              SizedBox(width: 140, child: _detailCol(Icons.warehouse_rounded, 'Dep. Origen', depositoOrigen)),
              SizedBox(width: 140, child: _detailCol(Icons.manage_accounts_rounded, 'Registrado por', creadorNombre)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailCol(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: DesignTokens.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: DesignTokens.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: DesignTokens.primary)),
      ],
    );
  }
'''

old_header = r'Widget _sectionHeader\(String codigo, String estado, String viajeCode,\s*String vehiculoCode, String choferNombre\) \{.*?\);[\s\n]*\}'
content = re.sub(old_header, new_header, content, flags=re.DOTALL)

with open('lib/pages/carga_detalle.dart', 'w', encoding='utf-8') as f:
    f.write(content)
