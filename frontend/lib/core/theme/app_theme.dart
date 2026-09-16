import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Estética "Pitch Velocity": oscura, técnica, deportiva. Verde eléctrico
/// como color principal, cian como acento secundario, carmesí para plazas
/// bloqueadas/alertas, blanco para información principal, gris azulado
/// para información secundaria.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF080B0E);
  static const Color surface = Color(0xFF121820);
  static const Color surfaceElevated = Color(0xFF1B2430);
  static const Color primaryGreen = Color(0xFF10FFA0);
  static const Color dangerRed = Color(0xFFFF3366);
  static const Color textPrimary = Color(0xFFF3F4F6);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color divider = Color(0x14FFFFFF);
  // Used only for the CLAUSE/AGREED/PENDING movement-type indicators
  // (🟢/🔵/🟡) in the history — everything else keeps the palette above.
  static const Color infoBlue = Color(0xFF00E5FF);
  static const Color pendingYellow = Color(0xFFEAB308);
}

/// Estilos de texto reutilizables del sistema de diseño: titulares en
/// Space Grotesk, cuerpo en Hanken Grotesk, cifras/timers en JetBrains
/// Mono (evita el "jitter" visual de dígitos que cambian de ancho).
class AppTextStyles {
  AppTextStyles._();

  static TextStyle headline({double? fontSize, FontWeight? fontWeight, Color? color}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: fontSize,
        fontWeight: fontWeight ?? FontWeight.w700,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle body({double? fontSize, FontWeight? fontWeight, Color? color}) =>
      GoogleFonts.hankenGrotesk(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle mono({double? fontSize, FontWeight? fontWeight, Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: fontSize,
        fontWeight: fontWeight ?? FontWeight.w500,
        color: color ?? AppColors.textPrimary,
      );
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryGreen,
        secondary: AppColors.infoBlue,
        surface: AppColors.surface,
        error: AppColors.dangerRed,
        onPrimary: Colors.black,
        onSurface: AppColors.textPrimary,
      ),
      fontFamily: GoogleFonts.hankenGrotesk().fontFamily,
    );

    final headlineTextStyle = GoogleFonts.spaceGrotesk(
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
        titleTextStyle: headlineTextStyle.copyWith(fontSize: 20),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.divider),
        ),
        margin: EdgeInsets.zero,
      ),
      textTheme: base.textTheme
          .apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          )
          .copyWith(
            displayLarge: headlineTextStyle,
            displayMedium: headlineTextStyle,
            displaySmall: headlineTextStyle,
            headlineLarge: headlineTextStyle,
            headlineMedium: headlineTextStyle,
            headlineSmall: headlineTextStyle.copyWith(fontWeight: FontWeight.w600),
            titleLarge: headlineTextStyle.copyWith(fontWeight: FontWeight.w600),
            titleMedium: headlineTextStyle.copyWith(fontWeight: FontWeight.w600),
            titleSmall: headlineTextStyle.copyWith(fontWeight: FontWeight.w600),
          ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.black,
          disabledBackgroundColor: AppColors.divider,
          disabledForegroundColor: AppColors.textSecondary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 6,
          shadowColor: AppColors.primaryGreen.withOpacity(0.35),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: headlineTextStyle.copyWith(fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.divider),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: headlineTextStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primaryGreen),
        ),
        labelStyle: GoogleFonts.hankenGrotesk(color: AppColors.textSecondary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primaryGreen,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
      ),
      dividerTheme:
          const DividerThemeData(color: AppColors.divider, thickness: 1),
    );
  }
}
