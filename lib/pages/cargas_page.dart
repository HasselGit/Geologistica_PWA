import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../backend/supabase_service.dart';
import '../backend/app_states.dart';
import '../backend/design_tokens.dart';
import '../widgets/geo_sidebar.dart';

class CargasPageWidget extends StatefulWidget {
  const CargasPageWidget({super.key});
  static String routePath = '/cargas';

  @override
  State<CargasPageWidget> createState() => _CargasPageWidgetState();
}

class _CargasPageWidgetState extends State<CargasPageWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _cargas = [];
  bool _loading = true;
  bool _isCardView = true;
  String? _userRole;
  String? _userId;
  String? _userEmail;
  String? _displayName;

  String _searchQuery = '';
  Timer? _debounce;

  final _tabs = [AppStates.pendiente, AppStates.enCurso, AppStates.terminado];
  final _tabLabels = ['PENDIENTE', 'EN CURSO', 'TERMINADO'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    if (mounted) {
      setState(() {
        _userRole = prefs.getString('user_puesto');
        _userId = prefs.getString('user_id');
        _userEmail = prefs.getString('user_email');
        _displayName = prefs.getString('user_name') ?? _userEmail;
      });
    }
    await _fetchCargas();
  }

  Future<void> _fetchCargas() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService().getCargas();
      if (mounted) setState(() { _cargas = data; _loading = false; });
    } catch (e) {
      print('CargasPage: Error fetching cargas: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = query.toLowerCase();
        });
      }
    });
  }

  List<Map<String, dynamic>> _cargasPorEstado(String estado) {
    var filtered = _cargas.where((c) => (c['estado'] ?? AppStates.pendiente) == estado).toList();
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((c) {
        final codigo = (c['carga_codigo'] ?? '').toString().toLowerCase();
        final viajeCode = (c['viaje']?['viaje_codigo'] ?? '').toString().toLowerCase();
        final vehiculo = (c['viaje']?['vehiculo_codigo'] ?? '').toString().toLowerCase();
        final choferNombre = ('${c['chofer']?['nombre'] ?? ''} ${c['chofer']?['apellido'] ?? ''}').toLowerCase();
        
        return codigo.contains(_searchQuery) || 
               viajeCode.contains(_searchQuery) || 
               vehiculo.contains(_searchQuery) || 
               choferNombre.contains(_searchQuery);
      }).toList();
    }
    return filtered;
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

  bool get _isAdmin => _userEmail == 'hassel00@gmail.com' || _normalizeRole(_userRole).contains('admin') || Supabase.instance.client.auth.currentUser?.email == 'hassel00@gmail.com';

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

  bool get _canCreate => _isAdmin || _isManagement || _isDeposito;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final mainLayout = isDesktop
        ? Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.fromLTRB(120, 48, 40, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Premium
                Row(
                  children: [
                    InkWell(
                      onTap: () => context.canPop() ? context.pop() : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: DesignTokens.primary.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 16, color: DesignTokens.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => context.go('/home'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: DesignTokens.primary.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: const Icon(Icons.home_rounded,
                            size: 18, color: DesignTokens.primary),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Cargas de Vehículos',
                      style: DesignTokens.headlineStyle(color: DesignTokens.primary)
                          .copyWith(fontSize: 24),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => setState(() => _isCardView = !_isCardView),
                      icon: Icon(_isCardView ? Icons.table_chart_rounded : Icons.dashboard_rounded, color: DesignTokens.primary, size: 22),
                      tooltip: 'Cambiar vista',
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 280,
                      height: 40,
                      child: _buildSearchBar(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: DesignTokens.primary, size: 22),
                      onPressed: _fetchCargas,
                      tooltip: 'Recargar',
                    ),
                    if (_canCreate) ...[
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/cargaDetalle?new=true').then((_) => _fetchCargas()),
                        style: DesignTokens.primaryButtonStyle,
                        icon: const Icon(Icons.add_box_rounded, size: 18),
                        label: const Text('NUEVA CARGA'),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 24),
                // Main Content Area (Kanban Funnel vs Table View)
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
                      : (_isCardView ? _buildKanbanView() : _buildTableView()),
                ),
              ],
            ),
          )
        : Column(
            children: [
              _buildMobileAppBar(),
              Expanded(child: _buildMobileLayout()),
            ],
          );

    final content = Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: const HoneycombPainter()),
          ),
        ),
        mainLayout,
      ],
    );

    return Scaffold(
      backgroundColor: DesignTokens.surfaceLow,
      body: isDesktop
          ? Row(
              children: [
                GeoSidebar(
                  userRole: _userRole ?? '',
                  userEmail: _userEmail ?? '',
                  displayName: _displayName ?? _userEmail ?? '',
                ),
                Expanded(child: content),
              ],
            )
          : content,
      floatingActionButton: _canCreate && !isDesktop
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/cargaDetalle?new=true').then((_) => _fetchCargas()),
              backgroundColor: DesignTokens.secondary,
              icon: const Icon(Icons.add_box_rounded, color: DesignTokens.primary),
              label: const Text('NUEVA CARGA',
                  style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800,
                      color: DesignTokens.primary, fontSize: 11)),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      backgroundColor: DesignTokens.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: DesignTokens.primary, size: 18),
        onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
      ),
      title: const Text('Cargas de Vehículos',
          style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800,
              fontSize: 17, color: DesignTokens.primary)),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: DesignTokens.primary),
          onPressed: _fetchCargas,
        ),
        IconButton(
          icon: const Icon(Icons.home_rounded, color: DesignTokens.primary),
          onPressed: () => context.go('/home'),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(105),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                height: 40,
                child: _buildSearchBar(),
              ),
            ),
            Container(height: 1, color: DesignTokens.primary.withValues(alpha: 0.08)),
            TabBar(
              controller: _tabController,
              labelColor: DesignTokens.primary,
              unselectedLabelColor: DesignTokens.onSurfaceVariant,
              indicatorColor: DesignTokens.secondary,
              labelStyle: const TextStyle(fontFamily: 'Work Sans',
                  fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.5),
              tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKanbanView() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildKanbanColumn('PENDIENTE', AppStates.pendiente)),
        const SizedBox(width: 16),
        Expanded(child: _buildKanbanColumn('EN CURSO', AppStates.enCurso)),
        const SizedBox(width: 16),
        Expanded(child: _buildKanbanColumn('TERMINADO', AppStates.terminado)),
      ],
    );
  }

  Widget _buildKanbanColumn(String title, String estado) {
    final filtered = _cargasPorEstado(estado);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, top: 4, bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Work Sans',
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  color: DesignTokens.onSurfaceVariant,
                  letterSpacing: 1.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${filtered.length}',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: DesignTokens.onSurfaceVariant,
                  ),
                ),
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
                      Icon(Icons.inventory_2_outlined, size: 48, color: Colors.black12),
                      SizedBox(height: 16),
                      Text('Sin cargas en este estado',
                          style: TextStyle(fontFamily: 'Inter', color: Colors.black45, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildCard(filtered[i], isDesktop: true),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTableView() {
    final allFiltered = _cargas.where((c) {
      if (_searchQuery.isEmpty) return true;
      final codigo = (c['carga_codigo'] ?? '').toString().toLowerCase();
      final viajeCode = (c['viaje']?['viaje_codigo'] ?? '').toString().toLowerCase();
      final vehiculo = (c['viaje']?['vehiculo_codigo'] ?? '').toString().toLowerCase();
      final choferNombre = ('${c['chofer']?['nombre'] ?? ''} ${c['chofer']?['apellido'] ?? ''}').toLowerCase();
      return codigo.contains(_searchQuery) ||
          viajeCode.contains(_searchQuery) ||
          vehiculo.contains(_searchQuery) ||
          choferNombre.contains(_searchQuery);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DesignTokens.outline.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(DesignTokens.surfaceLow.withValues(alpha: 0.5)),
          dataRowMaxHeight: 64,
          dataRowMinHeight: 64,
          showBottomBorder: true,
          columns: const [
            DataColumn(label: Text('CÓDIGO', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 11, color: DesignTokens.primary))),
            DataColumn(label: Text('VIAJE / VEHÍCULO', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 11, color: DesignTokens.primary))),
            DataColumn(label: Text('CHOFER', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 11, color: DesignTokens.primary))),
            DataColumn(label: Text('ESTADO', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 11, color: DesignTokens.primary))),
            DataColumn(label: Text('ACCIÓN', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 11, color: DesignTokens.primary))),
          ],
          rows: allFiltered.map((c) {
            final codigo = c['carga_codigo'] ?? 'S/C';
            final viajeCode = c['viaje']?['viaje_codigo'] ?? 'Sin viaje';
            final vehiculo = c['viaje']?['vehiculo_codigo'] ?? '';
            final choferNombre = c['chofer'] != null ? '${c['chofer']['nombre']} ${c['chofer']['apellido']}' : 'S/D';
            final estado = c['estado'] ?? AppStates.pendiente;

            return DataRow(
              cells: [
                DataCell(Text(codigo, style: const TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold, fontSize: 13, color: DesignTokens.primary))),
                DataCell(Text('$viajeCode ${vehiculo.isNotEmpty ? "($vehiculo)" : ""}', style: const TextStyle(fontFamily: 'Inter', fontSize: 13))),
                DataCell(Text(choferNombre, style: const TextStyle(fontFamily: 'Inter', fontSize: 13))),
                DataCell(_buildStatusBadge(estado)),
                DataCell(
                  TextButton.icon(
                    icon: const Icon(Icons.visibility_rounded, size: 16),
                    label: const Text('Ver Detalle', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: DesignTokens.secondary),
                    onPressed: () => context.push('/cargaDetalle?id=${c['id']}').then((_) => _fetchCargas()),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String estado) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Color(AppStates.stateBgColor(estado)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estado.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Work Sans',
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Color(AppStates.stateTextColor(estado)),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return TabBarView(
      controller: _tabController,
      children: _tabs.map((estado) => _buildList(estado, false)).toList(),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      onChanged: _onSearchChanged,
      style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: DesignTokens.onSurface),
      decoration: InputDecoration(
        hintText: 'Buscar código, viaje, chofer...',
        hintStyle: TextStyle(color: DesignTokens.onSurfaceVariant.withValues(alpha: 0.5)),
        prefixIcon: Icon(Icons.search_rounded, size: 18, color: DesignTokens.onSurfaceVariant.withValues(alpha: 0.5)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: DesignTokens.primary.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: DesignTokens.primary.withValues(alpha: 0.1)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: DesignTokens.secondary),
        ),
      ),
    );
  }

  Widget _buildList(String estado, bool isDesktop) {
    final list = _cargasPorEstado(estado);
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76, height: 76,
              decoration: BoxDecoration(
                  color: DesignTokens.primary.withValues(alpha: 0.06),
                  shape: BoxShape.circle),
              child: Icon(Icons.inventory_2_outlined,
                  size: 34, color: DesignTokens.primary.withValues(alpha: 0.3)),
            ),
            const SizedBox(height: 16),
            Text('Sin cargas ${estado.toLowerCase()}',
                style: const TextStyle(fontFamily: 'Manrope',
                    fontWeight: FontWeight.w700, fontSize: 15, color: DesignTokens.primary)),
            const SizedBox(height: 6),
            Text('Las cargas aparecerán aquí.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                    color: DesignTokens.onSurfaceVariant.withValues(alpha: 0.6))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: DesignTokens.secondary,
      onRefresh: _fetchCargas,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        itemCount: list.length,
        itemBuilder: (ctx, i) => _buildCard(list[i], isDesktop: isDesktop),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> c, {bool isDesktop = false}) {
    final estado = c['estado'] ?? AppStates.pendiente;
    final viaje = c['viaje'] as Map<String, dynamic>? ?? {};
    final chofer = c['chofer'] as Map<String, dynamic>? ?? {};
    final items = List<Map<String, dynamic>>.from(c['carga_items'] ?? []);
    final codigo = c['carga_codigo'] ?? 'S/C';
    final viajeCode = viaje['viaje_codigo'] ?? 'S/V';
    final vehiculo = viaje['vehiculo_codigo'] ?? 'S/V';
    final choferNombre = chofer.isNotEmpty
        ? '${chofer['nombre'] ?? ''} ${chofer['apellido'] ?? ''}'.trim()
        : 'Sin chofer';

    final rawFecha = c['created_at'] ?? c['fecha_carga'] ?? c['fecha'];
    String fechaStr = 'S/F';
    if (rawFecha != null) {
      final parsed = DateTime.tryParse(rawFecha.toString());
      if (parsed != null) {
        fechaStr = DateFormat('dd/MM/yyyy HH:mm').format(parsed.toLocal());
      }
    }

    final borderColor = Color(AppStates.stateBorderColor(estado));

    double totalKg = 0;
    int totalTamb = 0;
    for (final item in items) {
      final qty = (item['cantidad'] as num?)?.toDouble() ?? 0;
      final prod = (item['producto_codigo'] ?? '').toString().toUpperCase();
      if (prod == 'TCM' || prod.contains('TAMBOR')) {
        totalKg += qty * 300;
        totalTamb += qty.round();
      } else if ((prod.startsWith('T') && prod != 'TV' && prod != 'TE') ||
          prod.contains('VACIO') ||
          prod.contains('VACÍO')) {
        totalKg += qty * 20;
        totalTamb += qty.round();
      } else if (prod == 'AZ') {
        totalKg += qty * 50;
      } else {
        totalKg += qty;
      }
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.push('/cargaDetalle?id=${c['id']}').then((_) => _fetchCargas()),
        child: Container(
          margin: isDesktop ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DesignTokens.primary.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    codigo,
                                    style: const TextStyle(
                                      fontFamily: 'Manrope',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: DesignTokens.primary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded,
                                          size: 11, color: DesignTokens.onSurfaceVariant),
                                      const SizedBox(width: 4),
                                      Text(
                                        fechaStr,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w500,
                                          fontSize: 11,
                                          color: DesignTokens.onSurfaceVariant.withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            _buildStatusBadge(estado),
                            if (isDesktop) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right_rounded, color: DesignTokens.primary, size: 18),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Divider(height: 1, color: DesignTokens.primary.withValues(alpha: 0.06)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.local_shipping_outlined, size: 13,
                                color: DesignTokens.onSurfaceVariant.withValues(alpha: 0.6)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Viaje: $viajeCode ${vehiculo != "S/V" ? "($vehiculo)" : ""}',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: DesignTokens.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded, size: 13,
                                color: DesignTokens.onSurfaceVariant.withValues(alpha: 0.6)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                choferNombre,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: DesignTokens.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (items.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4, runSpacing: 4,
                            children: items.take(3).map((it) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: DesignTokens.primary.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                '${it['producto_codigo']} • ${it['cantidad']}',
                                style: const TextStyle(fontFamily: 'Work Sans',
                                    fontWeight: FontWeight.w700, fontSize: 9,
                                    color: DesignTokens.onSurfaceVariant),
                              ),
                            )).toList(),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          decoration: BoxDecoration(
                              color: DesignTokens.surfaceLow,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: DesignTokens.primary.withValues(alpha: 0.04))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _metricCol('PESO EST.', '${totalKg.round()} kg',
                                  Icons.monitor_weight_outlined),
                              Container(width: 1, height: 22,
                                  color: DesignTokens.primary.withValues(alpha: 0.08)),
                              _metricCol('TAMBORES', '$totalTamb un.',
                                  Icons.inventory_2_outlined),
                              Container(width: 1, height: 22,
                                  color: DesignTokens.primary.withValues(alpha: 0.08)),
                              _metricCol('ÍTEMS', '${items.length}',
                                  Icons.list_alt_rounded),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricCol(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: DesignTokens.primary.withValues(alpha: 0.5)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Work Sans',
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: DesignTokens.primary.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: DesignTokens.primary,
          ),
        ),
      ],
    );
  }
}

