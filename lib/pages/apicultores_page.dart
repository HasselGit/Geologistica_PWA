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

  int _currentPage = 0;
  final int _rowsPerPage = 15;

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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o localidad...',
                prefixIcon: const Icon(Icons.search, color: DesignTokens.primary),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: DesignTokens.outline.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: DesignTokens.outline.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: DesignTokens.primary),
                ),
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
    int totalPages = (_filtered.length / _rowsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;
    if (_currentPage >= totalPages) _currentPage = totalPages - 1;
    if (_currentPage < 0) _currentPage = 0;

    int startIndex = _currentPage * _rowsPerPage;
    int endIndex = startIndex + _rowsPerPage;
    if (endIndex > _filtered.length) endIndex = _filtered.length;
    
    List<Map<String, dynamic>> paginated = _filtered.sublist(startIndex, endIndex);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DesignTokens.outline.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(DesignTokens.surfaceLow),
                dataRowMinHeight: 60,
                dataRowMaxHeight: 60,
                horizontalMargin: 24,
                columns: const [
                  DataColumn(label: Text('CÓDIGO', style: TextStyle(fontWeight: FontWeight.bold, color: DesignTokens.primary, fontSize: 13))),
                  DataColumn(label: Text('NOMBRE', style: TextStyle(fontWeight: FontWeight.bold, color: DesignTokens.primary, fontSize: 13))),
                  DataColumn(label: Text('LOCALIDAD', style: TextStyle(fontWeight: FontWeight.bold, color: DesignTokens.primary, fontSize: 13))),
                  DataColumn(label: Text('TELÉFONO', style: TextStyle(fontWeight: FontWeight.bold, color: DesignTokens.primary, fontSize: 13))),
                  DataColumn(label: Text('ACCIÓN', style: TextStyle(fontWeight: FontWeight.bold, color: DesignTokens.primary, fontSize: 13))),
                ],
                rows: paginated.map((a) {
                  final nombre = a['nombre'] ?? 'Sin nombre';
                  final localidad = a['localidad'] ?? 'Sin localidad';
                  final telefono = a['telefono'] ?? '-';
                  final id = a['id']?.toString() ?? '';
                  final codigo = a['apicultor_codigo'] ?? (id.length > 6 ? id.substring(0, 6).toUpperCase() : id);

                  return DataRow(
                    cells: [
                      DataCell(Text(codigo, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'JetBrains Mono'))),
                      DataCell(Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(localidad, style: const TextStyle(color: DesignTokens.onSurfaceVariant))),
                      DataCell(Text(telefono, style: const TextStyle(fontFamily: 'JetBrains Mono', color: DesignTokens.onSurfaceVariant))),
                      DataCell(
                        TextButton.icon(
                          icon: const Icon(Icons.visibility_rounded, size: 18),
                          label: const Text('Ver Perfil', style: TextStyle(fontWeight: FontWeight.w600)),
                          style: TextButton.styleFrom(
                            foregroundColor: DesignTokens.secondary,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
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
            if (totalPages > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: DesignTokens.outline.withOpacity(0.1))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mostrando ${startIndex + 1} - $endIndex de ${_filtered.length} apicultores',
                      style: const TextStyle(color: DesignTokens.onSurfaceVariant, fontSize: 13),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded),
                          onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                          color: _currentPage > 0 ? DesignTokens.primary : DesignTokens.outline,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Página ${_currentPage + 1} de $totalPages',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                          color: _currentPage < totalPages - 1 ? DesignTokens.primary : DesignTokens.outline,
                        ),
                      ],
                    )
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DesignTokens.outline.withOpacity(0.1)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: DesignTokens.surfaceLow, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.person_pin_circle_rounded, color: DesignTokens.secondary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre, 
                    style: DesignTokens.headlineStyle().copyWith(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(localidad, style: DesignTokens.bodyStyle(color: DesignTokens.onSurfaceVariant).copyWith(fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: DesignTokens.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                codigo,
                style: const TextStyle(fontSize: 10, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w600, color: DesignTokens.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
