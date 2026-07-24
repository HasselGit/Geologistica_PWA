import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:signature/signature.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../backend/design_tokens.dart';
import '../backend/pdf_invoice_generator.dart';
import '../backend/apicultores_data.dart';

class RemitoPageWidget extends StatefulWidget {
  final String paradaId;
  final String? receptorTipo;
  final String? receptorNombre;
  final String? receptorDni;

  const RemitoPageWidget({
    super.key, 
    required this.paradaId,
    this.receptorTipo,
    this.receptorNombre,
    this.receptorDni,
  });

  static String routeName = 'RemitoPage';
  static String routePath = '/remito';

  @override
  State<RemitoPageWidget> createState() => _RemitoPageWidgetState();
}

class _RemitoPageWidgetState extends State<RemitoPageWidget> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _paradaData;
  Map<String, dynamic>? _viajeData;
  List<Map<String, dynamic>> _items = [];
  String? _depositoOrigen;

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.transparent,
  );

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final parada = await Supabase.instance.client
          .from('paradas')
          .select('id, viaje_id, solicitud_id, orden_secuencia, tipo, ubicacion, localidad, estado, carga_kg')
          .eq('id', widget.paradaId)
          .maybeSingle();

      if (parada == null) throw Exception('Parada no encontrada');

      // NEW: Try to find apicultor_id by name (ubicacion) to link the remito correctly
      String? apiId;
      String? apiTelefono;
      try {
        final api = await Supabase.instance.client
            .from('apicultores')
            .select('id, apicultor_codigo, telefono')
            .eq('nombre', parada['ubicacion'] ?? '')
            .maybeSingle();
        apiId = api?['apicultor_codigo'] ?? api?['id'];
        apiTelefono = api?['telefono']?.toString();
      } catch (_) {}
      
      if (apiTelefono == null || apiTelefono.trim().isEmpty) {
        final String searchName = (parada['ubicacion'] ?? '').toString().toLowerCase().trim();
        final match = ApicultoresData.fallbackApicultores.firstWhere(
          (a) => a['nombre'].toString().toLowerCase().trim() == searchName,
          orElse: () => <String, dynamic>{},
        );
        if (match.isNotEmpty && match['telefono'] != null) {
          apiTelefono = match['telefono'].toString();
        }
      }
      
      _paradaData = parada;
      if (apiId != null) _paradaData!['apicultor_id'] = apiId;
      if (apiTelefono != null) _paradaData!['apicultor_telefono'] = apiTelefono;

      final itemsRaw = await Supabase.instance.client
          .from('parada_items')
          .select('id, producto_codigo, cantidad, unidad')
          .eq('parada_id', widget.paradaId);
      
      _items = List<Map<String, dynamic>>.from(itemsRaw);

      final viajeId = parada['viaje_id'];
      if (viajeId != null) {
        final viaje = await Supabase.instance.client
            .from('viajes')
            .select('id, viaje_codigo, vehiculo_codigo, chofer_id')
            .eq('id', viajeId)
            .maybeSingle();
        _viajeData = viaje;
        
        try {
          final cargasRes = await Supabase.instance.client
              .from('cargas')
              .select('deposito_origen')
              .eq('viaje_id', viajeId);
          if (cargasRes.isNotEmpty) {
            _depositoOrigen = cargasRes.map((c) => c['deposito_origen'] ?? '').where((d) => d.toString().isNotEmpty).join(', ');
          }
        } catch (e) {
          print('Error fetching cargas for deposito_origen in remito_page: $e');
        }
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _cleanPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.isEmpty) return '';
    // Si tiene 10 dígitos (ej. celular de Argentina sin prefijo internacional), agregar 549
    if (cleaned.length == 10) {
      cleaned = '549$cleaned';
    }
    return cleaned;
  }

  Future<void> _shareWhatsApp(String pdfUrl) async {
    final apicultorPhone = _paradaData?['apicultor_telefono']?.toString() ?? '';
    final apicultorNombre = _paradaData?['ubicacion']?.toString() ?? 'Cliente';
    await _shareWhatsAppToNumber(apicultorPhone, pdfUrl, apicultorNombre);
  }

  Future<void> _shareWhatsAppToNumber(String rawPhone, String pdfUrl, String recipientLabel) async {
    final String cleanPhone = _cleanPhoneNumber(rawPhone);
    final String humanId = 'REM-${widget.paradaId.split('-').first.toUpperCase()}';
    final String text = 'Hola $recipientLabel, le envío el Remito Digital de la operación ($humanId) de la plataforma GeoLogística: $pdfUrl';
    
    String url;
    if (cleanPhone.isNotEmpty) {
      url = 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(text)}';
    } else {
      url = 'https://wa.me/?text=${Uri.encodeComponent(text)}';
    }
    
    try {
      final uri = Uri.parse(url);
      bool launched = await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp en la aplicación ni en el navegador.')),
        );
      }
    } catch (e) {
      debugPrint('Error launching WhatsApp, trying platformDefault: $e');
      try {
        final uri = Uri.parse(url);
        final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
        if (!launched) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir el enlace de WhatsApp.')),
          );
        }
      } catch (e2) {
        debugPrint('Second failure launching: $e2');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir WhatsApp: $e2')),
        );
      }
    }
  }

  Widget _buildRoleShareChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generarYCompartirPDF() async {
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, firme el remito antes de generarlo.')));
      return;
    }

    setState(() => _loading = true);
    try {
      final signatureBytes = await _signatureController.toPngBytes();
      if (signatureBytes == null) throw Exception('Error al procesar firma');

      double tryParseDouble(dynamic val) {
        if (val == null) return 0.0;
        if (val is num) return val.toDouble();
        return double.tryParse(val.toString()) ?? 0.0;
      }

      final tipoOperacion = _paradaData?['tipo'] ?? 'Operación';
      final apicultorNombre = _paradaData?['ubicacion'] ?? 'Sin nombre';
      final apicultorLocalidad = _paradaData?['localidad'] ?? 'S/D';
      final receptorNombre = widget.receptorTipo == 'Tercero' ? (widget.receptorNombre ?? apicultorNombre) : apicultorNombre;
      final receptorDni = widget.receptorTipo == 'Tercero' ? (widget.receptorDni ?? '') : '';

      double totalBruto = tryParseDouble(_paradaData?['carga_kg']);
      double totalNeto = tryParseDouble(_paradaData?['neto_kg']);

      Uint8List? logoBytes;
      try {
        final logoData = await rootBundle.load('assets/images/geomiel_logo.png');
        logoBytes = logoData.buffer.asUint8List();
      } catch (e) {
        print('Error cargando geomiel_logo.png para remito: $e');
      }

      // Sufijo secuencial para numero_remito para evitar colisión de clave única
      final existingRemitos = await Supabase.instance.client
          .from('remitos')
          .select('id')
          .eq('parada_id', widget.paradaId);
      final int count = (existingRemitos as List).length;
      final String codeBase = 'REM-${widget.paradaId.split('-').first.toUpperCase()}';
      final String humanId = count == 0 ? codeBase : '$codeBase-${count + 1}';

      final pdfBytes = await PdfInvoiceGenerator.generateClientRemitoPDF(
        paradaId: widget.paradaId,
        tipoOperacion: tipoOperacion,
        vehiculoCodigo: _viajeData?['vehiculo_codigo'],
        viajeCodigo: _viajeData?['viaje_codigo'],
        apicultorNombre: apicultorNombre,
        apicultorLocalidad: apicultorLocalidad,
        receptorNombre: receptorNombre,
        receptorDni: receptorDni,
        items: _items,
        totalBruto: totalBruto,
        totalNeto: totalNeto,
        signatureBytes: signatureBytes,
        logoBytes: logoBytes,
        depositoOrigen: _depositoOrigen,
        numeroRemito: humanId,
      );

      final fileName = 'remito_${widget.paradaId.split('-').first}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      await Supabase.instance.client.storage.from('remitos').uploadBinary(
        fileName, 
        pdfBytes,
        fileOptions: const FileOptions(contentType: 'application/pdf'),
      );
      final pdfUrl = Supabase.instance.client.storage.from('remitos').getPublicUrl(fileName);

      final insertedRemito = await Supabase.instance.client.from('remitos').insert({
        'parada_id': widget.paradaId,
        'viaje_id': _paradaData?['viaje_id'],
        'pdf_url': pdfUrl,
        'numero_remito': humanId,
        'tipo': tipoOperacion,
        'fecha': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'persona_nombre': receptorNombre,
        'persona_dni': receptorDni,
      }).select('id').single();
      final remitoId = insertedRemito['id']?.toString();

      // Remito guardado con éxito
      print('RemitoPage: Remito guardado con éxito con ID: $remitoId');
      
      try {
        final solId = _paradaData?['solicitud_id'];
        if (_paradaData?['carga_kg'] != null) {
          await Supabase.instance.client.from('solicitudes').update({'estado': 'Terminada'}).eq('id', solId);
        }
      } catch (e) {
        print('Error updating solicitud state in RemitoPage: $e');
      }

      if (mounted) {
        setState(() => _loading = false);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Remito Emitido', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text('El remito digital ha sido generado y guardado correctamente.'),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.visibility_outlined, color: Color(0xFF0369A1)),
                        label: const Text('VER', style: TextStyle(color: Color(0xFF0369A1), fontWeight: FontWeight.bold)),
                        onPressed: () {
                          _showPdfPreviewDialog(context, pdfBytes, 'Remito $humanId');
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.print_outlined, color: Color(0xFFB45309)),
                        label: const Text('IMPRIMIR', style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          await Printing.layoutPdf(onLayout: (format) => pdfBytes);
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.share_rounded, color: Color(0xFF15803D)),
                        label: const Text('COMPARTIR ARCHIVO', style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          await Printing.sharePdf(bytes: pdfBytes, filename: 'Remito_$humanId.pdf');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'ENVIAR POR WHATSAPP A:',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: DesignTokens.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.person_pin_circle_rounded, size: 20, color: Colors.white),
                      label: Text(_paradaData?['apicultor_telefono']?.toString().isNotEmpty == true 
                          ? 'RECEPTOR (${_paradaData!['apicultor_telefono']})' 
                          : 'RECEPTOR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366), 
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final phone = _paradaData?['apicultor_telefono']?.toString() ?? '';
                        final name = _paradaData?['ubicacion']?.toString() ?? 'Cliente';
                        _shareWhatsAppToNumber(phone, pdfUrl, name);
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildRoleShareChip(
                        label: 'COMPRAS',
                        icon: Icons.business_center_rounded,
                        color: const Color(0xFF1E293B),
                        onPressed: () => _shareWhatsAppToNumber('5492302456789', pdfUrl, 'Compras'),
                      ),
                      _buildRoleShareChip(
                        label: 'DEPÓSITO',
                        icon: Icons.warehouse_rounded,
                        color: const Color(0xFF0D9488),
                        onPressed: () => _shareWhatsAppToNumber('5492302987654', pdfUrl, 'Depósito'),
                      ),
                      _buildRoleShareChip(
                        label: 'CEO',
                        icon: Icons.star_rounded,
                        color: const Color(0xFFB45309),
                        onPressed: () => _shareWhatsAppToNumber('5492302123456', pdfUrl, 'CEO'),
                      ),
                      _buildRoleShareChip(
                        label: 'GERENTE',
                        icon: Icons.account_box_rounded,
                        color: const Color(0xFF64748B),
                        onPressed: () => _shareWhatsAppToNumber('5492302654321', pdfUrl, 'Gerente'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.pop(true);
                    },
                    child: const Text('CERRAR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
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
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: DesignTokens.primary)));
    if (_error != null) return Scaffold(appBar: AppBar(title: const Text('Error')), body: Center(child: Text(_error!)));

    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface,
        title: Text('Finalizar Operación', style: DesignTokens.headlineStyle().copyWith(fontSize: 17)),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: DesignTokens.primary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Firma de Conformidad', style: DesignTokens.headlineStyle().copyWith(fontSize: 22)),
            const SizedBox(height: 8),
            Text('El responsable debe firmar para validar la operación y generar el remito.', style: TextStyle(color: DesignTokens.onSurfaceVariant)),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: DesignTokens.primary.withOpacity(0.1)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Signature(
                  controller: _signatureController,
                  height: 300,
                  backgroundColor: const Color(0xFFF9F9F9),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _signatureController.clear(),
                icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.redAccent),
                label: const Text('Limpiar Firma', style: TextStyle(color: Colors.redAccent)),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _generarYCompartirPDF,
                style: DesignTokens.primaryButtonStyle,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('FINALIZAR Y GENERAR REMITO'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
