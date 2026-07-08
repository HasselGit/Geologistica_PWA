import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import '../components/agregaritem.dart';
import '../backend/design_tokens.dart';
import '../backend/app_states.dart';
import '../backend/supabase_service.dart';
import 'remito_registro.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/geo_sidebar.dart';

class ParadaDetalleWidget extends StatefulWidget {
  const ParadaDetalleWidget({super.key, required this.paradaId});

  final String? paradaId;

  static String routeName = 'ParadaDetalle';
  static String routePath = '/paradaDetalle';

  @override
  State<ParadaDetalleWidget> createState() => _ParadaDetalleWidgetState();
}

class _ParadaDetalleWidgetState extends State<ParadaDetalleWidget> {
  late Future<Map<String, dynamic>?> _paradaFuture;
  final Map<String, TextEditingController> _quantityControllers = {};
  String? _receptorTipo = 'Apicultor'; // 'Apicultor' o 'Tercero'
  final _receptorNombreController = TextEditingController();
  final _receptorDniController = TextEditingController();
  bool _isEditingQuantities = false;
  bool _isFinishing = false;
  String? _userRole;
  String? _userEmail;
  Map<String, dynamic>? _resolvedParada;
  Map<String, String> _apicultoresMap = {};

  bool get _isChofer => _userRole == 'Chofer';
  bool get _isAdmin => _userEmail == 'hassel00@gmail.com' || _userRole == 'Administrador' || _userRole == 'Admin' || Supabase.instance.client.auth.currentUser?.email == 'hassel00@gmail.com';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _paradaFuture = _fetchParadaData();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userRole = prefs.getString('user_puesto');
        _userEmail = prefs.getString('user_email');
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchParadaData() async {
    if (widget.paradaId == null) return null;
    try {
      final client = Supabase.instance.client;

      // Cargar mapa de apicultores
      final apicultoresData = await client
          .from('apicultores')
          .select('id, nombre');
      
      final Map<String, String> apicMap = {
        for (var a in List<Map<String, dynamic>>.from(apicultoresData ?? []))
          a['id'].toString().trim().toLowerCase(): a['nombre'].toString()
      };

      final data = await client
          .from('paradas')
          .select('*, parada_items(*), remitos(*), pesajes(*), viajes(id, vehiculo_codigo, viaje_codigo, estado)')
          .eq('id', widget.paradaId!)
          .maybeSingle();
      
      if (data != null) {
        if (mounted) {
          setState(() {
            _resolvedParada = data;
            _apicultoresMap = apicMap;
          });
        }
        
        final List<Map<String, dynamic>> items = [];
        if (data['parada_items'] is List) {
          for (var it in data['parada_items']) {
            if (it is Map) {
              items.add(Map<String, dynamic>.from(it));
            }
          }
        }
        
        // Corrección de unidades TCM envuelta en try-catch RLS
        try {
          for (var item in items) {
            final String pCode = (item['producto_codigo'] ?? '').toString().trim().toUpperCase();
            if (pCode == 'TCM' || pCode == '1') {
              // 1. Corregir unidad si está mal (kg -> uni)
              final String unitRaw = (item['unidad'] ?? '').toString();
              final String unitBase = unitRaw.contains('|') ? unitRaw.split('|').first : unitRaw;
              if (unitBase.toLowerCase() != 'uni') {
                final String unitOp = unitRaw.contains('|') ? '|${unitRaw.split('|').last}' : '';
                final String newUnit = 'uni$unitOp';
                await client.from('parada_items').update({'unidad': newUnit}).eq('id', item['id']);
                item['unidad'] = newUnit;
              }
            }
          }
        } catch (mutError) {
          print('ParadaDetalle: Error en reconciliación en caliente RLS (omitido): $mutError');
        }
      }
      return data;
    } catch (e) {
      print('ParadaDetalle: Error al cargar datos de la parada: $e');
      return null;
    }
  }

  TextEditingController _getController(String id, String initialValue) {
    if (!_quantityControllers.containsKey(id)) {
      _quantityControllers[id] = TextEditingController(text: initialValue);
    }
    return _quantityControllers[id]!;
  }

  @override
  void dispose() {
    for (var controller in _quantityControllers.values) {
      controller.dispose();
    }
    _receptorNombreController.dispose();
    _receptorDniController.dispose();
    super.dispose();
  }

  Future<void> _updateItemQuantity(String itemId, double qty) async {
    try {
      await Supabase.instance.client.from('parada_items').update({'cantidad': qty}).eq('id', itemId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cantidad actualizada'), duration: Duration(seconds: 1)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteItem(String itemId) async {
    try {
      await SupabaseService().deleteParadaItem(itemId);
      setState(() { _paradaFuture = _fetchParadaData(); });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item eliminado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    dynamic viajesRaw = _resolvedParada != null ? _resolvedParada!['viajes'] : null;
    Map<String, dynamic> viajeAsociado = {};
    if (viajesRaw is Map) {
      viajeAsociado = Map<String, dynamic>.from(viajesRaw);
    } else if (viajesRaw is List && viajesRaw.isNotEmpty) {
      viajeAsociado = Map<String, dynamic>.from(viajesRaw.first);
    }

    final bool isParadaTerminada = _resolvedParada != null && AppStates.normalize(_resolvedParada!['estado']) == AppStates.terminado;
    final bool isViajeTerminado = viajeAsociado.isNotEmpty && AppStates.normalize(viajeAsociado['estado']) == AppStates.terminado;
    final bool isViajePendiente = viajeAsociado.isNotEmpty && AppStates.normalize(viajeAsociado['estado']) == AppStates.pendiente;
    
    final List<dynamic> remitosList = [];
    if (_resolvedParada != null && _resolvedParada!['remitos'] is List) {
      remitosList.addAll(_resolvedParada!['remitos']);
    }
    
    final bool hasNoRemito = remitosList.isEmpty;
    // isReadOnly: solo lectura para todos si el viaje no ha comenzado o si la parada ya terminó (a menos que sea admin)
    final bool isReadOnly = isViajePendiente || (_isAdmin ? false : (!_isChofer || (isParadaTerminada && !hasNoRemito) || isViajeTerminado));
    // canFinalizarParada: el chofer puede finalizar la parada si el viaje está activo y la parada no está terminada
    final bool canFinalizarParada = _isChofer && !isViajePendiente && !isViajeTerminado && !isParadaTerminada;

    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= 900;

      Widget content = SafeArea(
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _paradaFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: DesignTokens.secondary)),
              );
            }
            final p = snapshot.data;
            if (p == null) return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No se encontró la parada')));

            if (isDesktop) {
              return SingleChildScrollView(
                child: _buildWebView(p, isReadOnly, canFinalizarParada, isParadaTerminada, isViajePendiente),
              );
            } else {
              return _buildMobileView(p, isReadOnly, canFinalizarParada, isParadaTerminada, isViajePendiente);
            }
          },
        ),
      );

      if (isDesktop) {
        return Scaffold(
          backgroundColor: DesignTokens.surfaceLow,
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
                  GeoSidebar(
                    userRole: _userRole ?? '',
                    userEmail: _userEmail ?? '',
                    displayName: _userEmail ?? '',
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(120, 0, 40, 0),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.only(top: 24, bottom: 24, left: 16),
                              child: Row(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      if (context.canPop()) {
                                        context.pop();
                                      } else {
                                        context.go('/home');
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.black.withOpacity(0.05)),
                                      ),
                                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: DesignTokens.primary),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Text('Operación en Parada', style: DesignTokens.headlineStyle().copyWith(fontSize: 24)),
                                  const Spacer(),
                                  if (!isReadOnly)
                                    IconButton(
                                      icon: Icon(_isEditingQuantities ? Icons.check_circle_rounded : Icons.edit_note_rounded, color: DesignTokens.primary),
                                      onPressed: () => setState(() => _isEditingQuantities = !_isEditingQuantities),
                                    ),
                                ],
                              ),
                            ),
                            Expanded(child: content),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }

      // Mobile fallback
      return Scaffold(
        backgroundColor: DesignTokens.surface,
        appBar: AppBar(
          backgroundColor: DesignTokens.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Text(
            'Operación en Parada',
            style: DesignTokens.headlineStyle().copyWith(fontSize: 17),
          ),
          leading: Center(
            child: InkWell(
              onTap: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: DesignTokens.primary),
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.home_rounded, color: DesignTokens.primary),
              onPressed: () => context.go('/home'),
            ),
            if (!isReadOnly)
              IconButton(
                icon: Icon(_isEditingQuantities ? Icons.check_circle_rounded : Icons.edit_note_rounded, color: DesignTokens.primary),
                onPressed: () => setState(() => _isEditingQuantities = !_isEditingQuantities),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: DesignTokens.primary.withOpacity(0.08)),
          ),
        ),
        body: content,
      );
    });
  }

  Widget _buildWebView(Map<String, dynamic> p, bool isReadOnly, bool canFinalizarParada, bool isParadaTerminada, bool isViajePendiente) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        children: [
          if (isViajePendiente)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: const Color(0xFFD97706), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Consulta únicamente. El viaje aún no ha comenzado.',
                      style: TextStyle(color: const Color(0xFF92400E), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildWebLeftColumn(p)),
              const SizedBox(width: 24),
              Expanded(flex: 4, child: _buildWebCenterTimeline(p, isReadOnly)),
              const SizedBox(width: 24),
              Expanded(flex: 3, child: _buildWebRightColumn(p, isReadOnly, canFinalizarParada, isParadaTerminada)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebLeftColumn(Map<String, dynamic> p) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FICHA DEL APICULTOR', style: DesignTokens.labelStyle().copyWith(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: DesignTokens.primary.withOpacity(0.1),
                child: const Icon(Icons.person_rounded, color: DesignTokens.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['persona_nombre'] ?? p['ubicacion'] ?? 'Sin Nombre', style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 18, color: DesignTokens.primary)),
                    if (p['persona_dni'] != null) Text('DNI: ${p['persona_dni']}', style: const TextStyle(fontFamily: 'Manrope', fontSize: 13, color: DesignTokens.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.location_on_rounded, 'Ubicación', p['ubicacion'] ?? 'S/D'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.map_rounded, 'Localidad', p['localidad'] ?? 'S/D'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.info_outline_rounded, 'Tipo de Parada', p['tipo'] ?? 'S/D'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.format_list_numbered_rounded, 'Secuencia', '#${p['orden_secuencia'] ?? '?'}'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: DesignTokens.secondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: DesignTokens.onSurfaceVariant, fontFamily: 'Work Sans')),
              Text(value, style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w600, fontSize: 14, color: DesignTokens.onSurface)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWebCenterTimeline(Map<String, dynamic> p, bool isReadOnly) {
    final String pTipo = (p['tipo'] ?? '').toString().trim();
    final bool isRecoleccion = pTipo == 'Recolección' || pTipo == 'Recoleccion';
    final bool hasPesajes = (p['pesajes'] as List? ?? []).isNotEmpty;
    final bool hasTcmItem = (p['parada_items'] as List? ?? []).any((it) => it['producto_codigo'] == 'TCM');
    final bool showPesaje = isRecoleccion || hasPesajes || hasTcmItem;
    
    final remitos = p['remitos'] as List? ?? [];
    final bool hasItems = (p['parada_items'] as List? ?? []).isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ITINERARIO DE PARADA', style: DesignTokens.labelStyle().copyWith(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
          const SizedBox(height: 24),
          _buildTimelineNode(
            'Resumen de Productos',
            _buildItemsSection(isReadOnly),
            isCompleted: hasItems,
            isActive: !hasItems,
            isLast: !showPesaje && remitos.isEmpty,
          ),
          if (showPesaje)
            _buildTimelineNode(
              'Pesaje de Tambores',
              _buildPesajeSection(p, isReadOnly),
              isCompleted: hasPesajes,
              isActive: hasItems && !hasPesajes,
              isLast: remitos.isEmpty,
            ),
          _buildTimelineNode(
            'Remitos Digitales',
            _buildDigitalRemitoForm(p, isReadOnly, isWebTimelineMode: true),
            isCompleted: remitos.isNotEmpty,
            isActive: (showPesaje ? hasPesajes : hasItems) && remitos.isEmpty,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineNode(String title, Widget content, {bool isLast = false, bool isCompleted = false, bool isActive = false}) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _TimelinePainter(isLast: isLast, isCompleted: isCompleted, isActive: isActive),
        child: Padding(
          padding: const EdgeInsets.only(left: 40.0, bottom: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold, fontSize: 16, color: DesignTokens.primary),
              ),
              const SizedBox(height: 16),
              content,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebRightColumn(Map<String, dynamic> p, bool isReadOnly, bool canFinalizarParada, bool isParadaTerminada) {
    double kilosAcumulados = 0;
    int tamboresCount = 0;
    if (p['pesajes'] is List) {
      for (var pe in p['pesajes']) {
        if (pe is Map) {
          final double bruto = (pe['peso_bruto'] as num?)?.toDouble() ?? 0.0;
          final double tara = (pe['tara'] as num?)?.toDouble() ?? 0.0;
          kilosAcumulados += (bruto - tara);
          tamboresCount++;
        }
      }
    }
    final remitos = p['remitos'] as List? ?? [];

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F3622), Color(0xFF1A6B43)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Icon(Icons.scale_rounded, size: 100, color: Colors.white.withOpacity(0.05)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('KILOS ACUMULADOS', style: TextStyle(fontFamily: 'Work Sans', color: DesignTokens.secondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Text(
                    '${kilosAcumulados.toStringAsFixed(1)} kg',
                    style: const TextStyle(fontFamily: 'JetBrains Mono', color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text('En $tamboresCount tambores', style: TextStyle(fontFamily: 'Manrope', color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ACCIONES', style: DesignTokens.labelStyle().copyWith(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
              const SizedBox(height: 16),
              if (!isReadOnly || canFinalizarParada) ...[
                if (!isParadaTerminada)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: !isReadOnly ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RemitoRegistroPage(
                              paradaId: widget.paradaId!,
                              apicultorId: p['apicultor_id'],
                              apicultorNombre: p['persona_nombre'] ?? p['ubicacion'],
                              apicultorDni: p['persona_dni'],
                              tipoOperacion: p['tipo'] ?? 'Recolección',
                            ),
                          ),
                        ).then((success) {
                          if (success == true) {
                            setState(() {
                              _quantityControllers.clear();
                              _receptorNombreController.clear();
                              _receptorDniController.clear();
                              _paradaFuture = _fetchParadaData();
                            });
                          }
                        });
                      } : null,
                      icon: const Icon(Icons.add_task_rounded, color: Colors.white, size: 20),
                      label: const Text('GENERAR REMITO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !isReadOnly ? const Color(0xFF1A6B43) : Colors.grey,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                if (remitos.isNotEmpty && canFinalizarParada) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () async {
                        setState(() => _isFinishing = true);
                        dynamic viajesRaw = p['viajes'];
                        Map<String, dynamic> viajeAsociado = {};
                        if (viajesRaw is Map) {
                          viajeAsociado = Map<String, dynamic>.from(viajesRaw);
                        } else if (viajesRaw is List && viajesRaw.isNotEmpty) {
                          viajeAsociado = Map<String, dynamic>.from(viajesRaw.first);
                        }
                        final String vehiculoCodigo = viajeAsociado['vehiculo_codigo']?.toString() ?? 'CAMION-01';
                        await SupabaseService().finalizarParada(widget.paradaId!, vehiculoCodigo);
                        if (mounted) context.pop();
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: DesignTokens.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('FINALIZAR PARADA', style: TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ] else ...[
                const Text('No hay acciones disponibles para esta parada.', style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileView(Map<String, dynamic> p, bool isReadOnly, bool canFinalizarParada, bool isParadaTerminada, bool isViajePendiente) {
    final String pTipo = (p['tipo'] ?? '').toString().trim();
    final bool isRecoleccion = pTipo == 'Recolección' || pTipo == 'Recoleccion';
    final bool hasPesajes = (p['pesajes'] as List? ?? []).isNotEmpty;
    final bool hasTcmItem = (p['parada_items'] as List? ?? []).any((it) => it['producto_codigo'] == 'TCM');

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isViajePendiente)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: const Color(0xFFD97706), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Consulta únicamente. El viaje aún no ha comenzado.',
                        style: TextStyle(color: const Color(0xFF92400E), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            _buildHeader(p),
            const SizedBox(height: 32),
            _buildItemsSection(isReadOnly),
            if (isRecoleccion || hasPesajes || hasTcmItem) ...[
              const SizedBox(height: 32),
              _buildPesajeSection(p, isReadOnly),
            ],
            const SizedBox(height: 32),
            _buildDigitalRemitoForm(p, isReadOnly, canFinalizarParada: canFinalizarParada, isParadaTerminada: isParadaTerminada),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // ─── SECCIÓN DE PESAJE (solo Recoleccion) ──────────────────────────────────
  Widget _buildPesajeSection(Map<String, dynamic> p, bool isReadOnly) {
    final viajeId = p['viaje_id']?.toString() ?? '';
    final apicultorNombre = p['ubicacion'] ?? p['localidad'] ?? 'S/D';
    final localidad = p['localidad'] ?? 'S/D';
    final apicultorId = p['apicultor_id']?.toString();

    final List<Map<String, dynamic>> pesajes = [];
    if (p['pesajes'] is List) {
      for (var pe in p['pesajes']) {
        if (pe is Map) {
          pesajes.add(Map<String, dynamic>.from(pe));
        }
      }
    }

    final bool isLoteSinPesar = pesajes.isNotEmpty && pesajes.every((pe) => ((pe['peso_bruto'] as num?)?.toDouble() ?? 0.0) == 0.0);

    // Obtener viaje_codigo del viaje asociado
    return FutureBuilder<dynamic>(
      future: viajeId.isNotEmpty
          ? Supabase.instance.client.from('viajes').select('viaje_codigo').eq('id', viajeId).maybeSingle()
          : Future.value(null),
      builder: (context, snap) {
        final data = snap.data as Map<String, dynamic>?;
        final viajeCode = data?['viaje_codigo']?.toString() ?? 'V-S/N';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isLoteSinPesar ? 'REGISTRO DE TAMBORES (TCM) — OPCIONAL' : 'PESAJE DE TAMBORES (TCM) — OPCIONAL', style: DesignTokens.labelStyle().copyWith(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: DesignTokens.secondary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DesignTokens.secondary.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: DesignTokens.secondary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(isLoteSinPesar ? Icons.assignment_turned_in_rounded : Icons.scale_rounded, size: 22, color: DesignTokens.secondary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isLoteSinPesar ? 'Registrar códigos SENASA' : 'Registrar pesos por tambor',
                              style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 15, color: DesignTokens.primary),
                            ),
                            Text(
                              isLoteSinPesar ? 'Escáner de código SENASA • Sin pesar' : 'Escán cod. SENASA • Ingresá Bruto y Tara',
                              style: TextStyle(fontSize: 12, color: DesignTokens.primary.withOpacity(0.45)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  if (pesajes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9), // Premium soft green background
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isLoteSinPesar ? 'Ya existe un registro de ${pesajes.length} TCM' : 'Ya existe un pesaje de ${pesajes.length} TCM',
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: DesignTokens.primary.withOpacity(0.08)),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: pesajes.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: DesignTokens.primary.withOpacity(0.08)),
                        itemBuilder: (ctx, idx) {
                          final pesaje = pesajes[idx];
                          final String senasa = pesaje['senasa_codigo']?.toString() ?? 'S/D';
                          final double bruto = (pesaje['peso_bruto'] as num?)?.toDouble() ?? 0.0;
                          final double tara = (pesaje['tara'] as num?)?.toDouble() ?? 0.0;
                          final double neto = (pesaje['peso_neto'] as num?)?.toDouble() ?? (bruto - tara);
                          final String apicultorId = pesaje['apicultor_id']?.toString() ?? '';
                          final String apicultorName = _apicultoresMap[apicultorId.trim().toLowerCase()] ?? p['ubicacion'] ?? 'S/D';
                          final bool isSinPesar = bruto == 0.0 && tara == 0.0;
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: DesignTokens.primary.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '#${idx + 1}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: DesignTokens.primary),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'SENASA: $senasa',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: DesignTokens.primary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Apicultor: $apicultorName${isSinPesar ? " • Sin pesar" : ""}',
                                        style: TextStyle(fontSize: 11, color: DesignTokens.primary.withOpacity(0.5)),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isSinPesar)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'NETO',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: DesignTokens.secondary, letterSpacing: 0.5),
                                      ),
                                      Text(
                                        '${neto.toStringAsFixed(1)} kg',
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: DesignTokens.primary),
                                      ),
                                    ],
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Sin pesar',
                                      style: TextStyle(fontSize: 11, color: Colors.black38, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  if (!isReadOnly) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push(
                          '/agregarPesaje',
                          extra: {
                            'paradaId': widget.paradaId ?? '',
                            'viajeId': viajeId,
                            'viajeCode': viajeCode,
                            'apicultorNombre': apicultorNombre,
                            'localidad': localidad,
                            if (apicultorId != null) 'apicultorId': apicultorId,
                          },
                        ).then((_) => setState(() {
                          _paradaFuture = _fetchParadaData();
                        })),
                        icon: Icon(
                          pesajes.isNotEmpty ? Icons.edit_rounded : Icons.add_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: Text(
                          pesajes.isEmpty
                              ? 'REGISTRAR TAMBORES / PESAJE'
                              : (isLoteSinPesar ? 'MODIFICAR TAMBORES RECOLECTADOS' : 'MODIFICAR PESAJE DE TAMBORES'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesignTokens.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(Map<String, dynamic> p) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: DesignTokens.secondary, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  'PARADA #${p['orden_secuencia'] ?? '?' }',
                  style: const TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1),
                ),
              ),
              Text(
                (p['tipo'] ?? 'Operación').toString().toUpperCase(),
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(p['ubicacion'] ?? 'Sin Nombre', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on_rounded, size: 14, color: DesignTokens.secondary.withOpacity(0.8)),
              const SizedBox(width: 4),
              Text(p['localidad'] ?? 'Sin Localidad', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(bool isReadOnly) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('RESUMEN DE PRODUCTOS', style: DesignTokens.labelStyle().copyWith(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
            if (!isReadOnly)
              TextButton.icon(
                onPressed: () async {
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) {
                      dynamic viajesRaw = _resolvedParada != null ? _resolvedParada!['viajes'] : null;
                      Map<String, dynamic> viajeAsociado = {};
                      if (viajesRaw is Map) {
                        viajeAsociado = Map<String, dynamic>.from(viajesRaw);
                      } else if (viajesRaw is List && viajesRaw.isNotEmpty) {
                        viajeAsociado = Map<String, dynamic>.from(viajesRaw.first);
                      }
                      final vId = viajeAsociado['id']?.toString() ?? '';
                      return AgregarItemWidget(paradaId: widget.paradaId!, viajeId: vId);
                    },
                  );
                  setState(() {
                    _paradaFuture = _fetchParadaData();
                  });
                },
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text('Agregar'),
                style: TextButton.styleFrom(foregroundColor: DesignTokens.primary),
              ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: Supabase.instance.client.from('parada_items').stream(primaryKey: ['id']).eq('parada_id', widget.paradaId!).order('id'),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final items = snapshot.data!;
            if (items.isEmpty) return _buildEmptyItems();
            
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                return _buildItemCard(item, isReadOnly);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyItems() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, color: DesignTokens.primary.withOpacity(0.2), size: 40),
          const SizedBox(height: 12),
          const Text('No hay productos registrados', style: TextStyle(color: DesignTokens.onSurfaceVariant, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, bool isReadOnly) {
    final String unitRaw = (item['unidad'] ?? 'uni').toString();
    final parts = unitRaw.split('|');
    final String unitBase = parts.first;
    final String opType = parts.length > 1 ? parts[1] : 'Recolección';

    final bool isRecoleccion = opType == 'Recolección';
    final Color badgeBg = isRecoleccion ? const Color(0xFFFEF3C7) : const Color(0xFFDBEAFE); // Soft Amber vs Soft Blue
    final Color badgeTextColor = isRecoleccion ? const Color(0xFFD97706) : const Color(0xFF2563EB); // Amber 600 vs Blue 600
    final IconData badgeIcon = isRecoleccion ? Icons.upload_rounded : Icons.download_rounded;
    final String badgeLabel = isRecoleccion ? 'RETIRO' : 'ENTREGA';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isRecoleccion ? const Color(0xFFFFFBEB) : const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(12)
            ),
            child: Icon(
              isRecoleccion ? Icons.upload_rounded : Icons.download_rounded,
              color: isRecoleccion ? const Color(0xFFD97706) : const Color(0xFF2563EB),
              size: 20
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item['producto_codigo'] ?? 'Producto',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: DesignTokens.primary),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 10, color: badgeTextColor),
                          const SizedBox(width: 3),
                          Text(
                            badgeLabel,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: badgeTextColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  unitBase,
                  style: const TextStyle(fontSize: 12, color: DesignTokens.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (!isReadOnly && _isEditingQuantities) ...[
            SizedBox(
              width: 70,
              child: TextField(
                controller: _getController(item['id'].toString(), item['cantidad'].toString()),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  isDense: true, 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                onSubmitted: (val) {
                  final qty = double.tryParse(val);
                  if (qty != null) _updateItemQuantity(item['id'], qty);
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: DesignTokens.error, size: 20),
              onPressed: () => _deleteItem(item['id']),
            ),
          ] else
            Text(
              item['cantidad'].toString(),
              style: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 18, color: DesignTokens.primary),
            ),
        ],
      ),
    );
  }

  Widget _buildDigitalRemitoForm(Map<String, dynamic> p, bool isReadOnly, {bool canFinalizarParada = false, bool isParadaTerminada = false, bool isWebTimelineMode = false}) {
    final remitos = p['remitos'] as List? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('REMITOS DE ESTA PARADA', style: DesignTokens.labelStyle().copyWith(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
            if (remitos.isNotEmpty)
              const Icon(Icons.check_circle_rounded, color: DesignTokens.success, size: 20),
          ],
        ),
        const SizedBox(height: 12),
        if (remitos.isEmpty)
          const Text('No hay remitos generados para esta parada.', style: TextStyle(fontSize: 13, color: Colors.grey))
        else
          ...remitos.map((r) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.description_rounded, color: DesignTokens.primary),
              title: Text('Remito #${r['id'].toString().substring(0, 6).toUpperCase()}'),
              subtitle: Text('Fecha: ${r['fecha'] != null ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(r['fecha'])) : 'S/D'} | Tipo: ${r['tipo'] ?? 'S/D'}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chevron_right_rounded),
                  // Botón eliminar remito: solo visible para admin
                  if (_isAdmin)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: DesignTokens.error, size: 20),
                      tooltip: 'Eliminar remito (Admin)',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Eliminar Remito'),
                            content: const Text('¿Confirma eliminar este remito? La parada volverá a estar editable para regenerarlo.'),
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
                        if (confirm == true && mounted) {
                          try {
                            await SupabaseService().deleteRemito(r['id'].toString(), widget.paradaId!);
                            setState(() { _paradaFuture = _fetchParadaData(); });
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Remito eliminado. La parada está editable nuevamente.'), backgroundColor: Colors.orange),
                            );
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                    ),
                ],
              ),
              onTap: () {
                final url = r['pdf_url'];
                if (url != null && url.isNotEmpty) {
                  _showPdfPreviewDialog(context, url, 'Remito - ${p['persona_nombre'] ?? 'Parada'}');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Este remito no tiene un PDF asociado')),
                  );
                }
              },
            ),
          )),
        // Botones de acción: si la parada no es solo lectura O si el chofer puede finalizar
        if (!isWebTimelineMode && (!isReadOnly || canFinalizarParada)) ...[
          const SizedBox(height: 24),
          if (!isParadaTerminada) // Botón GENERAR NUEVO REMITO solo si la parada no está terminada
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: !isReadOnly ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RemitoRegistroPage(
                      paradaId: widget.paradaId!,
                      apicultorId: p['apicultor_id'],
                      apicultorNombre: p['persona_nombre'] ?? p['ubicacion'],
                      apicultorDni: p['persona_dni'],
                      tipoOperacion: p['tipo'] ?? 'Recolección',
                    ),
                  ),
                ).then((success) {
                  if (success == true) {
                    setState(() {
                      _quantityControllers.clear();
                      _receptorNombreController.clear();
                      _receptorDniController.clear();
                      _paradaFuture = _fetchParadaData();
                    });
                  }
                });
              } : null,
              icon: const Icon(Icons.add_task_rounded, color: Colors.white),
              label: const Text('GENERAR NUEVO REMITO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: !isReadOnly ? const Color(0xFF1A6B43) : Colors.grey,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (remitos.isNotEmpty && canFinalizarParada) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () async {
                  setState(() => _isFinishing = true);
                  dynamic viajesRaw = p['viajes'];
                  Map<String, dynamic> viajeAsociado = {};
                  if (viajesRaw is Map) {
                    viajeAsociado = Map<String, dynamic>.from(viajesRaw);
                  } else if (viajesRaw is List && viajesRaw.isNotEmpty) {
                    viajeAsociado = Map<String, dynamic>.from(viajesRaw.first);
                  }
                  final String vehiculoCodigo = viajeAsociado['vehiculo_codigo']?.toString() ?? 'CAMION-01';
                  await SupabaseService().finalizarParada(widget.paradaId!, vehiculoCodigo);
                  if (mounted) context.pop();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: DesignTokens.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('FINALIZAR PARADA COMPLETA', style: TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Future<Uint8List> _downloadPdf(String url) async {
    try {
      // 1. Try public fetch
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return res.bodyBytes;
      }
    } catch (_) {}
    
    // 2. Fallback to Supabase Storage direct download
    try {
      final fileName = url.split('/').last;
      final bytes = await Supabase.instance.client.storage.from('remitos').download(fileName);
      return bytes;
    } catch (e) {
      print('Error downloading PDF from Storage: $e');
      rethrow;
    }
  }

  void _showPdfPreviewDialog(BuildContext context, String url, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Scaffold(
        appBar: AppBar(
          backgroundColor: DesignTokens.primary,
          elevation: 0,
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(ctx),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white),
              tooltip: 'Abrir en Navegador',
              onPressed: () async {
                try {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
                  }
                } catch (e) {
                  print('Error al abrir PDF externo: $e');
                }
              },
            ),
          ],
        ),
        body: FutureBuilder<Uint8List>(
          future: _downloadPdf(url),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: DesignTokens.secondary));
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: DesignTokens.error, size: 48),
                      const SizedBox(height: 16),
                      Text('Error al cargar vista previa del PDF: ${snapshot.error}', textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.open_in_browser_rounded),
                        label: const Text('ABRIR EN NAVEGADOR'),
                        style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.primary),
                        onPressed: () async {
                          try {
                            final uri = Uri.parse(url);
                            await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
                          } catch (_) {}
                        },
                      ),
                    ],
                  ),
                ),
              );
            }
            try {
              return PdfPreview(
                build: (format) => snapshot.data!,
                allowPrinting: true,
                allowSharing: true,
                canChangePageFormat: false,
                dynamicLayout: false,
              );
            } catch (previewErr) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded, color: DesignTokens.primary, size: 48),
                      const SizedBox(height: 16),
                      const Text('El plugin de vista previa no es compatible con este dispositivo.', textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.open_in_browser_rounded),
                        label: const Text('ABRIR CON VISOR NATIVO'),
                        style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.primary),
                        onPressed: () async {
                          try {
                            final uri = Uri.parse(url);
                            await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
                          } catch (_) {}
                        },
                      ),
                    ],
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final bool isLast;
  final bool isCompleted;
  final bool isActive;

  _TimelinePainter({required this.isLast, required this.isCompleted, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = isCompleted ? DesignTokens.primary.withOpacity(0.4) : const Color(0xFFE2E8F0)
      ..strokeWidth = 1.5;
    
    if (!isLast) {
      // Draw line from below the circle to the bottom of the widget
      canvas.drawLine(const Offset(12, 24), Offset(12, size.height), paintLine);
    }

    final paintDot = Paint()
      ..color = isCompleted ? DesignTokens.primary : (isActive ? DesignTokens.secondary : const Color(0xFFE2E8F0))
      ..style = isCompleted || isActive ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 2;
      
    // Circle size is smaller and hollow if not active/completed
    canvas.drawCircle(const Offset(12, 12), 6, paintDot);
    
    if (isCompleted) {
      final whitePaint = Paint()..color = Colors.white;
      canvas.drawCircle(const Offset(12, 12), 2, whitePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) {
    return oldDelegate.isLast != isLast || oldDelegate.isCompleted != isCompleted || oldDelegate.isActive != isActive;
  }
}
