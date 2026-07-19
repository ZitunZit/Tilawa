import 'package:flutter/material.dart';

/// Identité visuelle Tilawa : noir profond + doré, sobre et élégante.
class AppColors {
  AppColors._();

  static const Color black = Color(0xFF0B0B0D);
  static const Color surface = Color(0xFF16161A);
  static const Color surfaceHigh = Color(0xFF1F1F26);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldSoft = Color(0xFFE8C86A);
  static const Color goldDim = Color(0xFF8A7220);
  static const Color textPrimary = Color(0xFFF4EFE0);
  static const Color textMuted = Color(0xFF9A968A);
  static const Color danger = Color(0xFFC0453B);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    const gold = AppColors.gold;
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.black,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        secondary: AppColors.goldSoft,
        surface: AppColors.surface,
        onPrimary: AppColors.black,
        onSurface: AppColors.textPrimary,
        error: AppColors.danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.gold,
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.goldDim, width: 0.5),
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      iconTheme: const IconThemeData(color: AppColors.gold),
      dividerColor: AppColors.goldDim.withValues(alpha: 0.3),
    );
  }
}
