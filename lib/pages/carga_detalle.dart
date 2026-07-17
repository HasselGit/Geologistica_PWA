import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../backend/supabase_service.dart';
import '../backend/app_states.dart';
import '../backend/design_tokens.dart';
import '../widgets/geo_sidebar.dart';

class CargaDetalleWidget extends StatefulWidget {
  final String? cargaId;
  final bool isNew;
  const CargaDetalleWidget({super.key, this.cargaId, this.isNew = false});
  static String routePath = '/cargaDetalle';

  @override
  State<CargaDetalleWidget> createState() => _CargaDetalleWidgetState();
}

class _CargaDetalleWidgetState extends State<CargaDetalleWidget> {
  Map<String, dynamic>? _carga;
  bool _loading = true;
  bool _saving = false;
  String? _userRole;
  String? _userId;
  String? _userEmail;

  // Para nueva carga
  List<Map<String, dynamic>> _viajes = [];
  List<Map<String, dynamic>> _productos = [];
  Map<String, dynamic>? _selectedViaje;
  String? _selectedViajeId;
  String _selectedDeposito = 'Parque Industrial';
  bool _depositoBloqueado = false; // true cuando el viaje está En Proceso (Huinca)
  final List<Map<String, dynamic>> _newItems = [];

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  Future<void> _initPage() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userRole = prefs.getString('user_puesto');
        _userId = prefs.getString('user_id');
        _userEmail = prefs.getString('user_email');
      });
    }
    if (widget.isNew) {
      // Pasamos el rol como parámetro para evitar problemas de resolución en el analizador
      final isChoferLocal = _isChofer;
      await _loadCatalogos(isChofer: isChoferLocal);
      if (mounted) setState(() => _loading = false);
    } else {
      await _loadCarga();
      try {
        _productos = await SupabaseService().getProductos();
        if (mounted) setState(() {});
      } catch (e) {
        print('CargaDetalle: Error cargando productos: $e');
      }
    }
  }

  Future<void> _loadCatalogos({bool isChofer = false}) async {
    final service = SupabaseService();
    try {
      final viajesData = await service.getViajes();
      // Si es chofer, mostrar tanto viajes pendientes como en proceso (los en proceso son Huinca)
      if (isChofer) {
        _viajes = viajesData.where((v) {
          final est = AppStates.normalize(v['estado']);
          return est == AppStates.pendiente || est == AppStates.enCurso;
        }).toList();
      } else {
        // Para depósito PI, solo viajes en Pendiente
        _viajes = viajesData.where((v) =>
          AppStates.normalize(v['estado']) == AppStates.pendiente).toList();
      }
    } catch (e) {
      print('CargaDetalle: Error cargando viajes: $e');
    }

    try {
      _productos = await service.getProductos();
    } catch (e) {
      print('CargaDetalle: Error cargando productos: $e');
    }
  }

  Future<void> _loadCarga() async {
    if (widget.cargaId == null) return;
    setState(() => _loading = true);
    try {
      final data = await SupabaseService().getCargaDetalle(widget.cargaId!);
      if (data != null && data['viaje_id'] != null) {
        final viajeData = await SupabaseService().getViajeDetalle(data['viaje_id']);
        if (viajeData != null) {
          data['viaje_detalle'] = viajeData;
        }
      }
      print('CargaDetalle: Carga fetched. Data: $data');
      if (data != null) {
        print('CargaDetalle: carga_items in map: ${data['carga_items']} (type: ${data['carga_items']?.runtimeType})');
      }
      if (mounted) setState(() { _carga = data; _loading = false; });
    } catch (e) {
      print('CargaDetalle: Error loading carga: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _normalizeRole(String? role) {
    if (role == null) return '';
    return role.toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .trim();
  }

  bool get _isAdmin => _userEmail == 'hassel00@gmail.com' || Supabase.instance.client.auth.currentUser?.email == 'hassel00@gmail.com';

  bool get _isDeposito {
    final r = _normalizeRole(_userRole);
    final email = (_userEmail ?? '').toLowerCase();
    return r.contains('deposito') || email.contains('cmerlo') || email.contains('csantana');
  }

  bool get _isManagement {
    final r = _normalizeRole(_userRole);
    final email = (_userEmail ?? '').toLowerCase();
    return r.contains('compras') || 
           r.contains('gerente') || 
           r.contains('gerencia') || 
           r.contains('ceo') || 
           r.contains('director') || 
           _isAdmin || 
           email.contains('hespinosa') || 
           email.contains('mparedes') || 
           email.contains('gparedes') || 
           email.contains('lcastellanos') || 
           email.contains('rsteierd');
  }

  bool get _isChofer {
    final r = _normalizeRole(_userRole);
    final email = (_userEmail ?? '').toLowerCase();
    return r.contains('chofer') || email.contains('mperez') || email.contains('cmuse') || email.contains('agomez') || email.contains('efernandez');
  }

  // Alias por compatibilidad
  bool get _isChoferDepositoHuinca => _isChofer;

  bool get _canChangeEstado {
    if (_carga == null) return false;
    final estado = AppStates.normalize(_carga!['estado'] ?? '');
    if (estado == AppStates.terminado) return _isAdmin; // Solo admin puede revertir terminado

    if (_isDeposito) {
      // Depósito PI gestiona cualquier carga
      return estado == AppStates.pendiente || estado == AppStates.enCurso;
    }

    if (_isChofer) {
      // El chofer SOLO puede gestionar cargas del depósito Huinca
      // Una carga es de Huinca cuando:
      //   a) deposito_origen == 'Depósito Huinca' (dato guardado en BD), o
      //   b) el viaje asociado está En Proceso (en ruta - lógica de fallback)
      final String deposito = (_carga!['deposito_origen'] ?? '').toString();
      final String viajeEstado = AppStates.normalize(
          (_carga!['viaje'] as Map<String, dynamic>?)?['estado'] ?? '');
      final bool esHuinca = deposito.toLowerCase().contains('huinca') ||
          viajeEstado == AppStates.enCurso;
      return esHuinca && (estado == AppStates.pendiente || estado == AppStates.enCurso);
    }

    if (_isManagement) {
      return estado == AppStates.pendiente;
    }
    return false;
  }

  Future<void> _cambiarEstado(String nuevoEstado) async {
    if (widget.cargaId == null) return;
    setState(() => _saving = true);
    try {
      await SupabaseService().updateCargaEstado(widget.cargaId!, nuevoEstado);
      await _loadCarga();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Carga actualizada a: $nuevoEstado'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _crearCarga() async {
    // Bloquear a choferes
    if (_isChofer) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Los choferes no pueden crear cargas'), backgroundColor: Colors.red));
      return;
    }
    if (_selectedViaje == null || _newItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seleccione viaje y agregue al menos un ítem')));
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService().createCarga(
        viajeId: _selectedViaje!['id'].toString(),
        items: _newItems,
        createdBy: _userId ?? '',
        depositoOrigen: _selectedDeposito,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Carga creada correctamente'), backgroundColor: Colors.green));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: DesignTokens.secondary)));
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        
        if (widget.isNew) {
           return isDesktop ? _buildNewCargaDesktop() : _buildNewCarga();
        }
        
        if (_carga == null) return Scaffold(appBar: AppBar(title: const Text('Carga no encontrada')));
        
        return isDesktop ? _buildDetalleDesktop() : _buildDetalleMobile();
      },
    );
  }

  // ─── DETALLE DE CARGA EXISTENTE (MOBILE) ──────────────────────────────────
  Widget _buildPremiumHeader(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24, top: 16),
      child: Row(
        children: [
          InkWell(
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              final userRole = prefs.getString('user_puesto');
              if (userRole == 'Gerente') {
                if (context.mounted) context.go('/gerentehome');
              } else {
                if (context.mounted) {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                }
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 18, color: DesignTokens.primary),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: DesignTokens.headlineStyle().copyWith(fontSize: 24), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildDetalleMobile() {
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

    // Calcular lo que va a agregar esta carga
    double estaCargaKg = 0;
    int estaCargaTamb = 0;
    for (final it in items) {
      final qty = (it['cantidad'] as num?)?.toDouble() ?? 0;
      final prod = (it['producto_codigo'] ?? '').toString().toUpperCase();
      if (prod == 'TCM' || prod.contains('TAMBOR')) {
        estaCargaKg += qty * 300;
        estaCargaTamb += qty.round();
      } else if ((prod.startsWith('T') && prod != 'TV' && prod != 'TE') ||
          prod.contains('VACIO') ||
          prod.contains('VACÍO')) {
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
    final progreso = capKg > 0 ? (proyectadoKg / capKg).clamp(0.0, 1.2) : 0.0;

    return Scaffold(
      backgroundColor: DesignTokens.surfaceLow,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildPremiumHeader(codigo),
          // ── HEADER ────────────────────────────────────────────────────────
          _sectionHeader(codigo, estado, viajeCode, vehiculoCode, choferNombre),
          const SizedBox(height: 20),

          // ── DEPÓSITO CIRCULANTE ───────────────────────────────────────────
          _labelText('DEPÓSITO CIRCULANTE DEL VEHÍCULO'),
              const SizedBox(height: 10),
              _depositoCard(_calcularInventarioCamion(_carga!["viaje_detalle"]), items),
              const SizedBox(height: 20),

          // ── ÍTEMS DE CARGA ────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _labelText('ÍTEMS DE LA CARGA'),
              if (_canChangeEstado)
                TextButton.icon(
                  onPressed: () => _showEditCargaDialog(),
                  icon: const Icon(Icons.edit_rounded, size: 16, color: DesignTokens.primary),
                  label: const Text('Editar', style: TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            _emptyCard('No hay ítems en esta carga')
          else
            ...items.map((it) => _itemCard(it)).toList(),
          const SizedBox(height: 24),

          // ── BOTONES DE ACCIÓN ─────────────────────────────────────────────
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
            const SizedBox(height: 40),
          ] else if ((_isDeposito || _isChoferDepositoHuinca) && _canChangeEstado) ...[
            const SizedBox(height: 40),
          ],
          if (estado == AppStates.terminado) ...[
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xFFD4F0E1), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF1A6B43)),
                  SizedBox(width: 10),
                  Text('Carga completada — Depósito actualizado',
                      style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700,
                          color: Color(0xFF1A6B43))),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ]),
      ),
    );
  }

  Future<void> _confirmarTerminar(bool excede) async {
    if (excede) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: DesignTokens.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text('Capacidad excedida',
                  style: TextStyle(fontFamily: 'Manrope', color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ],
          ),
          content: const Text('Esta carga excede la capacidad del vehículo. ¿Confirmar de todas formas?', style: TextStyle(fontFamily: 'Inter', fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCELAR', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, color: DesignTokens.primary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('CONFIRMAR', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _cambiarEstado(AppStates.terminado);
  }

  Future<void> _confirmarEliminarCarga() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DesignTokens.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text('Eliminar Carga', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text('Esta acción eliminará de forma permanente esta carga y todos sus ítems. ¿Confirmar eliminación?', style: TextStyle(fontFamily: 'Inter', fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, color: DesignTokens.primary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('ELIMINAR', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (ok == true) {
      setState(() => _saving = true);
      try {
        await SupabaseService().deleteCarga(widget.cargaId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Carga eliminada correctamente'),
            backgroundColor: Colors.redAccent,
          ));
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.red,
          ));
        }
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  Widget _sectionHeader(String codigo, String estado, String viajeCode,
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

  Widget _depositoCard(Map<String, Map<String, dynamic>> baseInventario, List<Map<String, dynamic>> itemsCarga) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: _buildInventarioTable(baseInventario, itemsCarga),
    );
  }

  Widget _itemCard(Map<String, dynamic> it) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DesignTokens.primary.withOpacity(0.05)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
              color: DesignTokens.surface, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.inventory_2_rounded, size: 18, color: DesignTokens.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(it['producto_codigo'] ?? 'Producto',
                style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800,
                    fontSize: 14, color: DesignTokens.primary)),
            Text(it['unidad'] ?? '', style: const TextStyle(fontSize: 11,
                color: DesignTokens.onSurfaceVariant)),
          ]),
        ),
        Text('${it['cantidad']}',
            style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w900,
                fontSize: 18, color: DesignTokens.primary)),
      ]),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 15, color: DesignTokens.secondary),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(fontFamily: 'Work Sans',
            fontWeight: FontWeight.w700, fontSize: 13, color: DesignTokens.onSurfaceVariant)),
        Expanded(child: Text(value, style: const TextStyle(fontFamily: 'Inter',
            fontWeight: FontWeight.w600, fontSize: 13, color: DesignTokens.primary),
            overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Widget _labelText(String text) => Text(text,
      style: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800,
          fontSize: 11, color: DesignTokens.onSurfaceVariant, letterSpacing: 0.5));

  Widget _emptyCard(String msg) => Container(
    width: double.infinity, padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DesignTokens.primary.withOpacity(0.05))),
    child: Text(msg, textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Inter', color: DesignTokens.onSurfaceVariant)),
  );

  Widget _actionButton({required String label, required IconData icon,
      required Color color, VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity, height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: _saving && onPressed != null
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Icon(icon, color: Colors.white),
        label: Text(label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        style: ElevatedButton.styleFrom(
            backgroundColor: color, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0),
      ),
    );
  }

  // ─── DETALLE DE CARGA EXISTENTE (DESKTOP) ─────────────────────────────────
  Widget _buildDetalleDesktop() {
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
        estaCargaKg += qty * 300;
        estaCargaTamb += qty.round();
      } else if ((prod.startsWith('T') && prod != 'TV' && prod != 'TE') ||
          prod.contains('VACIO') ||
          prod.contains('VACÍO')) {
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
    final progreso = capKg > 0 ? (proyectadoKg / capKg).clamp(0.0, 1.2) : 0.0;

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPremiumHeader(codigo),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // COLUMNA IZQUIERDA
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionHeader(codigo, estado, viajeCode, vehiculoCode, choferNombre),
                              const SizedBox(height: 32),
                              _labelText('DEPÓSITO CIRCULANTE (PROYECTADO)'),
                              const SizedBox(height: 16),
                              _depositoCard(_calcularInventarioCamion(_carga!["viaje_detalle"]), items),
                          const SizedBox(height: 32),
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
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                          ]
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _labelText('ÍTEMS DE LA CARGA'),
                                if (_canChangeEstado)
                                  ElevatedButton.icon(
                                    onPressed: () => _showEditCargaDialog(),
                                    icon: const Icon(Icons.edit_rounded, size: 16),
                                    label: const Text('Editar', style: TextStyle(fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: DesignTokens.surface,
                                      foregroundColor: DesignTokens.primary,
                                      elevation: 0,
                                      side: BorderSide(color: DesignTokens.primary.withOpacity(0.1)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            if (items.isEmpty)
                              _emptyCard('No hay ítems en esta carga')
                            else
                              _buildItemsTable(items),
                          ],
                        ),
                      ),
                    ),
                  ],
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

  // ─── HELPER PARA DATA TABLE (DESKTOP) ─────────────────────────────────────
  Widget _buildItemsTable(List<Map<String, dynamic>> items, {bool isNew = false, void Function(int)? onRemove}) {
    return Column(
      children: items.asMap().entries.map((e) {
        final idx = e.key;
        final it = e.value;
        final prodStr = (it['producto_codigo'] ?? '').toString().toUpperCase();
        final isTcm = prodStr == 'TCM' || prodStr == '1';
        final icon = isTcm ? Icons.inventory_2_rounded : Icons.category_rounded;
        final color = isTcm ? const Color(0xFFE65100) : const Color(0xFF1565C0);
        final bg = isTcm ? const Color(0xFFFFF3E0) : const Color(0xFFE3F2FD);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DesignTokens.primary.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      it['producto_codigo'] ?? 'Producto',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: DesignTokens.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Unidad: ${it['unidad'] ?? 'N/A'}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: DesignTokens.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${it['cantidad']}',
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: DesignTokens.primary,
                    ),
                  ),
                  const Text(
                    'CANTIDAD',
                    style: TextStyle(
                      fontFamily: 'Work Sans',
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 0.5,
                      color: DesignTokens.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (isNew) ...[
                const SizedBox(width: 16),
                Container(
                  width: 1,
                  height: 32,
                  color: DesignTokens.primary.withOpacity(0.08),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => onRemove?.call(idx),
                  icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent),
                  splashRadius: 24,
                ),
              ]
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─── NUEVA CARGA (formulario) ─────────────────────────────────────────────

    Map<String, Map<String, dynamic>> _calcularInventarioCamion(Map<String, dynamic>? viajeDetalle) {
    if (viajeDetalle == null) return {};
    Map<String, Map<String, dynamic>> inventario = {};

    void _add(String prod, double qty, {bool isTcm = false, List<Map<String, dynamic>>? pesajes}) {
      prod = prod.trim().toUpperCase();
      if (!inventario.containsKey(prod)) {
        inventario[prod] = {'cantidad': 0.0, 'peso': 0.0, 'unidad': 'UN'};
      }
      inventario[prod]!['cantidad'] += qty;
      
      double peso = 0.0;
      if (prod == 'TCM' || prod == '1') {
         if (isTcm && pesajes != null && pesajes.isNotEmpty) {
            double brutoTcm = 0;
            for (var p in pesajes) {
               final bruto = (p['peso_bruto'] as num?)?.toDouble() ?? 0;
               // El camión carga el tambor físico completo, por lo tanto usamos el PESO BRUTO.
               brutoTcm += bruto > 0 ? bruto : 330.0; 
            }
            peso = brutoTcm;
         } else {
            peso = qty * 330.0;
         }
      } else if (prod.startsWith('T') && (prod.contains('V') || prod.contains('N') || prod.contains('R') || prod.contains('E') || prod.contains('A'))) {
         peso = qty * 20.0;
      } else if (prod == 'AZ') {
         peso = qty * 50.0;
      } else {
         peso = qty * 1.0;
      }
      inventario[prod]!['peso'] += peso;
    }

    void _sub(String prod, double qty) {
      prod = prod.trim().toUpperCase();
      if (!inventario.containsKey(prod)) return;
      
      double qtyBefore = inventario[prod]!['cantidad'];
      double pesoBefore = inventario[prod]!['peso'];
      double avgWeight = qtyBefore > 0 ? pesoBefore / qtyBefore : 0;
      
      inventario[prod]!['cantidad'] -= qty;
      inventario[prod]!['peso'] -= qty * avgWeight;
      
      if (inventario[prod]!['cantidad'] <= 0) {
        inventario.remove(prod);
      }
    }

    final cargas = List<Map<String, dynamic>>.from(viajeDetalle['cargas'] ?? []);
    for (var c in cargas) {
       if (c['id']?.toString() == widget.cargaId) continue;
       final estado = (c['estado'] ?? '').toString().toLowerCase();
       if (estado == 'cancelada' || estado == 'anulada') continue;
       final items = List<Map<String, dynamic>>.from(c['carga_items'] ?? []);
       for (var it in items) {
          final prod = (it['producto_codigo'] ?? '').toString();
          final qty = (it['cantidad'] as num?)?.toDouble() ?? 0;
          if (prod.isNotEmpty && qty > 0) _add(prod, qty);
       }
    }

    final paradas = List<Map<String, dynamic>>.from(viajeDetalle['paradas'] ?? []);
    for (var p in paradas) {
       final estado = (p['estado'] ?? '').toString().toLowerCase();
       if (estado != 'terminado' && estado != 'terminada') continue;
       final tipo = (p['tipo'] ?? '').toString().toLowerCase();
       final isRec = tipo.contains('recol') || tipo.contains('mixt') || tipo.contains('ambos');
       final pesajes = List<Map<String, dynamic>>.from(p['pesajes'] ?? []);
       
       final items = List<Map<String, dynamic>>.from(p['parada_items'] ?? []);
       for (var it in items) {
          final prod = (it['producto_codigo'] ?? '').toString();
          final qty = (it['cantidad'] as num?)?.toDouble() ?? 0;
          if (prod.isEmpty || qty <= 0) continue;
          
          final uni = (it['unidad'] ?? '').toString().toLowerCase();
          final isRecoleccion = uni.contains('recol') || uni.contains('retiro') || isRec; 
          
          if (isRecoleccion) {
             _add(prod, qty, isTcm: true, pesajes: pesajes);
          } else {
             _sub(prod, qty);
          }
       }
    }
    return inventario;
  }

  Widget _buildInventarioTable(Map<String, Map<String, dynamic>> base, List<Map<String, dynamic>> itemsCarga) {
    Map<String, Map<String, dynamic>> proyectado = {};
    base.forEach((k, v) => proyectado[k] = {'cantidad': v['cantidad'], 'peso': v['peso']});
    
    for (var it in itemsCarga) {
       final prod = (it['producto_codigo'] ?? '').toString().trim().toUpperCase();
       final qty = (it['cantidad'] as num?)?.toDouble() ?? 0;
       if (prod.isEmpty || qty <= 0) continue;
       
       if (!proyectado.containsKey(prod)) proyectado[prod] = {'cantidad': 0.0, 'peso': 0.0};
       proyectado[prod]!['cantidad'] += qty;
       
       double peso = 0.0;
       if (prod == 'TCM' || prod == '1') peso = qty * 330.0;
       else if (prod.startsWith('T') && (prod.contains('V') || prod.contains('N') || prod.contains('R') || prod.contains('E'))) peso = qty * 20.0;
       else if (prod == 'AZ') peso = qty * 50.0;
       else peso = qty * 1.0;
       
       proyectado[prod]!['peso'] += peso;
    }
    
    final allProds = proyectado.keys.toList()..sort();
    if (allProds.isEmpty) {
       return const Padding(padding: EdgeInsets.all(16), child: Text('El camión está vacío', style: TextStyle(color: Colors.grey)));
    }
    
    double totalPeso = 0;
    
    final rows = allProds.map((prod) {
       final bQty = base[prod]?['cantidad'] ?? 0.0;
       final pQty = proyectado[prod]?['cantidad'] ?? 0.0;
       final addQty = pQty - bQty;
       final pPeso = proyectado[prod]?['peso'] ?? 0.0;
       totalPeso += pPeso;
       
       return TableRow(
         decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
         children: [
           Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8), child: Text(prod, style: const TextStyle(fontWeight: FontWeight.bold, color: DesignTokens.primary))),
           Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8), child: Text(bQty > 0 ? bQty.toStringAsFixed(0) : '-', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey))),
           Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8), child: Text(addQty > 0 ? '+${addQty.toStringAsFixed(0)}' : '-', textAlign: TextAlign.center, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
           Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8), child: Text('${pPeso.toStringAsFixed(0)} kg', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
         ],
       );
    }).toList();
    
    return Column(
      children: [
        Table(
          columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1.2), 2: FlexColumnWidth(1.2), 3: FlexColumnWidth(1.5)},
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade50),
              children: const [
                Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8), child: Text('Prod.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8), child: Text('Actual', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8), child: Text('Suma', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8), child: Text('Total Kg', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
              ],
            ),
            ...rows,
          ],
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: DesignTokens.primary.withOpacity(0.05), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               const Text('PESO TOTAL PROYECTADO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DesignTokens.primary)),
               Text('${totalPeso.toStringAsFixed(0)} kg', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: DesignTokens.primary)),
            ],
          )
        )
      ]
    );
  }

  Widget _buildNewCarga() {
    // Los choferes no pueden crear cargas
    if (_isChofer) {
      return Scaffold(
        backgroundColor: DesignTokens.surfaceLow,
        appBar: AppBar(
          backgroundColor: DesignTokens.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: DesignTokens.primary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Nueva Carga',
              style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800,
                  fontSize: 17, color: DesignTokens.primary)),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_rounded, size: 64, color: Colors.redAccent),
                SizedBox(height: 20),
                Text('Sin permiso', style: TextStyle(fontFamily: 'Manrope',
                    fontWeight: FontWeight.w800, fontSize: 20, color: DesignTokens.primary)),
                SizedBox(height: 10),
                Text('Los choferes no pueden crear cargas de vehículos. Contacte al personal de depósito o administración.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: DesignTokens.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: DesignTokens.surfaceLow,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildPremiumHeader('Nueva Carga'),
          _labelText('1. SELECCIONAR VIAJE'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: DesignTokens.primary.withOpacity(0.1))),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                hint: const Text('Seleccionar viaje...', style: TextStyle(color: Colors.black38)),
                value: _selectedViajeId,
                items: _viajes.map((v) => DropdownMenuItem<String>(
                  value: v['id'].toString(),
                  child: Text('${v['viaje_codigo'] ?? 'S/C'} — ${v['vehiculo_codigo'] ?? 'S/V'} [${v['estado'] ?? ''}]'),
                )).toList(),
                onChanged: (v) => setState(() {
                  _selectedViajeId = v;
                  _selectedViaje = _viajes.firstWhere((x) => x['id'].toString() == v);
                  // Si el viaje está En Proceso -> es Huinca, bloquear depósito
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
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _depositoBloqueado
                ? DesignTokens.secondary.withOpacity(0.4)
                : DesignTokens.primary.withOpacity(0.1))),
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
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _labelText('3. ÍTEMS DE CARGA'),
            TextButton.icon(
              onPressed: () => _showAddItemDialog(),
              icon: const Icon(Icons.add_rounded, size: 16, color: DesignTokens.primary),
              label: const Text('Agregar', style: TextStyle(color: DesignTokens.primary,
                  fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 8),
          if (_newItems.isEmpty)
            _emptyCard('Agregue ítems a la carga'),
          ..._newItems.asMap().entries.map((e) => Stack(
            children: [
              _itemCard(e.value),
              Positioned(top: 4, right: 4,
                child: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.red),
                  onPressed: () => setState(() => _newItems.removeAt(e.key)),
                )),
            ],
          )).toList(),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: _saving ? null : _crearCarga,
              style: DesignTokens.primaryButtonStyle,
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('CREAR CARGA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  // ─── NUEVA CARGA (DESKTOP) ────────────────────────────────────────────────
  Widget _buildNewCargaDesktop() {
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPremiumHeader('Nueva Carga'),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // COLUMNA IZQUIERDA
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _labelText('1. SELECCIONAR VIAJE'),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: DesignTokens.primary.withOpacity(0.1))),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                hint: const Text('Seleccionar viaje...', style: TextStyle(color: Colors.black38)),
                                value: _selectedViajeId,
                                items: _viajes.map((v) => DropdownMenuItem<String>(
                                  value: v['id'].toString(),
                                  child: Text('${v['viaje_codigo'] ?? 'S/C'} — ${v['vehiculo_codigo'] ?? 'S/V'} [${v['estado'] ?? ''}]'),
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
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _depositoBloqueado
                                ? DesignTokens.secondary.withOpacity(0.4)
                                : DesignTokens.primary.withOpacity(0.1))),
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
                                  : const Text('CREAR CARGA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                          ]
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              _labelText('3. ÍTEMS DE CARGA'),
                              ElevatedButton.icon(
                                onPressed: () => _showAddItemDialog(),
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('Agregar', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: DesignTokens.surface,
                                  foregroundColor: DesignTokens.primary,
                                  elevation: 0,
                                  side: BorderSide(color: DesignTokens.primary.withOpacity(0.1)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 16),
                            if (_newItems.isEmpty)
                              _emptyCard('Agregue ítems a la carga')
                            else
                              _buildItemsTable(
                                _newItems,
                                isNew: true,
                                onRemove: (idx) => setState(() => _newItems.removeAt(idx))
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
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

  Future<void> _showAddItemDialog() async {
    Map<String, dynamic>? selectedProducto;
    String? selectedProductoCode;
    final qtyController = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: SafeArea(
              top: false,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.75,
                ),
                decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Agregar Ítem', style: TextStyle(fontFamily: 'Manrope',
                          fontSize: 20, fontWeight: FontWeight.w800, color: DesignTokens.primary)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        hint: const Text('Producto'),
                        value: selectedProductoCode,
                        decoration: InputDecoration(
                            filled: true, fillColor: DesignTokens.surfaceLow,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none)),
                        items: _productos.map((p) => DropdownMenuItem<String>(
                          value: p['codigo'].toString(),
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width - 100,
                            child: Text(
                              '${p['codigo'] ?? ''} — ${p['descripcion'] ?? ''}',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        )).toList(),
                        onChanged: (v) => setModal(() {
                          selectedProductoCode = v;
                          selectedProducto = _productos.firstWhere((x) => x['codigo'].toString() == v);
                        }),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: qtyController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: 'Cantidad',
                            filled: true, fillColor: DesignTokens.surfaceLow,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none)),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity, height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            if (selectedProducto == null || qtyController.text.isEmpty) return;
                            setState(() {
                              _newItems.add({
                                'producto_codigo': selectedProducto!['codigo'] ?? selectedProducto!['descripcion'],
                                'cantidad': double.tryParse(qtyController.text) ?? 0,
                                'unidad': selectedProducto!['unidad'] ?? 'UN',
                              });
                            });
                            Navigator.pop(ctx);
                          },
                          style: DesignTokens.primaryButtonStyle,
                          child: const Text('AGREGAR', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showEditCargaDialog() async {
    if (widget.cargaId == null || _carga == null) return;
    final cargaId = widget.cargaId!;
    
    // Copia mutable de los ítems
    final List<Map<String, dynamic>> currentItems = List<Map<String, dynamic>>.from(
      (_carga!['carga_items'] as List? ?? []).map((item) => Map<String, dynamic>.from(item)),
    );

    // Controladores persistentes
    final List<TextEditingController> itemControllers = currentItems
        .map((item) => TextEditingController(
            text: '${(item['cantidad'] ?? 0).toDouble().toStringAsFixed(0)}'))
        .toList();

    String? selectedProductoCodigo;
    final qtyController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: bottomInset, top: 24, left: 24, right: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabecera
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Editar Carga', style: DesignTokens.headlineStyle(color: DesignTokens.primary).copyWith(fontSize: 20)),
                            Text('Carga: ${_carga!['carga_codigo'] ?? ''}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Lista de ítems actuales
                  if (currentItems.isNotEmpty) ...[
                    const Text('ÍTEMS DE LA CARGA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey, letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: currentItems.length,
                      itemBuilder: (_, idx) {
                        final item = currentItems[idx];
                        final ctrl = (idx < itemControllers.length) ? itemControllers[idx] : TextEditingController();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: DesignTokens.primary.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: DesignTokens.primary.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: DesignTokens.primary.withOpacity(0.12)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _productos.any((p) => p['codigo']?.toString() == item['producto_codigo']?.toString())
                                          ? item['producto_codigo']?.toString()
                                          : null,
                                      hint: const Text('Prod.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      isExpanded: true,
                                      style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: DesignTokens.primary, fontSize: 13),
                                      icon: const Icon(Icons.arrow_drop_down, size: 18, color: DesignTokens.primary),
                                      items: _productos.map((p) {
                                        final code = p['codigo']?.toString() ?? '';
                                        return DropdownMenuItem<String>(
                                          value: code,
                                          child: Text(code, overflow: TextOverflow.ellipsis),
                                        );
                                      }).toList(),
                                      onChanged: (v) {
                                        if (v != null) {
                                          setModalState(() {
                                            item['producto_codigo'] = v;
                                            final catalogProd = _productos.firstWhere((p) => p['codigo']?.toString() == v, orElse: () => {});
                                            if (catalogProd.isNotEmpty) {
                                              item['unidad'] = catalogProd['unidad'] ?? 'UN';
                                            }
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 70,
                                child: TextField(
                                  controller: ctrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    border: OutlineInputBorder(),
                                    labelText: 'Cant.',
                                  ),
                                  onChanged: (v) {
                                    final parsed = double.tryParse(v);
                                    if (parsed != null) {
                                      currentItems[idx]['cantidad'] = parsed;
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(item['unidad']?.toString() ?? 'UN', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    currentItems.removeAt(idx);
                                    if (idx < itemControllers.length) {
                                      itemControllers.removeAt(idx).dispose();
                                    }
                                  });
                                },
                                child: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('AGREGAR PRODUCTO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey, letterSpacing: 0.5)),
                  const SizedBox(height: 10),

                  // Selector de producto
                  DropdownButtonFormField<String>(
                    value: selectedProductoCodigo,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Producto',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: _productos.map((p) => DropdownMenuItem<String>(
                      value: p['codigo']?.toString(),
                      child: Text(
                        p['descripcion'] ?? 'S/N',
                        overflow: TextOverflow.ellipsis,
                      ),
                    )).toList(),
                    onChanged: (v) => setModalState(() => selectedProductoCodigo = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Cantidad',
                      prefixIcon: Icon(Icons.numbers_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (selectedProductoCodigo == null || qtyController.text.isEmpty) return;
                        final prod = _productos.firstWhere((p) => p['codigo']?.toString() == selectedProductoCodigo, orElse: () => {});
                        final qty = double.tryParse(qtyController.text) ?? 0;
                        if (qty <= 0) return;
                        setModalState(() {
                          final existing = currentItems.firstWhere(
                            (i) => i['producto_codigo']?.toString() == selectedProductoCodigo,
                            orElse: () => {},
                          );
                          if (existing.isNotEmpty) {
                            existing['cantidad'] = (existing['cantidad'] as num).toDouble() + qty;
                            final existIdx = currentItems.indexOf(existing);
                            if (existIdx < itemControllers.length) {
                              itemControllers[existIdx].text = existing['cantidad'].toStringAsFixed(0);
                            }
                          } else {
                            currentItems.add({
                              'producto_codigo': selectedProductoCodigo,
                              'cantidad': qty,
                              'unidad': prod['unidad'] ?? 'UN',
                            });
                            itemControllers.add(TextEditingController(text: qty.toStringAsFixed(0)));
                          }
                          selectedProductoCodigo = null;
                          qtyController.clear();
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('AGREGAR A LA LISTA'),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Botón guardar
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        for (int i = 0; i < currentItems.length; i++) {
                          if (i < itemControllers.length) {
                            final parsed = double.tryParse(itemControllers[i].text);
                            if (parsed != null) currentItems[i]['cantidad'] = parsed;
                          }
                        }
                        try {
                          await SupabaseService().updateCargaItems(cargaId, currentItems);
                          for (final c in itemControllers) { c.dispose(); }
                          qtyController.dispose();
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _loadCarga();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Carga actualizada correctamente'), backgroundColor: Colors.green),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('GUARDAR CAMBIOS'),
                      style: DesignTokens.primaryButtonStyle,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
