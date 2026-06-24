import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../backend/supabase_service.dart';
import '../backend/design_tokens.dart';

class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key});

  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  bool _isLoading = true;
  String _filtroTiempo = 'Últimos 30 días'; // Opciones: 'Últimos 30 días', 'Este mes', 'Este año'
  
  List<Map<String, dynamic>> _gastos = [];
  List<Map<String, dynamic>> _pesajes = [];

  double _montoTotalGastos = 0.0;
  double _montoTotalKg = 0.0;
  
  List<double> _graficoGastos = [];
  List<double> _graficoKg = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final supa = SupabaseService();
      
      final gastosResponse = await supa.getGastos();
      final pesajesResponse = await supa.getPesajes();

      setState(() {
        _gastos = gastosResponse;
        _pesajes = pesajesResponse;
      });

      _aplicarFiltros();
    } catch (e) {
      print('ReportesPage: Error cargando datos $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _aplicarFiltros() {
    final now = DateTime.now();
    DateTime fechaInicio;
    
    switch (_filtroTiempo) {
      case 'Este mes':
        fechaInicio = DateTime(now.year, now.month, 1);
        break;
      case 'Este año':
        fechaInicio = DateTime(now.year, 1, 1);
        break;
      case 'Últimos 30 días':
      default:
        fechaInicio = now.subtract(const Duration(days: 30));
        break;
    }

    // Filtrar Gastos
    double tempGastos = 0.0;
    List<double> dailyGastos = List.filled(30, 0.0); // Simple simulación o agrupar real
    for (var g in _gastos) {
      final fechaRaw = g['fecha'] ?? g['created_at'];
      if (fechaRaw != null) {
        final fecha = DateTime.tryParse(fechaRaw.toString());
        if (fecha != null && fecha.isAfter(fechaInicio)) {
          final monto = double.tryParse(g['monto']?.toString() ?? '0') ?? 0.0;
          tempGastos += monto;
          // Simple binning for sparkline
          int dayDiff = now.difference(fecha).inDays;
          if (dayDiff >= 0 && dayDiff < 30) {
            dailyGastos[29 - dayDiff] += monto;
          }
        }
      }
    }

    // Filtrar Pesajes
    double tempKg = 0.0;
    List<double> dailyKg = List.filled(30, 0.0);
    for (var p in _pesajes) {
      final fechaRaw = p['created_at'];
      if (fechaRaw != null) {
        final fecha = DateTime.tryParse(fechaRaw.toString());
        if (fecha != null && fecha.isAfter(fechaInicio)) {
          final neto = double.tryParse(p['peso_neto']?.toString() ?? '0') ?? 0.0;
          tempKg += neto;
          // Simple binning
          int dayDiff = now.difference(fecha).inDays;
          if (dayDiff >= 0 && dayDiff < 30) {
            dailyKg[29 - dayDiff] += neto;
          }
        }
      }
    }

    setState(() {
      _montoTotalGastos = tempGastos;
      _montoTotalKg = tempKg;
      _graficoGastos = dailyGastos;
      _graficoKg = dailyKg;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: Text('Reportes STITCH', style: DesignTokens.headlineStyle(color: Colors.white)),
        backgroundColor: DesignTokens.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWeb = constraints.maxWidth > 900;
          return CustomPaint(
            painter: const HoneycombPainter(),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(isWeb ? 32.0 : 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(color: DesignTokens.secondary))
                          : _buildBentoGrid(isWeb),
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

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Dashboard Gerencial',
          style: DesignTokens.headlineStyle(),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: DesignTokens.surfaceLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DesignTokens.outline),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filtroTiempo,
              icon: const Icon(Icons.keyboard_arrow_down, color: DesignTokens.primary),
              style: DesignTokens.bodyStyle(color: DesignTokens.primary).copyWith(fontWeight: FontWeight.w600),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() => _filtroTiempo = newValue);
                  _aplicarFiltros();
                }
              },
              items: <String>['Últimos 30 días', 'Este mes', 'Este año']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBentoGrid(bool isWeb) {
    final currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$');
    final numberFormat = NumberFormat.decimalPattern('es_AR');

    if (isWeb) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildKpiCard('Total Miel Acopiada', '${numberFormat.format(_montoTotalKg)} Kg', Icons.scale, DesignTokens.secondary, _graficoKg)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildKpiCard('Gastos Operativos', currencyFormat.format(_montoTotalGastos), Icons.monetization_on, DesignTokens.error, _graficoGastos)),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(child: _buildMainChart()),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: _buildResumenList(),
          )
        ],
      );
    } else {
      return ListView(
        children: [
          _buildKpiCard('Total Miel Acopiada', '${numberFormat.format(_montoTotalKg)} Kg', Icons.scale, DesignTokens.secondary, _graficoKg),
          const SizedBox(height: 16),
          _buildKpiCard('Gastos Operativos', currencyFormat.format(_montoTotalGastos), Icons.monetization_on, DesignTokens.error, _graficoGastos),
          const SizedBox(height: 16),
          SizedBox(height: 300, child: _buildMainChart()),
          const SizedBox(height: 16),
          SizedBox(height: 400, child: _buildResumenList()),
        ],
      );
    }
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color, List<double> data) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Text(title, style: DesignTokens.labelStyle()),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: DesignTokens.headlineStyle(color: DesignTokens.onSurface).copyWith(fontSize: 28)),
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            width: double.infinity,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: SparklinePainter(data, color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Rendimiento vs Gasto (Relación)', style: DesignTokens.headlineStyle(color: DesignTokens.onSurface)),
          const SizedBox(height: 24),
          Expanded(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: RendimientoVsGastoPainter(_graficoKg, _graficoGastos),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenList() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Últimos Gastos', style: DesignTokens.headlineStyle(color: DesignTokens.onSurface)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: math.min(10, _gastos.length),
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final gasto = _gastos[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(gasto['categoria'] ?? 'Gasto', style: DesignTokens.bodyStyle(color: DesignTokens.onSurface)),
                  subtitle: Text(gasto['fecha'] ?? '', style: DesignTokens.labelStyle()),
                  trailing: Text(
                    NumberFormat.currency(locale: 'es_AR', symbol: '\$').format(double.tryParse(gasto['monto']?.toString() ?? '0') ?? 0),
                    style: DesignTokens.bodyStyle(color: DesignTokens.error).copyWith(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class RendimientoVsGastoPainter extends CustomPainter {
  final List<double> rendimientos;
  final List<double> gastos;

  RendimientoVsGastoPainter(this.rendimientos, this.gastos);

  @override
  void paint(Canvas canvas, Size size) {
    if (rendimientos.isEmpty || gastos.isEmpty) return;

    final maxRendimiento = rendimientos.reduce(math.max) == 0 ? 1.0 : rendimientos.reduce(math.max);
    final maxGasto = gastos.reduce(math.max) == 0 ? 1.0 : gastos.reduce(math.max);

    final rendPaint = Paint()
      ..color = DesignTokens.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final gastoPaint = Paint()
      ..color = DesignTokens.error
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final rendPath = Path();
    final gastoPath = Path();

    final dx = size.width / (rendimientos.length - 1 == 0 ? 1 : rendimientos.length - 1);

    for (int i = 0; i < rendimientos.length; i++) {
      final x = i * dx;
      final yRend = size.height - (rendimientos[i] / maxRendimiento * size.height * 0.8);
      final yGasto = size.height - (gastos[i] / maxGasto * size.height * 0.8);

      if (i == 0) {
        rendPath.moveTo(x, yRend);
        gastoPath.moveTo(x, yGasto);
      } else {
        // Curve to make it look smooth (bezier)
        final prevX = (i - 1) * dx;
        final prevYRend = size.height - (rendimientos[i - 1] / maxRendimiento * size.height * 0.8);
        final prevYGasto = size.height - (gastos[i - 1] / maxGasto * size.height * 0.8);

        rendPath.quadraticBezierTo(prevX + dx / 2, prevYRend, x, yRend);
        gastoPath.quadraticBezierTo(prevX + dx / 2, prevYGasto, x, yGasto);
      }
    }

    // Grid lines
    final gridPaint = Paint()
      ..color = DesignTokens.outline.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    for (int i = 0; i < 5; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    canvas.drawPath(rendPath, rendPaint);
    canvas.drawPath(gastoPath, gastoPaint);
  }

  @override
  bool shouldRepaint(covariant RendimientoVsGastoPainter oldDelegate) {
    return oldDelegate.rendimientos != rendimientos || oldDelegate.gastos != gastos;
  }
}
