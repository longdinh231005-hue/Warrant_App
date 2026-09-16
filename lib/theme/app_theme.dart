import 'package:flutter/material.dart';

/// WarrantSafe Design Tokens & Theme
class AppColors {
  AppColors._();

  // ── Primary palette ──────────────────────────────────────────────
  static const Color primaryBlue = Color(0xFF1A8FE3);
  static const Color primaryDark = Color(0xFF0D1B2A);
  static const Color primaryLight = Color(0xFFE8F4FD);

  // ── Neutral palette ──────────────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF7F8FA);
  static const Color cardGrey = Color(0xFFF2F3F5);
  static const Color inputFill = Color(0xFFF5F6F8);
  static const Color border = Color(0xFFE0E3E8);
  static const Color divider = Color(0xFFE8EAED);

  // ── Text palette ─────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0D1B2A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textLabel = Color(0xFF5A6270);

  // ── Accent / semantic ────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color logout = Color(0xFFDC2626);
  static const Color google = Color(0xFF4285F4);

  // ── Avatar ───────────────────────────────────────────────────────
  static const Color avatarBg = Color(0xFF1A8FE3);
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryBlue,
        primary: AppColors.primaryBlue,
        onPrimary: AppColors.white,
        surface: AppColors.white,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        brightness: Brightness.light,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: AppColors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(double.infinity, 56),
          side: const BorderSide(color: AppColors.border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.primaryBlue,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: const TextStyle(
          color: AppColors.textHint,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          color: AppColors.textLabel,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),
    );
  }
}
