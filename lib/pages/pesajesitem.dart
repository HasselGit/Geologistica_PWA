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

  Future<void> _guardarPesaje() async {
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pesaje guardado'), backgroundColor: Colors.green));
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      }
    } catch (e) {
      print('PesajesItem: Error al guardar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildDigitalScaleDisplay(double neto) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F0D),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFDBE49).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 4,
              decoration: const BoxDecoration(
                color: Color(0xFFFDBE49),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          neto.toStringAsFixed(1),
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFDBE49),
                            shadows: [
                              Shadow(
                                color: Color(0x66FDBE49),
                                blurRadius: 15,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'KG',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFDBE49),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isDesktop, List<ParadaItemsRow> containerParadaItemsRowList, double neto) {
    if (!isDesktop) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Mobile layout keep it simple
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Form(
                
                child: Column(
                  children: [
                    TextFormField(
                      controller: _model.textController,
                      focusNode: _model.textFieldFocusNode,
                      decoration: const InputDecoration(labelText: 'Código SENASA', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _model.brutoController,
                      decoration: const InputDecoration(labelText: 'Peso Bruto', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => safeSetState(() {}),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _model.taraController,
                      decoration: const InputDecoration(labelText: 'Tara', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => safeSetState(() {}),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => _guardarPesaje(),
                      child: const Text('GUARDAR'),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // OLA 3: Desktop Bento Layout (Terminal & Analytical)
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT COLUMN: Dark Terminal
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0F0D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDBE49).withOpacity(0.3), width: 1),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFFDBE49).withOpacity(0.05), blurRadius: 40),
                ],
              ),
              child: Theme(
                data: ThemeData.dark().copyWith(
                  primaryColor: const Color(0xFFFDBE49),
                  colorScheme: const ColorScheme.dark(primary: Color(0xFFFDBE49), secondary: Color(0xFFFDBE49)),
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFDBE49))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                    labelStyle: const TextStyle(color: Colors.white70),
                  ),
                ),
                child: Form(
                  
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MODIFICAR TAMBOR', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w900, color: Color(0xFFFDBE49), letterSpacing: 1.5, fontSize: 14)),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _model.textController,
                        focusNode: _model.textFieldFocusNode,
                        decoration: const InputDecoration(labelText: 'Código SENASA'),
                        style: const TextStyle(fontFamily: 'JetBrains Mono', color: Colors.white),
                        validator: (val) => (val == null || val.isEmpty) ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: TextFormField(
                            controller: _model.brutoController,
                            decoration: const InputDecoration(labelText: 'Peso Bruto (kg)'),
                            style: const TextStyle(fontFamily: 'JetBrains Mono', color: Colors.white, fontSize: 18),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => safeSetState(() {}),
                            validator: (val) => (val == null || val.isEmpty) ? 'Requerido' : null,
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: TextFormField(
                            controller: _model.taraController,
                            decoration: const InputDecoration(labelText: 'Tara (kg)'),
                            style: const TextStyle(fontFamily: 'JetBrains Mono', color: Colors.white, fontSize: 18),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => safeSetState(() {}),
                            validator: (val) => (val == null || val.isEmpty) ? 'Requerido' : null,
                            onFieldSubmitted: (_) => _guardarPesaje(),
                          )),
                        ],
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFDBE49),
                            foregroundColor: const Color(0xFF0A0F0D),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _guardarPesaje(),
                          child: const Text('ACTUALIZAR (Ctrl+Enter)', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          // RIGHT COLUMN: Analytical Bento Card
          Expanded(
            flex: 6,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DesignTokens.primary.withOpacity(0.05)),
                boxShadow: [
                  BoxShadow(color: DesignTokens.primary.withOpacity(0.05), blurRadius: 40),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF08201A).withOpacity(0.02),
                            const Color(0xFFC68E17).withOpacity(0.02),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -20,
                    right: -20,
                    child: Icon(Icons.analytics_rounded, size: 120, color: DesignTokens.primary.withOpacity(0.03)),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ANALÍTICA DE TAMBOR', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w900, color: DesignTokens.primary, letterSpacing: 1.2, fontSize: 16)),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildAnalyticalItem('ID Correlativo', widget.paradaItemId?.substring(0, 8) ?? 'N/A'),
                          _buildAnalyticalItem('Temperatura', '22°C (Est)'),
                          _buildAnalyticalItem('Humedad', '18% (Est)'),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDF7E7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDBE49).withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ECUACIÓN DE MASA (Kg)', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w700, color: Color(0xFFC68E17), fontSize: 11)),
                            const SizedBox(height: 12),
                            Text(
                              '[${_model.brutoController?.text.isEmpty ?? true ? "0" : _model.brutoController?.text}] Bruto - [${_model.taraController?.text.isEmpty ?? true ? "0" : _model.taraController?.text}] Tara = [$neto] Neto',
                              style: const TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold, fontSize: 18, color: DesignTokens.primary),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticalItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Work Sans', fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w600, fontSize: 15, color: DesignTokens.primary)),
      ],
    );
  }

  Widget _thAnalitico(String text, int flex, {bool right = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        text.toUpperCase(),
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: const TextStyle(fontFamily: 'Work Sans', color: DesignTokens.secondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
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
          final bool isDesktop = constraints.maxWidth >= 900;
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
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: DesignTokens.primary),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
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
                if (event is RawKeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.escape) {
                    _model.textController?.clear();
                    _model.brutoController?.clear();
                    _model.taraController?.clear();
                    _model.textFieldFocusNode?.requestFocus();
                    safeSetState(() {});
                  } else if (event.isControlPressed && (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
                    _guardarPesaje();
                  }
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

                        double bruto = double.tryParse(_model.brutoController?.text ?? '0') ?? 0;
                        double tara = double.tryParse(_model.taraController?.text ?? '0') ?? 0;
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

