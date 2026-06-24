import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../backend/supabase_service.dart';
import '../backend/design_tokens.dart';
import 'historial_tambor.dart';

class TrazabilidadPage extends StatefulWidget {
  const TrazabilidadPage({Key? key}) : super(key: key);

  @override
  _TrazabilidadPageState createState() => _TrazabilidadPageState();
}

class _TrazabilidadPageState extends State<TrazabilidadPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  
  bool _isLoading = false;
  bool _hasSearched = false;
  List<Map<String, dynamic>> _historyData = [];
  String _searchQuery = '';

  Future<void> _performSearch(String query) async {
    final trimQuery = query.trim();
    if (trimQuery.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _searchQuery = trimQuery;
    });

    try {
      final allPesajes = await SupabaseService().getPesajes();
      
      // Filter locally for matches in id or senasa_codigo
      final matches = allPesajes.where((p) {
        final id = p['id']?.toString().toLowerCase() ?? '';
        final senasa = p['senasa_codigo']?.toString().toLowerCase() ?? '';
        final q = trimQuery.toLowerCase();
        return id.contains(q) || senasa.contains(q);
      }).toList();

      // Sort by created_at ascending to form a timeline
      matches.sort((a, b) {
        final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.now();
        final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.now();
        return dateA.compareTo(dateB);
      });

      setState(() {
        _historyData = matches;
      });
    } catch (e) {
      print('Error during search: $e');
      setState(() {
        _historyData = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWeb = constraints.maxWidth > 900;
        return Scaffold(
          backgroundColor: DesignTokens.surface,
          body: Stack(
            children: [
              const Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(painter: HoneycombPainter()),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: DesignTokens.primary),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Trazabilidad de Tambor',
                            style: DesignTokens.headlineStyle(color: DesignTokens.primary).copyWith(fontSize: 28),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 48.0),
                        child: Text(
                          'Ingrese el ID o código de SENASA para ver el historial de movimientos.',
                          style: DesignTokens.bodyStyle(color: DesignTokens.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.only(left: 48.0, right: 24.0),
                        child: _buildSearchBar(),
                      ),
                      const SizedBox(height: 32),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 48.0, right: 24.0),
                          child: _buildContent(isWeb),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildSearchBar() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: DesignTokens.primary.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: DesignTokens.outline.withOpacity(0.2)),
      ),
      child: RawKeyboardListener(
        focusNode: _searchFocus,
        onKey: (event) {
          if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
            _performSearch(_searchController.text);
          }
        },
        child: TextField(
          controller: _searchController,
          style: DesignTokens.bodyStyle(color: DesignTokens.onSurface),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Buscar por ID o Código SENASA...',
            hintStyle: DesignTokens.bodyStyle(color: DesignTokens.outline),
            prefixIcon: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Icon(Icons.search, color: DesignTokens.secondary),
            ),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.arrow_forward_rounded, color: DesignTokens.primary),
                onPressed: () => _performSearch(_searchController.text),
              ),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          onSubmitted: _performSearch,
        ),
      ),
    );
  }

  Widget _buildContent(bool isWeb) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: DesignTokens.secondary),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner_rounded, size: 64, color: DesignTokens.outline.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'Realice una búsqueda para comenzar',
              style: DesignTokens.bodyStyle(color: DesignTokens.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    if (_historyData.isEmpty) {
      return _buildEmptyState();
    }

    return isWeb 
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 1,
              child: _buildDrumInfoCard(_historyData.first),
            ),
            const SizedBox(width: 32),
            Expanded(
              flex: 2,
              child: HistorialTambor(history: _historyData),
            ),
          ],
        )
      : Column(
          children: [
            _buildDrumInfoCard(_historyData.first),
            const SizedBox(height: 24),
            Expanded(child: HistorialTambor(history: _historyData)),
          ],
        );
  }

  Widget _buildDrumInfoCard(Map<String, dynamic> firstRecord) {
    final String senasa = firstRecord['senasa_codigo']?.toString() ?? 'N/A';
    final String apicultorNombre = firstRecord['apicultores']?['nombre'] ?? '';
    final String apicultorApellido = firstRecord['apicultores']?['apellido'] ?? '';
    final String apicultor = '$apicultorNombre $apicultorApellido'.trim();
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.outline.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: DesignTokens.primary.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DesignTokens.primary.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.propane_tank_rounded, color: DesignTokens.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tambor Seleccionado',
                      style: DesignTokens.labelStyle(color: DesignTokens.onSurfaceVariant),
                    ),
                    Text(
                      firstRecord['id']?.toString() ?? 'Desconocido',
                      style: DesignTokens.bodyStyle(color: DesignTokens.onSurface).copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: DesignTokens.surfaceLow),
          const SizedBox(height: 24),
          _buildInfoRow('Código SENASA', senasa),
          const SizedBox(height: 16),
          _buildInfoRow('Apicultor', apicultor.isEmpty ? 'N/A' : apicultor),
          const SizedBox(height: 16),
          _buildInfoRow('Último Peso Neto', '${_historyData.last['peso_neto'] ?? 0} kg'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: DesignTokens.bodyStyle(color: DesignTokens.onSurfaceVariant)),
        Flexible(
          child: Text(
            value, 
            style: DesignTokens.bodyStyle(color: DesignTokens.onSurface).copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DesignTokens.outline.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: DesignTokens.primary.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: DesignTokens.surfaceLow,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded, size: 48, color: DesignTokens.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Text(
              'No se encontraron resultados',
              style: DesignTokens.headlineStyle(color: DesignTokens.primary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'No existe ningún registro de pesaje asociado al ID o código SENASA "$_searchQuery". Verifica el dato e intenta nuevamente.',
              style: DesignTokens.bodyStyle(color: DesignTokens.onSurfaceVariant).copyWith(height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _hasSearched = false;
                  _searchQuery = '';
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Limpiar Búsqueda'),
              style: DesignTokens.secondaryButtonStyle,
            ),
          ],
        ),
      ),
    );
  }
}
