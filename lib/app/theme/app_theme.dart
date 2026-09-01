import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Central Material 3 theme definitions for TasteWise.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final interactiveColor = isDark ? AppColors.accent : AppColors.primary;
    final onInteractiveColor =
        isDark ? AppColors.onAccent : AppColors.cream;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: interactiveColor,
      onPrimary: onInteractiveColor,
      primaryContainer:
          isDark ? AppColors.primaryDark : AppColors.primaryLight,
      onPrimaryContainer: isDark ? Colors.white : AppColors.secondary,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer:
          isDark ? AppColors.charcoalLight : AppColors.secondaryLight,
      onSecondaryContainer:
          isDark ? AppColors.textPrimaryDark : AppColors.secondary,
      tertiary: AppColors.accent,
      onTertiary: AppColors.onAccent,
      tertiaryContainer: isDark ? AppColors.charcoalLight : AppColors.accentLight,
      onTertiaryContainer: AppColors.onAccent,
      error: AppColors.error,
      onError: Colors.white,
      surface: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      onSurface:
          isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      onSurfaceVariant:
          isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      outline: isDark ? AppColors.outlineDark : AppColors.outlineLight,
      outlineVariant: isDark ? AppColors.outlineDark : AppColors.outlineLight,
      shadow: Colors.black26,
      scrim: Colors.black54,
      inverseSurface: isDark ? AppColors.cream : AppColors.charcoal,
      onInverseSurface: isDark ? AppColors.charcoal : AppColors.cream,
      inversePrimary: isDark ? AppColors.primary : AppColors.primaryLight,
      surfaceContainerHighest:
          isDark ? const Color(0xFF2E353D) : AppColors.cream,
    );

    final textTheme = AppTypography.textTheme(
      colorScheme.onSurface,
      colorScheme.onSurfaceVariant,
    );

    final background =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          side: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.55),
            width: 0.5,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          elevation: 0,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor:
              colorScheme.primary.withValues(alpha: 0.4),
          disabledForegroundColor:
              colorScheme.onPrimary.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          textStyle:
              textTheme.labelLarge?.copyWith(color: colorScheme.onPrimary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.9)),
          backgroundColor: colorScheme.surface.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? colorScheme.surface
            : Colors.white.withValues(alpha: 0.92),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md + 2,
        ),
        hintStyle: textTheme.bodyMedium
            ?.copyWith(color: colorScheme.onSurfaceVariant),
        labelStyle: textTheme.bodyMedium
            ?.copyWith(color: colorScheme.onSurfaceVariant),
        prefixIconColor: colorScheme.onSurfaceVariant,
        suffixIconColor: colorScheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.85),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.14),
        height: 68,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 26,
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium!.copyWith(
            fontWeight: FontWeight.w700,
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: AppColors.accent,
        dividerColor: colorScheme.outline.withValues(alpha: 0.4),
        overlayColor: WidgetStatePropertyAll(
          AppColors.accent.withValues(alpha: 0.12),
        ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: AppColors.accent,
        secondarySelectedColor: AppColors.accent,
        backgroundColor: colorScheme.surface,
        checkmarkColor: AppColors.onAccent,
        labelStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.onAccent,
          fontWeight: FontWeight.w800,
        ),
        shape: const StadiumBorder(),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.7)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colorScheme.surface,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        subtitleTextStyle: textTheme.bodySmall,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colorScheme.primary,
        selectionColor: colorScheme.primary.withValues(alpha: 0.28),
        selectionHandleColor: colorScheme.primary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium
            ?.copyWith(color: colorScheme.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dividerTheme:
          DividerThemeData(color: colorScheme.outline, thickness: 0.5),
    );
  }
}
