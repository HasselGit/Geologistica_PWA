import 'package:flutter/material.dart';
import 'dart:math' as math;

class DesignTokens {
  // Brand Colors
  static const Color primary = Color(0xFF08201A);      // Deep Forest (Main Primary)
  static const Color primaryVariant = Color(0xFF1E352F); // Forest Green
  static const Color secondary = Color(0xFFC68E17);    // Honey Gold
  static const Color accent = Color(0xFFFDBE49);       // Soft Gold
  
  // Neutral Colors
  static const Color surface = Color(0xFFFBF9F8);      // Off-white surface
  static const Color surfaceLow = Color(0xFFF5F3F3);   // Low emphasis surface
  static const Color surfaceVariant = Color(0xFFEEECEB); // Slightly darker surface
  static const Color onSurface = Color(0xFF1B1C1C);    // Primary text
  static const Color onSurfaceVariant = Color(0xFF424846); // Secondary text
  static const Color outline = Color(0xFFC2C8C4);      // Borders/Dividers
  
  // Semantic Colors
  static const Color error = Color(0xFFBA1A1A);
  static const Color success = Color(0xFF1A6B43);
  
  // Typography Styles
  static TextStyle headlineStyle({Color color = primary}) => TextStyle(
    fontFamily: 'Manrope',
    fontWeight: FontWeight.w800,
    fontSize: 22,
    color: color,
  );
  
  static TextStyle bodyStyle({Color color = onSurface}) => TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w400,
    fontSize: 14,
    color: color,
  );
  
  static TextStyle labelStyle({Color color = onSurfaceVariant}) => TextStyle(
    fontFamily: 'Work Sans',
    fontWeight: FontWeight.w600,
    fontSize: 12,
    color: color,
    letterSpacing: 0.5,
  );

  // Button Styles
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primary,
    foregroundColor: Colors.white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    textStyle: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1),
  );

  static ButtonStyle secondaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primary,
    foregroundColor: Colors.white,
    elevation: 0,
    side: const BorderSide(color: secondary, width: 1.5),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    textStyle: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1),
  );
}

class HoneycombPainter extends CustomPainter {
  const HoneycombPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF08201A).withOpacity(0.015) // Faint 1.5% opac.
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const double radius = 25.0;
    final double h = radius * math.sqrt(3);
    final double w = radius * 2;

    for (double y = 0; y < size.height + h; y += h) {
      for (double x = 0; x < size.width + w; x += radius * 3) {
        _drawHex(canvas, x, y, radius, paint);
        _drawHex(canvas, x + radius * 1.5, y + h / 2, radius, paint);
      }
    }
  }

  void _drawHex(Canvas canvas, double cx, double cy, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final double angle = i * math.pi / 3;
      final double x = cx + radius * math.cos(angle);
      final double y = cy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant HoneycombPainter oldDelegate) => false;
}

class SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  SparklinePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final double dx = size.width / (data.length - 1);
    final double maxVal = data.reduce((a, b) => a > b ? a : b);
    final double minVal = data.reduce((a, b) => a < b ? a : b);
    final double range = maxVal - minVal == 0 ? 1 : maxVal - minVal;

    for (int i = 0; i < data.length; i++) {
      final double x = i * dx;
      final double y = size.height - ((data[i] - minVal) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SparklinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.data != data;
  }
}

