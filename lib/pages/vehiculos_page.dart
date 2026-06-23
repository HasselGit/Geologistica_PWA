import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../backend/supabase_service.dart';
import '../backend/design_tokens.dart';
import 'package:go_router/go_router.dart';

class VehiculosPageWidget extends StatefulWidget {
  const VehiculosPageWidget({super.key});

  @override
  State<VehiculosPageWidget> createState() => _VehiculosPageWidgetState();
}

class _VehiculosPageWidgetState extends State<VehiculosPageWidget> {
  List<Map<String, dynamic>> _vehiculos = [];
  bool _loading = true;

  // Design system constants


  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final data = await SupabaseService().getVehiculos();
    if (mounted) {
      setState(() {
        _vehiculos = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DesignTokens.primary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Gestión de Vehículos',
          style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold, color: DesignTokens.primary),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FLOTA ACTIVA',
                    style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.bold, fontSize: 11, color: DesignTokens.onSurfaceVariant, letterSpacing: 1.1),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 1,
                      mainAxisSpacing: 16,
                      childAspectRatio: 2.2,
                    ),
                    itemCount: _vehiculos.length,
                    itemBuilder: (context, index) {
                      final v = _vehiculos[index];
                      return _buildVehicleCard(v);
                    },
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addVehiculo,
        backgroundColor: DesignTokens.secondary,
        child: const Icon(Icons.add, color: DesignTokens.primary),
      ),
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> v) {
    final codigo = v['vehiculo_codigo'] ?? v['codigo'] ?? 'S/D';
    final modelo = v['modelo'] ?? 'Modelo desconocido';
    final patente = v['patente'] ?? 'S/P';
    final capKg = v['capacidad_kg']?.toString() ?? '0';
    final capTamb = v['capacidad_tambores']?.toString() ?? '0';

    return GestureDetector(
      onTap: () => context.push('/vehiculoDetalle?id=${v['id']}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DesignTokens.primary.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(color: DesignTokens.primary.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 100,
              decoration: const BoxDecoration(
                color: Color(0xFFF5F3F3),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
              ),
              child: const Center(
                child: Icon(Icons.local_shipping_rounded, size: 40, color: DesignTokens.primary),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          codigo,
                          style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 18, color: DesignTokens.primary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: DesignTokens.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text(patente, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: DesignTokens.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(modelo, style: const TextStyle(fontSize: 12, color: DesignTokens.onSurfaceVariant)),
                    const Spacer(),
                    Row(
                      children: [
                        _specItem(Icons.scale_rounded, '$capKg kg'),
                        const SizedBox(width: 16),
                        _specItem(Icons.inventory_2_rounded, '$capTamb tamb'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addVehiculo() {
    final codigoController = TextEditingController();
    final patenteController = TextEditingController();
    final modeloController = TextEditingController();
    final capKgController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: DesignTokens.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nuevo Vehículo', style: TextStyle(fontFamily: 'Manrope', fontSize: 22, fontWeight: FontWeight.w800, color: DesignTokens.primary)),
            const SizedBox(height: 24),
            _input(codigoController, 'Código (ej: V-01)', Icons.qr_code_rounded),
            const SizedBox(height: 16),
            _input(patenteController, 'Patente', Icons.credit_card_rounded),
            const SizedBox(height: 16),
            _input(modeloController, 'Modelo/Marca', Icons.branding_watermark_rounded),
            const SizedBox(height: 16),
            _input(capKgController, 'Capacidad (KG)', Icons.scale_rounded, isNumeric: true),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  if (codigoController.text.isEmpty) return;
                  await Supabase.instance.client.from('vehiculos').insert({
                    'vehiculo_codigo': codigoController.text,
                    'patente': patenteController.text,
                    'modelo': modeloController.text,
                    'capacidad_kg': double.tryParse(capKgController.text) ?? 0,
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    _fetchData();
                  }
                },
                style: DesignTokens.primaryButtonStyle,
                child: const Text('GUARDAR VEHÍCULO'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(TextEditingController controller, String label, IconData icon, {bool isNumeric = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _specItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: DesignTokens.secondary),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: DesignTokens.primary)),
      ],
    );
  }
}
