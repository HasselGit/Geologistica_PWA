import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../backend/design_tokens.dart';
import '../backend/pdf_invoice_generator.dart';

class RemitoCargaPageWidget extends StatefulWidget {
  final String cargaId;

  const RemitoCargaPageWidget({super.key, required this.cargaId});

  @override
  State<RemitoCargaPageWidget> createState() => _RemitoCargaPageWidgetState();
}

class _RemitoCargaPageWidgetState extends State<RemitoCargaPageWidget> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _carga;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('cargas')
          .select('*, viaje:viaje_id(*, vehiculos:vehiculo_codigo(*)), carga_items(*)')
          .eq('id', widget.cargaId)
          .maybeSingle();

      if (res == null) throw Exception('Carga no encontrada');

      // Fetch profile (chofer) separately to avoid foreign key join issues
      final viaje = res['viaje'];
      if (viaje != null && viaje['chofer_id'] != null) {
        try {
          final chofer = await Supabase.instance.client
              .from('profiles')
              .select('nombre, apellido')
              .eq('id', viaje['chofer_id'])
              .maybeSingle();
          viaje['profiles'] = chofer;
        } catch (e) {
          print('Error loading chofer profile for remito: $e');
        }
      }
      
      setState(() {
        _carga = res;
        _items = List<Map<String, dynamic>>.from(res['carga_items'] ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _shareWhatsApp() async {
    final code = _carga?['carga_codigo'] ?? 'S/C';
    final remitoCode = code.replaceAll(RegExp(r'carga-', caseSensitive: false), 'PI-').replaceAll(RegExp(r'car-', caseSensitive: false), 'PI-');
    final viaje = _carga?['viaje']?['viaje_codigo'] ?? 'S/V';
    final chofer = '${_carga?['viaje']?['profiles']?['nombre'] ?? ''} ${_carga?['viaje']?['profiles']?['apellido'] ?? ''}'.trim();
    
    String itemsText = '';
    for (var it in _items) {
      itemsText += '\n• ${it['producto_codigo']}: ${it['cantidad']} ${it['unidad']}';
    }

    final String text = '* GeoLogística - Remito de Carga *\n\n'
        'Remito Nro: $remitoCode\n'
        'ID Carga: $code\n'
        'Viaje: $viaje\n'
        'Chofer: $chofer\n'
        'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(_carga?['updated_at'] ?? DateTime.now().toIso8601String()))}\n'
        '\n*Detalle:*$itemsText\n\n'
        'Confirmado por Depósito.';

    final String url = 'https://wa.me/?text=${Uri.encodeComponent(text)}';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalNonBrowserApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp')));
    }
  }

  Future<Uint8List> _generatePdfBytes() async {
    final chofer = '${_carga?['viaje']?['profiles']?['nombre'] ?? ''} ${_carga?['viaje']?['profiles']?['apellido'] ?? ''}'.trim();
    final String updatedAtDate = _carga?['updated_at'] ?? DateTime.now().toIso8601String();
    final String code = _carga?['carga_codigo'] ?? 'S/C';
    final String remitoCode = code.replaceAll(RegExp(r'carga-', caseSensitive: false), 'PI-').replaceAll(RegExp(r'car-', caseSensitive: false), 'PI-');

    Uint8List? logoBytes;
    try {
      final logoData = await rootBundle.load('assets/images/geomiel_logo.png');
      logoBytes = logoData.buffer.asUint8List();
    } catch (e) {
      print('Error cargando geomiel_logo.png para remito de carga: $e');
    }

    return await PdfInvoiceGenerator.generateCargaManifestPDF(
      cargaCodigo: code,
      remitoCodigo: remitoCode,
      viajeCodigo: _carga?['viaje']?['viaje_codigo'] ?? 'S/V',
      choferNombre: chofer,
      vehiculoCodigo: _carga?['viaje']?['vehiculo_codigo'] ?? 'S/D',
      updatedAtDate: updatedAtDate,
      items: _items,
      logoBytes: logoBytes,
    );
  }

  void _showPdfPreviewDialog(BuildContext context, Uint8List pdfBytes, String title) {
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
        body: PdfPreview(
          build: (format) => pdfBytes,
          allowPrinting: true,
          allowSharing: true,
          canChangePageFormat: false,
          dynamicLayout: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(appBar: AppBar(), body: Center(child: Text(_error!)));
    
    final code = _carga?['carga_codigo'] ?? 'S/C';
    final remitoCode = code.replaceAll(RegExp(r'carga-', caseSensitive: false), 'PI-').replaceAll(RegExp(r'car-', caseSensitive: false), 'PI-');
    final via = _carga?['viaje']?['viaje_codigo'] ?? 'S/V';

    return Scaffold(
      backgroundColor: DesignTokens.surfaceLow,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface,
        title: Text('Remito de Carga', style: DesignTokens.headlineStyle().copyWith(fontSize: 17)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('COMPROBANTE DIGITAL', style: TextStyle(color: DesignTokens.secondary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                          Text(remitoCode, style: DesignTokens.headlineStyle().copyWith(fontSize: 24)),
                        ],
                      ),
                      const Icon(Icons.qr_code_2, size: 48, color: DesignTokens.primary),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),
                  _infoRow('Número de Carga', code),
                  _infoRow('Viaje', via),
                  _infoRow('Fecha', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(_carga?['updated_at'] ?? DateTime.now().toIso8601String()))),
                  _infoRow('Vehículo', _carga?['viaje']?['vehiculo_codigo'] ?? 'S/D'),
                  const SizedBox(height: 20),
                  const Text('DETALLE DE ÍTEMS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  ..._items.map((it) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(child: Text(it['producto_codigo'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                        Text('${it['cantidad']} ${it['unidad']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )).toList(),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _shareWhatsApp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), 
                  foregroundColor: Colors.white, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('ENVIAR POR WHATSAPP', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.visibility_outlined,
                    label: 'VER',
                    backgroundColor: const Color(0xFFE0F2FE),
                    textColor: const Color(0xFF0369A1),
                    onTap: () async {
                      final bytes = await _generatePdfBytes();
                      if (mounted) {
                        _showPdfPreviewDialog(context, bytes, 'Comprobante Carga $code');
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
                      final bytes = await _generatePdfBytes();
                      await Printing.sharePdf(bytes: bytes, filename: 'Comprobante_Carga_$code.pdf');
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
                      final bytes = await _generatePdfBytes();
                      await Printing.layoutPdf(onLayout: (format) => bytes);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: DesignTokens.primary)),
        ],
      ),
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
