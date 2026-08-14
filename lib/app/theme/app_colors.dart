import 'package:flutter/material.dart';

/// TasteWise brand palette — charcoal + crimson from the app icon.
abstract final class AppColors {
  // Brand
  static const Color primary = Color(0xFFC33530);
  static const Color primaryDark = Color(0xFF9E2A26);
  static const Color primaryLight = Color(0xFFF6E4E3);

  static const Color secondary = Color(0xFF2A2F35);
  static const Color secondaryLight = Color(0xFFE8EAEC);

  static const Color accent = Color(0xFFB45309);
  static const Color accentLight = Color(0xFFFFF1D6);

  // Neutrals
  static const Color cream = Color(0xFFF7F4F1);
  static const Color charcoal = Color(0xFF1A1D21);
  static const Color charcoalLight = Color(0xFF2A2F35);

  // Surfaces — light
  static const Color surfaceLight = Color(0xFFFFFBFA);
  static const Color backgroundLight = Color(0xFFF0EBE6);
  static const Color outlineLight = Color(0xFFD0C6BE);
  static const Color feedWash = Color(0x33C33530);
  static const Color feedAccentSoft = Color(0xFFFFF0E8);

  // Surfaces — dark (stronger separation for readable contrast)
  static const Color surfaceDark = Color(0xFF242A31);
  static const Color backgroundDark = Color(0xFF12151A);
  static const Color outlineDark = Color(0xFF3E4650);

  // Text
  static const Color textPrimaryLight = Color(0xFF14181D);
  static const Color textSecondaryLight = Color(0xFF5C6570);
  static const Color textPrimaryDark = Color(0xFFF3F5F7);
  static const Color textSecondaryDark = Color(0xFFB0B8C2);

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

  static LinearGradient stageBackground(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1A1214), Color(0xFF12151A), Color(0xFF161B22)],
      );
    }
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFF6EDEA), Color(0xFFF0EBE6), Color(0xFFE8E4DF)],
    );
  }
}
