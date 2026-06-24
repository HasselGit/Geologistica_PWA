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

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWeb = constraints.maxWidth >= 700;
          
          if (isWeb) {
            return Row(
              children: [
                // LEFT sidebar (280px, dark green)
                Container(
                  width: 280,
                  color: const Color(0xFF08201A),
                  child: SafeArea(
                    child: Column(
                      children: [
                        const SizedBox(height: 28),
                        // User avatar
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
                        // Vertical tab filters
                        _sidebarTab(0, 'PENDIENTES', Icons.schedule_rounded, theme),
                        _sidebarTab(1, 'EN CURSO', Icons.local_shipping_rounded, theme),
                        _sidebarTab(2, 'TERMINADOS', Icons.check_circle_rounded, theme),
                        const Spacer(),
                        const Divider(color: Colors.white12),
                        // Quick actions
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
                  ),
                ),
                // RIGHT content
                Expanded(
                  child: Container(
                    color: const Color(0xFFF5F3F3),
                    child: Column(
                      children: [
                        // Top bar
                        Container(
                          padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFBF9F8),
                            border: Border(bottom: BorderSide(color: Color(0x0D08201A))),
                          ),
                          child: Row(
                            children: [
                              const Text('Mis Viajes', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 22, color: Color(0xFF08201A))),
                              const Spacer(),
                              GestureDetector(
                                onTap: _fetchData,
                                child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0x0A08201A), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.refresh_rounded, color: Color(0xFF08201A), size: 18)),
                              ),
                            ],
                          ),
                        ),
                        // Trip list
                        Expanded(
                          child: _loading
                              ? Center(child: CircularProgressIndicator(color: theme.secondary))
                              : _error != null
                                  ? _buildError(theme)
                                  : _filtered.isEmpty
                                      ? _buildEmpty(theme)
                                      : RefreshIndicator(
                                          color: theme.secondary,
                                          onRefresh: _fetchData,
                                          child: ListView.builder(
                                            padding: const EdgeInsets.all(28),
                                            itemCount: _filtered.length,
                                            itemBuilder: (ctx, i) => _buildTripCard(_filtered[i], theme),
                                          ),
                                        ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          
          return Column(
            children: [
              // existing mobile header
              Container(
                color: const Color(0xFFFBF9F8),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Row(
                          children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFDBE49), width: 2), color: const Color(0x1408201A)),
                              child: Center(child: Text(iniciales, style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF08201A)))),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Bienvenido', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: const Color(0xFF424846).withOpacity(0.6))),
                                Text(nombre, style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF08201A))),
                              ]),
                            ),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: const Color(0x26FDBE49), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0x66FDBE49))), child: const Text('CHOFER', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 9, color: Color(0xFF7D5700), letterSpacing: 1))),
                            const SizedBox(width: 8),
                            IconButton(icon: const Icon(Icons.logout_rounded, color: Color(0xFF08201A), size: 22), onPressed: () async { await Supabase.instance.client.auth.signOut(); if (context.mounted) context.go('/'); }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Mis Viajes', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 24, color: Color(0xFF08201A))), GestureDetector(onTap: _fetchData, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0x0A08201A), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.refresh_rounded, color: Color(0xFF08201A), size: 18)))])),
                      const SizedBox(height: 16),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [Expanded(child: _quickAction(Icons.inventory_2_rounded, 'CARGAS', () => context.push('/depositoHome'))), const SizedBox(width: 12), Expanded(child: _quickAction(Icons.account_balance_wallet_rounded, 'GASTOS', () => context.push('/gastos'))), const SizedBox(width: 12), Expanded(child: _quickAction(Icons.local_shipping_rounded, 'VEHÍCULOS', () => context.push('/vehiculos')))])),
                      const SizedBox(height: 16),
                      Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [_tabPill(theme, 0, 'PENDIENTES'), const SizedBox(width: 8), _tabPill(theme, 1, 'EN CURSO'), const SizedBox(width: 8), _tabPill(theme, 2, 'TERMINADOS')]))),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  color: const Color(0xFFF5F3F3),
                  child: _loading
                      ? Center(child: CircularProgressIndicator(color: theme.secondary))
                      : _error != null
                          ? _buildError(theme)
                          : _filtered.isEmpty
                              ? _buildEmpty(theme)
                              : RefreshIndicator(
                                  color: theme.secondary,
                                  onRefresh: _fetchData,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                                    itemCount: _filtered.length,
                                    itemBuilder: (ctx, i) => _buildTripCard(_filtered[i], theme),
                                  ),
                                ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width >= 700 ? null : _buildBottomNav(theme),
    );
  }

  Widget _sidebarTab(int idx, String label, IconData icon, FlutterFlowTheme theme) {
    final active = _selectedTab == idx;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = idx),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFDBE49).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? const Color(0xFFFDBE49).withOpacity(0.3) : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: active ? const Color(0xFFFDBE49) : Colors.white54),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 11, color: active ? const Color(0xFFFDBE49) : Colors.white54, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _sidebarAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.white38),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w600, fontSize: 11, color: Colors.white38, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _tabPill(FlutterFlowTheme theme, int idx, String label) {
    final active = _selectedTab == idx;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFDBE49) : const Color(0xFF08201A).withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? const Color(0xFFFDBE49) : const Color(0xFF08201A).withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Work Sans',
            fontWeight: FontWeight.w800,
            fontSize: 10,
            color: active ? const Color(0xFF08201A) : const Color(0xFF08201A).withOpacity(0.5),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF08201A).withOpacity(0.08)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF08201A), size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Work Sans',
                fontWeight: FontWeight.w800,
                fontSize: 8,
                color: Color(0xFF08201A),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> v, FlutterFlowTheme theme) {
    final estado = v['estado'] ?? 'Planificado';
    final id = v['id']?.toString() ?? '';
    // Use human-readable viaje_codigo if available
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF08201A).withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF08201A).withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Colored left border
              Container(
                width: 4,
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
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vehiculo,
                                style: TextStyle(
                                  fontFamily: 'Work Sans',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 9,
                                  color: const Color(0xFF08201A).withOpacity(0.4),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                displayId,
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: Color(0xFF08201A),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: chipBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              estado.toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'Work Sans',
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                color: chipColor,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
                      Divider(height: 1, color: const Color(0xFF08201A).withOpacity(0.06)),
                      const SizedBox(height: 14),

                      // Description
                      if (v['descripcion'] != null && v['descripcion'].toString().isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 14, color: theme.secondaryText.withOpacity(0.5)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                v['descripcion'].toString(),
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF424846)),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Icon(Icons.local_shipping_outlined, size: 14, color: theme.secondaryText.withOpacity(0.5)),
                            const SizedBox(width: 8),
                            Text(
                              'Toca para ver el detalle de la ruta',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: const Color(0xFF424846).withOpacity(0.6)),
                            ),
                          ],
                        ),

                      const SizedBox(height: 14),

                      // Footer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (fecha != null)
                            Text(
                              fecha,
                              style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: theme.secondaryText.withOpacity(0.5)),
                            )
                          else
                            const SizedBox(),
                          Row(
                            children: [
                              Text(
                                'VER RUTA',
                                style: TextStyle(
                                  fontFamily: 'Work Sans',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  color: theme.secondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right_rounded, size: 16, color: theme.secondary),
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
              color: theme.primary.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.local_shipping_rounded, size: 36, color: theme.primary.withOpacity(0.3)),
          ),
          const SizedBox(height: 20),
          Text(
            'Sin ${labels[_selectedTab]}',
            style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF08201A)),
          ),
          const SizedBox(height: 8),
          Text(
            'Los viajes aparecerán aquí cuando sean asignados.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: const Color(0xFF424846).withOpacity(0.6)),
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
          Icon(Icons.cloud_off_rounded, size: 48, color: theme.error),
          const SizedBox(height: 16),
          Text('Error de conexión', style: theme.titleSmall),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _fetchData,
            style: ElevatedButton.styleFrom(backgroundColor: theme.primary, foregroundColor: Colors.white),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(FlutterFlowTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: const Color(0xFF08201A).withOpacity(0.07))),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(theme, Icons.home_rounded, 'HOME', false, () => context.go('/home')),
              _navItem(theme, Icons.alt_route_rounded, 'MIS VIAJES', true, () {}),
              _navItem(theme, Icons.group_rounded, 'APICULTORES', false, () {}),
              _navItem(theme, Icons.more_horiz_rounded, 'MÁS', false, () {}),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(FlutterFlowTheme theme, IconData icon, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: active ? theme.tertiary : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: active ? theme.secondary : theme.secondaryText.withOpacity(0.5)),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Work Sans',
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
              fontSize: 9,
              color: active ? theme.tertiary : theme.secondaryText.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
