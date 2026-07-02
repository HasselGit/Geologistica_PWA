import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../backend/supabase_service.dart';
import '../backend/design_tokens.dart';
import '../backend/app_states.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:math';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'gastos_detalle.dart';

class SaveIntent extends Intent { const SaveIntent(); }
class ClearIntent extends Intent { const ClearIntent(); }

class GastosPageWidget extends StatefulWidget {
  const GastosPageWidget({super.key});

  @override
  State<GastosPageWidget> createState() => _GastosPageWidgetState();
}

class _GastosPageWidgetState extends State<GastosPageWidget> {
  // Web Form state
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  final _comprobanteController = TextEditingController();
  final _litrosController = TextEditingController();

  final _amountFocus = FocusNode();
  final _descFocus = FocusNode();
  final _comprobanteFocus = FocusNode();
  final _litrosFocus = FocusNode();

  String? _selectedTipoWeb = 'Combustible';
  String? _selectedMetodoWeb = 'Efectivo';
  DateTime _selectedFechaWeb = DateTime.now();
  String? _selectedViajeIdWeb;
  PlatformFile? _pickedFileWeb;
  int _currentPageWeb = 0;
  final int _rowsPerPageWeb = 15;
  bool _savingForm = false;

  List<Map<String, dynamic>> _gastos = [];
  List<Map<String, dynamic>> _viajesParaGasto = [];
  bool _loading = true;
  String _searchQuery = '';
  bool _isChofer = false;
  String? _selectedCategoryFilter;

  List<Map<String, dynamic>> get _filteredGastos {
    List<Map<String, dynamic>> list = _gastos;
    
    // Filtro por categoría seleccionada
    if (_selectedCategoryFilter != null && _selectedCategoryFilter != 'Todos') {
      list = list.where((g) => (g['tipo_gasto'] ?? '').toString().toLowerCase() == _selectedCategoryFilter!.toLowerCase()).toList();
    }
    
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((g) {
      final tipo = (g['tipo_gasto'] ?? '').toString().toLowerCase();
      final importe = (g['importe'] ?? '').toString().toLowerCase();
      final chofer = g['profiles'] != null ? '${g['profiles']['nombre']} ${g['profiles']['apellido']}'.toLowerCase() : '';
      final viaje = (g['viajes']?['viaje_codigo'] ?? '').toString().toLowerCase();
      final descripcion = (g['descripcion'] ?? '').toString().toLowerCase();
      return tipo.contains(q) || importe.contains(q) || chofer.contains(q) || viaje.contains(q) || descripcion.contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    // Detectar si el usuario es chofer para filtrar sus viajes
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final userRole = (prefs.getString('user_puesto') ?? '').toLowerCase();
    final userEmail = (prefs.getString('user_email') ?? '').toLowerCase();
    final isChofer = userRole.contains('chofer') ||
        userEmail.contains('mperez') || userEmail.contains('cmuse') ||
        userEmail.contains('agomez') || userEmail.contains('efernandez');

    List<Map<String, dynamic>> data = await SupabaseService().getGastos();

    var query = Supabase.instance.client
        .from('viajes')
        .select('id, viaje_codigo, estado, chofer_id')
        .filter('estado', 'in', ['En Proceso', 'En Curso', 'Terminado'])
        .order('fecha', ascending: false)
        .limit(40);

    // Los choferes solo ven sus propios viajes en curso (En Proceso / En Curso)
    if (isChofer && userId != null && userId.isNotEmpty) {
      query = Supabase.instance.client
          .from('viajes')
          .select('id, viaje_codigo, estado, chofer_id')
          .filter('estado', 'in', ['En Proceso', 'En Curso'])
          .eq('chofer_id', userId)
          .order('fecha', ascending: false)
          .limit(20);

      // Si es chofer, filtrar gastos para ver solo los vinculados a su viaje actual en proceso
      data = data.where((g) {
        final viaje = g['viajes'];
        if (viaje == null) return false;
        final choferId = viaje['chofer_id']?.toString();
        final estado = AppStates.normalize(viaje['estado']?.toString());
        return choferId == userId && estado == AppStates.enCurso;
      }).toList();
    }
    final viajesRaw = await query;
    if (mounted) {
      setState(() {
        _isChofer = isChofer;
        _gastos = data;
        _viajesParaGasto = List<Map<String, dynamic>>.from(viajesRaw);
        _loading = false;
      });
    }
  }

  double _getCategoryTotal(String value) {
    if (value == 'Todos') {
      return _gastos.fold(0.0, (sum, g) => sum + (double.tryParse(g['importe']?.toString() ?? '0') ?? 0.0));
    }
    if (value == 'Otros') {
      return _gastos
          .where((g) {
            final t = (g['tipo_gasto'] ?? '').toString().toLowerCase();
            return t != 'combustible' && t != 'comida' && t != 'peaje' && t != 'reparación' && t != 'reparacion';
          })
          .fold(0.0, (sum, g) => sum + (double.tryParse(g['importe']?.toString() ?? '0') ?? 0.0));
    }
    return _gastos
        .where((g) => (g['tipo_gasto'] ?? '').toString().toLowerCase() == value.toLowerCase())
        .fold(0.0, (sum, g) => sum + (double.tryParse(g['importe']?.toString() ?? '0') ?? 0.0));
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color backgroundColor,
    required Color textColor,
    required Color accentColor,
    Color? borderColor,
  }) {
    return Container(
      width: 175,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: borderColor != null ? Border.all(color: borderColor, width: 1) : null,
        boxShadow: backgroundColor == Colors.white 
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))]
            : [BoxShadow(color: DesignTokens.primary.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
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
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: backgroundColor == Colors.white ? Colors.grey : Colors.white70,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(icon, size: 20, color: accentColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: textColor,
              fontFamily: 'Manrope',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: backgroundColor == Colors.white ? DesignTokens.onSurfaceVariant : Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIPanel() {
    double totalGasto = 0.0;
    double combustibleMonto = 0.0;
    double combustibleLitros = 0.0;

    for (var g in _gastos) {
      final imp = double.tryParse(g['importe']?.toString() ?? '0') ?? 0.0;
      totalGasto += imp;
      
      final tipo = (g['tipo_gasto'] ?? '').toString().toLowerCase();
      if (tipo.contains('combustible')) {
        combustibleMonto += imp;
        combustibleLitros += (g['cantidad_litros'] as num?)?.toDouble() ?? 0.0;
      }
    }

    return Container(
      height: 140,
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildKPICard(
            title: 'GASTO TOTAL',
            value: '\$${totalGasto.toStringAsFixed(0)}',
            subtitle: '${_gastos.length} comprobantes',
            icon: Icons.payments_rounded,
            backgroundColor: DesignTokens.primary,
            textColor: Colors.white,
            accentColor: DesignTokens.secondary,
          ),
          _buildKPICard(
            title: 'COMBUSTIBLE',
            value: '\$${combustibleMonto.toStringAsFixed(0)}',
            subtitle: '${combustibleLitros.toStringAsFixed(1)} Litros',
            icon: Icons.local_gas_station_rounded,
            backgroundColor: Colors.white,
            textColor: DesignTokens.primary,
            accentColor: DesignTokens.secondary,
            borderColor: DesignTokens.primary.withValues(alpha: 0.08),
          ),
          _buildKPICard(
            title: 'OTROS RUBROS',
            value: '\$${(totalGasto - combustibleMonto).toStringAsFixed(0)}',
            subtitle: 'Comida/Peaje/Rep.',
            icon: Icons.category_rounded,
            backgroundColor: Colors.white,
            textColor: DesignTokens.primary,
            accentColor: DesignTokens.primary.withValues(alpha: 0.5),
            borderColor: DesignTokens.primary.withValues(alpha: 0.08),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterRow() {
    final categories = [
      {'label': 'Todos', 'value': 'Todos', 'icon': Icons.all_inclusive_rounded},
      {'label': 'Combustible', 'value': 'Combustible', 'icon': Icons.local_gas_station_rounded},
      {'label': 'Comida', 'value': 'Comida', 'icon': Icons.restaurant_rounded},
      {'label': 'Peaje', 'value': 'Peaje', 'icon': Icons.toll_rounded},
      {'label': 'Reparación', 'value': 'Reparación', 'icon': Icons.build_rounded},
      {'label': 'Otros', 'value': 'Otros', 'icon': Icons.more_horiz_rounded},
    ];

    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final label = cat['label'] as String;
          final val = cat['value'] as String;
          final icon = cat['icon'] as IconData;
          
          final isSelected = (_selectedCategoryFilter == null && val == 'Todos') || (_selectedCategoryFilter == val);
          final totalCat = _getCategoryTotal(val);
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              showCheckmark: false,
              avatar: Icon(
                icon, 
                size: 14, 
                color: isSelected ? Colors.white : DesignTokens.primary.withValues(alpha: 0.7)
              ),
              label: Text(
                '$label (\$${totalCat.toStringAsFixed(0)})',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Work Sans',
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : DesignTokens.primary,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategoryFilter = val == 'Todos' ? null : val;
                });
              },
              selectedColor: DesignTokens.primary,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? Colors.transparent : DesignTokens.primary.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              elevation: 0,
              pressElevation: 0,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: DesignTokens.primary.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 64,
                  color: DesignTokens.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Sin Gastos Registrados',
                style: DesignTokens.headlineStyle().copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                _isChofer 
                    ? 'No se encontraron gastos vinculados a tu viaje actual en proceso.' 
                    : 'No se encontraron gastos con los filtros aplicados o no hay registros aún.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.enter): const SaveIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const ClearIntent(),
      },
      child: Actions(
        actions: {
          SaveIntent: CallbackAction<SaveIntent>(onInvoke: (intent) => _saveGastoWeb()),
          ClearIntent: CallbackAction<ClearIntent>(onInvoke: (intent) => _clearWebForm()),
        },
        child: Scaffold(
          backgroundColor: DesignTokens.surface,
          appBar: AppBar(
            backgroundColor: DesignTokens.surface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: DesignTokens.primary),
              onPressed: () => context.go('/home'),
            ),
            title: const Text(
              'Gestión de Gastos',
              style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold, color: DesignTokens.primary),
            ),
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 900) {
                return _buildWebLayout();
              }
              return _buildMobileLayout();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: DesignTokens.secondary));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildKPIPanel(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar por chofer, viaje, comprobante, observaciones...',
              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Inter'),
              prefixIcon: const Icon(Icons.search, color: DesignTokens.primary, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.primary.withValues(alpha: 0.1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.primary.withValues(alpha: 0.08))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: DesignTokens.accent, width: 1.5)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
          ),
        ),
        _buildCategoryFilterRow(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'REGISTROS MOSTRADOS (${_filteredGastos.length})', 
                style: const TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 11, color: DesignTokens.onSurfaceVariant, letterSpacing: 0.5)
              ),
              Text(
                'Total: \$${_filteredGastos.fold(0.0, (sum, g) => sum + (double.tryParse(g['importe']?.toString() ?? '0') ?? 0.0)).toStringAsFixed(2)}', 
                style: const TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w900, fontSize: 15, color: DesignTokens.primary)
              ),
            ],
          ),
        ),
        Expanded(
          child: _filteredGastos.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: _filteredGastos.length,
                  itemBuilder: (context, index) {
                    final g = _filteredGastos[index];
                    return _buildGastoCard(g);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildWebLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: DesignTokens.primary.withValues(alpha: 0.1))),
            ),
            child: _buildWebForm(),
          ),
        ),
        Expanded(
          flex: 2,
          child: _buildWebRightPanel(),
        ),
      ],
    );
  }

  Widget _buildWebRightPanel() {
    final startIndex = _currentPageWeb * _rowsPerPageWeb;
    final endIndex = min(startIndex + _rowsPerPageWeb, _filteredGastos.length);
    final currentItems = _filteredGastos.sublist(startIndex, endIndex);
    final totalPages = (_filteredGastos.length / _rowsPerPageWeb).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24, left: 24, right: 24),
          child: _buildKPIPanel(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCategoryFilterRow(),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DesignTokens.outline.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 40, offset: const Offset(0, 4))
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
                      Icons.receipt_long_rounded,
                      size: 120,
                      color: const Color(0xFF08201A).withValues(alpha: 0.03),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(DesignTokens.surfaceLow.withValues(alpha: 0.5)),
                          dataRowMinHeight: 60,
                          dataRowMaxHeight: 60,
                          columns: const [
                            DataColumn(label: Text('FECHA', style: TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Manrope', color: DesignTokens.primary, fontSize: 13))),
                            DataColumn(label: Text('TIPO', style: TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Manrope', color: DesignTokens.primary, fontSize: 13))),
                            DataColumn(label: Text('IMPORTE', style: TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Manrope', color: DesignTokens.primary, fontSize: 13))),
                            DataColumn(label: Text('CHOFER', style: TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Manrope', color: DesignTokens.primary, fontSize: 13))),
                            DataColumn(label: Text('ACCIÓN', style: TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Manrope', color: DesignTokens.primary, fontSize: 13))),
                          ],
                          rows: currentItems.map((g) {
                            final tipo = g['tipo_gasto'] ?? 'Gasto';
                            final importe = g['importe']?.toString() ?? '0';
                            final fecha = DateTime.tryParse(g['fecha']?.toString() ?? '') ?? DateTime.now();
                            final fechaStr = DateFormat('dd/MM/yyyy').format(fecha);
                            final chofer = g['profiles'] != null ? '${g['profiles']['nombre']} ${g['profiles']['apellido']}' : 'S/D';
                            
                            return DataRow(
                              cells: [
                                DataCell(Text(fechaStr, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'JetBrains Mono'))),
                                DataCell(Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: DesignTokens.secondary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                                  child: Text(tipo.toUpperCase(), style: const TextStyle(color: Color(0xFF7D5700), fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold)),
                                )),
                                DataCell(Text('\$ $importe', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'JetBrains Mono', color: DesignTokens.primary, fontSize: 16))),
                                DataCell(Text(chofer, style: const TextStyle(fontFamily: 'Inter', color: DesignTokens.onSurfaceVariant))),
                                DataCell(
                                  TextButton.icon(
                                    icon: const Icon(Icons.visibility_rounded, size: 18),
                                    label: const Text('Ver Detalle', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                                    style: TextButton.styleFrom(
                                      foregroundColor: DesignTokens.secondary,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _showGastoDetailDialog(context, g),
                                  )
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      if (totalPages > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: DesignTokens.outline.withValues(alpha: 0.1))),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Mostrando ${startIndex + 1} - $endIndex de ${_filteredGastos.length}',
                                style: const TextStyle(color: DesignTokens.onSurfaceVariant, fontSize: 13, fontFamily: 'Inter'),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left_rounded),
                                    onPressed: _currentPageWeb > 0 ? () => setState(() => _currentPageWeb--) : null,
                                    color: _currentPageWeb > 0 ? DesignTokens.primary : DesignTokens.outline,
                                  ),
                                  Text(
                                    'Página ${_currentPageWeb + 1} de $totalPages',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Inter'),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right_rounded),
                                    onPressed: _currentPageWeb < totalPages - 1 ? () => setState(() => _currentPageWeb++) : null,
                                    color: _currentPageWeb < totalPages - 1 ? DesignTokens.primary : DesignTokens.outline,
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWebForm() {
    if (_selectedViajeIdWeb == null && _viajesParaGasto.isNotEmpty) {
      final viajeEnCurso = _viajesParaGasto.where((v) {
        final est = (v['estado'] ?? '').toString().toLowerCase();
        return est.contains('proceso') || est.contains('curso');
      }).toList();
      if (viajeEnCurso.isNotEmpty) {
        _selectedViajeIdWeb = viajeEnCurso.first['id']?.toString();
      }
    }

    final inputBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: DesignTokens.primary.withValues(alpha: 0.05)));
    final focusBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DesignTokens.accent, width: 2));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Registrar Nuevo Gasto', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Manrope', color: DesignTokens.primary)),
        const SizedBox(height: 8),
        const Text('Presione Ctrl+Enter para guardar, Esc para limpiar', style: TextStyle(fontSize: 12, fontFamily: 'Inter', color: DesignTokens.onSurfaceVariant)),
        const SizedBox(height: 24),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedFechaWeb,
                            firstDate: DateTime(2024),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setState(() => _selectedFechaWeb = picked);
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Fecha',
                            labelStyle: const TextStyle(fontFamily: 'Inter'),
                            prefixIcon: const Icon(Icons.calendar_today_rounded, color: DesignTokens.primary),
                            filled: true,
                            fillColor: DesignTokens.surfaceLow,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            enabledBorder: inputBorder,
                            focusedBorder: focusBorder,
                          ),
                          child: Text(DateFormat('dd/MM/yyyy').format(_selectedFechaWeb), style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'JetBrains Mono')),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _comprobanteController,
                        focusNode: _comprobanteFocus,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => FocusScope.of(context).requestFocus(_amountFocus),
                        style: const TextStyle(fontFamily: 'Inter'),
                        decoration: InputDecoration(
                          labelText: 'N° Comprobante',
                          labelStyle: const TextStyle(fontFamily: 'Inter'),
                          prefixIcon: const Icon(Icons.receipt_rounded, color: DesignTokens.primary),
                          filled: true,
                          fillColor: DesignTokens.surfaceLow,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          enabledBorder: inputBorder,
                          focusedBorder: focusBorder,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedTipoWeb,
                  decoration: InputDecoration(
                    labelText: 'Tipo de Gasto',
                    labelStyle: const TextStyle(fontFamily: 'Inter'),
                    prefixIcon: const Icon(Icons.category_rounded, color: DesignTokens.primary),
                    filled: true,
                    fillColor: DesignTokens.surfaceLow,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    enabledBorder: inputBorder,
                    focusedBorder: focusBorder,
                  ),
                  items: ['Combustible', 'Comida', 'Peaje', 'Reparación', 'Otros']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontFamily: 'Inter'))))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedTipoWeb = v),
                ),
                if (_selectedTipoWeb == 'Combustible') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _litrosController,
                    focusNode: _litrosFocus,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => FocusScope.of(context).requestFocus(_descFocus),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontFamily: 'Inter'),
                    decoration: InputDecoration(
                      labelText: 'Cantidad en Litros (L)',
                      labelStyle: const TextStyle(fontFamily: 'Inter'),
                      prefixIcon: const Icon(Icons.local_gas_station_rounded, color: DesignTokens.primary),
                      filled: true,
                      fillColor: DesignTokens.surfaceLow,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: inputBorder,
                      focusedBorder: focusBorder,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedViajeIdWeb,
                  decoration: InputDecoration(
                    labelText: 'Vincular a Viaje',
                    labelStyle: const TextStyle(fontFamily: 'Inter'),
                    prefixIcon: const Icon(Icons.local_shipping_rounded, color: DesignTokens.primary),
                    filled: true,
                    fillColor: DesignTokens.surfaceLow,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    enabledBorder: inputBorder,
                    focusedBorder: focusBorder,
                  ),
                  hint: const Text('Seleccione un viaje...', style: TextStyle(fontFamily: 'Inter')),
                  items: _viajesParaGasto.map((v) => DropdownMenuItem<String>(
                    value: v['id']?.toString(),
                    child: Text('${v['viaje_codigo'] ?? 'S/C'} (${v['estado'] ?? ''})', style: const TextStyle(fontFamily: 'Inter')),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedViajeIdWeb = v),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _amountController,
                        focusNode: _amountFocus,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => FocusScope.of(context).requestFocus(_descFocus),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'Importe (\$)',
                          labelStyle: const TextStyle(fontFamily: 'Inter'),
                          prefixIcon: const Icon(Icons.attach_money_rounded, color: DesignTokens.primary),
                          filled: true,
                          fillColor: DesignTokens.surfaceLow,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          enabledBorder: inputBorder,
                          focusedBorder: focusBorder,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedMetodoWeb,
                        decoration: InputDecoration(
                          labelText: 'Forma de Pago',
                          labelStyle: const TextStyle(fontFamily: 'Inter'),
                          prefixIcon: const Icon(Icons.payment_rounded, color: DesignTokens.primary),
                          filled: true,
                          fillColor: DesignTokens.surfaceLow,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          enabledBorder: inputBorder,
                          focusedBorder: focusBorder,
                        ),
                        items: ['Efectivo', 'Tarjeta', 'Transferencia', 'Cuenta Corriente']
                            .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontFamily: 'Inter'))))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedMetodoWeb = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descController,
                  focusNode: _descFocus,
                  textInputAction: TextInputAction.done,
                  maxLines: 2,
                  style: const TextStyle(fontFamily: 'Inter'),
                  decoration: InputDecoration(
                    labelText: 'Observaciones',
                    labelStyle: const TextStyle(fontFamily: 'Inter'),
                    alignLabelWithHint: true,
                    prefixIcon: const Icon(Icons.notes_rounded, color: DesignTokens.primary),
                    filled: true,
                    fillColor: DesignTokens.surfaceLow,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    enabledBorder: inputBorder,
                    focusedBorder: focusBorder,
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf'],
                      withData: true,
                    );
                    if (result != null && result.files.isNotEmpty) {
                      setState(() => _pickedFileWeb = result.files.first);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: DesignTokens.surfaceLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: DesignTokens.primary.withValues(alpha: 0.1)),
                    ),
                    child: _pickedFileWeb != null 
                      ? Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _pickedFileWeb!.extension == 'pdf'
                                  ? const Icon(Icons.picture_as_pdf, size: 64, color: Colors.red)
                                  : kIsWeb && _pickedFileWeb!.bytes != null
                                      ? Image.memory(_pickedFileWeb!.bytes!, height: 100, width: double.infinity, fit: BoxFit.cover)
                                      : _pickedFileWeb!.path != null 
                                          ? Image.file(File(_pickedFileWeb!.path!), height: 100, width: double.infinity, fit: BoxFit.cover)
                                          : const Icon(Icons.insert_drive_file, size: 64),
                            ),
                            const SizedBox(height: 8),
                            const Text('FOTO ADJUNTADA', style: TextStyle(fontFamily: 'Work Sans', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        )
                      : const Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           Icon(Icons.add_photo_alternate_rounded, size: 32, color: DesignTokens.primary),
                           SizedBox(height: 8),
                           Text('ADJUNTAR TICKET (GALERÍA/PC)', style: TextStyle(fontFamily: 'Work Sans', fontSize: 10, fontWeight: FontWeight.bold, color: DesignTokens.primary)),
                          ],
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _savingForm ? null : _saveGastoWeb,
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _savingForm 
              ? const CircularProgressIndicator(color: DesignTokens.primary)
              : const Text('GUARDAR GASTO', style: TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.bold, fontFamily: 'Manrope')),
          ),
        ),
      ],
    );
  }

  void _clearWebForm() {
    setState(() {
      _amountController.clear();
      _descController.clear();
      _comprobanteController.clear();
      _litrosController.clear();
      _selectedTipoWeb = 'Combustible';
      _selectedMetodoWeb = 'Efectivo';
      _selectedFechaWeb = DateTime.now();
      _pickedFileWeb = null;
    });
  }

  Future<void> _saveGastoWeb() async {
    if (_savingForm) return;

    if (_amountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingrese el importe del gasto'), backgroundColor: Colors.orangeAccent));
      return;
    }
    
    final importeStr = _amountController.text.replaceAll(',', '.');
    final importe = double.tryParse(importeStr) ?? 0.0;
    if (importe <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El importe debe ser mayor a 0'), backgroundColor: Colors.orangeAccent));
      return;
    }

    if (_comprobanteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debe ingresar el número de comprobante'), backgroundColor: Colors.orangeAccent));
      return;
    }
    if (_selectedViajeIdWeb == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debe seleccionar un viaje para vincular el gasto'), backgroundColor: Colors.orangeAccent));
      return;
    }
    if (_selectedTipoWeb == 'Combustible') {
      if (_litrosController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debe ingresar la cantidad en litros para Combustible'), backgroundColor: Colors.orangeAccent));
        return;
      }
      final litresVal = double.tryParse(_litrosController.text.replaceAll(',', '.')) ?? 0.0;
      if (litresVal <= 0.0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debe ingresar una cantidad válida en litros'), backgroundColor: Colors.orangeAccent));
        return;
      }
    }

    setState(() => _savingForm = true);
    
    try {
      String? publicUrl;
      if (_pickedFileWeb != null) {
        final bytes = _pickedFileWeb!.bytes ?? await File(_pickedFileWeb!.path!).readAsBytes();
        String ext = _pickedFileWeb!.extension != null ? '.' + _pickedFileWeb!.extension! : '';
        if (ext.isEmpty) ext = '.jpg';
        final fileName = 'gasto_${DateTime.now().millisecondsSinceEpoch}$ext';
        
        await Supabase.instance.client.storage.from('gastos').uploadBinary(
          fileName, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
        publicUrl = Supabase.instance.client.storage.from('gastos').getPublicUrl(fileName);
      }

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final userNombre = prefs.getString('user_nombre') ?? '';
      final userApellido = prefs.getString('user_apellido') ?? '';
      final userPuesto = prefs.getString('user_puesto') ?? '';
      
      final auditSuffix = '\n[Registrado por: $userNombre $userApellido ($userPuesto)]';

      final selectedTrip = _viajesParaGasto.firstWhere((v) => v['id']?.toString() == _selectedViajeIdWeb, orElse: () => <String, dynamic>{});
      final tripChoferId = selectedTrip['chofer_id'];
      final choferIdToInsert = tripChoferId ?? userId;

      if (choferIdToInsert == null || choferIdToInsert.isEmpty) {
        throw Exception('No se pudo determinar el chofer del viaje seleccionado.');
      }

      final litresVal = _selectedTipoWeb == 'Combustible' ? (double.tryParse(_litrosController.text.replaceAll(',', '.')) ?? 0.0) : 0.0;
      final String prefix = _selectedTipoWeb == 'Combustible' ? 'Litros: $litresVal L\n' : '';
      final String descWithLitres = prefix + _descController.text + auditSuffix;

      await Supabase.instance.client.from('gastos').insert({
        'tipo_gasto': _selectedTipoWeb,
        'importe': importe,
        'descripcion': descWithLitres,
        'nro_comprobante': _comprobanteController.text,
        'forma_pago': _selectedMetodoWeb,
        'viaje_id': _selectedViajeIdWeb,
        'fecha': _selectedFechaWeb.toIso8601String(),
        'chofer_id': choferIdToInsert,
        'comprobante_url': publicUrl,
        'cantidad_litros': litresVal > 0 ? litresVal : null,
      });

      if (mounted) {
        _clearWebForm();
        _fetchData();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gasto registrado con éxito'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _savingForm = false);
    }
  }

  Widget _buildGastoCard(Map<String, dynamic> g) {
    final tipo = g['tipo_gasto'] ?? 'Gasto';
    final importe = g['importe']?.toString() ?? '0';
    final fecha = DateTime.tryParse(g['fecha']?.toString() ?? '') ?? DateTime.now();
    final fechaStr = DateFormat('dd/MM/yyyy').format(fecha);
    final chofer = g['profiles'] != null ? '${g['profiles']['nombre']} ${g['profiles']['apellido']}' : 'S/D';
    final viaje = g['viajes']?['viaje_codigo'] ?? 'Sin viaje';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: DesignTokens.primary.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        onTap: () => _showGastoDetailDialog(context, g),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: DesignTokens.secondary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                    child: Text(tipo.toUpperCase(), style: const TextStyle(color: Color(0xFF7D5700), fontFamily: 'Work Sans', fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  Text('\$ $importe', style: const TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w800, fontSize: 18, color: DesignTokens.primary)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person_rounded, size: 14, color: DesignTokens.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(chofer, style: const TextStyle(fontSize: 12, fontFamily: 'Inter', color: DesignTokens.onSurfaceVariant)),
                  const Spacer(),
                  const Icon(Icons.calendar_today_rounded, size: 14, color: DesignTokens.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(fechaStr, style: const TextStyle(fontSize: 12, fontFamily: 'Inter', color: DesignTokens.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.local_shipping_rounded, size: 14, color: DesignTokens.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text('Viaje: $viaje', style: const TextStyle(fontSize: 12, fontFamily: 'Inter', color: DesignTokens.onSurfaceVariant)),
                ],
              ),
              if (g['descripcion'] != null && g['descripcion'].toString().trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DesignTokens.surfaceLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DesignTokens.primary.withValues(alpha: 0.05)),
                  ),
                  child: Text(
                    g['descripcion'],
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: DesignTokens.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showGastoDetailDialog(BuildContext context, Map<String, dynamic> g) {
    showDialog(
      context: context,
      builder: (ctx) => GastosDetalleDialog(gasto: g),
    );
  }
}
