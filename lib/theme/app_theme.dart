import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WildPathColors {
  static const pine = Color(0xFF17351E);
  static const forest = Color(0xFF285231);
  static const moss = Color(0xFF4E7B49);
  static const sage = Color(0xFF7DA567);
  static const fern = Color(0xFFBAD98E);
  static const mist = Color(0xFFDDECD4);
  static const cream = Color(0xFFF8F3E7);
  static const white = Color(0xFFffffff);
  static const amber = Color(0xFFD79931);
  static const ember = Color(0xFFE66B33);
  static const smoke = Color(0xFF708271);
  static const stone = Color(0xFFCCBFA8);
  static const red = Color(0xFFdc5555);
  static const blue = Color(0xFF5599cc);
}

class WildPathTheme {
  static ThemeData get theme => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: WildPathColors.forest,
          primary: WildPathColors.forest,
          secondary: WildPathColors.amber,
        ),
        scaffoldBackgroundColor: WildPathColors.cream,
        textTheme: GoogleFonts.plusJakartaSansTextTheme().apply(
          bodyColor: WildPathColors.pine,
          displayColor: WildPathColors.pine,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: WildPathColors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: WildPathColors.mist, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: WildPathColors.amber, width: 1.8),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: WildPathColors.forest,
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                WildPathColors.smoke.withValues(alpha: 0.32),
            disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: const BorderSide(color: WildPathColors.pine, width: 1),
            minimumSize: const Size(double.infinity, 50),
            elevation: 2,
            shadowColor: WildPathColors.pine.withValues(alpha: 0.18),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            textStyle: WildPathTypography.body(
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        useMaterial3: true,
      );
}

class WildPathTypography {
  static TextStyle display({
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    Color? color,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) {
    return GoogleFonts.sora(
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
    );
  }

  static TextStyle body({
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    Color? color,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
    );
  }
}
