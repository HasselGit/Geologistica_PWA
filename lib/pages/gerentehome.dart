import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../backend/supabase_service.dart';
import '../backend/design_tokens.dart';

class GerenteHomeWidget extends StatefulWidget {
  const GerenteHomeWidget({super.key});

  @override
  State<GerenteHomeWidget> createState() => _GerenteHomeWidgetState();
}

class _GerenteHomeWidgetState extends State<GerenteHomeWidget> {
  bool _loading = true;
  double _totalKg = 0;
  int _viajesEnCurso = 0;
  int _tamboresStock = 0;
  List<Map<String, dynamic>> _viajesActivos = [];

  // Enriched operational stats
  Map<String, dynamic> _viajesCount = {
    'pendientes': 0,
    'enCurso': 0,
    'terminados': 0,
    'total': 0,
  };

  Map<String, dynamic> _solicitudesCount = {
    'recoleccionesTotal': 0,
    'distribucionesTotal': 0,
    'recoleccionesByState': {'Pendiente': 0, 'Asignada': 0, 'En Curso': 0, 'Terminada': 0},
    'distribucionesByState': {'Pendiente': 0, 'Asignada': 0, 'En Curso': 0, 'Terminada': 0},
  };

  List<Map<String, dynamic>> _productTotals = [];

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final stats = await SupabaseService().getGerenteStats();
      
      if (mounted) {
        setState(() {
          _totalKg = (stats['totalKg'] as num?)?.toDouble() ?? 0.0;
          _viajesEnCurso = stats['viajesEnCurso'] ?? 0;
          _viajesActivos = List<Map<String, dynamic>>.from(stats['viajesActivos'] ?? []);
          _tamboresStock = stats['tamboresStock'] ?? 0;
          _viajesCount = Map<String, dynamic>.from(stats['viajesCount'] ?? {});
          _solicitudesCount = Map<String, dynamic>.from(stats['solicitudesCount'] ?? {});
          _productTotals = List<Map<String, dynamic>>.from(stats['productTotals'] ?? []);
          _loading = false;
        });
      }
    } catch (e) {
      print('GerenteHome: Error en _fetchStats: $e');
      if (mounted) setState(() => _loading = false);
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: DesignTokens.primary),
          onPressed: () => context.go('/home'),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dashboard de Gestión', style: DesignTokens.headlineStyle().copyWith(fontSize: 18)),
            Text('ESTADÍSTICAS Y KPIS GENERALES', style: DesignTokens.labelStyle().copyWith(fontSize: 8, color: DesignTokens.primary.withOpacity(0.4))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: DesignTokens.primary),
            onPressed: _fetchStats,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: DesignTokens.primary),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go('/');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator(color: DesignTokens.primary))
        : RefreshIndicator(
            onRefresh: _fetchStats,
            color: DesignTokens.secondary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Boxes Grid (Total volume, active trips, drums stock)
                  _buildSummaryGrid(),
                  const SizedBox(height: 28),

                  // 1. Viajes por Estado Section (Beautiful large boxes)
                  Text('VIAJES POR ESTADO', style: DesignTokens.labelStyle().copyWith(letterSpacing: 1.1, fontSize: 11)),
                  const SizedBox(height: 12),
                  _buildViajesStateGrid(),
                  const SizedBox(height: 28),

                  // 2. Distribuciones & Recolecciones Section
                  Text('DISTRIBUCIONES Y RECOLECCIONES', style: DesignTokens.labelStyle().copyWith(letterSpacing: 1.1, fontSize: 11)),
                  const SizedBox(height: 12),
                  _buildSolicitudesDashboard(),
                  const SizedBox(height: 28),

                  // 3. Totales por Producto Gestionado
                  Text('TOTALES POR PRODUCTO GESTIONADO', style: DesignTokens.labelStyle().copyWith(letterSpacing: 1.1, fontSize: 11)),
                  const SizedBox(height: 12),
                  _buildProductTotalsCard(),
                  const SizedBox(height: 28),

                  // 4. Viajes Activos List
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('VIAJES EN CURSO EN DETALLE', style: DesignTokens.labelStyle().copyWith(letterSpacing: 1.1, fontSize: 11)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: DesignTokens.secondary.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                        child: Text('${_viajesActivos.length} ACTIVOS', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: DesignTokens.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_viajesActivos.isEmpty)
                    _buildEmptyState()
                  else
                    ..._viajesActivos.map((v) => _buildViajeCard(v)).toList(),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSummaryGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.5,
      children: [
        _statBox('CARGA TOTAL EN VIAJE', '${_totalKg.toStringAsFixed(0)} Kg', Icons.scale_rounded, DesignTokens.primary, const Color(0xFFE8F5E9)),
        _statBox('STOCK TAMBORES EN PESAJE', _tamboresStock.toString(), Icons.inventory_2_rounded, DesignTokens.secondary, const Color(0xFFFFFDE7)),
      ],
    );
  }

  Widget _statBox(String label, String value, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, fontFamily: 'Manrope', color: DesignTokens.primary)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.black45, letterSpacing: 0.5, fontFamily: 'Work Sans')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViajesStateGrid() {
    final pCount = _viajesCount['pendientes'] ?? 0;
    final cCount = _viajesCount['enCurso'] ?? 0;
    final tCount = _viajesCount['terminados'] ?? 0;

    return Row(
      children: [
        Expanded(child: _stateCountCard('PENDIENTES', pCount, const Color(0xFF1565C0), const Color(0xFFE3F2FD))),
        const SizedBox(width: 10),
        Expanded(child: _stateCountCard('EN CURSO', cCount, const Color(0xFF7D5700), const Color(0xFFFDEFCC))),
        const SizedBox(width: 10),
        Expanded(child: _stateCountCard('TERMINADOS', tCount, const Color(0xFF1A6B43), const Color(0xFFD4F0E1))),
      ],
    );
  }

  Widget _stateCountCard(String title, int count, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color, fontFamily: 'Manrope'),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5, fontFamily: 'Work Sans'),
          ),
        ],
      ),
    );
  }

  Widget _buildSolicitudesDashboard() {
    final recCount = _solicitudesCount['recoleccionesTotal'] ?? 0;
    final distCount = _solicitudesCount['distribucionesTotal'] ?? 0;
    final Map<String, dynamic> recStates = _solicitudesCount['recoleccionesByState'] ?? {};
    final Map<String, dynamic> distStates = _solicitudesCount['distribucionesByState'] ?? {};

    return Column(
      children: [
        _buildSolCard(
          title: 'RECOLECCIONES',
          subtitle: 'Miel TCM, Miel TRR, Tambores Llenos',
          total: recCount,
          states: recStates,
          primaryColor: const Color(0xFF1565C0),
          bgColor: const Color(0xFFE3F2FD),
          icon: Icons.download_rounded,
          onTap: () => context.push('/recolecciones').then((_) => _fetchStats()),
        ),
        const SizedBox(height: 14),
        _buildSolCard(
          title: 'DISTRIBUCIONES',
          subtitle: 'Tambores Vacíos, Azúcar, Insumos',
          total: distCount,
          states: distStates,
          primaryColor: const Color(0xFF1A6B43),
          bgColor: const Color(0xFFD4F0E1),
          icon: Icons.upload_rounded,
          onTap: () => context.push('/distribuciones').then((_) => _fetchStats()),
        ),
      ],
    );
  }

  Widget _buildSolCard({
    required String title,
    required String subtitle,
    required int total,
    required Map<String, dynamic> states,
    required Color primaryColor,
    required Color bgColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: DesignTokens.primary.withOpacity(0.04)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
                          child: Icon(icon, size: 18, color: primaryColor),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: DesignTokens.primary, fontFamily: 'Manrope')),
                            Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.black38, fontFamily: 'Inter')),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(12)),
                          child: Text('$total TOTAL', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Work Sans')),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right_rounded, color: primaryColor.withOpacity(0.6), size: 20),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 24, thickness: 0.8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _subStateItem('Pendientes', states['Pendiente'] ?? 0, Colors.black54),
                    _subStateItem('Asignadas', states['Asignada'] ?? 0, const Color(0xFF1565C0)),
                    _subStateItem('En Curso', states['En Curso'] ?? 0, const Color(0xFF7D5700)),
                    _subStateItem('Terminadas', states['Terminada'] ?? 0, const Color(0xFF1A6B43)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _subStateItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(value.toString(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color, fontFamily: 'Manrope')),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.black45, fontFamily: 'Work Sans')),
      ],
    );
  }

  Widget _buildProductTotalsCard() {
    if (_productTotals.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: const Center(child: Text('No hay productos gestionados aún', style: TextStyle(color: Colors.black38))),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: DesignTokens.primary.withOpacity(0.04)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _productTotals.length,
        separatorBuilder: (context, index) => const Divider(height: 1, thickness: 0.5),
        itemBuilder: (context, index) {
          final item = _productTotals[index];
          final String prod = item['producto']?.toString() ?? 'DESCONOCIDO';
          final double qty = (item['cantidad'] as num?)?.toDouble() ?? 0.0;
          final String unit = item['unidad']?.toString() ?? 'uni';

          IconData pIcon = Icons.inventory_2_rounded;
          Color pColor = DesignTokens.primary;
          Color pBg = const Color(0xFFECEFF1);

          if (prod.contains('TCM')) {
            pIcon = Icons.hive_rounded;
            pColor = const Color(0xFFB45309);
            pBg = const Color(0xFFFEF3C7);
          } else if (prod.contains('TRR')) {
            pIcon = Icons.hive_outlined;
            pColor = const Color(0xFFD97706);
            pBg = const Color(0xFFFFFBEB);
          } else if (prod.contains('TAMBOR') || prod.contains('TAM')) {
            pIcon = Icons.adjust_rounded;
            pColor = const Color(0xFF0F766E);
            pBg = const Color(0xFFCCFBF1);
          } else if (prod.contains('AZUCAR') || prod.contains('AZ')) {
            pIcon = Icons.grain_rounded;
            pColor = const Color(0xFF475569);
            pBg = const Color(0xFFF1F5F9);
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: pBg, borderRadius: BorderRadius.circular(10)),
                      child: Icon(pIcon, size: 16, color: pColor),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      prod,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: DesignTokens.primary, fontFamily: 'Manrope'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      qty.toStringAsFixed(qty % 1 == 0 ? 0 : 1),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: DesignTokens.primary, fontFamily: 'Manrope'),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unit.toUpperCase(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38, fontFamily: 'Work Sans'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildViajeCard(Map<String, dynamic> v) {
    final chofer = v['profiles'] ?? {};
    final choferName = chofer['nombre'] != null ? '${chofer['nombre']} ${chofer['apellido']}' : 'Sin Asignar';
    final id = v['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: DesignTokens.primary.withOpacity(0.04)),
      ),
      child: InkWell(
        onTap: () => context.push('/viajedetalle?viajeId=$id'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(v['viaje_codigo'] ?? 'V-000', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: DesignTokens.primary, fontFamily: 'Manrope')),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFFDEFCC), borderRadius: BorderRadius.circular(10)),
                    child: const Text('EN CURSO', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF7D5700), fontFamily: 'Work Sans')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 14, color: Colors.black38),
                  const SizedBox(width: 6),
                  Text(choferName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Colors.black54, fontFamily: 'Inter')),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.description_outlined, size: 14, color: Colors.black38),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(v['descripcion'] ?? 'Sin descripción', style: const TextStyle(fontSize: 12, color: Colors.black38, fontFamily: 'Inter'), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Icon(Icons.no_transfer_rounded, size: 40, color: DesignTokens.primary.withOpacity(0.1)),
          const SizedBox(height: 12),
          const Text('No hay viajes activos en este momento', style: TextStyle(color: Colors.black38, fontSize: 12, fontFamily: 'Inter')),
        ],
      ),
    );
  }
}
