import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import '../backend/supabase_service.dart';
import '../backend/productos_data.dart';
import '../backend/design_tokens.dart';

class ProductosPageWidget extends StatefulWidget {
  const ProductosPageWidget({super.key});

  @override
  State<ProductosPageWidget> createState() => _ProductosPageWidgetState();
}

class _ProductosPageWidgetState extends State<ProductosPageWidget> {
  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _filteredProductos = [];
  final _searchController = TextEditingController();
  bool _loading = true;
  String? _userRole;
  Timer? _debounce;

  int _currentPage = 0;
  final int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadRole();
    _fetchData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _userRole = prefs.getString('user_puesto'));
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    
    try {
      final box = await Hive.openBox('productosCache');
      if (box.containsKey('data')) {
        final cached = box.get('data');
        if (cached != null && cached is List && mounted) {
          final parsed = List<Map<String, dynamic>>.from(
            cached.map((e) => Map<String, dynamic>.from(e as Map))
          );
          parsed.sort((a, b) => (a['descripcion'] ?? '').toString().toLowerCase().compareTo((b['descripcion'] ?? '').toString().toLowerCase()));
          setState(() {
            _productos = parsed;
            _filteredProductos = parsed;
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Hive cache error: $e');
    }

    try {
      final data = await SupabaseService().getProductos();
      if (mounted) {
        data.sort((a, b) => (a['descripcion'] ?? '').toString().toLowerCase().compareTo((b['descripcion'] ?? '').toString().toLowerCase()));
        setState(() {
          _productos = data;
          _filteredProductos = data;
          _loading = false;
        });

        try {
          final box = await Hive.openBox('productosCache');
          await box.put('data', data);
        } catch (e) {
          debugPrint('Hive save error: $e');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filterProducts(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    // Search bar: Consume Hive cache first. Deep Supabase search needs 400ms Debounce.
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() {
        _filteredProductos = _productos.where((p) {
          final desc = (p['descripcion'] ?? '').toString().toLowerCase();
          final cod = (p['codigo'] ?? '').toString().toLowerCase();
          return desc.contains(query.toLowerCase()) || cod.contains(query.toLowerCase());
        }).toList();
        _currentPage = 0; // reset pagination
      });
      
      // If no local matches, perform a deep search in Supabase
      if (_filteredProductos.isEmpty && query.isNotEmpty) {
        setState(() => _loading = true);
        try {
          final data = await Supabase.instance.client
              .from('productos')
              .select()
              .or('descripcion.ilike.%$query%,codigo.ilike.%$query%');
              
          if (mounted) {
            setState(() {
              _filteredProductos = List<Map<String, dynamic>>.from(data);
              _loading = false;
            });
          }
        } catch (e) {
          if (mounted) setState(() => _loading = false);
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
        title: Text('Inventario de Productos', style: DesignTokens.headlineStyle(color: DesignTokens.primary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DesignTokens.primary), 
          onPressed: () => context.pop()
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterProducts,
              style: DesignTokens.bodyStyle(color: DesignTokens.onSurface),
              decoration: InputDecoration(
                hintText: 'Buscar producto o código...',
                hintStyle: DesignTokens.bodyStyle(color: DesignTokens.onSurfaceVariant),
                prefixIcon: const Icon(Icons.search, color: DesignTokens.primary),
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: DesignTokens.outline.withOpacity(0.3))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DesignTokens.primary, width: 2)),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          Expanded(
            child: _loading && _filteredProductos.isEmpty
              ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 900) {
                      return RepaintBoundary(child: _buildWebTable());
                    } else {
                      return RepaintBoundary(child: _buildMobileList());
                    }
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: (_userRole == 'CEO' || _userRole == 'Gerente' || _userRole == 'Compras') 
        ? FloatingActionButton.extended(
            onPressed: _addProduct,
            backgroundColor: DesignTokens.primary,
            icon: const Icon(Icons.add, color: DesignTokens.accent),
            label: Text('Nuevo Producto', style: DesignTokens.labelStyle(color: DesignTokens.accent)),
          )
        : null,
    );
  }

  Widget _buildWebTable() {
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = min(startIndex + _rowsPerPage, _filteredProductos.length);
    final currentItems = _filteredProductos.sublist(startIndex, endIndex);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DesignTokens.outline.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: DesignTokens.primary.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Catálogo Maestro',
                    style: DesignTokens.headlineStyle(color: DesignTokens.primary).copyWith(fontSize: 18),
                  ),
                  Text(
                    '${_filteredProductos.length} registros',
                    style: DesignTokens.labelStyle(color: DesignTokens.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: DesignTokens.outline.withOpacity(0.2)),
            DataTable(
              headingRowColor: WidgetStateProperty.all(DesignTokens.surfaceLow),
              dataRowMinHeight: 64,
              dataRowMaxHeight: 64,
              horizontalMargin: 24,
              columnSpacing: 32,
              columns: [
                DataColumn(label: Text('CÓDIGO', style: DesignTokens.labelStyle(color: DesignTokens.primary))),
                DataColumn(label: Text('DESCRIPCIÓN', style: DesignTokens.labelStyle(color: DesignTokens.primary))),
                DataColumn(label: Text('UNIDAD', style: DesignTokens.labelStyle(color: DesignTokens.primary))),
                if (_userRole == 'CEO' || _userRole == 'Gerente' || _userRole == 'Compras')
                  DataColumn(label: Text('ACCIÓN', style: DesignTokens.labelStyle(color: DesignTokens.primary))),
              ],
              rows: currentItems.map((p) {
                return DataRow(
                  cells: [
                    DataCell(Text(p['codigo'] ?? 'S/C', style: DesignTokens.bodyStyle(color: DesignTokens.onSurface))),
                    DataCell(Text(p['descripcion'] ?? 'Sin descripción', style: DesignTokens.bodyStyle(color: DesignTokens.onSurface))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: DesignTokens.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(p['unidad'] ?? 'UN', style: DesignTokens.labelStyle(color: DesignTokens.primary)),
                    )),
                    if (_userRole == 'CEO' || _userRole == 'Gerente' || _userRole == 'Compras')
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20, color: DesignTokens.primary),
                              onPressed: () => _editProduct(p),
                              tooltip: 'Editar',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: DesignTokens.error),
                              onPressed: () => _confirmDelete(p),
                              tooltip: 'Eliminar',
                            ),
                          ],
                        )
                      ),
                  ],
                );
              }).toList(),
            ),
            Divider(height: 1, color: DesignTokens.outline.withOpacity(0.2)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${_filteredProductos.isEmpty ? 0 : startIndex + 1}-${endIndex} de ${_filteredProductos.length}',
                    style: DesignTokens.bodyStyle(color: DesignTokens.onSurfaceVariant),
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: DesignTokens.primary),
                    onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: DesignTokens.primary),
                    onPressed: endIndex < _filteredProductos.length ? () => setState(() => _currentPage++) : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _filteredProductos.length,
      itemBuilder: (context, index) => _buildProductCard(_filteredProductos[index]),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.outline.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(color: DesignTokens.primary.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: DesignTokens.surfaceLow, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.inventory_2_rounded, color: DesignTokens.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['descripcion'] ?? 'Sin descripción', style: DesignTokens.bodyStyle(color: DesignTokens.onSurface).copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Código: ${p['codigo'] ?? 'S/C'}', style: DesignTokens.bodyStyle(color: DesignTokens.onSurfaceVariant).copyWith(fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: DesignTokens.secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(p['unidad'] ?? 'UN', style: DesignTokens.labelStyle(color: DesignTokens.primary).copyWith(fontSize: 10)),
          ),
          if (_userRole == 'CEO' || _userRole == 'Gerente' || _userRole == 'Compras') ...[
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: DesignTokens.onSurfaceVariant, size: 20),
              onSelected: (val) {
                if (val == 'edit') _editProduct(p);
                if (val == 'delete') _confirmDelete(p);
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Editar')])),
                PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: DesignTokens.error), const SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: DesignTokens.error))])),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _editProduct(Map<String, dynamic> p) {
    final descController = TextEditingController(text: p['descripcion']);
    final codeController = TextEditingController(text: p['codigo']);
    String? selectedUnidad = p['unidad'] ?? 'KG';

    void saveProduct() async {
      if (descController.text.isEmpty) return;
      try {
        await SupabaseService().updateProducto(p['id'].toString(), {
          'descripcion': descController.text,
          'codigo': codeController.text,
          'unidad': selectedUnidad,
        });
        if (mounted) Navigator.pop(context);
        _fetchData();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, control: true): saveProduct,
          const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(ctx),
        },
        child: Focus(
          autofocus: true,
          child: StatefulBuilder(
            builder: (ctx, setModalState) => Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Editar Producto', style: DesignTokens.headlineStyle(color: DesignTokens.primary).copyWith(fontSize: 20)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: descController,
                    style: DesignTokens.bodyStyle(color: DesignTokens.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Descripción',
                      prefixIcon: const Icon(Icons.inventory_2_outlined, color: DesignTokens.primary),
                      filled: true,
                      fillColor: DesignTokens.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: codeController,
                          style: DesignTokens.bodyStyle(color: DesignTokens.onSurface),
                          decoration: InputDecoration(
                            labelText: 'Código',
                            filled: true,
                            fillColor: DesignTokens.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedUnidad,
                          style: DesignTokens.bodyStyle(color: DesignTokens.onSurface),
                          decoration: InputDecoration(
                            labelText: 'Unidad',
                            filled: true,
                            fillColor: DesignTokens.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          items: ['KG', 'Kg', 'kg', 'UN', 'Uni', 'L', 'Lts', 'Tambor', 'Bolsa x 50 Kg', 'Caja x 600 Uni']
                              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (v) => setModalState(() => selectedUnidad = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: saveProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DesignTokens.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('ACTUALIZAR PRODUCTO', style: DesignTokens.labelStyle(color: Colors.white).copyWith(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Eliminar producto?', style: DesignTokens.headlineStyle(color: DesignTokens.primary).copyWith(fontSize: 18)),
        content: Text('El producto "${p['descripcion']}" se ocultará pero se mantendrá en el historial.', style: DesignTokens.bodyStyle(color: DesignTokens.onSurfaceVariant)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('CANCELAR', style: DesignTokens.labelStyle(color: DesignTokens.onSurfaceVariant))),
          TextButton(
            onPressed: () async {
              try {
                await SupabaseService().softDeleteProducto(p['id'].toString());
                if (mounted) Navigator.pop(ctx);
                _fetchData();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            }, 
            child: Text('ELIMINAR', style: DesignTokens.labelStyle(color: DesignTokens.error))
          ),
        ],
      ),
    );
  }

  void _addProduct() {
    final descController = TextEditingController();
    final codeController = TextEditingController();
    String? selectedUnidad = 'KG';
    
    final sortedCatalog = List<Map<String, dynamic>>.from(ProductosData.masterCatalog)
      ..sort((a, b) => (a['descripcion'] ?? '').toString().toLowerCase().compareTo((b['descripcion'] ?? '').toString().toLowerCase()));

    void saveProduct() async {
      if (descController.text.isEmpty) return;
      try {
        await Supabase.instance.client.from('productos').insert({
          'descripcion': descController.text,
          'codigo': codeController.text,
          'unidad': selectedUnidad,
        });
        if (mounted) Navigator.pop(context);
        _fetchData();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, control: true): saveProduct,
          const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(ctx),
        },
        child: Focus(
          autofocus: true,
          child: StatefulBuilder(
            builder: (ctx, setModalState) => Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nuevo Producto', style: DesignTokens.headlineStyle(color: DesignTokens.primary).copyWith(fontSize: 20)),
                  const SizedBox(height: 20),
                  Text('Seleccionar del Catálogo Maestro:', style: DesignTokens.labelStyle(color: DesignTokens.primary)),
                  const SizedBox(height: 12),
                  Container(
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: DesignTokens.outline.withOpacity(0.2)),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: sortedCatalog.length,
                      itemBuilder: (ctx, i) {
                        final item = sortedCatalog[i];
                        final isAlreadyAdded = _productos.any((p) => p['codigo'] == item['producto']);
                        
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isAlreadyAdded ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                            color: isAlreadyAdded ? DesignTokens.success : DesignTokens.primary.withOpacity(0.5),
                          ),
                          title: Text(item['descripcion'] ?? '', style: DesignTokens.bodyStyle(color: isAlreadyAdded ? DesignTokens.onSurfaceVariant : DesignTokens.onSurface).copyWith(
                            fontWeight: isAlreadyAdded ? FontWeight.bold : FontWeight.normal,
                          )),
                          subtitle: Text('Código: ${item['producto']} • ${item['unidad']}', style: DesignTokens.bodyStyle(color: DesignTokens.onSurfaceVariant).copyWith(fontSize: 12)),
                          trailing: isAlreadyAdded ? Text('Ya agregado', style: DesignTokens.labelStyle(color: DesignTokens.success).copyWith(fontSize: 10)) : null,
                          onTap: isAlreadyAdded ? null : () {
                            setModalState(() {
                              descController.text = item['descripcion'] ?? '';
                              codeController.text = item['producto'] ?? '';
                              selectedUnidad = item['unidad'] ?? 'UN';
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: descController,
                    style: DesignTokens.bodyStyle(color: DesignTokens.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Descripción confirmada',
                      prefixIcon: const Icon(Icons.inventory_2_outlined, color: DesignTokens.primary),
                      filled: true,
                      fillColor: DesignTokens.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: codeController,
                          style: DesignTokens.bodyStyle(color: DesignTokens.onSurface),
                          decoration: InputDecoration(
                            labelText: 'Código',
                            filled: true,
                            fillColor: DesignTokens.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedUnidad,
                          style: DesignTokens.bodyStyle(color: DesignTokens.onSurface),
                          decoration: InputDecoration(
                            labelText: 'Unidad',
                            filled: true,
                            fillColor: DesignTokens.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          items: ['KG', 'Kg', 'kg', 'UN', 'Uni', 'L', 'Lts', 'Tambor', 'Bolsa x 50 Kg', 'Caja x 600 Uni']
                              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (v) => setModalState(() => selectedUnidad = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: saveProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DesignTokens.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: Text('GUARDAR PRODUCTO', style: DesignTokens.labelStyle(color: Colors.white).copyWith(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
