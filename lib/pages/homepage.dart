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
import '../widgets/geo_sidebar.dart';

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

  bool get _isAdministrativo {
    final r = _normalizeRole(_userRole);
    return r.contains('administrativo') || r.contains('administracion') || r.contains('gastos');
  }

  String get _initials {
    final parts = _displayName.split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Widget _buildSyncMonitorFloating() {
    return ValueListenableBuilder<int>(
      valueListenable: _queueLengthNotifier,
      builder: (context, pendingCount, _) {
        return ValueListenableBuilder<int>(
          valueListenable: _errorsLengthNotifier,
          builder: (context, errorCount, _) {
            final bool isOnline = _isOnlineForSyncMonitor;
            
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withOpacity(0.05)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 30,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOnline ? Colors.greenAccent.shade700 : Colors.orangeAccent,
                      boxShadow: [
                        if (isOnline)
                          BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 4),
                      ],
                    ),
                  ),
                  if (pendingCount > 0 || errorCount > 0) ...[
                    const SizedBox(width: 12),
                    Container(width: 1, height: 12, color: DesignTokens.outline.withOpacity(0.2)),
                    const SizedBox(width: 12),
                    if (pendingCount > 0)
                      Text(
                        '$pendingCount PENDIENTES',
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: DesignTokens.onSurfaceVariant),
                      ),
                    if (errorCount > 0) ...[
                      if (pendingCount > 0) const SizedBox(width: 8),
                      Text(
                        '$errorCount ERRORES',
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                    ],
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
      height: 300,
      decoration: BoxDecoration(
        color: DesignTokens.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DesignTokens.outline),
        image: const DecorationImage(
          image: NetworkImage('https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/static/-64.2831,-34.8465,13.5,0/800x400?access_token=pk.eyJ1IjoiZ2VvbG9naXN0aWNhIiwiYSI6ImNsd3F1cDNsczAxbDMyanJ4anR5aWZ4ZmEifQ.xxx'),
          fit: BoxFit.cover,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            color: Colors.black.withOpacity(0.1),
            child: Stack(
              children: [
                Positioned(
                  top: 24,
                  left: 24,
                  child: _buildGlassmorphicOverlay(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: const Row(
                      children: [
                        Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'BASE OPERATIVA',
                          style: TextStyle(
                            fontFamily: 'Work Sans',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: FloatingActionButton.extended(
                    heroTag: 'map_btn',
                    onPressed: () {},
                    backgroundColor: DesignTokens.primary,
                    icon: const Icon(Icons.map_rounded, color: Colors.white),
                    label: const Text('VER MAPA COMPLETO', style: TextStyle(fontFamily: 'Manrope', color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildGlassmorphicOverlay({required Widget child, required EdgeInsetsGeometry padding}) {
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
    if (!isDesktop) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _buildMosaicoBento(context, isDesktop),
      );
    }
    
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _buildMosaicoBento(context, isDesktop),
        ),
      ),
    );
  }

  Widget _buildMosaicoBento(BuildContext context, bool isDesktop) {
    // Definir tarjetas de módulo condicionales basadas en el rol
    List<Widget> leftModules = [];
    List<Widget> rightModules = [];
    
    // Rol Chofer o Genérico
    if (_isChofer || _userRole == null) {
      leftModules.add(_moduleCard(icon: Icons.local_shipping_rounded, title: 'Mis Viajes', subtitle: 'Rutas asignadas', bgColor: Colors.white, accentColor: DesignTokens.secondary, onTap: () => context.push('/choferHome')));
      rightModules.add(_moduleCard(icon: Icons.warehouse_rounded, title: 'Depósito', subtitle: 'Cargas y stock', bgColor: Colors.white, accentColor: DesignTokens.secondary, onTap: () => context.push('/depositoHome')));
    } 
    // Rol Depósito Exclusivo (no management, no chofer)
    else if (_isDeposito && !_isManagement && !_isAdmin) {
      leftModules.add(_moduleCard(icon: Icons.warehouse_rounded, title: 'Depósito', subtitle: 'Cargas y stock', bgColor: Colors.white, accentColor: DesignTokens.secondary, onTap: () => context.push('/depositoHome')));
    }
    // Roles Management / Admin (Compras, Gerente, CEO, Admin)
    else if (_isAdmin || _isManagement) {
      leftModules.add(_moduleCard(
        icon: Icons.alt_route_rounded, 
        title: 'Gestión de Viajes', 
        subtitle: 'Todas las rutas', 
        bgColor: Colors.white, 
        accentColor: DesignTokens.secondary, 
        onTap: () => context.push('/viajes')
      ));
      leftModules.add(const SizedBox(height: 16));
      leftModules.add(_moduleCard(
        icon: Icons.list_alt_rounded,
        title: 'Solicitudes', 
        subtitle: 'Recolección y Distribución', 
        bgColor: Colors.white, 
        accentColor: DesignTokens.secondary, 
        onTap: () => context.push('/necesidades')
      ));

      rightModules.add(_moduleCard(
        icon: Icons.scale_rounded, 
        title: 'Control Pesajes', 
        subtitle: 'Báscula', 
        bgColor: Colors.white, 
        accentColor: DesignTokens.secondary, 
        onTap: () => context.push('/pesajes')
      ));
      rightModules.add(const SizedBox(height: 16));
      rightModules.add(_moduleCard(
        icon: Icons.group_rounded, 
        title: 'Apicultores', 
        subtitle: 'Gestión de productores', 
        bgColor: Colors.white, 
        accentColor: DesignTokens.secondary, 
        onTap: () => context.push('/apicultores')
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado principal (Home)
        if (isDesktop) ...[
          Text('GEOLOGÍSTICA > INICIO', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w600, fontSize: 10, color: DesignTokens.primary.withOpacity(0.5), letterSpacing: 2)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Home', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 28, color: DesignTokens.primary, letterSpacing: -0.5)),
              Row(
                children: [
                  IconButton(
                    onPressed: _fetchData,
                    icon: const Icon(Icons.refresh_rounded, color: DesignTokens.primary),
                  ),
                  if (_isManagement || _isAdmin)
                    IconButton(
                      onPressed: () {
                        if (context.canPop()) context.pop();
                        else context.go('/gerenteHome');
                      },
                      icon: const Icon(Icons.arrow_back_rounded, color: DesignTokens.primary),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
        // Encabezado
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('OPERACIONES EN CURSO', style: TextStyle(fontFamily: 'Work Sans', fontSize: 14, fontWeight: FontWeight.w800, color: DesignTokens.primary.withOpacity(0.5), letterSpacing: 2)),
            if (!isDesktop) ...[
              Row(
                children: [
                  if (_isManagement || _isAdmin)
                    IconButton(
                      onPressed: () {
                        if (context.canPop()) context.pop();
                        else context.go('/gerenteHome');
                      },
                      icon: const Icon(Icons.arrow_back_rounded, color: DesignTokens.primary),
                    ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        // KPIs
        isDesktop ? Row(
          children: [
            Expanded(
              child: _bentoCard(
                title: 'PENDIENTES',
                value: _loadingStats ? '—' : '${_stats['planificados'] ?? 0}',
                trend: 'Viajes planificados',
                iconWidget: const Icon(Icons.pending_actions_rounded, color: Colors.blueAccent, size: 24),
                onTap: () => context.push('/viajes?estado=Pendiente'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _bentoCard(
                title: 'EN CURSO',
                value: _loadingStats ? '—' : '${_stats['en_curso'] ?? 0}',
                trend: 'Viajes activos',
                accentColor: DesignTokens.secondary,
                iconWidget: const Icon(Icons.local_shipping_rounded, color: DesignTokens.secondary, size: 24),
                sparklineData: const [5.0, 8.0, 4.0, 7.0, 10.0, 8.0, 12.0],
                onTap: () => context.push('/viajes?estado=En%20Curso'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _bentoCard(
                title: 'TERMINADOS',
                value: _loadingStats ? '—' : '${_stats['terminados'] ?? 0}',
                trend: 'Historial',
                iconWidget: const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 24),
                onTap: () => context.push('/viajes?estado=Terminado'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _bentoCard(
                title: 'CARGAS HOY',
                value: _loadingStats ? '—' : '${(_cargasStats['planificadas'] ?? 0) + (_cargasStats['en_curso'] ?? 0) + (_cargasStats['terminadas'] ?? 0)}',
                trend: 'Cargas en depósito',
                iconWidget: const Icon(Icons.warehouse_rounded, color: DesignTokens.primary, size: 24),
                onTap: () => context.push('/depositoHome'),
              ),
            ),
          ],
        ) : Column(
          children: [
            Row(
              children: [
                Expanded(child: _bentoCard(title: 'PENDIENTES', value: _loadingStats ? '—' : '${_stats['planificados'] ?? 0}', trend: 'Viajes planificados', iconWidget: const Icon(Icons.pending_actions_rounded, color: Colors.blueAccent, size: 20), onTap: () => context.push('/viajes?estado=Pendiente'))),
                const SizedBox(width: 16),
                Expanded(child: _bentoCard(title: 'EN CURSO', value: _loadingStats ? '—' : '${_stats['en_curso'] ?? 0}', trend: 'Viajes activos', accentColor: DesignTokens.secondary, iconWidget: const Icon(Icons.local_shipping_rounded, color: DesignTokens.secondary, size: 20), sparklineData: const [5.0, 8.0, 4.0, 7.0, 10.0, 8.0, 12.0], onTap: () => context.push('/viajes?estado=En%20Curso'))),
              ]
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _bentoCard(title: 'TERMINADOS', value: _loadingStats ? '—' : '${_stats['terminados'] ?? 0}', trend: 'Historial', iconWidget: const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 20), onTap: () => context.push('/viajes?estado=Terminado'))),
                const SizedBox(width: 16),
                Expanded(child: _bentoCard(title: 'CARGAS HOY', value: _loadingStats ? '—' : '${(_cargasStats['planificadas'] ?? 0) + (_cargasStats['en_curso'] ?? 0) + (_cargasStats['terminadas'] ?? 0)}', trend: 'Cargas en depósito', iconWidget: const Icon(Icons.warehouse_rounded, color: DesignTokens.primary, size: 20), onTap: () => context.push('/depositoHome'))),
              ]
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 24, color: Colors.black12),
        
        Expanded(
          child: RefreshIndicator(
            color: DesignTokens.secondary,
            onRefresh: _fetchData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 12, bottom: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MÓDULOS DE OPERACIÓN', style: TextStyle(fontFamily: 'Work Sans', fontSize: 14, fontWeight: FontWeight.w800, color: DesignTokens.primary.withOpacity(0.5), letterSpacing: 2)),
                  const SizedBox(height: 16),
                  // Mosaico Asimétrico Real (Estructura de Bloques 70/30)
                  isDesktop ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: leftModules,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: rightModules,
                        ),
                      ),
                    ],
                  ) : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [...leftModules, if (rightModules.isNotEmpty) const SizedBox(height: 16), ...rightModules],
                  ),
                ],
              ),
            ),
          ),
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
    return _BentoCardWidget(
      title: title,
      value: value,
      trend: trend,
      iconWidget: iconWidget,
      accentColor: accentColor,
      sparklineData: sparklineData,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;
        final bool isGerenteAdminDesktop = isDesktop && (_isManagement || _isAdmin);
        
        return Scaffold(
          backgroundColor: const Color(0xFFFBF9F8),
          drawer: isGerenteAdminDesktop ? null : (isDesktop ? null : _buildDrawer()),
          appBar: isDesktop
              ? null
              : AppBar(
                  backgroundColor: const Color(0xFFFBF9F8),
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
                  if (isDesktop) GeoSidebar(userRole: _userRole ?? 'Operador', userEmail: _userEmail ?? '', displayName: _displayName),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: _buildMainContent(context, isDesktop),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 24,
                right: 24,
                child: _buildSyncMonitorFloating(),
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
    return _ModuleCardWidget(
      icon: icon,
      title: title,
      subtitle: subtitle,
      bgColor: bgColor,
      accentColor: accentColor,
      onTap: onTap,
    );
  }

  Widget _quickAction(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 30, offset: const Offset(0, 8)),
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
                if ((_isAdmin || _isManagement) && !_isAdministrativo)
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
                    fontFamily: 'JetBrains Mono',
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
                      fontFamily: 'JetBrains Mono',
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
                      fontFamily: 'JetBrains Mono',
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

class _BentoCardWidget extends StatefulWidget {
  final String title;
  final String value;
  final String trend;
  final Widget? iconWidget;
  final Color? accentColor;
  final List<double>? sparklineData;
  final VoidCallback? onTap;

  const _BentoCardWidget({
    required this.title,
    required this.value,
    required this.trend,
    this.iconWidget,
    this.accentColor,
    this.sparklineData,
    this.onTap,
  });

  @override
  State<_BentoCardWidget> createState() => _BentoCardWidgetState();
}

class _BentoCardWidgetState extends State<_BentoCardWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color cardBg = const Color(0xFFFFFFFF);
    Color subColor = DesignTokens.onSurfaceVariant.withOpacity(0.7);
    Color valueColor = const Color(0xFF08201A);
    Color accent = widget.accentColor ?? DesignTokens.secondary;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _isHovered ? -6 : 0, 0),
          decoration: BoxDecoration(
            color: cardBg.withOpacity(0.9), // Glassmorphism hint
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accent.withOpacity(_isHovered ? 0.3 : 0.05),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(_isHovered ? 0.15 : 0.04),
                blurRadius: _isHovered ? 30 : 15,
                offset: Offset(0, _isHovered ? 12 : 6),
              )
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Efecto de brillo de fondo
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withOpacity(0.05),
                  ),
                ),
              ),
              if (widget.sparklineData != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 80,
                  child: Opacity(
                    opacity: 0.25, // Mucho más visible
                    child: CustomPaint(
                      painter: SparklinePainter(widget.sparklineData!, accent),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 1.2,
                            color: subColor,
                          ),
                        ),
                        if (widget.iconWidget != null) widget.iconWidget!,
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.value,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w900,
                        fontSize: 48,
                        color: valueColor,
                        height: 1.0,
                        letterSpacing: -1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.trend,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: accent.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleCardWidget extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color bgColor;
  final Color accentColor;
  final VoidCallback onTap;

  const _ModuleCardWidget({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bgColor,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_ModuleCardWidget> createState() => _ModuleCardWidgetState();
}

class _ModuleCardWidgetState extends State<_ModuleCardWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color baseAccent = widget.accentColor;
    
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
            borderRadius: BorderRadius.circular(28), // Bordes más suaves
            border: Border.all(
              color: baseAccent.withOpacity(_isHovered ? 0.4 : 0.08),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: baseAccent.withOpacity(_isHovered ? 0.2 : 0.05),
                blurRadius: _isHovered ? 40 : 20,
                offset: Offset(0, _isHovered ? 15 : 8),
              )
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Capa 1: Fondo y Gradiente Premium
              Positioned.fill(
                child: Container(
                  color: const Color(0xFFFFFFFF).withOpacity(0.8), // Efecto cristal
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFFFFFFF),
                          baseAccent.withOpacity(_isHovered ? 0.08 : 0.03),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Capa 2: Textura (Icono gigante muy difuminado)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutQuint,
                bottom: _isHovered ? -15 : -25,
                right: _isHovered ? -15 : -25,
                child: Transform.rotate(
                  angle: _isHovered ? -0.1 : 0,
                  child: Icon(
                    widget.icon,
                    size: 160,
                    color: baseAccent.withOpacity(0.06), // Opacidad mayor para que se note
                  ),
                ),
              ),
              // Capa 3: Contenido Frontal
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: baseAccent.withOpacity(_isHovered ? 0.15 : 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(widget.icon, size: 32, color: baseAccent),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w900, // Extrabold real
                        fontSize: 26,
                        color: Color(0xFF08201A), // Dark verde corporativo
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        color: const Color(0xFF08201A).withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
