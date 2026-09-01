import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../restaurants/domain/entities/restaurant.dart';
import '../../../restaurants/presentation/widgets/claim_status_badge.dart';

/// Promotes the owner's restaurant at the top of their personal profile.
class OwnedRestaurantBanner extends StatelessWidget {
  const OwnedRestaurantBanner({super.key, required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rating = restaurant.averageRating;
    final image = restaurant.coverUrl ?? restaurant.logoUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(Routes.restaurantPath(restaurant.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 140,
                child: image != null
                    ? CachedNetworkImage(imageUrl: image, fit: BoxFit.cover)
                    : const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppColors.brandGradient,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.restaurant_rounded,
                            color: Colors.white70,
                            size: 42,
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClaimStatusBadge(restaurant: restaurant),
                    const SizedBox(height: 8),
                    Text(
                      restaurant.name,
                      style: GoogleFonts.fraunces(
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (rating != null) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: AppColors.ratingStar,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            '  ·  ${restaurant.ratingCount} ratings',
                            style: theme.textTheme.bodySmall,
                          ),
                        ] else
                          Text(
                            'No ratings yet',
                            style: theme.textTheme.bodySmall,
                          ),
                        const Spacer(),
                        Text(
                          'Open table',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
