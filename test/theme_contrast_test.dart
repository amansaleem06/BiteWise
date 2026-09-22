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

void _expectContrast(Color foreground, Color background) {
  expect(
    _contrast(foreground, background),
    greaterThanOrEqualTo(4.5),
  );
}

void main() {
  test('primary and secondary copy remains readable in both themes', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final scheme = theme.colorScheme;
      _expectContrast(scheme.onSurface, scheme.surface);
      _expectContrast(scheme.onSurfaceVariant, scheme.surface);
      _expectContrast(
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHighest,
      );
      _expectContrast(scheme.onPrimary, scheme.primary);
      _expectContrast(scheme.error, scheme.surface);
    }
  });

  test('passport and reservation labels retain normal-text contrast', () {
    _expectContrast(AppColors.accent, AppColors.surfaceDark);
    _expectContrast(AppColors.accentDark, AppColors.accentLight);
    _expectContrast(AppColors.warningTextDark, AppColors.warningSurfaceDark);
    _expectContrast(AppColors.warningTextLight, AppColors.warningSurfaceLight);
    _expectContrast(AppColors.successTextDark, AppColors.successSurfaceDark);
    _expectContrast(AppColors.successTextLight, AppColors.successSurfaceLight);
  });
}
