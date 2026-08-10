import 'package:flutter/material.dart';

/// Typography scale built on the system font stack for a clean, premium feel.
///
/// If a custom brand font is added later (e.g. via google_fonts), only this
/// file needs to change.
abstract final class AppTypography {
  static TextTheme textTheme(Color primary, Color secondary) => TextTheme(
        displayLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: primary,
        ),
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: primary,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: primary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: primary),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: primary),
        bodySmall: TextStyle(fontSize: 12, height: 1.4, color: secondary),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        labelMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: secondary,
        ),
      );
}
