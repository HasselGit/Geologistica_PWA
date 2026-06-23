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
      print('CargasPage: Cargas fetched. Count: ${data.length}');
      for (var c in data) {
        print('CargasPage: Carga ID=${c['id']}, Codigo=${c['carga_codigo']}, Items=${c['carga_items']} (type: ${c['carga_items']?.runtimeType})');
      }
      if (mounted) setState(() { _cargas = data; _loading = false; });
    } catch (e) {
      print('CargasPage: Error fetching cargas: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _cargasPorEstado(String estado) =>
      _cargas.where((c) => (c['estado'] ?? AppStates.pendiente) == estado).toList();

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
    return Scaffold(
      backgroundColor: DesignTokens.surfaceLow,
      appBar: AppBar(
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
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
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
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
          : TabBarView(
              controller: _tabController,
              children: _tabs.map((estado) => _buildList(estado)).toList(),
            ),
      floatingActionButton: _canCreate
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

  Widget _buildList(String estado) {
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
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        itemCount: list.length,
        itemBuilder: (ctx, i) => _buildCargaCard(list[i]),
      ),
    );
  }

  Widget _buildCargaCard(Map<String, dynamic> c) {
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

    // Calcular totales
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

    return GestureDetector(
      onTap: () => context.push('/cargaDetalle?id=${c['id']}').then((_) => _fetchCargas()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: DesignTokens.primary.withOpacity(0.06)),
          boxShadow: [BoxShadow(
              color: DesignTokens.primary.withOpacity(0.05),
              blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Borde color estado
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18), bottomLeft: Radius.circular(18)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(vehiculo,
                                style: TextStyle(fontFamily: 'Work Sans',
                                    fontWeight: FontWeight.w700, fontSize: 9,
                                    color: DesignTokens.primary.withOpacity(0.4),
                                    letterSpacing: 0.8)),
                            const SizedBox(height: 2),
                            Text(codigo,
                                style: const TextStyle(fontFamily: 'Manrope',
                                    fontWeight: FontWeight.w800, fontSize: 18,
                                    color: DesignTokens.primary)),
                          ]),
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
                      const SizedBox(height: 12),
                      Divider(height: 1, color: DesignTokens.primary.withOpacity(0.06)),
                      const SizedBox(height: 12),
                      // Info: viaje y chofer
                      Row(children: [
                        Icon(Icons.local_shipping_outlined, size: 13,
                            color: DesignTokens.onSurfaceVariant.withOpacity(0.5)),
                        const SizedBox(width: 6),
                        Text('Viaje: $viajeCode',
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 12,
                                color: DesignTokens.onSurfaceVariant)),
                        const SizedBox(width: 14),
                        Icon(Icons.person_outline_rounded, size: 13,
                            color: DesignTokens.onSurfaceVariant.withOpacity(0.5)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(choferNombre,
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 12,
                                color: DesignTokens.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis)),
                      ]),
                      const SizedBox(height: 12),
                      // Items resumen
                      if (items.isNotEmpty) ...[
                        Wrap(
                          spacing: 6, runSpacing: 4,
                          children: items.take(3).map((it) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: DesignTokens.surfaceLow,
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              '${it['producto_codigo']} × ${it['cantidad']}',
                              style: const TextStyle(fontFamily: 'Work Sans',
                                  fontWeight: FontWeight.w700, fontSize: 9,
                                  color: DesignTokens.onSurfaceVariant),
                            ),
                          )).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Totales
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: DesignTokens.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: DesignTokens.primary.withOpacity(0.05))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _metricCol('PESO EST.', '${totalKg.round()} kg',
                                Icons.monitor_weight_outlined),
                            Container(width: 1, height: 24,
                                color: DesignTokens.primary.withOpacity(0.08)),
                            _metricCol('TAMBORES', '$totalTamb un.',
                                Icons.inventory_2_outlined),
                            Container(width: 1, height: 24,
                                color: DesignTokens.primary.withOpacity(0.08)),
                            _metricCol('ÍTEMS', '${items.length}',
                                Icons.list_alt_rounded),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        const Text('VER DETALLE',
                            style: TextStyle(fontFamily: 'Work Sans',
                                fontWeight: FontWeight.w800, fontSize: 11,
                                color: DesignTokens.primary, letterSpacing: 0.5)),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 14,
                            color: DesignTokens.primary.withOpacity(0.6)),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricCol(String label, String value, IconData icon) {
    return Column(children: [
      Row(children: [
        Icon(icon, size: 11, color: DesignTokens.primary.withOpacity(0.4)),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontFamily: 'Work Sans', fontSize: 9,
            fontWeight: FontWeight.bold, color: DesignTokens.primary.withOpacity(0.4))),
      ]),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontFamily: 'Manrope', fontSize: 13,
          fontWeight: FontWeight.w800, color: DesignTokens.primary)),
    ]);
  }
}
