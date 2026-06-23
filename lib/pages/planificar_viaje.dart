import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../backend/supabase_service.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../backend/design_tokens.dart';
import '../backend/productos_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlanificarViajeWidget extends StatefulWidget {
  final String? editId;
  const PlanificarViajeWidget({super.key, this.editId});

  static String routeName = 'PlanificarViaje';
  static String routePath = '/planificarViaje';

  @override
  State<PlanificarViajeWidget> createState() => _PlanificarViajeWidgetState();
}

class _PlanificarViajeWidgetState extends State<PlanificarViajeWidget> {
  final _descripcionController = TextEditingController();
  final _searchController = TextEditingController();
  final _kmController = TextEditingController();
  
  List<Map<String, dynamic>> _necesidades = [];
  List<Map<String, dynamic>> _filteredNecesidades = [];
  final List<Map<String, dynamic>> _selectedNecesidades = [];
  List<Map<String, dynamic>> _vehiculos = [];
  List<Map<String, dynamic>> _choferes = [];
  
  Map<String, dynamic>? _selectedVehiculo;
  Map<String, dynamic>? _selectedChofer;
  DateTime _fechaPlanificada = DateTime.now();
  bool _loading = true;
  bool _saving = false;
  double _totalKg = 0;
  int _totalTambores = 0;
  double _distanciaEstimada = 0;

  bool _isUnitProduct(String? productCode) {
    if (productCode == null) return false;
    final codeClean = productCode.trim().toUpperCase();
    final match = ProductosData.masterCatalog.firstWhere(
      (p) => p['producto']?.toString().toUpperCase() == codeClean || p['codigo']?.toString() == codeClean,
      orElse: () => <String, dynamic>{},
    );
    if (match.isNotEmpty) {
      final String unidad = (match['unidad'] ?? '').toString().toLowerCase();
      return unidad.contains('uni') || unidad.contains('un');
    }
    final fallbackCode = codeClean.toLowerCase();
    return fallbackCode.contains('tcm') || 
           fallbackCode.contains('trr') || 
           fallbackCode.contains('tambor') || 
           fallbackCode.contains('uni') ||
           fallbackCode == '1' ||
           fallbackCode == '2';
  }

  @override
  void initState() {
    super.initState();
    _fetchData();
    _searchController.addListener(_filterNecesidades);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _descripcionController.dispose();
    _kmController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String userRole = (prefs.getString('user_puesto') ?? '').toLowerCase();
      final String userEmail = (prefs.getString('user_email') ?? '').toLowerCase();
      final bool isChofer = userRole.contains('chofer') || userEmail.contains('mperez') || userEmail.contains('cmuse') || userEmail.contains('agomez') || userEmail.contains('efernandez');
      
      if (isChofer && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Acceso denegado: los choferes no pueden planificar viajes.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        context.go('/home');
        return;
      }

      final service = SupabaseService();
      
      // Fetch needs: Pending ones always, and Planificadas only if we are editing (to show what's already in the trip)
      final List<Map<String, dynamic>> necData;
      if (widget.editId != null) {
        // Obtenemos las pendientes
        final pendientes = await service.getNecesidadesPendientes();
        // Obtenemos el viaje para ver qué solicitudes tiene ya asignadas
        final viaje = await service.getViajeDetalle(widget.editId!);
        final List<Map<String, dynamic>> asignadasAlViaje = [];
        
        if (viaje != null && viaje['paradas'] != null) {
          final List<String> solIds = [];
          for (var p in (viaje['paradas'] as List)) {
            if (p['solicitud_id'] != null) {
              solIds.add(p['solicitud_id'].toString());
            }
          }
          if (solIds.isNotEmpty) {
            // Buscamos estas solicitudes específicas aunque no estén pendientes,
            // pero excluimos las Eliminadas (no deben reaparecer en el planificador)
            final data = await Supabase.instance.client.from('solicitudes')
                .select('*, apicultores(*)')
                .filter('id', 'in', solIds)
                .neq('estado', 'Eliminada');
            asignadasAlViaje.addAll(List<Map<String, dynamic>>.from(data as List));
          }
        }
        
        // Unir listas sin duplicados
        final Map<String, Map<String, dynamic>> combined = {};
        for (var s in pendientes) {
          combined[s['id'].toString()] = s;
        }
        for (var s in asignadasAlViaje) {
          combined[s['id'].toString()] = s;
        }
        necData = combined.values.toList();
      } else {
        necData = await service.getNecesidadesPendientes();
      }
      
      final vehData = await service.getVehiculos(soloDisponibles: true, excluirViajeId: widget.editId);
      final choData = await service.getChoferes(soloDisponibles: true, excluirViajeId: widget.editId);

      if (mounted) {
        setState(() {
          // Asegurar IDs únicos para evitar duplicados visuales
          final Map<String, Map<String, dynamic>> uniqueMap = {};
          for (var item in necData) {
            if (item['id'] != null) uniqueMap[item['id'].toString()] = item;
          }
          final cleanedList = uniqueMap.values.toList();

          // Ordenar alfabéticamente
          cleanedList.sort((a, b) {
            final nameA = (a['apicultores']?['nombre'] ?? a['apicultor_nombre'] ?? '').toString().toLowerCase();
            final nameB = (b['apicultores']?['nombre'] ?? b['apicultor_nombre'] ?? '').toString().toLowerCase();
            return nameA.compareTo(nameB);
          });
          
          _necesidades = cleanedList;
          _filteredNecesidades = List.from(cleanedList);
          _vehiculos = vehData;
          _choferes = choData;
        });

        // Si estamos editando, cargar datos del viaje (Punto 10 del Workflow)
        if (widget.editId != null) {
          final viaje = await service.getViajeDetalle(widget.editId!);
          if (viaje != null) {
            setState(() {
              _descripcionController.text = viaje['descripcion'] ?? '';
              _fechaPlanificada = DateTime.tryParse(viaje['fecha'] ?? '') ?? DateTime.now();
              
              // Seleccionar vehículo y chofer
              if (viaje['vehiculo_codigo'] != null) {
                _selectedVehiculo = _vehiculos.firstWhere((v) => v['vehiculo_codigo'] == viaje['vehiculo_codigo'], orElse: () => _vehiculos.first);
              }
              if (viaje['chofer_id'] != null) {
                _selectedChofer = _choferes.firstWhere((c) => c['id'].toString() == viaje['chofer_id'].toString(), orElse: () => _choferes.first);
              }
              
              final paradas = viaje['paradas'] as List? ?? [];
              for (final p in paradas) {
                final pItems = p['parada_items'] as List? ?? [];
                // Intentar buscar por ID de solicitud primero (más preciso)
                final String? sId = p['solicitud_id']?.toString();
                
                final matched = _necesidades.firstWhere(
                  (n) {
                    if (sId != null && n['id']?.toString() == sId) return true;
                    // Fallback por ubicación y producto si no hay ID
                    final String pProd = pItems.isNotEmpty ? pItems[0]['producto_codigo'] ?? '' : '';
                    return (n['apicultores']?['nombre'] ?? n['apicultor_nombre'] ?? n['apicultor']) == p['ubicacion'] && 
                           n['producto'] == pProd;
                  },
                  orElse: () => <String, dynamic>{},
                );
                
                if (matched.isNotEmpty && !_selectedNecesidades.any((exist) => exist['id'] == matched['id'])) {
                  _selectedNecesidades.add(matched);
                }
              }
              _updateCalculos();
            });
          }
        }
        setState(() => _loading = false);
      }
    } catch (e) {
      // print('PlanificarViaje: Error en _fetchData: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filterNecesidades() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredNecesidades = List.from(_necesidades));
      return;
    }
    
    setState(() {
      _filteredNecesidades = _necesidades.where((n) {
        final apicultor = (n['apicultores']?['nombre'] ?? n['apicultor_nombre'] ?? '').toString().toLowerCase();
        final localidad = (n['apicultores']?['localidad'] ?? n['localidad_nombre'] ?? '').toString().toLowerCase();
        return apicultor.contains(query) || localidad.contains(query);
      }).toList();
    });
  }

  double _calcularDistanciaAutomatica() {
    if (_selectedNecesidades.isEmpty) return 0;
    
    final distanciasDesdePico = {
      'Trenel': 35.0,
      'Realicó': 105.0,
      'Intendente Alvear': 55.0,
      'Santa Rosa': 135.0,
      'Miramar': 610.0, 
      'Luján': 510.0,
      'Quemú Quemú': 90.0,
      'Caleufú': 120.0,
      'Colonia Seré': 150.0,
      'Colonia Sere': 150.0,
      'Balcarce': 580.0,
    };

    double maxDist = 0;
    for (final n in _selectedNecesidades) {
      final loc = n['apicultores']?['localidad'] ?? n['localidad_nombre'] ?? '';
      if (distanciasDesdePico.containsKey(loc)) {
        if (distanciasDesdePico[loc]! > maxDist) maxDist = distanciasDesdePico[loc]!;
      }
    }
    return maxDist * 2 * 1.15;
  }
  
  void _updateCalculos() {
    double tempKg = 0.0;
    int tempTambores = 0;
    
    for (final Map<String, dynamic> n in _selectedNecesidades) {
      final double cant = (n['cantidad'] ?? 0).toDouble();
      final String prod = (n['producto'] ?? '').toString().toUpperCase();
      
      if (prod == 'TCM' || prod.contains('TAMBOR CON MIEL')) {
        tempKg += cant * 300.0;
        tempTambores += cant.round();
      } 
      else if ((prod.startsWith('T') && prod != 'TV' && prod != 'TE') ||
          prod.contains('VACIO') ||
          prod.contains('VACÍO') ||
          prod.contains('TV') ||
          (prod.contains('TAMBOR') && !prod.contains('CERA'))) {
        tempTambores += cant.round();
        tempKg += cant * 20.0; 
      }
      else {
        tempKg += cant;
      }
    }
    
    setState(() {
      _totalKg = tempKg;
      _totalTambores = tempTambores;
      _distanciaEstimada = _calcularDistanciaAutomatica();
    });
  }

  bool get _excedeCapacidad {
    if (_selectedVehiculo == null) return false;
    final capKg = (_selectedVehiculo!['capacidad_kg'] ?? 0).toDouble();
    final capTambores = (_selectedVehiculo!['capacidad_tambores'] ?? 0);
    if (capKg > 0 && _totalKg > capKg) return true;
    if (capTambores > 0 && _totalTambores > capTambores) return true;
    return false;
  }

  Future<void> _openPreviewMap() async {
    const String baseLocation = 'General Pico, La Pampa, Argentina';
    
    final intermediateLocalities = _selectedNecesidades
        .map((n) {
          final String localidad = n['apicultores']?['localidad']?.toString() ?? n['localidad_nombre']?.toString() ?? n['localidad']?.toString() ?? '';
          final String provincia = n['apicultores']?['provincia']?.toString() ?? '';
          if (localidad.isEmpty) return '';
          return provincia.isNotEmpty ? '$localidad, $provincia, Argentina' : '$localidad, Argentina';
        })
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList();
    
    final String origin = Uri.encodeComponent(baseLocation);
    final String destination = Uri.encodeComponent(baseLocation);
    final String waypoints = intermediateLocalities.isNotEmpty 
        ? Uri.encodeComponent(intermediateLocalities.join('|'))
        : '';
    
    final url = 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&waypoints=$waypoints&travelmode=driving';
    
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalNonBrowserApplication);
    } catch (e) {
      // print('Error al abrir mapa: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir Google Maps.')));
      }
    }
  }

  Future<void> _crearViaje() async {
    if (_selectedVehiculo == null || _selectedChofer == null || _selectedNecesidades.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete todos los campos y seleccione necesidades')));
      return;
    }
    if (_excedeCapacidad) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: La carga excede la capacidad del vehículo'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _saving = true);
    try {
      if (widget.editId != null) {
        await SupabaseService().updateViajeCompleto(
          viajeId: widget.editId!,
          viajeData: {
            'chofer_id': _selectedChofer!['id'],
            'vehiculo_codigo': _selectedVehiculo!['vehiculo_codigo'],
            'fecha': _fechaPlanificada.toIso8601String(),
            'descripcion': _descripcionController.text,
          },
          necesidades: _selectedNecesidades,
        );
      } else {
        await SupabaseService().createViajeCompleto(
          viajeData: {
            'chofer_id': _selectedChofer!['id'],
            'vehiculo_codigo': _selectedVehiculo!['vehiculo_codigo'],
            'viaje_codigo': 'VIAJE-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
            'estado': 'Pendiente',
            'fecha': _fechaPlanificada.toIso8601String(),
            'descripcion': _descripcionController.text,
          },
          necesidades: _selectedNecesidades,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ruta planificada con éxito', style: TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.bold)), 
            backgroundColor: DesignTokens.secondary,
          )
        );
        context.pop();
      }
    } catch (e) {
      // print('PlanificarViaje: Error al crear viaje: $e');
      if (mounted) {
        String errorMsg = e.toString();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error al Planificar'),
            content: Text('Detalle técnico: $errorMsg\n\nPor favor reporte este error.'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
          )
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface,
        title: Text('Planificador de Ruta', style: DesignTokens.headlineStyle()),
        elevation: 0,
        iconTheme: const IconThemeData(color: DesignTokens.primary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Seleccionar Solicitudes', style: DesignTokens.headlineStyle(color: DesignTokens.primary).copyWith(fontSize: 18)),
            const SizedBox(height: 12),
            
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por apicultor, localidad o tipo...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
            const SizedBox(height: 12),

            Container(
              height: 280,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF08201A).withOpacity(0.1)),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: _filteredNecesidades.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final n = _filteredNecesidades[index];
                  final isSelected = _selectedNecesidades.any((element) => element['id'] == n['id']);
                  final String productoRaw = n['producto']?.toString() ?? 'Producto';
                  final String apicultorNombre = (n['apicultores']?['nombre'] ?? n['apicultor_nombre'] ?? n['apicultor'] ?? 'Sin Nombre').toString().toUpperCase();
                  final String localidad = (n['apicultores']?['localidad'] ?? n['localidad_nombre'] ?? n['localidad'] ?? 'Sin Localidad').toString();
                  final String tipo = n['tipo'] ?? 'S/T';
                  
                  final bool esUnidades = _isUnitProduct(productoRaw);
                  final String unidad = esUnidades ? 'Un.' : 'Kg';
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: DesignTokens.primary.withOpacity(isSelected ? 0.3 : 0.05), width: isSelected ? 1.5 : 1),
                    ),
                    child: CheckboxListTile(
                      value: isSelected,
                      activeColor: DesignTokens.secondary,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedNecesidades.add(n);
                          } else {
                            _selectedNecesidades.removeWhere((item) => item['id'] == n['id']);
                          }
                          _updateCalculos();
                        });
                      },
                      title: Text(apicultorNombre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      subtitle: Text('$productoRaw ($tipo) • $localidad', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      secondary: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${n['cantidad']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                          Text(unidad.toUpperCase(), style: const TextStyle(fontSize: 8)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _excedeCapacidad ? const Color(0xFFFFEBEE) : const Color(0xFFF0F4F3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _excedeCapacidad ? Colors.red.withOpacity(0.3) : Colors.transparent),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(children: [const Text('KG TOTAL'), Text('${_totalKg.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))]),
                      Column(children: [const Text('TAMBORES'), Text('$_totalTambores', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))]),
                      Column(children: [const Text('KM EST.'), Text('${_distanciaEstimada.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))]),
                    ],
                  ),
                  if (_selectedNecesidades.isNotEmpty) ...[
                    const Divider(height: 24),
                    SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _openPreviewMap, icon: const Icon(Icons.map_rounded), label: const Text('VER RECORRIDO'), style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.primary, foregroundColor: Colors.white))),
                  ]
                ],
              ),
            ),

            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTextField(label: 'Descripción del Viaje', controller: _descripcionController, hint: 'Ej: Recolección Zona Norte...'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Fecha Planificada', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF424846))),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context, 
                            initialDate: _fechaPlanificada, 
                            firstDate: DateTime.now().subtract(const Duration(days: 365)), 
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            locale: const Locale('es', 'AR'),
                          );
                          if (date != null) setState(() => _fechaPlanificada = date);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF08201A).withOpacity(0.1))),
                          child: Text(DateFormat('dd/MM/yy').format(_fechaPlanificada), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            Text('2. Logística', style: DesignTokens.headlineStyle(color: DesignTokens.primary).copyWith(fontSize: 18)),
            const SizedBox(height: 12),
            
            _buildDropdown<String>(
              label: 'Vehículo',
              hint: 'Seleccione un vehículo...',
              value: _selectedVehiculo?['id']?.toString(),
              items: _vehiculos.map((v) {
                String display = v['vehiculo_codigo']?.toString() ?? '';
                // Limpia el texto eliminando lo que esté entre paréntesis (ej: MB 1634 (Taller) -> MB 1634)
                if (display.contains('(')) {
                  display = display.split('(')[0].trim();
                }
                return DropdownMenuItem(
                  value: v['id'].toString(), 
                  child: Text(display)
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedVehiculo = _vehiculos.firstWhere((e) => e['id'].toString() == v)),
            ),
            
            const SizedBox(height: 16),
            
            _buildDropdown<String>(
              label: 'Chofer',
              hint: 'Seleccione un chofer...',
              value: _selectedChofer?['id']?.toString(),
              items: _choferes.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text('${c['nombre']} ${c['apellido']}'))).toList(),
              onChanged: (v) => setState(() => _selectedChofer = _choferes.firstWhere((e) => e['id'].toString() == v)),
            ),

            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _saving ? null : _crearViaje,
                style: DesignTokens.primaryButtonStyle,
                child: _saving 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : Text(widget.editId != null ? 'GUARDAR CAMBIOS' : 'PLANIFICAR VIAJE'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({required String label, required TextEditingController controller, String? hint, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF424846))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: const Color(0xFF08201A).withOpacity(0.1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: const Color(0xFF08201A).withOpacity(0.1))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({required String label, String? hint, T? value, required List<DropdownMenuItem<T>> items, required void Function(T?) onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF424846))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF08201A).withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              hint: hint != null ? Text(hint, style: const TextStyle(fontSize: 14, color: Colors.black45)) : null,
              value: value,
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
