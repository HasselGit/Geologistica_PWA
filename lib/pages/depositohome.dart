import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import '../backend/supabase_service.dart';
import '../backend/app_states.dart';
import '../backend/design_tokens.dart';

class DepositohomeWidget extends StatefulWidget {
  final String? initialTab;
  const DepositohomeWidget({super.key, this.initialTab});

  @override
  State<DepositohomeWidget> createState() => _DepositohomeWidgetState();
}

class _DepositohomeWidgetState extends State<DepositohomeWidget> with SingleTickerProviderStateMixin {
  Set<String> _selectedItems = {};
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _unfocusNode = FocusNode();
  late TabController _tabController;
  List<Map<String, dynamic>> _viajesPlanificados = [];
  List<Map<String, dynamic>> _cargasTerminadas = [];
  List<Map<String, dynamic>> _filteredHistory = [];
  List<Map<String, dynamic>> _productos = [];
  bool _loading = true;
  String _searchQuery = '';
  DateTime? _selectedDate;
  // Rol del usuario en sesión
  bool _isChofer = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    int initIdx = 0;
    if (widget.initialTab != null) {
      if (widget.initialTab == '1') initIdx = 1;
      else if (widget.initialTab == '2') initIdx = 2;
    }
    _tabController = TabController(length: 3, vsync: this, initialIndex: initIdx);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      // Se removió el signOut() que deslogueaba al usuario y rompía las demás pantallas.

      // Obtener viajes con cargas activas (Pendiente, En Proceso, En Curso)
      final prefs = await SharedPreferences.getInstance();
      final userRole = (prefs.getString('user_puesto') ?? '').toLowerCase();
      final userEmail = (prefs.getString('user_email') ?? '').toLowerCase();
      final isChofer = userRole.contains('chofer') || userEmail.contains('mperez') || userEmail.contains('cmuse') || userEmail.contains('agomez') || userEmail.contains('efernandez');
      final isDeposito = userRole.contains('deposito') || userEmail.contains('cmerlo') || userEmail.contains('csantana');
      final onlyChofer = isChofer && !isDeposito;
      final currentUserId = prefs.getString('user_id') ?? '';

      // Obtener viajes con cargas activas (Pendiente, En Proceso, En Curso)
      final pendingViajesRaw = await Supabase.instance.client
          .from('viajes')
          .select('*, paradas(*, parada_items(*)), vehiculos:vehiculo_codigo(capacidad_kg, capacidad_tambores), cargas(id, carga_codigo, estado, carga_items(*))')
          .or('estado.eq.Pendiente,estado.eq.En Proceso,estado.eq.En Curso')
          .order('fecha', ascending: true);

      final List<dynamic> voyagesFiltered = [];
      for (var v in (pendingViajesRaw as List)) {
        if (!onlyChofer || (v['chofer_id']?.toString() == currentUserId)) {
          voyagesFiltered.add(v);
        }
      }

      // Deep copy mutable para permitir la inyección de ítems si el RLS anidado falla
      final List<Map<String, dynamic>> rawList = voyagesFiltered.map((v) {
        final Map<String, dynamic> vMap = Map<String, dynamic>.from(v as Map);
        if (vMap['cargas'] != null) {
          vMap['cargas'] = (vMap['cargas'] as List).map((c) {
            final Map<String, dynamic> cMap = Map<String, dynamic>.from(c as Map);
            // Aplicar enriquecimiento manual de cargas para separar carga_codigo y deposito_origen
            final String rawCode = (cMap['carga_codigo'] ?? '').toString();
            if (rawCode.contains(' | ')) {
              final parts = rawCode.split(' | ');
              cMap['carga_codigo'] = parts.first;
              cMap['deposito_origen'] = parts.length > 1 ? parts[1] : 'Parque Industrial';
            } else {
              cMap['deposito_origen'] = 'Parque Industrial';
            }
            return cMap;
          }).toList();
        }
        return vMap;
      }).toList();

      final List<Map<String, dynamic>> pendingViajes = [];

      for (var v in rawList) {
        if (v['chofer_id'] != null) {
          try {
            final chofer = await Supabase.instance.client
                .from('profiles')
                .select('nombre, apellido')
                .eq('id', v['chofer_id'])
                .maybeSingle();
            v['profiles'] = chofer;
          } catch (_) {}
        }
        
        var listCargas = v['cargas'] as List? ?? [];
        
        if (onlyChofer) {
          // Eliminamos el filtrado por deposito_origen porque la columna ya no existe en BD
          // listCargas = listCargas.where((c) => c['deposito_origen'] == 'Depósito Huinca').toList();
          v['cargas'] = listCargas;
        }

        // Fallback directo si carga_items viene vacío por RLS stale
        for (var c in listCargas) {
          final items = c['carga_items'] as List? ?? [];
          if (items.isEmpty) {
            try {
              final directItems = await Supabase.instance.client
                  .from('carga_items')
                  .select('*')
                  .eq('carga_id', c['id']);
              c['carga_items'] = directItems;
            } catch (fallbackErr) {
              print('DepositoHome: Error en fallback directo carga_items para ${c['id']}: $fallbackErr');
            }
          }
        }

        if (listCargas.isNotEmpty) {
          pendingViajes.add(v);
        } else {
          // If the viaje has no cargas, only show to Deposito, not to Chofer
          if (!onlyChofer) {
            pendingViajes.add(v);
          }
        }
      }

      // Obtener cargas terminadas para la segunda pestaña
      var history = await SupabaseService().getTerminatedCargas();
      if (onlyChofer) {
        history = history.where((c) => c['viaje']?['chofer_id']?.toString() == currentUserId).toList();
      }

      // Obtener productos disponibles
      final prods = await SupabaseService().getProductos();

      if (mounted) {
        setState(() {
          _viajesPlanificados = pendingViajes;
          _cargasTerminadas = history;
          _productos = List<Map<String, dynamic>>.from(prods);
          _isChofer = onlyChofer;
          _currentUserId = currentUserId;
          _applyFilters();
          _loading = false;
        });
      }
    } catch (e, stack) {
      print('DepositoHome: Error fetching data: $e');
      print(stack);
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredHistory = _cargasTerminadas.where((c) {
        final query = _searchQuery.toLowerCase();
        
        // 1. Numero de carga y numero de viaje
        final cargaCode = (c['carga_codigo'] ?? '').toString().toLowerCase();
        final viajeCode = (c['viaje']?['viaje_codigo'] ?? '').toString().toLowerCase();
        
        // 2. Vehiculo
        final vehiculo = (c['viaje']?['vehiculo_codigo'] ?? '').toString().toLowerCase();
        
        // 3. Numero de remito: Ej. PI-1 if carga_codigo is Carga-1 (we replace "carga-" with "pi-")
        final remitoCode = cargaCode.replaceAll('carga-', 'pi-');
        
        // 4. Depósito
        final deposito = (c['deposito_origen'] ?? '').toString().toLowerCase();
        
        // 5. Chofer
        final choferNombre = (c['viaje']?['profiles']?['nombre'] ?? '').toString().toLowerCase();
        final choferApellido = (c['viaje']?['profiles']?['apellido'] ?? '').toString().toLowerCase();
        final choferFull = '$choferNombre $choferApellido'.trim();
        
        // 6. Productos
        bool productMatch = false;
        final items = c['carga_items'] as List? ?? [];
        for (var item in items) {
          final prodCode = (item['producto_codigo'] ?? '').toString().toLowerCase();
          if (prodCode.contains(query)) {
            productMatch = true;
            break;
          }
        }
        
        final matchesSearch = cargaCode.contains(query) ||
                              viajeCode.contains(query) ||
                              vehiculo.contains(query) ||
                              remitoCode.contains(query) ||
                              deposito.contains(query) ||
                              choferFull.contains(query) ||
                              productMatch;
        
        bool dateMatch = true;
        if (_selectedDate != null) {
          final updated = DateTime.tryParse(c['updated_at'] ?? '');
          dateMatch = updated != null && 
                      updated.year == _selectedDate!.year && 
                      updated.month == _selectedDate!.month && 
                      updated.day == _selectedDate!.day;
        }
        return matchesSearch && dateMatch;
      }).toList();
    });
  }

  // ─── Calcular métricas de un viaje ──────────────────────────────────────────

  Map<String, dynamic> _calcCardMetrics(Map<String, dynamic> item) {
    double totalKg = 0;
    int totalTambores = 0;
    final Map<String, double> aggregatedItems = {};

    final type = item['type'] as String;
    final Map<String, dynamic> viaje = item['viaje'];
    final Map<String, dynamic>? carga = item['carga'];

    // Obtener peso unitario del catálogo dinámicamente
    double getProductWeight(String code) {
      final p = _productos.firstWhere(
        (prod) => prod['codigo']?.toString().toUpperCase() == code.toUpperCase(),
        orElse: () => {},
      );
      if (p.isNotEmpty && p['peso_unit_kg'] != null) {
        return (p['peso_unit_kg'] as num).toDouble();
      }
      // Fallbacks estándar
      if (code == 'TCM' || code.contains('TAMBOR')) return 300.0;
      if ((code.startsWith('T') && code != 'TV' && code != 'TE') || code.contains('VACIO') || code.contains('VACÍO')) return 20.0;
      if (code == 'AZ') return 50.0;
      return 1.0;
    }

    if (type == 'carga_activa' && carga != null) {
      // 1. Carga Inicial en Depósito
      final items = carga['carga_items'] as List? ?? [];
      for (var item in items) {
        final double cant = (item['cantidad'] ?? 0).toDouble();
        final String prod = (item['producto_codigo'] ?? '').toString().toUpperCase();
        if (prod.isNotEmpty) {
          aggregatedItems[prod] = (aggregatedItems[prod] ?? 0) + cant;
        }
        final double factor = getProductWeight(prod);
        totalKg += cant * factor;
        
        if (prod == 'TCM' || prod.contains('TAMBOR')) {
          totalTambores += cant.toInt();
        } else if ((prod.startsWith('T') && prod != 'TV' && prod != 'TE') || prod.contains('VACIO') || prod.contains('VACÍO')) {
          totalTambores += cant.toInt();
        }
      }

      // 2. Ajuste dinámico por paradas finalizadas (restar entregas, sumar recolecciones)
      final paradas = viaje['paradas'] as List? ?? [];
      for (var p in paradas) {
        if (p['estado'] == 'Terminado') {
          final String paradaTipo = p['tipo'] ?? '';
          final items = p['parada_items'] as List? ?? [];
          for (var item in items) {
            final double cant = (item['cantidad'] ?? 0).toDouble();
            final String prod = (item['producto_codigo'] ?? '').toString().toUpperCase();
            final double factor = getProductWeight(prod);
            final double itemWeight = cant * factor;

            if (paradaTipo == 'Distribución') {
              totalKg -= itemWeight;
              if (prod.isNotEmpty) {
                aggregatedItems[prod] = (aggregatedItems[prod] ?? 0) - cant;
                if (aggregatedItems[prod]! <= 0) aggregatedItems.remove(prod);
              }
              if (prod == 'TCM' || prod.contains('TAMBOR')) {
                totalTambores -= cant.toInt();
              } else if ((prod.startsWith('T') && prod != 'TV' && prod != 'TE') || prod.contains('VACIO') || prod.contains('VACÍO')) {
                totalTambores -= cant.toInt();
              }
            } else if (paradaTipo == 'Recolección') {
              totalKg += itemWeight;
              if (prod.isNotEmpty) {
                aggregatedItems[prod] = (aggregatedItems[prod] ?? 0) + cant;
              }
              if (prod == 'TCM' || prod.contains('TAMBOR')) {
                totalTambores += cant.toInt();
              } else if ((prod.startsWith('T') && prod != 'TV' && prod != 'TE') || prod.contains('VACIO') || prod.contains('VACÍO')) {
                totalTambores += cant.toInt();
              }
            }
          }
        }
      }
    } else {
      // Fallback a paradas planificadas para viaje_sin_carga
      for (var p in (viaje['paradas'] as List? ?? [])) {
        for (var item in (p['parada_items'] as List? ?? [])) {
          final double cant = (item['cantidad'] ?? 0).toDouble();
          final String prod = (item['producto_codigo'] ?? '').toString().toUpperCase();
          if (prod.isNotEmpty) {
            aggregatedItems[prod] = (aggregatedItems[prod] ?? 0) + cant;
          }
          final double factor = getProductWeight(prod);
          totalKg += cant * factor;
          
          if (prod == 'TCM' || prod.contains('TAMBOR')) {
            totalTambores += cant.toInt();
          } else if ((prod.startsWith('T') && prod != 'TV' && prod != 'TE') || prod.contains('VACIO') || prod.contains('VACÍO')) {
            totalTambores += cant.toInt();
          }
        }
      }
    }

    return {
      'totalKg': totalKg.clamp(0.0, double.infinity),
      'totalTambores': totalTambores.clamp(0, 9999),
      'aggregatedItems': aggregatedItems,
    };
  }

  // ─── Acciones ───────────────────────────────────────────────────────────────

  Future<void> _iniciarCarga(Map<String, dynamic> viaje, Map<String, dynamic> carga) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Iniciar Carga', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('¿Iniciar la carga ${carga['carga_codigo']} del viaje ${viaje['viaje_codigo']}?\nEsto indica que el depósito está cargando el camión.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
            child: const Text('INICIAR', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await SupabaseService().iniciarCarga(carga['id'].toString());
        await _fetchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Carga iniciada — en proceso de carga'), backgroundColor: Color(0xFF1565C0)),
          );
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _finalizarCarga(Map<String, dynamic> viaje, Map<String, dynamic> carga) async {
    final SignatureController signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    final bool? confirm = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Finalizar Carga', style: DesignTokens.headlineStyle(color: DesignTokens.primary).copyWith(fontSize: 20)),
              Text('Firma del chofer para ${carga['carga_codigo']}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: DesignTokens.primary.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Signature(
                    controller: signatureController,
                    height: 200,
                    backgroundColor: Colors.grey.shade50,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Limpiar'),
                    onPressed: () => signatureController.clear(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        signatureController.dispose();
                        Navigator.pop(ctx, false);
                      },
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('CANCELAR'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DesignTokens.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('FINALIZAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      if (signatureController.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debe proporcionar la firma del chofer')));
        signatureController.dispose();
        return;
      }

      setState(() => _loading = true);
      try {
        final signatureBytes = await signatureController.toPngBytes();
        if (signatureBytes == null) throw Exception('Error al capturar la firma');
        
        final signatureFileName = 'firma_carga_${carga['id']}_${DateTime.now().millisecondsSinceEpoch}.png';
        await Supabase.instance.client.storage
            .from('remitos')
            .uploadBinary(
              signatureFileName,
              signatureBytes,
              fileOptions: const FileOptions(contentType: 'image/png'),
            );
        final firmaUrl = Supabase.instance.client.storage.from('remitos').getPublicUrl(signatureFileName);

        await Supabase.instance.client.from('cargas').update({
          'estado': AppStates.terminado,
          'chofer_firma_url': firmaUrl,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', carga['id']);

        await _fetchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Carga finalizada correctamente'), backgroundColor: Colors.green),
          );
          _tabController.animateTo(2); // Ir a la pestaña terminadas
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
          setState(() => _loading = false);
        }
      }
    }
    signatureController.dispose();
  }

  // ─── Diálogo de edición de carga ────────────────────────────────────────────

  Future<void> _showEditCargaDialog(Map<String, dynamic> viaje, Map<String, dynamic> carga) async {
    final cargaId = carga['id'].toString();
    // Copia mutable de los ítems
    final List<Map<String, dynamic>> currentItems = List<Map<String, dynamic>>.from(
      (carga['carga_items'] as List? ?? []).map((item) => Map<String, dynamic>.from(item)),
    );

    // ── Controladores creados FUERA del builder para persistir entre rebuilds ──
    final List<TextEditingController> itemControllers = currentItems
        .map((item) => TextEditingController(
            text: '${(item['cantidad'] ?? 0).toDouble().toStringAsFixed(0)}'))
        .toList();

    String? selectedProductoCodigo;
    final qtyController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Cabecera ──────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Editar Carga', style: DesignTokens.headlineStyle(color: DesignTokens.primary).copyWith(fontSize: 20)),
                            Text('Carga: ${carga['carga_codigo'] ?? ''} • Viaje: ${viaje['viaje_codigo'] ?? ''}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Lista de ítems actuales ───────────────────────────────
                  if (currentItems.isNotEmpty) ...[
                    const Text('ÍTEMS DE LA CARGA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey, letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: currentItems.length,
                      itemBuilder: (_, idx) {
                        final item = currentItems[idx];
                        // Usar el controller persistente para este índice
                        final ctrl = (idx < itemControllers.length) ? itemControllers[idx] : TextEditingController();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: DesignTokens.primary.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: DesignTokens.primary.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                               Expanded(
                                flex: 3,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: DesignTokens.primary.withOpacity(0.12)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _productos.any((p) => p['codigo']?.toString() == item['producto_codigo']?.toString())
                                          ? item['producto_codigo']?.toString()
                                          : null,
                                      hint: const Text('Prod.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      isExpanded: true,
                                      style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: DesignTokens.primary, fontSize: 13),
                                      icon: const Icon(Icons.arrow_drop_down, size: 18, color: DesignTokens.primary),
                                      items: _productos.map((p) {
                                        final code = p['codigo']?.toString() ?? '';
                                        return DropdownMenuItem<String>(
                                          value: code,
                                          child: Text(code, overflow: TextOverflow.ellipsis),
                                        );
                                      }).toList(),
                                      onChanged: (v) {
                                        if (v != null) {
                                          setModalState(() {
                                            item['producto_codigo'] = v;
                                            final catalogProd = _productos.firstWhere((p) => p['codigo']?.toString() == v, orElse: () => {});
                                            if (catalogProd.isNotEmpty) {
                                              item['unidad'] = catalogProd['unidad'] ?? 'UN';
                                            }
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 70,
                                child: TextField(
                                  controller: ctrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    border: OutlineInputBorder(),
                                    labelText: 'Cant.',
                                  ),
                                  onChanged: (v) {
                                    final parsed = double.tryParse(v);
                                    if (parsed != null) {
                                      currentItems[idx]['cantidad'] = parsed;
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(item['unidad']?.toString() ?? 'UN', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    currentItems.removeAt(idx);
                                    if (idx < itemControllers.length) {
                                      itemControllers.removeAt(idx).dispose();
                                    }
                                  });
                                },
                                child: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('AGREGAR PRODUCTO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey, letterSpacing: 0.5)),
                  const SizedBox(height: 10),

                  // ── Selector de producto ──────────────────────────────────
                  DropdownButtonFormField<String>(
                    value: selectedProductoCodigo,
                    isExpanded: true,   // ← Fix overflow
                    decoration: const InputDecoration(
                      labelText: 'Producto',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: _productos.map((p) => DropdownMenuItem<String>(
                      value: p['codigo']?.toString(),
                      child: Text(
                        p['descripcion'] ?? 'S/N',
                        overflow: TextOverflow.ellipsis,
                      ),
                    )).toList(),
                    onChanged: (v) => setModalState(() => selectedProductoCodigo = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Cantidad',
                      prefixIcon: Icon(Icons.numbers_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (selectedProductoCodigo == null || qtyController.text.isEmpty) return;
                        final prod = _productos.firstWhere((p) => p['codigo']?.toString() == selectedProductoCodigo, orElse: () => {});
                        final qty = double.tryParse(qtyController.text) ?? 0;
                        if (qty <= 0) return;
                        setModalState(() {
                          final existing = currentItems.firstWhere(
                            (i) => i['producto_codigo']?.toString() == selectedProductoCodigo,
                            orElse: () => {},
                          );
                          if (existing.isNotEmpty) {
                            existing['cantidad'] = (existing['cantidad'] as num).toDouble() + qty;
                            // Actualizar el controller del item existente
                            final existIdx = currentItems.indexOf(existing);
                            if (existIdx < itemControllers.length) {
                              itemControllers[existIdx].text = existing['cantidad'].toStringAsFixed(0);
                            }
                          } else {
                            currentItems.add({
                              'producto_codigo': selectedProductoCodigo,
                              'cantidad': qty,
                              'unidad': prod['unidad'] ?? 'UN',
                            });
                            itemControllers.add(TextEditingController(text: qty.toStringAsFixed(0)));
                          }
                          selectedProductoCodigo = null;
                          qtyController.clear();
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('AGREGAR A LA LISTA'),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Botón guardar ─────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Sincronizar cantidades de los controllers antes de guardar
                        for (int i = 0; i < currentItems.length; i++) {
                          if (i < itemControllers.length) {
                            final parsed = double.tryParse(itemControllers[i].text);
                            if (parsed != null) currentItems[i]['cantidad'] = parsed;
                          }
                        }
                        try {
                          await SupabaseService().updateCargaItems(cargaId, currentItems);
                          // Dispose controllers
                          for (final c in itemControllers) { c.dispose(); }
                          qtyController.dispose();
                          if (ctx.mounted) Navigator.pop(ctx);
                          _fetchData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Carga actualizada correctamente'), backgroundColor: Colors.green),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            showDialog(
                              context: ctx,
                              builder: (_) => AlertDialog(
                                title: const Text('Error al guardar'),
                                content: Text(e.toString()),
                                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                              ),
                            );
                          }
                        }
                      },
                      style: DesignTokens.primaryButtonStyle,
                      icon: const Icon(Icons.save_rounded, color: DesignTokens.accent),
                      label: const Text('GUARDAR CAMBIOS'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  // ─── Build Web DataTable ────────────────────────────────────────────────────
  Widget _buildWebDataTable(int tabIndex) {
    List<Map<String, dynamic>> tableItems = [];
    if (tabIndex == 0) {
      tableItems = _getActiveItems().where((item) {
        if (item['type'] == 'viaje_sin_carga') return true;
        final c = item['carga'];
        return c != null && c['estado'] == AppStates.pendiente;
      }).toList();
    } else if (tabIndex == 1) {
      tableItems = _getActiveItems().where((item) {
        if (item['type'] == 'viaje_sin_carga') return false;
        final c = item['carga'];
        return c != null && c['estado'] == AppStates.enCurso;
      }).toList();
    } else {
      tableItems = _filteredHistory.map((c) => {
        'type': 'carga_terminada',
        'viaje': c['viaje'] ?? {},
        'carga': c,
      }).toList();
    }

    if (tableItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.table_chart_outlined, size: 48, color: const Color(0xFF08201A).withOpacity(0.1)),
            const SizedBox(height: 16),
            const Text('No hay datos en esta sección.', style: TextStyle(color: Colors.grey, fontFamily: 'Inter')),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(const Color(0xFF08201A).withOpacity(0.04)),
          dataRowMinHeight: 60,
          dataRowMaxHeight: 70,
          columns: const [
            DataColumn(label: Text('Viaje/Carga', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF08201A), fontFamily: 'Manrope'))),
            DataColumn(label: Text('Chofer', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF08201A), fontFamily: 'Manrope'))),
            DataColumn(label: Text('Vehículo', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF08201A), fontFamily: 'Manrope'))),
            DataColumn(label: Text('Kg', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF08201A), fontFamily: 'Manrope'))),
            DataColumn(label: Text('Tambores', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF08201A), fontFamily: 'Manrope'))),
            DataColumn(label: Text('Acción', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF08201A), fontFamily: 'Manrope'))),
          ],
          rows: tableItems.map((item) {
            final type = item['type'] as String;
            final v = item['viaje'] ?? {};
            final c = item['carga'];
            final chofer = v['profiles'] ?? {};
            
            double totalKg = 0;
            int totalTambores = 0;
            if (type == 'carga_terminada') {
               final items = c?['carga_items'] as List? ?? [];
               for (var it in items) {
                  final double cant = (it['cantidad'] ?? 0).toDouble();
                  totalKg += cant * 300.0;
                  final String prodCode = (it['producto_codigo'] ?? '').toString().toUpperCase();
                  if (prodCode == 'TCM' || prodCode.contains('TAMBOR') || prodCode.startsWith('T')) {
                     if (prodCode != 'TV' && prodCode != 'TE') totalTambores += cant.toInt();
                  }
               }
            } else {
               final metrics = _calcCardMetrics(item);
               totalKg = metrics['totalKg'] as double;
               totalTambores = metrics['totalTambores'] as int;
            }

            final itemKey = (v['viaje_codigo'] ?? 'SC') + '_' + (c?['carga_codigo'] ?? 'SC');
            return DataRow(
              selected: _selectedItems.contains(itemKey),
              onSelectChanged: (selected) {
                setState(() {
                  if (selected == true) {
                    _selectedItems.add(itemKey);
                  } else {
                    _selectedItems.remove(itemKey);
                  }
                });
              },
              cells: [
                DataCell(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v['viaje_codigo'] ?? 'S/C', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF08201A), fontFamily: 'JetBrains Mono')),
                      if (c != null) Text(c['carga_codigo'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'Inter')),
                    ],
                  ),
                ),
                DataCell(Text('${chofer['nombre'] ?? ''} ${chofer['apellido'] ?? ''}'.trim(), style: const TextStyle(fontSize: 13, fontFamily: 'Inter'))),
                DataCell(Text(v['vehiculo_codigo'] ?? 'S/D', style: const TextStyle(fontSize: 13, fontFamily: 'Inter'))),
                DataCell(Text('${totalKg.round()} kg', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF08201A), fontFamily: 'JetBrains Mono'))),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(value: totalTambores > 0, onChanged: (bool? val) {}, activeColor: const Color(0xFFC68E17)),
                      Text('$totalTambores un.', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'JetBrains Mono')),
                    ],
                  ),
                ),
                DataCell(
                  ElevatedButton(
                    onPressed: () {
                       if (c != null && type != 'carga_terminada') context.push('/cargaDetalle?id=${c['id']}');
                       else if (type == 'carga_terminada') context.push('/remito_carga?cargaId=${c['id']}');
                       else context.push('/viajedetalle?viajeId=${v['id']}');
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF08201A), foregroundColor: Colors.white, elevation: 0),
                    child: const Text('VER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Manrope')),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          // WEB LAYOUT (STITCH Design - Ola 1)
          final bentoDecoration = BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 30,
                offset: const Offset(0, 8),
              )
            ],
          );

          return Scaffold(
            backgroundColor: const Color(0xFFFBF9F8),
            body: RepaintBoundary(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Stack(
                    children: [
                  // Header
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/home');
                              }
                            },
                            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF08201A)),
                            tooltip: 'Volver',
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'GeoLogística Depósito',
                            style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 24, color: Color(0xFF08201A)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Asymmetrical 3 Bento Blocks
                  Positioned.fill(
                    top: 80,
                    child: AnimatedOpacity(
                      opacity: _loading ? 0.4 : 1.0,
                      duration: const Duration(milliseconds: 400),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Left Panel: Quick actions & Tabs
                            Expanded(
                              flex: 2,
                              child: Container(
                                decoration: bentoDecoration,
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('MENÚ Y ACCIONES', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF08201A))),
                                    const SizedBox(height: 24),
                                    _buildSidebarTab(0, 'PENDIENTES', Icons.hourglass_empty_rounded),
                                    _buildSidebarTab(1, 'EN CURSO', Icons.local_shipping_rounded),
                                    _buildSidebarTab(2, 'TERMINADAS', Icons.check_circle_rounded),
                                    const Spacer(),
                                    const Divider(color: Colors.black12),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: _fetchData,
                                      icon: const Icon(Icons.sync_rounded),
                                      label: const Text('ACTUALIZAR', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF08201A).withOpacity(0.05),
                                        foregroundColor: const Color(0xFF08201A),
                                        minimumSize: const Size(double.infinity, 48),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        elevation: 0,
                                      ),
                                    ),
                                    if (!_isChofer) ...[
                                      const SizedBox(height: 12),
                                      ElevatedButton.icon(
                                        onPressed: _showAddCargaDialog,
                                        icon: const Icon(Icons.add_box_rounded),
                                        label: const Text('NUEVA CARGA', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFC68E17),
                                          foregroundColor: const Color(0xFFFFFFFF),
                                          minimumSize: const Size(double.infinity, 48),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            // 2. Expanded Center Panel: Wide DataTable
                            Expanded(
                              flex: 6,
                              child: Container(
                                decoration: bentoDecoration,
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.05))),
                                      ),
                                      child: const Text('TABLERO DE CONTROL', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF08201A))),
                                    ),
                                    Expanded(
                                      child: TabBarView(
                                        controller: _tabController,
                                        children: [
                                          _buildWebDataTable(0),
                                          _buildWebDataTable(1),
                                          _buildWebDataTable(2),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            // 3. Right Panel: Stock alerts in white cards
                            Expanded(
                              flex: 2,
                              child: Container(
                                decoration: bentoDecoration,
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('ALERTAS DE STOCK', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF08201A))),
                                    const SizedBox(height: 24),
                                    // Alerta de ejemplo con status badge
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF08201A).withOpacity(0.02),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFF08201A).withOpacity(0.05)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Text('BAJO', style: TextStyle(color: Colors.deepOrange, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          const Text('Tambores Vacíos', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF08201A))),
                                          const SizedBox(height: 4),
                                          const Text('Nivel por debajo del 20% en Parque Industrial.', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey)),
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
                  ),
                  if (_loading)
                    const Positioned.fill(
                      child: Center(
                        child: CircularProgressIndicator(color: Color(0xFFC68E17)),
                      ),
                    ),
                ],
              ),
            ),
            ),
            ),
          );
        }

        // MOBILE LAYOUT
        return Scaffold(
          backgroundColor: const Color(0xFFFBF9F8),
          appBar: AppBar(
            backgroundColor: const Color(0xFFFFFFFF),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF08201A)),
              onPressed: () => context.go('/home'),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('GeoLogística Depósito', style: TextStyle(color: Color(0xFF08201A), fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 18)),
                const Text('Gestión de Cargas', style: TextStyle(color: Colors.grey, fontFamily: 'Inter', fontSize: 12)),
              ],
            ),
            bottom: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF08201A),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFFC68E17),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'PENDIENTES'),
                Tab(text: 'EN CURSO'),
                Tab(text: 'TERMINADAS'),
              ],
            ),
          ),
          body: _loading 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFC68E17)))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildPendientesTab(),
                  _buildEnCursoTab(),
                  _buildTerminadasTab(),
                ],
              ),
          floatingActionButton: _loading || _isChofer
              ? null
              : FloatingActionButton.extended(
                  onPressed: _showAddCargaDialog,
                  backgroundColor: const Color(0xFF08201A),
                  icon: const Icon(Icons.add_box_rounded, color: Color(0xFFC68E17)),
                  label: const Text('NUEVA CARGA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Manrope')),
                ),
        );
      },
    );
  }

  Widget _buildSidebarTab(int index, String label, IconData icon) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        final isActive = _tabController.index == index;
        return GestureDetector(
          onTap: () => _tabController.animateTo(index),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF08201A) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: isActive ? const Color(0xFFFFFFFF) : const Color(0xFF08201A).withOpacity(0.5)),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: isActive ? const Color(0xFFFFFFFF) : const Color(0xFF08201A).withOpacity(0.7),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _getActiveItems() {
    final List<Map<String, dynamic>> items = [];
    for (var v in _viajesPlanificados) {
      final listCargas = v['cargas'] as List? ?? [];
      final activeCargas = listCargas.where((c) => c['estado'] != AppStates.terminado).toList();
      for (var c in activeCargas) {
        // 1. Filtrar cargas vacías (sin productos reales cargados)
        final cItems = c['carga_items'] as List? ?? [];
        if (cItems.isEmpty) {
          continue;
        }

        // 2. Si el viaje ya está En Curso, cualquier carga de Parque Industrial ya debe estar Terminada
        // Por ende, no debe mostrarse como pendiente/activa en el depósito
        final String origen = c['deposito_origen'] ?? 'Parque Industrial';
        final String normalizedViajeState = AppStates.normalize(v['estado']?.toString());
        if (normalizedViajeState == AppStates.enCurso && origen == 'Parque Industrial') {
          continue;
        }

        items.add({'type': 'carga_activa', 'viaje': v, 'carga': c});
      }
    }
    return items;
  }

  Widget _buildPendientesTab() {
    final allItems = _getActiveItems();
    final pendientesItems = allItems.where((item) {
      if (item['type'] == 'viaje_sin_carga') return true;
      final c = item['carga'];
      return c != null && c['estado'] == AppStates.pendiente;
    }).toList();

    if (pendientesItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty_rounded, size: 64, color: DesignTokens.primary.withOpacity(0.1)),
            const SizedBox(height: 16),
            const Text('No hay cargas pendientes.'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          _sectionHeader(
            icon: Icons.hourglass_empty_rounded,
            label: 'PENDIENTES',
            color: const Color(0xFF1565C0),
            bgColor: const Color(0xFFD6E4FF),
            count: pendientesItems.length,
          ),
          const SizedBox(height: 10),
          ...pendientesItems.map((item) => _buildViajeCard(item, isEnCurso: false)),
        ],
      ),
    );
  }

  Widget _buildEnCursoTab() {
    final allItems = _getActiveItems();
    final enCursoItems = allItems.where((item) {
      if (item['type'] == 'viaje_sin_carga') return false;
      final c = item['carga'];
      return c != null && c['estado'] == AppStates.enCurso;
    }).toList();

    if (enCursoItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping_outlined, size: 64, color: DesignTokens.primary.withOpacity(0.1)),
            const SizedBox(height: 16),
            const Text('No hay cargas en curso.'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          _sectionHeader(
            icon: Icons.local_shipping_rounded,
            label: 'EN CARGA',
            color: const Color(0xFF7D5700),
            bgColor: const Color(0xFFFDEFCC),
            count: enCursoItems.length,
          ),
          const SizedBox(height: 10),
          ...enCursoItems.map((item) => _buildViajeCard(item, isEnCurso: true)),
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required int count,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color, letterSpacing: 0.5)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
          child: Text('$count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color)),
        ),
      ],
    );
  }

  Widget _buildViajeCard(Map<String, dynamic> item, {required bool isEnCurso}) {
    final type = item['type'] as String;
    final Map<String, dynamic> v = item['viaje'];
    final Map<String, dynamic>? c = item['carga'];

    final chofer = v['profiles'] ?? {};
    final vehiculo = v['vehiculos'] ?? {};
    final metrics = _calcCardMetrics(item);
    final totalKg = metrics['totalKg'] as double;
    final totalTambores = metrics['totalTambores'] as int;
    final aggregatedItems = metrics['aggregatedItems'] as Map<String, double>;
    
    final capKg = (vehiculo['capacidad_kg'] ?? 0).toDouble();
    final excede = capKg > 0 && totalKg > capKg;

    final borderColor = isEnCurso ? const Color(0xFFFDBE49) : DesignTokens.primary.withOpacity(0.12);
    final topBarColor = isEnCurso ? const Color(0xFFFDEFCC) : DesignTokens.primary.withOpacity(0.04);

    return GestureDetector(
      onTap: () => c != null 
          ? context.push('/cargaDetalle?id=${c['id']}') 
          : context.push('/viajedetalle?viajeId=${v['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: isEnCurso ? 1.5 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Barra superior de estado
          Container(
            decoration: BoxDecoration(
              color: topBarColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  isEnCurso ? Icons.local_shipping_rounded : Icons.hourglass_empty_rounded,
                  size: 14,
                  color: isEnCurso ? const Color(0xFF7D5700) : DesignTokens.primary.withOpacity(0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  isEnCurso ? 'EN CARGA' : 'PENDIENTE',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 0.5,
                    color: isEnCurso ? const Color(0xFF7D5700) : DesignTokens.primary.withOpacity(0.5),
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    '${v['viaje_codigo'] ?? 'S/C'}${c != null ? ' • ${c['carga_codigo']}' : ' • SIN CARGA'}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: DesignTokens.primary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info chofer y vehículo
                Row(
                  children: [
                    Icon(Icons.person_rounded, size: 14, color: DesignTokens.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      '${chofer['nombre'] ?? 'Sin asignar'} ${chofer['apellido'] ?? ''}'.trim(),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: DesignTokens.onSurface),
                    ),
                    const Spacer(),
                    Icon(Icons.directions_car_rounded, size: 14, color: DesignTokens.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(v['vehiculo_codigo'] ?? 'S/D', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                if (c != null && c['deposito_origen'] != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.warehouse_rounded, size: 14, color: DesignTokens.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        'Origen: ${c['deposito_origen']}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Métricas
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _metricCol('PESO TOTAL', '${totalKg.round()} Kg', Icons.scale),
                    _metricCol('TAMBORES', '$totalTambores un.', Icons.inventory_2),
                  ],
                ),

                // Barra de capacidad del camión
                if (capKg > 0) ...[ 
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CAPACIDAD DEL CAMIÓN',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: DesignTokens.primary.withOpacity(0.4), letterSpacing: 0.5),
                      ),
                      Text(
                        excede
                          ? '⚠️ EXCEDIDO ${(totalKg - capKg).round()} kg'
                          : 'Libre: ${(capKg - totalKg).round()} kg',
                        style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.bold,
                          color: excede ? Colors.orange : const Color(0xFF1A6B43),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (totalKg / capKg).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: DesignTokens.primary.withOpacity(0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        excede ? Colors.orange : const Color(0xFF1A6B43),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(totalKg / capKg * 100).clamp(0.0, 150.0).round()}% de ${capKg.round()} kg',
                    style: TextStyle(fontSize: 9, color: DesignTokens.onSurfaceVariant.withOpacity(0.5)),
                  ),
                ],

                // Productos
                if (aggregatedItems.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.inventory_2_rounded, size: 12, color: DesignTokens.primary.withOpacity(0.6)),
                      const SizedBox(width: 6),
                      const Text(
                        'DETALLE DE PRODUCTOS A CARGAR',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: Colors.grey,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: DesignTokens.primary.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: DesignTokens.primary.withOpacity(0.06)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: aggregatedItems.entries.map((entry) {
                        final String prodCode = entry.key.toUpperCase();
                        final prod = _productos.firstWhere(
                          (p) => p['codigo']?.toString().toUpperCase() == prodCode,
                          orElse: () => {},
                        );
                        final String prodDesc = prod.isNotEmpty ? (prod['descripcion'] ?? prodCode) : prodCode;
                        
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: DesignTokens.primary.withOpacity(0.06),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: DesignTokens.primary.withOpacity(0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  prodCode.contains('VACIO') || prodCode.contains('VACÍO') || prodCode == 'TV'
                                      ? Icons.hourglass_empty_rounded
                                      : Icons.inventory_2_rounded,
                                  size: 14,
                                  color: DesignTokens.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      prodDesc,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: DesignTokens.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Código: $prodCode',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: DesignTokens.onSurfaceVariant.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: DesignTokens.primary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${entry.value.round()} un.',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                if (type != 'viaje_sin_cargo') ...[
                  const SizedBox(height: 14),

                  // Botones de acción
                  Row(
                    children: [
                      // El botón EDITAR sólo es visible para roles no choferes
                      if (!_isChofer) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showEditCargaDialog(v, c!),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: DesignTokens.primary,
                              side: const BorderSide(color: DesignTokens.primary, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.edit_rounded, size: 16),
                            label: const Text('EDITAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],

                      // Botón principal: según estado y permisos
                      Expanded(
                        flex: 2,
                        child: () {
                          // Verificar si el usuario tiene permiso para iniciar/finalizar la carga
                          final bool isAssignedDriver = v['chofer_id'] != null && v['chofer_id'] == _currentUserId;
                          final bool canOperate = !_isChofer || isAssignedDriver;

                          return ElevatedButton.icon(
                            onPressed: canOperate
                                ? (isEnCurso
                                    ? () => _finalizarCarga(v, c!)
                                    : () => _iniciarCarga(v, c!))
                                : null, // Deshabilitar si es otro chofer
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isEnCurso ? DesignTokens.primary : const Color(0xFF1565C0),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.withOpacity(0.12),
                              disabledForegroundColor: Colors.grey.withOpacity(0.48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            icon: Icon(
                              isEnCurso ? Icons.check_circle_outline : Icons.play_circle_outline,
                              size: 16,
                              color: canOperate
                                  ? (isEnCurso ? DesignTokens.accent : Colors.white)
                                  : Colors.grey.withOpacity(0.4),
                            ),
                            label: Text(
                              !canOperate
                                  ? 'ASIGNADO A OTRO CHOFER'
                                  : (isEnCurso ? 'FINALIZAR CARGA' : 'INICIAR CARGA'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          );
                        }(),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildTerminadasTab() {
    return RefreshIndicator(
      onRefresh: _fetchData,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar por viaje, chofer, producto, depósito...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) {
                      _searchQuery = val;
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _selectedDate = date);
                      _applyFilters();
                    }
                  },
                  icon: Icon(Icons.calendar_month, color: _selectedDate != null ? DesignTokens.accent : Colors.white),
                  style: IconButton.styleFrom(backgroundColor: DesignTokens.primary),
                ),
                if (_selectedDate != null)
                  IconButton(onPressed: () { setState(() => _selectedDate = null); _applyFilters(); }, icon: const Icon(Icons.clear, color: Colors.red)),
              ],
            ),
          ),
          Expanded(
            child: _filteredHistory.isEmpty
              ? const Center(child: Text('No se encontraron cargas terminadas.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _filteredHistory.length,
                  itemBuilder: (ctx, i) => _buildHistoryCard(_filteredHistory[i]),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> c) {
    final updated = DateTime.tryParse(c['updated_at'] ?? '');
    final dateStr = updated != null ? DateFormat('dd/MM/yyyy HH:mm').format(updated) : 'S/F';
    final items = List<Map<String, dynamic>>.from(c['carga_items'] ?? []);
    final viajeId = c['viaje_id'] ?? c['viaje']?['id'];

    return GestureDetector(
      onTap: viajeId != null ? () => context.push('/viajedetalle?viajeId=$viajeId') : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
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
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c['carga_codigo'] ?? 'CARGA', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        Text('Viaje: ${c['viaje']?['viaje_codigo'] ?? 'S/V'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: items.map((item) {
                  final String prod = (item['producto_codigo'] ?? 'S/D').toString().toUpperCase();
                  final double cant = (item['cantidad'] ?? 0).toDouble();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.withOpacity(0.15)),
                    ),
                    child: Text(
                      '$prod × ${cant.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/remito_carga?cargaId=${c['id']}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.secondary,
                  foregroundColor: DesignTokens.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                label: const Text('REMITO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCol(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: DesignTokens.primary.withOpacity(0.4)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: DesignTokens.primary.withOpacity(0.4))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: DesignTokens.primary)),
      ],
    );
  }

  void _showAddCargaDialog({String? preselectedViajeId}) {
    if (_isChofer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Los choferes no tienen permisos para crear cargas.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    String? selectedViajeId = preselectedViajeId;
    String? selectedProductoCodigo;
    final qtyController = TextEditingController();
    List<Map<String, dynamic>> allViajes = List.from(_viajesPlanificados);
    String selectedDeposito = 'Parque Industrial';

    List<Map<String, dynamic>> plannedItems = [];
    bool isLoadingPlanned = false;
    bool autoLoadPlanned = true;
    bool hasFetchedOnStartup = false;

    // Obtener peso unitario del catálogo dinámicamente
    double getProductWeight(String code) {
      final p = _productos.firstWhere(
        (prod) => prod['codigo']?.toString().toUpperCase() == code.toUpperCase(),
        orElse: () => {},
      );
      if (p.isNotEmpty && p['peso_unit_kg'] != null) {
        return (p['peso_unit_kg'] as num).toDouble();
      }
      if (code == 'TCM' || code.contains('TAMBOR')) return 300.0;
      if ((code.startsWith('T') && code != 'TV' && code != 'TE') || code.contains('VACIO') || code.contains('VACÍO')) return 20.0;
      if (code == 'AZ') return 50.0;
      return 1.0;
    }

    Future<void> fetchPlannedItems(String viajeId, Function setModalState) async {
      setModalState(() {
        isLoadingPlanned = true;
        plannedItems = [];
      });
      try {
        final res = await Supabase.instance.client
            .from('paradas')
            .select('tipo, parada_items(producto_codigo, cantidad, unidad)')
            .eq('viaje_id', viajeId)
            .eq('tipo', 'Distribución');
        
        final Map<String, double> consolidated = {};
        final Map<String, String> units = {};
        
        for (var p in res) {
          final items = p['parada_items'] as List? ?? [];
          for (var it in items) {
            final String prod = (it['producto_codigo'] ?? '').toString().trim().toUpperCase();
            final double cant = (it['cantidad'] ?? 0.0).toDouble();
            final String unit = (it['unidad'] ?? 'UN').toString().split('|')[0];
            if (prod.isNotEmpty && cant > 0) {
              consolidated[prod] = (consolidated[prod] ?? 0) + cant;
              units[prod] = unit;
            }
          }
        }
        
        final List<Map<String, dynamic>> list = [];
        consolidated.forEach((prod, cant) {
          list.add({
            'producto_codigo': prod,
            'cantidad': cant,
            'unidad': units[prod] ?? 'UN',
          });
        });
        
        setModalState(() {
          plannedItems = list;
          isLoadingPlanned = false;
        });
      } catch (e) {
        print('Error fetching planned items: $e');
        setModalState(() {
          isLoadingPlanned = false;
        });
      }
    }

    // También cargamos viajes pendientes de la BD por si hay más
    Future<void> refreshViajes(setModalState) async {
      try {
        var query = Supabase.instance.client
            .from('viajes')
            .select('id, viaje_codigo, vehiculo_codigo, estado, chofer_id, vehiculos:vehiculo_codigo(capacidad_kg, capacidad_tambores)')
            .or('estado.eq.Pendiente,estado.eq.En Proceso,estado.eq.En Curso');

        if (_isChofer && _currentUserId != null) {
          query = query.eq('chofer_id', _currentUserId!);
        }

        final raw = await query.order('fecha', ascending: true);
        if (raw.isNotEmpty) {
          setModalState(() => allViajes = List<Map<String, dynamic>>.from(raw));
        }
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          // Load viajes on first build
          if (allViajes.isEmpty) {
            refreshViajes(setModalState);
          }

          if (!hasFetchedOnStartup && selectedViajeId != null) {
            hasFetchedOnStartup = true;
            Future.microtask(() => fetchPlannedItems(selectedViajeId!, setModalState));
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Asignar Carga a Viaje', style: DesignTokens.headlineStyle(color: DesignTokens.primary).copyWith(fontSize: 20)),
                  const SizedBox(height: 20),
                  if (allViajes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedViajeId != null && allViajes.any((v) => v['id']?.toString() == selectedViajeId)
                        ? selectedViajeId : null,
                    decoration: const InputDecoration(labelText: 'Seleccionar Viaje', prefixIcon: Icon(Icons.local_shipping_rounded)),
                    hint: const Text('Seleccionar viaje...', overflow: TextOverflow.ellipsis, maxLines: 1),
                    items: allViajes.map((v) => DropdownMenuItem<String>(
                      value: v['id']?.toString(),
                      child: Text(
                        '${v['viaje_codigo'] ?? 'S/C'} — ${v['vehiculo_codigo'] ?? 'S/V'} (${v['estado'] ?? ''})',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    )).toList(),
                    onChanged: (v) {
                      setModalState(() {
                        selectedViajeId = v;
                        
                        // Si el viaje seleccionado está En Curso, forzar Depósito Huinca
                        final selectedTrip = allViajes.firstWhere(
                          (trip) => trip['id']?.toString() == v,
                          orElse: () => {},
                        );
                        final String tripState = selectedTrip['estado'] ?? '';
                        final String normalizedState = AppStates.normalize(tripState);
                        if (normalizedState == AppStates.enCurso) {
                          selectedDeposito = 'Depósito Huinca';
                        }
                      });
                      if (v != null) {
                        fetchPlannedItems(v, setModalState);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    key: ValueKey(selectedViajeId), // Forzar reconstrucción limpia si cambia el viaje
                    value: selectedDeposito,
                    decoration: const InputDecoration(
                      labelText: 'Depósito de Origen',
                      prefixIcon: Icon(Icons.warehouse_rounded),
                    ),
                    items: (() {
                      final selectedTrip = allViajes.firstWhere(
                        (trip) => trip['id']?.toString() == selectedViajeId,
                        orElse: () => {},
                      );
                      final String tripState = selectedTrip['estado'] ?? '';
                      final String normalizedState = AppStates.normalize(tripState);
                      if (normalizedState == AppStates.enCurso) {
                        return ['Depósito Huinca'];
                      }
                      return ['Parque Industrial', 'Depósito Huinca'];
                    }()).map((dep) => DropdownMenuItem<String>(
                      value: dep,
                      child: Text(dep, overflow: TextOverflow.ellipsis, maxLines: 1),
                    )).toList(),
                    onChanged: (_isChofer || (() {
                      final selectedTrip = allViajes.firstWhere(
                        (trip) => trip['id']?.toString() == selectedViajeId,
                        orElse: () => {},
                      );
                      final String tripState = selectedTrip['estado'] ?? '';
                      final String normalizedState = AppStates.normalize(tripState);
                      return normalizedState == AppStates.enCurso;
                    }())) ? null : (v) {
                      if (v != null) {
                        setModalState(() {
                          selectedDeposito = v;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  if (isLoadingPlanned)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (plannedItems.isNotEmpty) ...[
                    Row(
                      children: [
                        Checkbox(
                          value: autoLoadPlanned,
                          activeColor: DesignTokens.primary,
                          onChanged: (val) {
                            setModalState(() {
                              autoLoadPlanned = val ?? true;
                            });
                          },
                        ),
                        Expanded(
                          child: Text(
                            'Pre-poblar carga con ítems planificados de Distribución',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: DesignTokens.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: DesignTokens.primary.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: DesignTokens.primary.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ítems planificados detectados:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: plannedItems.map((item) {
                              final prod = item['producto_codigo'] ?? '';
                              final cant = item['cantidad'] ?? 0;
                              final unit = item['unidad'] ?? 'uni';
                              return Chip(
                                label: Text(
                                  '$prod: ${cant.toStringAsFixed(0)} $unit',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: DesignTokens.primary,
                                  ),
                                ),
                                backgroundColor: DesignTokens.secondary.withOpacity(0.3),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_productos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Cargando productos...', style: TextStyle(color: Colors.grey)),
                    )
                  else
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedProductoCodigo,
                    decoration: const InputDecoration(labelText: 'Producto Adicional', prefixIcon: Icon(Icons.inventory_2_rounded)),
                    hint: const Text('Seleccionar producto...', overflow: TextOverflow.ellipsis, maxLines: 1),
                    items: _productos.map((p) => DropdownMenuItem<String>(
                      value: p['codigo']?.toString(),
                      child: Text(
                        '${p['codigo'] ?? ''} — ${p['descripcion'] ?? p['codigo'] ?? 'S/N'}',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    )).toList(),
                    onChanged: (v) => setModalState(() => selectedProductoCodigo = v),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cantidad Adicional', prefixIcon: Icon(Icons.numbers_rounded)),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (selectedViajeId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Por favor, selecciona un viaje.'), backgroundColor: Colors.orangeAccent),
                          );
                          return;
                        }
                        
                        final viaje = allViajes.firstWhere(
                          (v) => v['id']?.toString() == selectedViajeId,
                          orElse: () => _viajesPlanificados.firstWhere((v) => v['id']?.toString() == selectedViajeId, orElse: () => {}),
                        );
                        if (viaje.isEmpty) return;

                        // BLOQUEO: Depósito PI no puede asignar cargas a viajes En Proceso
                        final vEstado = AppStates.normalize(viaje['estado']?.toString() ?? '');
                        if (selectedDeposito == 'Parque Industrial' && vEstado == AppStates.enCurso) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No se pueden asignar cargas del depósito PI a un viaje que ya está En Proceso. Las cargas en ruta corresponden al Depósito Huinca.'),
                              backgroundColor: Colors.deepOrange,
                              duration: Duration(seconds: 4),
                            ),
                          );
                          return;
                        }

                        // Construir lista de ítems a insertar
                        final List<Map<String, dynamic>> itemsToInsert = [];
                        double totalProjectedWeight = 0.0;

                        if (autoLoadPlanned) {
                          for (var item in plannedItems) {
                            final String prod = item['producto_codigo'] ?? '';
                            final double cant = (item['cantidad'] ?? 0.0).toDouble();
                            final String unit = item['unidad'] ?? 'UN';
                            if (cant > 0) {
                              itemsToInsert.add({
                                'producto_codigo': prod,
                                'cantidad': cant.round(),
                                'unidad': unit,
                              });
                              totalProjectedWeight += cant * getProductWeight(prod);
                            }
                          }
                        }

                        if (selectedProductoCodigo != null && qtyController.text.isNotEmpty) {
                          final double customQty = double.tryParse(qtyController.text) ?? 0.0;
                          if (customQty > 0) {
                            final prod = _productos.firstWhere((p) => p['codigo']?.toString() == selectedProductoCodigo, orElse: () => {});
                            final existingIndex = itemsToInsert.indexWhere((it) => it['producto_codigo'] == selectedProductoCodigo);
                            if (existingIndex != -1) {
                              final currentVal = itemsToInsert[existingIndex]['cantidad'] as num;
                              itemsToInsert[existingIndex]['cantidad'] = currentVal.toInt() + customQty.round();
                            } else {
                              itemsToInsert.add({
                                'producto_codigo': selectedProductoCodigo,
                                'cantidad': customQty.round(),
                                'unidad': prod['unidad'] ?? 'UN',
                              });
                            }
                            totalProjectedWeight += customQty * getProductWeight(selectedProductoCodigo!);
                          }
                        }

                        if (itemsToInsert.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Por favor, selecciona al menos un ítem o activa la pre-población.'),
                              backgroundColor: Colors.orangeAccent,
                            ),
                          );
                          return;
                        }

                        // Validar Peso Máximo del Camión
                        final double capKg = (viaje['vehiculos']?['capacidad_kg'] ?? 0).toDouble();
                        if (capKg > 0 && totalProjectedWeight > capKg) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: El peso proyectado (${totalProjectedWeight.toStringAsFixed(0)} kg) supera la capacidad del camión (${capKg.toStringAsFixed(0)} kg).'),
                              backgroundColor: Colors.orangeAccent,
                            ),
                          );
                          return;
                        }

                        try {
                          int count = 0;
                          try {
                            final list = await Supabase.instance.client
                                .from('cargas')
                                .select('id');
                            count = list.length;
                          } catch (e) {
                            print('DepositoHome: Error counting charges: $e');
                          }
                          final humanId = 'Carga-${count + 1}';
                          
                          // Crear la Carga principal con created_by y deposito_origen serializado en carga_codigo
                          final formattedCargaCodigo = '$humanId | $selectedDeposito';
                          final cargaInsert = {
                            'viaje_id': viaje['id'],
                            'carga_codigo': formattedCargaCodigo,
                            'estado': AppStates.pendiente,
                            if (_currentUserId != null && _currentUserId!.isNotEmpty)
                              'created_by': _currentUserId,
                          };
                          final cargaResp = await Supabase.instance.client.from('cargas').insert(cargaInsert).select('id').single();

                          // Asignar el ID de la carga recién creada a cada uno de los ítems
                          for (var item in itemsToInsert) {
                            item['carga_id'] = cargaResp['id'];
                          }

                          final messenger = ScaffoldMessenger.of(context);
                          
                          // Insertar todos los carga_items
                          await Supabase.instance.client.from('carga_items').insert(itemsToInsert);

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            _fetchData();
                            messenger.showSnackBar(const SnackBar(content: Text('Carga asignada correctamente')));
                          }
                        } catch (e) {
                          final messenger = ScaffoldMessenger.of(context);
                          if (ctx.mounted) messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                      style: DesignTokens.primaryButtonStyle,
                      child: const Text('ASIGNAR CARGA'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
