import '../flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/supabase_service.dart';
import '../backend/app_states.dart';
import 'package:go_router/go_router.dart';

class ChoferHomeWidget extends StatefulWidget {
  const ChoferHomeWidget({super.key});

  static String routeName = 'ChoferHome';
  static String routePath = '/choferHome';

  @override
  State<ChoferHomeWidget> createState() => _ChoferHomeWidgetState();
}

class _ChoferHomeWidgetState extends State<ChoferHomeWidget> {
  List<Map<String, dynamic>> _viajes = [];
  bool _loading = true;
  String? _error;
  String? _choferNombre;
  int _selectedTab = 0; // 0=Planificados, 1=En Proceso, 2=Terminados

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      _choferNombre = prefs.getString('user_nombre');
      
      print('ChoferHome: Iniciando fetch para userId: $userId');

      if (userId != null) {
        final data = await SupabaseService().getViajes(userId: userId, role: 'Chofer');
        if (mounted) {
          setState(() {
            _viajes = data;
            _loading = false;
          });
        }
      } else {
        print('ChoferHome: No hay userId en SharedPreferences');
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Sesión no encontrada. Por favor reingrese.';
          });
        }
      }
    } catch (e) {
      print('ChoferHome: Error general en _fetchData: $e');
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_selectedTab == 0) return _viajes.where((v) => v['estado'] == AppStates.pendiente).toList();
    if (_selectedTab == 1) return _viajes.where((v) => v['estado'] == AppStates.enCurso).toList();
    if (_selectedTab == 2) return _viajes.where((v) => v['estado'] == AppStates.terminado).toList();
    return _viajes;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final nombre = _choferNombre ?? 'Chofer';
    final iniciales = nombre.isNotEmpty
        ? nombre.split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join()
        : 'CH';

    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: !isDesktop ? _buildMobileAppBar() : null,
      drawer: !isDesktop ? _buildDrawer(iniciales, nombre) : null,
      body: RepaintBoundary(
        child: isDesktop 
            ? _buildDesktopLayout(iniciales, nombre, theme)
            : _buildMobileLayout(theme),
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFFBF9F8),
      elevation: 0,
      iconTheme: const IconThemeData(color: Color(0xFF08201A)),
      title: const Text(
        'Mis Viajes',
        style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 20, color: Color(0xFF08201A)),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF08201A)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ],
    );
  }

  Widget _buildDrawer(String iniciales, String nombre) {
    return Drawer(
      backgroundColor: const Color(0xFF08201A),
      child: _sidebarContent(iniciales, nombre),
    );
  }

  Widget _sidebarContent(String iniciales, String nombre) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 28),
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFDBE49), width: 2),
              color: Colors.white.withOpacity(0.1),
            ),
            child: Center(child: Text(iniciales, style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 20, color: Colors.white))),
          ),
          const SizedBox(height: 12),
          Text(nombre, style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFDBE49).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFDBE49).withOpacity(0.4)),
            ),
            child: const Text('CHOFER', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 9, color: Color(0xFFFDBE49), letterSpacing: 1)),
          ),
          const SizedBox(height: 32),
          const Divider(color: Colors.white12),
          const SizedBox(height: 16),
          _sidebarTab(0, 'PENDIENTES', Icons.schedule_rounded),
          _sidebarTab(1, 'EN CURSO', Icons.local_shipping_rounded),
          _sidebarTab(2, 'TERMINADOS', Icons.check_circle_rounded),
          const Spacer(),
          const Divider(color: Colors.white12),
          _sidebarAction(Icons.inventory_2_rounded, 'CARGAS', () => context.push('/depositoHome')),
          _sidebarAction(Icons.account_balance_wallet_rounded, 'GASTOS', () => context.push('/gastos')),
          _sidebarAction(Icons.local_shipping_rounded, 'VEHÍCULOS', () => context.push('/vehiculos')),
          const SizedBox(height: 12),
          _sidebarAction(Icons.logout_rounded, 'SALIR', () async {
            await Supabase.instance.client.auth.signOut();
            if (context.mounted) context.go('/');
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(String iniciales, String nombre, FlutterFlowTheme theme) {
    return Row(
      children: [
        Container(
          width: 280,
          margin: const EdgeInsets.only(left: 16, top: 16, bottom: 16, right: 0),
          decoration: BoxDecoration(
            color: const Color(0xFF08201A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _sidebarContent(iniciales, nombre),
          ),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFBF9F8),
                      border: Border(bottom: BorderSide(color: Color(0x0D08201A))),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF08201A)),
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/home');
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        const Text('Mis Viajes', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 24, color: Color(0xFF08201A))),
                        const Spacer(),
                        GestureDetector(
                          onTap: _fetchData,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFFFF),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 30, offset: const Offset(0, 4)),
                              ]
                            ),
                            child: const Icon(Icons.refresh_rounded, color: Color(0xFF08201A), size: 20)
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _buildMainContent(theme, isMobile: false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(FlutterFlowTheme theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(child: _bentoQuickAction(Icons.inventory_2_rounded, 'CARGAS', () => context.push('/depositoHome'))),
              const SizedBox(width: 12),
              Expanded(child: _bentoQuickAction(Icons.account_balance_wallet_rounded, 'GASTOS', () => context.push('/gastos'))),
              const SizedBox(width: 12),
              Expanded(child: _bentoQuickAction(Icons.local_shipping_rounded, 'VEHÍCULOS', () => context.push('/vehiculos'))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _bentoTabPill(0, 'PENDIENTES'),
                const SizedBox(width: 8),
                _bentoTabPill(1, 'EN CURSO'),
                const SizedBox(width: 8),
                _bentoTabPill(2, 'TERMINADOS'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _buildMainContent(theme, isMobile: true),
        ),
      ],
    );
  }

  Widget _buildMainContent(FlutterFlowTheme theme, {bool isMobile = false}) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: theme.secondary));
    }
    if (_error != null) {
      return _buildError(theme);
    }
    if (_filtered.isEmpty) {
      return _buildEmpty(theme);
    }

    return RefreshIndicator(
      color: theme.secondary,
      onRefresh: _fetchData,
      child: ListView.builder(
        padding: EdgeInsets.all(isMobile ? 20 : 32),
        itemCount: _filtered.length,
        itemBuilder: (ctx, i) => _buildTripCard(_filtered[i], theme),
      ),
    );
  }

  Widget _bentoQuickAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 30, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF08201A), size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w800,
                fontSize: 10,
                color: Color(0xFF08201A),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bentoTabPill(int idx, String label) {
    final active = _selectedTab == idx;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFDBE49) : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(20),
          boxShadow: active ? [] : [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
          ],
          border: Border.all(
            color: active ? const Color(0xFFFDBE49) : const Color(0xFF08201A).withOpacity(0.05),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w800,
            fontSize: 11,
            color: active ? const Color(0xFF08201A) : const Color(0xFF08201A).withOpacity(0.5),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _sidebarTab(int idx, String label, IconData icon) {
    final active = _selectedTab == idx;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedTab = idx);
        if (MediaQuery.of(context).size.width < 900) {
          Navigator.pop(context);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFDBE49).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? const Color(0xFFFDBE49).withOpacity(0.3) : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: active ? const Color(0xFFFDBE49) : Colors.white54),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 12, color: active ? const Color(0xFFFDBE49) : Colors.white54, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _sidebarAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.white38),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white38, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> v, FlutterFlowTheme theme) {
    final estado = v['estado'] ?? 'Planificado';
    final id = v['id']?.toString() ?? '';
    final displayId = v['viaje_codigo']?.toString() ?? (id.length > 6 ? 'V-${id.substring(0, 6).toUpperCase()}' : 'V-$id').toUpperCase();
    final vehiculo = v['vehiculo_codigo']?.toString() ?? 'Sin vehículo';
    final fecha = v['created_at'] != null ? _formatDate(v['created_at'].toString()) : null;

    Color chipColor;
    Color chipBg;
    Color leftBorder;
    if (estado == AppStates.enCurso) {
      chipColor = const Color(0xFF7D5700);
      chipBg = const Color(0xFFFDEFCC);
      leftBorder = const Color(0xFFFDBE49);
    } else if (estado == AppStates.terminado) {
      chipColor = const Color(0xFF1A6B43);
      chipBg = const Color(0xFFD4F0E1);
      leftBorder = const Color(0xFF249689);
    } else {
      chipColor = const Color(0xFF1565C0);
      chipBg = const Color(0xFFD6E4FF);
      leftBorder = const Color(0xFF1565C0);
    }

    return GestureDetector(
      onTap: () => context.push('/viajedetalle?viajeId=$id'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 30,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: leftBorder,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vehiculo,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                  color: const Color(0xFF08201A).withOpacity(0.5),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                displayId,
                                style: const TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: Color(0xFF08201A),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: chipBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              estado.toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                color: chipColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(height: 1, color: const Color(0xFF08201A).withOpacity(0.06)),
                      const SizedBox(height: 16),
                      if (v['descripcion'] != null && v['descripcion'].toString().isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: const Color(0xFF08201A).withOpacity(0.5)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                v['descripcion'].toString(),
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF424846)),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Icon(Icons.local_shipping_outlined, size: 16, color: const Color(0xFF08201A).withOpacity(0.5)),
                            const SizedBox(width: 8),
                            Text(
                              'Toca para ver el detalle de la ruta',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: const Color(0xFF424846).withOpacity(0.6)),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (fecha != null)
                            Text(
                              fecha,
                              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: const Color(0xFF08201A).withOpacity(0.5)),
                            )
                          else
                            const SizedBox(),
                          Row(
                            children: [
                              const Text(
                                'VER RUTA',
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: Color(0xFF249689),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF249689)),
                            ],
                          ),
                        ],
                      ),
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

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  Widget _buildEmpty(FlutterFlowTheme theme) {
    final labels = ['viajes pendientes', 'viajes en curso', 'viajes terminados'];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 30, offset: const Offset(0, 4)),
              ]
            ),
            child: Icon(Icons.local_shipping_rounded, size: 36, color: const Color(0xFF08201A).withOpacity(0.3)),
          ),
          const SizedBox(height: 24),
          Text(
            'Sin ${labels[_selectedTab]}',
            style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF08201A)),
          ),
          const SizedBox(height: 8),
          Text(
            'Los viajes aparecerán aquí cuando sean asignados.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: const Color(0xFF424846).withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildError(FlutterFlowTheme theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 30, offset: const Offset(0, 4)),
              ]
            ),
            child: const Icon(Icons.cloud_off_rounded, size: 36, color: Colors.redAccent),
          ),
          const SizedBox(height: 24),
          const Text('Error de conexión', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF08201A))),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF249689),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Reintentar', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
