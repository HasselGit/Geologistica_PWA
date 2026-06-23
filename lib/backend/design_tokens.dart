import 'package:flutter/material.dart';

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
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1),
  );

  static ButtonStyle secondaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primary,
    foregroundColor: Colors.white,
    elevation: 0,
    side: const BorderSide(color: secondary, width: 1.5),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1),
  );
}
