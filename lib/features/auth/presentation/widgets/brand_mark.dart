import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';

/// TasteWise logo mark used on auth screens and empty states.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64, this.showWordmark = true});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.location_on_rounded,
                color: Colors.white.withValues(alpha: 0.95),
                size: size * 0.62,
              ),
              Padding(
                padding: EdgeInsets.only(bottom: size * 0.08),
                child: Icon(
                  Icons.restaurant_rounded,
                  color: AppColors.primaryDark,
                  size: size * 0.22,
                ),
              ),
            ],
          ),
        ),
        if (showWordmark) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            AppStrings.appName,
            style: theme.textTheme.headlineMedium?.copyWith(
              letterSpacing: -0.6,
            ),
          ),
        ],
      ],
    );
  }
}
