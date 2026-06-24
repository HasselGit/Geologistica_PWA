import 'package:flutter/material.dart';
import '../backend/design_tokens.dart';

class AlertasPage extends StatefulWidget {
  const AlertasPage({super.key});

  @override
  State<AlertasPage> createState() => _AlertasPageState();
}

class _AlertasPageState extends State<AlertasPage> {
  // Mock alerts to preserve the logic structure
  final List<Map<String, dynamic>> alertas = [
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
        title: Text('Alertas', style: DesignTokens.headlineStyle(color: DesignTokens.primary)),
        backgroundColor: DesignTokens.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: DesignTokens.primary),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWeb = constraints.maxWidth > 800;
          
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
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Panel de Alertas', style: DesignTokens.headlineStyle(color: DesignTokens.primary)),
          const SizedBox(height: 24),
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
      width: isWeb ? 400 : double.infinity,
      decoration: BoxDecoration(
        color: DesignTokens.surface, // Clean light backgrounds constraint
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.outline.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: DesignTokens.primary.withOpacity(0.05),
            blurRadius: 10,
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
                  border: Border.all(color: badgeColor.withOpacity(0.3)),
                ),
                child: Text(
                  badgeText,
                  style: DesignTokens.labelStyle(color: badgeColor).copyWith(fontSize: 10),
                ),
              ),
              Text(
                alerta['date'],
                style: DesignTokens.labelStyle(color: DesignTokens.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            alerta['title'],
            style: DesignTokens.headlineStyle(color: DesignTokens.primary).copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            alerta['description'],
            style: DesignTokens.bodyStyle(color: DesignTokens.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
