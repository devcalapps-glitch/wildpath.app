import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WildPathColors {
  static const pine = Color(0xFF1a2e1a);
  static const forest = Color(0xFF2d4a2d);
  static const moss = Color(0xFF4a6741);
  static const sage = Color(0xFF7a9e6e);
  static const fern = Color(0xFFa8c49a);
  static const mist = Color(0xFFd4e8cc);
  static const cream = Color(0xFFf5f0e8);
  static const white = Color(0xFFffffff);
  static const amber = Color(0xFFc4842a);
  static const ember = Color(0xFFe8612a);
  static const smoke = Color(0xFF8a9985);
  static const stone = Color(0xFFc8c0b0);
  static const red = Color(0xFFdc5555);
  static const blue = Color(0xFF5599cc);
}

class WildPathTheme {
  static ThemeData get theme => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: WildPathColors.forest,
          primary: WildPathColors.forest,
          secondary: WildPathColors.moss,
        ),
        scaffoldBackgroundColor: WildPathColors.cream,
        textTheme: GoogleFonts.plusJakartaSansTextTheme().apply(
          bodyColor: WildPathColors.pine,
          displayColor: WildPathColors.pine,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: WildPathColors.cream,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.transparent, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: WildPathColors.moss, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: WildPathColors.forest,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            minimumSize: const Size(double.infinity, 48),
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
