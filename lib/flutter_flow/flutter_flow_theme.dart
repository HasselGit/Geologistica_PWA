import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class FlutterFlowTheme {
  static final LightModeTheme _lightTheme = LightModeTheme();
  static FlutterFlowTheme of(BuildContext context) => _lightTheme;

  late Color primary;
  late Color secondary;
  late Color tertiary;
  late Color alternate;
  late Color primaryText;
  late Color secondaryText;
  late Color primaryBackground;
  late Color secondaryBackground;
  late Color accent1;
  late Color accent2;
  late Color accent3;
  late Color accent4;
  late Color success;
  late Color warning;
  late Color error;
  late Color info;

  late TextStyle displayLarge;
  late TextStyle displayMedium;
  late TextStyle displaySmall;
  late TextStyle headlineLarge;
  late TextStyle headlineMedium;
  late TextStyle headlineSmall;
  late TextStyle titleLarge;
  late TextStyle titleMedium;
  late TextStyle titleSmall;
  late TextStyle bodyLarge;
  late TextStyle bodyMedium;
  late TextStyle bodySmall;
  late TextStyle labelLarge;
  late TextStyle labelMedium;
  late TextStyle labelSmall;
}

class LightModeTheme extends FlutterFlowTheme {
  LightModeTheme() {
    primary = const Color(0xFF1E352F);
    secondary = const Color(0xFFC68E17);
    tertiary = const Color(0xFFFAF9F6);
    alternate = const Color(0xFFE4E2E2);
    primaryText = const Color(0xFF1B1C1C);
    secondaryText = const Color(0xFF4A4A4A);
    primaryBackground = const Color(0xFFFAF9F6);
    secondaryBackground = const Color(0xFFFFFFFF);
    accent1 = const Color(0xFF4B635C);
    accent2 = const Color(0xFFC68E17);
    accent3 = const Color(0xFFEE8B60);
    accent4 = const Color(0xFFE4E2E2);
    success = const Color(0xFF249689);
    warning = const Color(0xFFF9CF58);
    error = const Color(0xFFBA1A1A);
    info = const Color(0xFFFFFFFF);

    // Estas llamadas ahora solo se ejecutan UNA VEZ en toda la vida de la app
    displayLarge = GoogleFonts.getFont('Manrope', fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.02, color: primaryText);
    displayMedium = GoogleFonts.getFont('Manrope', fontSize: 28, fontWeight: FontWeight.bold, color: primaryText);
    displaySmall = GoogleFonts.getFont('Manrope', fontSize: 24, fontWeight: FontWeight.bold, color: primaryText);
    headlineLarge = GoogleFonts.getFont('Manrope', fontSize: 32, fontWeight: FontWeight.normal, color: primaryText);
    headlineMedium = GoogleFonts.getFont('Manrope', fontSize: 24, fontWeight: FontWeight.w600, color: primaryText);
    headlineSmall = GoogleFonts.getFont('Manrope', fontSize: 20, fontWeight: FontWeight.w600, color: primaryText);
    titleLarge = GoogleFonts.getFont('Manrope', fontSize: 22, fontWeight: FontWeight.normal, color: primaryText);
    titleMedium = GoogleFonts.getFont('Manrope', fontSize: 18, fontWeight: FontWeight.normal, color: primaryText);
    titleSmall = GoogleFonts.getFont('Manrope', fontSize: 18, fontWeight: FontWeight.w600, color: primaryText);
    bodyLarge = GoogleFonts.getFont('Inter', fontSize: 16, fontWeight: FontWeight.normal, color: primaryText);
    bodyMedium = GoogleFonts.getFont('Inter', fontSize: 14, fontWeight: FontWeight.normal, color: primaryText);
    bodySmall = GoogleFonts.getFont('Inter', fontSize: 12, fontWeight: FontWeight.normal, color: primaryText);
    labelLarge = GoogleFonts.getFont('Inter', fontSize: 16, fontWeight: FontWeight.normal, color: primaryText);
    labelMedium = GoogleFonts.getFont('Inter', fontSize: 14, fontWeight: FontWeight.normal, color: primaryText);
    labelSmall = GoogleFonts.getFont('Work Sans', fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.05, color: secondaryText);
  }
}

extension TextStyleHelper on TextStyle {
  TextStyle override({
    TextStyle? font,
    String? fontFamily,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    TextDecoration? decoration,
    double? lineHeight,
  }) =>
      copyWith(
        fontFamily: font?.fontFamily ?? fontFamily,
        color: color ?? font?.color,
        fontSize: fontSize ?? font?.fontSize,
        fontWeight: fontWeight ?? font?.fontWeight,
        fontStyle: fontStyle ?? font?.fontStyle,
        letterSpacing: letterSpacing ?? font?.letterSpacing,
        decoration: decoration ?? font?.decoration,
        height: lineHeight ?? font?.height,
      );
}
