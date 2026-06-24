import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../backend/design_tokens.dart';

class GastosDetalleDialog extends StatelessWidget {
  final Map<String, dynamic> gasto;

  const GastosDetalleDialog({super.key, required this.gasto});

  @override
  Widget build(BuildContext context) {
    final tipo = gasto['tipo_gasto'] ?? 'Gasto';
    final importe = gasto['importe']?.toString() ?? '0';
    final fecha = DateTime.tryParse(gasto['fecha']?.toString() ?? '') ?? DateTime.now();
    final fechaStr = DateFormat('dd/MM/yyyy HH:mm').format(fecha);
    final chofer = gasto['profiles'] != null 
        ? '${gasto['profiles']['nombre']} ${gasto['profiles']['apellido']}' 
        : 'S/D';
    final viaje = gasto['viajes']?['viaje_codigo'] ?? (gasto['viaje_codigo'] ?? 'S/D');
    final metodo = gasto['forma_pago'] ?? 'S/D';
    final comprobante = gasto['nro_comprobante'] ?? 'S/D';
    final descripcion = gasto['descripcion'] ?? '';
    final ticketUrl = gasto['comprobante_url'];
    final litros = gasto['cantidad_litros']?.toString();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: DesignTokens.surface,
      child: Container(
        width: 800,
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 900),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Detalle de Gasto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28, color: DesignTokens.primary, fontFamily: 'Manrope')),
                IconButton(icon: const Icon(Icons.close_rounded, size: 28), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 32),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildBentoItem('Importe Total', '\$ $importe', Icons.attach_money_rounded, Colors.white, width: 380, isHighlight: true),
                    _buildBentoItem('Tipo de Gasto', tipo.toUpperCase(), Icons.category_rounded, const Color(0xFFFFF9E6), width: 340, textColor: const Color(0xFFC68E17), isHighlight: true),
                    _buildBentoItem('Fecha de Registro', fechaStr, Icons.calendar_today_rounded, Colors.white, width: 230),
                    _buildBentoItem('Registrado por', chofer, Icons.person_rounded, Colors.white, width: 250),
                    _buildBentoItem('Viaje Asociado', viaje, Icons.local_shipping_rounded, Colors.white, width: 230),
                    _buildBentoItem('Forma de Pago', metodo, Icons.payment_rounded, Colors.white, width: 230),
                    _buildBentoItem('Comprobante', comprobante, Icons.receipt_rounded, Colors.white, width: 250),
                    if (tipo == 'Combustible' && litros != null)
                      _buildBentoItem('Litros Cargados', '$litros L', Icons.local_gas_station_rounded, Colors.white, width: 230),
                    if (descripcion.toString().trim().isNotEmpty)
                      _buildBentoItem('Observaciones', descripcion, Icons.notes_rounded, Colors.white, width: 736),
                    if (ticketUrl != null && ticketUrl.toString().isNotEmpty)
                      _buildBentoImage('Ticket / Comprobante', ticketUrl, context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBentoItem(String label, String value, IconData icon, Color bgColor, {required double width, bool isHighlight = false, Color? textColor}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DesignTokens.primary.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: DesignTokens.secondary),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlight ? 32 : 18,
              fontWeight: FontWeight.w900,
              color: textColor ?? DesignTokens.primary,
              fontFamily: isHighlight ? 'Manrope' : 'Work Sans',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoImage(String label, String url, BuildContext context) {
    return Container(
      width: 736,
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DesignTokens.primary.withOpacity(0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(url, fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                ),
              ),
            ),
            Positioned(
              left: 24, bottom: 24,
              child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            Positioned(
              bottom: 24, right: 24,
              child: FloatingActionButton.extended(
                backgroundColor: DesignTokens.primary,
                icon: const Icon(Icons.zoom_in_rounded, color: Colors.white),
                label: const Text('Ampliar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (zoomCtx) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.all(20),
                      child: InteractiveViewer(
                        panEnabled: true,
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(url, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
