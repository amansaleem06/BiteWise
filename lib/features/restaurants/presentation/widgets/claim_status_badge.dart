import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/restaurant.dart';

/// Visible trust signal: verified owner vs unclaimed Maps listing.
class ClaimStatusBadge extends StatelessWidget {
  const ClaimStatusBadge({super.key, required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    late final String label;
    late final IconData icon;
    late final Color bg;
    late final Color fg;

    if (restaurant.isClaimed) {
      label = 'Verified Owner';
      icon = Icons.verified_rounded;
      bg = AppColors.accent;
      fg = AppColors.onAccent;
    } else if (restaurant.isPendingClaim) {
      label = 'Claim pending review';
      icon = Icons.hourglass_top_rounded;
      bg = AppColors.primaryLight;
      fg = AppColors.primary;
    } else {
      label = 'Unclaimed listing';
      icon = Icons.public_outlined;
      bg = theme.colorScheme.surfaceContainerHighest;
      fg = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
