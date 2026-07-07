import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../backend/supabase_service.dart';
import '../backend/app_states.dart';
import '../backend/design_tokens.dart';
import '../widgets/geo_sidebar.dart';
import 'package:intl/intl.dart';

class ViajesPageWidget extends StatefulWidget {
  final String? initialEstado;
  const ViajesPageWidget({super.key, this.initialEstado});

  static String routeName = 'Viajes';
  static String routePath = '/viajes';

  @override
  State<ViajesPageWidget> createState() => _ViajesPageWidgetState();
}

class _ViajesPageWidgetState extends State<ViajesPageWidget> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _viajes = [];
  bool _loading = true;
  String? _userRole;
  String? _userId;
  String? _userEmail;
  bool _isAdmin = false;
  
  String _searchQuery = '';
  Timer? _debounce;
  bool _isCardView = true;

  final _tabs = [AppStates.pendiente, AppStates.enCurso, AppStates.terminado];
  final _tabLabels = ['PENDIENTE', 'EN CURSO', 'TERMINADO'];

  @override
  void initState() {
    super.initState();
    int initialIndex = 0;
    if (widget.initialEstado != null) {
      final s = AppStates.normalize(widget.initialEstado!);
      if (s == AppStates.enCurso) initialIndex = 1;
      else if (s == AppStates.terminado) initialIndex = 2;
    }
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex);
    _loadRoleAndFetch();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadRoleAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email') ?? Supabase.instance.client.auth.currentUser?.email ?? '';
    if (mounted) {
      setState(() {
        _userRole = prefs.getString('user_puesto');
        _userId = prefs.getString('user_id');
        _userEmail = email;
        _isAdmin = (email == 'hassel00@gmail.com');
      });
    }
    await _fetchViajes();
  }

  Future<void> _fetchViajes() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService().getViajes(userId: _userId, role: _userRole);
      if (mounted) setState(() { _viajes = data; _loading = false; });
    } catch (e) {
      print('ViajesPage: Error fetching viajes: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _searchQuery = query.toLowerCase());
    });
  }

  List<Map<String, dynamic>> _viajesPorEstado(String estado) {
    var filtered = _viajes.where((v) => AppStates.normalize(v['estado']) == estado).toList();
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((v) {
        final codigo = (v['viaje_codigo'] ?? '').toString().toLowerCase();
        final vehiculo = (v['vehiculo_codigo'] ?? '').toString().toLowerCase();
        
        final rawChofer = v['chofer'];
        String choferNombre = '';
        if (rawChofer is Map) {
          choferNombre = '${rawChofer['nombre'] ?? ''} ${rawChofer['apellido'] ?? ''}'.toLowerCase();
        }

        // Búsqueda en paradas (para apicultor y localidad)
        bool matchParada = false;
        if (v['paradas'] != null && v['paradas'] is List) {
          for (var p in v['paradas']) {
            final loc = (p['localidad'] ?? '').toString().toLowerCase();
            final api = (p['apicultor_nombre'] ?? '').toString().toLowerCase();
            if (loc.contains(_searchQuery) || api.contains(_searchQuery)) {
              matchParada = true;
              break;
            }
          }
        }
        
        return codigo.contains(_searchQuery) || 
               vehiculo.contains(_searchQuery) || 
               choferNombre.contains(_searchQuery) ||
               matchParada;
      }).toList();
    }
    return filtered;
  }

  bool get _canCreate => _isAdmin || (_userRole != null && _userRole != 'Chofer');

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        
        if (isDesktop) {
          return Scaffold(
            backgroundColor: DesignTokens.surfaceLow,
            body: Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: HoneycombPainter(),
                    ),
                  ),
                ),
                Row(
                  children: [
                    GeoSidebar(userRole: _userRole ?? '', userEmail: _userEmail ?? '', displayName: _userEmail ?? ''),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(120, 0, 40, 0),
                          constraints: const BoxConstraints(maxWidth: 1400),
                          child: Column(
                            children: [
                              _buildHeader(isDesktop),
                              Expanded(
                                child: _loading
                                    ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
                                    : _buildKanbanView(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: DesignTokens.surfaceLow,
          body: Column(
            children: [
              _buildHeader(isDesktop),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
                    : TabBarView(
                        controller: _tabController,
                        children: _tabs.map((estado) => _buildViajesList(estado)).toList(),
                      ),
              ),
            ],
          ),
          floatingActionButton: _canCreate && !isDesktop
              ? FloatingActionButton.extended(
                  onPressed: () => context.push('/planificarViaje').then((_) => _fetchViajes()),
                  backgroundColor: DesignTokens.primary,
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  label: const Text('NUEVO VIAJE', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, color: Colors.white)),
                )
              : null,
        );
      },
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(isDesktop ? 0 : 16, isDesktop ? 40 : 16, isDesktop ? 0 : 16, 16),
            child: Row(
              children: [
                if (!isDesktop) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: DesignTokens.primary),
                    onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                  ),
                  const SizedBox(width: 8),
                ],
                const Expanded(
                  child: Text(
                    'Control de Viajes',
                    style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 24, color: DesignTokens.primary, letterSpacing: -0.5),
                  ),
                ),
                // Buscador
                if (isDesktop) _buildSearchBar(),
                const SizedBox(width: 16),
                // Toggle View
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black.withOpacity(0.05))),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.grid_view_rounded, color: _isCardView ? DesignTokens.secondary : Colors.black26),
                        onPressed: () => setState(() => _isCardView = true),
                        tooltip: 'Vista Tarjetas',
                      ),
                      IconButton(
                        icon: Icon(Icons.table_rows_rounded, color: !_isCardView ? DesignTokens.secondary : Colors.black26),
                        onPressed: () => setState(() => _isCardView = false),
                        tooltip: 'Vista Tabla',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black.withOpacity(0.05))),
                  child: IconButton(
                    onPressed: _fetchViajes,
                    icon: const Icon(Icons.refresh_rounded, color: Colors.black45),
                    tooltip: 'Actualizar',
                  ),
                ),
                if (isDesktop && _canCreate) ...[
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/planificarViaje').then((_) => _fetchViajes()),
                    style: DesignTokens.primaryButtonStyle,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text(
                      'NUEVO VIAJE',
                      style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isDesktop) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: _buildSearchBar()),
          if (!isDesktop)
            TabBar(
              controller: _tabController,
              indicatorColor: DesignTokens.secondary,
              indicatorWeight: 3,
              labelColor: DesignTokens.primary,
              unselectedLabelColor: Colors.black38,
              labelStyle: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1),
              unselectedLabelStyle: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: 0.5),
              tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      width: 350,
      height: 40,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black.withOpacity(0.05))),
      child: TextField(
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Buscar viaje, chofer...',
          hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.black38),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.black38),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.black87),
      ),
    );
  }

  Widget _buildKanbanView() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildKanbanColumn('PENDIENTE', AppStates.pendiente)),
          const SizedBox(width: 24),
          Expanded(child: _buildKanbanColumn('EN CURSO', AppStates.enCurso)),
          const SizedBox(width: 24),
          Expanded(child: _buildKanbanColumn('TERMINADO', AppStates.terminado)),
        ],
      ),
    );
  }

  Widget _buildKanbanColumn(String title, String estado) {
    final filtered = _viajesPorEstado(estado);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, top: 12, bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 11, color: DesignTokens.onSurfaceVariant, letterSpacing: 1.5)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(12)),
                  child: Text('${filtered.length}', style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 11, color: DesignTokens.onSurfaceVariant)),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.local_shipping_outlined, size: 48, color: Colors.black12),
                        SizedBox(height: 16),
                        Text('No hay viajes', style: TextStyle(fontFamily: 'Inter', color: Colors.black45, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildTripCard(filtered[i]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildViajesList(String estado) {
    final filtered = _viajesPorEstado(estado);
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.local_shipping_outlined, size: 64, color: Colors.black12),
            SizedBox(height: 16),
            Text('No hay viajes en este estado', style: TextStyle(fontFamily: 'Inter', color: Colors.black45)),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _fetchViajes,
      child: _isCardView ? _buildCardView(filtered) : _buildTableView(filtered),
    );
  }

  Widget _buildCardView(List<Map<String, dynamic>> viajes) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 24,
        runSpacing: 24,
        children: viajes.map((v) => _buildTripCard(v)).toList(),
      ),
    );
  }

  Widget _buildTableView(List<Map<String, dynamic>> viajes) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(const Color(0xFFF9F9F9)),
          dataRowMaxHeight: 64,
          dataRowMinHeight: 64,
          showBottomBorder: true,
          columns: const [
            DataColumn(label: Text('CÓDIGO', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black54))),
            DataColumn(label: Text('CHOFER / VEHÍCULO', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black54))),
            DataColumn(label: Text('FECHA', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black54))),
            DataColumn(label: Text('CANTIDAD', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black54))),
            DataColumn(label: Text('ESTADO', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black54))),
          ],
          rows: viajes.map((v) {
            final id = v['id']?.toString() ?? '';
            final codigo = v['viaje_codigo']?.toString() ?? id;
            final fechaStr = _getFecha(v);
            final choferStr = _getChofer(v);
            final cantidadStr = _getCantidad(v);
            final estado = AppStates.normalize(v['estado']);

            return DataRow(
              onSelectChanged: (_) => context.push('/viajedetalle?viajeId=$id').then((_) => _fetchViajes()),
              cells: [
                DataCell(Text(codigo, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13))),
                DataCell(Text(choferStr, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.black87))),
                DataCell(Text(fechaStr, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.black54))),
                DataCell(Text(cantidadStr, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.black87))),
                DataCell(_buildStatusBadge(estado)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> v) {
    final id = v['id']?.toString() ?? '';
    final codigo = v['viaje_codigo']?.toString() ?? id;
    final estado = AppStates.normalize(v['estado']);
    final fechaStr = _getFecha(v);
    final choferStr = _getChofer(v);
    final cantidadStr = _getCantidad(v);
    final vehiculo = v['vehiculo_codigo']?.toString() ?? 'N/A';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/viajedetalle?viajeId=$id').then((_) => _fetchViajes()),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              codigo,
                              style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 16, color: DesignTokens.onSurface, letterSpacing: -0.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(fechaStr, style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w600, fontSize: 12, color: DesignTokens.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      _buildStatusBadge(estado),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_rounded, size: 16, color: DesignTokens.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(child: Text(choferStr, style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w600, fontSize: 13, color: DesignTokens.onSurface), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.local_shipping_rounded, size: 16, color: DesignTokens.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(child: Text(vehiculo, style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w600, fontSize: 13, color: DesignTokens.onSurface), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(color: DesignTokens.surfaceLow, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('CARGA NETA', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 10, color: DesignTokens.onSurfaceVariant, letterSpacing: 0.5)),
                            Text(cantidadStr, style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 13, color: DesignTokens.primary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String estado) {
    Color bg = DesignTokens.surfaceLow;
    Color fg = DesignTokens.onSurfaceVariant;
    if (estado == AppStates.pendiente) { bg = const Color(0xFFFFF7ED); fg = const Color(0xFFC2410C); }
    else if (estado == AppStates.enCurso) { bg = DesignTokens.secondary.withOpacity(0.15); fg = DesignTokens.primary; }
    else if (estado == AppStates.terminado) { bg = const Color(0xFFF0FDF4); fg = const Color(0xFF15803D); }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(estado.toUpperCase(), style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 10, color: fg, letterSpacing: 1)),
    );
  }

  String _getFecha(Map<String, dynamic> v) {
    final estado = AppStates.normalize(v['estado']);
    final raw = (estado == AppStates.pendiente) ? v['fecha_planificada'] : (estado == AppStates.terminado) ? v['fecha_terminado'] : v['fecha_inicio'];
    final fallback = v['fecha'] ?? v['created_at'];
    final dt = DateTime.tryParse(raw?.toString() ?? fallback?.toString() ?? '');
    return dt != null ? DateFormat('dd/MM/yyyy HH:mm').format(dt) : 'S/D';
  }

  String _getChofer(Map<String, dynamic> v) {
    final raw = v['chofer'];
    if (raw is Map) return '${raw['nombre'] ?? ''} ${raw['apellido'] ?? ''}'.trim();
    return 'Sin chofer asignado';
  }

  String _getCantidad(Map<String, dynamic> v) {
    int kilos = 0;
    int tambores = 0;
    if (v['paradas'] != null && v['paradas'] is List) {
      for (var p in v['paradas']) {
        if (p['parada_items'] != null && p['parada_items'] is List) {
          for (var item in p['parada_items']) {
            kilos += (item['peso_estimado'] as num?)?.toInt() ?? 0;
            tambores += (item['tambores'] as num?)?.toInt() ?? 0;
          }
        }
      }
    }
    if (kilos > 0 || tambores > 0) return '${tambores}T | ${kilos}KG';
    return 'Sin registrar';
  }
}
