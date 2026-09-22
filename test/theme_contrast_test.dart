import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitewise/app/theme/app_colors.dart';
import 'package:bitewise/app/theme/app_theme.dart';

double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (first > second ? first + 0.05 : second + 0.05) /
      (first > second ? second + 0.05 : first + 0.05);
}

void main() {
  test('primary and secondary copy remains readable in both themes', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final scheme = theme.colorScheme;
      expect(_contrast(scheme.onSurface, scheme.surface),
          greaterThanOrEqualTo(4.5));
      expect(_contrast(scheme.onSurfaceVariant, scheme.surface),
          greaterThanOrEqualTo(4.5));
      expect(_contrast(scheme.onSurfaceVariant, scheme.surfaceContainerHighest),
          greaterThanOrEqualTo(4.5));
      expect(_contrast(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(4.5));
      expect(
          _contrast(scheme.error, scheme.surface), greaterThanOrEqualTo(4.5));
    }
  });

  test('passport and reservation labels retain normal-text contrast', () {
    expect(_contrast(AppColors.accent, AppColors.surfaceDark),
        greaterThanOrEqualTo(4.5));
    expect(_contrast(AppColors.accentDark, AppColors.accentLight),
        greaterThanOrEqualTo(4.5));
    expect(_contrast(AppColors.warningTextDark, AppColors.warningSurfaceDark),
        greaterThanOrEqualTo(4.5));
    expect(_contrast(AppColors.warningTextLight, AppColors.warningSurfaceLight),
        greaterThanOrEqualTo(4.5));
    expect(_contrast(AppColors.successTextDark, AppColors.successSurfaceDark),
        greaterThanOrEqualTo(4.5));
    expect(_contrast(AppColors.successTextLight, AppColors.successSurfaceLight),
        greaterThanOrEqualTo(4.5));
  });
}
