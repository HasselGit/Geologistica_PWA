import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../backend/design_tokens.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../backend/supabase_service.dart';
import '../backend/apicultores_data.dart';
import '../backend/productos_data.dart';

class ApicultorDetalleWidget extends StatefulWidget {
  final Map<String, dynamic> apicultor;
  const ApicultorDetalleWidget({super.key, required this.apicultor});

  @override
  State<ApicultorDetalleWidget> createState() => _ApicultorDetalleWidgetState();
}

class _ApicultorDetalleWidgetState extends State<ApicultorDetalleWidget> {
  List<Map<String, dynamic>> _pendientes = [];
  List<Map<String, dynamic>> _recientes = [];
  Map<String, Map<String, double>> _resumenDetallado = {}; 
  Map<String, Map<String, double>> _resumenPendiente = {}; 
  Map<String, int> _statusCounts = {};
  bool _isLoading = true;
  double _maxTotal = 1.0;
  double _maxTotalPendiente = 1.0;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadRole();
    _refreshApicultorData();
    _fetchDetailedData();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _userRole = prefs.getString('user_puesto'));
  }

  Future<void> _refreshApicultorData() async {
    try {
      final code = widget.apicultor['apicultor_codigo'] ?? widget.apicultor['id'];
      if (code == null) return;
      
      final localData = ApicultoresData.fallbackApicultores.firstWhere(
        (a) => a['apicultor_codigo'] == code,
        orElse: () => {},
      );

      final fullData = await Supabase.instance.client
          .from('apicultores')
          .select('id, nombre, localidad, provincia, cuit, telefono, renapa, dni')
          .eq('id', code)
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (localData.isNotEmpty) {
            widget.apicultor.addAll(localData);
          }
          
          if (fullData != null) {
            fullData.forEach((key, value) {
              if (value != null && value.toString().isNotEmpty) {
                if (key == 'localidad' && value.toString().contains(',') && localData['localidad'] != null) {
                   return;
                }
                widget.apicultor[key] = value;
              }
            });
          }

          _syncToSupabaseIfNeeded(code, localData, fullData);
        });
      }
    } catch (e) {
      print('Error refreshing apicultor data: $e');
    }
  }

  Future<void> _syncToSupabaseIfNeeded(String id, Map<String, dynamic> local, Map<String, dynamic>? db) async {
    if (db == null) return;
    
    Map<String, dynamic> toUpdate = {};
    
    final fields = ['cuit', 'renapa', 'localidad', 'provincia', 'telefono'];
    
    for (var f in fields) {
      final localVal = local[f]?.toString() ?? '';
      final dbVal = db[f]?.toString() ?? '';
      
      if (localVal.isNotEmpty && dbVal.isEmpty) {
        toUpdate[f] = localVal;
      }
    }

    final localName = local['nombre']?.toString() ?? '';
    final dbName = db['nombre']?.toString() ?? '';
    if (localName.isNotEmpty && localName.length > dbName.length + 5 && localName.contains(dbName)) {
      toUpdate['nombre'] = localName;
    }

    if (toUpdate.isNotEmpty) {
      print('DEBUG: Sincronizando datos faltantes a Supabase para $id: $toUpdate');
      await SupabaseService().updateApicultorBasicData(id, toUpdate);
    }
  }

  Map<String, String> _resolveProductInfo(String codeOrDesc) {
    final clean = codeOrDesc.trim().toUpperCase();
    
    // Fix broken encoding in database/sheets
    var cleanFixed = clean;
    if (clean.contains('AZ') && clean.contains('AR')) {
      cleanFixed = 'AZ';
    } else if (clean.contains('AZÚCAR') || clean.contains('AZUCAR') || clean.contains('AZÃºCAR')) {
      cleanFixed = 'AZ';
    }
    
    final prod = ProductosData.masterCatalog.firstWhere(
      (p) => p['producto'].toString().toUpperCase() == cleanFixed ||
             p['codigo'].toString().toUpperCase() == cleanFixed ||
             p['descripcion'].toString().toUpperCase() == cleanFixed,
      orElse: () => <String, dynamic>{},
    );
    
    if (prod.isNotEmpty) {
      return {
        'descripcion': prod['descripcion'].toString(),
        'unidad': prod['unidad'].toString().toLowerCase().contains('bolsa') ? 'Bolsas' : prod['unidad'].toString(),
      };
    }
    
    // Fallback if not found in catalog
    return {
      'descripcion': codeOrDesc,
      'unidad': 'kg',
    };
  }

  Future<void> _fetchDetailedData() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final apiId = (widget.apicultor['apicultor_codigo'] ?? widget.apicultor['id']).toString();
      
      // Generar una lista ultra-resiliente de posibles formatos del código de apicultor
      final clean = apiId.trim().toUpperCase();
      final numericPart = clean.replaceAll(RegExp(r'^A0*'), '');
      
      final List<String> idCandidates = [clean];
      if (numericPart.isNotEmpty) {
        idCandidates.add(numericPart);
        idCandidates.add('A${numericPart.padLeft(5, '0')}'); // A01887
        idCandidates.add('A${numericPart.padLeft(4, '0')}'); // A1887
        idCandidates.add('A$numericPart');
      }
      final uniqueCandidates = idCandidates.toSet().toList();
 
      String orFilter = uniqueCandidates.map((id) => 'apicultor_id.eq.$id').join(',');
 
      final allSolsRes = await client.from('solicitudes')
          .select('*')
          .or(orFilter)
          .neq('estado', 'Eliminada')
          .order('created_at', ascending: false);
      
      final List<Map<String, dynamic>> allSols = List<Map<String, dynamic>>.from(allSolsRes as List);
 
      // Enriquecer con remitos y datos de producto de forma ultra segura
      for (var s in allSols) {
        s['remito_codigo'] = null;
        
        // Resolver producto
        final prodRaw = s['producto'] ?? 'S/D';
        final resolved = _resolveProductInfo(prodRaw.toString());
        s['producto_display'] = resolved['descripcion'];
        s['unidad_display'] = resolved['unidad'];
 
        try {
          final paradasData = await client.from('paradas')
              .select('id')
              .eq('solicitud_id', s['id'])
              .limit(1);
          if (paradasData.isNotEmpty) {
            final paradaId = paradasData[0]['id'];
            final remitoData = await client.from('remitos')
                .select('numero_remito')
                .eq('parada_id', paradaId)
                .maybeSingle();
            if (remitoData != null) {
              s['remito_codigo'] = remitoData['numero_remito'] ?? 'REM-${paradaId.toString().split('-').first.toUpperCase()}';
            }
          }
        } catch (e) {
          print('Error recuperando remito para apicultor detalle: $e');
        }
      }
 
      final List<Map<String, dynamic>> activas = allSols.where((s) {
        final estado = (s['estado'] ?? 'Pendiente').toString().toLowerCase().trim();
        return estado != 'terminada' && estado != 'terminado' &&
               estado != 'finalizada' && estado != 'finalizado' &&
               estado != 'completada' && estado != 'completado' &&
               estado != 'cancelada' && estado != 'cancelado';
      }).toList();
 
      final List<Map<String, dynamic>> recientes = allSols.where((s) {
        final estado = (s['estado'] ?? 'Pendiente').toString().toLowerCase().trim();
        return estado == 'terminada' || estado == 'terminado' ||
               estado == 'finalizada' || estado == 'finalizado' ||
               estado == 'completada' || estado == 'completado';
      }).take(10).toList();
 
      final Map<String, Map<String, double>> resumen = {};
      final Map<String, Map<String, double>> resumenPendiente = {};
      final Map<String, int> estadoCounts = {
        'PENDIENTES': 0,
        'ASIGNADAS': 0,
        'EN CURSO': 0,
        'TERMINADAS': 0,
      };
 
      for (var s in allSols) {
        final prodDisplay = s['producto_display'] ?? s['producto'] ?? 'S/D';
        final cant = double.tryParse(s['cantidad']?.toString() ?? '0') ?? 0;
        final tipoRaw = (s['tipo'] ?? 'Operación').toString();
        final String tipo = tipoRaw.toLowerCase().contains('recolecci') ? 'Recolección' : 'Distribución';
        final estado = (s['estado'] ?? 'Pendiente').toString().toUpperCase().trim();
        
        final bool isCompleted = estado.contains('TERMINADA') || estado.contains('TERMINADO') ||
                                 estado.contains('FINALIZADA') || estado.contains('FINALIZADO') ||
                                 estado.contains('COMPLETADA') || estado.contains('COMPLETADO');
        final bool isCanceled = estado.contains('CANCELADA') || estado.contains('CANCELADO') || estado.contains('ELIMINADA');
        
        if (isCompleted) {
          resumen.putIfAbsent(prodDisplay, () => {});
          resumen[prodDisplay]![tipo] = (resumen[prodDisplay]![tipo] ?? 0) + cant;
        } else if (!isCanceled) {
          resumenPendiente.putIfAbsent(prodDisplay, () => {});
          resumenPendiente[prodDisplay]![tipo] = (resumenPendiente[prodDisplay]![tipo] ?? 0) + cant;
        }
 
        if (estado.contains('PENDIENTE')) {
          estadoCounts['PENDIENTES'] = (estadoCounts['PENDIENTES'] ?? 0) + 1;
        } else if (estado.contains('ASIGNADA')) {
          estadoCounts['ASIGNADAS'] = (estadoCounts['ASIGNADAS'] ?? 0) + 1;
        } else if (estado.contains('CURSO') || estado.contains('PROCESO')) {
          estadoCounts['EN CURSO'] = (estadoCounts['EN CURSO'] ?? 0) + 1;
        } else if (isCompleted) {
          estadoCounts['TERMINADAS'] = (estadoCounts['TERMINADAS'] ?? 0) + 1;
        }
      }
 
      // Calcular maxTotal para barras de progreso histórico
      double maxT = 1.0;
      for (var prodResumen in resumen.values) {
        double prodTotal = prodResumen.values.fold(0.0, (a, b) => a + b);
        if (prodTotal > maxT) maxT = prodTotal;
      }
      
      // Calcular maxTotalPendiente para barras de progreso pendiente
      double maxTPendiente = 1.0;
      for (var prodResumen in resumenPendiente.values) {
        double prodTotal = prodResumen.values.fold(0.0, (a, b) => a + b);
        if (prodTotal > maxTPendiente) maxTPendiente = prodTotal;
      }
 
      if (mounted) {
        setState(() {
          _pendientes = activas;
          _recientes = recientes;
          _resumenDetallado = resumen;
          _resumenPendiente = resumenPendiente;
          _statusCounts = estadoCounts;
          _maxTotal = maxT;
          _maxTotalPendiente = maxTPendiente;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('ApicultorDetalle: Error fetching detailed data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userRole == 'Chofer') {
      return Scaffold(
        appBar: AppBar(title: const Text('Acceso Restringido')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person_rounded, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text('No tiene permisos para ver perfiles de apicultores', 
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: () => context.pop(), child: const Text('VOLVER'))
            ],
          ),
        ),
      );
    }

    final a = widget.apicultor;
    return Scaffold(
      backgroundColor: DesignTokens.surface,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
            onPressed: () => context.pop(),
          ),
          centerTitle: false,
          title: Text('Perfil de Apicultor', 
            style: DesignTokens.headlineStyle().copyWith(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: DesignTokens.primary)
          ),
        ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
        : RefreshIndicator(
            onRefresh: _fetchDetailedData,
            color: DesignTokens.secondary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildProfileHeader(a),
                  const SizedBox(height: 24),
                  _buildInfoGrid(a),
                  
                  const SizedBox(height: 40),
                  _buildSectionHeader('Solicitudes Activas', null),
                  const SizedBox(height: 16),
                  if (_pendientes.isEmpty)
                    _buildEmptyState('No hay solicitudes activas')
                  else
                    ..._pendientes.map((s) => _buildPendienteCard(s)).toList(),

                  const SizedBox(height: 40),
                  _buildSectionHeader('Total Estimado Pendiente', null),
                  const SizedBox(height: 16),
                  if (_resumenPendiente.isEmpty)
                    _buildEmptyState('No hay solicitudes pendientes o en proceso')
                  else
                    _buildProductSummaryPendiente(),
 
                  const SizedBox(height: 40),
                  _buildStatusOverview(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Resumen por Producto (Histórico)', null),
                  const SizedBox(height: 16),
                  if (_resumenDetallado.isEmpty)
                    _buildEmptyState('Sin operaciones registradas')
                  else
                    _buildProductSummary(),

                  const SizedBox(height: 40),
                  _buildSectionHeader('Operaciones Recientes', null, showIcons: true),
                  const SizedBox(height: 16),
                  if (_recientes.isEmpty)
                    _buildEmptyState('No hay operaciones terminadas recientemente')
                  else
                    ..._recientes.map((s) => _buildRecienteCard(s)).toList(),
                  
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
      floatingActionButton: (_userRole == 'CEO' || _userRole == 'Gerente' || _userRole == 'Compras') 
        ? FloatingActionButton(
            onPressed: _showAddSolicitudModal,
            backgroundColor: DesignTokens.secondary,
            elevation: 8,
            child: const Icon(Icons.add_rounded, color: DesignTokens.primary, size: 32),
          )
        : null,
    );
  }

  void _showAddSolicitudModal() async {
    final apicultor = widget.apicultor;
    String? selectedTipo = 'Recolección';
    String? selectedProducto;
    final cantidadController = TextEditingController();
    List<Map<String, dynamic>> productos = [];

    // Cargar productos igual que en necesidades_page
    try {
      final prodData = await SupabaseService().getProductos();
      productos = List<Map<String, dynamic>>.from(prodData);
    } catch (e) {
      print('Error cargando productos: $e');
    }

    if (productos.isEmpty) {
      productos = [
        {'codigo': 'TCM', 'descripcion': 'Tambor con Miel', 'unidad': 'Uni'},
        {'codigo': 'TRR', 'descripcion': 'Tambor Reacondicionado Raldas', 'unidad': 'Uni'},
        {'codigo': 'TRC', 'descripcion': 'Tambor Reacondicionado Cosde', 'unidad': 'Uni'},
        {'codigo': 'TRO', 'descripcion': 'Tambor Reacondicionado Ombu', 'unidad': 'Uni'},
        {'codigo': 'TNAR', 'descripcion': 'Tambor Nuevo Alto Raldas', 'unidad': 'Uni'},
        {'codigo': 'TNAF', 'descripcion': 'Tambor Nuevo Alto Fabritam', 'unidad': 'Uni'},
        {'codigo': 'TNP', 'descripcion': 'Tambor Nuevo Petiso', 'unidad': 'Uni'},
        {'codigo': 'CO', 'descripcion': 'Cera Operculo', 'unidad': 'Kg'},
        {'codigo': 'CR', 'descripcion': 'Cera Recupero', 'unidad': 'Kg'},
      ];
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool _savingSolicitud = false;
        return StatefulBuilder(
          builder: (context, setModalState) => Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nueva Solicitud', style: DesignTokens.headlineStyle().copyWith(fontSize: 20)),
                const SizedBox(height: 8),
                Text('Para: ${apicultor['nombre']} - ${apicultor['localidad'] ?? 'S/D'}', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                
                const Text('Tipo de Operación', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Recolección')),
                        selected: selectedTipo == 'Recolección',
                        onSelected: (val) => setModalState(() => selectedTipo = 'Recolección'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Distribución')),
                        selected: selectedTipo == 'Distribución',
                        onSelected: (val) => setModalState(() => selectedTipo = 'Distribución'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                const Text('Producto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final result = await showDialog<String>(
                      context: context,
                      builder: (context) {
                        String searchQuery = '';
                        return StatefulBuilder(
                          builder: (context, setDialogState) {
                            final filteredProds = productos.where((p) => 
                              (p['codigo']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false) || 
                              (p['descripcion']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false)
                            ).toList();
                            return AlertDialog(
                              title: const Text('Buscar Producto'),
                              content: SizedBox(
                                width: double.maxFinite,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      decoration: const InputDecoration(hintText: 'Nombre del producto...', prefixIcon: Icon(Icons.inventory_2_rounded)),
                                      onChanged: (v) => setDialogState(() => searchQuery = v),
                                    ),
                                    const SizedBox(height: 10),
                                    Expanded(
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: filteredProds.length,
                                        itemBuilder: (context, i) => ListTile(
                                          title: Text(filteredProds[i]['codigo'] ?? ''),
                                          subtitle: Text(filteredProds[i]['descripcion'] ?? ''),
                                          trailing: Text(filteredProds[i]['unidad'] ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                          onTap: () => Navigator.pop(context, filteredProds[i]['codigo']),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                    if (result != null) {
                      setModalState(() {
                        selectedProducto = result;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: DesignTokens.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: DesignTokens.primary.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, size: 20, color: DesignTokens.primary.withOpacity(0.5)),
                        const SizedBox(width: 12),
                        Text(selectedProducto ?? 'Seleccionar producto...', 
                          style: TextStyle(color: selectedProducto != null ? DesignTokens.primary : Colors.black38)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text('Cantidad Estimada', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: cantidadController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Ej: 15',
                    filled: true,
                    fillColor: DesignTokens.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _savingSolicitud ? null : () async {
                      if (selectedProducto == null || cantidadController.text.isEmpty) return;
                      
                      setModalState(() => _savingSolicitud = true);
                      try {
                        final service = SupabaseService();
                        await service.createNecesidad({
                          'solicitud_codigo': 'SOL-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                          'apicultor_id': apicultor['apicultor_codigo'] ?? apicultor['id'],
                          'producto': selectedProducto,
                          'cantidad': double.tryParse(cantidadController.text) ?? 0,
                          'tipo': selectedTipo,
                          'localidad': apicultor['localidad'],
                          'estado': 'Pendiente',
                        });
                        
                        if (context.mounted) {
                          Navigator.pop(context);
                          _fetchDetailedData();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud guardada con éxito'), backgroundColor: Colors.green));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                        }
                      } finally {
                        if (context.mounted) setModalState(() => _savingSolicitud = false);
                      }
                    },
                    style: DesignTokens.primaryButtonStyle,
                    child: _savingSolicitud 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('GUARDAR SOLICITUD'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> a) {
    return Column(
      children: [
        const SizedBox(height: 10),
        
        // Name
        Text(
          a['nombre'] ?? 'Sin Nombre',
          textAlign: TextAlign.center,
          style: DesignTokens.headlineStyle().copyWith(
            fontSize: 24, 
            fontWeight: FontWeight.w900, 
            color: DesignTokens.primary,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 14),
        
        // COD box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: DesignTokens.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DesignTokens.primary.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('CÓDIGO DE APICULTOR:', style: DesignTokens.labelStyle().copyWith(fontSize: 9, fontWeight: FontWeight.bold, color: DesignTokens.primary.withOpacity(0.5))),
              const SizedBox(width: 8),
              Text(
                a['apicultor_codigo'] ?? a['id'] ?? 'S/C',
                style: const TextStyle(fontWeight: FontWeight.w900, color: DesignTokens.primary, fontSize: 16, letterSpacing: 1.0),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }


  Widget _buildInfoGrid(Map<String, dynamic> a) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DesignTokens.outline.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildInfoItem('DNI', a['dni']?.toString() ?? a['documento']?.toString() ?? '—')),
              const SizedBox(width: 16),
              Expanded(child: _buildInfoItem('CUIT', a['cuit']?.toString() ?? '—')),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: DesignTokens.outline.withOpacity(0.05), height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildInfoItem('RENAPA', a['renapa'] ?? '—', highlight: true)),
              const SizedBox(width: 16),
              Expanded(child: _buildInfoItem('TELÉFONO', a['telefono'] ?? '—')),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: DesignTokens.outline.withOpacity(0.05), height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildInfoItem('LOCALIDAD', a['localidad'] ?? '—', highlight: true)),
              const SizedBox(width: 16),
              Expanded(child: _buildInfoItem('PROVINCIA', a['provincia'] ?? '—')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: DesignTokens.labelStyle().copyWith(fontSize: 9, color: DesignTokens.onSurfaceVariant.withOpacity(0.5))),
        const SizedBox(height: 4),
        Text(
          value,
          style: DesignTokens.bodyStyle().copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: highlight ? DesignTokens.secondary : DesignTokens.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildPendienteCard(Map<String, dynamic> s) {
    final tipoRaw = s['tipo'] ?? 'Operación';
    final String tipo = tipoRaw.toString().toLowerCase().contains('recolecci') ? 'Recolección' : 'Distribución';
    final isRecoleccion = tipo == 'Recolección';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.secondary.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isRecoleccion ? DesignTokens.success.withOpacity(0.1) : DesignTokens.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isRecoleccion ? Icons.download_rounded : Icons.upload_rounded,
              color: isRecoleccion ? DesignTokens.success : DesignTokens.secondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s['producto_display'] ?? s['producto'] ?? 'Producto', style: DesignTokens.bodyStyle().copyWith(fontWeight: FontWeight.bold)),
                Text('${tipo} • Estimado: ${s['cantidad']} ${s['unidad_display'] ?? s['unidad'] ?? 'kg'}', 
                  style: DesignTokens.bodyStyle().copyWith(fontSize: 12, color: Colors.black38)
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(s['estado']).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(s['estado']?.toUpperCase() ?? 'PENDIENTE', 
              style: DesignTokens.labelStyle().copyWith(fontSize: 8, color: _getStatusColor(s['estado']), fontWeight: FontWeight.w900)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecienteCard(Map<String, dynamic> s) {
    final tipoRaw = s['tipo'] ?? 'Operación';
    final String tipo = tipoRaw.toString().toLowerCase().contains('recolecci') ? 'Recolección' : 'Distribución';
    final isRecoleccion = tipo == 'Recolección';
    final remito = s['remito_codigo'];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isRecoleccion ? Icons.download_done_rounded : Icons.upload_file_rounded,
              color: Colors.black26,
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s['producto_display'] ?? s['producto'] ?? 'Producto', style: DesignTokens.bodyStyle().copyWith(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('${tipo} • ${s['cantidad']} ${s['unidad_display'] ?? s['unidad'] ?? 'kg'}', 
                  style: DesignTokens.bodyStyle().copyWith(fontSize: 11, color: Colors.black38)
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (remito != null)
                Text('REMITO: $remito', style: DesignTokens.labelStyle().copyWith(fontSize: 8, color: DesignTokens.secondary, fontWeight: FontWeight.w900)),
              Text('TERMINADA', style: DesignTokens.labelStyle().copyWith(fontSize: 8, color: DesignTokens.success, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(dynamic estado) {
    final e = estado?.toString().toLowerCase() ?? '';
    if (e.contains('pendiente')) return DesignTokens.secondary;
    if (e.contains('asignada')) return Colors.blue;
    if (e.contains('en curso')) return Colors.orange;
    if (e.contains('terminada') || e.contains('finalizada')) return DesignTokens.success;
    return DesignTokens.secondary;
  }

  Widget _buildStatusOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: DesignTokens.primary.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Operaciones Totales', style: DesignTokens.labelStyle().copyWith(color: Colors.white70, fontSize: 12)),
              Icon(Icons.query_stats_rounded, color: Colors.white30, size: 20),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatusItem('PENDIENTES', _statusCounts['PENDIENTES'] ?? 0, DesignTokens.secondary),
              _buildStatusDivider(),
              _buildStatusItem('ASIGNADAS', _statusCounts['ASIGNADAS'] ?? 0, Colors.blue),
              _buildStatusDivider(),
              _buildStatusItem('EN CURSO', _statusCounts['EN CURSO'] ?? 0, Colors.orange),
              _buildStatusDivider(),
              _buildStatusItem('TERMINADAS', _statusCounts['TERMINADAS'] ?? 0, DesignTokens.success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, int count, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(count.toString(), style: DesignTokens.headlineStyle().copyWith(fontSize: 22, color: Colors.white)),
          const SizedBox(height: 4),
          Text(label, style: DesignTokens.labelStyle().copyWith(fontSize: 7, color: Colors.white54, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(height: 3, width: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        ],
      ),
    );
  }

  Widget _buildStatusDivider() {
    return Container(height: 30, width: 1, color: Colors.white10);
  }

  Widget _buildProductSummary() {
    return Column(
      children: _resumenDetallado.entries.map<Widget>((entry) {
        final product = entry.key;
        final totalsByType = entry.value;
        return _buildProductCardDetailed(product, totalsByType);
      }).toList(),
    );
  }

  Widget _buildProductSummaryPendiente() {
    return Column(
      children: _resumenPendiente.entries.map<Widget>((entry) {
        final product = entry.key;
        final totalsByType = entry.value;
        return _buildProductCardDetailedPendiente(product, totalsByType);
      }).toList(),
    );
  }

  Widget _buildProductCardDetailedPendiente(String product, Map<String, double> totalsByType) {
    final resolved = _resolveProductInfo(product);
    final String unitLabel = resolved['unidad'] ?? 'unidades';
    double total = totalsByType.values.fold(0, (sum, v) => sum + v);
    IconData icon = Icons.hive_rounded;
    Color iconColor = const Color(0xFFD97706); // Amber
    
    if (product.toLowerCase().contains('tambor')) icon = Icons.inventory_2_rounded;
    else if (product.toLowerCase().contains('alimento')) icon = Icons.eco_rounded;
    else if (product.toLowerCase().contains('cera')) icon = Icons.layers_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFEF3C7).withOpacity(0.5)), // Soft amber border
        boxShadow: [BoxShadow(color: const Color(0xFFD97706).withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              Row(
                children: totalsByType.entries.map((t) => Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: t.key.toLowerCase().contains('recolección') || t.key.toLowerCase().contains('entrega') 
                        ? const Color(0xFFFEF3C7) 
                        : const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${t.key}: ${NumberFormat('#,###', 'es_AR').format(t.value)}',
                    style: TextStyle(
                      fontSize: 10, 
                      fontWeight: FontWeight.bold, 
                      color: t.key.toLowerCase().contains('recolección') || t.key.toLowerCase().contains('entrega') 
                          ? const Color(0xFFD97706) 
                          : const Color(0xFF2563EB)
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(product.toUpperCase(), style: DesignTokens.labelStyle().copyWith(fontSize: 10, color: Colors.black38, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(NumberFormat('#,###', 'es_AR').format(total), 
                style: DesignTokens.headlineStyle().copyWith(fontSize: 28, fontWeight: FontWeight.w900, color: DesignTokens.primary)
              ),
              const SizedBox(width: 8),
              Text('${unitLabel.toLowerCase()} pendientes', style: DesignTokens.bodyStyle().copyWith(fontSize: 14, color: Colors.black26)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total / _maxTotalPendiente,
              backgroundColor: DesignTokens.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(iconColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCardDetailed(String product, Map<String, double> totalsByType) {
    final resolved = _resolveProductInfo(product);
    final String unitLabel = resolved['unidad'] ?? 'unidades';
    double total = totalsByType.values.fold(0, (sum, v) => sum + v);
    IconData icon = Icons.hive_rounded;
    Color iconColor = const Color(0xFFC68E17);
    
    if (product.toLowerCase().contains('tambor')) icon = Icons.inventory_2_rounded;
    else if (product.toLowerCase().contains('alimento')) icon = Icons.eco_rounded;
    else if (product.toLowerCase().contains('cera')) icon = Icons.layers_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.outline.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              // Totales por tipo en chips compactos
              Row(
                children: totalsByType.entries.map((t) => Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: t.key.toLowerCase().contains('recolección') || t.key.toLowerCase().contains('entrega') 
                        ? DesignTokens.success.withOpacity(0.1) 
                        : DesignTokens.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${t.key}: ${NumberFormat('#,###', 'es_AR').format(t.value)}',
                    style: TextStyle(
                      fontSize: 10, 
                      fontWeight: FontWeight.bold, 
                      color: t.key.toLowerCase().contains('recolección') || t.key.toLowerCase().contains('entrega') 
                          ? DesignTokens.success 
                          : DesignTokens.secondary
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(product.toUpperCase(), style: DesignTokens.labelStyle().copyWith(fontSize: 10, color: Colors.black38, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(NumberFormat('#,###', 'es_AR').format(total), 
                style: DesignTokens.headlineStyle().copyWith(fontSize: 28, fontWeight: FontWeight.w900, color: DesignTokens.primary)
              ),
              const SizedBox(width: 8),
              Text('${unitLabel.toLowerCase()} totales', style: DesignTokens.bodyStyle().copyWith(fontSize: 14, color: Colors.black26)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total / _maxTotal,
              backgroundColor: DesignTokens.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(iconColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildSectionHeader(String title, String? actionText, {bool showIcons = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(showIcons ? Icons.history_rounded : Icons.analytics_outlined, color: DesignTokens.secondary, size: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Text(title, 
                  overflow: TextOverflow.ellipsis,
                  style: DesignTokens.headlineStyle().copyWith(fontSize: 18, fontWeight: FontWeight.w400, color: const Color(0xFF424846))
                ),
              ),
            ],
          ),
        ),
        if (actionText != null)
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Generando informe detallado del apicultor...'), duration: Duration(seconds: 2))
              );
            },
            child: Text(actionText, style: DesignTokens.labelStyle().copyWith(color: DesignTokens.secondary, fontWeight: FontWeight.w900, fontSize: 10)),
          ),
        if (showIcons)
          Row(
            children: [
              _buildSmallIconAction(Icons.filter_list_rounded),
              const SizedBox(width: 12),
              _buildSmallIconAction(Icons.file_download_outlined),
            ],
          ),
      ],
    );
  }

  Widget _buildSmallIconAction(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Icon(icon, size: 18, color: Colors.black38),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DesignTokens.outline.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(Icons.assignment_outlined, size: 48, color: DesignTokens.primary.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(message, 
            textAlign: TextAlign.center,
            style: DesignTokens.bodyStyle().copyWith(color: Colors.black26, fontSize: 14)
          ),
        ],
      ),
    );
  }
}
