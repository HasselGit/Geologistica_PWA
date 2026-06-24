import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../backend/design_tokens.dart';

class HistorialTambor extends StatelessWidget {
  final List<Map<String, dynamic>> history;

  const HistorialTambor({Key? key, required this.history}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.outline.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: DesignTokens.primary.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Línea de Tiempo del Tambor',
              style: DesignTokens.headlineStyle(color: DesignTokens.primary).copyWith(fontSize: 20),
            ),
          ),
          const Divider(height: 1, color: DesignTokens.surfaceLow),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final record = history[index];
                final isLast = index == history.length - 1;
                return _buildTimelineEvent(record, isLast);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineEvent(Map<String, dynamic> record, bool isLast) {
    final DateTime date = DateTime.tryParse(record['created_at']?.toString() ?? '') ?? DateTime.now();
    final String formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(date);
    
    // Extract location or action information if possible
    final parada = record['paradas'] ?? {};
    final ruta = parada['rutas'] ?? {};
    final viaje = ruta['viajes'] ?? {};
    
    String actionTitle = 'Pesaje Registrado';
    String actionDetails = 'Peso Bruto: ${record['peso_bruto']} kg | Tara: ${record['tara']} kg | Neto: ${record['peso_neto']} kg';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: DesignTokens.secondary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: DesignTokens.secondary.withOpacity(0.4),
                      blurRadius: 4,
                    )
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: DesignTokens.outline.withOpacity(0.3),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formattedDate,
                    style: DesignTokens.labelStyle(color: DesignTokens.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    actionTitle,
                    style: DesignTokens.bodyStyle(color: DesignTokens.onSurface).copyWith(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    actionDetails,
                    style: DesignTokens.bodyStyle(color: DesignTokens.onSurfaceVariant),
                  ),
                  if (viaje['chofer_id'] != null || parada['viaje_id'] != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: DesignTokens.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: DesignTokens.primary.withOpacity(0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_shipping_outlined, size: 14, color: DesignTokens.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Asociado a Viaje',
                            style: DesignTokens.labelStyle(color: DesignTokens.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
