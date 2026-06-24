import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive/hive.dart';
import 'dart:async';
import 'dart:ui';
import '../backend/supabase_service.dart';
import '../backend/design_tokens.dart';

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});

  static String routeName = 'Home';
  static String routePath = '/home';

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> with WidgetsBindingObserver {
  Map<String, int> _stats = {'planificados': 0, 'en_curso': 0, 'terminados': 0};
  Map<String, int> _cargasStats = {'planificadas': 0, 'en_curso': 0, 'terminadas': 0};
  bool _loadingStats = true;
  String? _userName;
  String? _userRole;
  String? _userEmail;

  // Stitch Redesign state variables
  bool _isSidebarHovered = false;
  bool _isOnlineForSyncMonitor = true;
  late final ValueNotifier<int> _queueLengthNotifier;
  late final ValueNotifier<int> _errorsLengthNotifier;
  StreamSubscription? _queueSub;
  StreamSubscription? _errorsSub;
  Timer? _connectivityTimer;

  // Dynamic Dashboard Events
  List<Map<String, dynamic>> _latestEvents = [];
  bool _loadingEvents = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SupabaseService().processQueue();
    _fetchData();

    // Set up ValueNotifiers and Hive listeners to prevent memory leaks
    _queueLengthNotifier = ValueNotifier<int>(Hive.box('sync_queue').length);
    _errorsLengthNotifier = ValueNotifier<int>(Hive.box('sync_errors').length);
    
    _queueSub = Hive.box('sync_queue').watch().listen((_) {
      if (mounted) {
        _queueLengthNotifier.value = Hive.box('sync_queue').length;
      }
    });
    _errorsSub = Hive.box('sync_errors').watch().listen((_) {
      if (mounted) {
        _errorsLengthNotifier.value = Hive.box('sync_errors').length;
      }
    });
    
    // Periodic check of connectivity
    SupabaseService().checkConnectivity().then((online) {
      if (mounted) {
        setState(() {
          _isOnlineForSyncMonitor = online;
        });
      }
    });
    _connectivityTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      final online = await SupabaseService().checkConnectivity();
      if (mounted) {
        setState(() {
          _isOnlineForSyncMonitor = online;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _queueSub?.cancel();
    _errorsSub?.cancel();
    _queueLengthNotifier.dispose();
    _errorsLengthNotifier.dispose();
    _connectivityTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('HomePage: App resumed, triggering processQueue()');
      SupabaseService().processQueue();
    }
  }

  Future<void> _fetchData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nombre = prefs.getString('user_nombre') ?? '';
      final apellido = prefs.getString('user_apellido') ?? '';
      
      if (mounted) {
        setState(() {
          _userName = '$nombre $apellido'.trim();
          _userRole = prefs.getString('user_puesto');
          _userEmail = prefs.getString('user_email');
        });
      }

      final userId = prefs.getString('user_id');
      if (userId == null || userId.isEmpty) {
        print('HomePage: No user session found. Redirecting to welcome/login.');
        if (mounted) {
          context.go('/');
        }
        return;
      }
      print('HomePage: Obteniendo stats para $_userRole ($userId)');
      
      final stats = await SupabaseService().getStats(userId: userId, role: _userRole);
      final cargasStats = await SupabaseService().getCargasStats(userId: userId, role: _userRole);

      // Fetch dynamic events from Supabase (pesajes / remitos) if available
      List<Map<String, dynamic>> events = [];
      try {
        final client = Supabase.instance.client;
        final res = await client
            .from('pesajes')
            .select('created_at, peso_neto, apicultores(nombre)')
            .order('created_at', ascending: false)
            .limit(3);
        if (res != null) {
          for (var item in (res as List)) {
            final name = item['apicultores'] != null ? item['apicultores']['nombre'] : 'Apicultor';
            final kg = item['peso_neto'] ?? 0;
            events.add({
              'title': 'Ingreso Pesaje: $name',
              'subtitle': 'Peso Neto registrado: ${kg}kg',
              'time': _formatTimestamp(item['created_at']),
              'type': 'normal',
              'icon': Icons.scale_rounded,
            });
          }
        }
      } catch (e) {
        print('HomePage: Error obteniendo pesajes reales, usando mockup: $e');
      }

      if (mounted) {
        setState(() {
          _stats = stats;
          _cargasStats = cargasStats;
          _latestEvents = events;
          _loadingStats = false;
          _loadingEvents = false;
        });
      }
    } catch (e) {
      print('HomePage: Error en _fetchData: $e');
      if (mounted) {
        setState(() {
          _loadingStats = false;
          _loadingEvents = false;
        });
      }
    }
  }

  String _formatTimestamp(String? ts) {
    if (ts == null) return 'Ahora';
    try {
      final dt = DateTime.parse(ts).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
      return '${dt.day}/${dt.month}';
    } catch (e) {
      return 'Reciente';
    }
  }

  String get _displayName => _userName?.isNotEmpty == true ? _userName! : 'Usuario';
  
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

  bool get _isChofer {
    final r = _normalizeRole(_userRole);
    final email = (_userEmail ?? '').toLowerCase();
    return r.contains('chofer') || email.contains('mperez') || email.contains('cmuse') || email.contains('agomez') || email.contains('efernandez');
  }

  bool get _isCeoOrGerente {
    final r = _normalizeRole(_userRole);
    return r.contains('ceo') || r.contains('gerente') || r.contains('gerencia');
  }

  bool get _isCompras {
    final r = _normalizeRole(_userRole);
    return r.contains('compras');
  }

  String get _initials {
    final parts = _displayName.split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Widget _buildSidebar(BuildContext context) {
    final double sidebarWidth = _isSidebarHovered ? 260 : 80;
    return MouseRegion(
      onEnter: (_) => setState(() => _isSidebarHovered = true),
      onExit: (_) => setState(() => _isSidebarHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: sidebarWidth,
        color: DesignTokens.primary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 30),
              child: Row(
                mainAxisAlignment: _isSidebarHovered ? MainAxisAlignment.start : MainAxisAlignment.center,
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/images/logo_Geologistica_Verde.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (_isSidebarHovered) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'GeoLogística',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'APIARY LOGISTICS',
                            style: TextStyle(
                              fontFamily: 'Work Sans',
                              fontWeight: FontWeight.w600,
                              fontSize: 8,
                              color: Colors.white.withOpacity(0.4),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Container(
                padding: EdgeInsets.all(_isSidebarHovered ? 12 : 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: _isSidebarHovered ? MainAxisAlignment.start : MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: DesignTokens.secondary,
                      ),
                      child: Text(
                        _initials,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                    if (_isSidebarHovered) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _userRole ?? 'Operador',
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  if (_isAdmin || _isManagement)
                    _sidebarItem(Icons.dashboard_rounded, 'Dashboard', () => context.push('/gerenteHome'), active: true),
                  if (_isAdmin || _isManagement)
                    _sidebarItem(Icons.alt_route_rounded, 'Gestión de Viajes', () => context.push('/viajes')),
                  _sidebarItem(Icons.local_shipping_rounded, 'Vehículos', () => context.push('/vehiculos')),
                  if (!_isDeposito && !_isChofer && !_isCompras)
                    _sidebarItem(Icons.inventory_2_rounded, 'Productos', () => context.push('/productos')),
                  if (!_isChofer) ...[
                    if (!_isCompras)
                      _sidebarItem(Icons.payments_rounded, 'Gestión de Gastos', () => context.push('/gastos')),
                    _sidebarItem(Icons.scale_rounded, 'Control de Pesajes', () => context.push('/pesajes')),
                  ],
                  if (_isDeposito || _isManagement || _isChofer)
                    _sidebarItem(Icons.warehouse_rounded, (_isDeposito || _isManagement) ? 'Cargas Depósito' : 'Depósito Huinca', () => context.push('/depositoHome')),
                  if ((_isAdmin || _isManagement) && !_isDeposito)
                    _sidebarItem(Icons.inventory_2_rounded, 'Gestión de Cargas', () => context.push('/cargas')),
                  const Divider(color: Colors.white10, height: 20),
                  if (!_isDeposito)
                    _sidebarItem(Icons.group_rounded, 'Apicultores', () => context.push('/apicultores')),
                  _sidebarItem(Icons.receipt_long_rounded, 'Remitos Digitales', () => context.push('/remitosLista')),
                ],
              ),
            ),
            _buildSyncMonitor(),
            const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              child: Column(
                children: [
                  _sidebarItem(Icons.logout_rounded, 'Cerrar Sesión', () async {
                    await Supabase.instance.client.auth.signOut();
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('keep_session'); // Eliminar persistencia de sesión activa al hacer logout
                    if (context.mounted) context.go('/');
                  }),
                  _sidebarItem(Icons.power_settings_new_rounded, 'Salir', () {
                    SystemNavigator.pop();
                  }, color: Colors.redAccent.shade100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String title, VoidCallback onTap, {bool active = false, Color? color}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: active ? DesignTokens.secondary.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
        leading: Icon(icon, color: active ? DesignTokens.secondary : (color ?? Colors.white70), size: 20),
        title: _isSidebarHovered
            ? Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12.5,
                  color: active ? DesignTokens.secondary : (color ?? Colors.white70),
                ),
              )
            : null,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildSyncMonitor() {
    return ValueListenableBuilder<int>(
      valueListenable: _queueLengthNotifier,
      builder: (context, pendingCount, _) {
        return ValueListenableBuilder<int>(
          valueListenable: _errorsLengthNotifier,
          builder: (context, errorCount, _) {
            final bool isOnline = _isOnlineForSyncMonitor;
            
            if (!_isSidebarHovered) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Icon(
                      isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      color: isOnline ? Colors.greenAccent : Colors.orangeAccent,
                      size: 16,
                    ),
                    if (pendingCount > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: DesignTokens.secondary, shape: BoxShape.circle),
                        child: Text(
                          '$pendingCount',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }
            
            return Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOnline ? Colors.greenAccent : Colors.orangeAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOnline ? 'ONLINE' : 'OFFLINE',
                        style: const TextStyle(
                          fontFamily: 'Work Sans',
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cola: $pendingCount pendientes',
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Inter'),
                  ),
                  if (errorCount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Errores: $errorCount en cola',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── DESKTOP PREMIUM LAYOUT FOR MANAGEMENT ─────────────────────────────────

  Widget _buildGerenteAdminDesktopContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Cabecera Principal Premium
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Centro de Comando',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w800,
                      fontSize: 32,
                      color: DesignTokens.primary,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const _PulsingDot(),
                      const SizedBox(width: 8),
                      Text(
                        'Operación activa: 12 unidades en tránsito',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: DesignTokens.onSurfaceVariant.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  // Buscador
                  Container(
                    width: 240,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: DesignTokens.outline.withOpacity(0.4)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: DesignTokens.onSurfaceVariant.withOpacity(0.6), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Buscar unidad...',
                              hintStyle: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: DesignTokens.onSurfaceVariant.withOpacity(0.4),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Botón Nueva Operación
                  ElevatedButton.icon(
                    onPressed: () => context.push('/planificarViaje'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesignTokens.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text(
                      'NUEVA OPERACIÓN',
                      style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          // 2. Métricas Bento Premium
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.6,
            children: [
              const CircularProgressLoader(
                progress: 0.82,
                label: 'Capacidad Planta',
                valueText: '82%',
              ),
              const SparklineCard(
                label: 'Unidades Activas',
                valueText: '24/30',
                trendText: 'En ruta en este momento',
                data: [5.0, 8.0, 4.0, 7.0, 10.0, 8.0, 12.0],
              ),
              _bentoCard(
                title: 'Logísticos Libres',
                value: '08',
                trend: 'Personal disponible',
                iconWidget: const Icon(Icons.supervisor_account_rounded, color: DesignTokens.secondary, size: 24),
              ),
              _bentoCard(
                title: 'Tonelaje Semanal',
                value: '4.2 Tn',
                trend: 'Meta semanal: 5.0 Tn',
                accentColor: DesignTokens.secondary, // Fondo dorado llamativo
              ),
            ],
          ),
          const SizedBox(height: 32),
          // 3. Grid de Operaciones (Mapa y Listas / Tablas)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna Izquierda (Ancho 8/12)
              Expanded(
                flex: 8,
                child: Column(
                  children: [
                    // Mapa Satelital Embebido
                    _buildSatelliteMap(),
                    const SizedBox(height: 32),
                    // Tabla de Estado de Flota
                    _buildFleetTable(),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              // Columna Derecha (Ancho 4/12)
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    // Monitor de Planta
                    _buildPlantaMonitor(),
                    const SizedBox(height: 32),
                    // Log de Operaciones
                    _buildOperationsLog(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSatelliteMap() {
    return Container(
      height: 600,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DesignTokens.primary.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Mapa base en escala de grises con contraste verdoso
            Positioned.fill(
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  0.15, 0.45, 0.1, 0, 0,
                  0.1, 0.55, 0.15, 0, 0,
                  0.05, 0.35, 0.1, 0, 0,
                  0,   0,   0,   1, 0,
                ]),
                child: Image.network(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuCAzxfqauJaxsGfgvA24P_vpOzTrxFNXF9nhGT7f3zzaz_OMraIKNexJ6XAHm2-fOQDYNlSQsV9EKst3h0Nyo7nM2KbnjNJEL_SPZ0BTlLcjdUZNshituAPhsA-FrTyTeXZA5SkU7w66G0qg9nFFFgAMev1t9lq48JylO-s-wKtc9Th9v_c1-30VPemfIhr9SVHx3MM1LvII0bTuFOqkyZYNKm_Xp11nql-ybMra0d1MmOUpFjcbbkA2R9aLjfvaq9SkXjCvjRHYD8',
                  fit: BoxFit.cover,
                  errorBuilder: (c, o, s) => Container(
                    color: const Color(0xFF0D1B17),
                    child: Center(
                      child: Icon(Icons.map_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                ),
              ),
            ),
            // Capa de retícula de radar fina
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: CustomPaint(
                  painter: const HoneycombPainter(),
                ),
              ),
            ),
            // Cabecera del Mapa
            Positioned(
              top: 24,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Sincronización Satelital tag esmerilado
                  _buildGlassmorphicOverlay(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'SINCRONIZACIÓN SATELITAL',
                          style: TextStyle(
                            fontFamily: 'Work Sans',
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: DesignTokens.secondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            const Text(
                              'Región Pampeana Norte',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Botón Expandir
                  _buildGlassmorphicOverlay(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: const Text(
                      'VER EN PANTALLA COMPLETA',
                      style: TextStyle(
                        fontFamily: 'Work Sans',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Marcador de Camión Flotante AR-402 (Centro-Izquierda)
            Positioned(
              top: 180,
              left: 150,
              child: Column(
                children: [
                  _buildGlassmorphicOverlay(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(color: DesignTokens.secondary.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.local_shipping_rounded, color: DesignTokens.secondary, size: 16),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('UNIDAD AR-402', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                            Text('EN RUTA: 82 KM/H', style: TextStyle(color: DesignTokens.secondary, fontSize: 9, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white.withOpacity(0.5), Colors.transparent],
                      ),
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: DesignTokens.secondary, shape: BoxShape.circle),
                  ),
                ],
              ),
            ),
            // Marcador de Apiario COL-98 (Centro-Derecha)
            Positioned(
              bottom: 160,
              right: 180,
              child: Column(
                children: [
                  _buildGlassmorphicOverlay(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.hive_rounded, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('APIARIO COL-98', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                            Text('COSECHA ACTIVA', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white.withOpacity(0.5), Colors.transparent],
                      ),
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  ),
                ],
              ),
            ),
            // Telemetría inferior
            Positioned(
              bottom: 24,
              left: 24,
              child: Row(
                children: [
                  _buildGlassmorphicOverlay(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: const Row(
                      children: [
                        Icon(Icons.gps_fixed_rounded, color: Colors.blueAccent, size: 12),
                        SizedBox(width: 6),
                        Text('GPS: 24 LAT', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'Work Sans')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildGlassmorphicOverlay(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: const Row(
                      children: [
                        Icon(Icons.thermostat_rounded, color: Colors.orangeAccent, size: 12),
                        SizedBox(width: 6),
                        Text('TEMP: 21°C', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'Work Sans')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper para construir capas Glassmorphic consistentes con BackdropFilter blur sigma 10
  Widget _buildGlassmorphicOverlay({required Widget child, required EdgeInsetsGeometry padding}) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    if (!isDesktop) {
      // Degradar en móviles para evitar el carísimo BackdropFilter
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: const Color(0xFF08201A).withOpacity(0.9), // Fondo oscuro sólido
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.0),
        ),
        child: child,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF08201A).withOpacity(0.75),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.0),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildFleetTable() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DesignTokens.primary.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Estado de Flota',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: DesignTokens.primary,
                ),
              ),
              Text(
                'MONITOREO EN VIVO',
                style: TextStyle(
                  fontFamily: 'Work Sans',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: DesignTokens.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          // Filas de operadores (Ricardo Gomez & Elena Vazquez)
          _buildFleetRow(
            initials: 'RG',
            name: 'Ricardo Gomez',
            unit: 'Unidad: SC-550',
            status: 'En Desplazamiento',
            isMoving: true,
            destination: 'Sector Balcarce • Zona B',
            volume: '82 Alzas',
          ),
          const Divider(height: 1),
          _buildFleetRow(
            initials: 'EV',
            name: 'Elena Vazquez',
            unit: 'Unidad: SC-901',
            status: 'Descargando',
            isMoving: false,
            destination: 'Planta Central • Muelle 4',
            volume: '140 Alzas',
          ),
        ],
      ),
    );
  }

  Widget _buildFleetRow({
    required String initials,
    required String name,
    required String unit,
    required String status,
    required bool isMoving,
    required String destination,
    required String volume,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: DesignTokens.primary, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(fontFamily: 'Manrope', color: DesignTokens.secondary, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(width: 16),
          // Identificación
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 14, color: DesignTokens.primary)),
                const SizedBox(height: 2),
                Text(unit, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: DesignTokens.onSurfaceVariant)),
              ],
            ),
          ),
          // Estado badge
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isMoving ? Colors.green.shade50 : DesignTokens.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Work Sans',
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: isMoving ? Colors.green.shade700 : DesignTokens.secondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
          // Destino
          Expanded(
            flex: 3,
            child: Text(
              destination,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: DesignTokens.onSurfaceVariant, fontWeight: FontWeight.w300),
            ),
          ),
          // Volumen
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                volume,
                style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 13, color: DesignTokens.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlantaMonitor() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: DesignTokens.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: DesignTokens.primary.withOpacity(0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monitor de Planta',
            style: TextStyle(fontFamily: 'Manrope', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 24),
          // Eficiencia operativa bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'EFICIENCIA OPERATIVA',
                    style: TextStyle(fontFamily: 'Work Sans', fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.6), letterSpacing: 0.5),
                  ),
                  const Text(
                    '94%',
                    style: TextStyle(fontFamily: 'Manrope', fontSize: 12, fontWeight: FontWeight.bold, color: DesignTokens.secondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: 0.94,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(DesignTokens.secondary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Grid controles rápidos
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.08))),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('REMITOS HOY', style: TextStyle(fontFamily: 'Work Sans', fontSize: 8, color: DesignTokens.secondary, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      SizedBox(height: 6),
                      Text('48', style: TextStyle(fontFamily: 'Manrope', fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.08))),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ALERTAS', style: TextStyle(fontFamily: 'Work Sans', fontSize: 8, color: DesignTokens.error, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      SizedBox(height: 6),
                      Text('03', style: TextStyle(fontFamily: 'Manrope', fontSize: 24, fontWeight: FontWeight.w800, color: DesignTokens.error)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOperationsLog() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DesignTokens.primary.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Log de Operaciones',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: DesignTokens.primary,
                ),
              ),
              Icon(Icons.history_toggle_off_rounded, color: DesignTokens.primary.withOpacity(0.4), size: 20),
            ],
          ),
          const SizedBox(height: 24),
          // Items del feed
          if (_loadingEvents)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else ...[
            ..._latestEvents.map((ev) => _buildLogItem(
              icon: ev['icon'] ?? Icons.scale_rounded,
              title: ev['title'] ?? 'Evento',
              time: ev['time'] ?? 'Ahora',
              subtitle: ev['subtitle'] ?? '',
              type: ev['type'] ?? 'normal',
            )),
            // Mock items for premium look if database log is short
            if (_latestEvents.length < 3) ...[
              _buildLogItem(
                icon: Icons.verified_rounded,
                title: 'Cosecha Balcarce Completada',
                time: 'Hace 20 min',
                subtitle: 'Líder: Mario S. - Alta Pureza',
                type: 'success',
              ),
              _buildLogItem(
                icon: Icons.sensors_rounded,
                title: 'Calibración de Sensores',
                time: 'Hace 2 h',
                subtitle: 'Realizado en Taller Central Huinca',
                type: 'normal',
              ),
              _buildLogItem(
                icon: Icons.error_outline_rounded,
                title: 'Alerta Térmica: AR-402',
                time: 'Hace 4 h',
                subtitle: 'Exceso en cabina (+2°C sobre ideal)',
                type: 'critical',
              ),
            ],
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                backgroundColor: DesignTokens.surfaceLow,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'AUDITORÍA COMPLETA',
                style: TextStyle(fontFamily: 'Work Sans', fontSize: 10, fontWeight: FontWeight.bold, color: DesignTokens.primary, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem({
    required IconData icon,
    required String title,
    required String time,
    required String subtitle,
    required String type,
  }) {
    Color itemColor = DesignTokens.primary;
    Color bgColor = DesignTokens.primary.withOpacity(0.06);
    if (type == 'success') {
      itemColor = Colors.green.shade700;
      bgColor = Colors.green.shade50;
    } else if (type == 'critical') {
      itemColor = DesignTokens.error;
      bgColor = DesignTokens.error.withOpacity(0.08);
    } else if (type == 'warning') {
      itemColor = DesignTokens.secondary;
      bgColor = DesignTokens.secondary.withOpacity(0.1);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Icon(icon, color: itemColor, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 13, color: DesignTokens.primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(time, style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: DesignTokens.onSurfaceVariant.withOpacity(0.5))),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: DesignTokens.onSurfaceVariant.withOpacity(0.7), fontWeight: FontWeight.w300),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── END OF DESKTOP LAYOUT ─────────────────────────────────────────────────

  Widget _buildMainContent(BuildContext context, bool isDesktop) {
    return RefreshIndicator(
      color: DesignTokens.secondary,
      onRefresh: _fetchData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, isDesktop ? 40 : 24, 20, 24),
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
                      'Bienvenido,',
                      style: DesignTokens.bodyStyle(color: DesignTokens.onSurfaceVariant),
                    ),
                    Text(
                      _displayName,
                      style: DesignTokens.headlineStyle().copyWith(fontSize: 26, letterSpacing: -0.5),
                    ),
                  ],
                ),
                if (isDesktop)
                  IconButton(
                    onPressed: () {},
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: DesignTokens.primary,
                        border: Border.all(color: DesignTokens.secondary, width: 2),
                      ),
                      child: Text(
                        _initials,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 24),

            if (!_isDeposito) ...[
              Text('ESTADO DE VIAJES', style: DesignTokens.labelStyle().copyWith(letterSpacing: 1.1, fontSize: 11)),
              const SizedBox(height: 14),
              _buildBentoGrid(isDesktop),
              const SizedBox(height: 28),
            ],

            const SizedBox(height: 14),

            Text(
              'MÓDULOS DE OPERACIÓN',
              style: DesignTokens.labelStyle().copyWith(letterSpacing: 1.1, fontSize: 11),
            ),
            const SizedBox(height: 14),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isDesktop ? 4 : 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: isDesktop ? 1.35 : 1.05,
              children: [
                if (_isChofer || _userRole == null)
                  _moduleCard(
                    icon: Icons.local_shipping_rounded,
                    title: 'Mis Viajes',
                    subtitle: 'Rutas asignadas\ny operaciones',
                    bgColor: DesignTokens.primary,
                    accentColor: DesignTokens.secondary,
                    onTap: () => context.push('/choferHome'),
                  ),
                if ((_isDeposito || _isManagement || _isChofer) && !_isCeoOrGerente)
                  _moduleCard(
                    icon: Icons.warehouse_rounded,
                    title: (_isDeposito || _isManagement) ? 'Cargas Depósito' : 'Depósito Huinca',
                    subtitle: 'Cargas y depósito\ncirculante',
                    bgColor: DesignTokens.primary,
                    accentColor: DesignTokens.secondary,
                    onTap: () => context.push('/depositoHome'),
                  ),
                if (_isAdmin || _isManagement)
                  _moduleCard(
                    icon: Icons.alt_route_rounded,
                    title: 'Gestión de Viajes',
                    subtitle: 'Lista completa\nde rutas y viajes',
                    bgColor: DesignTokens.primary,
                    accentColor: DesignTokens.secondary,
                    onTap: () => context.push('/viajes'),
                  ),
                if (_isAdmin || _isManagement)
                  _moduleCard(
                    icon: Icons.dashboard_customize_rounded,
                    title: 'Dashboard',
                    subtitle: 'Estadísticas y\nKPIs de gestión',
                    bgColor: DesignTokens.primary,
                    accentColor: DesignTokens.secondary,
                    onTap: () => context.push('/gerenteHome'),
                  ),
                if (!_isDeposito && (_isManagement && !_isCeoOrGerente && !_isCompras))
                  _moduleCard(
                    icon: Icons.inventory_2_rounded,
                    title: 'Gestión de Cargas',
                    subtitle: 'Preparar cargas\npara viajes',
                    bgColor: DesignTokens.primary,
                    accentColor: DesignTokens.secondary,
                    onTap: () => context.push('/cargas'),
                  ),
                if (!_isChofer && !_isDeposito) ...[
                  _moduleCard(
                    icon: Icons.assignment_ind_rounded,
                    title: 'Planificador',
                    subtitle: 'Crear rutas y\nasignar choferes',
                    bgColor: DesignTokens.primary,
                    accentColor: DesignTokens.secondary,
                    onTap: () => context.push('/planificarViaje'),
                  ),
                  _moduleCard(
                    icon: Icons.list_alt_rounded,
                    title: 'Solicitudes',
                    subtitle: 'Gestión de carga\ny recolecciones',
                    bgColor: DesignTokens.primary,
                    accentColor: DesignTokens.secondary,
                    onTap: () => context.push('/necesidades'),
                  ),
                ],
                if (!_isChofer && !_isCeoOrGerente && !_isDeposito) ...[
                  _moduleCard(
                    icon: Icons.scale_rounded,
                    title: 'Control Pesajes',
                    subtitle: 'Listado de pesajes\ny control de carga',
                    bgColor: DesignTokens.primary,
                    accentColor: DesignTokens.secondary,
                    onTap: () => context.push('/pesajes'),
                  ),
                  if (!_isCompras) ...[
                    _moduleCard(
                      icon: Icons.inventory_2_rounded,
                      title: 'Productos',
                      subtitle: 'Gestión de stock\ne insumos',
                      bgColor: DesignTokens.primary,
                      accentColor: DesignTokens.secondary,
                      onTap: () => context.push('/productos'),
                    ),
                    _moduleCard(
                      icon: Icons.payments_rounded,
                      title: 'Gastos',
                      subtitle: 'Peajes, comida\ny combustible',
                      bgColor: DesignTokens.primary,
                      accentColor: DesignTokens.secondary,
                      onTap: () => context.push('/gastos'),
                    ),
                  ],
                ],
                if (!_isDeposito && !_isChofer && !_isCeoOrGerente)
                  _moduleCard(
                    icon: Icons.alt_route_rounded,
                    title: 'Control de Ruta',
                    subtitle: 'Trayectos activos\nen tiempo real',
                    bgColor: DesignTokens.primary,
                    accentColor: DesignTokens.secondary,
                    onTap: () => context.push('/rutas'),
                  ),
              ],
            ),

            const SizedBox(height: 28),

            Text(
              'ACCIONES RÁPIDAS',
              style: DesignTokens.labelStyle().copyWith(letterSpacing: 1.1, fontSize: 11),
            ),
            const SizedBox(height: 12),

            if (!_isDeposito) ...[                      
              if (!_isCompras) ...[
                _quickAction(Icons.inventory_2_rounded, 'Inventario de Productos', 'Gestión de stock e insumos', () => context.push('/productos')),
                const SizedBox(height: 10),
              ],
              _quickAction(Icons.group_rounded, 'Apicultores', 'Directorio de productores', () => context.push('/apicultores')),
              const SizedBox(height: 10),
            ],
            if (!_isCompras) ...[
              _quickAction(Icons.payments_rounded, 'Gestión de Gastos', 'Registro de peajes y combustible', () => context.push('/gastos')),
              const SizedBox(height: 10),
            ],
            if (!_isChofer) ...[
              _quickAction(
                Icons.map_rounded,
                'Seguimiento Satelital',
                'Monitoreo de camiones en tiempo real',
                () async {
                  final satelitalUrl = Uri.parse('http://satelital.uninet.com.ar/GpsGateServer/VehicleTracker/VehicleTracker.html?appid=59');
                  try {
                    bool launched = await launchUrl(satelitalUrl, mode: LaunchMode.externalApplication);
                    if (!launched) {
                      await launchUrl(satelitalUrl, mode: LaunchMode.platformDefault);
                    }
                  } catch (e) {
                    try {
                      await launchUrl(satelitalUrl, mode: LaunchMode.platformDefault);
                    } catch (err) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al abrir sitio satelital: $err')),
                        );
                      }
                    }
                  }
                },
              ),
              const SizedBox(height: 10),
            ],
            _quickAction(Icons.receipt_long_rounded, 'Remitos Digitales', 'Documentos de cierre', () => context.push('/remitosLista')),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBentoGrid(bool isDesktop) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isDesktop ? 4 : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isDesktop ? 1.45 : 1.1,
      children: [
        _bentoCard(
          title: 'PENDIENTES',
          value: _loadingStats ? '—' : '${_stats['planificados']}',
          trend: 'Viajes planificados',
          iconWidget: const Icon(Icons.pending_actions_rounded, color: Colors.blueAccent, size: 24),
          onTap: () => context.push('/viajes?estado=Pendiente'),
        ),
        _bentoCard(
          title: 'EN CURSO',
          value: _loadingStats ? '—' : '${_stats['en_curso']}',
          trend: 'Viajes activos',
          accentColor: DesignTokens.secondary,
          sparklineData: const [5.0, 8.0, 4.0, 7.0, 10.0, 8.0, 12.0],
          onTap: () => context.push('/viajes?estado=En%20Curso'),
        ),
        _bentoCard(
          title: 'TERMINADOS',
          value: _loadingStats ? '—' : '${_stats['terminados']}',
          trend: 'Historial',
          iconWidget: const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 24),
          onTap: () => context.push('/viajes?estado=Terminado'),
        ),
        _bentoCard(
          title: 'CARGAS HOY',
          value: _loadingStats ? '—' : '${_cargasStats['planificadas']! + _cargasStats['en_curso']! + _cargasStats['terminadas']!}',
          trend: 'Cargas en depósito',
          iconWidget: const Icon(Icons.warehouse_rounded, color: DesignTokens.primary, size: 24),
          onTap: () => context.push('/depositoHome'),
        ),
      ],
    );
  }

  Widget _bentoCard({
    required String title,
    required String value,
    required String trend,
    Widget? iconWidget,
    Color? accentColor,
    List<double>? sparklineData,
    VoidCallback? onTap,
  }) {
    final bool isGold = accentColor == DesignTokens.secondary;
    final bool isDark = accentColor == DesignTokens.primary;
    
    Color cardBg = Colors.white;
    Color textColor = DesignTokens.primary;
    Color subColor = DesignTokens.onSurfaceVariant.withOpacity(0.6);
    Color valueColor = DesignTokens.primary;
    
    if (isGold) {
      cardBg = DesignTokens.secondary;
      textColor = DesignTokens.primary;
      subColor = DesignTokens.primary.withOpacity(0.7);
      valueColor = DesignTokens.primary;
    } else if (isDark) {
      cardBg = DesignTokens.primary;
      textColor = Colors.white;
      subColor = Colors.white60;
      valueColor = DesignTokens.secondary;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (isGold || isDark) ? Colors.transparent : DesignTokens.primary.withOpacity(0.05),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Work Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                    letterSpacing: 0.5,
                    color: subColor,
                  ),
                ),
                if (iconWidget != null) iconWidget,
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    color: valueColor,
                  ),
                ),
                const SizedBox(width: 4),
                if (sparklineData != null)
                  Expanded(
                    child: Container(
                      height: 24,
                      padding: const EdgeInsets.only(left: 12, right: 4),
                      child: CustomPaint(
                        painter: SparklinePainter(sparklineData, DesignTokens.secondary),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              trend,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                color: subColor.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 1024;
        final bool isGerenteAdminDesktop = isDesktop && (_isManagement || _isAdmin);
        
        return Scaffold(
          backgroundColor: DesignTokens.surface,
          drawer: isGerenteAdminDesktop ? null : (isDesktop ? null : _buildDrawer()),
          appBar: isDesktop
              ? null
              : AppBar(
                  backgroundColor: DesignTokens.surface,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  leading: Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu_rounded, color: DesignTokens.primary),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  title: Row(
                    children: [
                      ClipOval(
                        child: Image.asset(
                          'assets/images/logo_Geologistica_Verde.png',
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GeoLogística',
                            style: DesignTokens.headlineStyle().copyWith(fontSize: 16),
                          ),
                          Text(
                            'APIARY LOGISTICS',
                            style: DesignTokens.labelStyle().copyWith(fontSize: 8, color: DesignTokens.primary.withOpacity(0.4), letterSpacing: 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      onPressed: () {},
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: DesignTokens.primary, border: Border.all(color: DesignTokens.secondary, width: 1.5)),
                        child: Text(_initials, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
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
                  if (isDesktop) _buildSidebar(context),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isDesktop ? 1200 : double.infinity),
                        child: isGerenteAdminDesktop
                            ? _buildGerenteAdminDesktopContent(context)
                            : _buildMainContent(context, isDesktop),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          bottomNavigationBar: isGerenteAdminDesktop ? null : (isDesktop ? null : _buildBottomNav()),
        );
      },
    );
  }

  Widget _moduleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color bgColor,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: bgColor.withOpacity(0.3),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: accentColor),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: Colors.white.withOpacity(0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: DesignTokens.primary.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(color: DesignTokens.primary.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: DesignTokens.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: DesignTokens.outline),
              ),
              child: Icon(icon, size: 20, color: DesignTokens.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 14, color: DesignTokens.onSurface)),
                  Text(subtitle, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: DesignTokens.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: DesignTokens.primary.withOpacity(0.25)),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: DesignTokens.surface,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: DesignTokens.primary),
            child: Row(
              children: [
                ClipOval(child: Image.asset('assets/images/logo_Geologistica_Verde.png', width: 50, height: 50)),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(_userRole ?? 'Operador', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (_isAdmin || _isManagement)
                  _drawerItem(Icons.dashboard_rounded, 'Dashboard', () => context.push('/gerenteHome')),
                if (_isAdmin || _isManagement)
                  _drawerItem(Icons.alt_route_rounded, 'Gestión de Viajes', () => context.push('/viajes')),
                _drawerItem(Icons.local_shipping_rounded, 'Vehículos', () => context.push('/vehiculos')),
                if (!_isDeposito && !_isChofer && !_isCompras) ...[
                  _drawerItem(Icons.inventory_2_rounded, 'Productos', () => context.push('/productos')),
                ],
                if (!_isChofer) ...[
                  if (!_isCompras)
                    _drawerItem(Icons.payments_rounded, 'Gestión de Gastos', () => context.push('/gastos')),
                  _drawerItem(Icons.scale_rounded, 'Control de Pesajes', () => context.push('/pesajes')),
                ],
                if (_isDeposito || _isManagement || _isChofer)
                  _drawerItem(Icons.warehouse_rounded, (_isDeposito || _isManagement) ? 'Cargas Depósito' : 'Depósito Huinca', () => context.push('/depositoHome')),
                if ((_isAdmin || _isManagement) && !_isDeposito)
                  _drawerItem(Icons.inventory_2_rounded, 'Gestión de Cargas', () => context.push('/cargas')),
                const Divider(),
                if (!_isDeposito)
                  _drawerItem(Icons.group_rounded, 'Apicultores', () => context.push('/apicultores')),
                _drawerItem(Icons.receipt_long_rounded, 'Remitos Digitales', () => context.push('/remitosLista')),
              ],
            ),
          ),
          const Divider(),
          _drawerItem(Icons.logout_rounded, 'Cerrar Sesión', () async {
            await Supabase.instance.client.auth.signOut();
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('keep_session'); // Eliminar persistencia al hacer logout
            if (context.mounted) context.go('/');
          }),
          _drawerItem(Icons.power_settings_new_rounded, 'Salir', () {
            SystemNavigator.pop();
          }, color: Colors.redAccent),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? DesignTokens.primary),
      title: Text(title, style: DesignTokens.labelStyle().copyWith(color: color ?? DesignTokens.onSurface)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: DesignTokens.primary.withOpacity(0.07))),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _navItem(Icons.home_filled, 'HOME', true, () {}),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: active ? DesignTokens.primary : DesignTokens.onSurface.withOpacity(0.3)),
          if (active) ...[
            const SizedBox(width: 8),
            Text(label, style: DesignTokens.labelStyle().copyWith(fontSize: 10, color: DesignTokens.primary, fontWeight: FontWeight.w800)),
          ],
        ],
      ),
    );
  }
}

// ─── HELPER WIDGETS FOR PREMIUM DASHBOARD ────────────────────────────────────

// Loader circular para capacidad de planta
class CircularProgressLoader extends StatelessWidget {
  final double progress;
  final String label;
  final String valueText;

  const CircularProgressLoader({
    super.key,
    required this.progress,
    required this.label,
    required this.valueText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DesignTokens.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: DesignTokens.primary.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Work Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                    letterSpacing: 0.5,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  valueText,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    color: DesignTokens.secondary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '+2.4% vs semana ant.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: Colors.greenAccent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CircularProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    color: DesignTokens.secondary,
                    strokeWidth: 4,
                  ),
                ),
                Center(
                  child: Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Tarjeta con Sparkline chart
class SparklineCard extends StatelessWidget {
  final String label;
  final String valueText;
  final String trendText;
  final List<double> data;
  final VoidCallback? onTap;

  const SparklineCard({
    super.key,
    required this.label,
    required this.valueText,
    required this.trendText,
    required this.data,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: DesignTokens.primary.withOpacity(0.05),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Work Sans',
                      fontWeight: FontWeight.w700,
                      fontSize: 9,
                      letterSpacing: 0.5,
                      color: DesignTokens.onSurfaceVariant.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    valueText,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      color: DesignTokens.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trendText,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: DesignTokens.onSurfaceVariant.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              height: 40,
              child: CustomPaint(
                painter: SparklinePainter(data, DesignTokens.secondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Punto verde parpadeante de status
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.greenAccent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
