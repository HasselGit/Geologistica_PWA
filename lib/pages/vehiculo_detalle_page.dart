import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../backend/supabase_service.dart';
import '../backend/design_tokens.dart';
import '../widgets/geo_sidebar.dart';

class VehiculoDetalleWidget extends StatefulWidget {
  final String? vehiculoId;
  const VehiculoDetalleWidget({super.key, this.vehiculoId});

  @override
  State<VehiculoDetalleWidget> createState() => _VehiculoDetalleWidgetState();
}

class _VehiculoDetalleWidgetState extends State<VehiculoDetalleWidget> {
  Map<String, dynamic>? _vehiculo;
  bool _loading = true;
  String? _error;
  
  String? _userRole;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _fetchData();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email') ?? Supabase.instance.client.auth.currentUser?.email ?? '';
    if (mounted) {
      setState(() {
        _userRole = prefs.getString('user_puesto');
        _userEmail = email;
      });
    }
  }

  Future<void> _fetchData() async {
    if (widget.vehiculoId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final data = await Supabase.instance.client
          .from('vehiculos')
          .select()
          .eq('id', widget.vehiculoId!)
          .maybeSingle();
      
      if (mounted) {
        setState(() {
          _vehiculo = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWeb = constraints.maxWidth >= 900;
          
          Widget content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Premium
              Padding(
                padding: const EdgeInsets.only(top: 40, bottom: 32),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () { if (context.canPop()) context.pop(); },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: DesignTokens.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => context.go('/home'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
                        child: const Icon(Icons.home_rounded, size: 18, color: DesignTokens.primary),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Text(_vehiculo?['vehiculo_codigo'] ?? 'Detalle Vehículo', style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 24, color: DesignTokens.primary)),
                  ],
                ),
              ),
              Expanded(
                child: _loading 
                  ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
                  : _error != null
                    ? Center(child: Text('Error: $_error'))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 40),
                        child: isWeb ? _buildWebSplitLayout() : _buildMobileLayout(),
                      ),
              ),
            ],
          );

          if (isWeb) {
            content = Padding(
              padding: const EdgeInsets.fromLTRB(120, 0, 40, 0),
              child: content,
            );
          } else {
            content = Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: content,
            );
          }

          return Stack(
            children: [
              const Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(painter: HoneycombPainter()),
                ),
              ),
              if (isWeb)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GeoSidebar(
                      userRole: _userRole ?? '',
                      userEmail: _userEmail ?? '',
                      displayName: _userEmail ?? '',
                    ),
                    Expanded(child: content),
                  ],
                )
              else
                content,
            ],
          );
        },
      ),
    );
  }

  Widget _buildWebSplitLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Panel: Hero Card
        Expanded(
          flex: 3,
          child: _buildHeroCard(),
        ),
        const SizedBox(width: 32),
        // Right Panel: Bento Grid
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFichaTecnicaCard(true),
              const SizedBox(height: 32),
              const Text('ESTADO OPERATIVO', 
                style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w700, fontSize: 12, color: DesignTokens.onSurfaceVariant, letterSpacing: 1.5)),
              const SizedBox(height: 16),
              _buildEstadoCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroCard(),
        const SizedBox(height: 32),
        _buildFichaTecnicaCard(false),
        const SizedBox(height: 32),
        const Text('ESTADO OPERATIVO', 
          style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w700, fontSize: 12, color: DesignTokens.onSurfaceVariant, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        _buildEstadoCard(),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: DesignTokens.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: DesignTokens.primary.withOpacity(0.08), 
            blurRadius: 15, 
            offset: const Offset(0, 4)
          )
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.local_shipping_rounded, size: 72, color: DesignTokens.secondary),
          const SizedBox(height: 24),
          Text(_vehiculo?['vehiculo_codigo'] ?? 'S/D', 
            style: const TextStyle(fontFamily: 'Manrope', color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_vehiculo?['patente'] ?? 'SIN PATENTE', 
              style: const TextStyle(fontFamily: 'JetBrains Mono', color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 2)),
          ),
        ],
      ),
    );
  }

  Widget _buildFichaTecnicaCard(bool isWeb) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.secondary.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: DesignTokens.secondary.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.badge_rounded, color: DesignTokens.secondary, size: 20),
              const SizedBox(width: 8),
              const Text('FICHA TÉCNICA', 
                style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w700, fontSize: 12, color: DesignTokens.secondary, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 24),
          if (isWeb)
            Row(
              children: [
                Expanded(child: _infoItem(Icons.branding_watermark_rounded, 'Modelo', _vehiculo?['modelo'] ?? 'No especificado')),
                const SizedBox(width: 16),
                Expanded(child: _infoItem(Icons.scale_rounded, 'Cap. Carga', '${_vehiculo?['capacidad_kg'] ?? 0} KG')),
                const SizedBox(width: 16),
                Expanded(child: _infoItem(Icons.inventory_2_rounded, 'Cap. Tambores', '${_vehiculo?['capacidad_tambores'] ?? 0} Unidades')),
              ],
            )
          else
            Column(
              children: [
                _infoItem(Icons.branding_watermark_rounded, 'Modelo', _vehiculo?['modelo'] ?? 'No especificado'),
                const SizedBox(height: 16),
                _infoItem(Icons.scale_rounded, 'Capacidad Carga', '${_vehiculo?['capacidad_kg'] ?? 0} KG'),
                const SizedBox(height: 16),
                _infoItem(Icons.inventory_2_rounded, 'Capacidad Tambores', '${_vehiculo?['capacidad_tambores'] ?? 0} Unidades'),
              ],
            )
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: DesignTokens.surfaceLow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: DesignTokens.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: DesignTokens.onSurfaceVariant, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontFamily: 'Manrope', fontSize: 14, fontWeight: FontWeight.w800, color: DesignTokens.onSurface)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEstadoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.surfaceLow, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: DesignTokens.primary.withOpacity(0.02), 
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              const Text('DISPONIBLE PARA VIAJE', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, color: Colors.green, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 32),
          _buildProgressBar(
            label: 'CARGA EN KG',
            current: (_vehiculo?['carga_actual_kg'] as num?)?.toDouble() ?? 0,
            total: (_vehiculo?['capacidad_kg'] as num?)?.toDouble() ?? 1,
            unit: 'KG',
            color: const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 24),
          _buildProgressBar(
            label: 'CARGA EN TAMBORES',
            current: (_vehiculo?['carga_actual_tambores'] as num?)?.toDouble() ?? 0,
            total: (_vehiculo?['capacidad_tambores'] as num?)?.toDouble() ?? 1,
            unit: 'UN',
            color: DesignTokens.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar({required String label, required double current, required double total, required String unit, required Color color}) {
    final double percent = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontFamily: 'Work Sans', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: DesignTokens.onSurfaceVariant)),
            Text('${current.toStringAsFixed(0)} / ${total.toStringAsFixed(0)} $unit', 
              style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, fontWeight: FontWeight.w600, color: DesignTokens.onSurface)),
          ],
        ),
        const SizedBox(height: 12),
        Stack(
          children: [
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(color: DesignTokens.surfaceLow, borderRadius: BorderRadius.circular(3)),
            ),
            FractionallySizedBox(
              widthFactor: percent,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
