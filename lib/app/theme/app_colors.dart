import 'package:flutter/material.dart';

/// TasteWise brand palette — charcoal + crimson from the app icon.
abstract final class AppColors {
  // Brand
  static const Color primary = Color(0xFFC33530); // Taste crimson
  static const Color primaryDark = Color(0xFF9E2A26);
  static const Color primaryLight = Color(0xFFF6E4E3);

  static const Color secondary = Color(0xFF2A2F35); // Icon charcoal
  static const Color secondaryLight = Color(0xFFE8EAEC);

  static const Color accent = Color(0xFFB45309); // Warm amber for ratings/food
  static const Color accentLight = Color(0xFFFFF1D6);

  // Neutrals
  static const Color cream = Color(0xFFF7F4F1);
  static const Color charcoal = Color(0xFF1A1D21);
  static const Color charcoalLight = Color(0xFF2A2F35);

  // Surfaces — light (warmer feed canvas)
  static const Color surfaceLight = Color(0xFFFFFBFA);
  static const Color backgroundLight = Color(0xFFF3EEE9);
  static const Color outlineLight = Color(0xFFD9CFC8);
  static const Color feedWash = Color(0x33C33530);
  static const Color feedAccentSoft = Color(0xFFFFF0E8);

  // Surfaces — dark
  static const Color surfaceDark = charcoalLight;
  static const Color backgroundDark = charcoal;
  static const Color outlineDark = Color(0xFF3F454C);

  // Text
  static const Color textPrimaryLight = Color(0xFF1A1D21);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFFA1A8B3);

  // Semantic
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF15803D);
  static const Color ratingStar = Color(0xFFEAB308);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFFD64540), Color(0xFF8F2420)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient authBackground = LinearGradient(
    colors: [Color(0xFFF7F4F1), Color(0xFFF0E6E4), Color(0xFFE8EEF2)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
