import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../backend/supabase_service.dart';
import '../backend/design_tokens.dart';

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




  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (widget.vehiculoId == null) {
      setState(() => _loading = false);
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
      appBar: AppBar(
        backgroundColor: DesignTokens.surface,
        elevation: 0,
        title: Text(_vehiculo?['vehiculo_codigo'] ?? 'Detalle Vehículo', 
          style: const TextStyle(color: DesignTokens.primary, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: DesignTokens.primary), onPressed: () => context.pop()),
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
        : _error != null
          ? Center(child: Text('Error: $_error'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: DesignTokens.primary,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: DesignTokens.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.local_shipping_rounded, size: 64, color: DesignTokens.secondary),
                        const SizedBox(height: 16),
                        Text(_vehiculo?['vehiculo_codigo'] ?? 'S/D', 
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                        Text(_vehiculo?['patente'] ?? 'SIN PATENTE', 
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  const Text('INFORMACIÓN TÉCNICA', 
                    style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black45, letterSpacing: 1.1)),
                  const SizedBox(height: 16),
                  
                  _infoTile(Icons.branding_watermark_rounded, 'Modelo', _vehiculo?['modelo'] ?? 'No especificado'),
                  _infoTile(Icons.scale_rounded, 'Capacidad Carga', '${_vehiculo?['capacidad_kg'] ?? 0} KG'),
                  _infoTile(Icons.inventory_2_rounded, 'Capacidad Tambores', '${_vehiculo?['capacidad_tambores'] ?? 0} Unidades'),
                  
                  const SizedBox(height: 32),
                  const Text('ESTADO OPERATIVO', 
                    style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black45, letterSpacing: 1.1)),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12, height: 12,
                              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 12),
                            const Text('DISPONIBLE PARA VIAJE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildProgressBar(
                          label: 'CARGA EN KG',
                          current: (_vehiculo?['carga_actual_kg'] as num?)?.toDouble() ?? 0,
                          total: (_vehiculo?['capacidad_kg'] as num?)?.toDouble() ?? 1,
                          unit: 'KG',
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 20),
                        _buildProgressBar(
                          label: 'CARGA EN TAMBORES',
                          current: (_vehiculo?['carga_actual_tambores'] as num?)?.toDouble() ?? 0,
                          total: (_vehiculo?['capacidad_tambores'] as num?)?.toDouble() ?? 1,
                          unit: 'UN',
                          color: const Color(0xFFC68E17),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProgressBar({required String label, required double current, required double total, required String unit, required Color color}) {
    final double percent = (current / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            Text('${current.toStringAsFixed(0)} / ${total.toStringAsFixed(0)} $unit', 
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 10,
              width: double.infinity,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
            ),
            FractionallySizedBox(
              widthFactor: percent,
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.primary.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: DesignTokens.primary.withOpacity(0.4), size: 20),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.black45, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: DesignTokens.primary)),
            ],
          ),
        ],
      ),
    );
  }
}
