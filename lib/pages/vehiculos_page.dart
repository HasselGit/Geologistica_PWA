import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../backend/supabase_service.dart';
import '../backend/design_tokens.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

class VehiculosPageWidget extends StatefulWidget {
  const VehiculosPageWidget({super.key});

  @override
  State<VehiculosPageWidget> createState() => _VehiculosPageWidgetState();
}

class _VehiculosPageWidgetState extends State<VehiculosPageWidget> {
  List<Map<String, dynamic>> _vehiculos = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  int _currentPage = 0;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    
    try {
      final box = await Hive.openBox('vehiculosCache');
      if (box.containsKey('data')) {
        final cached = box.get('data');
        if (cached != null && cached is List && mounted) {
          final parsed = List<Map<String, dynamic>>.from(
            cached.map((e) => Map<String, dynamic>.from(e as Map))
          );
          setState(() {
            _vehiculos = parsed;
            _filtered = parsed;
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Hive cache error: $e');
    }

    try {
      final data = await SupabaseService().getVehiculos();
      if (mounted) {
        setState(() {
          _vehiculos = data;
          _filtered = data;
          _loading = false;
          _currentPage = 0;
        });

        try {
          final box = await Hive.openBox('vehiculosCache');
          await box.put('data', data);
        } catch (e) {
          debugPrint('Hive save error: $e');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    // Check local cache first
    final query = val.toLowerCase();
    final localMatches = _vehiculos.where((v) {
      final codigo = (v['vehiculo_codigo'] ?? v['codigo'] ?? '').toString().toLowerCase();
      final patente = (v['patente'] ?? '').toString().toLowerCase();
      final modelo = (v['modelo'] ?? '').toString().toLowerCase();
      return codigo.contains(query) || patente.contains(query) || modelo.contains(query);
    }).toList();

    if (localMatches.isNotEmpty || query.isEmpty) {
      setState(() {
        _filtered = localMatches;
        _currentPage = 0;
      });
      return;
    }

    // If local cache doesn't have it, debounce 400ms for Supabase deep search
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _loading = true);
      try {
        final response = await Supabase.instance.client
            .from('vehiculos')
            .select()
            .or('vehiculo_codigo.ilike.%$query%,patente.ilike.%$query%,modelo.ilike.%$query%');
            
        if (mounted) {
          setState(() {
            _filtered = List<Map<String, dynamic>>.from(response);
            _currentPage = 0;
            _loading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _filtered = [];
            _loading = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DesignTokens.primary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Gestión de Vehículos',
          style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold, color: DesignTokens.primary),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(fontFamily: 'Inter'),
                  decoration: InputDecoration(
                    hintText: 'Buscar por código, patente o modelo...',
                    hintStyle: const TextStyle(color: Colors.black45),
                    prefixIcon: const Icon(Icons.search, color: DesignTokens.primary),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), 
                      borderSide: BorderSide(color: DesignTokens.surfaceLow, width: 1.5)
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), 
                      borderSide: BorderSide(color: DesignTokens.surfaceLow, width: 1.5)
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), 
                      borderSide: const BorderSide(color: DesignTokens.primary, width: 2)
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _loading && _filtered.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 900) {
                          return _buildWebTable();
                        } else {
                          return _buildMobileList();
                        }
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addVehiculo,
        backgroundColor: DesignTokens.secondary,
        child: const Icon(Icons.add, color: DesignTokens.primary),
      ),
    );
  }

  Widget _buildWebTable() {
    final int totalPages = (_filtered.length / _itemsPerPage).ceil();
    final int startIndex = _currentPage * _itemsPerPage;
    final int endIndex = (startIndex + _itemsPerPage).clamp(0, _filtered.length);
    final List<Map<String, dynamic>> currentItems = _filtered.sublist(startIndex, endIndex);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DesignTokens.surfaceLow, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: DesignTokens.primary.withValues(alpha: 0.02), 
                    blurRadius: 10,
                    offset: const Offset(0, 4)
                  )
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF08201A).withValues(alpha: 0.02),
                              const Color(0xFFC68E17).withValues(alpha: 0.02),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Icon(
                      Icons.local_shipping_rounded,
                      size: 120,
                      color: const Color(0xFF08201A).withValues(alpha: 0.03),
                    ),
                  ),
                  ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(DesignTokens.surfaceLow.withValues(alpha: 0.5)),
                  dataRowMinHeight: 64,
                  dataRowMaxHeight: 64,
                  columns: const [
                    DataColumn(label: Text('CÓDIGO', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 12, color: DesignTokens.onSurfaceVariant))),
                    DataColumn(label: Text('MODELO', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 12, color: DesignTokens.onSurfaceVariant))),
                    DataColumn(label: Text('PATENTE', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 12, color: DesignTokens.onSurfaceVariant))),
                    DataColumn(label: Text('CAPACIDAD', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 12, color: DesignTokens.onSurfaceVariant))),
                    DataColumn(label: Text('ACCIÓN', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 12, color: DesignTokens.onSurfaceVariant))),
                  ],
                  rows: currentItems.map((v) {
                    final codigo = v['vehiculo_codigo'] ?? v['codigo'] ?? 'S/D';
                    final modelo = v['modelo'] ?? 'Modelo desconocido';
                    final patente = v['patente'] ?? 'S/P';
                    final capKg = v['capacidad_kg']?.toString() ?? '0';

                    return DataRow(
                      cells: [
                        DataCell(Text(codigo, style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, color: DesignTokens.onSurface))),
                        DataCell(Text(modelo, style: const TextStyle(fontFamily: 'Inter', color: DesignTokens.onSurfaceVariant))),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: DesignTokens.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                          child: Text(patente, style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, fontWeight: FontWeight.w600, color: DesignTokens.primary)),
                        )),
                        DataCell(Text('$capKg kg', style: const TextStyle(fontFamily: 'Inter', color: DesignTokens.onSurfaceVariant))),
                        DataCell(
                          TextButton.icon(
                            icon: const Icon(Icons.visibility_rounded, size: 18),
                            label: const Text('Ver Detalles', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                            style: TextButton.styleFrom(
                              foregroundColor: DesignTokens.secondary,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: () => context.push('/vehiculoDetalle?id=${v['id']}'),
                          )
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
                ],
              ),
            ),
          ),
        ),
        if (totalPages > 1)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: DesignTokens.surface,
              border: Border(top: BorderSide(color: DesignTokens.surfaceLow)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Mostrando ${startIndex + 1} - $endIndex de ${_filtered.length}',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: DesignTokens.onSurfaceVariant),
                ),
                const SizedBox(width: 24),
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: _currentPage > 0 ? DesignTokens.primary : Colors.grey,
                  onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                ),
                Text(
                  'Página ${_currentPage + 1} de $totalPages',
                  style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: DesignTokens.onSurface),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: _currentPage < totalPages - 1 ? DesignTokens.primary : Colors.grey,
                  onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMobileList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FLOTA ACTIVA',
            style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 11, color: DesignTokens.onSurfaceVariant, letterSpacing: 1.5),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _buildVehicleCard(_filtered[index]);
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> v) {
    final codigo = v['vehiculo_codigo'] ?? v['codigo'] ?? 'S/D';
    final modelo = v['modelo'] ?? 'Modelo desconocido';
    final patente = v['patente'] ?? 'S/P';
    final capKg = v['capacidad_kg']?.toString() ?? '0';
    final capTamb = v['capacidad_tambores']?.toString() ?? '0';

    return GestureDetector(
      onTap: () => context.push('/vehiculoDetalle?id=${v['id']}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DesignTokens.surfaceLow, width: 1.5),
          boxShadow: [
            BoxShadow(color: DesignTokens.primary.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 100,
              height: 120,
              decoration: const BoxDecoration(
                color: Color(0xFFF5F3F3),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
              ),
              child: const Center(
                child: Icon(Icons.local_shipping_rounded, size: 40, color: DesignTokens.primary),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          codigo,
                          style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 18, color: DesignTokens.primary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: DesignTokens.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                          child: Text(patente, style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 10, fontWeight: FontWeight.w700, color: DesignTokens.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(modelo, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: DesignTokens.onSurfaceVariant)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _specItem(Icons.scale_rounded, '$capKg kg'),
                        const SizedBox(width: 16),
                        _specItem(Icons.inventory_2_rounded, '$capTamb tamb'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addVehiculo() {
    final codigoController = TextEditingController();
    final patenteController = TextEditingController();
    final modeloController = TextEditingController();
    final capKgController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.pop(context);
            } else if (event.logicalKey == LogicalKeyboardKey.enter && HardwareKeyboard.instance.isControlPressed) {
              _saveVehiculo(codigoController, patenteController, modeloController, capKgController);
            }
          }
        },
        child: Container(
          decoration: const BoxDecoration(color: DesignTokens.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Nuevo Vehículo', style: TextStyle(fontFamily: 'Manrope', fontSize: 22, fontWeight: FontWeight.w800, color: DesignTokens.primary)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Cerrar (Esc)',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _input(codigoController, 'Código (ej: V-01)', Icons.qr_code_rounded),
              const SizedBox(height: 16),
              _input(patenteController, 'Patente', Icons.credit_card_rounded),
              const SizedBox(height: 16),
              _input(modeloController, 'Modelo/Marca', Icons.branding_watermark_rounded),
              const SizedBox(height: 16),
              _input(capKgController, 'Capacidad (KG)', Icons.scale_rounded, isNumeric: true),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => _saveVehiculo(codigoController, patenteController, modeloController, capKgController),
                  style: DesignTokens.primaryButtonStyle,
                  child: const Text('GUARDAR VEHÍCULO', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text('Atajo: Ctrl + Enter para guardar', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveVehiculo(
      TextEditingController codigoController, 
      TextEditingController patenteController, 
      TextEditingController modeloController, 
      TextEditingController capKgController) async {
    if (codigoController.text.isEmpty) return;
    
    await Supabase.instance.client.from('vehiculos').insert({
      'vehiculo_codigo': codigoController.text,
      'patente': patenteController.text,
      'modelo': modeloController.text,
      'capacidad_kg': double.tryParse(capKgController.text) ?? 0,
    });
    if (mounted) {
      Navigator.pop(context);
      _fetchData();
    }
  }

  Widget _input(TextEditingController controller, String label, IconData icon, {bool isNumeric = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontFamily: 'Inter'),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: DesignTokens.onSurfaceVariant),
        prefixIcon: Icon(icon, size: 22, color: DesignTokens.primary.withValues(alpha: 0.7)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: DesignTokens.surfaceLow, width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: DesignTokens.surfaceLow, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DesignTokens.primary, width: 2)),
      ),
    );
  }

  Widget _specItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: DesignTokens.secondary),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: DesignTokens.onSurface)),
      ],
    );
  }
}
