import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/supabase_service.dart';
import '../backend/productos_data.dart';
import 'package:hive/hive.dart';

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

  static const kPrimary = Color(0xFF08201A);
  static const kSecContainer = Color(0xFFFDBE49);
  static const kSurface = Color(0xFFFBF9F8);

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
      print('Hive cache error: $e');
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
          print('Hive save error: $e');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filterProducts(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _filteredProductos = _productos.where((p) {
          final desc = (p['descripcion'] ?? '').toString().toLowerCase();
          final cod = (p['codigo'] ?? '').toString().toLowerCase();
          return desc.contains(query.toLowerCase()) || cod.contains(query.toLowerCase());
        }).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        title: const Text('Inventario de Productos', style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: kPrimary), onPressed: () => context.pop()),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: TextField(
              controller: _searchController,
              onChanged: _filterProducts,
              decoration: InputDecoration(
                hintText: 'Buscar producto o código...',
                prefixIcon: const Icon(Icons.search, color: kPrimary),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: _loading && _productos.isEmpty
              ? const Center(child: CircularProgressIndicator(color: kSecContainer))
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
      floatingActionButton: (_userRole == 'CEO' || _userRole == 'Gerente' || _userRole == 'Compras') 
        ? FloatingActionButton(
            onPressed: _addProduct,
            backgroundColor: kPrimary,
            child: const Icon(Icons.add, color: kSecContainer),
          )
        : null,
    );
  }

  Widget _buildWebTable() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(kPrimary.withOpacity(0.05)),
            columns: const [
              DataColumn(label: Text('CÓDIGO', style: TextStyle(fontWeight: FontWeight.bold, color: kPrimary))),
              DataColumn(label: Text('DESCRIPCIÓN', style: TextStyle(fontWeight: FontWeight.bold, color: kPrimary))),
              DataColumn(label: Text('UNIDAD', style: TextStyle(fontWeight: FontWeight.bold, color: kPrimary))),
              DataColumn(label: Text('ACCIÓN', style: TextStyle(fontWeight: FontWeight.bold, color: kPrimary))),
            ],
            rows: _filteredProductos.map((p) {
              return DataRow(
                cells: [
                  DataCell(Text(p['codigo'] ?? 'S/C', style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text(p['descripcion'] ?? 'Sin descripción')),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: kSecContainer.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                    child: Text(p['unidad'] ?? 'UN', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: kPrimary)),
                  )),
                  DataCell(
                    (_userRole == 'CEO' || _userRole == 'Gerente' || _userRole == 'Compras')
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: kPrimary),
                              onPressed: () => _editProduct(p),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              onPressed: () => _confirmDelete(p),
                            ),
                          ],
                        )
                      : const SizedBox(),
                  ),
                ],
              );
            }).toList(),
          ),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: kPrimary.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.inventory_2_rounded, color: kPrimary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['descripcion'] ?? 'Sin descripción', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Código: ${p['codigo'] ?? 'S/C'}', style: const TextStyle(fontSize: 12, color: Colors.black45)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: kSecContainer.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Text(p['unidad'] ?? 'UN', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: kPrimary)),
          ),
          if (_userRole == 'CEO' || _userRole == 'Gerente' || _userRole == 'Compras') ...[
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black26, size: 20),
              onSelected: (val) {
                if (val == 'edit') _editProduct(p);
                if (val == 'delete') _confirmDelete(p);
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Editar')])),
                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))])),
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Editar Producto', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPrimary)),
              const SizedBox(height: 20),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: 'Descripción',
                  prefixIcon: const Icon(Icons.inventory_2_outlined, color: kPrimary),
                  filled: true,
                  fillColor: kSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: codeController,
                      decoration: InputDecoration(
                        labelText: 'Código',
                        filled: true,
                        fillColor: kSurface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedUnidad,
                      decoration: InputDecoration(
                        labelText: 'Unidad',
                        filled: true,
                        fillColor: kSurface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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
                  onPressed: () async {
                    if (descController.text.isEmpty) return;
                    try {
                      await SupabaseService().updateProducto(p['id'].toString(), {
                        'descripcion': descController.text,
                        'codigo': codeController.text,
                        'unidad': selectedUnidad,
                      });
                      if (mounted) Navigator.pop(ctx);
                      _fetchData();
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('ACTUALIZAR PRODUCTO', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar producto?'),
        content: Text('El producto "${p['descripcion']}" se ocultará pero se mantendrá en el historial.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')),
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
            child: const Text('ELIMINAR', style: TextStyle(color: Colors.red))
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nuevo Producto', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPrimary)),
              const SizedBox(height: 20),
              const Text('Seleccionar del Catálogo Maestro:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kPrimary)),
              const SizedBox(height: 12),
              Container(
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kPrimary.withOpacity(0.1)),
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
                        color: isAlreadyAdded ? Colors.green : kPrimary.withOpacity(0.5),
                      ),
                      title: Text(item['descripcion'] ?? '', style: TextStyle(
                        fontWeight: isAlreadyAdded ? FontWeight.bold : FontWeight.normal,
                        color: isAlreadyAdded ? Colors.black45 : Colors.black,
                      )),
                      subtitle: Text('Código: ${item['producto']} • ${item['unidad']}'),
                      trailing: isAlreadyAdded ? const Text('Ya agregado', style: TextStyle(fontSize: 10, color: Colors.green)) : null,
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
                decoration: InputDecoration(
                  labelText: 'Descripción confirmada',
                  prefixIcon: const Icon(Icons.inventory_2_outlined, color: kPrimary),
                  filled: true,
                  fillColor: kSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: codeController,
                      decoration: InputDecoration(
                        labelText: 'Código',
                        filled: true,
                        fillColor: kSurface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedUnidad,
                      decoration: InputDecoration(
                        labelText: 'Unidad',
                        filled: true,
                        fillColor: kSurface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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
                  onPressed: () async {
                    if (descController.text.isEmpty) return;
                    try {
                      await Supabase.instance.client.from('productos').insert({
                        'descripcion': descController.text,
                        'codigo': codeController.text,
                        'unidad': selectedUnidad,
                      });
                      Navigator.pop(ctx);
                      _fetchData();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: const Text('GUARDAR PRODUCTO', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
