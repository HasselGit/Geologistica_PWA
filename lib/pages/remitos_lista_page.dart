import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../backend/supabase_service.dart';
import '../backend/design_tokens.dart';
import '../widgets/geo_sidebar.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;

class RemitosListaPageWidget extends StatefulWidget {
  const RemitosListaPageWidget({super.key});

  @override
  State<RemitosListaPageWidget> createState() => _RemitosListaPageWidgetState();
}

class _RemitosListaPageWidgetState extends State<RemitosListaPageWidget> {
  bool _loading = true;
  String? _userRole;
  String? _userEmail;
  String? _displayName;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _remitos = [];
  List<Map<String, dynamic>> _filtered = [];
  String _activeFilter = 'Todos';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _userRole = prefs.getString('user_puesto');
          _userEmail = prefs.getString('user_email');
          _displayName = prefs.getString('user_name') ?? _userEmail;
        });
      }
      final data = await SupabaseService().getRemitos();
      if (mounted) {
        setState(() {
          _remitos = data;
          _filtered = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: DesignTokens.primary, size: 20),
          onPressed: () => context.go('/home'),
        ),
        centerTitle: false,
        title: Text('Remitos PDF', style: DesignTokens.headlineStyle()),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Gestión y control de documentación de carga.', style: DesignTokens.bodyStyle().copyWith(color: Colors.black38, fontSize: 14)),
          ),
          const SizedBox(height: 24),
          _buildSearchAndFilter(),
          const SizedBox(height: 24),
          _buildFilterChips(),
          const SizedBox(height: 24),
          Expanded(
            child: _loading 
              ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
              : _filtered.isEmpty 
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) => _buildRemitoCard(_filtered[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => _applyFilters(),
                decoration: const InputDecoration(
                  hintText: 'Buscar por Productor o ID...',
                  hintStyle: TextStyle(fontSize: 14, color: Colors.black26),
                  prefixIcon: Icon(Icons.search, size: 20, color: Colors.black26),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 48, width: 48,
            decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.tune_rounded, color: Colors.black38),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final chips = ['Todos', 'Mixta', 'Recolecciones', 'Distribuciones', 'Esta Semana'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: 20),
      child: Row(
        children: chips.map((c) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: ChoiceChip(
            label: Text(c),
            selected: _activeFilter == c,
            onSelected: (val) {
              setState(() {
                _activeFilter = c;
                _applyFilters();
              });
            },
            selectedColor: const Color(0xFF1E302C),
            labelStyle: TextStyle(
              color: _activeFilter == c ? Colors.white : Colors.black38,
              fontWeight: FontWeight.bold,
              fontSize: 12
            ),
            backgroundColor: const Color(0xFFF5F5F5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        )).toList(),
      ),
    );
  }

  void _applyFilters() {
    setState(() {
      _filtered = _remitos.where((r) {
        final matchesSearch = _searchController.text.isEmpty || 
          (r['apicultor_nombre'] ?? '').toString().toLowerCase().contains(_searchController.text.toLowerCase()) ||
          (r['remito_codigo'] ?? '').toString().toLowerCase().contains(_searchController.text.toLowerCase());
        
        if (_activeFilter == 'Todos') return matchesSearch;
        if (_activeFilter == 'Recolecciones') return matchesSearch && r['tipo_categoria'] == 'Recolecciones';
        if (_activeFilter == 'Distribuciones') return matchesSearch && r['tipo_categoria'] == 'Distribuciones';
        if (_activeFilter == 'Mixta') return matchesSearch && r['tipo_categoria'] == 'Mixta';
        if (_activeFilter == 'Esta Semana') {
          final dateStr = r['created_at']?.toString() ?? '';
          final date = DateTime.tryParse(dateStr);
          if (date != null) {
            final now = DateTime.now();
            final diff = now.difference(date).inDays;
            return matchesSearch && diff <= 7;
          }
        }
        return matchesSearch;
      }).toList();
    });
  }

  Widget _buildRemitoCard(Map<String, dynamic> r) {
    final statusRaw = r['estado'] ?? 'FIRMADO';
    final status = statusRaw == 'PENDIENTE' ? 'FIRMADO' : statusRaw;
    final isSigned = status == 'FIRMADO' || status == 'Emitido' || status == 'FIRMADA';
    final statusColor = isSigned ? const Color(0xFF4CAF50) : const Color(0xFFFFC107);
    
    final apicultorNombre = r['apicultor_nombre'] ?? 'Apicultor S/D';
    final apicultorLocalidad = r['apicultor_localidad'] ?? 'Sin localidad';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                 decoration: BoxDecoration(color: const Color(0xFFFDF7E7), borderRadius: BorderRadius.circular(8)),
                 child: Text('ID: ${r['remito_codigo'] ?? 'V-2024-000'}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC68E17))),
               ),
              Row(
                children: [
                  CircleAvatar(radius: 3, backgroundColor: statusColor),
                  const SizedBox(width: 6),
                  Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('$apicultorNombre ($apicultorLocalidad)', style: DesignTokens.headlineStyle().copyWith(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildCardInfo(Icons.local_shipping_outlined, 'TIPO', r['tipo_display'] ?? 'Recolección'),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(height: 1, color: Color(0xFFF5F5F5)),
          ),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.black26),
              const SizedBox(width: 8),
              Text(DateFormat('dd MMM yyyy • HH:mm').format(DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now()), 
                style: const TextStyle(fontSize: 12, color: Colors.black38)),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.visibility_outlined,
                  label: 'VER',
                  backgroundColor: const Color(0xFFE0F2FE),
                  textColor: const Color(0xFF0369A1),
                  onTap: () {
                    final url = r['pdf_url'];
                    if (url != null) {
                      _showPdfPreviewDialog(context, url, 'Remito ${r['remito_codigo']}');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL del PDF no disponible')));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.download_rounded,
                  label: 'DESCARGAR',
                  backgroundColor: const Color(0xFFF0FDF4),
                  textColor: const Color(0xFF15803D),
                  onTap: () async {
                    final url = r['pdf_url'];
                    if (url != null) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => const Center(child: CircularProgressIndicator(color: DesignTokens.secondary)),
                      );
                      try {
                        final resp = await http.get(Uri.parse(url));
                        if (context.mounted) Navigator.pop(context); // Close loading dialog
                        await Printing.sharePdf(bytes: resp.bodyBytes, filename: 'Remito_${r['remito_codigo']}.pdf');
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al descargar: $e')));
                        }
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL del PDF no disponible')));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.print_outlined,
                  label: 'IMPRIMIR',
                  backgroundColor: const Color(0xFFFEF3C7),
                  textColor: const Color(0xFFB45309),
                  onTap: () async {
                    final url = r['pdf_url'];
                    if (url != null) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => const Center(child: CircularProgressIndicator(color: DesignTokens.secondary)),
                      );
                      try {
                        final resp = await http.get(Uri.parse(url));
                        if (context.mounted) Navigator.pop(context); // Close loading dialog
                        await Printing.layoutPdf(onLayout: (format) => resp.bodyBytes);
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al imprimir: $e')));
                        }
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL del PDF no disponible')));
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPdfPreviewDialog(BuildContext context, String url, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Scaffold(
        appBar: AppBar(
          backgroundColor: DesignTokens.primary,
          elevation: 0,
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(ctx),
          ),
        ),
        body: FutureBuilder<Uint8List>(
          future: http.get(Uri.parse(url)).then((response) => response.bodyBytes),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: DesignTokens.secondary));
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error al cargar PDF: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
              ));
            }
            return PdfPreview(
              build: (format) => snapshot.data!,
              allowPrinting: true,
              allowSharing: true,
              canChangePageFormat: false,
              dynamicLayout: false,
            );
          },
        ),
      ),
    );
  }

  Widget _buildCardInfo(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.black38),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black38)),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF424846))),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.description_outlined, size: 48, color: Colors.black12),
          const SizedBox(height: 16),
          Text('No hay remitos disponibles', style: DesignTokens.bodyStyle().copyWith(color: Colors.black38)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final mainLayout = isDesktop
        ? Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.fromLTRB(120, 48, 40, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Premium
                Row(
                  children: [
                    InkWell(
                      onTap: () => context.canPop() ? context.pop() : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: DesignTokens.primary.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 16, color: DesignTokens.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => context.go('/home'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: DesignTokens.primary.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: const Icon(Icons.home_rounded,
                            size: 18, color: DesignTokens.primary),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Histórico Remitos',
                      style: DesignTokens.headlineStyle(color: DesignTokens.primary)
                          .copyWith(fontSize: 24),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Main Content (Left Search Filter + Right Table)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Filter Box (Width 320px)
                      Container(
                        width: 320,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: DesignTokens.outline.withValues(alpha: 0.15)),
                          boxShadow: [
                            BoxShadow(
                              color: DesignTokens.primary.withValues(alpha: 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('BÚSQUEDA',
                                style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: DesignTokens.onSurfaceVariant)),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _searchController,
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'ID, Nombre...',
                                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: DesignTokens.primary),
                                filled: true,
                                fillColor: DesignTokens.surfaceLow,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none),
                              ),
                              onChanged: (_) => _applyFilters(),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                style: DesignTokens.primaryButtonStyle.copyWith(
                                  shape: WidgetStateProperty.all(
                                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                icon: const Icon(Icons.filter_list_rounded, size: 16),
                                label: const Text('Aplicar Filtros',
                                    style: TextStyle(
                                        fontFamily: 'Work Sans',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                onPressed: () => _applyFilters(),
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right DataGrid
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: DesignTokens.outline.withValues(alpha: 0.1)),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4)),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              children: [
                                Positioned(
                                  bottom: -20,
                                  right: -20,
                                  child: Icon(Icons.receipt_long_rounded,
                                      size: 120,
                                      color: DesignTokens.primary.withValues(alpha: 0.03)),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                          border: Border(
                                              bottom: BorderSide(
                                                  color: DesignTokens.primary
                                                      .withValues(alpha: 0.05)))),
                                      child: const Text(
                                        'REMITOS PDF GENERADOS',
                                        style: TextStyle(
                                            fontFamily: 'Manrope',
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            letterSpacing: 1.2,
                                            color: DesignTokens.primary),
                                      ),
                                    ),
                                    Expanded(
                                      child: _loading
                                          ? const Center(
                                              child: CircularProgressIndicator(
                                                  color: DesignTokens.secondary))
                                          : SingleChildScrollView(
                                              child: DataTable(
                                                headingRowColor: WidgetStateProperty.all(
                                                    DesignTokens.surfaceLow.withValues(alpha: 0.5)),
                                                dataRowMinHeight: 50,
                                                dataRowMaxHeight: 50,
                                                horizontalMargin: 20,
                                                columnSpacing: 20,
                                                columns: const [
                                                  DataColumn(
                                                      label: Text('ID REMITO',
                                                          style: TextStyle(
                                                              fontFamily: 'Work Sans',
                                                              fontWeight: FontWeight.w700,
                                                              fontSize: 11,
                                                              color: DesignTokens.primary))),
                                                  DataColumn(
                                                      label: Text('APICULTOR / LOC',
                                                          style: TextStyle(
                                                              fontFamily: 'Work Sans',
                                                              fontWeight: FontWeight.w700,
                                                              fontSize: 11,
                                                              color: DesignTokens.primary))),
                                                  DataColumn(
                                                      label: Text('ESTADO',
                                                          style: TextStyle(
                                                              fontFamily: 'Work Sans',
                                                              fontWeight: FontWeight.w700,
                                                              fontSize: 11,
                                                              color: DesignTokens.primary))),
                                                  DataColumn(
                                                      label: Text('ACCIÓN',
                                                          style: TextStyle(
                                                              fontFamily: 'Work Sans',
                                                              fontWeight: FontWeight.w700,
                                                              fontSize: 11,
                                                              color: DesignTokens.primary))),
                                                ],
                                                rows: _filtered.map((r) {
                                                  final statusRaw = r['estado'] ?? 'FIRMADO';
                                                  final status = statusRaw == 'PENDIENTE' ? 'FIRMADO' : statusRaw;
                                                  final isSigned = status == 'FIRMADO' || status == 'Emitido' || status == 'FIRMADA';
                                                  
                                                  final apicultorNombre = r['apicultor_nombre'] ?? 'Apicultor S/D';
                                                  final apicultorLocalidad = r['apicultor_localidad'] ?? 'Sin localidad';

                                                  return DataRow(
                                                    cells: [
                                                      DataCell(Text(r['remito_codigo'] ?? '-', style: const TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w600, color: DesignTokens.primary))),
                                                      DataCell(Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Text(apicultorNombre, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13, color: DesignTokens.primary)),
                                                          Text(apicultorLocalidad, style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: DesignTokens.onSurfaceVariant)),
                                                        ],
                                                      )),
                                                      DataCell(
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: isSigned ? const Color(0xFF4CAF50).withValues(alpha: 0.1) : const Color(0xFFFFC107).withValues(alpha: 0.1),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(status, style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 10, color: isSigned ? const Color(0xFF4CAF50) : const Color(0xFFC68E17))),
                                                        )
                                                      ),
                                                      DataCell(
                                                        TextButton.icon(
                                                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                                                          label: const Text('PDF', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w700)),
                                                          style: TextButton.styleFrom(foregroundColor: DesignTokens.primary),
                                                          onPressed: () {},
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                }).toList(),
                                              ),
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
                  ),
                ),
              ],
            ),
          )
        : Column(
            children: [
              AppBar(
                backgroundColor: DesignTokens.surface,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: DesignTokens.primary, size: 18),
                  onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                ),
                title: const Text(
                  'Histórico Remitos',
                  style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold, color: DesignTokens.primary),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.home_rounded, color: DesignTokens.primary),
                    onPressed: () => context.go('/home'),
                  ),
                ],
              ),
              Expanded(child: _buildMobileLayout(context)),
            ],
          );

    final content = Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: const HoneycombPainter()),
          ),
        ),
        mainLayout,
      ],
    );

    return Scaffold(
      backgroundColor: DesignTokens.surfaceLow,
      body: isDesktop
          ? Row(
              children: [
                GeoSidebar(
                  userRole: _userRole ?? '',
                  userEmail: _userEmail ?? '',
                  displayName: _displayName ?? _userEmail ?? '',
                ),
                Expanded(child: content),
              ],
            )
          : content,
    );
  }
}
