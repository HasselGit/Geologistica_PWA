import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../backend/supabase_service.dart';
import '../backend/app_states.dart';
import '../backend/design_tokens.dart';

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
  String? _userRole;
  String? _userId;
  String? _userEmail;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        
        return Scaffold(
          backgroundColor: DesignTokens.surfaceLow,
          appBar: isDesktop ? null : _buildMobileAppBar(),
          body: _loading
            ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
            : isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
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
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      backgroundColor: DesignTokens.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: DesignTokens.primary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text('Cargas de Vehículos',
          style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800,
              fontSize: 17, color: DesignTokens.primary)),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: DesignTokens.primary),
          onPressed: _fetchCargas,
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
            Container(height: 1, color: DesignTokens.primary.withOpacity(0.08)),
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

  Widget _buildDesktopLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
          color: DesignTokens.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: DesignTokens.primary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  const Text('Cargas de Vehículos',
                      style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800,
                          fontSize: 24, color: DesignTokens.primary)),
                  const Spacer(),
                  SizedBox(
                    width: 300,
                    height: 40,
                    child: _buildSearchBar(),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: DesignTokens.primary),
                    onPressed: _fetchCargas,
                    tooltip: 'Recargar',
                  ),
                  if (_canCreate) ...[
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/cargaDetalle?new=true').then((_) => _fetchCargas()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DesignTokens.secondary,
                        foregroundColor: DesignTokens.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add_box_rounded, size: 18),
                      label: const Text('NUEVA CARGA',
                          style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ),
                  ]
                ],
              ),
              const SizedBox(height: 24),
              TabBar(
                controller: _tabController,
                labelColor: DesignTokens.primary,
                unselectedLabelColor: DesignTokens.onSurfaceVariant,
                indicatorColor: DesignTokens.secondary,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontFamily: 'Work Sans',
                    fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5),
                tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
              ),
            ],
          ),
        ),
        Container(height: 1, color: DesignTokens.primary.withOpacity(0.08)),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _tabs.map((estado) => _buildList(estado, true)).toList(),
          ),
        ),
      ],
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
        hintStyle: TextStyle(color: DesignTokens.onSurfaceVariant.withOpacity(0.5)),
        prefixIcon: Icon(Icons.search_rounded, size: 18, color: DesignTokens.onSurfaceVariant.withOpacity(0.5)),
        filled: true,
        fillColor: DesignTokens.surfaceLow,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: DesignTokens.primary.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: DesignTokens.primary.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
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
                  color: DesignTokens.primary.withOpacity(0.06),
                  shape: BoxShape.circle),
              child: Icon(Icons.inventory_2_outlined,
                  size: 34, color: DesignTokens.primary.withOpacity(0.3)),
            ),
            const SizedBox(height: 16),
            Text('Sin cargas ${estado.toLowerCase()}',
                style: const TextStyle(fontFamily: 'Manrope',
                    fontWeight: FontWeight.w700, fontSize: 15, color: DesignTokens.primary)),
            const SizedBox(height: 6),
            Text('Las cargas aparecerán aquí.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                    color: DesignTokens.onSurfaceVariant.withOpacity(0.6))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: DesignTokens.secondary,
      onRefresh: _fetchCargas,
      child: isDesktop 
          ? GridView.builder(
              padding: const EdgeInsets.all(32),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 420,
                mainAxisSpacing: 24,
                crossAxisSpacing: 24,
                mainAxisExtent: 230,
              ),
              itemCount: list.length,
              itemBuilder: (ctx, i) => _buildCargaCard(list[i], true),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              itemCount: list.length,
              itemBuilder: (ctx, i) => _buildCargaCard(list[i], false),
            ),
    );
  }

  Widget _buildCargaCard(Map<String, dynamic> c, bool isDesktop) {
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

    final bgColor = Color(AppStates.stateBgColor(estado));
    final textColor = Color(AppStates.stateTextColor(estado));
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
          margin: isDesktop ? EdgeInsets.zero : const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: DesignTokens.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DesignTokens.primary.withOpacity(0.06)),
            boxShadow: [BoxShadow(
                color: DesignTokens.primary.withOpacity(0.04),
                blurRadius: 24, offset: const Offset(0, 8))],
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
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(vehiculo,
                                    style: TextStyle(fontFamily: 'Work Sans',
                                        fontWeight: FontWeight.w700, fontSize: 10,
                                        color: DesignTokens.primary.withOpacity(0.5),
                                        letterSpacing: 0.8)),
                                const SizedBox(height: 4),
                                Text(codigo,
                                    style: const TextStyle(fontFamily: 'Manrope',
                                        fontWeight: FontWeight.w800, fontSize: 18,
                                        color: DesignTokens.primary),
                                    overflow: TextOverflow.ellipsis),
                              ]),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: bgColor,
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text(estado.toUpperCase(),
                                  style: TextStyle(fontFamily: 'Work Sans',
                                      fontWeight: FontWeight.w800, fontSize: 10,
                                      color: textColor)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(height: 1, color: DesignTokens.primary.withOpacity(0.06)),
                        const SizedBox(height: 16),
                        Row(children: [
                          Icon(Icons.local_shipping_outlined, size: 14,
                              color: DesignTokens.onSurfaceVariant.withOpacity(0.6)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Viaje: $viajeCode',
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 13,
                                    color: DesignTokens.onSurfaceVariant),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.person_outline_rounded, size: 14,
                              color: DesignTokens.onSurfaceVariant.withOpacity(0.6)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(choferNombre,
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 13,
                                    color: DesignTokens.onSurfaceVariant),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                        if (items.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6, runSpacing: 4,
                            children: items.take(3).map((it) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: DesignTokens.primary.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text(
                                '${it['producto_codigo']} × ${it['cantidad']}',
                                style: const TextStyle(fontFamily: 'Work Sans',
                                    fontWeight: FontWeight.w700, fontSize: 9,
                                    color: DesignTokens.onSurfaceVariant),
                              ),
                            )).toList(),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                              color: DesignTokens.surfaceLow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: DesignTokens.primary.withOpacity(0.04))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _metricCol('PESO EST.', '${totalKg.round()} kg',
                                  Icons.monitor_weight_outlined),
                              Container(width: 1, height: 32,
                                  color: DesignTokens.primary.withOpacity(0.08)),
                              _metricCol('TAMBORES', '$totalTamb un.',
                                  Icons.inventory_2_outlined),
                              Container(width: 1, height: 32,
                                  color: DesignTokens.primary.withOpacity(0.08)),
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
    return Column(children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: DesignTokens.primary.withOpacity(0.5)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontFamily: 'Work Sans', fontSize: 9,
              fontWeight: FontWeight.bold, color: DesignTokens.primary.withOpacity(0.5))),
        ]
      ),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontFamily: 'Manrope', fontSize: 13,
          fontWeight: FontWeight.w800, color: DesignTokens.primary)),
    ]);
  }
}

