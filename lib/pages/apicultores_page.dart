import 'dart:async';
import 'package:flutter/material.dart';
import '../backend/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'apicultor_detalle.dart';
import 'package:go_router/go_router.dart';
import '../backend/design_tokens.dart';
import 'package:hive/hive.dart';

class ApicultoresPageWidget extends StatefulWidget {
  const ApicultoresPageWidget({super.key});

  @override
  State<ApicultoresPageWidget> createState() => _ApicultoresPageWidgetState();
}

class _ApicultoresPageWidgetState extends State<ApicultoresPageWidget> {
  List<Map<String, dynamic>> _apicultores = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

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
      final box = await Hive.openBox('apicultoresCache');
      if (box.containsKey('data')) {
        final cached = box.get('data');
        if (cached != null && cached is List && mounted) {
          final parsed = List<Map<String, dynamic>>.from(
            cached.map((e) => Map<String, dynamic>.from(e as Map))
          );
          parsed.sort((a, b) => (a['nombre'] ?? '').toString().toLowerCase()
              .compareTo((b['nombre'] ?? '').toString().toLowerCase()));
          setState(() {
            _apicultores = parsed;
            _filtered = parsed;
            _loading = false;
          });
        }
      }
    } catch (e) {
      print('Hive cache error: $e');
    }

    try {
      final data = await SupabaseService().getApicultores();
      
      if (mounted) {
        data.sort((a, b) => (a['nombre'] ?? '').toString().toLowerCase()
            .compareTo((b['nombre'] ?? '').toString().toLowerCase()));
            
        setState(() {
          _apicultores = data;
          _filtered = data;
          _loading = false;
        });

        try {
          final box = await Hive.openBox('apicultoresCache');
          await box.put('data', data);
        } catch (e) {
          print('Hive save error: $e');
        }
      }
    } catch (e) {
      try {
        final resp = await Supabase.instance.client
          .from('apicultores')
          .select('*')
          .order('nombre', ascending: true);
        if (mounted) {
          setState(() {
            _apicultores = List<Map<String, dynamic>>.from(resp);
            _filtered = _apicultores;
            _loading = false;
          });
        }
      } catch (e2) {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _onSearch(val);
    });
  }

  void _onSearch(String val) {
    setState(() {
      final filtered = _apicultores.where((a) {
        final name = (a['nombre'] ?? '').toString().toLowerCase();
        final loc = (a['localidad'] ?? '').toString().toLowerCase();
        return name.contains(val.toLowerCase()) || loc.contains(val.toLowerCase());
      }).toList();
      
      filtered.sort((a, b) => (a['nombre'] ?? '').toString().trim().toLowerCase()
          .compareTo((b['nombre'] ?? '').toString().trim().toLowerCase()));
          
      _filtered = filtered;
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
          onPressed: () => context.go('/home'),
        ),
        centerTitle: false,
        title: Text(
          'Directorio de Apicultores',
          style: DesignTokens.headlineStyle(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o localidad...',
                prefixIcon: const Icon(Icons.search, color: DesignTokens.primary),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _loading && _apicultores.isEmpty
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
          boxShadow: [BoxShadow(color: DesignTokens.primary.withOpacity(0.05), blurRadius: 10)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(DesignTokens.primary.withOpacity(0.05)),
            columns: const [
              DataColumn(label: Text('CÓDIGO', style: TextStyle(fontWeight: FontWeight.bold, color: DesignTokens.primary))),
              DataColumn(label: Text('NOMBRE', style: TextStyle(fontWeight: FontWeight.bold, color: DesignTokens.primary))),
              DataColumn(label: Text('LOCALIDAD', style: TextStyle(fontWeight: FontWeight.bold, color: DesignTokens.primary))),
              DataColumn(label: Text('TELÉFONO', style: TextStyle(fontWeight: FontWeight.bold, color: DesignTokens.primary))),
              DataColumn(label: Text('ACCIÓN', style: TextStyle(fontWeight: FontWeight.bold, color: DesignTokens.primary))),
            ],
            rows: _filtered.map((a) {
              final nombre = a['nombre'] ?? 'Sin nombre';
              final localidad = a['localidad'] ?? 'Sin localidad';
              final telefono = a['telefono'] ?? '-';
              final id = a['id']?.toString() ?? '';
              final codigo = a['apicultor_codigo'] ?? (id.length > 6 ? id.substring(0, 6).toUpperCase() : id);

              return DataRow(
                cells: [
                  DataCell(Text(codigo, style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text(nombre)),
                  DataCell(Text(localidad)),
                  DataCell(Text(telefono)),
                  DataCell(
                    TextButton.icon(
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('Ver Detalles'),
                      style: TextButton.styleFrom(foregroundColor: DesignTokens.secondary),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ApicultorDetalleWidget(apicultor: a)),
                        );
                      },
                    )
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
      key: ValueKey(_filtered.length + (_searchController.text.length)),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _filtered.length,
      itemBuilder: (context, index) {
        final a = _filtered[index];
        return _buildApicultorCard(a);
      },
    );
  }

  Widget _buildApicultorCard(Map<String, dynamic> a) {
    final nombre = a['nombre'] ?? 'Sin nombre';
    final localidad = a['localidad'] ?? 'Sin localidad';
    final id = a['id']?.toString() ?? '';
    final codigo = a['apicultor_codigo'] ?? (id.length > 6 ? id.substring(0, 6).toUpperCase() : id);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ApicultorDetalleWidget(apicultor: a)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: DesignTokens.primary.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: DesignTokens.primary, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.person_pin_circle_rounded, color: DesignTokens.secondary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(nombre, 
                          style: DesignTokens.headlineStyle().copyWith(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Text(localidad, style: DesignTokens.bodyStyle(color: DesignTokens.onSurfaceVariant).copyWith(fontSize: 12)),
                ],
              ),
            ),
            Text(
              codigo,
              style: DesignTokens.labelStyle().copyWith(fontSize: 10, color: DesignTokens.primary.withOpacity(0.3)),
            ),
          ],
        ),
      ),
    );
  }
}
