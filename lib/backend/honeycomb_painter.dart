import 'package:flutter/material.dart';
import 'dart:math';

class HoneycombPainter extends CustomPainter {
  final Color color;
  const HoneycombPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = color.withOpacity(0.08) // Aumentamos visibilidad
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..isAntiAlias = true; 

    const radius = 30.0;
    final double hexWidth = radius * 1.732;
    final double hexHeight = radius * 2;
    final double verticalSpacing = hexHeight * 0.75;

    // Usamos un solo Path para optimizar el dibujado en una sola llamada de GPU
    final path = Path();

    for (double y = -radius; y < size.height + radius; y += verticalSpacing) {
      bool offset = ((y / verticalSpacing).round() % 2 == 0);
      for (double x = -hexWidth; x < size.width + hexWidth; x += hexWidth) {
        double cx = x + (offset ? hexWidth / 2 : 0);
        
        for (int i = 0; i < 6; i++) {
          double angle = (pi / 3) * i - (pi / 2);
          double px = cx + radius * cos(angle);
          double py = y + radius * sin(angle);
          if (i == 0) path.moveTo(px, py); else path.lineTo(px, py);
        }
        path.close();
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant HoneycombPainter oldDelegate) => oldDelegate.color != color;
}
