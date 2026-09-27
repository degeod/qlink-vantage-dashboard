import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const charcoal = Color(0xFF12151A);
  static const charcoalElevated = Color(0xFF1B2129);
  static const ink = Color(0xFFE8E2D6);
  static const muted = Color(0xFF9AA3AD);
  static const amber = Color(0xFFE0A14A);
  static const amberSoft = Color(0x33E0A14A);
  static const danger = Color(0xFFD96B5B);
  static const ok = Color(0xFF6FBF8B);
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.charcoal,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.charcoalElevated,
        primary: AppColors.amber,
        onPrimary: Color(0xFF1A1208),
        secondary: AppColors.ink,
        error: AppColors.danger,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.sourceSans3TextTheme(base.textTheme).apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ).copyWith(
        displaySmall: GoogleFonts.fraunces(
          fontSize: 34,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
          height: 1.1,
        ),
        headlineMedium: GoogleFonts.fraunces(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        titleLarge: GoogleFonts.fraunces(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.charcoalElevated,
        indicatorColor: AppColors.amberSoft,
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.sourceSans3(fontSize: 12, color: AppColors.muted),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.amber,
        thumbColor: AppColors.amber,
        inactiveTrackColor: Color(0x33E8E2D6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.amber,
          foregroundColor: const Color(0xFF1A1208),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.sourceSans3(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }
}
