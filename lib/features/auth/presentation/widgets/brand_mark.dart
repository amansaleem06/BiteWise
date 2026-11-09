import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';

/// TasteBump logo mark used on auth screens and empty states.
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
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Image.asset(AppStrings.brandLogo),
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
