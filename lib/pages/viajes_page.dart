import '../flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/supabase_service.dart';
import '../backend/design_tokens.dart';
import '../backend/app_states.dart';
import 'package:intl/intl.dart';

class ViajesPageWidget extends StatefulWidget {
  final String? initialEstado;
  const ViajesPageWidget({super.key, this.initialEstado});

  static String routeName = 'Viajes';
  static String routePath = '/viajes';

  @override
  State<ViajesPageWidget> createState() => _ViajesPageWidgetState();
}

class _ViajesPageWidgetState extends State<ViajesPageWidget>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _viajes = [];
  bool _loading = true;
  String? _error;
  String? _userRole;
  bool _isAdmin = false; // hassel00@gmail.com tiene acceso total

  final List<String> _tabs = ['PENDIENTE', 'EN CURSO', 'TERMINADOS'];
  final List<String> _statusKeys = [AppStates.pendiente, AppStates.enCurso, AppStates.terminado];
  int _selectedStatusIndex = 0;
  String get _selectedStatus => _statusKeys[_selectedStatusIndex];

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
    _fetchViajes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchViajes() async {
    setState(() { _loading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_puesto');
      final userEmail = prefs.getString('user_email') ?? Supabase.instance.client.auth.currentUser?.email ?? '';
      if (mounted) setState(() {
        _userRole = userRole;
        _isAdmin = (userEmail == 'hassel00@gmail.com');
      });
      final userId = prefs.getString('user_id');
      print('ViajesPage: Iniciando fetch para role: $userRole, userId: $userId, admin: $_isAdmin');

      final data = await SupabaseService().getViajes(userId: userId, role: userRole);
      
      if (mounted) setState(() { 
        _viajes = data;
        _loading = false; 
      });
    } catch (e) {
      print('ViajesPage: Error en _fetchViajes: $e');
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Map<String, dynamic>> _filtered(String status) {
    return _viajes.where((v) {
      final vEstado = AppStates.normalize(v['estado']);
      final filterEstado = AppStates.normalize(status);
      return vEstado == filterEstado;
    }).toList();
  }

  Future<void> _confirmDelete(String id, String codigo) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Viaje'),
        content: Text('¿Está seguro de eliminar el viaje $codigo? Las solicitudes incluidas volverán a estar pendientes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      try {
        await SupabaseService().deleteViaje(id);
        _fetchViajes();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
          setState(() => _loading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          // WEB LAYOUT
          return Scaffold(
            backgroundColor: DesignTokens.surfaceLow,
            body: Row(
              children: [
                // LEFT PANEL
                Container(
                  width: 280,
                  color: const Color(0xFF08201A),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      const Text(
                        'GeoLogística',
                        style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 32, color: Colors.white),
                      ),
                      const Text(
                        'CONTROL DE VIAJES',
                        style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 10, color: Color(0xFFFDBE49), letterSpacing: 2),
                      ),
                      const SizedBox(height: 32),
                      const Divider(color: Colors.white12),
                      const SizedBox(height: 16),
                      // Status Filters
                      ...List.generate(_tabs.length, (i) {
                        final isActive = _selectedStatusIndex == i;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedStatusIndex = i),
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFFFDBE49) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                _tabs[i],
                                style: TextStyle(
                                  fontFamily: 'Work Sans',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: isActive ? const Color(0xFF08201A) : Colors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      const Spacer(),
                      const Divider(color: Colors.white12),
                      const SizedBox(height: 16),
                      IconButton(
                        onPressed: _fetchViajes,
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white54, size: 28),
                      ),
                      if (_isAdmin || (_userRole != null && _userRole != 'Chofer')) ...[
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await context.push('/planificarViaje');
                              _fetchViajes();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFDBE49),
                              foregroundColor: const Color(0xFF08201A),
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('NUEVO VIAJE', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, letterSpacing: 1)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                // RIGHT PANEL
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(bottom: BorderSide(color: DesignTokens.primary.withOpacity(0.05))),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => context.go('/home'),
                              child: const Icon(Icons.home_rounded, color: DesignTokens.primary, size: 20),
                            ),
                            const SizedBox(width: 8),
                            const Text('/', style: TextStyle(color: Colors.black26)),
                            const SizedBox(width: 8),
                            const Text(
                              'CONTROL DE VIAJES',
                              style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 11, color: DesignTokens.primary, letterSpacing: 1.5),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _loading
                            ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
                            : _error != null
                                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                                : _buildTripList(_selectedStatus, theme),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // MOBILE LAYOUT
        return Scaffold(
          backgroundColor: DesignTokens.surfaceLow,
          appBar: AppBar(
            backgroundColor: DesignTokens.surface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: DesignTokens.primary),
              onPressed: () => context.go('/home'),
            ),
            title: Text(
              _userRole == 'Chofer' ? 'Mis Viajes' : 'Control de Viajes',
              style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 17, color: DesignTokens.primary),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: DesignTokens.primary),
                onPressed: _fetchViajes,
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: DesignTokens.secondary,
              indicatorWeight: 3,
              labelColor: DesignTokens.primary,
              unselectedLabelColor: DesignTokens.primary.withOpacity(0.4),
              labelStyle: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.8),
              unselectedLabelStyle: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w600, fontSize: 10, letterSpacing: 0.5),
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
            ),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                  : TabBarView(
                      controller: _tabController,
                      children: _statusKeys.map((s) => _buildTripList(s, theme)).toList(),
                    ),
          floatingActionButton: (_isAdmin || (_userRole != null && _userRole != 'Chofer'))
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    await context.push('/planificarViaje');
                    _fetchViajes();
                  },
                  backgroundColor: DesignTokens.secondary,
                  icon: const Icon(Icons.add_rounded, color: DesignTokens.primary),
                  label: const Text(
                    'NUEVO VIAJE',
                    style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, color: DesignTokens.primary),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildTripList(String status, FlutterFlowTheme theme) {
    final trips = _filtered(status);

    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping_outlined, size: 48, color: Colors.black12),
            const SizedBox(height: 16),
            Text('No hay viajes en esta sección', style: TextStyle(color: Colors.black45, fontFamily: 'Inter')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchViajes,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: trips.length,
        itemBuilder: (context, index) => _buildTripCard(trips[index], theme),
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> v, FlutterFlowTheme theme) {
    try {
      final estado = v['estado'] ?? 'Planificado';
      final id = v['id']?.toString() ?? '';
      final codigo = v['viaje_codigo']?.toString() ?? (id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase());
      final vehiculo = v['vehiculo_codigo']?.toString() ?? 'Sin vehículo';
      final fechaPlanRaw = v['fecha_planificada'];
      final fechaIniRaw = v['fecha_inicio'];
      final fechaTermRaw = v['fecha_terminado'];
      final fechaRaw = v['fecha'] ?? v['created_at'];
      
      DateTime? fechaToShow;
      String labelFecha = 'Fecha';

      if (estado == 'Planificado' || estado == 'Pendiente') {
        fechaToShow = DateTime.tryParse(fechaPlanRaw?.toString() ?? fechaRaw?.toString() ?? '');
        labelFecha = 'Fecha Planificada';
      } else if (estado == 'En Proceso' || estado == 'En Curso' || estado == 'Cargado') {
        fechaToShow = DateTime.tryParse(fechaIniRaw?.toString() ?? fechaRaw?.toString() ?? '');
        labelFecha = 'Iniciado el';
      } else {
        fechaToShow = DateTime.tryParse(fechaTermRaw?.toString() ?? fechaRaw?.toString() ?? '');
        labelFecha = 'Terminado el';
      }

      final fechaStr = fechaToShow != null ? DateFormat('dd/MM/yyyy HH:mm').format(fechaToShow) : 'S/D';
      
      final dynamic rawChofer = v['chofer'];
      Map<dynamic, dynamic> chofer = {};
      try {
        if (rawChofer is List && rawChofer.isNotEmpty) {
          final first = rawChofer.first;
          if (first is Map) {
            chofer = first;
          }
        } else if (rawChofer is Map) {
          chofer = rawChofer;
        }
      } catch (e) {
        print('ViajesPage: Error parsing chofer: $e');
      }
      
      final choferNombre = '${chofer['nombre'] ?? 'Sin'} ${chofer['apellido'] ?? 'Asignar'}';

      Color chipColor;
      Color chipBg;
      Color leftBorder;
      if (estado == 'En Proceso' || estado == 'En Curso' || estado == 'Cargado') {
        chipColor = const Color(0xFF7D5700);
        chipBg = const Color(0xFFFDEFCC);
        leftBorder = const Color(0xFFFDBE49);
      } else if (estado == 'Terminado' || estado == 'Finalizado') {
        chipColor = const Color(0xFF1A6B43);
        chipBg = const Color(0xFFD4F0E1);
        leftBorder = const Color(0xFF249689);
      } else {
        chipColor = const Color(0xFF1565C0);
        chipBg = const Color(0xFFD6E4FF);
        leftBorder = const Color(0xFF1565C0);
      }
      
      return LayoutBuilder(
        builder: (context, constraints) {
          final isWeb = MediaQuery.of(context).size.width >= 900;
          if (isWeb) {
            return GestureDetector(
              onTap: () => context.push('/viajedetalle?viajeId=$id'),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.05))),
                ),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: leftBorder, shape: BoxShape.circle)),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 120,
                      child: Text(codigo, style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF08201A))),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Vehículo: $vehiculo', style: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w600, fontSize: 11, color: Colors.black54)),
                          const SizedBox(height: 2),
                          Text('Chofer: $choferNombre', style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.black87)),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('$labelFecha: $fechaStr', style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.black54)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(20)),
                      child: Text(estado.toUpperCase(), style: TextStyle(color: chipColor, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Work Sans')),
                    ),
                    const SizedBox(width: 16),
                    if ((_isAdmin || _userRole == 'Gerente' || _userRole == 'Compras' || _userRole == 'CEO') &&
                        (_isAdmin || estado == 'Planificado' || estado == 'Pendiente' || estado == 'En Proceso' || estado == 'En Curso' || estado == 'Cargado')) ...[
                      IconButton(
                        icon: const Icon(Icons.edit_note_rounded, color: DesignTokens.primary, size: 20),
                        onPressed: () async {
                          await context.push('/planificarViaje?editId=$id');
                          _fetchViajes();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        onPressed: () => _confirmDelete(id, codigo),
                      ),
                    ],
                    const SizedBox(width: 16),
                    const Icon(Icons.chevron_right_rounded, color: Colors.black26),
                  ],
                ),
              ),
            );
          }

          // Mobile layout
          return GestureDetector(
            onTap: () => context.push('/viajedetalle?viajeId=$id'),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: leftBorder,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
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
                                      Text(vehiculo, style: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w700, fontSize: 9, color: Colors.black45, letterSpacing: 0.8)),
                                      const SizedBox(height: 2),
                                      Text(codigo, style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF08201A)), overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(20)),
                                      child: Text(estado.toUpperCase(), style: TextStyle(color: chipColor, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Work Sans')),
                                    ),
                                    if ((_isAdmin || _userRole == 'Gerente' || _userRole == 'Compras' || _userRole == 'CEO') &&
                                        (_isAdmin || estado == 'Planificado' || estado == 'Pendiente' || estado == 'En Proceso' || estado == 'En Curso' || estado == 'Cargado')) ...[
                                      const SizedBox(width: 6),
                                      IconButton(
                                        icon: const Icon(Icons.edit_note_rounded, color: DesignTokens.primary, size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () async {
                                          await context.push('/planificarViaje?editId=$id');
                                          _fetchViajes();
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _confirmDelete(id, codigo),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.black45),
                                const SizedBox(width: 6),
                                Text('$labelFecha: $fechaStr', style: const TextStyle(color: Colors.black45, fontSize: 12, fontFamily: 'Inter')),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.person_rounded, size: 14, color: Colors.black45),
                                const SizedBox(width: 6),
                                Expanded(child: Text('Chofer: $choferNombre', style: const TextStyle(color: Colors.black45, fontSize: 12, fontFamily: 'Inter'), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                            const Divider(height: 24),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('VER DETALLE', style: TextStyle(color: Color(0xFF08201A), fontWeight: FontWeight.w800, fontSize: 11, fontFamily: 'Work Sans', letterSpacing: 0.5)),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF08201A)),
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
          );
        },
      );
    } catch (e, stack) {
      print('ViajesPage: Error in _buildTripCard: $e\n$stack');
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Error al procesar viaje: ${v['viaje_codigo'] ?? 'S/C'}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900)),
            const SizedBox(height: 8),
            Text(e.toString(), style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
          ],
        ),
      );
    }
  }
}
