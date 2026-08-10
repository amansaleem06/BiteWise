import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';

/// BiteWise logo mark used on auth screens and empty states.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64, this.showWordmark = true});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
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
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.restaurant_rounded,
            color: Colors.white,
            size: size * 0.5,
          ),
        ),
        if (showWordmark) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            AppStrings.appName,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ],
      ],
    );
  }
}
