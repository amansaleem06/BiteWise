import 'package:flutter/material.dart';

/// TasteWise brand palette from the editorial redesign:
/// deep maroon, warm cream paper, lime call-to-action.
abstract final class AppColors {
  // Brand
  static const Color primary = Color(0xFF4A0E0E);
  static const Color primaryDark = Color(0xFF2F0808);
  static const Color primaryLight = Color(0xFFF3E4D4);

  static const Color secondary = Color(0xFF2A1A18);
  static const Color secondaryLight = Color(0xFFEDE4D8);

  static const Color accent = Color(0xFFC6D92D);
  static const Color accentDark = Color(0xFF8FA31A);
  static const Color accentLight = Color(0xFFF4F8C8);
  static const Color onAccent = Color(0xFF2F0808);

  // Neutrals
  static const Color cream = Color(0xFFFDF8F1);
  static const Color charcoal = Color(0xFF1A0C0C);
  static const Color charcoalLight = Color(0xFF2A1616);

  // Surfaces — light
  static const Color surfaceLight = Color(0xFFFFFBF6);
  static const Color backgroundLight = Color(0xFFFDF8F1);
  static const Color outlineLight = Color(0xFFE2D5C6);
  static const Color feedWash = Color(0x334A0E0E);
  static const Color feedAccentSoft = Color(0xFFF4F8C8);

  // Surfaces — dark
  static const Color surfaceDark = Color(0xFF2A1616);
  static const Color backgroundDark = Color(0xFF140A0A);
  static const Color outlineDark = Color(0xFF4A3330);

  // Text
  static const Color textPrimaryLight = Color(0xFF1A0C0C);
  static const Color textSecondaryLight = Color(0xFF6B5752);
  static const Color textPrimaryDark = Color(0xFFFDF8F1);
  static const Color textSecondaryDark = Color(0xFFC9B8B0);

  // Semantic
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF15803D);
  static const Color ratingStar = Color(0xFFEAB308);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF5C1616), Color(0xFF3A0A0A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient authBackground = LinearGradient(
    colors: [Color(0xFFFDF8F1), Color(0xFFF6EDE4), Color(0xFFEEE4D4)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient stageBackground(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1C0F0F), Color(0xFF140A0A), Color(0xFF1A1010)],
      );
    }
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFDF8F1), Color(0xFFF7F0E6), Color(0xFFF0E6D8)],
    );
  }
}
