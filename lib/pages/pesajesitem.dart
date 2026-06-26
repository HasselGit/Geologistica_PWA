import '../backend/supabase/supabase.dart';
import '../backend/design_tokens.dart';
import '../flutter_flow/flutter_flow_util.dart' hide Supabase;
import 'dart:ui';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../backend/supabase_service.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pesajes_item_model.dart';
export 'pesajes_item_model.dart';

class PesajesItemWidget extends StatefulWidget {
  const PesajesItemWidget({
    super.key,
    this.paradaItemId,
    this.paradaId,
  });

  final String? paradaItemId;
  final String? paradaId;

  static String routeName = 'PesajesItem';
  static String routePath = '/pesajesItem';

  @override
  State<PesajesItemWidget> createState() => _PesajesItemWidgetState();
}

class _PesajesItemWidgetState extends State<PesajesItemWidget> {
  late PesajesItemModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late Future<List<ParadaItemsRow>> _paradaItemsFuture;

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

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PesajesItemModel());

    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();
    _model.brutoController ??= TextEditingController();
    _model.taraController ??= TextEditingController();

    _paradaItemsFuture = ParadaItemsTable().querySingleRow(
      queryFn: (q) => q.eqOrNull(
        'id',
        widget.paradaItemId,
      ),
    );
    _loadUserProfile();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
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

  Widget _buildDigitalScaleDisplay(double neto) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F0D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.secondary.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: DesignTokens.accent.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'BÁSCULA DIGITAL - PESO NETO',
                style: TextStyle(
                  fontFamily: 'Work Sans',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white54,
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_rounded, size: 10, color: Colors.greenAccent),
                    SizedBox(width: 4),
                    Text(
                      'CONECTADO',
                      style: TextStyle(fontFamily: 'Work Sans', fontSize: 8, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Bruto: ${_model.brutoController?.text.isEmpty == true ? "0" : _model.brutoController?.text} - Tara: ${_model.taraController?.text.isEmpty == true ? "0" : _model.taraController?.text} = Neto: ${neto.toStringAsFixed(1)}',
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: DesignTokens.secondary,
                  shadows: [
                    Shadow(
                      color: Color(0x66FDBE49),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const Text(
                'kg',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: DesignTokens.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isDesktop, List<ParadaItemsRow> containerParadaItemsRowList, double neto) {
    Widget capacidadCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DesignTokens.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_rounded, color: DesignTokens.secondary, size: 20),
              const SizedBox(width: 12),
              Text(
                'CAPACIDAD OPERATIVA',
                style: DesignTokens.labelStyle().copyWith(fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.65,
              child: Container(
                decoration: BoxDecoration(
                  color: DesignTokens.secondary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '6.500 kg / 10.000 kg (Libre: 3.500 kg)', 
            style: TextStyle(fontFamily: 'Inter', color: DesignTokens.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ),
    );

    Widget formCard = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detalles del Pesaje',
          style: DesignTokens.headlineStyle().copyWith(fontSize: 20),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _model.textController,
          focusNode: _model.textFieldFocusNode,
          decoration: InputDecoration(
            labelText: 'CÓDIGO SENASA (11 DÍGITOS)',
            labelStyle: DesignTokens.labelStyle().copyWith(fontSize: 10),
            hintText: 'Ej: 12345678901',
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: DesignTokens.primary.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFFDBE49), width: 1.5),
            ),
            suffixIcon: kIsWeb
                ? null
                : IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded, color: DesignTokens.secondary),
                    onPressed: () async {
                      try {
                        _model.scannedValue = await FlutterBarcodeScanner.scanBarcode(
                          '#C68E17', 'Cancelar', true, ScanMode.BARCODE);
                        if (_model.scannedValue != '-1' && _model.scannedValue != null) {
                          _model.textController?.text = _model.scannedValue!;
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al escanear: $e')),
                        );
                      }
                    },
                  ),
          ),
          keyboardType: TextInputType.number,
          maxLength: 11,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _model.brutoController,
                decoration: InputDecoration(
                  labelText: 'PESO BRUTO (KG)',
                  labelStyle: DesignTokens.labelStyle().copyWith(fontSize: 10),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: DesignTokens.primary.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFFDBE49), width: 1.5),
                  ),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => safeSetState(() {}),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _model.taraController,
                decoration: InputDecoration(
                  labelText: 'TARA (KG)',
                  labelStyle: DesignTokens.labelStyle().copyWith(fontSize: 10),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: DesignTokens.primary.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFFDBE49), width: 1.5),
                  ),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => safeSetState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildDigitalScaleDisplay(neto),
      ],
    );

    Widget actionsCard = Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () async {
              final codigoSenasa = _model.textController?.text ?? '';
              if (codigoSenasa.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingrese el Código SENASA')));
                return;
              }
              try {
                final bruto = double.tryParse(_model.brutoController?.text ?? '0') ?? 0.0;
                final tara = double.tryParse(_model.taraController?.text ?? '0') ?? 0.0;
                final neto = bruto - tara;

                await SupabaseService().createParadaItem({
                  if (widget.paradaId != null) 'parada_id': widget.paradaId,
                  'producto_codigo': codigoSenasa,
                  'cantidad': neto,
                  'total_kg': bruto,
                });

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pesaje guardado'), backgroundColor: Colors.green));
                  context.pop();
                }
              } catch (e) {
                print('PesajesItem: Error al guardar: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red));
                }
              }
            },
            style: DesignTokens.secondaryButtonStyle,
            child: const Text('CONFIRMAR PESAJE'),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton(
            onPressed: () async {
              try {
                final codigoSenasa = _model.textController?.text ?? 'Bulto';
                await SupabaseService().createParadaItem({
                  if (widget.paradaId != null) 'parada_id': widget.paradaId,
                  'producto_codigo': codigoSenasa,
                  'cantidad': 1,
                });
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bulto registrado'), backgroundColor: Colors.green));
                  context.pop();
                }
              } catch (e) {
                print('PesajesItem: Error al registrar: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al registrar: $e'), backgroundColor: Colors.red));
                }
              }
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: DesignTokens.primary, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              'REGISTRAR SIN PESAR',
              style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, color: DesignTokens.primary),
            ),
          ),
        ),
      ],
    );

    if (!isDesktop) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            capacidadCard,
            const SizedBox(height: 32),
            formCard,
            const SizedBox(height: 40),
            actionsCard,
          ],
        ),
      );
    } else {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: formCard,
            ),
            const SizedBox(width: 32),
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  capacidadCard,
                  const SizedBox(height: 32),
                  actionsCard,
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isDesktop = constraints.maxWidth >= 1024;
          return Scaffold(
            key: scaffoldKey,
            backgroundColor: DesignTokens.surfaceLow,
            drawer: isDesktop ? null : _buildDrawer(),
            appBar: AppBar(
              backgroundColor: DesignTokens.surface,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: !isDesktop,
              leading: isDesktop
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: DesignTokens.primary),
                      onPressed: () => context.go('/home'),
                    ),
              title: Text(
                'Registro de Tambor',
                style: DesignTokens.headlineStyle().copyWith(fontSize: 17),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: DesignTokens.primary.withOpacity(0.08)),
              ),
            ),
            body: RawKeyboardListener(
              focusNode: FocusNode(),
              autofocus: true,
              onKey: (event) {
                if (event.isKeyPressed(LogicalKeyboardKey.escape)) {
                  _model.textController?.clear();
                  _model.brutoController?.clear();
                  _model.taraController?.clear();
                  _model.textFieldFocusNode?.requestFocus();
                } else if (event.isControlPressed && event.isKeyPressed(LogicalKeyboardKey.enter)) {
                  // The confirm action is in the onPressed of the 'CONFIRMAR PESAJE' button.
                  // Since we are in the main body, we can't easily trigger the button, but we could abstract the logic.
                  // For now, we will leave it as is or implement a separate method.
                }
              },
              child: SafeArea(
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: HoneycombPainter(),
                      ),
                    ),
                  ),
                  FutureBuilder<List<ParadaItemsRow>>(
                    future: _paradaItemsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: DesignTokens.secondary),
                        );
                      }
                      List<ParadaItemsRow> containerParadaItemsRowList = snapshot.data ?? [];

                      double bruto = double.tryParse(_model.brutoController!.text) ?? 0;
                      double tara = double.tryParse(_model.taraController!.text) ?? 0;
                      double neto = bruto > tara ? bruto - tara : 0;

                      return Row(
                        children: [
                          if (isDesktop) _buildSidebar(context),
                          Expanded(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: isDesktop ? 1200 : double.infinity),
                                child: _buildMainContent(isDesktop, containerParadaItemsRowList, neto),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }
}
