import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// Small label that marks an account as a person or a restaurant page.
class IdentityBadge extends StatelessWidget {
  const IdentityBadge({
    super.key,
    required this.label,
    this.icon,
    this.emphasized = false,
  });

  final String label;
  final IconData? icon;
  final bool emphasized;

  /// Foodie / normal signed-in account.
  factory IdentityBadge.member() => const IdentityBadge(
        label: 'Member',
        icon: Icons.person_outline_rounded,
      );

  /// Business place page (not a personal account).
  factory IdentityBadge.restaurant({bool claimed = false}) => IdentityBadge(
        label: claimed ? 'Restaurant · Claimed' : 'Restaurant',
        icon: Icons.storefront_rounded,
        emphasized: claimed,
      );

  /// Personal account that owns a claimed restaurant.
  factory IdentityBadge.restaurantOwner() => const IdentityBadge(
        label: 'Restaurant owner',
        icon: Icons.badge_outlined,
        emphasized: true,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = emphasized
        ? AppColors.primary.withValues(alpha: 0.14)
        : theme.colorScheme.surfaceContainerHighest;
    final fg = emphasized
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: emphasized
            ? AppColors.primary.withValues(alpha: 0.12)
            : bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
