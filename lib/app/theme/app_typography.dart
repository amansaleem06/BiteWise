import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// TasteWise typography — Fraunces for display, Source Sans 3 for UI.
abstract final class AppTypography {
  static TextTheme textTheme(Color primary, Color secondary) {
    final display = GoogleFonts.fraunces(
      color: primary,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing: -0.4,
    );
    final body = GoogleFonts.sourceSans3(
      color: primary,
      height: 1.45,
    );

    return TextTheme(
      displayLarge: display.copyWith(fontSize: 36, fontWeight: FontWeight.w800),
      headlineLarge: display.copyWith(fontSize: 30),
      headlineMedium: display.copyWith(fontSize: 24),
      titleLarge: display.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
      titleMedium: body.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      titleSmall: body.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
      bodyLarge: body.copyWith(fontSize: 16),
      bodyMedium: body.copyWith(fontSize: 14),
      bodySmall: body.copyWith(fontSize: 12, color: secondary),
      labelLarge: body.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
      labelMedium: body.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: secondary,
      ),
    );
  }
}
