import '../flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/supabase_service.dart';
import '../backend/design_tokens.dart';

class RutasPageWidget extends StatefulWidget {
  const RutasPageWidget({super.key});

  static String routeName = 'Rutas';
  static String routePath = '/rutas';

  @override
  State<RutasPageWidget> createState() => _RutasPageWidgetState();
}

class _RutasPageWidgetState extends State<RutasPageWidget> {
  List<Map<String, dynamic>> _rutas = [];
  bool _loading = true;
  String? _error;
  String? _userRole;
  String? _userEmail;

  bool get _isAdmin => _userEmail == 'hassel00@gmail.com' || _userRole == 'Administrador' || _userRole == 'Admin' || Supabase.instance.client.auth.currentUser?.email == 'hassel00@gmail.com';

  @override
  void initState() {
    super.initState();
    _loadRoleAndFetchRutas();
  }

  Future<void> _loadRoleAndFetchRutas() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userRole = prefs.getString('user_puesto');
        _userEmail = prefs.getString('user_email');
      });
    }
    _fetchRutas();
  }

  Future<void> _fetchRutas() async {
    setState(() { _loading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_puesto');
      final userId = prefs.getString('user_id');

      print('RutasPage: Iniciando fetch para role: $userRole, userId: $userId, admin: $_isAdmin');

      final data = await SupabaseService().getViajes(userId: userId, role: userRole);

      if (mounted) setState(() { 
        _rutas = data;
        _loading = false; 
      });
    } catch (e) {
      print('RutasPage: Error en _fetchRutas: $e');
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surfaceLow,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: DesignTokens.primary),
          onPressed: () => context.go('/home'),
        ),
        title: const Text(
          'Gestión de Rutas',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: DesignTokens.primary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: DesignTokens.primary),
            onPressed: _fetchRutas,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: DesignTokens.primary.withOpacity(0.08)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
          : _error != null
              ? _buildError()
              : _rutas.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      color: DesignTokens.secondary,
                      onRefresh: _fetchRutas,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                        itemCount: _rutas.length,
                        itemBuilder: (ctx, i) => _buildRouteCard(_rutas[i]),
                      ),
                    ),
      floatingActionButton: (_isAdmin || (_userRole != null && _userRole != 'Chofer'))
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/planificarViaje'),
              backgroundColor: DesignTokens.secondary,
              icon: const Icon(Icons.add_location_alt_rounded, color: DesignTokens.primary),
              label: const Text(
                'NUEVA RUTA',
                style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, color: DesignTokens.primary),
              ),
            )
          : null,
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> v) {
    final estado = v['estado'] ?? 'Planificado';
    final id = v['id']?.toString() ?? '';
    final displayId = 'RUTA-${id.length > 6 ? id.substring(0, 6).toUpperCase() : id.toUpperCase()}';
    final vehiculo = v['vehiculo'] ?? '';
    final capacidadMax = double.tryParse(v['capacidad_kg']?.toString() ?? '') ?? 0;

    // Compute enriched data from paradas
    final paradas = (v['paradas'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final nParadas = paradas.length;
    
    // Attempt to deduce Origin -> Destination
    String trayecto = 'Ruta sin definir';
    if (nParadas >= 2) {
      final origen = paradas.first['localidad']?.toString().split(',').first ?? 'Origen';
      final destino = paradas.last['localidad']?.toString().split(',').first ?? 'Destino';
      trayecto = '$origen ➔ $destino';
    } else if (nParadas == 1) {
      trayecto = 'Punto: ${paradas.first['localidad']}';
    }

    final desc = v['descripcion']?.toString() ?? '';

    int nRecoleccion = 0;
    double totalKg = 0;
    double collectedKg = 0;
    for (final p in paradas) {
      final tipo = (p['tipo'] ?? p['tipo_operacion'] ?? '').toString().toLowerCase();
      if (tipo.contains('recolec')) nRecoleccion++;

      double stopKg = 0;
      if (p['carga_kg'] != null) {
        stopKg = (p['carga_kg'] as num).toDouble();
      } else {
        final items = p['parada_items'] as List? ?? [];
        for (final item in items) {
          final String prod = (item['producto_codigo'] ?? '').toString().toUpperCase();
          final double qty = (item['cantidad'] as num?)?.toDouble() ?? 0;
          // Usar peso por unidad segun tipo de producto
          if (prod == 'TCM' || prod.contains('TAMBOR') || prod.contains('MIEL')) {
            stopKg += qty * 300; // Tambor con miel ~300 kg
          } else if (prod.startsWith('TV') || prod.startsWith('TE') || prod.contains('VACIO') || prod.contains('VACÍO')) {
            stopKg += qty * 20; // Tambor vacio ~20 kg
          } else if (prod == 'AZ' || prod.contains('AZUCAR')) {
            stopKg += qty * 50; // Bolsa azucar 50 kg
          } else if (qty > 0) {
            stopKg += qty; // fallback: cantidad directamente
          }
        }
      }
      totalKg += stopKg;

      final st = (p['estado'] ?? '').toString().toLowerCase();
      if (st.contains('terminad')) {
        collectedKg += stopKg;
      }
    }

    final progress = totalKg > 0 
        ? (collectedKg / totalKg).clamp(0.0, 1.0) 
        : (nParadas > 0 ? ((paradas.where((p) => (p['estado'] ?? '').toString().toLowerCase().contains('terminad')).length) / nParadas).clamp(0.0, 1.0) : 0.0);
    final pctStr = '${(progress * 100).round()}%';
    
    final totalTambores = (totalKg / 300).round();

    Color statusColor;
    Color statusBg;
    if (estado == 'En Curso' || estado == 'En Proceso' || estado == 'Cargado') {
      statusColor = const Color(0xFF7D5700);
      statusBg = const Color(0xFFFDEFCC);
    } else if (estado == 'Terminado') {
      statusColor = const Color(0xFF1A6B43);
      statusBg = const Color(0xFFD4F0E1);
    } else {
      statusColor = const Color(0xFF1565C0);
      statusBg = const Color(0xFFD6E4FF);
    }

    return GestureDetector(
      onTap: () => context.push('/rutadetalle?viajeId=$id'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: DesignTokens.primary.withOpacity(0.06)),
          boxShadow: [BoxShadow(color: DesignTokens.primary.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trayecto.toUpperCase(),
                          style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w900, fontSize: 14, color: DesignTokens.primary, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          displayId,
                          style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w700, fontSize: 10, color: DesignTokens.primary.withOpacity(0.4)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
                    child: Text(estado.toUpperCase(), style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 9, color: statusColor)),
                  ),
                ],
              ),
              if ((_isAdmin || _userRole == 'Gerente' || _userRole == 'Compras' || _userRole == 'CEO') && 
                  (_isAdmin || estado == 'Planificado' || estado == 'Pendiente'))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_note_rounded, color: DesignTokens.primary, size: 20),
                        onPressed: () async {
                          await context.push('/planificarViaje?editId=$id');
                          _fetchRutas();
                        },
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        onPressed: () => _confirmDeleteRoute(id, displayId),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ],
                  ),
                ),

              Text(
                desc.isNotEmpty ? desc : 'Sin descripción adicional',
                style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: DesignTokens.onSurfaceVariant.withOpacity(0.7), fontStyle: FontStyle.italic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 16),
              
              Row(
                children: [
                  _infoChip(Icons.location_on_rounded, '$nParadas PARADAS'),
                ],
              ),

              const SizedBox(height: 16),
              
              if (nParadas > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Progreso de Ruta', style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: DesignTokens.onSurfaceVariant.withOpacity(0.6))),
                    Text(pctStr, style: const TextStyle(fontFamily: 'Manrope', fontSize: 12, fontWeight: FontWeight.w800, color: DesignTokens.primary)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: DesignTokens.primary.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DesignTokens.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DesignTokens.primary.withOpacity(0.05)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(child: _buildMetricCol('TOTAL ESTIMADO', '${totalKg.round()} kg', Icons.monitor_weight_outlined)),
                    Expanded(child: _buildMetricCol('PROCESADO', '${collectedKg.round()} kg', Icons.check_circle_outline)),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('VER CONTROL DE RUTA', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 11, color: DesignTokens.primary, letterSpacing: 0.5)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: DesignTokens.primary.withOpacity(0.6)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteRoute(String id, String displayId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Ruta'),
        content: Text('¿Estás seguro de que deseas eliminar la ruta $displayId? Las solicitudes asociadas volverán a estar pendientes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ELIMINAR')
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await SupabaseService().deleteViaje(id);
        _fetchRutas();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ruta eliminada correctamente')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: DesignTokens.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w700, fontSize: 9, color: DesignTokens.onSurfaceVariant, letterSpacing: 0.3)),
      ]),
    );
  }

  Widget _buildMetricCol(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: const Color(0xFF08201A).withOpacity(0.5)),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontFamily: 'Work Sans', fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF08201A).withOpacity(0.5))),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontFamily: 'Manrope', fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF08201A))),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: DesignTokens.primary.withOpacity(0.06), shape: BoxShape.circle),
            child: Icon(Icons.alt_route_rounded, size: 36, color: DesignTokens.primary.withOpacity(0.3)),
          ),
          const SizedBox(height: 20),
          const Text('Sin rutas registradas', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 16, color: DesignTokens.primary)),
          const SizedBox(height: 8),
          Text('Las rutas aparecerán aquí cuando sean creadas.', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: DesignTokens.onSurfaceVariant.withOpacity(0.6))),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Error de conexión', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w600, fontSize: 16, color: DesignTokens.primary)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _fetchRutas,
            style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.primary, foregroundColor: Colors.white),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
