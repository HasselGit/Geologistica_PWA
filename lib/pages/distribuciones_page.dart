import '../flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/supabase_service.dart';
import '../backend/design_tokens.dart';

class DistribucionesPageWidget extends StatefulWidget {
  const DistribucionesPageWidget({super.key});

  static String routeName = 'Distribuciones';
  static String routePath = '/distribuciones';

  @override
  State<DistribucionesPageWidget> createState() => _DistribucionesPageWidgetState();
}

class _DistribucionesPageWidgetState extends State<DistribucionesPageWidget>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _planificadas = []; // Solicitudes pendientes
  List<Map<String, dynamic>> _asignadas = [];   // En viajes planificados
  List<Map<String, dynamic>> _enCurso = [];     // En viajes en curso
  List<Map<String, dynamic>> _terminadas = [];  // En viajes terminados
  bool _loading = true;
  String? _error;
  String? _userRole;

  final List<String> _tabs = ['PLANIFICADAS', 'ASIGNADAS', 'EN CURSO', 'TERMINADAS'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadRole();
    _fetchData();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_puesto');
    if (mounted) {
      setState(() {
        _userRole = role;
        if (_userRole == 'Chofer') {
          _tabController = TabController(length: 3, vsync: this);
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final service = SupabaseService();
      
      // 1. Fetch Planificadas (Solicitudes Pendientes de tipo Distribución)
      final solicitudes = await service.getAllNecesidades();
      _planificadas = solicitudes.where((s) => 
        s['estado'] == 'Pendiente' && 
        (s['tipo']?.toString() ?? '').toLowerCase().contains('distribuc')
      ).toList();

      // 2. Fetch Trips to extract paradas
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_puesto');
      final userId = prefs.getString('user_id');
      final viajes = await service.getViajes(userId: userId, role: userRole);

      _asignadas = [];
      _enCurso = [];
      _terminadas = [];

      for (final v in viajes) {
        final estadoViaje = (v['estado'] ?? 'Planificado').toString();
        final paradas = (v['paradas'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        
        for (final p in paradas) {
          final isDistribucion = (p['tipo'] ?? p['tipo_operacion'] ?? '').toString().toLowerCase().contains('distribuc');
          if (!isDistribucion) continue;

          final paradaConViaje = {...p, 'viaje_codigo': v['viaje_codigo'], 'viaje_id': v['id']};
          
          final String estadoParada = (p['estado'] ?? '').toString();
          final bool isParadaTerminada = estadoParada == 'Terminado' || estadoParada == 'Terminada' || (p['remito_id'] != null) || (p['remitos'] as List? ?? []).isNotEmpty;

          if (isParadaTerminada) {
            _terminadas.add(paradaConViaje);
          } else if (estadoViaje == 'Planificado') {
            _asignadas.add(paradaConViaje);
          } else if (estadoViaje == 'En Curso' || estadoViaje == 'En Proceso' || estadoViaje == 'Cargado') {
            _enCurso.add(paradaConViaje);
          } else if (estadoViaje == 'Terminado') {
            _terminadas.add(paradaConViaje);
          }
        }
      }

      if (mounted) setState(() { _loading = false; });
    } catch (e) {
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: DesignTokens.primary),
          onPressed: () => context.go('/home'),
        ),
        title: const Text(
          'Distribuciones',
          style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 17, color: DesignTokens.primary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: DesignTokens.primary),
            onPressed: _fetchData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: DesignTokens.secondary,
            indicatorWeight: 3,
            labelColor: DesignTokens.primary,
            unselectedLabelColor: DesignTokens.primary.withOpacity(0.4),
            labelStyle: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.8),
            tabs: _tabs.where((t) => _userRole != 'Chofer' || t != 'PLANIFICADAS').map((t) => Tab(text: t)).toList(),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
          : TabBarView(
              controller: _tabController,
              children: [
                if (_userRole != 'Chofer') _buildList(_planificadas, 'planificada', isSolicitud: true),
                _buildList(_asignadas, 'asignada'),
                _buildList(_enCurso, 'en curso'),
                _buildList(_terminadas, 'terminada'),
              ],
            ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, String status, {bool isSolicitud = false}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_rounded, size: 48, color: const Color(0xFF08201A).withOpacity(0.2)),
            const SizedBox(height: 16),
            Text('No hay distribuciones $status', style: const TextStyle(color: Color(0xFF424846))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildCard(items[index], isSolicitud),
    );
  }

  Widget _buildCard(Map<String, dynamic> item, bool isSolicitud) {
    final theme = FlutterFlowTheme.of(context);
    final id = item['id']?.toString() ?? '';
    final code = isSolicitud ? (item['solicitud_codigo'] ?? 'SOL-') : (item['viaje_codigo'] ?? 'VIAJE-');
    String? personaNombreFromRemito;
    final rList = item['remitos'] as List? ?? [];
    if (rList.isNotEmpty && rList.first is Map) {
      personaNombreFromRemito = rList.first['persona_nombre']?.toString();
    }

    final title = isSolicitud 
        ? (item['apicultores']?['nombre'] ?? 'Sin nombre')
        : (item['ubicacion'] ?? personaNombreFromRemito ?? 'Sin nombre');
    final subtitle = isSolicitud
        ? (item['apicultores']?['localidad'] ?? 'Sin localidad')
        : (item['localidad'] ?? 'Sin localidad');

    String detail = 'Entrega en Viaje ${item['viaje_codigo'] ?? ''}';
    if (isSolicitud) {
      detail = '${item['cantidad']} UN - ${item['producto'] ?? 'Insumos'}';
    } else {
      final itemsList = List<Map<String, dynamic>>.from(item['parada_items'] ?? []);
      if (itemsList.isNotEmpty) {
        detail = itemsList.map((it) => 'Entrega: ${it['cantidad']} ${it['unidad'] ?? 'Uni'} - ${it['producto_codigo'] ?? ''}').join(', ');
      }
    }

    return GestureDetector(
      onTap: () {
        if (isSolicitud) {
          context.push('/necesidades');
        } else {
          context.push('/viajedetalle?viajeId=${item['viaje_id']}');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(code, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF08201A), fontSize: 12)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSolicitud && (_userRole == 'CEO' || _userRole == 'Gerente' || _userRole == 'Compras')) ...[
                      IconButton(
                        icon: const Icon(Icons.edit_note_rounded, color: DesignTokens.primary, size: 18),
                        onPressed: () => context.push('/necesidades'),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                        onPressed: () => _confirmDeleteSolicitud(item['id'].toString()),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF1A6B43).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(isSolicitud ? 'PENDIENTE' : 'VIAJE', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF1A6B43))),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF08201A))),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF424846))),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF424846)),
                const SizedBox(width: 8),
                Text(detail, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteSolicitud(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Solicitud'),
        content: const Text('¿Estás seguro de que deseas eliminar esta solicitud pendiente?'),
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
        await SupabaseService().deleteSolicitud(id);
        _fetchData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud eliminada')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
