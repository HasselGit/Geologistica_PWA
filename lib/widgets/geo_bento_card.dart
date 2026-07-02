import 'package:flutter/material.dart';
import '../backend/design_tokens.dart';
import 'dart:ui';

class GeoBentoCard extends StatefulWidget {
  final String title;
  final String value;
  final String trend;
  final Widget? iconWidget;
  final Color? accentColor;
  final List<double>? sparklineData;
  final VoidCallback? onTap;

  const GeoBentoCard({
    required this.title,
    required this.value,
    required this.trend,
    this.iconWidget,
    this.accentColor,
    this.sparklineData,
    this.onTap,
  });

  @override
  State<GeoBentoCard> createState() => GeoBentoCardState();
}

class GeoBentoCardState extends State<GeoBentoCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color cardBg = const Color(0xFFFFFFFF);
    Color subColor = DesignTokens.onSurfaceVariant.withOpacity(0.7);
    Color valueColor = const Color(0xFF08201A);
    Color accent = widget.accentColor ?? DesignTokens.secondary;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _isHovered ? -6 : 0, 0),
          decoration: BoxDecoration(
            color: cardBg.withOpacity(0.9), // Glassmorphism hint
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accent.withOpacity(_isHovered ? 0.3 : 0.05),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(_isHovered ? 0.15 : 0.04),
                blurRadius: _isHovered ? 30 : 15,
                offset: Offset(0, _isHovered ? 12 : 6),
              )
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Efecto de brillo de fondo
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withOpacity(0.05),
                  ),
                ),
              ),
              if (widget.sparklineData != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 80,
                  child: Opacity(
                    opacity: 0.25, // Mucho más visible
                    child: CustomPaint(
                      painter: SparklinePainter(widget.sparklineData!, accent),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 1.2,
                            color: subColor,
                          ),
                        ),
                        if (widget.iconWidget != null) widget.iconWidget!,
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.value,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w900,
                        fontSize: 48,
                        color: valueColor,
                        height: 1.0,
                        letterSpacing: -1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.trend,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: accent.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


