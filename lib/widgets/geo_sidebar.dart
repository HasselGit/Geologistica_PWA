import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../backend/design_tokens.dart';

class GeoSidebar extends StatefulWidget {
  final String userRole;
  final String userEmail;
  final String displayName;

  const GeoSidebar({
    super.key,
    required this.userRole,
    required this.userEmail,
    required this.displayName,
  });

  @override
  State<GeoSidebar> createState() => _GeoSidebarState();
}

class _GeoSidebarState extends State<GeoSidebar> {
  bool _isSidebarHovered = false;

  String _normalizeRole(String? role) {
    if (role == null) return '';
    return role.toLowerCase().trim();
  }

  bool get _isManagement {
    final r = _normalizeRole(widget.userRole);
    return r.contains('gestor') || r.contains('manager') || r.contains('jefe');
  }

  bool get _isDeposito {
    final r = _normalizeRole(widget.userRole);
    return r.contains('depósito') || r.contains('deposito');
  }

  bool get _isAdmin {
    final r = _normalizeRole(widget.userRole);
    final email = widget.userEmail.toLowerCase();
    return r.contains('admin') || 
           r.contains('gerente') || 
           r.contains('gerencia') || 
           r.contains('ceo') || 
           r.contains('director') || 
           email.contains('hespinosa') || 
           email.contains('mparedes') || 
           email.contains('gparedes') || 
           email.contains('lcastellanos') || 
           email.contains('rsteierd');
  }

  bool get _isChofer {
    final r = _normalizeRole(widget.userRole);
    final email = widget.userEmail.toLowerCase();
    return r.contains('chofer') || email.contains('mperez') || email.contains('cmuse') || email.contains('agomez') || email.contains('efernandez');
  }

  bool get _isCeoOrGerente {
    final r = _normalizeRole(widget.userRole);
    return r.contains('ceo') || r.contains('gerente') || r.contains('gerencia');
  }

  bool get _isCompras {
    final r = _normalizeRole(widget.userRole);
    return r.contains('compras');
  }

  bool get _isAdministrativo {
    final r = _normalizeRole(widget.userRole);
    return r.contains('administrativo') || r.contains('administracion') || r.contains('gastos');
  }

  String get _initials {
    final parts = widget.displayName.split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Widget _sidebarItem(IconData icon, String title, VoidCallback onTap, {bool active = false, Color? color, bool showLabel = true}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: active ? DesignTokens.secondary.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
        leading: Icon(icon, color: active ? DesignTokens.secondary : (color ?? Colors.white70), size: 20),
        title: showLabel
            ? Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13.5,
                  color: active ? DesignTokens.secondary : (color ?? Colors.white70),
                ),
              )
            : null,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;
    final bool showExpanded = isMobile || _isSidebarHovered;
    final double sidebarWidth = isMobile ? double.infinity : (showExpanded ? 260 : 80);

    return MouseRegion(
      onEnter: (_) => setState(() => _isSidebarHovered = true),
      onExit: (_) => setState(() => _isSidebarHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: sidebarWidth,
        margin: EdgeInsets.only(left: isMobile ? 0 : 16, top: isMobile ? 0 : 16, bottom: isMobile ? 0 : 16, right: 0),
        decoration: BoxDecoration(
          color: DesignTokens.primary,
          borderRadius: BorderRadius.circular(isMobile ? 0 : 16),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Row(
                  mainAxisAlignment: showExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                  children: [
                    ClipOval(
                      child: Image.asset(
                        'assets/images/logo_Geologistica_Verde.png',
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (showExpanded) ...[
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'GeoLogística',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: EdgeInsets.all(showExpanded ? 12 : 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: showExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
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
                      if (showExpanded) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.displayName.isEmpty ? 'Usuario' : widget.displayName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                widget.userRole.isEmpty ? 'Operador' : widget.userRole,
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _sidebarItem(Icons.home_rounded, 'Inicio', () {
                      if (isMobile && Scaffold.of(context).isDrawerOpen) {
                        Navigator.pop(context);
                      }
                      context.go('/home');
                    }, showLabel: showExpanded),
                    if ((_isAdmin || _isManagement) && !_isAdministrativo)
                      _sidebarItem(Icons.dashboard_rounded, 'Dashboard', () {
                        if (isMobile && Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
                        context.push('/gerenteHome');
                      }, showLabel: showExpanded),
                    if (_isAdmin || _isManagement) ...[
                      _sidebarItem(Icons.alt_route_rounded, 'Gestión de Viajes', () {
                        if (isMobile && Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
                        context.push('/viajes');
                      }, showLabel: showExpanded),
                      _sidebarItem(Icons.assignment_rounded, 'Gestión de Solicitudes', () {
                        if (isMobile && Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
                        context.push('/necesidades');
                      }, showLabel: showExpanded),
                    ],
                    _sidebarItem(Icons.local_shipping_rounded, 'Vehículos', () {
                      if (isMobile && Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
                      context.push('/vehiculos');
                    }, showLabel: showExpanded),
                    if (!_isDeposito && !_isChofer)
                      _sidebarItem(Icons.inventory_2_rounded, 'Productos', () {
                        if (isMobile && Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
                        context.push('/productos');
                      }, showLabel: showExpanded),
                    if (!_isChofer) ...[
                      if (!_isCompras)
                        _sidebarItem(Icons.payments_rounded, 'Gestión de Gastos', () {
                          if (isMobile && Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
                          context.push('/gastos');
                        }, showLabel: showExpanded),
                      _sidebarItem(Icons.scale_rounded, 'Control de Pesajes', () {
                        if (isMobile && Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
                        context.push('/pesajes');
                      }, showLabel: showExpanded),
                    ],
                    if (_isDeposito || _isManagement || _isChofer)
                      _sidebarItem(Icons.warehouse_rounded, (_isDeposito || _isManagement) ? 'Cargas Depósito' : 'Depósito Huinca', () {
                        if (isMobile && Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
                        context.push('/depositoHome');
                      }, showLabel: showExpanded),
                    if ((_isAdmin || _isManagement) && !_isDeposito)
                      _sidebarItem(Icons.inventory_2_rounded, 'Gestión de Cargas', () {
                        if (isMobile && Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
                        context.push('/cargas');
                      }, showLabel: showExpanded),
                    const Divider(color: Colors.white10, height: 20),
                    if (!_isDeposito)
                      _sidebarItem(Icons.group_rounded, 'Apicultores', () {
                        if (isMobile && Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
                        context.push('/apicultores');
                      }, showLabel: showExpanded),
                    _sidebarItem(Icons.receipt_long_rounded, 'Remitos Digitales', () {
                      if (isMobile && Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
                      context.push('/remitosLista');
                    }, showLabel: showExpanded),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                child: Column(
                  children: [
                    _sidebarItem(Icons.logout_rounded, 'Cerrar Sesión', () async {
                      await Supabase.instance.client.auth.signOut();
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('keep_session'); 
                      if (context.mounted) context.go('/');
                    }, showLabel: showExpanded),
                    _sidebarItem(Icons.power_settings_new_rounded, 'Salir', () {
                      SystemNavigator.pop();
                    }, color: Colors.redAccent.shade100, showLabel: showExpanded),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
