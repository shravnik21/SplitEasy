import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central color palette -- light mode, pink/white/black: a white canvas,
/// bold near-black text, one pink accent used for selection and primary
/// actions. Green/red are kept only for money in vs. money out.
class AppColors {
  static const background = Color(0xFFFFF6FA);
  static const card = Colors.white;
  static const textPrimary = Color(0xFF1A1418);
  static const textSecondary = Color(0xFF8A6B78);
  static const textMuted = Color(0xFFC79AAE);
  static const divider = Color(0xFFF7E4ED);
  static const accentPink = Color(0xFFE0417B);
  static const accentPinkDark = Color(0xFFC42C64);
  static const accentPinkSoft = Color(0xFFFCE4EE);
  static const accentGreen = Color(0xFF1E9E5A);
  static const accentRed = Color(0xFFDC2626);
  static const avatarBackground = Color(0xFFFCE4EE);
  static const inputFill = Color(0xFFFFFBFD);
  static const inputBorder = Color(0xFFF3D9E5);
}

class AppTheme {
  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: AppColors.accentPink,
      scaffoldBackgroundColor: AppColors.background,
    );

    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: GoogleFonts.manrope(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.accentPink, width: 1.4),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accentPink,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          textStyle: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accentPink,
        foregroundColor: Colors.white,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppColors.accentPink,
          selectedForegroundColor: Colors.white,
          foregroundColor: AppColors.textSecondary,
          side: const BorderSide(color: AppColors.inputBorder),
          textStyle: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}