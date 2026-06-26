import 'package:flutter/material.dart';
import '../backend/design_tokens.dart';

class AlertasPage extends StatefulWidget {
  const AlertasPage({super.key});

  @override
  State<AlertasPage> createState() => _AlertasPageState();
}

class _AlertasPageState extends State<AlertasPage> {
  // Mock alerts to preserve the logic structure, adding the requested critical notification
  final List<Map<String, dynamic>> alertas = [
    {
      'id': 'ST-501',
      'title': 'Stock Crítico: Tambores Vacíos',
      'description': 'Depósito Huinca reporta stock por debajo del mínimo (2 unidades restantes). Se requiere reabastecimiento urgente.',
      'type': 'error',
      'date': '25 Jun 2026',
    },
    {
      'id': 'AR-402',
      'title': 'Alerta Térmica: AR-402',
      'description': 'Temperatura en la colmena excedió el umbral seguro.',
      'type': 'warning',
      'date': '24 Jun 2026',
    },
    {
      'id': 'TR-105',
      'title': 'Desvío de Ruta',
      'description': 'El vehículo se desvió de la ruta planeada en el último trayecto.',
      'type': 'error',
      'date': '24 Jun 2026',
    },
    {
      'id': 'MT-992',
      'title': 'Mantenimiento Sugerido',
      'description': 'Revisión de extractor de miel recomendada para la próxima semana.',
      'type': 'info',
      'date': '23 Jun 2026',
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surfaceLow,
      appBar: AppBar(
        title: Text('Panel de Alertas', style: DesignTokens.headlineStyle(color: DesignTokens.primary)),
        backgroundColor: DesignTokens.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: DesignTokens.primary),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWeb = constraints.maxWidth >= 900;
          
          if (isWeb) {
            return _buildWebLayout();
          } else {
            return _buildMobileLayout();
          }
        },
      ),
    );
  }

  Widget _buildWebLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Notificaciones Activas', 
                style: DesignTokens.headlineStyle(color: DesignTokens.primary).copyWith(fontSize: 24)
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: DesignTokens.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined, color: DesignTokens.error, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${alertas.where((a) => a['type'] == 'error').length} Críticas',
                      style: DesignTokens.labelStyle(color: DesignTokens.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: alertas.map((alerta) => _buildBentoCard(alerta, isWeb: true)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: alertas.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _buildBentoCard(alertas[index], isWeb: false);
      },
    );
  }

  Widget _buildBentoCard(Map<String, dynamic> alerta, {required bool isWeb}) {
    Color badgeColor;
    String badgeText;

    switch (alerta['type']) {
      case 'error':
        badgeColor = DesignTokens.error;
        badgeText = 'CRÍTICO';
        break;
      case 'warning':
        badgeColor = DesignTokens.secondary;
        badgeText = 'ADVERTENCIA';
        break;
      case 'info':
      default:
        badgeColor = DesignTokens.success;
        badgeText = 'INFO';
        break;
    }

    return Container(
      width: isWeb ? 380 : double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF), // Clean white background constraint
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.outline.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: DesignTokens.primary.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Restrict strong warning colors EXCLUSIVELY to discrete status badges
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withOpacity(0.2)),
                ),
                child: Text(
                  badgeText,
                  style: DesignTokens.labelStyle(color: badgeColor).copyWith(fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                alerta['date'],
                style: DesignTokens.bodyStyle(color: DesignTokens.onSurfaceVariant).copyWith(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            alerta['title'],
            style: DesignTokens.headlineStyle(color: DesignTokens.primary).copyWith(fontSize: 18),
          ),
          const SizedBox(height: 12),
          Text(
            alerta['description'],
            style: DesignTokens.bodyStyle(color: DesignTokens.onSurfaceVariant),
          ),
          if (alerta['type'] == 'error') ...[
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  backgroundColor: DesignTokens.surfaceLow,
                ),
                child: Text('REVISAR', style: DesignTokens.labelStyle(color: DesignTokens.primary)),
              ),
            ),
          ]
        ],
      ),
    );
  }
}
