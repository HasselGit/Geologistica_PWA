import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/supabase_service.dart';
import '../backend/design_tokens.dart';
import '../widgets/geo_sidebar.dart';
import '../widgets/geo_bento_card.dart';

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

  String _userRole = '';
  String _userEmail = '';
  String _displayName = '';

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
    
    // Bloqueo de seguridad para rol administrativo
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_puesto') ?? '';
    _userRole = role;
    _userEmail = prefs.getString('user_email') ?? '';
    _displayName = prefs.getString('user_name') ?? '';
    
    final roleNormalized = role.toLowerCase().replaceAll('á', 'a').replaceAll('ó', 'o').replaceAll('í', 'i').replaceAll('é', 'e').replaceAll('ú', 'u').trim();
    
    if (roleNormalized.contains('administrativo') || roleNormalized.contains('administracion') || roleNormalized.contains('gastos')) {
      if (mounted) context.go('/home');
      return;
    }

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
    return LayoutBuilder(builder: (context, constraints) {
      final isWeb = constraints.maxWidth >= 900;
      Widget scaffold = Scaffold(
        backgroundColor: isWeb ? Colors.transparent : DesignTokens.surfaceLow,
        appBar: isWeb ? null : AppBar(
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
          : (isWeb ? _buildHighEndDesktopLayout() : _buildMobileLayout()),
      );
      if (isWeb) {
        return Scaffold(
          backgroundColor: Colors.transparent,
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
                children: [
                  GeoSidebar(userRole: _userRole, userEmail: _userEmail, displayName: _displayName),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(120, 0, 40, 0),
                        child: ClipRRect(child: scaffold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }
      return scaffold;
    });
  }

  Widget _buildMobileLayout() {
    return RefreshIndicator(
      onRefresh: _fetchStats,
      color: DesignTokens.secondary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryGrid(false),
            const SizedBox(height: 28),
            Text('VIAJES POR ESTADO', style: DesignTokens.labelStyle().copyWith(letterSpacing: 1.1, fontSize: 11)),
            const SizedBox(height: 12),
            _buildViajesStateGrid(),
            const SizedBox(height: 28),
            Text('DISTRIBUCIONES Y RECOLECCIONES', style: DesignTokens.labelStyle().copyWith(letterSpacing: 1.1, fontSize: 11)),
            const SizedBox(height: 12),
            _buildSolicitudesDashboard(),
            const SizedBox(height: 28),
            Text('TOTALES POR PRODUCTO GESTIONADO', style: DesignTokens.labelStyle().copyWith(letterSpacing: 1.1, fontSize: 11)),
            const SizedBox(height: 12),
            _buildProductTotalsCard(),
            const SizedBox(height: 28),
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
    );
  }

  Widget _buildHighEndDesktopLayout() {
    final pendCount = _viajesCount['pendientes'] ?? 0;
    final cursCount = _viajesCount['enCurso'] ?? 0;
    final termCount = _viajesCount['terminados'] ?? 0;

    return Column(
      children: [
        // FIXED HEADER + KPIs
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
          child: Column(
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: DesignTokens.primary),
                        onPressed: () => context.go('/home'),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('GEOLOGÍSTICA', style: TextStyle(fontFamily: 'Work Sans', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38, letterSpacing: 1)),
                              const Icon(Icons.chevron_right_rounded, size: 14, color: Colors.black38),
                              Text('DASHBOARD', style: TextStyle(fontFamily: 'Work Sans', fontSize: 10, fontWeight: FontWeight.bold, color: DesignTokens.primary.withOpacity(0.6), letterSpacing: 1)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text('Dashboard de Gestión', style: TextStyle(fontFamily: 'Manrope', fontSize: 32, fontWeight: FontWeight.w800, color: DesignTokens.primary, letterSpacing: -1)),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: DesignTokens.primary.withOpacity(0.08))),
                        child: IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.black54),
                          onPressed: _fetchStats,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: DesignTokens.primary.withOpacity(0.08))),
                        child: IconButton(
                          icon: const Icon(Icons.logout_rounded, size: 20, color: Colors.black54),
                          onPressed: () async {
                            await Supabase.instance.client.auth.signOut();
                            if (context.mounted) context.go('/');
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Top Row: High Impact KPIs
                            Row(
                children: [
                  Expanded(
                    child: GeoBentoCard(
                      title: 'CARGA EN VIAJE',
                      value: '${_totalKg.toStringAsFixed(0)} KG',
                      trend: 'En vivo',
                      iconWidget: const Icon(Icons.balance_rounded, color: DesignTokens.secondary, size: 24),
                      accentColor: DesignTokens.secondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GeoBentoCard(
                      title: 'VIAJES ACTIVOS',
                      value: '$cursCount',
                      trend: '$pendCount en espera',
                      iconWidget: const Icon(Icons.local_shipping_rounded, color: Colors.green, size: 24),
                      accentColor: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GeoBentoCard(
                      title: 'STOCK TAMBORES',
                      value: '$_tamboresStock',
                      trend: 'Unidades en inventario',
                      iconWidget: const Icon(Icons.inventory_2_rounded, color: DesignTokens.primary, size: 24),
                      accentColor: DesignTokens.primary,
                    ),
                  ),
                ],
              ),
            ]
          )
        ),
        
        const Divider(height: 1, color: Colors.black12),
        
        // SCROLLABLE CONTENT
        Expanded(
          child: RefreshIndicator(
            color: DesignTokens.secondary,
            onRefresh: _fetchStats,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('MATRIZ DE OPERACIONES', style: TextStyle(fontFamily: 'Work Sans', fontSize: 14, fontWeight: FontWeight.w800, color: DesignTokens.primary.withOpacity(0.5), letterSpacing: 2)),
                      Row(
                        children: [
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: DesignTokens.primary.withOpacity(0.08))), child: const Icon(Icons.filter_list_rounded, size: 16, color: Colors.black54)),
                          const SizedBox(width: 8),
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: DesignTokens.primary.withOpacity(0.08))), child: const Icon(Icons.download_rounded, size: 16, color: Colors.black54)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildMatrixRow(
                    'Recolecciones', 'MIEL TCM/TRR', Icons.download_rounded, Colors.blue.shade700, Colors.blue.shade700.withOpacity(0.1),
                    [
                      _solicitudesCount['recoleccionesByState']?['Pendiente'] ?? 0,
                      _solicitudesCount['recoleccionesByState']?['Asignada'] ?? 0,
                      _solicitudesCount['recoleccionesByState']?['En Curso'] ?? 0,
                      _solicitudesCount['recoleccionesByState']?['Terminada'] ?? 0,
                    ],
                    () {
                      context.go('/recolecciones');
                      _fetchStats();
                    }
                  ),
                  _buildMatrixRow(
                    'Distribuciones', 'INSUMOS/AZÚCAR', Icons.upload_rounded, Colors.green.shade600, Colors.green.shade600.withOpacity(0.1),
                    [
                      _solicitudesCount['distribucionesByState']?['Pendiente'] ?? 0,
                      _solicitudesCount['distribucionesByState']?['Asignada'] ?? 0,
                      _solicitudesCount['distribucionesByState']?['En Curso'] ?? 0,
                      _solicitudesCount['distribucionesByState']?['Terminada'] ?? 0,
                    ],
                    () {
                      context.go('/distribuciones');
                      _fetchStats();
                    }
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // 50/50 SPLIT
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LEFT COLUMN: Inventario
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('INVENTARIO DE PRODUCTOS', style: TextStyle(fontFamily: 'Work Sans', fontSize: 14, fontWeight: FontWeight.w800, color: DesignTokens.primary.withOpacity(0.5), letterSpacing: 2)),
                                const SizedBox(width: 16),
                                Expanded(child: Container(height: 1, color: DesignTokens.primary.withOpacity(0.08))),
                              ],
                            ),
                            const SizedBox(height: 24),
                            if (_productTotals.isEmpty)
                              const Center(child: Text('No hay productos gestionados aún', style: TextStyle(color: Colors.black38)))
                            else
                              ..._productTotals.map((item) {
                                final String prod = item['producto']?.toString() ?? 'DESCONOCIDO';
                                final double qty = (item['cantidad'] as num?)?.toDouble() ?? 0.0;
                                final String unit = item['unidad']?.toString() ?? 'uni';
                                
                                IconData pIcon = Icons.inventory_2_rounded;
                                Color pColor = DesignTokens.primary;
                                bool isPrimary = false;

                                if (prod.contains('TCM')) {
                                  pIcon = Icons.hive_rounded;
                                  pColor = const Color(0xFFB45309);
                                  isPrimary = true;
                                } else if (prod.contains('TRR')) {
                                  pIcon = Icons.hive_outlined;
                                  pColor = const Color(0xFFD97706);
                                } else if (prod.contains('TAMBOR') || prod.contains('TAM')) {
                                  pIcon = Icons.adjust_rounded;
                                  pColor = const Color(0xFF0F766E);
                                } else if (prod.contains('AZUCAR') || prod.contains('AZ')) {
                                  pIcon = Icons.grain_rounded;
                                  pColor = const Color(0xFF475569);
                                }
                                
                                double percent = qty / 1000.0;
                                if (percent > 1.0) percent = 1.0;
                                if (percent < 0.05 && qty > 0) percent = 0.05;

                                return _buildProductBar(prod, 'INVENTARIO REGISTRADO', pIcon, pColor, percent, qty.toStringAsFixed(qty % 1 == 0 ? 0 : 1), isPrimary);
                              }).toList(),
                          ]
                        )
                      ),
                      const SizedBox(width: 40),
                      
                      // RIGHT COLUMN: Viajes Activos
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('DETALLE DE VIAJES ACTIVOS', style: TextStyle(fontFamily: 'Work Sans', fontSize: 14, fontWeight: FontWeight.w800, color: DesignTokens.primary.withOpacity(0.5), letterSpacing: 2)),
                                const SizedBox(width: 16),
                                Expanded(child: Container(height: 1, color: DesignTokens.primary.withOpacity(0.08))),
                              ],
                            ),
                            const SizedBox(height: 24),
                            if (_viajesActivos.isEmpty)
                              _buildEmptyState()
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _viajesActivos.length,
                                itemBuilder: (context, index) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildViajeCard(_viajesActivos[index]),
                                ),
                              ),
                          ]
                        )
                      )
                    ]
                  )
                ]
              )
            )
          )
        )
      ]
    );
  }

  

  

  

  Widget _buildMatrixRow(String title, String subtitle, IconData icon, Color iconColor, Color iconBg, List<int> stats, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _GlassCard(
        accentColor: iconColor,
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: DesignTokens.primary.withOpacity(0.02),
                  border: Border(right: BorderSide(color: DesignTokens.primary.withOpacity(0.05))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(title, style: const TextStyle(fontFamily: 'Manrope', fontSize: 14, fontWeight: FontWeight.w800, color: DesignTokens.primary)),
                          Text(subtitle, style: const TextStyle(fontFamily: 'Work Sans', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38, letterSpacing: 1)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildMatrixCell('PENDIENTES', stats[0].toString(), DesignTokens.primary),
            _buildMatrixCell('ASIGNADAS', stats[1].toString(), DesignTokens.primary),
            _buildMatrixCell('EN CURSO', stats[2].toString(), DesignTokens.primary),
            _buildMatrixCell('TERMINADAS', stats[3].toString(), DesignTokens.primary),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${stats.fold(0, (a, b) => a + b)} Operaciones', style: const TextStyle(fontFamily: 'Manrope', fontSize: 10, fontWeight: FontWeight.w800, color: DesignTokens.primary)),
                        const Text('Actualizado ahora', style: TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.w500, color: Colors.black45)),
                      ],
                    ),
                    Container(
                      width: 32, height: 32,
                      decoration: const BoxDecoration(color: DesignTokens.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.chevron_right_rounded, color: DesignTokens.secondary, size: 16),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildMatrixCell(String label, String value, Color valueColor, {bool isHighlight = false}) {
    return Expanded(
      flex: 1,
      child: Container(
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: DesignTokens.primary.withOpacity(0.05))),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, style: TextStyle(fontFamily: 'Manrope', fontSize: 24, fontWeight: FontWeight.w800, color: valueColor, fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontFamily: 'Work Sans', fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildProductBar(String title, String subtitle, IconData icon, Color iconColor, double percent, String units, bool isPrimary) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.primary.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: isPrimary ? DesignTokens.secondary.withOpacity(0.1) : DesignTokens.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontFamily: 'Manrope', fontSize: 16, fontWeight: FontWeight.w800, color: DesignTokens.primary)),
                Text(subtitle, style: const TextStyle(fontFamily: 'Work Sans', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38, letterSpacing: 1)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(color: DesignTokens.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(3)),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: percent,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isPrimary ? DesignTokens.secondary : DesignTokens.primary.withOpacity(0.4), 
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: isPrimary ? [BoxShadow(color: DesignTokens.secondary.withOpacity(0.4), blurRadius: 10)] : null,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 48),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(units, style: const TextStyle(fontFamily: 'Manrope', fontSize: 24, fontWeight: FontWeight.w800, color: DesignTokens.primary, fontFeatures: [FontFeature.tabularFigures()])),
                    const SizedBox(width: 8),
                    const Text('UNI', style: TextStyle(fontFamily: 'Work Sans', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSummaryGrid(bool isWeb) {
    if (isWeb) {
      return Row(
        children: [
          Expanded(child: _statBox('CARGA TOTAL EN VIAJE', '${_totalKg.toStringAsFixed(0)} Kg', Icons.scale_rounded, DesignTokens.primary, const Color(0xFFE8F5E9))),
          const SizedBox(width: 16),
          Expanded(child: _statBox('VIAJES ACTIVOS', _viajesActivos.length.toString(), Icons.local_shipping_rounded, const Color(0xFFC68E17), const Color(0xFFFDF7E8))),
          const SizedBox(width: 16),
          Expanded(child: _statBox('STOCK TAMBORES', _tamboresStock.toString(), Icons.inventory_2_rounded, DesignTokens.secondary, const Color(0xFFFFFDE7))),
        ],
      );
    }
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.5,
      children: [
        _statBox('CARGA TOTAL EN VIAJE', '${_totalKg.toStringAsFixed(0)} Kg', Icons.scale_rounded, DesignTokens.primary, const Color(0xFFE8F5E9)),
        _statBox('STOCK TAMBORES', _tamboresStock.toString(), Icons.inventory_2_rounded, DesignTokens.secondary, const Color(0xFFFFFDE7)),
      ],
    );
  }

  Widget _statBox(String label, String value, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 30, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 20, color: color),
              ),
              if (color == const Color(0xFFC68E17))
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                   decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                   child: Text('LIVE', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
                 )
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, fontFamily: 'Manrope', color: DesignTokens.primary)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black45, letterSpacing: 0.5, fontFamily: 'Work Sans')),
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
        Expanded(child: _stateCountCard('PENDIENTES', pCount)),
        const SizedBox(width: 10),
        Expanded(child: _stateCountCard('EN CURSO', cCount)),
        const SizedBox(width: 10),
        Expanded(child: _stateCountCard('TERMINADOS', tCount)),
      ],
    );
  }

  Widget _stateCountCard(String title, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.primary.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: DesignTokens.primary, fontFamily: 'Manrope'),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.black54, letterSpacing: 0.5, fontFamily: 'Work Sans'),
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
          onTap: () { context.go('/recolecciones'); },
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
          onTap: () { context.go('/distribuciones'); },
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
                    _subStateItem('Pendientes', states['Pendiente'] ?? 0),
                    _subStateItem('Asignadas', states['Asignada'] ?? 0),
                    _subStateItem('En Curso', states['En Curso'] ?? 0),
                    _subStateItem('Terminadas', states['Terminada'] ?? 0),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _subStateItem(String label, int value) {
    return Column(
      children: [
        Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: DesignTokens.primary, fontFamily: 'Manrope')),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.black54, fontFamily: 'Work Sans')),
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
        onTap: () => context.go('/viajedetalle?viajeId=$id'),
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


class _GerentePulsingDot extends StatefulWidget {
  const _GerentePulsingDot();
  @override
  State<_GerentePulsingDot> createState() => _GerentePulsingDotState();
}

class _GerentePulsingDotState extends State<_GerentePulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: DesignTokens.primary, shape: BoxShape.circle)),
    );
  }
}

class _GerenteSparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _GerenteSparklinePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final minVal = data.reduce((a, b) => a < b ? a : b);
    final range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minVal) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _GlassCard extends StatefulWidget {
  final Widget child;
  final Color accentColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  const _GlassCard({
    required this.child,
    this.accentColor = DesignTokens.secondary,
    this.onTap,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  State<_GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<_GlassCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuint,
          transform: Matrix4.translationValues(0, _isHovered ? -8 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: widget.accentColor.withOpacity(_isHovered ? 0.4 : 0.08),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withOpacity(_isHovered ? 0.15 : 0.05),
                blurRadius: _isHovered ? 40 : 20,
                offset: Offset(0, _isHovered ? 15 : 8),
              )
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    color: const Color(0xFFFFFFFF).withOpacity(0.65),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            widget.accentColor.withOpacity(0.08),
                            widget.accentColor.withOpacity(0.02),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: widget.padding ?? EdgeInsets.zero,
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatrixHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _MatrixHeaderDelegate({required this.child});

  @override
  double get minExtent => 340.0;
  @override
  double get maxExtent => 340.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          color: const Color(0xFFF8FAFC).withOpacity(0.85),
          padding: const EdgeInsets.only(top: 16, bottom: 16, left: 32, right: 32),
          child: child,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}
