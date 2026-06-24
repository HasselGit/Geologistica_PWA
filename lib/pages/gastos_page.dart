import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../backend/supabase_service.dart';
import '../backend/design_tokens.dart';
import '../backend/app_states.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
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
  XFile? _pickedFileWeb;
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
            ? [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
            : [BoxShadow(color: DesignTokens.primary.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
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

    final avgPriceL = combustibleLitros > 0 ? (combustibleMonto / combustibleLitros) : 0.0;

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
            borderColor: DesignTokens.primary.withOpacity(0.08),
          ),
          if (combustibleLitros > 0)
            _buildKPICard(
              title: 'PRECIO MEDIO L',
              value: '\$${avgPriceL.toStringAsFixed(1)} / L',
              subtitle: 'Consumo promedio',
              icon: Icons.calculate_rounded,
              backgroundColor: Colors.white,
              textColor: DesignTokens.primary,
              accentColor: const Color(0xFF1A6B43),
              borderColor: DesignTokens.primary.withOpacity(0.08),
            ),
          _buildKPICard(
            title: 'OTROS RUBROS',
            value: '\$${(totalGasto - combustibleMonto).toStringAsFixed(0)}',
            subtitle: 'Comida/Peaje/Rep.',
            icon: Icons.category_rounded,
            backgroundColor: Colors.white,
            textColor: DesignTokens.primary,
            accentColor: DesignTokens.primary.withOpacity(0.5),
            borderColor: DesignTokens.primary.withOpacity(0.08),
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
                color: isSelected ? Colors.white : DesignTokens.primary.withOpacity(0.7)
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
                  color: isSelected ? Colors.transparent : DesignTokens.primary.withOpacity(0.08),
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
                  color: DesignTokens.primary.withOpacity(0.05),
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
              onPressed: () => context.pop(),
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
          floatingActionButton: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 900) return const SizedBox.shrink();
              return FloatingActionButton.extended(
                onPressed: _showAddGastoDialog,
                backgroundColor: DesignTokens.primary,
                icon: const Icon(Icons.payments_rounded, color: Colors.white),
                label: const Text('NUEVO GASTO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              );
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
              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: DesignTokens.primary, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.primary.withOpacity(0.1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.primary.withOpacity(0.08))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: DesignTokens.secondary, width: 1.5)),
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
                style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold, fontSize: 11, color: DesignTokens.onSurfaceVariant, letterSpacing: 0.5)
              ),
              Text(
                'Total: \$${_filteredGastos.fold(0.0, (sum, g) => sum + (double.tryParse(g['importe']?.toString() ?? '0') ?? 0.0)).toStringAsFixed(2)}', 
                style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w900, fontSize: 15, color: DesignTokens.primary)
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
        Container(
          width: 450,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: DesignTokens.primary.withOpacity(0.1))),
          ),
          child: _buildWebForm(),
        ),
        Expanded(
          child: _buildMobileLayout(),
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

    const honeyGold = Color(0xFFC68E17);
    final inputBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.primary.withOpacity(0.05)));
    final focusBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: honeyGold, width: 2));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Registrar Nuevo Gasto', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: DesignTokens.primary)),
        const SizedBox(height: 8),
        const Text('Presione Ctrl+Enter para guardar, Esc para limpiar', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 20),
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
                            prefixIcon: const Icon(Icons.calendar_today_rounded, color: DesignTokens.primary),
                            filled: true,
                            fillColor: DesignTokens.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            enabledBorder: inputBorder,
                          ),
                          child: Text(DateFormat('dd/MM/yyyy').format(_selectedFechaWeb), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                        decoration: InputDecoration(
                          labelText: 'N° Comprobante',
                          prefixIcon: const Icon(Icons.receipt_rounded, color: DesignTokens.primary),
                          filled: true,
                          fillColor: DesignTokens.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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
                    prefixIcon: const Icon(Icons.category_rounded, color: DesignTokens.primary),
                    filled: true,
                    fillColor: DesignTokens.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    enabledBorder: inputBorder,
                    focusedBorder: focusBorder,
                  ),
                  items: ['Combustible', 'Comida', 'Peaje', 'Reparación', 'Otros']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
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
                    decoration: InputDecoration(
                      labelText: 'Cantidad en Litros (L)',
                      prefixIcon: const Icon(Icons.local_gas_station_rounded, color: DesignTokens.primary),
                      filled: true,
                      fillColor: DesignTokens.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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
                    prefixIcon: const Icon(Icons.local_shipping_rounded, color: DesignTokens.primary),
                    filled: true,
                    fillColor: DesignTokens.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    enabledBorder: inputBorder,
                    focusedBorder: focusBorder,
                  ),
                  hint: const Text('Seleccione un viaje...'),
                  items: _viajesParaGasto.map((v) => DropdownMenuItem<String>(
                    value: v['id']?.toString(),
                    child: Text('${v['viaje_codigo'] ?? 'S/C'} (${v['estado'] ?? ''})'),
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
                        decoration: InputDecoration(
                          labelText: 'Importe (\$)',
                          prefixIcon: const Icon(Icons.attach_money_rounded, color: DesignTokens.primary),
                          filled: true,
                          fillColor: DesignTokens.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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
                          prefixIcon: const Icon(Icons.payment_rounded, color: DesignTokens.primary),
                          filled: true,
                          fillColor: DesignTokens.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          enabledBorder: inputBorder,
                          focusedBorder: focusBorder,
                        ),
                        items: ['Efectivo', 'Tarjeta', 'Transferencia', 'Cuenta Corriente']
                            .map((m) => DropdownMenuItem(value: m, child: Text(m)))
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
                  decoration: InputDecoration(
                    labelText: 'Observaciones',
                    alignLabelWithHint: true,
                    prefixIcon: const Icon(Icons.notes_rounded, color: DesignTokens.primary),
                    filled: true,
                    fillColor: DesignTokens.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    enabledBorder: inputBorder,
                    focusedBorder: focusBorder,
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 70,
                    );
                    if (image != null) {
                      setState(() => _pickedFileWeb = image);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: DesignTokens.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: DesignTokens.primary.withOpacity(0.1)),
                    ),
                    child: _pickedFileWeb != null 
                      ? Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: kIsWeb
                              ? Image.network(_pickedFileWeb!.path, height: 100, width: double.infinity, fit: BoxFit.cover)
                              : Image.file(File(_pickedFileWeb!.path), height: 100, width: double.infinity, fit: BoxFit.cover),
                            ),
                            const SizedBox(height: 8),
                            const Text('FOTO ADJUNTADA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        )
                      : const Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           Icon(Icons.add_photo_alternate_rounded, size: 32, color: DesignTokens.primary),
                           SizedBox(height: 8),
                           Text('ADJUNTAR TICKET (GALERÍA/PC)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: DesignTokens.primary)),
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
              backgroundColor: honeyGold,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _savingForm 
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('GUARDAR GASTO (Ctrl+Enter)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        final bytes = await _pickedFileWeb!.readAsBytes();
        String ext = p.extension(_pickedFileWeb!.path);
        if (ext.isEmpty) ext = p.extension(_pickedFileWeb!.name);
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
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: DesignTokens.primary.withOpacity(0.05)),
      ),
      child: InkWell(
        onTap: () => _showGastoDetailDialog(context, g),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: DesignTokens.secondary.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                    child: Text(tipo.toUpperCase(), style: const TextStyle(color: Color(0xFF7D5700), fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  Text('\$ $importe', style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 18, color: DesignTokens.primary)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person_rounded, size: 14, color: DesignTokens.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(chofer, style: const TextStyle(fontSize: 12, color: DesignTokens.onSurfaceVariant)),
                  const Spacer(),
                  const Icon(Icons.calendar_today_rounded, size: 14, color: DesignTokens.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(fechaStr, style: const TextStyle(fontSize: 12, color: DesignTokens.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.local_shipping_rounded, size: 14, color: DesignTokens.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text('Viaje: $viaje', style: const TextStyle(fontSize: 12, color: DesignTokens.onSurfaceVariant)),
                ],
              ),
              if (g['descripcion'] != null && g['descripcion'].toString().trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F9F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Text(
                    g['descripcion'],
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
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

  void _showAddGastoDialog() {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    final comprobanteController = TextEditingController();
    final litrosController = TextEditingController();
    String? selectedTipo = 'Combustible';
    String? selectedMetodo = 'Efectivo';
    DateTime selectedFecha = DateTime.now();
    XFile? pickedFile;
    bool savingGasto = false;

    // Pre-seleccionar el viaje En Proceso/En Curso si existe
    final viajeEnCurso = _viajesParaGasto.where((v) {
      final est = (v['estado'] ?? '').toString().toLowerCase();
      return est.contains('proceso') || est.contains('curso');
    }).toList();
    String? selectedViajeId = viajeEnCurso.isNotEmpty ? viajeEnCurso.first['id']?.toString() : null;

    showModalBottomSheet(
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
                  const Text('Registrar Nuevo Gasto', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: DesignTokens.primary)),
                  const SizedBox(height: 20),
                  
                  // Fila de Fecha y Comprobante
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: selectedFecha,
                              firstDate: DateTime(2024),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) setModalState(() => selectedFecha = picked);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Fecha',
                              prefixIcon: const Icon(Icons.calendar_today_rounded, color: DesignTokens.primary),
                              filled: true,
                              fillColor: DesignTokens.surface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.primary.withOpacity(0.05))),
                            ),
                            child: Text(DateFormat('dd/MM/yyyy').format(selectedFecha), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: comprobanteController,
                          decoration: InputDecoration(
                            labelText: 'N° Comprobante',
                            prefixIcon: const Icon(Icons.receipt_rounded, color: DesignTokens.primary),
                            filled: true,
                            fillColor: DesignTokens.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.primary.withOpacity(0.05))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.secondary.withOpacity(0.1), width: 2)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: selectedTipo,
                    decoration: InputDecoration(
                      labelText: 'Tipo de Gasto',
                      prefixIcon: const Icon(Icons.category_rounded, color: DesignTokens.primary),
                      filled: true,
                      fillColor: DesignTokens.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.primary.withOpacity(0.05))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.secondary.withOpacity(0.1), width: 2)),
                    ),
                    items: ['Combustible', 'Comida', 'Peaje', 'Reparación', 'Otros']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setModalState(() => selectedTipo = v),
                  ),
                  if (selectedTipo == 'Combustible') ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: litrosController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Cantidad en Litros (L)',
                        prefixIcon: const Icon(Icons.local_gas_station_rounded, color: DesignTokens.primary),
                        filled: true,
                        fillColor: DesignTokens.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.primary.withOpacity(0.05))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.secondary.withOpacity(0.1), width: 2)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: selectedViajeId,
                    decoration: InputDecoration(
                      labelText: 'Vincular a Viaje',
                      prefixIcon: const Icon(Icons.local_shipping_rounded, color: DesignTokens.primary),
                      filled: true,
                      fillColor: DesignTokens.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.primary.withOpacity(0.05))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.secondary.withOpacity(0.1), width: 2)),
                    ),
                    hint: const Text('Seleccione un viaje...'),
                    items: _viajesParaGasto.map((v) => DropdownMenuItem<String>(
                      value: v['id']?.toString(),
                      child: Text('${v['viaje_codigo'] ?? 'S/C'} (${v['estado'] ?? ''})'),
                    )).toList(),
                    onChanged: (v) => setModalState(() => selectedViajeId = v),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Importe (\$)',
                      prefixIcon: const Icon(Icons.attach_money_rounded, color: DesignTokens.primary),
                      filled: true,
                      fillColor: DesignTokens.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.primary.withOpacity(0.05))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.secondary.withOpacity(0.1), width: 2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedMetodo,
                    decoration: InputDecoration(
                      labelText: 'Forma de Pago',
                      prefixIcon: const Icon(Icons.payment_rounded, color: DesignTokens.primary),
                      filled: true,
                      fillColor: DesignTokens.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.primary.withOpacity(0.05))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.secondary.withOpacity(0.1), width: 2)),
                    ),
                    items: ['Efectivo', 'Tarjeta', 'Transferencia', 'Cuenta Corriente']
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) => setModalState(() => selectedMetodo = v),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: descController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Observaciones',
                      alignLabelWithHint: true,
                      prefixIcon: const Icon(Icons.notes_rounded, color: DesignTokens.primary),
                      filled: true,
                      fillColor: DesignTokens.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.primary.withOpacity(0.05))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignTokens.secondary.withOpacity(0.1), width: 2)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 20),                    // Sección de Foto (Ahora funcional y robusta con fallback)
                    InkWell(
                      onTap: () async {
                        showModalBottomSheet(
                          context: ctx,
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (sheetCtx) => SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Adjuntar Foto de Ticket',
                                    style: TextStyle(
                                      fontFamily: 'Manrope',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: DesignTokens.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  ListTile(
                                    leading: const Icon(Icons.camera_alt_rounded, color: DesignTokens.primary),
                                    title: const Text('Tomar Foto con Cámara'),
                                    onTap: () async {
                                      Navigator.pop(sheetCtx);
                                      try {
                                        final ImagePicker picker = ImagePicker();
                                        final XFile? image = await picker.pickImage(
                                          source: ImageSource.camera,
                                          imageQuality: 70,
                                        );
                                        if (image != null) {
                                          setModalState(() => pickedFile = image);
                                        }
                                      } catch (e) {
                                        print('Camera pick error: $e');
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text('No se pudo abrir la cámara: $e. Puede seleccionar una imagen desde su galería.'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  const Divider(),
                                  ListTile(
                                    leading: const Icon(Icons.photo_library_rounded, color: DesignTokens.primary),
                                    title: const Text('Seleccionar de Galería'),
                                    onTap: () async {
                                      Navigator.pop(sheetCtx);
                                      try {
                                        final ImagePicker picker = ImagePicker();
                                        final XFile? image = await picker.pickImage(
                                          source: ImageSource.gallery,
                                          imageQuality: 70,
                                        );
                                        if (image != null) {
                                          setModalState(() => pickedFile = image);
                                        }
                                      } catch (e) {
                                        print('Gallery pick error: $e');
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text('No se pudo abrir la galería: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: DesignTokens.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: DesignTokens.primary.withOpacity(0.1)),
                        ),
                        child: pickedFile != null 
                          ? Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: kIsWeb
                                  ? Image.network(pickedFile!.path, height: 100, width: double.infinity, fit: BoxFit.cover)
                                  : Image.file(File(pickedFile!.path), height: 100, width: double.infinity, fit: BoxFit.cover),
                                ),
                                const SizedBox(height: 8),
                                const Text('FOTO ADJUNTADA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                                const Text('Toca para cambiar', style: TextStyle(fontSize: 10, color: Colors.black26)),
                              ],
                            )
                          : Column(
                             mainAxisAlignment: MainAxisAlignment.center,
                             children: [
                               const Icon(Icons.add_a_photo_rounded, size: 32, color: DesignTokens.primary),
                               const SizedBox(height: 8),
                               Text(pickedFile == null ? 'ADJUNTAR FOTO' : 'CAMBIAR FOTO', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: DesignTokens.primary)),
                              ],
                            ),
                      ),
                    ),

                   const SizedBox(height: 28),
                   
                   SizedBox(
                     width: double.infinity,
                     height: 56,
                     child: ElevatedButton(
                       onPressed: savingGasto ? null : () async {
                         if (amountController.text.trim().isEmpty) {
                           ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Ingrese el importe del gasto'), backgroundColor: Colors.orangeAccent));
                           return;
                         }
                         if (comprobanteController.text.trim().isEmpty) {
                           ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Debe ingresar el número de comprobante'), backgroundColor: Colors.orangeAccent));
                           return;
                         }
                         if (selectedViajeId == null) {
                           ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Debe seleccionar un viaje para vincular el gasto'), backgroundColor: Colors.orangeAccent));
                           return;
                         }
                         if (selectedTipo == 'Combustible') {
                           if (litrosController.text.trim().isEmpty) {
                             ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Debe ingresar la cantidad en litros para Combustible'), backgroundColor: Colors.orangeAccent));
                             return;
                           }
                           final litresVal = double.tryParse(litrosController.text.replaceAll(',', '.')) ?? 0.0;
                           if (litresVal <= 0.0) {
                             ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Debe ingresar una cantidad válida en litros'), backgroundColor: Colors.orangeAccent));
                             return;
                           }
                         }
                         setModalState(() => savingGasto = true);
                         try {
                           String? publicUrl;
                           if (pickedFile != null) {
                              final bytes = await pickedFile!.readAsBytes();
                              String ext = p.extension(pickedFile!.path);
                              if (ext.isEmpty) {
                                ext = p.extension(pickedFile!.name);
                              }
                              if (ext.isEmpty) {
                                ext = '.jpg';
                              }
                              final fileName = 'gasto_${DateTime.now().millisecondsSinceEpoch}$ext';
                             
                             try {
                               await Supabase.instance.client.storage.from('gastos').uploadBinary(
                                 fileName, 
                                 bytes,
                                 fileOptions: const FileOptions(contentType: 'image/jpeg'),
                               );
                             } catch (uploadErr) {
                               print('Storage upload failure: $uploadErr');
                               throw Exception(
                                 'No se pudo subir la foto del ticket a Supabase.\n'
                                 'Por favor verifique que exista el bucket de almacenamiento "gastos" con acceso público.'
                               );
                             }
                             publicUrl = Supabase.instance.client.storage.from('gastos').getPublicUrl(fileName);
                           }

                          final prefs = await SharedPreferences.getInstance();
                          final userId = prefs.getString('user_id');
                          final userNombre = prefs.getString('user_nombre') ?? '';
                          final userApellido = prefs.getString('user_apellido') ?? '';
                          final userPuesto = prefs.getString('user_puesto') ?? '';
                          
                          final auditSuffix = '\n[Registrado por: $userNombre $userApellido ($userPuesto)]';

                          // Buscar el chofer real asignado al viaje seleccionado para evitar violar restricciones de clave foránea
                          final selectedTrip = _viajesParaGasto.firstWhere(
                            (v) => v['id']?.toString() == selectedViajeId,
                            orElse: () => <String, dynamic>{},
                          );
                          final tripChoferId = selectedTrip['chofer_id'];
                          final choferIdToInsert = tripChoferId ?? userId;

                          if (choferIdToInsert == null || choferIdToInsert.isEmpty) {
                            throw Exception('No se pudo determinar el chofer del viaje seleccionado. Asegúrese de que el viaje tenga un chofer asignado.');
                          }

                          final litresVal = selectedTipo == 'Combustible' ? (double.tryParse(litrosController.text.replaceAll(',', '.')) ?? 0.0) : 0.0;
                          final String prefix = selectedTipo == 'Combustible' ? 'Litros: $litresVal L\n' : '';
                          final String descWithLitres = prefix + descController.text + auditSuffix;

                          await Supabase.instance.client.from('gastos').insert({
                            'tipo_gasto': selectedTipo,
                            'importe': double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0.0,
                            'descripcion': descWithLitres,
                            'nro_comprobante': comprobanteController.text,
                            'forma_pago': selectedMetodo,
                            'viaje_id': selectedViajeId,
                            'fecha': selectedFecha.toIso8601String(),
                            'chofer_id': choferIdToInsert,
                            'comprobante_url': publicUrl,
                          });
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            _fetchData();
                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Gasto registrado con éxito'), backgroundColor: Colors.green));
                          }
                        } catch (e) {
                          print('Error saving gasto: $e');
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                          }
                        } finally {
                          if (ctx.mounted) setModalState(() => savingGasto = false);
                        }
                      },
                      style: DesignTokens.primaryButtonStyle,
                      child: savingGasto 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('GUARDAR REGISTRO'),
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

  void _showGastoDetailDialog(BuildContext context, Map<String, dynamic> g) {
    showDialog(
      context: context,
      builder: (ctx) => GastosDetalleDialog(gasto: g),
    );
  }
}
