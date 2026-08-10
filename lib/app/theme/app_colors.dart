import 'package:flutter/material.dart';

/// BiteWise brand palette.
///
/// Primary: Warm Orange · Secondary: Deep Terracotta · Accent: Fresh Green
/// Neutral: Cream · Dark: Charcoal
abstract final class AppColors {
  // Brand
  static const Color primary = Color(0xFFF97316); // Warm Orange
  static const Color primaryDark = Color(0xFFEA580C);
  static const Color primaryLight = Color(0xFFFFEDD5);

  static const Color secondary = Color(0xFFC2410C); // Deep Terracotta
  static const Color secondaryLight = Color(0xFFFFE8DE);

  static const Color accent = Color(0xFF16A34A); // Fresh Green
  static const Color accentLight = Color(0xFFDCFCE7);

  // Neutrals
  static const Color cream = Color(0xFFFDF8F3);
  static const Color charcoal = Color(0xFF1C1917);
  static const Color charcoalLight = Color(0xFF292524);

  // Surfaces — light
  static const Color surfaceLight = Colors.white;
  static const Color backgroundLight = cream;
  static const Color outlineLight = Color(0xFFE7E0D8);

  // Surfaces — dark
  static const Color surfaceDark = charcoalLight;
  static const Color backgroundDark = charcoal;
  static const Color outlineDark = Color(0xFF44403C);

  // Text
  static const Color textPrimaryLight = Color(0xFF1C1917);
  static const Color textSecondaryLight = Color(0xFF78716C);
  static const Color textPrimaryDark = Color(0xFFFAFAF9);
  static const Color textSecondaryDark = Color(0xFFA8A29E);

  // Semantic
  static const Color error = Color(0xFFDC2626);
  static const Color success = accent;
  static const Color ratingStar = Color(0xFFFBBF24);

  // Gradients (use sparingly)
  static const LinearGradient brandGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
