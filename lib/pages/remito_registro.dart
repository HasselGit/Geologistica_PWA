import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:signature/signature.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/design_tokens.dart';
import '../backend/supabase_service.dart';
import '../backend/pdf_invoice_generator.dart';
import '../backend/apicultores_data.dart';

class RemitoRegistroPage extends StatefulWidget {
  final String paradaId;
  final String? apicultorId;
  final String? apicultorNombre;
  final String? apicultorDni;
  final String tipoOperacion; // 'recoleccion' or 'distribucion'

  const RemitoRegistroPage({
    super.key,
    required this.paradaId,
    this.apicultorId,
    this.apicultorNombre,
    this.apicultorDni,
    required this.tipoOperacion,
  });

  @override
  State<RemitoRegistroPage> createState() => _RemitoRegistroPageState();
}

class _RemitoRegistroPageState extends State<RemitoRegistroPage> {
  String? _userName;
  String? _userRole;
  String get _displayName => _userName?.isNotEmpty == true ? _userName! : 'Usuario';
  String get _initials {
    final parts = _displayName.split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Future<void> _loadUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          final nombre = prefs.getString('user_nombre') ?? '';
          final apellido = prefs.getString('user_apellido') ?? '';
          _userName = '$nombre $apellido'.trim();
          _userRole = prefs.getString('user_puesto');
        });
      }
    } catch (_) {}
  }

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  bool _isApicultorFirmante = true;
  final TextEditingController _firmanteNombreController = TextEditingController();
  final TextEditingController _firmanteDniController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _terceroTelefonoController = TextEditingController();
  
  List<Map<String, dynamic>> _availableItems = [];
  Map<String, double> _selectedQuantities = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isOnline = true;

  String? _titularId;
  String? _titularNombre;
  String? _titularDni;
  String? _apicultorTelefono;
  List<Map<String, dynamic>> _apicultoresList = [];
  Map<String, Map<String, dynamic>> _apicultoresMap = {};
  String? _titularIdOfParada;

  bool get _isTitularResponsable {
    if (_titularId == null || _titularIdOfParada == null) return false;
    return _titularId!.trim().toLowerCase() == _titularIdOfParada!.trim().toLowerCase();
  }


  @override
  void initState() {
    super.initState();
    _titularId = widget.apicultorId;
    _titularNombre = widget.apicultorNombre;
    _titularDni = widget.apicultorDni;
    _loadItems();
    if (widget.apicultorNombre != null) {
      _firmanteNombreController.text = widget.apicultorNombre!;
      _firmanteDniController.text = widget.apicultorDni ?? '';
    }
    _loadUserProfile();
  }

  List<Map<String, dynamic>> _pesajes = [];
  Map<String, dynamic>? _paradaData;
  Map<String, dynamic>? _viajeData;
  String? _depositoOrigen;

  Future<void> _loadItems() async {
    try {
      final service = SupabaseService();
      final bool online = await service.checkConnectivity();
      
      final dataSafe = await service.getParadaAndViajeOfflineSafe(widget.paradaId);
      final parada = dataSafe?['parada'];
      final viaje = dataSafe?['viaje'];
      
      _paradaData = parada;
      _viajeData = viaje;
      
      String? apicultorIdResolved = widget.apicultorId;
      Map<String, dynamic>? apicultorData;

      if (apicultorIdResolved == null && parada != null && parada['solicitud_id'] != null) {
        if (online) {
          try {
            final solicitud = await Supabase.instance.client
                .from('solicitudes')
                .select('apicultor_id')
                .eq('id', parada['solicitud_id'])
                .maybeSingle();
            if (solicitud != null && solicitud['apicultor_id'] != null) {
              apicultorIdResolved = solicitud['apicultor_id'].toString();
            }
          } catch (e) {
            print('Error resolving apicultor from solicitud: $e');
          }
        }
      }

      final apicultoresList = await service.getApicultores();
      
      if (apicultorIdResolved != null) {
        final matched = apicultoresList.firstWhere(
          (a) => a['id']?.toString().trim().toLowerCase() == apicultorIdResolved!.trim().toLowerCase(),
          orElse: () => <String, dynamic>{},
        );
        if (matched.isNotEmpty) {
          apicultorData = matched;
        } else if (online) {
          try {
            apicultorData = await Supabase.instance.client
                .from('apicultores')
                .select('id, nombre, telefono, dni')
                .eq('id', apicultorIdResolved)
                .maybeSingle();
          } catch (e) {
            print('Error fetching apicultor data: $e');
          }
        }
      }

      String? depositoOrigen;
      if (viaje != null) {
        if (online) {
          try {
            final cargasRes = await Supabase.instance.client
                .from('cargas')
                .select('deposito_origen')
                .eq('viaje_id', viaje['id']);
            if (cargasRes.isNotEmpty) {
              depositoOrigen = cargasRes.map((c) => c['deposito_origen'] ?? '').where((d) => d.toString().isNotEmpty).join(', ');
            }
          } catch (e) {
            print('Error fetching cargas for deposito_origen in remito_registro: $e');
          }
          
          if (viaje['chofer_id'] != null && viaje['chofer'] == null) {
            try {
              final chofer = await Supabase.instance.client
                  .from('profiles')
                  .select('nombre, apellido')
                  .eq('id', viaje['chofer_id'])
                  .maybeSingle();
              _viajeData!['chofer'] = chofer;
            } catch (_) {}
          }
        } else {
          final cargas = viaje['cargas'] as List?;
          if (cargas != null && cargas.isNotEmpty) {
            depositoOrigen = cargas.map((c) => c['deposito_origen'] ?? '').where((d) => d.toString().isNotEmpty).join(', ');
          }
        }
      }

      final itemsList = parada != null && parada['parada_items'] != null
          ? List<Map<String, dynamic>>.from(parada['parada_items'])
          : <Map<String, dynamic>>[];
      
      final pesajesList = await service.getPesajesOfflineSafe(widget.paradaId);

      setState(() {
        _isOnline = online;
        _depositoOrigen = depositoOrigen;
        _apicultoresList = apicultoresList;
        _apicultoresMap = {for (var a in apicultoresList) a['id'].toString().trim().toLowerCase(): a};
        _availableItems = itemsList;
        _pesajes = pesajesList;
        _titularIdOfParada = apicultorIdResolved;

        final bool isTitularIdEmpty = _titularId == null || _titularId!.trim().isEmpty || _titularId == 'null';
        if (isTitularIdEmpty && apicultorIdResolved != null) {
          _titularId = apicultorIdResolved;
          _titularNombre = apicultorData?['nombre']?.toString() ?? widget.apicultorNombre;
          _titularDni = apicultorData?['dni']?.toString() ?? widget.apicultorDni;
          
          if (widget.apicultorNombre == null) {
            _firmanteNombreController.text = _titularNombre ?? '';
            _firmanteDniController.text = _titularDni ?? '';
          }
        }
        
        if (apicultorData != null && apicultorData['telefono'] != null && apicultorData['telefono'].toString().trim().isNotEmpty) {
          _apicultorTelefono = apicultorData['telefono'].toString();
          _telefonoController.text = apicultorData['telefono'].toString();
        } else {
          final String searchName = (widget.apicultorNombre ?? _titularNombre ?? '').toString().toLowerCase().trim();
          final match = ApicultoresData.fallbackApicultores.firstWhere(
            (a) => a['nombre'].toString().toLowerCase().trim() == searchName,
            orElse: () => <String, dynamic>{},
          );
          if (match.isNotEmpty && match['telefono'] != null) {
            _apicultorTelefono = match['telefono'].toString();
            _telefonoController.text = match['telefono'].toString();
          }
        }
        
        _updateTcmQuantity();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading items/pesajes/metadata: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateTcmQuantity() {
    // Remove temporary TCM item if it exists, to re-evaluate it for the new apicultor
    _availableItems.removeWhere((item) => item['id'] == 'TCM_TEMP');

    final filtered = _pesajes.where((p) {
      final drumApicultorId = p['apicultor_id']?.toString() ?? widget.apicultorId ?? _titularIdOfParada ?? '';
      return drumApicultorId.trim().toLowerCase() == _titularId?.trim().toLowerCase();
    }).toList();
    
    final bool isThirdParty = !_isTitularResponsable;
    
    // Si TCM no existe en _availableItems pero tenemos pesajes, lo inyectamos
    final hasTcm = _availableItems.any((item) {
      final pCode = (item['producto_codigo'] ?? '').toString().trim().toUpperCase();
      final id = item['id'].toString();
      if (isThirdParty) {
        return id == 'TCM_TEMP';
      } else {
        return (pCode == 'TCM' || pCode == '1') && id != 'TCM_TEMP';
      }
    });
    
    if (!hasTcm && filtered.isNotEmpty) {
      _availableItems.add({
        'id': 'TCM_TEMP',
        'producto_codigo': 'TCM',
        'cantidad': 0.0,
        'unidad': 'uni|Recolección',
        'peso_kg': 0.0,
        'parada_id': widget.paradaId,
      });
    }

    // Now populate _selectedQuantities
    for (var item in _availableItems) {
      final id = item['id'].toString();
      final String pCode = (item['producto_codigo'] ?? '').toString().trim().toUpperCase();
      
      if (pCode == 'TCM' || pCode == '1') {
        if (id == 'TCM_TEMP') {
          _selectedQuantities[id] = filtered.length.toDouble();
        } else if (isThirdParty) {
          _selectedQuantities[id] = 0.0; // Hide/ignore main apicultor's planned TCM
        } else {
          _selectedQuantities[id] = filtered.length.toDouble();
        }
      } else {
        if (isThirdParty) {
          if (id.startsWith('ADHOC')) {
            if (!_selectedQuantities.containsKey(id)) {
              _selectedQuantities[id] = (item['cantidad'] as num).toDouble();
            }
          } else {
            _selectedQuantities[id] = 0.0; // Ignore all planned items of titular apicultor
          }
        } else {
          if (!_selectedQuantities.containsKey(id)) {
            _selectedQuantities[id] = (item['cantidad'] as num).toDouble();
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _firmanteNombreController.dispose();
    _firmanteDniController.dispose();
    _telefonoController.dispose();
    super.dispose();
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
    await _shareWhatsAppToNumber(_telefonoController.text, pdfUrl, _firmanteNombreController.text);
  }

  Future<void> _shareWhatsAppToNumber(String rawPhone, String pdfUrl, String recipientLabel) async {
    final String cleanPhone = _cleanPhoneNumber(rawPhone);
    final String humanId = 'REM-${widget.paradaId.split('-').first.toUpperCase()}';
    final String text = pdfUrl == 'local_offline'
        ? 'Hola $recipientLabel, le envío el Remito Digital de la operación ($humanId) de la plataforma GeoLogística. El documento se encuentra pendiente de sincronización en mi dispositivo.'
        : 'Hola $recipientLabel, le envío el Remito Digital de la operación ($humanId) de la plataforma GeoLogística: $pdfUrl';
    
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

  Future<void> _uploadFileWithAutoBucket(
    String path,
    Uint8List bytes,
    FileOptions options,
  ) async {
    try {
      await Supabase.instance.client.storage.from('remitos').uploadBinary(
        path,
        bytes,
        fileOptions: options,
      );
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('bucket not found') || errStr.contains('404')) {
        print('Bucket "remitos" no encontrado. Intentando crear dinámicamente...');
        try {
          await Supabase.instance.client.storage.createBucket(
            'remitos',
            const BucketOptions(public: true),
          );
          print('Bucket "remitos" creado con éxito. Reintentando la subida...');
          await Supabase.instance.client.storage.from('remitos').uploadBinary(
            path,
            bytes,
            fileOptions: options,
          );
          return;
        } catch (createErr) {
          print('Error crítico al crear bucket: $createErr');
          throw Exception(
            'El bucket de almacenamiento "remitos" no existe en Supabase.\n'
            'Por favor, créalo desde la consola web de Supabase con acceso público,\n'
            'y define las políticas RLS correspondientes para lectura y escritura.'
          );
        }
      } else {
        rethrow;
      }
    }
  }

  Future<void> _guardarRemito() async {
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, capture la firma')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Process Signature
      final signatureBytes = await _signatureController.toPngBytes();
      if (signatureBytes == null) throw Exception('Error al capturar la firma');

      final filteredPesajes = _pesajes.where((p) {
        final drumApicultorId = p['apicultor_id']?.toString() ?? widget.apicultorId ?? _titularIdOfParada ?? '';
        return drumApicultorId.trim().toLowerCase() == _titularId?.trim().toLowerCase();
      }).toList();

      // Calculate Totals using filtered pesajes
      double totalBruto = filteredPesajes.fold(0.0, (sum, pItem) => sum + ((pItem['peso_bruto'] as num?)?.toDouble() ?? 0.0));
      double totalTara = filteredPesajes.fold(0.0, (sum, pItem) => sum + ((pItem['tara'] as num?)?.toDouble() ?? 0.0));
      double totalNeto = totalBruto - totalTara;
      
      final receptorNombre = _firmanteNombreController.text;
      final receptorDni = _firmanteDniController.text;
      
      final itemsToInclude = _availableItems.map((it) {
        final id = it['id'].toString();
        final selQty = _selectedQuantities[id] ?? 0;
        return {
          'producto_codigo': it['producto_codigo'] ?? '-',
          'cantidad': selQty,
          'unidad': it['unidad'] ?? '-',
        };
      }).where((it) => (it['cantidad'] as num) > 0).toList();

      Uint8List? logoBytes;
      try {
        final logoData = await rootBundle.load('assets/images/geomiel_logo.png');
        logoBytes = logoData.buffer.asUint8List();
      } catch (e) {
        print('Error cargando geomiel_logo.png para remito de bascula: $e');
      }

      // Sufijo secuencial para numero_remito para evitar colisión de clave única
      final bool online = await SupabaseService().checkConnectivity();
      String numeroRemito;
      if (online) {
        final existingRemitos = await Supabase.instance.client
            .from('remitos')
            .select('id')
            .eq('parada_id', widget.paradaId);
        final int count = (existingRemitos as List).length;
        final String codeBase = 'REM-${widget.paradaId.split('-').first.toUpperCase()}';
        numeroRemito = count == 0 ? codeBase : '$codeBase-${count + 1}';
      } else {
        numeroRemito = 'REM-${widget.paradaId.split('-').first.toUpperCase()}-${DateTime.now().millisecondsSinceEpoch.toString().substring(10)}';
      }

      final pdfBytes = await PdfInvoiceGenerator.generateWeighingRemitoPDF(
        paradaId: widget.paradaId,
        tipoOperacion: widget.tipoOperacion,
        vehiculoCodigo: _viajeData?['vehiculo_codigo'],
        viajeCodigo: _viajeData?['viaje_codigo'],
        titularNombre: _titularNombre,
        titularDni: _titularDni,
        receptorNombre: receptorNombre,
        receptorDni: receptorDni,
        items: itemsToInclude,
        pesajes: filteredPesajes,
        totalBruto: totalBruto,
        totalTara: totalTara,
        totalNeto: totalNeto,
        signatureBytes: signatureBytes,
        logoBytes: logoBytes,
        depositoOrigen: _depositoOrigen,
        numeroRemito: numeroRemito,
      );

      final cleanPhone = _cleanPhoneNumber(_telefonoController.text);
      final originalSolId = _paradaData?['solicitud_id']?.toString();

      final result = await SupabaseService().submitRemito(
        paradaId: widget.paradaId,
        viajeId: _paradaData?['viaje_id'],
        apicultorId: _titularId,
        choferId: _viajeData?['chofer_id'],
        remitoCodigo: numeroRemito,
        personaNombre: receptorNombre,
        personaDni: receptorDni,
        totalKg: totalNeto,
        signatureBytes: signatureBytes,
        pdfBytes: pdfBytes,
        cleanPhone: cleanPhone,
        itemsToInclude: itemsToInclude,
        tipoOperacion: widget.tipoOperacion,
        originalSolId: originalSolId,
      );

      final String pdfUrl = result['pdf_url'];

      print('RemitoRegistro: Remito guardado con éxito con resultado: $result');

      // 7. Show success dialog and prompt share options
      if (mounted) {
        setState(() => _isSaving = false);

        // Envío de WhatsApp automático
        final String phoneToShare = _isApicultorFirmante
            ? _telefonoController.text
            : (_terceroTelefonoController.text.isNotEmpty ? _terceroTelefonoController.text : _telefonoController.text);
        final String nameToShare = _isApicultorFirmante
            ? (_titularNombre ?? '')
            : _firmanteNombreController.text;

        if (phoneToShare.isNotEmpty) {
          _shareWhatsAppToNumber(phoneToShare, pdfUrl, nameToShare);
        }

        final humanId = 'REM-${widget.paradaId.split('-').first.toUpperCase()}';
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
                      label: Text(_telefonoController.text.isNotEmpty ? 'APICULTOR (${_telefonoController.text})' : 'APICULTOR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366), 
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () {
                        _shareWhatsAppToNumber(_telefonoController.text, pdfUrl, _titularNombre ?? '');
                      },
                    ),
                  ),
                  if (!_isApicultorFirmante) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.person_outline_rounded, size: 20, color: Colors.white),
                        label: Text(_terceroTelefonoController.text.isNotEmpty ? 'TERCERO (${_terceroTelefonoController.text})' : 'TERCERO'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366), 
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        onPressed: () {
                          _shareWhatsAppToNumber(_terceroTelefonoController.text, pdfUrl, _firmanteNombreController.text);
                        },
                      ),
                    ),
                  ],
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
                      Navigator.pop(context, true);
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar remito: $e')));
      if (mounted) setState(() => _isSaving = false);
    }
  }


  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: DesignTokens.surface,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: DesignTokens.primary),
            child: Row(
              children: [
                ClipOval(child: Image.asset('assets/images/logo_Geologistica_Verde.png', width: 50, height: 50)),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(_userRole ?? 'Operador', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _sidebarItem(Icons.dashboard_rounded, 'Dashboard', () => context.push('/gerenteHome')),
                _sidebarItem(Icons.alt_route_rounded, 'Gestión de Viajes', () => context.push('/viajes'), active: true),
                _sidebarItem(Icons.local_shipping_rounded, 'Vehículos', () => context.push('/vehiculos')),
                const Divider(),
                _sidebarItem(Icons.group_rounded, 'Apicultores', () => context.push('/apicultores')),
                _sidebarItem(Icons.receipt_long_rounded, 'Remitos Digitales', () => context.push('/remitosLista')),
              ],
            ),
          ),
          const Divider(),
          _sidebarItem(Icons.logout_rounded, 'Cerrar Sesión', () async {
            await Supabase.instance.client.auth.signOut();
            if (context.mounted) context.go('/');
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 260,
      color: DesignTokens.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 30),
            child: Row(
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/images/logo_Geologistica_Verde.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GeoLogística',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'APIARY LOGISTICS',
                        style: TextStyle(
                          fontFamily: 'Work Sans',
                          fontWeight: FontWeight.w600,
                          fontSize: 8,
                          color: Colors.white.withOpacity(0.4),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: DesignTokens.secondary,
                    ),
                    child: Text(
                      _initials,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _userRole ?? 'Operador',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _sidebarItem(Icons.dashboard_rounded, 'Dashboard', () => context.push('/gerenteHome')),
                _sidebarItem(Icons.alt_route_rounded, 'Gestión de Viajes', () => context.push('/viajes'), active: true),
                _sidebarItem(Icons.local_shipping_rounded, 'Vehículos', () => context.push('/vehiculos')),
                const Divider(color: Colors.white10, height: 20),
                _sidebarItem(Icons.group_rounded, 'Apicultores', () => context.push('/apicultores')),
                _sidebarItem(Icons.receipt_long_rounded, 'Remitos Digitales', () => context.push('/remitosLista')),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              children: [
                _sidebarItem(Icons.logout_rounded, 'Cerrar Sesión', () async {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) context.go('/');
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String title, VoidCallback onTap, {bool active = false, Color? color}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: active ? DesignTokens.secondary.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
        leading: Icon(icon, color: active ? DesignTokens.secondary : (color ?? Colors.white70), size: 20),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12.5,
            color: active ? DesignTokens.secondary : (color ?? Colors.white70),
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.redAccent.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: const [
          Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Modo Offline (Sin Conexión) — Los datos se sincronizarán al reconectar.',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _guardarRemito,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFDBE49),
          foregroundColor: const Color(0xFF08201A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: const Color(0xFFFDBE49).withOpacity(0.4),
        ),
        icon: _isSaving 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF08201A), strokeWidth: 2))
          : const Icon(Icons.border_color_rounded, size: 20, color: Color(0xFF08201A)),
        label: Text(
          _isSaving ? 'GUARDANDO REMITO...' : 'GENERAR Y FIRMAR REMITO',
          style: const TextStyle(
            fontFamily: 'Work Sans',
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: 0.8,
            color: Color(0xFF08201A),
          ),
        ),
      ),
    );
  }

  Widget _buildCabecera(String displayOperacion, bool isRecoleccion) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── CABECERA DEL DOCUMENTO ────────────────────────────────────
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDBE49).withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.assignment_turned_in_rounded,
                                color: Color(0xFF7D5700),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'REMITO DE OPERACIÓN',
                                    style: TextStyle(
                                      fontFamily: 'Manrope',
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: DesignTokens.primary,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        'Nº: ${_viajeData?['viaje_codigo'] ?? 'V-PENDIENTE'}',
                                        style: TextStyle(
                                          fontFamily: 'Work Sans',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                          color: DesignTokens.primary.withOpacity(0.5),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Fecha: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                                        style: TextStyle(
                                          fontFamily: 'Work Sans',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                          color: DesignTokens.primary.withOpacity(0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(color: DesignTokens.primary.withOpacity(0.08), height: 1, thickness: 1),
                        const SizedBox(height: 20),

                        // ── DATOS DEL PERSONAL ────────────────────────────────────────
                        _sectionHeader('💼 DATOS DEL PERSONAL'),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              _documentDataRow('Chofer', _getChoferDisplay()),
                              const SizedBox(height: 8),
                              _documentDataRow('Apicultor / Receptor', _titularNombre ?? 'Sin Asignar'),
                              const SizedBox(height: 8),
                              _documentDataRow('Viaje ID', _viajeData?['viaje_codigo']?.toString() ?? 'S/D'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── DETALLE DE OPERACIÓN ──────────────────────────────────────
                        _sectionHeader('⚙️ DETALLE DE OPERACIÓN'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _operacionBadgeCard(
                                'Tipo de Operación',
                                displayOperacion.toUpperCase(),
                                isRecoleccion ? const Color(0xFFFEF3C7) : const Color(0xFFDBEAFE),
                                isRecoleccion ? const Color(0xFFB45309) : const Color(0xFF1E40AF),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _operacionBadgeCard(
                                'Estado Parada',
                                'EN CURSO',
                                const Color(0xFFF1F5F9),
                                const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // ── VERIFICACIÓN DE CONTACTO ──────────────────────────────────
                        _sectionHeader('📞 VERIFICACIÓN DE CONTACTO'),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB), // Soft yellow/brown background
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.phone_iphone_rounded, color: Color(0xFFB45309), size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Teléfono Apicultor Titular (WhatsApp)',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: const Color(0xFFB45309).withOpacity(0.9),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _telefonoController,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(
                                  fontFamily: 'Work Sans',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Colors.black,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  hintText: 'Ej: 5491165432109',
                                  hintStyle: TextStyle(color: Colors.black.withOpacity(0.3)),
                                  prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF7D5700), size: 18),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFF59E0B)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildApicultorTitular() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── APICULTOR TITULAR ──────────────────────────────────────────
                        _sectionHeader('🐝 APICULTOR TITULAR DEL REMITO'),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () async {
                            final result = await showDialog<Map<String, dynamic>>(
                              context: context,
                              builder: (context) {
                                String searchQuery = '';
                                return StatefulBuilder(
                                  builder: (context, setDialogState) {
                                    final filtered = _apicultoresList.where((a) =>
                                      (a['nombre']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false) ||
                                      (a['dni']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false)
                                    ).toList();
                                    return AlertDialog(
                                      title: const Text('Buscar Apicultor Titular', style: TextStyle(fontWeight: FontWeight.bold)),
                                      content: SizedBox(
                                        width: double.maxFinite,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextField(
                                              decoration: InputDecoration(
                                                hintText: 'Nombre o DNI...',
                                                prefixIcon: const Icon(Icons.search_rounded),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              ),
                                              onChanged: (v) => setDialogState(() => searchQuery = v),
                                            ),
                                            const SizedBox(height: 12),
                                            Expanded(
                                              child: filtered.isEmpty
                                                  ? const Center(child: Text('No se encontraron apicultores', style: TextStyle(color: Colors.black45)))
                                                  : ListView.builder(
                                                      shrinkWrap: true,
                                                      itemCount: filtered.length,
                                                      itemBuilder: (context, i) => ListTile(
                                                        leading: const Icon(Icons.person_outline_rounded, color: DesignTokens.primary),
                                                        title: Text(filtered[i]['nombre'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                        subtitle: Text('DNI: ${filtered[i]['dni'] ?? '—'}', style: const TextStyle(fontSize: 12)),
                                                        onTap: () => Navigator.pop(context, filtered[i]),
                                                      ),
                                                    ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                            if (result != null) {
                              final newId = result['id']?.toString();
                              if (newId != _titularId) {
                                setState(() {
                                  _selectedQuantities.clear();
                                  _titularId = newId;
                                  _titularNombre = result['nombre']?.toString();
                                  _titularDni = result['dni']?.toString();
                                  _apicultorTelefono = result['telefono']?.toString();
                                  if (result['telefono'] != null) {
                                    _telefonoController.text = result['telefono'].toString();
                                  }
                                  
                                  _isApicultorFirmante = true;
                                  _firmanteNombreController.text = _titularNombre ?? '';
                                  _firmanteDniController.text = _titularDni ?? '';
                                  
                                  _updateTcmQuantity();
                                });
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.person_search_rounded, size: 22, color: DesignTokens.primary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _titularNombre ?? 'Seleccionar Apicultor...',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: DesignTokens.primary),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _isTitularResponsable ? 'Apicultor Responsable de la Parada' : 'Tercero Apicultor (Multi-Remito)',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: _isTitularResponsable ? Colors.green : Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down_rounded, color: Colors.black54),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildQuienFirma() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── ¿QUIÉN FIRMA? ─────────────────────────────────────────────
                        _sectionHeader('👤 RESPONSABLE FIRMANTE'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _firmanteRadioTile('El Apicultor', true),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _firmanteRadioTile('Un Tercero', false),
                            ),
                          ],
                        ),
                        if (!_isApicultorFirmante) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _firmanteNombreController,
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: 'Nombre del Tercero',
                                    labelStyle: const TextStyle(color: Colors.black54),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _firmanteDniController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: 'DNI / CUIT',
                                    labelStyle: const TextStyle(color: Colors.black54),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _terceroTelefonoController,
                                  keyboardType: TextInputType.phone,
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: 'Teléfono del Tercero (WhatsApp)',
                                    labelStyle: const TextStyle(color: Colors.black54),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDetalleProductos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('📦 DETALLE DE PRODUCTOS'),
                        const SizedBox(height: 10),
                        _buildProductsTable(),
                        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPlanillaPesaje() {
    final apicPesajes = _pesajes.where((p) {
      final drumApicultorId = p['apicultor_id']?.toString() ?? widget.apicultorId ?? _titularIdOfParada ?? '';
      return drumApicultorId.trim().toLowerCase() == _titularId?.trim().toLowerCase();
    }).toList();
    
    if (apicPesajes.isEmpty) return const SizedBox.shrink();
    
    final bool isLoteSinPesar = apicPesajes.every((p) => ((p['peso_bruto'] as num?)?.toDouble() ?? 0.0) == 0.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(isLoteSinPesar ? '📝 DETALLE DE TAMBORES REGISTRADOS' : '⚖️ PLANILLA DE PESAJE TÉCNICA'),
        const SizedBox(height: 10),
        _buildWeighingTable(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFirmasConformidad() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── FIRMAS DE CONFORMIDAD ─────────────────────────────────────
                        _sectionHeader('✍️ FIRMAS DE CONFORMIDAD'),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Apicultor / Receptor Signature Column
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    _isApicultorFirmante ? 'RECEPTOR (APICULTOR)' : 'RECEPTOR (TERCERO)',
                                    style: const TextStyle(
                                      fontFamily: 'Work Sans',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 9,
                                      color: Colors.black54,
                                      letterSpacing: 0.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Center(
                                    child: Container(
                                      width: 360,
                                      height: 130,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                                        borderRadius: BorderRadius.circular(8),
                                        color: const Color(0xFFF8FAFC),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Signature(
                                          controller: _signatureController,
                                          backgroundColor: const Color(0xFFF8FAFC),
                                          width: 360,
                                          height: 130,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TextButton.icon(
                                    onPressed: () => _signatureController.clear(),
                                    icon: const Icon(Icons.clear_rounded, size: 14, color: Colors.redAccent),
                                    label: const Text(
                                      'LIMPIAR FIRMA',
                                      style: TextStyle(
                                        fontFamily: 'Work Sans',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Chofer Signature Seal Column
                            Expanded(
                              child: Column(
                                children: [
                                  const Text(
                                    'CERTIFICACIÓN (CHOFER)',
                                    style: TextStyle(
                                      fontFamily: 'Work Sans',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 9,
                                      color: Colors.black54,
                                      letterSpacing: 0.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    height: 130,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: const Color(0xFFDCFCE7), width: 1.5),
                                      borderRadius: BorderRadius.circular(8),
                                      color: const Color(0xFFF0FDF4),
                                    ),
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 28),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'FIRMA VALIDADA',
                                              style: TextStyle(
                                                fontFamily: 'Work Sans',
                                                fontWeight: FontWeight.w900,
                                                fontSize: 10,
                                                color: Color(0xFF166534),
                                                letterSpacing: 0.5,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _getChoferDisplay(),
                                              style: const TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 9,
                                                color: Color(0xFF15803D),
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 2,
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
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
                        const SizedBox(height: 20),
                        Divider(color: DesignTokens.primary.withOpacity(0.08), height: 1),
                        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFooterLegal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
                          'El presente documento digital certifica la entrega y recepción de los productos detallados. Firma emitida mediante la plataforma digital GeoLogística.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontStyle: FontStyle.italic,
                            fontSize: 10,
                            color: Colors.black38,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Center(
                          child: Text(
                            'GeoLogística - Tecnología y Logística Apícola',
                            style: TextStyle(
                              fontFamily: 'Work Sans',
                              fontWeight: FontWeight.w700,
                              fontSize: 9,
                              color: Colors.black26,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
      ],
    );
  }

  Widget _buildPaperSheet(bool isDesktop, String displayOperacion, bool isRecoleccion) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.primary.withOpacity(0.08), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCabecera(displayOperacion, isRecoleccion),
          _buildApicultorTitular(),
          _buildQuienFirma(),
          _buildDetalleProductos(),
          _buildPlanillaPesaje(),
          _buildFirmasConformidad(),
          _buildFooterLegal(),
        ],
      ),
    );
  }

  Widget _buildLeftColumnCard(String displayOperacion, bool isRecoleccion) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.primary.withOpacity(0.08), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCabecera(displayOperacion, isRecoleccion),
          _buildApicultorTitular(),
          _buildQuienFirma(),
          _buildDetalleProductos(),
          _buildPlanillaPesaje(),
        ],
      ),
    );
  }

  Widget _buildRightColumnCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.primary.withOpacity(0.08), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFirmasConformidad(),
          _buildFooterLegal(),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isDesktop, String displayOperacion, bool isRecoleccion) {
    if (!isDesktop) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            if (!_isOnline) _buildOfflineBanner(),
            _buildPaperSheet(isDesktop, displayOperacion, isRecoleccion),
            const SizedBox(height: 24),
            _buildSubmitButton(),
            const SizedBox(height: 20),
          ],
        ),
      );
    } else {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isOnline) _buildOfflineBanner(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: _buildLeftColumnCard(displayOperacion, isRecoleccion),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      _buildRightColumnCard(),
                      const SizedBox(height: 24),
                      _buildSubmitButton(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 100),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasDistribucion = false;
    bool hasRecoleccion = false;
    for (var item in _availableItems) {
      if ((_selectedQuantities[item['id'].toString()] ?? 0) > 0) {
        final unitRaw = (item['unidad'] ?? 'uni').toString();
        final opType = unitRaw.split('|').length > 1 ? unitRaw.split('|')[1] : widget.tipoOperacion;
        if (opType == 'Distribución' || opType == 'Distribucion') hasDistribucion = true;
        if (opType == 'Recolección' || opType == 'Recoleccion') hasRecoleccion = true;
      }
    }
    final String displayOperacion = (hasDistribucion && hasRecoleccion) ? 'MIXTA' : widget.tipoOperacion;
    final isRecoleccion = displayOperacion.toLowerCase().contains('recolec') || displayOperacion == 'MIXTA';

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 1024;
        
        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          drawer: isDesktop ? null : _buildDrawer(),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: isDesktop
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: DesignTokens.primary),
                    onPressed: () => Navigator.pop(context),
                  ),
            title: const Text(
              'NUEVO REMITO DIGITAL',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: DesignTokens.primary,
                letterSpacing: 0.5,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: DesignTokens.primary.withOpacity(0.08)),
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
              : Row(
                  children: [
                    if (isDesktop) _buildSidebar(context),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: isDesktop ? 1200 : double.infinity),
                          child: _buildMainContent(isDesktop, displayOperacion, isRecoleccion),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }


  Widget _sectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'Work Sans',
        fontWeight: FontWeight.w900,
        fontSize: 11,
        color: Color(0xFF9C6644), // Elegant brown/gold brand tone
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _documentDataRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: Colors.black.withOpacity(0.45),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _operacionBadgeCard(String label, String badgeText, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              color: Colors.black.withOpacity(0.4),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                fontFamily: 'Work Sans',
                fontWeight: FontWeight.w800,
                fontSize: 9,
                color: textColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _firmanteRadioTile(String label, bool isApicultor) {
    final active = _isApicultorFirmante == isApicultor;
    return GestureDetector(
      onTap: () {
        setState(() {
          _isApicultorFirmante = isApicultor;
          if (isApicultor) {
            _firmanteNombreController.text = _titularNombre ?? '';
            _firmanteDniController.text = _titularDni ?? '';
            _telefonoController.text = _apicultorTelefono ?? '';
          } else {
            final String mainApicName = _apicultoresMap[_titularIdOfParada?.trim().toLowerCase()]?['nombre'] ?? widget.apicultorNombre ?? '';
            final String mainApicDni = _apicultoresMap[_titularIdOfParada?.trim().toLowerCase()]?['dni'] ?? widget.apicultorDni ?? '';
            _firmanteNombreController.text = mainApicName;
            _firmanteDniController.text = mainApicDni;
            _terceroTelefonoController.clear();
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF08201A).withOpacity(0.04) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? const Color(0xFF08201A) : const Color(0xFFE2E8F0),
            width: active ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              active ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: active ? const Color(0xFF08201A) : Colors.black38,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? const Color(0xFF08201A) : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getChoferDisplay() {
    final chofer = _viajeData?['chofer'];
    if (chofer != null) {
      final name = chofer['nombre']?.toString() ?? '';
      final surname = chofer['apellido']?.toString() ?? '';
      if (name.isNotEmpty || surname.isNotEmpty) {
        return '$name $surname'.trim();
      }
    }
    return 'Chofer Asignado';
  }

  Widget _buildProductsTableGroup({
    required String title,
    required List<Map<String, dynamic>> itemsList,
    required Color headerBgColor,
    required Color badgeBgColor,
    required Color badgeTextColor,
    required IconData headerIcon,
    required String operationType,
  }) {
    if (itemsList.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: headerBgColor.withOpacity(0.15), width: 1.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: headerBgColor.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerBgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(headerIcon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Work Sans',
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${itemsList.length} ${itemsList.length == 1 ? 'ITEM' : 'ITEMS'}',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Subheader Row for Columns
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: headerBgColor.withOpacity(0.03),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DESCRIPCIÓN DEL PRODUCTO',
                  style: TextStyle(
                    fontFamily: 'Work Sans',
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                    color: headerBgColor.withOpacity(0.6),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'CANTIDAD REAL',
                  style: TextStyle(
                    fontFamily: 'Work Sans',
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                    color: headerBgColor.withOpacity(0.6),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // Table Rows
          ...List.generate(itemsList.length, (idx) {
            final item = itemsList[idx];
            final id = item['id'].toString();
            final String pCode = (item['producto_codigo'] ?? '').toString().trim().toUpperCase();
            final isTCM = pCode == 'TCM' || pCode == '1';
            final qty = _selectedQuantities[id] ?? 0;
            final isLast = idx == itemsList.length - 1;
            final filteredPesajesCount = _pesajes.where((p) {
              final drumApicultorId = p['apicultor_id']?.toString() ?? widget.apicultorId ?? _titularIdOfParada ?? '';
              return drumApicultorId.trim().toLowerCase() == _titularId?.trim().toLowerCase();
            }).length;
            final double planQty = (item['cantidad'] as num?)?.toDouble() ?? 0.0;
            final hasMismatch = isTCM && _isTitularResponsable && filteredPesajesCount != planQty;

            final String unitRaw = (item['unidad'] ?? 'uni').toString();
            final String unitBase = unitRaw.split('|').first;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isLast ? Colors.transparent : headerBgColor.withOpacity(0.08),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['producto_codigo'] ?? '',
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Planificado: ${item['cantidad']} $unitBase',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: Colors.black.withOpacity(0.4),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (isTCM)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF08201A).withOpacity(0.04),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            qty.toStringAsFixed(0),
                            style: const TextStyle(
                              fontFamily: 'Work Sans',
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Color(0xFF08201A),
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (qty > 0) {
                                  setState(() {
                                    _selectedQuantities[id] = qty - 1;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFF1F5F9),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Icon(Icons.remove_rounded, size: 18, color: Color(0xFF08201A)),
                              ),
                            ),
                            Container(
                              width: 60,
                              alignment: Alignment.center,
                              child: Text(
                                qty.toStringAsFixed(0),
                                style: const TextStyle(
                                  fontFamily: 'Work Sans',
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                if (operationType == 'Distribución') {
                                  final double stockDisponible = await _calcularStockDisponibleEnCamion(pCode, excludeItemId: id);
                                  if (qty + 1 > stockDisponible) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: No hay suficiente stock en el camión. Disponible: ${stockDisponible.round()} unidades.'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                    return;
                                  }
                                }
                                setState(() {
                                  _selectedQuantities[id] = qty + 1;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFF1F5F9),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF08201A)),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (hasMismatch) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber[900]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sugerido: $filteredPesajesCount TCM según ${filteredPesajesCount > 0 && _pesajes.any((p) => ((p['peso_bruto'] as num?)?.toDouble() ?? 0.0) > 0.0) ? "pesajes" : "tambores"} registrados.',
                              style: TextStyle(
                                color: Colors.amber[900],
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              context.push(
                                '/agregarPesaje',
                                extra: {
                                  'paradaId': widget.paradaId,
                                  'viajeId': _paradaData?['viaje_id']?.toString(),
                                  'viajeCode': _viajeData?['viaje_codigo']?.toString() ?? 'V-S/N',
                                  'apicultorNombre': widget.apicultorNombre ?? _titularNombre ?? 'S/D',
                                  'localidad': _paradaData?['localidad']?.toString() ?? 'S/D',
                                  'apicultorId': _titularId,
                                },
                              ).then((_) => _loadItems());
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.amber[900],
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: Text(
                              filteredPesajesCount > 0 && _pesajes.any((p) => ((p['peso_bruto'] as num?)?.toDouble() ?? 0.0) > 0.0)
                                  ? 'CORREGIR PESAJE'
                                  : 'CORREGIR REGISTRO',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProductsTable() {
    final bool isThirdParty = !_isTitularResponsable;
    
    final displayedItems = isThirdParty
        ? _availableItems.where((item) {
            final String id = item['id'].toString();
            return id == 'TCM_TEMP' || id.startsWith('ADHOC');
          }).toList()
        : _availableItems;

    final entregas = displayedItems.where((item) {
      final String unitRaw = (item['unidad'] ?? 'uni').toString();
      final parts = unitRaw.split('|');
      final String opType = parts.length > 1 ? parts[1] : 'Recolección';
      return opType == 'Distribución';
    }).toList();

    final retiros = displayedItems.where((item) {
      final String unitRaw = (item['unidad'] ?? 'uni').toString();
      final parts = unitRaw.split('|');
      final String opType = parts.length > 1 ? parts[1] : 'Recolección';
      return opType == 'Recolección';
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextButton.icon(
              onPressed: _showAddAdHocProductDialog,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: DesignTokens.secondary),
              label: const Text(
                'AGREGAR PRODUCTO (FUERA DE PLAN)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: DesignTokens.secondary,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: DesignTokens.secondary),
                ),
              ),
            ),
          ),
        ),
        if (entregas.isEmpty && retiros.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'No hay productos registrados en este remito.\nPresioná AGREGAR PRODUCTO para registrar una operación.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black38, fontSize: 13),
            ),
          )
        else ...[
          if (entregas.isNotEmpty) ...[
            _buildProductsTableGroup(
              title: 'Productos Entregados (Distribución)',
              itemsList: entregas,
              headerBgColor: const Color(0xFF1E3A8A), // Navy Blue
              badgeBgColor: const Color(0xFFDBEAFE),
              badgeTextColor: const Color(0xFF1E40AF),
              headerIcon: Icons.download_rounded,
              operationType: 'Distribución',
            ),
            const SizedBox(height: 16),
          ],
          if (retiros.isNotEmpty)
            _buildProductsTableGroup(
              title: 'Productos Retirados (Recolección)',
              itemsList: retiros,
              headerBgColor: const Color(0xFFB45309), // Amber Brown
              badgeBgColor: const Color(0xFFFEF3C7),
              badgeTextColor: const Color(0xFFB45309),
              headerIcon: Icons.upload_rounded,
              operationType: 'Recolección',
            ),
        ],
      ],
    );
  }

  Future<double> _calcularStockDisponibleEnCamion(String productCode, {String? excludeItemId}) async {
    final String? viajeId = _viajeData?['id']?.toString() ?? _paradaData?['viaje_id']?.toString();
    if (viajeId == null || viajeId.isEmpty) return 99999.0;

    double stock = 0.0;

    // 1. Sumar stock inicial cargado desde Cargas
    try {
      final cargas = await Supabase.instance.client
          .from('cargas')
          .select('carga_items(producto_codigo, cantidad)')
          .eq('viaje_id', viajeId)
          .or('estado.eq.Terminado,estado.eq.Terminada');
          
      for (var c in cargas) {
        final items = c['carga_items'] as List? ?? [];
        for (var it in items) {
          if (it['producto_codigo'].toString().trim().toUpperCase() == productCode.toUpperCase()) {
            stock += (it['cantidad'] ?? 0).toDouble();
          }
        }
      }
    } catch (e) {
      print('RemitoRegistro: Error al calcular stock inicial de carga: $e');
    }

    // 2. Ajustar por paradas finalizadas (restar entregas, sumar recolecciones)
    try {
      final paradas = await Supabase.instance.client
          .from('paradas')
          .select('tipo, estado, parada_items(producto_codigo, cantidad)')
          .eq('viaje_id', viajeId)
          .eq('estado', 'Terminado');

      for (var p in paradas) {
        final String tipo = p['tipo'] ?? '';
        final items = p['parada_items'] as List? ?? [];
        for (var it in items) {
          if (it['producto_codigo'].toString().trim().toUpperCase() == productCode.toUpperCase()) {
            final double cant = (it['cantidad'] ?? 0).toDouble();
            if (tipo == 'Distribución') {
              stock -= cant;
            } else if (tipo == 'Recolección') {
              stock += cant;
            }
          }
        }
      }
    } catch (e) {
      print('RemitoRegistro: Error al calcular ajustes de paradas para stock: $e');
    }

    // 3. Restar lo que ya está seleccionado en la pantalla del remito actual
    for (final item in _availableItems) {
      final String id = item['id'].toString();
      if (id == excludeItemId) continue;

      final String pCode = (item['producto_codigo'] ?? '').toString().trim().toUpperCase();
      if (pCode != productCode.toUpperCase()) continue;

      final String unitRaw = (item['unidad'] ?? 'uni').toString();
      final parts = unitRaw.split('|');
      final String opType = parts.length > 1 ? parts[1] : 'Recolección';

      if (opType == 'Distribución') {
        final double selQty = _selectedQuantities[id] ?? 0;
        stock -= selQty;
      }
    }

    return stock;
  }

  void _showAddAdHocProductDialog() {
    String selectedOpType = 'Recolección';
    String selectedProductCode = 'TCM';
    final TextEditingController qtyController = TextEditingController(text: '1');
    final adHocFormKey = GlobalKey<FormState>();

    final List<Map<String, String>> catalog = [
      {'codigo': 'TCM', 'nombre': 'Tambor con Miel (TCM)', 'unidad': 'uni'},
      {'codigo': 'CO', 'nombre': 'Cera Opérculo (CO)', 'unidad': 'Kg'},
      {'codigo': 'CR', 'nombre': 'Cera Recupero (CR)', 'unidad': 'Kg'},
      {'codigo': 'CE STD', 'nombre': 'Cera Estampada STD', 'unidad': 'uni'},
      {'codigo': 'TRR', 'nombre': 'Tambor Reacondicionado Raldas (TRR)', 'unidad': 'uni'},
      {'codigo': 'AZ', 'nombre': 'Azúcar (AZ)', 'unidad': 'Bolsa'},
      {'codigo': 'GL', 'nombre': 'Glucosa (GL)', 'unidad': 'Kg'},
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.add_circle_outline_rounded, color: DesignTokens.secondary),
                  SizedBox(width: 8),
                  Text('Producto Fuera de Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: Form(
                key: adHocFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TIPO DE OPERACIÓN',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedOpType,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF7F7F7),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Distribución', child: Text('Distribución (Entrega / Recibe)', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'Recolección', child: Text('Recolección (Retiro / Entrega)', style: TextStyle(fontSize: 13))),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedOpType = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'PRODUCTO',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedProductCode,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF7F7F7),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: catalog.map((p) {
                          return DropdownMenuItem(
                            value: p['codigo'],
                            child: Text('${p['codigo']} - ${p['nombre']}', style: const TextStyle(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedProductCode = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'CANTIDAD / KG',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: qtyController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF7F7F7),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido';
                          final numVal = double.tryParse(v);
                          if (numVal == null || numVal <= 0) return 'Debe ser > 0';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('CANCELAR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!adHocFormKey.currentState!.validate()) return;
                    final qty = double.parse(qtyController.text);
                    final prodMatch = catalog.firstWhere((p) => p['codigo'] == selectedProductCode);
                    final String unit = prodMatch['unidad']!;
                    
                    if (selectedOpType == 'Distribución') {
                      final double stockDisponible = await _calcularStockDisponibleEnCamion(selectedProductCode);
                      if (qty > stockDisponible) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: No hay suficiente stock en el camión. Disponible: ${stockDisponible.round()} unidades.'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }
                    }

                    final String newId = 'ADHOC_${selectedProductCode}_${DateTime.now().millisecondsSinceEpoch}';
                    
                    setState(() {
                      _availableItems.add({
                        'id': newId,
                        'producto_codigo': selectedProductCode,
                        'cantidad': qty,
                        'unidad': '$unit|$selectedOpType',
                        'peso_kg': 0.0,
                        'parada_id': widget.paradaId,
                      });
                      _selectedQuantities[newId] = qty;
                      _updateTcmQuantity();
                    });
                    
                    Navigator.pop(ctx);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✓ Agregado: $selectedProductCode ($qty $unit) en $selectedOpType'),
                        backgroundColor: Colors.green.shade700,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.secondary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('AGREGAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildWeighingTable() {
    final filtered = _pesajes.where((p) {
      final drumApicultorId = p['apicultor_id']?.toString() ?? widget.apicultorId ?? _titularIdOfParada ?? '';
      return drumApicultorId.trim().toLowerCase() == _titularId?.trim().toLowerCase();
    }).toList();

    final isLoteSinPesar = filtered.isNotEmpty &&
        ((filtered.first['peso_bruto'] as num?)?.toDouble() ?? 0.0) == 0.0;

    double totalBruto = filtered.fold(0.0, (sum, pItem) => sum + ((pItem['peso_bruto'] as num?)?.toDouble() ?? 0.0));
    double totalTara = filtered.fold(0.0, (sum, pItem) => sum + ((pItem['tara'] as num?)?.toDouble() ?? 0.0));
    double totalNeto = totalBruto - totalTara;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDCFCE7)), // Soft green outline matching light green theme
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A), // Rich green header
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: isLoteSinPesar
                  ? const [
                      Expanded(
                        flex: 1,
                        child: Text(
                          'N°',
                          style: TextStyle(
                            fontFamily: 'Work Sans',
                            fontWeight: FontWeight.w800,
                            fontSize: 8,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          'CÓDIGO SENASA',
                          style: TextStyle(
                            fontFamily: 'Work Sans',
                            fontWeight: FontWeight.w800,
                            fontSize: 8,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'DETALLE',
                          style: TextStyle(
                            fontFamily: 'Work Sans',
                            fontWeight: FontWeight.w800,
                            fontSize: 8,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ]
                  : const [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'CÓDIGO SENASA',
                          style: TextStyle(
                            fontFamily: 'Work Sans',
                            fontWeight: FontWeight.w800,
                            fontSize: 8,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'BRUTO (KG)',
                          style: TextStyle(
                            fontFamily: 'Work Sans',
                            fontWeight: FontWeight.w800,
                            fontSize: 8,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'TARA (KG)',
                          style: TextStyle(
                            fontFamily: 'Work Sans',
                            fontWeight: FontWeight.w800,
                            fontSize: 8,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'NETO (KG)',
                          style: TextStyle(
                            fontFamily: 'Work Sans',
                            fontWeight: FontWeight.w800,
                            fontSize: 8,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
            ),
          ),
          // Table Rows
          ...List.generate(filtered.length, (idx) {
            final pItem = filtered[idx];
            final bruto = (pItem['peso_bruto'] as num?)?.toDouble() ?? 0.0;
            final tara = (pItem['tara'] as num?)?.toDouble() ?? 0.0;
            final neto = bruto - tara;
            final senasa = pItem['senasa_codigo'] ?? 'S/D';

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: idx % 2 == 0 ? const Color(0xFFF9FBF9) : Colors.white,
              child: Row(
                children: isLoteSinPesar
                    ? [
                        Expanded(
                          flex: 1,
                          child: Text(
                            '${idx + 1}',
                            style: const TextStyle(
                              fontFamily: 'Work Sans',
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            senasa,
                            style: const TextStyle(
                              fontFamily: 'Work Sans',
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              color: Color(0xFF166534),
                            ),
                          ),
                        ),
                        const Expanded(
                          flex: 3,
                          child: Text(
                            'Sin pesar',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontFamily: 'Work Sans',
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: Colors.black38,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ]
                    : [
                        Expanded(
                          flex: 3,
                          child: Text(
                            senasa,
                            style: const TextStyle(
                              fontFamily: 'Work Sans',
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              color: Color(0xFF166534),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            bruto.toStringAsFixed(1),
                            style: const TextStyle(
                              fontFamily: 'Work Sans',
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            tara.toStringAsFixed(1),
                            style: const TextStyle(
                              fontFamily: 'Work Sans',
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            neto.toStringAsFixed(1),
                            style: const TextStyle(
                              fontFamily: 'Work Sans',
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              color: Color(0xFF15803D),
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
              ),
            );
          }),
          // Table Footer (Totals row highlighted in light yellow/gold)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFFFFBEB), // Soft golden brand highlight
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
              border: Border(top: BorderSide(color: Color(0xFFFDE68A), width: 1.5)),
            ),
            child: Row(
              children: isLoteSinPesar
                  ? [
                      const Expanded(
                        flex: 5,
                        child: Text(
                          'CANTIDAD TOTAL',
                          style: TextStyle(
                            fontFamily: 'Work Sans',
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            color: Color(0xFF7D5700),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          '${filtered.length} Tambores (TCM)',
                          style: const TextStyle(
                            fontFamily: 'Work Sans',
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            color: Color(0xFF7D5700),
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ]
                  : [
                      const Expanded(
                        flex: 3,
                        child: Text(
                          'TOTALES',
                          style: TextStyle(
                            fontFamily: 'Work Sans',
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            color: Color(0xFF7D5700),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${totalBruto.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                            fontFamily: 'Work Sans',
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${totalTara.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                            fontFamily: 'Work Sans',
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${totalNeto.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                            fontFamily: 'Work Sans',
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            color: Color(0xFF7D5700),
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
            ),
          ),
        ],
      ),
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
}
