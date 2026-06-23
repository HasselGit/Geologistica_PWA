import 'package:flutter/material.dart';
import '../backend/supabase_service.dart';
import '../backend/design_tokens.dart';
import '../backend/apicultores_data.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class RutaDetalleWidget extends StatefulWidget {
  final String viajeId;
  const RutaDetalleWidget({super.key, required this.viajeId});

  @override
  State<RutaDetalleWidget> createState() => _RutaDetalleWidgetState();
}

class _RutaDetalleWidgetState extends State<RutaDetalleWidget> {
  Map<String, dynamic>? _ruta;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService().getViajeDetalle(widget.viajeId);
      setState(() => _ruta = data);
    } catch (e) {
      print('Error cargando ruta: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: DesignTokens.secondary)));
    if (_ruta == null) return const Scaffold(body: Center(child: Text('No se encontró la ruta')));

    final paradas = List<Map<String, dynamic>>.from(_ruta!['paradas'] ?? []);

    return Scaffold(
      backgroundColor: DesignTokens.surfaceLow,
      appBar: AppBar(
        title: Text('Plan Logístico', style: DesignTokens.headlineStyle().copyWith(fontSize: 17)),
        backgroundColor: DesignTokens.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: DesignTokens.primary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // INFO DE PLANIFICACIÓN
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: DesignTokens.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: DesignTokens.primary.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: Row(
                children: [
                  const Icon(Icons.route_rounded, color: DesignTokens.secondary, size: 32),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOTAL NODOS', style: DesignTokens.labelStyle(color: Colors.white.withOpacity(0.6))),
                      Text('${paradas.length} Paradas', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'Manrope')),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            Text('SECUENCIA DE NODOS', style: DesignTokens.labelStyle()),
            const SizedBox(height: 16),

            if (paradas.isEmpty)
              _buildEmptyState()
            else
              ...paradas.map((p) => _buildNodoItem(p)).toList(),

            const SizedBox(height: 40),

            // BOTÓN DE MAPA DE NODOS
            if (paradas.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.map_rounded),
                  label: const Text('VER NODOS EN MAPA'),
                  style: DesignTokens.secondaryButtonStyle,
                  onPressed: () => _openMap(paradas),
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
        children: [
          Icon(Icons.add_location_alt_outlined, size: 60, color: DesignTokens.primary.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text('Esta ruta aún no tiene nodos asignados.', style: TextStyle(color: DesignTokens.onSurfaceVariant.withOpacity(0.5), fontStyle: FontStyle.italic)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.push('/planificarViaje?editId=${widget.viajeId}'),
            style: DesignTokens.secondaryButtonStyle,
            child: const Text('PLANIFICAR AHORA'),
          ),
        ],
      ),
    );
  }

  Widget _buildNodoItem(Map<String, dynamic> p) {
    final items = List<Map<String, dynamic>>.from(p['parada_items'] ?? []);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // LINEA DE TIEMPO / SECUENCIA
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: DesignTokens.primary, shape: BoxShape.circle),
                child: Center(child: Text('${p['orden_secuencia']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
              ),
              Expanded(child: Container(width: 2, color: DesignTokens.primary.withOpacity(0.1))),
            ],
          ),
          const SizedBox(width: 16),
          // CONTENIDO DEL NODO
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DesignTokens.primary.withOpacity(0.05)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(p['ubicacion'] ?? 'S/N', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: DesignTokens.primary, fontFamily: 'Manrope')),
                      Text((p['tipo'] ?? 'OP').toUpperCase(), style: const TextStyle(color: DesignTokens.secondary, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 12, color: DesignTokens.primary.withOpacity(0.4)),
                      const SizedBox(width: 4),
                      Text(p['localidad'] ?? 'S/D', style: TextStyle(color: DesignTokens.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const Divider(height: 24),
                  if (items.isNotEmpty) ...[
                    Text('REQUERIMIENTOS', style: DesignTokens.labelStyle().copyWith(fontSize: 9)),
                    const SizedBox(height: 8),
                    ...items.map((it) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 12, color: DesignTokens.secondary),
                          const SizedBox(width: 8),
                          Text('${it['producto_codigo']}: ${it['cantidad']} ${it['unidad']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: DesignTokens.primary)),
                        ],
                      ),
                    )),
                  ] else
                    Text('Sin requerimientos específicos', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: DesignTokens.onSurfaceVariant.withOpacity(0.6))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openMap(List<Map<String, dynamic>> paradas) async {
    if (paradas.isEmpty) return;
    
    final paradasOrdenadas = List<Map<String, dynamic>>.from(paradas);
    paradasOrdenadas.sort((a, b) => (a['orden_secuencia'] ?? 0).compareTo(b['orden_secuencia'] ?? 0));

    final intermediateLocalities = paradasOrdenadas
        .map((p) {
          final ubi = (p['ubicacion'] ?? '').toString().trim();
          final loc = (p['localidad'] ?? '').toString().trim();
          if (loc.toLowerCase().contains('sin localidad') || loc.isEmpty || loc == 'S/D') {
            return '';
          }
          
          // Resolver provincia usando el nombre del apicultor (ubicacion)
          String prov = 'La Pampa';
          if (ubi.isNotEmpty) {
            final match = ApicultoresData.fallbackApicultores.firstWhere(
              (a) => a['nombre']?.toString().toLowerCase().trim() == ubi.toLowerCase(),
              orElse: () => <String, dynamic>{},
            );
            if (match.isNotEmpty && match['provincia'] != null) {
              prov = match['provincia'].toString().trim();
            }
          }
          return '$loc, $prov, Argentina';
        })
        .where((s) => s.isNotEmpty)
        .toList();

    final String origin = Uri.encodeComponent('General Pico, La Pampa, Argentina');
    final String destination = Uri.encodeComponent('General Pico, La Pampa, Argentina');
    final String waypoints = intermediateLocalities.isNotEmpty 
        ? Uri.encodeComponent(intermediateLocalities.join('|'))
        : '';
        
    final url = 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&waypoints=$waypoints&travelmode=driving';
    
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      try {
        final uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }
  }
}
