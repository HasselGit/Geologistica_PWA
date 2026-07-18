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

  Widget _sidebarItem(IconData icon, String title, VoidCallback onTap, {bool active = false, Color? color}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: active ? DesignTokens.secondary.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
        leading: Icon(icon, color: active ? DesignTokens.secondary : (color ?? Colors.white70), size: 20),
        title: _isSidebarHovered
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
    final double sidebarWidth = _isSidebarHovered ? 260 : 80;
    return MouseRegion(
      onEnter: (_) => setState(() => _isSidebarHovered = true),
      onExit: (_) => setState(() => _isSidebarHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: sidebarWidth,
        margin: const EdgeInsets.only(left: 16, top: 16, bottom: 16, right: 0),
        decoration: BoxDecoration(
          color: DesignTokens.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 30),
              child: Row(
                mainAxisAlignment: _isSidebarHovered ? MainAxisAlignment.start : MainAxisAlignment.center,
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/images/logo_Geologistica_Verde.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (_isSidebarHovered) ...[
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

                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Container(
                padding: EdgeInsets.all(_isSidebarHovered ? 12 : 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: _isSidebarHovered ? MainAxisAlignment.start : MainAxisAlignment.center,
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
                    if (_isSidebarHovered) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.displayName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.userRole,
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
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  if ((_isAdmin || _isManagement) && !_isAdministrativo)
                    _sidebarItem(Icons.dashboard_rounded, 'Dashboard', () => context.push('/gerenteHome'), active: false),
                  if (_isAdmin || _isManagement)
                    _sidebarItem(Icons.alt_route_rounded, 'Gestión de Viajes', () => context.push('/viajes')),
                  _sidebarItem(Icons.local_shipping_rounded, 'Vehículos', () => context.push('/vehiculos')),
                  if (!_isDeposito && !_isChofer && !_isCompras)
                    _sidebarItem(Icons.inventory_2_rounded, 'Productos', () => context.push('/productos')),
                  if (!_isChofer) ...[
                    if (!_isCompras)
                      _sidebarItem(Icons.payments_rounded, 'Gestión de Gastos', () => context.push('/gastos')),
                    _sidebarItem(Icons.scale_rounded, 'Control de Pesajes', () => context.push('/pesajes')),
                  ],
                  if (_isDeposito || _isManagement || _isChofer)
                    _sidebarItem(Icons.warehouse_rounded, (_isDeposito || _isManagement) ? 'Cargas Depósito' : 'Depósito Huinca', () => context.push('/depositoHome')),
                  if ((_isAdmin || _isManagement) && !_isDeposito)
                    _sidebarItem(Icons.inventory_2_rounded, 'Gestión de Cargas', () => context.push('/cargas')),
                  const Divider(color: Colors.white10, height: 20),
                  if (!_isDeposito)
                    _sidebarItem(Icons.group_rounded, 'Apicultores', () => context.push('/apicultores')),
                  _sidebarItem(Icons.receipt_long_rounded, 'Remitos Digitales', () => context.push('/remitosLista')),
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
                  }),
                  _sidebarItem(Icons.power_settings_new_rounded, 'Salir', () {
                    SystemNavigator.pop();
                  }, color: Colors.redAccent.shade100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
