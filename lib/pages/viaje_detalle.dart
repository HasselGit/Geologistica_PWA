import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geo_logistica/backend/supabase_service.dart';
import 'package:geo_logistica/backend/design_tokens.dart';
import 'package:geo_logistica/backend/app_states.dart';
import 'package:geo_logistica/backend/apicultores_data.dart';
import 'package:geo_logistica/flutter_flow/flutter_flow_theme.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import '../widgets/geo_sidebar.dart';

class ViajeDetalleWidget extends StatefulWidget {
  final String viajeId;
  const ViajeDetalleWidget({super.key, required this.viajeId});

  @override
  State<ViajeDetalleWidget> createState() => _ViajeDetalleWidgetState();
}

class _ViajeDetalleWidgetState extends State<ViajeDetalleWidget> {
  Map<String, dynamic>? _viaje;
  bool _loading = true;
  bool _saving = false;
  String? _userRole;
  String? _userId;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadRoleAndData();
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: child,
    );
  }

  Future<void> _loadRoleAndData() async {
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_puesto');
    _userId = prefs.getString('user_id');
    _userEmail = prefs.getString('user_email');
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService().getViajeDetalle(widget.viajeId);
      if (mounted) setState(() => _viaje = data);
    } catch (e) {
      print('Error cargando detalle: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isChofer => _userRole == 'Chofer';
  bool get _isAdmin => _userEmail == 'hassel00@gmail.com' || _userRole == 'Administrador' || _userRole == 'Admin' || Supabase.instance.client.auth.currentUser?.email == 'hassel00@gmail.com';
  String get _displayName => _userEmail ?? 'Usuario';
  bool get _canOperateViaje => _isChofer || _isAdmin;
  bool get _canEditRoute =>
      _isAdmin || _userRole == 'Gerente' || _userRole == 'CEO' || _userRole == 'Compras';

  Future<void> _cambiarEstado(String nuevoEstado) async {
    setState(() => _saving = true);
    try {
      await SupabaseService().updateViajeEstado(widget.viajeId, nuevoEstado);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Viaje actualizado: $nuevoEstado'),
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

  // ─────────────────────────────────────────────────────────────────────────
  // STATUS HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  Color _estadoColor(String estado) {
    final n = AppStates.normalize(estado);
    if (n == AppStates.enCurso) return const Color(0xFF1565C0);
    if (n == AppStates.terminado) return DesignTokens.success;
    if (n == AppStates.pendiente) return DesignTokens.secondary;
    return DesignTokens.onSurfaceVariant;
  }

  IconData _estadoIcon(String estado) {
    final n = AppStates.normalize(estado);
    if (n == AppStates.enCurso) return Icons.play_circle_rounded;
    if (n == AppStates.terminado) return Icons.check_circle_rounded;
    if (n == AppStates.pendiente) return Icons.schedule_rounded;
    return Icons.info_outline_rounded;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: DesignTokens.secondary)));
    if (_viaje == null) return const Scaffold(body: Center(child: Text('No se encontró el viaje')));

    final List<Map<String, dynamic>> paradas = [];
    if (_viaje!['paradas'] is List) {
      for (var p in _viaje!['paradas']) {
        if (p is Map) paradas.add(Map<String, dynamic>.from(p));
      }
    }
    paradas.sort((a, b) {
      final int oA = (a['orden_secuencia'] as num?)?.toInt() ?? 0;
      final int oB = (b['orden_secuencia'] as num?)?.toInt() ?? 0;
      return oA.compareTo(oB);
    });

    final List<Map<String, dynamic>> gastos = [];
    if (_viaje!['gastos'] is List) {
      for (var g in _viaje!['gastos']) {
        if (g is Map) gastos.add(Map<String, dynamic>.from(g));
      }
    }

    dynamic choferRaw = _viaje!['chofer'] ?? _viaje!['profiles'] ?? {};
    Map<String, dynamic> chofer = {};
    if (choferRaw is Map) {
      chofer = Map<String, dynamic>.from(choferRaw);
    } else if (choferRaw is List && choferRaw.isNotEmpty) {
      chofer = Map<String, dynamic>.from(choferRaw.first);
    }

    final choferNombre = (chofer['nombre'] != null)
        ? '${chofer['nombre']} ${chofer['apellido']}'
        : 'ID: ${_viaje!['chofer_id'] ?? 'S/D'}';

    final bool esPendiente = AppStates.normalize(_viaje!['estado']) == AppStates.pendiente;
    final bool esEnCurso = AppStates.normalize(_viaje!['estado']) == AppStates.enCurso;
    final bool tieneRuta = paradas.isNotEmpty;
    final bool todasTerminadas = tieneRuta &&
        paradas.every((p) {
          final String estado = AppStates.normalize(p['estado']);
          final List<dynamic> pRemitos = p['remitos'] as List? ?? [];
          return estado == AppStates.terminado || pRemitos.isNotEmpty;
        });

    final List<Map<String, dynamic>> cargas = [];
    if (_viaje!['cargas'] is List) {
      for (var c in _viaje!['cargas']) {
        if (c is Map) cargas.add(Map<String, dynamic>.from(c));
      }
    }
    final bool tieneCargaPendiente = cargas.any((c) => AppStates.normalize(c['estado']) == AppStates.pendiente);
    final bool puedeIniciar = esPendiente && tieneRuta && !tieneCargaPendiente;

    final List<Map<String, dynamic>> rutasRaw = [];
    if (_viaje!['rutas_data'] is List) {
      for (var r in _viaje!['rutas_data']) {
        if (r is Map) rutasRaw.add(Map<String, dynamic>.from(r));
      }
    }

    // ── LAYOUT DECISION ──────────────────────────────────────────────────────
    return LayoutBuilder(builder: (context, constraints) {
      final bool isWeb = constraints.maxWidth >= 900;

      if (isWeb) {
        return _buildWebLayout(
          theme: theme,
          paradas: paradas,
          gastos: gastos,
          cargas: cargas,
          rutasRaw: rutasRaw,
          choferNombre: choferNombre,
          esPendiente: esPendiente,
          esEnCurso: esEnCurso,
          tieneRuta: tieneRuta,
          todasTerminadas: todasTerminadas,
          tieneCargaPendiente: tieneCargaPendiente,
          puedeIniciar: puedeIniciar,
        );
      }

      // ── MOBILE FALLBACK (original layout) ────────────────────────────────
      return Scaffold(
        backgroundColor: DesignTokens.surface,
        appBar: AppBar(
          title: Text('Viaje ${_viaje!['viaje_codigo']}',
              style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: DesignTokens.primary)),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: DesignTokens.primary),
          actions: [
            if (_isAdmin)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                tooltip: 'Eliminar viaje (Admin)',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Eliminar Viaje'),
                      content: Text(
                          '¿Está seguro de eliminar el viaje ${_viaje!['viaje_codigo']}? Esta acción no se puede deshacer.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('ELIMINAR'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && mounted) {
                    try {
                      await SupabaseService().deleteViaje(widget.viajeId);
                      if (mounted) context.pop();
                    } catch (e) {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red),
                        );
                    }
                  }
                },
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoCard(theme, choferNombre),
              const SizedBox(height: 24),
              _buildOdometerSection(theme, esPendiente, esEnCurso),
              const SizedBox(height: 24),
              if (_canEditRoute && esPendiente && !tieneRuta)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add_road),
                      label: const Text('AGREGAR RUTA Y SOLICITUDES'),
                      style: DesignTokens.primaryButtonStyle,
                      onPressed: () => context.push('/planificarViaje?editId=${widget.viajeId}'),
                    ),
                  ),
                ),
              if (_canOperateViaje) ...[
                if (esPendiente && tieneRuta)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.play_circle_outline_rounded),
                            label: const Text('INICIAR VIAJE'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: puedeIniciar ? const Color(0xFF1565C0) : Colors.grey,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                            onPressed: (_saving || !puedeIniciar) ? null : () => _cambiarEstado(AppStates.enCurso),
                          ),
                        ),
                        if (tieneCargaPendiente)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 14),
                                const SizedBox(width: 6),
                                Text('Carga pendiente de confirmación en depósito',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.orange[800],
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                if (esEnCurso && todasTerminadas)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('FINALIZAR VIAJE'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A6B43),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        onPressed: _saving ? null : () => _cambiarEstado(AppStates.terminado),
                      ),
                    ),
                  ),
                if (esEnCurso)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.alt_route_rounded, size: 18),
                            label: const Text('SOLICITAR CAMBIO DE RECORRIDO'),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.orange),
                              foregroundColor: Colors.orange,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _mostrarDialogoSolicitudCambio(paradas),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.withOpacity(0.3))),
                          child: const Row(children: [
                            Icon(Icons.info_outline_rounded, color: Colors.orange, size: 16),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Puede solicitar cambios en nodos futuros sin detener su marcha.',
                                style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ),
                  ),
              ],
              if (rutasRaw.isNotEmpty) ...[
                _buildSectionTitle(theme, 'Rutas del Viaje', Icons.map_outlined),
                ...rutasRaw.map((ruta) => _buildRutaGroup(ruta, theme)).toList(),
              ] else ...[
                _buildSectionTitle(theme, 'Operaciones y Documentación', Icons.assignment_outlined),
                if (!tieneRuta)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                        child: Text('Pendiente de asignar ruta',
                            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))),
                  )
                else
                  ...paradas.map((p) => _buildParadaItem(p, theme)).toList(),
              ],
              const SizedBox(height: 24),
              _buildSectionTitle(theme, 'Cargas del Vehículo', Icons.inventory_2_outlined),
              if (cargas.isEmpty)
                const Text('Sin cargas asignadas a este viaje.',
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
              else
                ...cargas.map((c) => _buildCargaItem(c, theme)).toList(),
              const SizedBox(height: 24),
              _buildSectionTitle(theme, 'Gastos de Viaje', Icons.account_balance_wallet_outlined),
              if (gastos.isEmpty)
                const Text('Sin gastos registrados.',
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
              else ...[
                ...gastos.map((g) => _buildGastoItem(g, theme)).toList(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('TOTAL GASTOS: ',
                        style: TextStyle(
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: theme.secondaryText)),
                    Text(
                        '\$${gastos.fold<double>(0.0, (sum, g) => sum + (double.tryParse(g['importe']?.toString() ?? '0') ?? 0.0)).toStringAsFixed(2)}',
                        style: TextStyle(
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: theme.primaryText)),
                  ],
                ),
              ],
              const SizedBox(height: 32),
              if (tieneRuta)
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.location_on),
                    label: const Text('VER RECORRIDO COMPLETO'),
                    style: DesignTokens.secondaryButtonStyle,
                    onPressed: () => _openMap(paradas),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WEB LAYOUT BUILDERS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildWebLayout({
    required FlutterFlowTheme theme,
    required List<Map<String, dynamic>> paradas,
    required List<Map<String, dynamic>> gastos,
    required List<Map<String, dynamic>> cargas,
    required List<Map<String, dynamic>> rutasRaw,
    required String choferNombre,
    required bool esPendiente,
    required bool esEnCurso,
    required bool tieneRuta,
    required bool todasTerminadas,
    required bool tieneCargaPendiente,
    required bool puedeIniciar,
  }) {
    // Compute all paradas from rutas OR flat list
    final List<Map<String, dynamic>> allParadas = rutasRaw.isNotEmpty
        ? rutasRaw.expand((r) => List<Map<String, dynamic>>.from(r['paradas'] ?? [])).toList()
        : paradas;
    allParadas.sort((a, b) => ((a['orden_secuencia'] as num?)?.toInt() ?? 0)
        .compareTo((b['orden_secuencia'] as num?)?.toInt() ?? 0));

    final double? oIni = (_viaje!['odometro_inicial'] as num?)?.toDouble();
    final double? oFin = (_viaje!['odometro_final'] as num?)?.toDouble();
    final double? distancia = (oIni != null && oFin != null) ? (oFin - oIni) : null;

    final double totalKg = allParadas.fold<double>(0.0, (sum, p) {
      final pesajes = List<Map<String, dynamic>>.from(p['pesajes'] ?? []);
      return sum +
          pesajes.fold<double>(0.0, (s, pe) {
            final b = (pe['peso_bruto'] as num?)?.toDouble() ?? 0;
            final t = (pe['tara'] as num?)?.toDouble() ?? 0;
            final n = (pe['peso_neto'] as num?)?.toDouble();
            return s + (n ?? (b - t));
          });
    });

    final estadoViaje = _viaje!['estado'] ?? 'Pendiente';
    final estadoColor = _estadoColor(estadoViaje);
    final estadoIcon = _estadoIcon(estadoViaje);

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      body: Stack(
        children: [
          const Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: HoneycombPainter(),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GeoSidebar(
                  userRole: _userRole ?? 'Operador',
                  userEmail: _userEmail ?? '',
                  displayName: _displayName),

          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(120, 0, 40, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Expanded(
                      flex: 8,
                      child: Container(
                        height: double.infinity,
                        decoration: const BoxDecoration(
                          border: Border(right: BorderSide(color: Color(0xFFEEECEB), width: 1)),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(top: 40, bottom: 40, right: 20),
                          child: _buildWebLeftPanel(
                            theme: theme,
                            choferNombre: choferNombre,
                            estadoViaje: estadoViaje,
                            estadoColor: estadoColor,
                            estadoIcon: estadoIcon,
                            esPendiente: esPendiente,
                            esEnCurso: esEnCurso,
                            tieneRuta: tieneRuta,
                            todasTerminadas: todasTerminadas,
                            tieneCargaPendiente: tieneCargaPendiente,
                            puedeIniciar: puedeIniciar,
                            paradas: paradas,
                            cargas: cargas,
                            gastos: gastos,
                            distancia: distancia,
                            totalKg: totalKg,
                          ),
                        ),
                      ),
                    ),
                    // ── RIGHT COLUMN ─────────────────────────────────────────────────
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 20, top: 40, bottom: 40),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Section header
                                  SizedBox(
                                    height: 36,
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'ITINERARIO',
                                          style: TextStyle(
                                            fontFamily: 'Work Sans',
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.5,
                                            color: DesignTokens.onSurfaceVariant,
                                          ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Container(
                                          height: 1,
                                          color: DesignTokens.outline,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: DesignTokens.primary.withOpacity(0.07),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '${allParadas.length} PARADAS',
                                          style: const TextStyle(
                                            fontFamily: 'Work Sans',
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1,
                                            color: DesignTokens.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                              ),
                            ),

                          // Timeline
                          if (allParadas.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 32, bottom: 32),
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: DesignTokens.outline),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.route_outlined,
                                size: 40, color: DesignTokens.onSurfaceVariant.withOpacity(0.4)),
                            const SizedBox(height: 12),
                            const Text('Pendiente de asignar ruta',
                                style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    color: DesignTokens.onSurfaceVariant)),
                            if (_canEditRoute && esPendiente) ...[
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add_road),
                                label: const Text('AGREGAR RUTA'),
                                style: DesignTokens.primaryButtonStyle,
                                onPressed: () =>
                                    context.push('/planificarViaje?editId=${widget.viajeId}'),
                              ),
                            ],
                          ],
                        ),
                      ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                    child: Column(
                      children: allParadas.asMap().entries.map((e) => _buildTimelineNode(e.value, e.key, e.key == allParadas.length - 1)).toList(),
                    ),
                  ),

                // Bottom action strip for web
                if (_canOperateViaje)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                      child: Row(
                        children: [
                          if (esPendiente && tieneRuta)
                            Expanded(
                              child: SizedBox(
                                height: 52,
                                child: ElevatedButton.icon(
                                  icon: _saving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              color: Colors.white, strokeWidth: 2))
                                      : const Icon(Icons.play_circle_outline_rounded),
                                  label: const Text('INICIAR VIAJE'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        puedeIniciar ? const Color(0xFF1565C0) : Colors.grey,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14)),
                                    textStyle: const TextStyle(
                                        fontFamily: 'Manrope',
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14),
                                  ),
                                  onPressed:
                                      (_saving || !puedeIniciar)
                                          ? null
                                          : () => _cambiarEstado(AppStates.enCurso),
                                ),
                              ),
                            ),
                          if (esEnCurso && todasTerminadas)
                            Expanded(
                              child: SizedBox(
                                height: 52,
                                child: ElevatedButton.icon(
                                  icon: _saving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              color: Colors.white, strokeWidth: 2))
                                      : const Icon(Icons.check_circle_outline_rounded),
                                  label: const Text('FINALIZAR VIAJE'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: DesignTokens.success,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14)),
                                    textStyle: const TextStyle(
                                        fontFamily: 'Manrope',
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14),
                                  ),
                                  onPressed: _saving
                                      ? null
                                      : () => _cambiarEstado(AppStates.terminado),
                                ),
                              ),
                            ),
                          if (esEnCurso && (esPendiente || esEnCurso)) ...[
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 52,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.alt_route_rounded, size: 18),
                                label: const Text('CAMBIO DE RECORRIDO'),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.orange),
                                  foregroundColor: Colors.orange,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  textStyle: const TextStyle(
                                      fontFamily: 'Manrope',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13),
                                ),
                                onPressed: () => _mostrarDialogoSolicitudCambio(paradas),
                              ),
                            ),
                          ],
                          if (tieneRuta) ...[
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 52,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.location_on_outlined, size: 18),
                                label: const Text('VER MAPA'),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: DesignTokens.primary),
                                  foregroundColor: DesignTokens.primary,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  textStyle: const TextStyle(
                                      fontFamily: 'Manrope',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13),
                                ),
                                onPressed: () => _openMap(paradas),
                              ),
                            ),
                          ],
                        ],
                      ),
                  ),
              ],
            ), // End of Column
            ), // End of SingleChildScrollView
          ), // End of inner Expanded(flex: 4)
          ], // End of inner Row children
          ), // End of inner Row
          ), // End of Container
          ), // End of Align
          ), // End of outer Expanded
        ], // End of outer Row children
      ), // End of outer Row
      ], // End of Stack children
      ), // End of Stack
    ); // End of Scaffold
  }

  

  String _fmt(dynamic d) {
    if (d == null || d.toString().trim().isEmpty) return '—';
    try {
      final DateTime dt = DateTime.parse(d).toLocal();
      return DateFormat('dd/MM HH:mm').format(dt);
    } catch (_) {
      return d.toString();
    }
  }

  Widget _buildWebCardHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Work Sans',
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: DesignTokens.primary,
      ),
    );
  }

  Widget _buildWebCardIdViaje(Color estadoColor, IconData estadoIcon, String estadoViaje) {
    return _buildGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWebCardHeader('ID DE VIAJE'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: estadoColor.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(estadoIcon, size: 12, color: estadoColor),
                    const SizedBox(width: 4),
                    Text(
                      estadoViaje.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Work Sans',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: estadoColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            _viaje!['viaje_codigo'] ?? '—',
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: DesignTokens.primary,
              height: 1.2,
            ),
          ),
          if (_viaje!['fecha_inicio'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Iniciado: ${_fmt(_viaje!['fecha_inicio'])}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: DesignTokens.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWebCardVehiculo() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWebCardHeader('VEHÍCULO'),
          const Spacer(),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: DesignTokens.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_shipping_rounded, size: 20, color: DesignTokens.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _viaje!['vehiculo_codigo'] ?? 'Sin asignar',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: DesignTokens.primary,
                      ),
                    ),
                    Text(
                      _viaje!['vehiculo_patente'] ?? '',
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11,
                        color: DesignTokens.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebCardChofer(String choferNombre) {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWebCardHeader('CHOFER'),
          const Spacer(),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: DesignTokens.secondary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded, size: 20, color: DesignTokens.secondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  choferNombre,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: DesignTokens.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebCardFechas() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildWebCardHeader('FECHAS'),
          const SizedBox(height: 10),
          _buildWebDateRowCompact(Icons.calendar_today_outlined, 'Planificado', _fmt(_viaje!['fecha_planificada'] ?? _viaje!['fecha']), Colors.blueAccent),
          const SizedBox(height: 6),
          _buildWebDateRowCompact(Icons.play_arrow_rounded, 'Inicio real', _fmt(_viaje!['fecha_inicio']), DesignTokens.success),
          if (_viaje!['fecha_terminado'] != null) ...[
            const SizedBox(height: 6),
            _buildWebDateRowCompact(Icons.check_circle_rounded, 'Terminado', _fmt(_viaje!['fecha_terminado']), DesignTokens.primary),
          ],
        ],
      ),
    );
  }
  
  Widget _buildWebDateRowCompact(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color.withOpacity(0.7)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: DesignTokens.onSurfaceVariant),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildWebCardParadas(List<dynamic> paradas) {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildWebCardHeader('PARADAS'),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: DesignTokens.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.flag_rounded, size: 14, color: DesignTokens.primary.withOpacity(0.7)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${paradas.length}',
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: DesignTokens.primary,
              height: 1,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 1.0, // Replace with actual progress if needed
              backgroundColor: DesignTokens.primary.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(DesignTokens.primary),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebCardCargaNeta(double totalKg) {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildWebCardHeader('CARGA NETA'),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: DesignTokens.secondary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_bottom_rounded, size: 14, color: DesignTokens.secondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                totalKg.toStringAsFixed(0),
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: DesignTokens.secondary,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Text(
                  'kg',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: DesignTokens.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalKg > 0 ? 0.7 : 0, // Placeholder ratio
              backgroundColor: DesignTokens.secondary.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(DesignTokens.secondary),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebCardCargas(List<dynamic> cargas, FlutterFlowTheme theme) {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWebCardHeader('CARGAS ASOCIADAS'),
          const SizedBox(height: 16),
          if (cargas.isEmpty)
            Expanded(
              child: Center(
                child: Text('No hay cargas registradas', style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: DesignTokens.onSurfaceVariant.withOpacity(0.6))),
              ),
            )
          else
            ...cargas.map((c) => _buildCargaItem(c, theme)).toList(),
        ],
      ),
    );
  }

  Widget _buildWebCardGastos(List<dynamic> gastos, FlutterFlowTheme theme) {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWebCardHeader('GASTOS DE VIAJE'),
          const SizedBox(height: 16),
          if (gastos.isEmpty)
            Expanded(
              child: Center(
                child: Text('No hay gastos registrados', style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: DesignTokens.onSurfaceVariant.withOpacity(0.6))),
              ),
            )
          else
            ...gastos.map((g) => _buildGastoItem(g, theme)).toList(),
        ],
      ),
    );
  }

Widget _buildWebLeftPanel({
    required FlutterFlowTheme theme,
    required String choferNombre,
    required String estadoViaje,
    required Color estadoColor,
    required IconData estadoIcon,
    required bool esPendiente,
    required bool esEnCurso,
    required bool tieneRuta,
    required bool todasTerminadas,
    required bool tieneCargaPendiente,
    required bool puedeIniciar,
    required List<Map<String, dynamic>> paradas,
    required List<Map<String, dynamic>> cargas,
    required List<Map<String, dynamic>> gastos,
    required double? distancia,
    required double totalKg,
  }) {
    final fmt = DateFormat('dd/MM HH:mm');
    String _fmt(dynamic d) {
      if (d == null || d.toString().trim().isEmpty) return '—';
      try {
        return fmt.format(DateTime.parse(d.toString().trim()));
      } catch (_) {
        return d.toString();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Back + Header + Acciones ─────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                final userRole = prefs.getString('user_puesto');
                if (userRole == 'Gerente') {
                  context.go('/gerentehome');
                } else {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                }
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: DesignTokens.primary),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Detalle de Viaje',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                  color: DesignTokens.primary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            // Admin delete
            if (_isAdmin)
              GestureDetector(
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Eliminar Viaje'),
                      content: Text(
                          '¿Eliminar viaje ${_viaje!['viaje_codigo']}? Esta acción no se puede deshacer.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('CANCELAR')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('ELIMINAR'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && mounted) {
                    try {
                      await SupabaseService().deleteViaje(widget.viajeId);
                      if (mounted) context.pop();
                    } catch (e) {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Error al eliminar: $e'),
                              backgroundColor: Colors.red),
                        );
                    }
                  }
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      size: 17, color: Colors.redAccent),
                ),
              ),
            if (_isAdmin) const SizedBox(width: 12),
          ],
        ),
        const SizedBox(height: 32),

        // ── 3x2 BENTO GRID ─────────────────────────────────────────────────
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildWebCardIdViaje(estadoColor, estadoIcon, estadoViaje)),
              const SizedBox(width: 16),
              Expanded(child: _buildWebCardVehiculo()),
              const SizedBox(width: 16),
              Expanded(child: _buildWebCardChofer(choferNombre)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildWebCardFechas()),
              const SizedBox(width: 16),
              Expanded(child: _buildWebCardParadas(paradas)),
              const SizedBox(width: 16),
              Expanded(child: _buildWebCardCargaNeta(totalKg)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── ODOMETER COMPACT ──────────────────────────────────────────────
        _buildOdometerSection(theme, esPendiente, esEnCurso),
        const SizedBox(height: 20),

        // ── CARGAS & GASTOS (2 Columns) ───────────────────────────────────
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildWebCardCargas(cargas, theme)),
              const SizedBox(width: 16),
              Expanded(child: _buildWebCardGastos(gastos, theme)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── ADD ROUTE BUTTON ──────────────────────────────────────────────
        if (_canEditRoute && esPendiente && !tieneRuta) ...[
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_road),
              label: const Text('AGREGAR RUTA'),
              style: DesignTokens.primaryButtonStyle,
              onPressed: () => context.push('/planificarViaje?editId=${widget.viajeId}'),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── REQUEST ROUTE CHANGE ──────────────────────────────────────────
        if (esEnCurso && _canOperateViaje)
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.alt_route_rounded, size: 16),
              label: const Text('SOLICITAR CAMBIO DE RECORRIDO'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.orange),
                foregroundColor: Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle:
                    const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 12),
              ),
              onPressed: () => _mostrarDialogoSolicitudCambio(paradas),
            ),
          ),
      ],
    );
  }

  Widget _buildWebDateRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color.withOpacity(0.7)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: DesignTokens.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildWebStatusBadge(String estado, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ESTADO',
                style: TextStyle(
                  fontFamily: 'Work Sans',
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: DesignTokens.onSurfaceVariant,
                ),
              ),
              Text(
                estado.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebStatRow({
    required List<Map<String, dynamic>> paradas,
    required double? distancia,
    required double totalKg,
  }) {
    // Estimación para progress bar, máximo de 30,000 kg si no está definido
    final double maxKg = 30000;
    final double progreso = (totalKg / maxKg).clamp(0.0, 1.0);
    final int completadas = paradas.where((p) => p['estado'] == 'Finalizado').length;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: _buildGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'PARADAS',
                        style: TextStyle(
                          fontFamily: 'Work Sans',
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: DesignTokens.onSurfaceVariant,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: DesignTokens.primary.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.flag_rounded, size: 14, color: DesignTokens.primary.withOpacity(0.7)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${paradas.length}',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: DesignTokens.onSurface,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$completadas completadas',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: DesignTokens.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 7,
            child: _buildGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CARGA NETA',
                        style: TextStyle(
                          fontFamily: 'Work Sans',
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: DesignTokens.onSurfaceVariant,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: DesignTokens.secondary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.hourglass_bottom_rounded, size: 14, color: DesignTokens.secondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        totalKg.toStringAsFixed(0),
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: DesignTokens.secondary,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Text(
                          'kg',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: DesignTokens.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progreso,
                      backgroundColor: DesignTokens.secondary.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(DesignTokens.secondary),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineNode(
      Map<String, dynamic> p, int index, bool isLast) {
    final String rawEstado = (p['estado'] ?? '').toString();
    final String estado = AppStates.normalize(rawEstado);
    final bool isDone = estado == AppStates.terminado ||
        (p['remitos'] as List? ?? []).isNotEmpty;
    final bool isActive = estado == AppStates.enCurso;

    // Node color logic
    final Color nodeColor = isDone
        ? DesignTokens.success
        : isActive
            ? DesignTokens.accent
            : DesignTokens.outline;
    final Color nodeBorderColor = isDone
        ? DesignTokens.success
        : isActive
            ? DesignTokens.secondary
            : DesignTokens.onSurfaceVariant.withOpacity(0.3);
    final Color lineColor = isDone
        ? DesignTokens.success.withOpacity(0.35)
        : DesignTokens.outline;

    // tipo display
    final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(
        (p['parada_items'] ?? []).whereType<Map>());
    bool hasRec = false, hasDist = false;
    for (final it in items) {
      final code = (it['producto_codigo'] ?? '').toString().toUpperCase();
      if (code == 'TCM' || code == '1' || code.contains('MIEL')) {
        hasRec = true;
      } else {
        hasDist = true;
      }
    }
    String tipoDisplay = p['tipo'] ?? 'Operación';
    if (hasRec && hasDist) {
      tipoDisplay = 'Mixta';
    } else if (hasRec) {
      tipoDisplay = 'Recolección';
    } else if (hasDist) {
      tipoDisplay = 'Distribución';
    }

    final Color tipoBg = tipoDisplay == 'Recolección'
        ? DesignTokens.secondary.withOpacity(0.12)
        : tipoDisplay == 'Distribución'
            ? const Color(0xFF1565C0).withOpacity(0.10)
            : DesignTokens.primary.withOpacity(0.08);
    final Color tipoFg = tipoDisplay == 'Recolección'
        ? DesignTokens.secondary
        : tipoDisplay == 'Distribución'
            ? const Color(0xFF1565C0)
            : DesignTokens.primary;

    final bool isViajeTerminado =
        AppStates.normalize(_viaje?['estado']) == AppStates.terminado;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── TIMELINE RAIL ─────────────────────────────────────────────
          SizedBox(
            width: 48,
            child: Column(
              children: [
                // Node circle
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    color: isDone
                        ? DesignTokens.success
                        : isActive
                            ? DesignTokens.accent
                            : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: nodeBorderColor, width: 2),
                    boxShadow: (isDone || isActive)
                        ? [
                            BoxShadow(
                              color: nodeColor.withOpacity(0.25),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white)
                        : isActive
                            ? Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: DesignTokens.secondary,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : Text(
                                '${(p['orden_secuencia'] as num?)?.toInt() ?? index + 1}',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: DesignTokens.onSurfaceVariant
                                      .withOpacity(0.6),
                                ),
                              ),
                  ),
                ),
                // Vertical connecting line
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        color: lineColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── PARADA CARD ───────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  left: 12, bottom: isLast ? 0 : 16, top: 8),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => context
                      .push('/paradaDetalle?paradaId=${p['id']}')
                      .then((_) => _loadData()),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDone
                            ? DesignTokens.success.withOpacity(0.25)
                            : isActive
                                ? DesignTokens.secondary.withOpacity(0.35)
                                : Colors.black.withOpacity(0.05),
                        width: isActive ? 1.5 : 1,
                      ),
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                p['ubicacion'] ?? 'Sin Apicultor',
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: DesignTokens.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: tipoBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tipoDisplay.toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'Work Sans',
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: tipoFg,
                                ),
                              ),
                            ),
                            if (!isViajeTerminado) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.chevron_right_rounded,
                                  size: 18, color: DesignTokens.primary),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 12,
                                color: DesignTokens.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                p['localidad'] ?? 'Sin localidad',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: DesignTokens.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Remito status pill
                            Builder(builder: (ctx) {
                              final remitos =
                                  List<Map<String, dynamic>>.from(
                                      (p['remitos'] ?? []).whereType<Map>());
                              if (remitos.isNotEmpty) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color:
                                        DesignTokens.success.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Text(
                                    'REMITO ✓',
                                    style: TextStyle(
                                      fontFamily: 'Work Sans',
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: DesignTokens.success,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            }),
                          ],
                        ),
                        // Items summary
                        if (items.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: items
                                .take(3)
                                .map((it) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: DesignTokens.primary
                                            .withOpacity(0.05),
                                        borderRadius:
                                            BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        '${it['producto_codigo']}: ${it['cantidad']} ${it['unidad'] ?? ''}'
                                            .trim(),
                                        style: const TextStyle(
                                          fontFamily: 'JetBrains Mono',
                                          fontSize: 9,
                                          color: DesignTokens.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(FlutterFlowTheme theme, String choferNombre) {
    final fmt = DateFormat('dd/MM HH:mm');
    String _format(dynamic date) {
      if (date == null || date.toString().trim().isEmpty) return '—';
      try {
        return fmt.format(DateTime.parse(date.toString().trim()));
      } catch (_) {
        return date.toString();
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          _buildDetailRow('Chofer', choferNombre, Icons.person),
          const Divider(),
          _buildDetailRow('Vehículo', _viaje!['vehiculo_codigo'] ?? 'S/D', Icons.local_shipping),
          const Divider(),
          _buildDetailRow('Estado', _viaje!['estado'] ?? 'Planificado', Icons.info_outline),
          const Divider(),
          // TIMELINE DATES
          _buildTimelineRow('Planificado', _format(_viaje!['fecha_planificada'] ?? _viaje!['fecha']), Icons.calendar_today, Colors.blue),
          _buildTimelineRow('Inicio Real', _format(_viaje!['fecha_inicio']), Icons.play_arrow_rounded, Colors.green),
          if (_viaje!['fecha_terminado'] != null)
            _buildTimelineRow('Terminado', _format(_viaje!['fecha_terminado']), Icons.check_circle_rounded, DesignTokens.primary),
        ],
      ),
    );
  }

  Widget _buildTimelineRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color.withOpacity(0.7)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFC68E17)),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(FlutterFlowTheme theme, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: theme.primary),
          const SizedBox(width: 8),
          Text(title, style: theme.titleSmall),
        ],
      ),
    );
  }

  Widget _buildParadaItem(Map<String, dynamic> p, FlutterFlowTheme theme) {
    final List<Map<String, dynamic>> items = [];
    if (p['parada_items'] is List) {
      for (var it in p['parada_items']) {
        if (it is Map) {
          items.add(Map<String, dynamic>.from(it));
        }
      }
    }

    final List<Map<String, dynamic>> remitos = [];
    if (p['remitos'] is List) {
      for (var r in p['remitos']) {
        if (r is Map) {
          remitos.add(Map<String, dynamic>.from(r));
        }
      }
    }

    final List<Map<String, dynamic>> pesajes = [];
    if (p['pesajes'] is List) {
      for (var pe in p['pesajes']) {
        if (pe is Map) {
          pesajes.add(Map<String, dynamic>.from(pe));
        }
      }
    }
    
    final bool isViajeTerminado = AppStates.normalize(_viaje?['estado']) == AppStates.terminado;
    
    // Determinar tipo display dinámico basado en productos reales
    bool hasRecoleccion = false;
    bool hasDistribucion = false;
    for (var item in items) {
      final code = (item['producto_codigo'] ?? '').toString().toUpperCase();
      if (code == 'TCM' || code == '1' || code.contains('MIEL')) {
        hasRecoleccion = true;
      } else {
        hasDistribucion = true;
      }
    }
    
    String tipoDisplay = p['tipo'] ?? 'Operación';
    if (hasRecoleccion && hasDistribucion) {
      tipoDisplay = 'Mixta';
    } else if (hasRecoleccion) {
                          tipoDisplay = 'Recolección';
    } else if (hasDistribucion) {
      tipoDisplay = 'Distribución';
    }
    
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/paradaDetalle?paradaId=${p['id']}').then((_) => _loadData()),

      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.primary.withOpacity(0.08)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: theme.primary.withOpacity(0.05), shape: BoxShape.circle),
                  child: Center(child: Text('${p['orden_secuencia']}', style: TextStyle(color: theme.primary, fontWeight: FontWeight.w900))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['ubicacion'] ?? 'Sin Apicultor', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF08201A))),
                      Text(p['localidad'] ?? 'Sin Localidad', style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: theme.secondary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(tipoDisplay.toUpperCase(), style: TextStyle(color: theme.primary, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
                ),
                if (!isViajeTerminado) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded, color: DesignTokens.primary, size: 20),
                ],
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, thickness: 0.5),
            ),
            if (items.isNotEmpty) ...[
              const Text(
                'REQUERIMIENTOS:',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              ...items.map((it) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 14, color: DesignTokens.secondary),
                    const SizedBox(width: 8),
                    Text(
                      '${it['producto_codigo']}: ${it['cantidad']} ${it['unidad']}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.primary),
                    ),
                  ],
                ),
              )).toList(),
              const SizedBox(height: 12),
            ],
            if (pesajes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'PESAJES DE TAMBORES (TCM):',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFC68E17),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _showPesajeDetalle(p, pesajes),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFEF3C7)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEF3C7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.scale_rounded, size: 16, color: Color(0xFFB45309)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pesaje de ${pesajes.length} tambores',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF78350F)),
                            ),
                            Text(
                              'Neto total: ${pesajes.fold<double>(0.0, (sum, pe) {
                                final bruto = (pe['peso_bruto'] as num?)?.toDouble() ?? 0.0;
                                final tara = (pe['tara'] as num?)?.toDouble() ?? 0.0;
                                return sum + (bruto - tara);
                              }).toStringAsFixed(1)} kg',
                              style: const TextStyle(fontSize: 10, color: Color(0xFFB45309), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFFB45309)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (remitos.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'DOCUMENTOS DE CONFORMIDAD:',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F5132),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              ...remitos.map((r) {
                final String pdfUrl = r['pdf_url'] ?? '';
                final String persona = r['persona_nombre'] ?? 'Receptor';
                String fechaRemito = '';
                if (r['fecha'] != null) {
                  try {
                    fechaRemito = DateFormat('dd/MM HH:mm').format(DateTime.parse(r['fecha'].toString()));
                  } catch (_) {
                    fechaRemito = r['fecha'].toString();
                  }
                }
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDCFCE7)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded, size: 20, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Remito - $persona',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF14532D)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (fechaRemito.isNotEmpty)
                              Text(
                                'Emitido: $fechaRemito',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                      if (pdfUrl.isNotEmpty) ...[
                        IconButton(
                          icon: const Icon(Icons.visibility_rounded, color: Color(0xFF16A34A), size: 18),
                          tooltip: 'Ver PDF',
                          onPressed: () => _showPdfPreviewDialog(context, pdfUrl, 'Remito - $persona'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.share_rounded, color: Color(0xFF16A34A), size: 18),
                          tooltip: 'Compartir',
                          onPressed: () => _sharePdf(pdfUrl, 'Remito - $persona'),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: remitos.isNotEmpty ? Colors.green.withOpacity(0.08) : Colors.orange.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, size: 16, color: remitos.isNotEmpty ? Colors.green[700] : Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      remitos.isNotEmpty ? 'REMITO: EMITIDO' : 'REMITO: PENDIENTE', 
                      style: TextStyle(
                        fontSize: 11, 
                        fontWeight: FontWeight.w900, 
                        color: remitos.isNotEmpty ? Colors.green[700] : Colors.orange,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (remitos.isNotEmpty) ...[
                      const Spacer(),
                      const Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                    ],
                  ],
                ),
              ),
            ],
            if (remitos.isEmpty && !isViajeTerminado && _canOperateViaje)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app_outlined, size: 14, color: theme.primary.withOpacity(0.5)),
                    const SizedBox(width: 4),
                    Text(
                      'TOCA PARA GESTIONAR ESTA PARADA',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.primary.withOpacity(0.5), letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showPesajeDetalle(Map<String, dynamic> p, List<Map<String, dynamic>> pesajes) {
    final apicultor = p['ubicacion'] ?? p['localidad'] ?? 'S/D';
    final localidad = p['localidad'] ?? 'S/D';
    final viajeCode = _viaje?['viaje_codigo'] ?? 'V-S/N';
    
    final totalBruto = pesajes.fold(0.0, (s, pe) => s + (double.tryParse(pe['peso_bruto']?.toString() ?? '0') ?? 0));
    final totalTara = pesajes.fold(0.0, (s, pe) => s + (double.tryParse(pe['tara']?.toString() ?? '0') ?? 0));
    final totalNeto = pesajes.fold(0.0, (s, pe) {
      final netoDB = double.tryParse(pe['peso_neto']?.toString() ?? '');
      if (netoDB != null) return s + netoDB;
      final b = double.tryParse(pe['peso_bruto']?.toString() ?? '0') ?? 0;
      final t = double.tryParse(pe['tara']?.toString() ?? '0') ?? 0;
      return s + (b - t);
    });

    final bool isViajeTerminado = AppStates.normalize(_viaje?['estado']) == AppStates.terminado;
    final bool canEdit = !isViajeTerminado && (_isChofer || _isAdmin);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, sc) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFBFBFB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detalle de Pesajes',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: DesignTokens.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$apicultor  •  $localidad',
                            style: const TextStyle(fontSize: 13, color: Colors.black45),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF7E7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${pesajes.length} TCM',
                        style: const TextStyle(
                          fontFamily: 'Work Sans',
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: Color(0xFFC68E17),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Totales
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  children: [
                    _totalBox('BRUTO TOTAL', totalBruto, false),
                    const SizedBox(width: 10),
                    _totalBox('TARA TOTAL', totalTara, false),
                    const SizedBox(width: 10),
                    _totalBox('NETO TOTAL', totalNeto, true),
                  ],
                ),
              ),
              // Tabla
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E302C),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: Row(
                          children: [
                            _th('#', 1),
                            _th('CÓD. SENASA', 4),
                            _th('BRUTO', 2, right: true),
                            _th('TARA', 2, right: true),
                            _th('NETO', 2, right: true),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: sc,
                          itemCount: pesajes.length,
                          itemBuilder: (ctx, i) => _detalleRow(i + 1, pesajes[i]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (canEdit)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        context.push(
                          '/agregarPesaje',
                          extra: {
                            'paradaId': p['id']?.toString() ?? '',
                            'viajeId': _viaje?['id']?.toString() ?? '',
                            'viajeCode': viajeCode,
                            'apicultorNombre': apicultor,
                            'localidad': localidad,
                            'apicultorId': p['apicultor_id']?.toString(),
                          },
                        ).then((_) => _loadData());
                      },
                      icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                      label: const Text(
                        'MODIFICAR REGISTROS',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      style: DesignTokens.primaryButtonStyle,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _totalBox(String label, double value, bool highlight) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: highlight ? DesignTokens.secondary.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlight ? DesignTokens.secondary.withOpacity(0.2) : const Color(0xFFEEEEEE),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.bold,
                color: highlight ? DesignTokens.secondary : Colors.black38,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${value.toStringAsFixed(0)} kg',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: highlight ? DesignTokens.secondary : const Color(0xFF424846),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _th(String text, int flex, {bool right = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: const TextStyle(
          fontFamily: 'Work Sans',
          color: Colors.white,
          fontSize: 7,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _detalleRow(int index, Map<String, dynamic> item) {
    final bruto = double.tryParse(item['peso_bruto']?.toString() ?? '0') ?? 0;
    final tara = double.tryParse(item['tara']?.toString() ?? '0') ?? 0;
    final neto = double.tryParse(item['peso_neto']?.toString() ?? '0') ?? (bruto - tara);
    final isEven = index % 2 == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isEven ? const Color(0xFFFAFAFA) : Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
      ),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text('$index', style: const TextStyle(fontSize: 11, color: Colors.black38))),
          Expanded(
            flex: 4,
            child: Text(
              item['senasa_codigo']?.toString() ?? 'TCM',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF424846),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${bruto.toStringAsFixed(0)} kg',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11, color: Color(0xFF424846)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${tara.toStringAsFixed(0)} kg',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11, color: Color(0xFF424846)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${neto.toStringAsFixed(0)} kg',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: DesignTokens.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGastoItem(Map<String, dynamic> g, FlutterFlowTheme theme) {
    String fechaGasto = '—';
    if (g['fecha'] != null && g['fecha'].toString().trim().isNotEmpty) {
      try {
        fechaGasto = DateFormat('dd/MM').format(DateTime.parse(g['fecha'].toString().trim()));
      } catch (_) {
        fechaGasto = g['fecha'].toString();
      }
    }
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.black12)),
      child: ListTile(
        leading: const Icon(Icons.receipt_long, color: Color(0xFF1E352F)),
        title: Text(g['tipo_gasto'] ?? 'Gasto'),
        subtitle: Text(fechaGasto),
        trailing: Text('\$${g['importe']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        onTap: () => _showGastoDetailDialog(context, g),
      ),
    );
  }

  Widget _buildCargaItem(Map<String, dynamic> c, FlutterFlowTheme theme) {
    final estado = AppStates.normalize(c['estado']);
    final items = List<Map<String, dynamic>>.from(c['carga_items'] ?? []);
    final isTerminada = estado == AppStates.terminado;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isTerminada ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ListTile(
        leading: Icon(Icons.inventory_2_outlined, color: isTerminada ? Colors.green : Colors.orange),
        title: Text(c['carga_codigo'] ?? 'CARGA', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Items: ${items.length} • Estado: $estado', style: const TextStyle(fontSize: 12)),
        trailing: isTerminada 
            ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
            : const Icon(Icons.pending_actions_rounded, color: Colors.orange, size: 20),
        onTap: () => context.push('/cargaDetalle?id=${c['id']}').then((_) => _loadData()),
      ),
    );
  }

  Widget _buildRutaGroup(Map<String, dynamic> ruta, FlutterFlowTheme theme) {
    final paradasRuta = List<Map<String, dynamic>>.from(ruta['paradas'] ?? []);
    final bool isViajeEnCurso = AppStates.normalize(_viaje?['estado']) == AppStates.enCurso;
    final bool cambioPendiente = ruta['cambio_solicitado'] == true && isViajeEnCurso;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          child: Row(
            children: [
              InkWell(
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final userRole = prefs.getString('user_puesto');
                  if (userRole == 'Gerente') {
                    context.go('/gerentehome');
                  } else {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
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
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: DesignTokens.primary),
                ),
              ),
              const SizedBox(width: 14),
              const Text('VOLVER', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 11, color: DesignTokens.primary, letterSpacing: 1.5)),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: DesignTokens.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: DesignTokens.primary.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.route_rounded, size: 18, color: DesignTokens.primary),
              const SizedBox(width: 10),
              Text(
                'RUTA: ${ruta['ruta_codigo']}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: DesignTokens.primary),
              ),
              const Spacer(),
              if (cambioPendiente)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(6)),
                  child: const Text('CAMBIO SOLICITADO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
        if (cambioPendiente && _canEditRoute)
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: TextButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('APROBAR CAMBIO DE RECORRIDO'),
              onPressed: () => _aprobarCambio(ruta['id']),
              style: TextButton.styleFrom(foregroundColor: Colors.green, padding: EdgeInsets.zero),
            ),
          ),
        ...paradasRuta.map((p) => _buildParadaItem(p, theme)).toList(),
      ],
    );
  }

  void _mostrarDialogoSolicitudCambio(List<Map<String, dynamic>> paradas) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Solicitar Cambio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿A partir de qué nodo desea solicitar el cambio de recorrido?'),
            const SizedBox(height: 20),
            ...paradas.where((p) => AppStates.normalize(p['estado']) != AppStates.normalize(AppStates.terminado)).map((p) => ListTile(
              title: Text('${p['orden_secuencia']}. ${p['ubicacion']}'),
              onTap: () {
                Navigator.pop(ctx);
                _solicitarCambio(p);
              },
            )).toList(),
          ],
        ),
      ),
    );
  }

  Future<void> _solicitarCambio(Map<String, dynamic> parada) async {
    setState(() => _saving = true);
    try {
      final rutaId = parada['ruta_id'];
      if (rutaId == null) throw 'La parada no tiene una ruta vinculada';
      
      await SupabaseService().solicitarCambioRuta(rutaId: rutaId, paradaId: parada['id']);
      
      // WhatsApp notification
      final msg = 'SOLICITUD DE CAMBIO DE RUTA\nViaje: ${_viaje!['viaje_codigo']}\nChofer: $_userId\nA partir de: ${parada['ubicacion']}';
      final url = 'https://wa.me/5492302123456?text=${Uri.encodeComponent(msg)}'; // Replace with real group/role numbers
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalNonBrowserApplication);
      
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _aprobarCambio(String rutaId) async {
    setState(() => _saving = true);
    try {
      await SupabaseService().aprobarCambioRuta(rutaId: rutaId, rolAprobador: _userRole ?? 'Gerente');
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cambio aprobado'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _saving = false);
    }
  }

  void _openMap(List<Map<String, dynamic>> paradas) async {
    if (paradas.isEmpty) return;
    
    // Ordenar paradas por secuencia para asegurar el recorrido correcto
    final paradasOrdenadas = List<Map<String, dynamic>>.from(paradas);
    paradasOrdenadas.sort((a, b) => (a['orden_secuencia'] ?? 0).compareTo(b['orden_secuencia'] ?? 0));
    
    final intermediateLocalities = paradasOrdenadas
        .map((p) {
          final ubi = (p['ubicacion'] ?? '').toString().trim();
          final loc = (p['localidad'] ?? '').toString().trim();
          if (loc.toLowerCase().contains('sin localidad') || loc.isEmpty || loc == 'S/D') {
            return '';
          }
          
          // Resolver provincia usando el nombre del apicultor (ubicacion)
          String prov = 'La Pampa';
          if (ubi.isNotEmpty) {
            final match = ApicultoresData.fallbackApicultores.firstWhere(
              (a) => a['nombre']?.toString().toLowerCase().trim() == ubi.toLowerCase(),
              orElse: () => <String, dynamic>{},
            );
            if (match.isNotEmpty && match['provincia'] != null) {
              prov = match['provincia'].toString().trim();
            }
          }
          return '$loc, $prov, Argentina';
        })
        .where((s) => s.isNotEmpty)
        .toList();

    final String origin = Uri.encodeComponent('General Pico, La Pampa, Argentina');
    final String destination = Uri.encodeComponent('General Pico, La Pampa, Argentina');
    final String waypoints = intermediateLocalities.isNotEmpty 
        ? Uri.encodeComponent(intermediateLocalities.join('|'))
        : '';
        
    final url = 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&waypoints=$waypoints&travelmode=driving';
    
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      try {
        final uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (err2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo abrir Google Maps: $err2'))
          );
        }
      }
    }
  }

  Future<Uint8List> _downloadPdf(String url) async {
    try {
      // 1. Try public fetch
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return res.bodyBytes;
      }
    } catch (_) {}
    
    // 2. Fallback to Supabase Storage direct download
    try {
      final fileName = url.split('/').last;
      final bytes = await Supabase.instance.client.storage.from('remitos').download(fileName);
      return bytes;
    } catch (e) {
      print('Error downloading PDF from Storage: $e');
      rethrow;
    }
  }

  void _showPdfPreviewDialog(BuildContext context, String url, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Scaffold(
        appBar: AppBar(
          backgroundColor: DesignTokens.primary,
          elevation: 0,
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(ctx),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white),
              tooltip: 'Abrir en Navegador',
              onPressed: () async {
                try {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
                  }
                } catch (e) {
                  print('Error al abrir PDF externo: $e');
                }
              },
            ),
          ],
        ),
        body: FutureBuilder<Uint8List>(
          future: _downloadPdf(url),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: DesignTokens.secondary));
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 16),
                      Text('Error al cargar vista previa del PDF: ${snapshot.error}', textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.open_in_browser_rounded),
                        label: const Text('ABRIR EN NAVEGADOR'),
                        style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.primary),
                        onPressed: () async {
                          try {
                            final uri = Uri.parse(url);
                            await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
                          } catch (_) {}
                        },
                      ),
                    ],
                  ),
                ),
              );
            }
            try {
              return PdfPreview(
                build: (format) => snapshot.data!,
                allowPrinting: true,
                allowSharing: true,
                canChangePageFormat: false,
                dynamicLayout: false,
              );
            } catch (previewErr) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded, color: DesignTokens.primary, size: 48),
                      const SizedBox(height: 16),
                      const Text('El plugin de vista previa no es compatible con este dispositivo.', textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.open_in_browser_rounded),
                        label: const Text('ABRIR CON VISOR NATIVO'),
                        style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.primary),
                        onPressed: () async {
                          try {
                            final uri = Uri.parse(url);
                            await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
                          } catch (_) {}
                        },
                      ),
                    ],
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _sharePdf(String url, String filename) async {
    try {
      final bytes = await _downloadPdf(url);
      await Printing.sharePdf(bytes: bytes, filename: '$filename.pdf');
    } catch (e) {
      print('Error sharing PDF (Printing): $e. Intentando compartir por enlace público...');
      try {
        await Share.share('Remito Digital: $url', subject: filename);
      } catch (shareErr) {
        print('Error en Share fallback: $shareErr');
      }
    }
  }

  void _showGastoDetailDialog(BuildContext context, Map<String, dynamic> g) {
    showDialog(
      context: context,
      builder: (ctx) {
        final tipo = g['tipo_gasto'] ?? 'Gasto';
        final importe = g['importe']?.toString() ?? '0';
        final fecha = DateTime.tryParse(g['fecha']?.toString() ?? '') ?? DateTime.now();
        final fechaStr = DateFormat('dd/MM/yyyy HH:mm').format(fecha);
        final chofer = g['profiles'] != null 
            ? '${g['profiles']['nombre']} ${g['profiles']['apellido']}' 
            : 'S/D';
        final viaje = g['viajes']?['viaje_codigo'] ?? (g['viaje_codigo'] ?? 'S/D');
        final metodo = g['forma_pago'] ?? 'S/D';
        final comprobante = g['nro_comprobante'] ?? 'S/D';
        final descripcion = g['descripcion'] ?? '';
        final ticketUrl = g['comprobante_url'];

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: const BoxDecoration(
                    color: DesignTokens.primary,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Detalle de Gasto',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: DesignTokens.secondary.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                            child: Text(tipo.toUpperCase(), style: const TextStyle(color: Color(0xFF7D5700), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                          ),
                          Text('\$ $importe', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: DesignTokens.primary)),
                        ],
                      ),
                      const Divider(height: 32),
                      _buildGastoDetailRow(Icons.calendar_today_rounded, 'Fecha de registro', fechaStr),
                      const SizedBox(height: 16),
                      _buildGastoDetailRow(Icons.person_rounded, 'Registrado por', chofer),
                      const SizedBox(height: 16),
                      _buildGastoDetailRow(Icons.local_shipping_rounded, 'Viaje asociado', viaje),
                      const SizedBox(height: 16),
                      _buildGastoDetailRow(Icons.payment_rounded, 'Forma de pago', metodo),
                      const SizedBox(height: 16),
                      _buildGastoDetailRow(Icons.receipt_rounded, 'Nro. Comprobante', comprobante),
                      if (tipo.toLowerCase().contains('combustible') && g['cantidad_litros'] != null) ...[
                        const SizedBox(height: 16),
                        _buildGastoDetailRow(Icons.local_gas_station_rounded, 'Litros cargados', '${g['cantidad_litros']} L'),
                      ],
                      if (descripcion.toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text('Observaciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DesignTokens.primary)),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F9F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFEEEEEE)),
                          ),
                          child: Text(descripcion, style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4)),
                        ),
                      ],

                      if (ticketUrl != null && ticketUrl.toString().isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text('Ticket / Comprobante', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DesignTokens.primary)),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (zoomCtx) => Dialog(
                                backgroundColor: Colors.transparent,
                                insetPadding: const EdgeInsets.all(10),
                                child: Stack(
                                  children: [
                                    InteractiveViewer(
                                      panEnabled: true,
                                      minScale: 0.5,
                                      maxScale: 4.0,
                                      child: Center(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: Image.network(ticketUrl, fit: BoxFit.contain),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: CircleAvatar(
                                        backgroundColor: Colors.black54,
                                        child: IconButton(
                                          icon: const Icon(Icons.close, color: Colors.white),
                                          onPressed: () => Navigator.pop(zoomCtx),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Image.network(
                                  ticketUrl,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      height: 180,
                                      color: const Color(0xFFF5F5F5),
                                      child: const Center(child: CircularProgressIndicator(color: DesignTokens.secondary)),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    height: 180,
                                    color: const Color(0xFFFEE2E2),
                                    child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.redAccent, size: 40)),
                                  ),
                                ),
                                Container(
                                  height: 180,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                                    ),
                                  ),
                                ),
                                const Positioned(
                                  bottom: 12,
                                  child: Row(
                                    children: [
                                      Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                                      SizedBox(width: 4),
                                      Text('Toca para ampliar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGastoDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: DesignTokens.secondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13, color: DesignTokens.primary, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  double? _getLitrosFromDescripcion(String? desc) {
    if (desc == null) return null;
    final match = RegExp(r'\[Litros:\s*([0-9.]+)\]').firstMatch(desc);
    if (match != null) {
      return double.tryParse(match.group(1) ?? '');
    }
    return null;
  }

  String _cleanDescripcion(String? desc) {
    if (desc == null) return '';
    return desc.replaceAll(RegExp(r'\n?\[Litros:\s*[0-9.]+\]'), '').trim();
  }

  String _buildNewDescripcion(String? baseDesc, double? litros) {
    final clean = _cleanDescripcion(baseDesc);
    if (litros == null) return clean;
    return '$clean\n[Litros: $litros]'.trim();
  }

  Widget _buildOdometerSection(FlutterFlowTheme theme, bool esPendiente, bool esEnCurso) {
    final double? oIni = (_viaje!['odometro_inicial'] as num?)?.toDouble();
    final double? oFin = (_viaje!['odometro_final'] as num?)?.toDouble();

    final double? distancia = (oIni != null && oFin != null) ? (oFin - oIni) : null;
    
    // Calculate total fuel expenses for this voyage
    final List<Map<String, dynamic>> gastos = [];
    if (_viaje!['gastos'] is List) {
      for (var g in _viaje!['gastos']) {
        if (g is Map) gastos.add(Map<String, dynamic>.from(g));
      }
    }
    
    final double litrosGastos = gastos
        .where((g) => (g['tipo_gasto'] ?? '').toString().toLowerCase().contains('combustible'))
        .fold(0.0, (sum, g) => sum + ((g['cantidad_litros'] as num?)?.toDouble() ?? 0.0));

    final double manualLitros = _getLitrosFromDescripcion(_viaje!['descripcion']) ?? 0.0;
    
    // Preferimos la suma de los gastos, si no hay usamos el manual (antiguo)
    final double? litros = (litrosGastos > 0) ? litrosGastos : (manualLitros > 0 ? manualLitros : null);

    final double gastoCombustible = gastos
        .where((g) => (g['tipo_gasto'] ?? '').toString().toLowerCase().contains('combustible'))
        .fold(0.0, (sum, g) => sum + ((g['importe'] as num?)?.toDouble() ?? 0.0));

    double? rendimientoL100;
    double? rendimientoKmL;
    if (distancia != null && distancia > 0 && litros != null && litros > 0) {
      rendimientoL100 = (litros / distancia) * 100;
      rendimientoKmL = distancia / litros;
    }

    double? costoPorKm;
    if (distancia != null && distancia > 0 && gastoCombustible > 0) {
      costoPorKm = gastoCombustible / distancia;
    }

    // Role-based permissions
    final bool isManagementOrAdmin = _userRole == 'Gerente' || _userRole == 'CEO' || _userRole == 'Compras' || _isAdmin;
    final bool canEditOdometer = isManagementOrAdmin || (_isChofer && (esEnCurso || esPendiente));

    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    String _formatDate(dynamic date) {
      if (date == null || date.toString().trim().isEmpty) return '—';
      try {
        return fmt.format(DateTime.parse(date.toString().trim()));
      } catch (_) {
        return date.toString();
      }
    }

    return _buildGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.scale_rounded, color: DesignTokens.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Control de Odómetro y Consumo',
                    style: DesignTokens.headlineStyle().copyWith(fontSize: 16),
                  ),
                ],
              ),
              if (canEditOdometer)
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: DesignTokens.secondary, size: 20),
                  tooltip: 'Registrar/Editar Datos',
                  onPressed: () => _showOdometerInputDialog(oIni, oFin, litros),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Odómetro Inicial',
                  oIni != null ? '${oIni.toStringAsFixed(1)} KM' : 'Sin registrar',
                  Icons.play_arrow_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  'Odómetro Final',
                  oFin != null ? '${oFin.toStringAsFixed(1)} KM' : 'Sin registrar',
                  Icons.stop_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Distancia Recorrida',
                  distancia != null ? '${distancia.toStringAsFixed(1)} KM' : '—',
                  Icons.trending_up_rounded,
                  color: DesignTokens.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  'Combustible Consumido',
                  litros != null ? '${litros.toStringAsFixed(1)} Litros' : '—',
                  Icons.local_gas_station_rounded,
                  color: DesignTokens.primary,
                ),
              ),
            ],
          ),
          
          if (rendimientoL100 != null || costoPorKm != null) ...[
            const Divider(height: 24),
            Row(
              children: [
                if (rendimientoL100 != null) ...[
                  Expanded(
                    child: _buildMetricTile(
                      'Rendimiento',
                      '${rendimientoL100.toStringAsFixed(2)} L/100km\n(${rendimientoKmL!.toStringAsFixed(2)} km/L)',
                      Icons.speed_rounded,
                      color: const Color(0xFF7D5700),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (costoPorKm != null)
                  Expanded(
                    child: _buildMetricTile(
                      'Costo por KM',
                      '\$ ${costoPorKm.toStringAsFixed(2)} / km\n(Total: \$ ${gastoCombustible.toStringAsFixed(2)})',
                      Icons.attach_money_rounded,
                      color: const Color(0xFF1A6B43),
                    ),
                  ),
              ],
            ),
          ],

          const Divider(height: 24),
          // Time stamps details
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: Colors.black38),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Inicio: ${_formatDate(_viaje!['fecha_inicio'])} • Fin: ${_formatDate(_viaje!['fecha_terminado'])}',
                  style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          if (!_isChofer) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.map_rounded, size: 18),
                label: const Text('SEGUIMIENTO SATELITAL'),
                style: DesignTokens.primaryButtonStyle,
                onPressed: () async {
                  final satelitalUrl = Uri.parse('http://satelital.uninet.com.ar/GpsGateServer/VehicleTracker/VehicleTracker.html?appid=59');
                  try {
                    bool launched = await launchUrl(satelitalUrl, mode: LaunchMode.externalApplication);
                    if (!launched) {
                      await launchUrl(satelitalUrl, mode: LaunchMode.platformDefault);
                    }
                  } catch (e) {
                    try {
                      await launchUrl(satelitalUrl, mode: LaunchMode.platformDefault);
                    } catch (err) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al abrir sitio satelital: $err')),
                        );
                      }
                    }
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
              ],
            ),
            child: Icon(icon, size: 18, color: color ?? Colors.black54),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Work Sans',
                    fontSize: 10,
                    color: Colors.black45,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color ?? Colors.black87,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOdometerInputDialog(double? currentIni, double? currentFin, double? currentLitros) {
    final iniCtrl = TextEditingController(text: currentIni?.toString() ?? '');
    final finCtrl = TextEditingController(text: currentFin?.toString() ?? '');
    final litrosCtrl = TextEditingController(text: currentLitros?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.scale_rounded, color: DesignTokens.primary),
              const SizedBox(width: 10),
              Text('Registrar Datos', style: DesignTokens.headlineStyle().copyWith(fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: iniCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Odómetro Inicial (KM)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.play_arrow_outlined),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: finCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Odómetro Final (KM)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.stop_outlined),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: litrosCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Litros Combustible Consumidos (L)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_gas_station_rounded),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCELAR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final double? dIni = double.tryParse(iniCtrl.text);
                final double? dFin = double.tryParse(finCtrl.text);
                final double? dLitros = double.tryParse(litrosCtrl.text);

                Navigator.pop(ctx);
                setState(() => _loading = true);

                try {
                  final newDesc = _buildNewDescripcion(_viaje!['descripcion'], dLitros);
                  await SupabaseService().updateViajeOdometerAndLitros(
                    widget.viajeId,
                    odometroInicial: dIni,
                    odometroFinal: dFin,
                    descripcion: newDesc,
                  );
                  await _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Datos de odómetro y consumo actualizados correctamente'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al actualizar datos: $e'), backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
              child: const Text('GUARDAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
