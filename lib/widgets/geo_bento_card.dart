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
    
    final bool isMobile = MediaQuery.of(context).size.width < 600;

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
            borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
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
                    opacity: 0.25,
                    child: CustomPaint(
                      painter: SparklinePainter(widget.sparklineData!, accent),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 10 : 24,
                  vertical: isMobile ? 12 : 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              widget.title,
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontWeight: FontWeight.w800,
                                fontSize: isMobile ? 11 : 12,
                                letterSpacing: isMobile ? 0.3 : 1.2,
                                color: subColor,
                              ),
                            ),
                          ),
                        ),
                        if (widget.iconWidget != null) ...[
                          const SizedBox(width: 4),
                          widget.iconWidget!,
                        ],
                      ],
                    ),
                    SizedBox(height: isMobile ? 6 : 14),
                    Text(
                      widget.value,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w900,
                        fontSize: isMobile ? 30 : 48,
                        color: valueColor,
                        height: 1.0,
                        letterSpacing: -1.0,
                      ),
                    ),
                    SizedBox(height: isMobile ? 6 : 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.trend,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: isMobile ? 10 : 11,
                            color: accent.withOpacity(0.8),
                          ),
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


