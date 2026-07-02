import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/design_tokens.dart';
import '../backend/supabase_service.dart';

/// Pantalla de Agregar Pesaje — asociada a una parada de recolección
/// Recibe: paradaId, viajeId, viajeCode, apicultorNombre, localidad
class AgregarPesajeWidget extends StatefulWidget {
  final String paradaId;
  final String? viajeId;
  final String viajeCode;
  final String apicultorNombre;
  final String localidad;
  final String? apicultorId;

  const AgregarPesajeWidget({
    super.key,
    required this.paradaId,
    this.viajeId,
    required this.viajeCode,
    required this.apicultorNombre,
    required this.localidad,
    this.apicultorId,
  });

  @override
  State<AgregarPesajeWidget> createState() => _AgregarPesajeWidgetState();
}

class _AgregarPesajeWidgetState extends State<AgregarPesajeWidget> {
  final List<Map<String, dynamic>> _tambores = [];
  bool _loadingExisting = true;
  bool _isOnline = true;

  final FocusNode _senasaFocusNode = FocusNode();
  final FocusNode _brutoFocusNode = FocusNode();
  final FocusNode _taraFocusNode = FocusNode();

  String? _userName;
  String? _userRole;
  String get _displayName => _userName?.isNotEmpty == true ? _userName! : 'Usuario';
  String get _initials {
    final parts = _displayName.split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Future<void> _loadUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          final nombre = prefs.getString('user_nombre') ?? '';
          final apellido = prefs.getString('user_apellido') ?? '';
          _userName = '$nombre $apellido'.trim();
          _userRole = prefs.getString('user_puesto');
        });
      }
    } catch (_) {}
  }

  // Multi-apicultor and optional weighing state
  List<Map<String, dynamic>> _apicultoresList = [];
  Map<String, Map<String, dynamic>> _apicultoresMap = {};
  String? _selectedApicultorId;
  bool _pesarTambores = true;
  bool _lockPesarMode = false;

  String? _titularIdOfParada;
  double _plannedTcmCount = 0.0;
  bool _isSaving = false;
  int _deletingIndex = -1;

  bool get _isTitularResponsable {
    if (_selectedApicultorId == null || _titularIdOfParada == null) return false;
    return _selectedApicultorId!.trim().toLowerCase() == _titularIdOfParada!.trim().toLowerCase();
  }

  Future<void> _scanBarcode() async {
    // TODO (Fase 2): Integrar mobile_scanner para reactivar la cámara en la PWA de los choferes
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El escaneo de código de barras no está disponible en la versión web. Ingrese el código manualmente.')),
      );
      return;
    }
    try {
      final String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
        '#08201A', // Primary forest green color from DesignTokens
        'Cancelar',
        true,
        ScanMode.BARCODE,
      );
      if (barcodeScanRes != '-1' && barcodeScanRes.isNotEmpty) {
        setState(() {
          _senasaController.text = barcodeScanRes;
        });
        if (_pesarTambores) {
          // Auto focus the bruto input after scanning successfully
          FocusScope.of(context).nextFocus();
        }
      }
    } catch (e) {
      debugPrint('Error scanning barcode: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al escanear: $e. Ingrese el código a mano.')),
      );
    }
  }

  // Controladores del formulario de nuevo tambor
  final _senasaController = TextEditingController();
  final _brutoController = TextEditingController();
  final _taraController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  double get _netoActual {
    final b = double.tryParse(_brutoController.text) ?? 0;
    final t = double.tryParse(_taraController.text) ?? 0;
    return (b - t).clamp(0, double.infinity);
  }

  bool _isSameApicId(String? id1, String? id2) {
    if (id1 == null || id2 == null) return false;
    return id1.trim().toLowerCase() == id2.trim().toLowerCase();
  }

  double get _totalBruto => _tambores.where((t) => _isSameApicId(t['apicultor_id']?.toString(), _selectedApicultorId)).fold(0, (s, t) => s + (t['peso_bruto'] as double));
  double get _totalTara => _tambores.where((t) => _isSameApicId(t['apicultor_id']?.toString(), _selectedApicultorId)).fold(0, (s, t) => s + (t['tara'] as double));
  double get _totalNeto => _tambores.where((t) => _isSameApicId(t['apicultor_id']?.toString(), _selectedApicultorId)).fold(0, (s, t) => s + (t['peso_neto'] as double));

  @override
  void initState() {
    super.initState();
    _loadExistingPesajes();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _senasaController.dispose();
    _brutoController.dispose();
    _taraController.dispose();
    _senasaFocusNode.dispose();
    _brutoFocusNode.dispose();
    _taraFocusNode.dispose();
    super.dispose();
  }

  void _updatePesarStateForSelectedApicultor() {
    final apicDrums = _tambores.where((t) => _isSameApicId(t['apicultor_id']?.toString(), _selectedApicultorId)).toList();
    if (apicDrums.isNotEmpty) {
      final firstDrumBruto = apicDrums.first['peso_bruto'] as double;
      _pesarTambores = firstDrumBruto > 0;
      _lockPesarMode = true;
    } else {
      _pesarTambores = true; // Default to true
      _lockPesarMode = false;
    }
  }

  Future<void> _loadExistingPesajes() async {
    try {
      final service = SupabaseService();
      final bool online = await service.checkConnectivity();
      
      final dataSafe = await service.getParadaAndViajeOfflineSafe(widget.paradaId);
      final parada = dataSafe?['parada'];
      
      String? titularIdOfParada;
      if (parada != null && parada['solicitud_id'] != null) {
        if (online) {
          try {
            final solicitud = await Supabase.instance.client
                .from('solicitudes')
                .select('apicultor_id')
                .eq('id', parada['solicitud_id'])
                .maybeSingle();
            if (solicitud != null && solicitud['apicultor_id'] != null) {
              titularIdOfParada = solicitud['apicultor_id'].toString();
            }
          } catch (e) {
            debugPrint('Error resolving apicultor from solicitud: $e');
          }
        }
      }
      
      titularIdOfParada ??= widget.apicultorId;

      double plannedTcmCount = 0.0;
      if (parada != null && parada['parada_items'] != null) {
        final itemsData = parada['parada_items'] as List;
        for (var item in itemsData) {
          final String code = (item['producto_codigo'] ?? '').toString().trim().toUpperCase();
          if (code == 'TCM' || code == '1') {
            plannedTcmCount += (item['cantidad'] as num).toDouble();
          }
        }
      }

      final apicultores = await service.getApicultores();
      final pesajesList = await service.getPesajesOfflineSafe(widget.paradaId);

      if (mounted) {
        setState(() {
          _isOnline = online;
          _apicultoresList = apicultores;
          _apicultoresMap = {for (var a in apicultores) a['id'].toString().trim().toLowerCase(): a};
          _titularIdOfParada = titularIdOfParada;
          _plannedTcmCount = plannedTcmCount;

          final defaultId = widget.apicultorId ?? titularIdOfParada;
          String? foundId;
          if (defaultId != null) {
            for (final key in _apicultoresMap.keys) {
              if (key.trim().toLowerCase() == defaultId.trim().toLowerCase()) {
                foundId = key;
                break;
              }
            }
          }
          if (foundId != null) {
            _selectedApicultorId = _apicultoresMap[foundId]?['id']?.toString() ?? defaultId;
          } else if (apicultores.isNotEmpty) {
            _selectedApicultorId = apicultores.first['id']?.toString();
          }

          _tambores.clear();
          _tambores.addAll(pesajesList.map((r) => {
            'id': r['id'],
            'senasa_codigo': r['senasa_codigo'] ?? '',
            'peso_bruto': r['peso_bruto'] ?? 0.0,
            'tara': r['tara'] ?? 0.0,
            'peso_neto': r['peso_neto'] ?? 0.0,
            'apicultor_id': r['apicultor_id']?.toString() ?? widget.apicultorId ?? titularIdOfParada,
            'guardado': r['guardado'] ?? true,
          }));

          _updatePesarStateForSelectedApicultor();
          _loadingExisting = false;
        });
      }
    } catch (e) {
      debugPrint('Error en _loadExistingPesajes: $e');
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  Future<void> _agregarTambor() async {
    if (!_formKey.currentState!.validate()) return;

    final bruto = _pesarTambores ? (double.tryParse(_brutoController.text) ?? 0) : 0.0;
    final tara = _pesarTambores ? (double.tryParse(_taraController.text) ?? 0) : 0.0;
    final neto = _pesarTambores ? (bruto - tara).clamp(0, double.infinity).toDouble() : 0.0;
    final senasa = _senasaController.text.trim();
    final apicId = _selectedApicultorId;

    setState(() {
      _isSaving = true;
    });

    try {
      final Map<String, dynamic> pesajeData = {
        'parada_id': widget.paradaId,
        'apicultor_id': apicId,
        'senasa_codigo': senasa,
        'peso_bruto': bruto,
        'tara': tara,
      };
      if (widget.viajeId != null) {
        pesajeData['viaje_id'] = widget.viajeId;
      }

      final bool online = await SupabaseService().checkConnectivity();
      final String generatedId = await SupabaseService().createPesaje(pesajeData);

      setState(() {
        _tambores.add({
          'id': generatedId,
          'senasa_codigo': senasa,
          'peso_bruto': bruto,
          'tara': tara,
          'peso_neto': neto,
          'apicultor_id': apicId,
          'guardado': online,
        });
        _lockPesarMode = true;
      });

      _senasaController.clear();
      _brutoController.clear();
      _taraController.clear();
      _senasaFocusNode.requestFocus();
    } catch (e) {
      debugPrint('Error inserting pesaje: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar pesaje: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _eliminarTambor(int index) async {
    final t = _tambores[index];
    final dbId = t['id'];

    setState(() {
      _deletingIndex = index;
    });

    try {
      if (dbId != null) {
        await SupabaseService().deletePesaje(dbId.toString(), widget.paradaId);
      }

      setState(() {
        _tambores.removeAt(index);
        _updatePesarStateForSelectedApicultor();
      });
    } catch (e) {
      debugPrint('Error deleting pesaje: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar pesaje: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _deletingIndex = -1;
        });
      }
    }
  }

  void _checkDiscrepancyAndPop() {
    final filteredCount = _tambores.where((t) => _isSameApicId(t['apicultor_id']?.toString(), _selectedApicultorId)).length;
    
    if (_isTitularResponsable && filteredCount != _plannedTcmCount) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Discrepancia detectada', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Has registrado $filteredCount tambores de los ${_plannedTcmCount.toStringAsFixed(0)} planificados.\n\n¿Deseas volver igualmente?',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCELAR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx); // Cerrar diálogo
                Navigator.pop(context); // Volver a la parada
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.secondary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('VOLVER IGUALMENTE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
    }
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
                _sidebarItem(Icons.dashboard_rounded, 'Dashboard', () => context.push('/gerenteHome')),
                _sidebarItem(Icons.alt_route_rounded, 'Gestión de Viajes', () => context.push('/viajes'), active: true),
                _sidebarItem(Icons.local_shipping_rounded, 'Vehículos', () => context.push('/vehiculos')),
                const Divider(),
                _sidebarItem(Icons.group_rounded, 'Apicultores', () => context.push('/apicultores')),
                _sidebarItem(Icons.receipt_long_rounded, 'Remitos Digitales', () => context.push('/remitosLista')),
              ],
            ),
          ),
          const Divider(),
          _sidebarItem(Icons.logout_rounded, 'Cerrar Sesión', () async {
            await Supabase.instance.client.auth.signOut();
            if (context.mounted) context.go('/');
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 260,
      color: DesignTokens.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 30),
            child: Row(
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/images/logo_Geologistica_Verde.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
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
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
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
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _sidebarItem(Icons.dashboard_rounded, 'Dashboard', () => context.push('/gerenteHome')),
                _sidebarItem(Icons.alt_route_rounded, 'Gestión de Viajes', () => context.push('/viajes'), active: true),
                _sidebarItem(Icons.local_shipping_rounded, 'Vehículos', () => context.push('/vehiculos')),
                const Divider(color: Colors.white10, height: 20),
                _sidebarItem(Icons.group_rounded, 'Apicultores', () => context.push('/apicultores')),
                _sidebarItem(Icons.receipt_long_rounded, 'Remitos Digitales', () => context.push('/remitosLista')),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              children: [
                _sidebarItem(Icons.logout_rounded, 'Cerrar Sesión', () async {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) context.go('/');
                }),
              ],
            ),
          ),
        ],
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
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12.5,
            color: active ? DesignTokens.secondary : (color ?? Colors.white70),
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      color: Colors.redAccent.shade100,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: const [
          Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Modo Offline (Sin Conexión) — Los datos se sincronizarán al reconectar.',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalScaleDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F0D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.secondary.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: DesignTokens.secondary.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
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
                'BÁSCULA DIGITAL - PESO NETO ACUMULADO',
                style: TextStyle(
                  fontFamily: 'Work Sans',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white54,
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_rounded, size: 10, color: Colors.greenAccent),
                    SizedBox(width: 4),
                    Text(
                      'CONECTADO',
                      style: TextStyle(fontFamily: 'Work Sans', fontSize: 8, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _totalNeto.toStringAsFixed(1),
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: DesignTokens.secondary,
                  shadows: [
                    Shadow(
                      color: Color(0x66FDBE49),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const Text(
                'kg',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: DesignTokens.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isDesktop) {
    if (!isDesktop) {
      return CustomScrollView(
        slivers: [
          if (!_isOnline) SliverToBoxAdapter(child: _buildOfflineBanner()),
          SliverToBoxAdapter(child: _buildContextCard()),
          if (_pesarTambores) SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: _buildDigitalScaleDisplay(),
            ),
          ),
          SliverToBoxAdapter(child: _buildFormCard()),
          SliverToBoxAdapter(child: _buildTamboresHeader()),
          if (_tambores.where((t) => _isSameApicId(t['apicultor_id']?.toString(), _selectedApicultorId)).isEmpty)
            SliverToBoxAdapter(child: _buildEmptyTambores())
          else
            SliverToBoxAdapter(child: _buildTabla()),
          if (_pesarTambores && _tambores.where((t) => _isSameApicId(t['apicultor_id']?.toString(), _selectedApicultorId)).isNotEmpty)
            SliverToBoxAdapter(child: _buildTotalesCard()),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      );
    } else {
      final drumsList = _tambores.where((t) => _isSameApicId(t['apicultor_id']?.toString(), _selectedApicultorId)).toList();
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna Izquierda: Monitor de báscula oscuro y Formulario
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_isOnline) _buildOfflineBanner(),
                      _buildContextCard(),
                      const SizedBox(height: 20),
                      _buildDigitalScaleDisplay(),
                      const SizedBox(height: 20),
                      _buildFormCard(),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Columna Derecha: Tabla analítica nativa y ecuación
                Expanded(
                  flex: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTamboresHeader(),
                      const SizedBox(height: 8),
                      // Ecuación explícita
                      if (_pesarTambores)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: DesignTokens.surfaceLow,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: DesignTokens.primary.withOpacity(0.1)),
                          ),
                          child: const Text(
                            '[Peso Bruto] - [Tara] = [Peso Neto]',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: DesignTokens.primary,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (drumsList.isEmpty)
                        _buildEmptyTambores()
                      else
                        _buildTablaAnalytics(),
                      if (_pesarTambores && drumsList.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildTotalesCard(),
                      ],
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

  Widget _buildTablaAnalytics() {
    final filteredDrums = _tambores.where((t) => _isSameApicId(t['apicultor_id']?.toString(), _selectedApicultorId)).toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.primary.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: Column(
        children: [
          // Header oscuro Tabla Analítica
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0A0F0D),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                _thAnalitico('N° Correlativo', 2),
                _thAnalitico('SENASA', 3),
                _thAnalitico('Lote', 2),
                _thAnalitico('Temp', 2),
                _thAnalitico('Hum', 2),
                if (_pesarTambores) ...[
                  _thAnalitico('Bruto', 2, right: true),
                  _thAnalitico('Tara', 2, right: true),
                  _thAnalitico('Neto', 2, right: true),
                ],
                const SizedBox(width: 40), // Acciones
              ],
            ),
          ),
          ...List.generate(filteredDrums.length, (i) {
            final t = filteredDrums[i];
            final originalIndex = _tambores.indexOf(t);
            final isEven = i % 2 == 0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isEven ? const Color(0xFFFAFAFA) : Colors.white,
                border: i < filteredDrums.length - 1
                    ? const Border(bottom: BorderSide(color: Color(0xFFF5F5F5)))
                    : null,
                borderRadius: i == filteredDrums.length - 1
                    ? const BorderRadius.vertical(bottom: Radius.circular(16))
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text('${i + 1}', style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12, color: DesignTokens.onSurfaceVariant))),
                  Expanded(flex: 3, child: Text(t['senasa_codigo']?.toString() ?? '', style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12, fontWeight: FontWeight.bold, color: DesignTokens.primary))),
                  Expanded(flex: 2, child: const Text('-', style: TextStyle(color: Colors.black38))), // Lote
                  Expanded(flex: 2, child: const Text('-', style: TextStyle(color: Colors.black38))), // Temp
                  Expanded(flex: 2, child: const Text('-', style: TextStyle(color: Colors.black38))), // Hum
                  if (_pesarTambores) ...[
                    Expanded(flex: 2, child: Text('${(t['peso_bruto'] as double).toStringAsFixed(1)} kg', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12, color: DesignTokens.onSurfaceVariant))),
                    Expanded(flex: 2, child: Text('${(t['tara'] as double).toStringAsFixed(1)} kg', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12, color: DesignTokens.onSurfaceVariant))),
                    Expanded(flex: 2, child: Text('${(t['peso_neto'] as double).toStringAsFixed(1)} kg', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12, fontWeight: FontWeight.bold, color: DesignTokens.secondary))),
                  ],
                  _deletingIndex == originalIndex
                      ? const SizedBox(width: 40, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))))
                      : SizedBox(
                          width: 40,
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            onPressed: () => _eliminarTambor(originalIndex),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _thAnalitico(String text, int flex, {bool right = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        text.toUpperCase(),
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: const TextStyle(fontFamily: 'Work Sans', color: DesignTokens.secondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;
        
        return Scaffold(
          backgroundColor: const Color(0xFFFBFBFB),
          drawer: isDesktop ? null : _buildDrawer(),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: isDesktop
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: DesignTokens.primary, size: 20),
                    onPressed: () => context.go('/home'),
                  )
                : IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: DesignTokens.primary, size: 20),
                    onPressed: () => _checkDiscrepancyAndPop(),
                  ),
            centerTitle: false,
            title: Text(_pesarTambores ? 'Pesaje de Tambores' : 'Registro de Tambores', style: DesignTokens.headlineStyle()),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: DesignTokens.primary.withOpacity(0.08)),
            ),
          ),
          body: RawKeyboardListener(
            focusNode: FocusNode(),
            autofocus: true,
            onKey: (event) {
              if (event.isKeyPressed(LogicalKeyboardKey.escape)) {
                _senasaController.clear();
                _brutoController.clear();
                _taraController.clear();
                _senasaFocusNode.requestFocus();
              } else if (event.isControlPressed && event.isKeyPressed(LogicalKeyboardKey.enter)) {
                if (!_isSaving) {
                  _agregarTambor();
                }
              }
            },
            child: _loadingExisting
                ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
                : Stack(
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
                              child: _buildMainContent(isDesktop),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
          ),
          floatingActionButtonLocation: isDesktop ? FloatingActionButtonLocation.endFloat : FloatingActionButtonLocation.centerFloat,
          floatingActionButton: _buildVolverBtn(),
        );
      },
    );
  }

  Widget _buildContextCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.primary.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: DesignTokens.secondary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_shipping_rounded, size: 20, color: DesignTokens.secondary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.viajeCode,
                  style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w900, fontSize: 16, color: DesignTokens.primary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.apicultorNombre}  •  ${widget.localidad}',
                  style: TextStyle(fontSize: 12, color: DesignTokens.primary.withOpacity(0.5)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF7E7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_tambores.where((t) => _isSameApicId(t['apicultor_id']?.toString(), _selectedApicultorId)).length} TCM',
              style: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFFC68E17)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.add_box_rounded, size: 18, color: DesignTokens.secondary),
                const SizedBox(width: 8),
                Text('Nuevo Tambor', style: DesignTokens.headlineStyle().copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
            
            // Tarjeta de instrucciones dinámica
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _pesarTambores ? const Color(0xFFFDF7E7) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _pesarTambores ? const Color(0xFFFEF3C7) : const Color(0xFFFCA5A5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _pesarTambores ? Icons.scale_rounded : Icons.warning_amber_rounded,
                    size: 14,
                    color: _pesarTambores ? const Color(0xFFB45309) : const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _pesarTambores 
                          ? 'Registrá el código SENASA y los pesos del tambor.' 
                          : '¡IMPORTANTE! Recordá recolectar el código SENASA de cada tambor. No se registrarán pesos.',
                      style: TextStyle(
                        fontSize: 11,
                        color: _pesarTambores ? const Color(0xFF78350F) : const Color(0xFF991B1B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Dropdown de Apicultor
            DropdownButtonFormField<String>(
              value: _selectedApicultorId,
              decoration: _inputDecoration('APICULTOR', Icons.person_rounded),
              items: _apicultoresList.map((a) => DropdownMenuItem<String>(
                value: a['id']?.toString(),
                child: Text(
                  a['nombre'] ?? '',
                  style: const TextStyle(fontSize: 13, fontFamily: 'Inter'),
                  overflow: TextOverflow.ellipsis,
                ),
              )).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedApicultorId = val;
                  _updatePesarStateForSelectedApicultor();
                });
              },
              validator: (v) => v == null ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),

            // Interruptor de Pesaje Inteligente
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'REGISTRAR PESOS',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black38),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _lockPesarMode
                            ? 'Fijado por consistencia'
                            : 'Habilita bruto y tara',
                        style: TextStyle(fontSize: 11, color: DesignTokens.primary.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _pesarTambores,
                  onChanged: _lockPesarMode
                      ? null
                      : (val) {
                          setState(() {
                            _pesarTambores = val;
                          });
                        },
                  activeColor: DesignTokens.secondary,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Código SENASA
            TextFormField(
              controller: _senasaController,
              focusNode: _senasaFocusNode,
              textInputAction: _pesarTambores ? TextInputAction.next : TextInputAction.done,
              onFieldSubmitted: (_) {
                if (_pesarTambores) {
                  FocusScope.of(context).requestFocus(_brutoFocusNode);
                } else {
                  _agregarTambor();
                }
              },
              decoration: _inputDecoration(
                'CÓDIGO SENASA',
                Icons.qr_code_rounded,
                suffixIcon: kIsWeb
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.qr_code_scanner_rounded, color: DesignTokens.secondary),
                        onPressed: _scanBarcode,
                        tooltip: 'Escanear Código de Barras',
                      ),
              ),
              keyboardType: TextInputType.text,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requerido';
                final cleaned = v.trim();
                if (cleaned == 'No se lee') return null;
                if (cleaned.length != 11 || double.tryParse(cleaned) == null) {
                  return 'Debe tener 11 dígitos o ser "No se lee"';
                }
                return null;
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _senasaController.text = 'No se lee';
                  });
                },
                icon: const Icon(Icons.blur_on_rounded, size: 16, color: DesignTokens.secondary),
                label: const Text('Marcar como "No se lee"', style: TextStyle(fontSize: 11, color: DesignTokens.secondary, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),

            if (_pesarTambores) ...[
              // Peso Bruto + Tara
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _brutoController,
                      focusNode: _brutoFocusNode,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_taraFocusNode),
                      decoration: _inputDecoration('PESO BRUTO (kg)', Icons.monitor_weight_rounded),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        if (!_pesarTambores) return null;
                        if (v == null || v.trim().isEmpty) return 'Requerido';
                        if (double.tryParse(v) == null) return 'Inválido';
                        if (double.parse(v) <= 0) return 'Debe ser > 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _taraController,
                      focusNode: _taraFocusNode,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _agregarTambor(),
                      decoration: _inputDecoration('TARA (kg)', Icons.scale_rounded),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        if (!_pesarTambores) return null;
                        if (v == null || v.trim().isEmpty) return 'Requerido';
                        if (double.tryParse(v) == null) return 'Inválido';
                        if (double.parse(v) < 0) return 'Debe ser >= 0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Preview del Neto + Botón Agregar
            Row(
              children: [
                if (_pesarTambores) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: DesignTokens.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: DesignTokens.secondary.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('NETO', style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Color(0xFFC68E17))),
                        Text(
                          '${_netoActual.toStringAsFixed(1)} kg',
                          style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w900, fontSize: 18, color: DesignTokens.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _agregarTambor,
                      icon: _isSaving 
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.add_rounded, color: Colors.white),
                      label: Text(_isSaving ? 'AGREGANDO...' : 'AGREGAR', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DesignTokens.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38),
      prefixIcon: Icon(icon, size: 18, color: DesignTokens.primary.withOpacity(0.4)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF7F7F7),
      counterText: '',
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: DesignTokens.secondary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget _buildTamboresHeader() {
    final filteredCount = _tambores.where((t) => _isSameApicId(t['apicultor_id']?.toString(), _selectedApicultorId)).length;
    final String planText = _isTitularResponsable 
        ? 'Planificado: ${_plannedTcmCount.toStringAsFixed(0)} TCM' 
        : 'Planificado: 0 TCM (Tercero)';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_rounded, size: 16, color: DesignTokens.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tambores Registrados', style: DesignTokens.headlineStyle().copyWith(fontSize: 15)),
              const SizedBox(height: 2),
              Text(planText, style: TextStyle(fontSize: 11, color: DesignTokens.primary.withOpacity(0.5), fontWeight: FontWeight.w500)),
            ],
          ),
          const Spacer(),
          Text('$filteredCount TAMBORES', style: DesignTokens.labelStyle().copyWith(fontSize: 9, color: Colors.black38)),
        ],
      ),
    );
  }

  Widget _buildEmptyTambores() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text('Ningún tambor registrado aún.\nCompletá el formulario y presioná AGREGAR.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black38, fontSize: 13)),
      ),
    );
  }

  Widget _buildTabla() {
    final filteredDrums = _tambores.where((t) => _isSameApicId(t['apicultor_id']?.toString(), _selectedApicultorId)).toList();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: Column(
        children: [
          // Header oscuro
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1E302C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                _th('#', 1),
                _th('SENASA / APICULTOR', 4),
                if (_pesarTambores) ...[
                  _th('BRUTO', 2, right: true),
                  _th('TARA', 2, right: true),
                  _th('NETO', 2, right: true),
                ] else ...[
                  _th('DETALLE', 6, right: true),
                ],
                const SizedBox(width: 28), // espacio para botón eliminar
              ],
            ),
          ),
          // Filas
          ...List.generate(filteredDrums.length, (i) {
            final t = filteredDrums[i];
            final originalIndex = _tambores.indexOf(t);
            return _buildFila(i, t, originalIndex);
          }),
        ],
      ),
    );
  }

  Widget _th(String text, int flex, {bool right = false}) {
    return Expanded(
      flex: flex,
      child: Text(text,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: const TextStyle(fontFamily: 'Work Sans', color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  Widget _buildFila(int displayIndex, Map<String, dynamic> t, int originalIndex) {
    final isEven = displayIndex % 2 == 0;
    final neto = t['peso_neto'] as double;
    final bruto = t['peso_bruto'] as double;
    final tara = t['tara'] as double;
    final String apicultorName = _apicultoresMap[t['apicultor_id']?.toString().trim().toLowerCase()]?['nombre'] ?? widget.apicultorNombre;
    final filteredCount = _tambores.where((drum) => _isSameApicId(drum['apicultor_id']?.toString(), _selectedApicultorId)).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: isEven ? const Color(0xFFFAFAFA) : Colors.white,
        border: displayIndex < filteredCount - 1
            ? const Border(bottom: BorderSide(color: Color(0xFFF5F5F5)))
            : null,
        borderRadius: displayIndex == filteredCount - 1
            ? const BorderRadius.vertical(bottom: Radius.circular(16))
            : null,
      ),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text('${displayIndex + 1}', style: const TextStyle(fontSize: 11, color: Colors.black38))),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['senasa_codigo']?.toString() ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF424846)), overflow: TextOverflow.ellipsis),
                Text(
                  apicultorName,
                  style: TextStyle(fontSize: 9, color: DesignTokens.primary.withOpacity(0.5), fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                if (t['guardado'] == true)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                    child: Text('guardado', style: TextStyle(fontSize: 7, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          if (!_pesarTambores) ...[
            const Expanded(
              flex: 6,
              child: Text(
                'Sin pesar',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, color: Colors.black38, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
              ),
            ),
          ] else ...[
            Expanded(flex: 2, child: Text('${bruto.toStringAsFixed(0)} kg', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFF424846)))),
            Expanded(flex: 2, child: Text('${tara.toStringAsFixed(0)} kg', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFF424846)))),
            Expanded(
              flex: 2,
              child: Text(
                '${neto.toStringAsFixed(0)} kg',
                textAlign: TextAlign.right,
                style: const TextStyle(fontFamily: 'Manrope', fontSize: 12, fontWeight: FontWeight.w800, color: DesignTokens.secondary),
              ),
            ),
          ],
          _deletingIndex == originalIndex
              ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                  ),
                )
              : IconButton(
                  icon: Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red.withOpacity(0.4)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => _eliminarTambor(originalIndex),
                ),
        ],
      ),
    );
  }

  Widget _buildTotalesCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [DesignTokens.primary, DesignTokens.primary.withOpacity(0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildTotalItem('BRUTO TOTAL', _totalBruto, Colors.white.withOpacity(0.6)),
          _buildDivider(),
          _buildTotalItem('TARA TOTAL', _totalTara, Colors.white.withOpacity(0.6)),
          _buildDivider(),
          _buildTotalItem('NETO TOTAL', _totalNeto, DesignTokens.secondary),
        ],
      ),
    );
  }

  Widget _buildTotalItem(String label, double value, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.5), letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(
            '${value.toStringAsFixed(0)} kg',
            style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w900, fontSize: 16, color: valueColor),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 32, color: Colors.white.withOpacity(0.15), margin: const EdgeInsets.symmetric(horizontal: 4));
  }

  Widget _buildVolverBtn() {
    return Container(
      width: MediaQuery.of(context).size.width - 40,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _checkDiscrepancyAndPop,
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
        label: const Text(
          'VOLVER A LA PARADA',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: DesignTokens.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: DesignTokens.primary.withOpacity(0.4),
        ),
      ),
    );
  }
}
