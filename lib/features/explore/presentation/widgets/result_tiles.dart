import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../restaurants/domain/entities/restaurant.dart';

/// Restaurant row used in search results and Top Rated.
class RestaurantTile extends StatelessWidget {
  const RestaurantTile({super.key, required this.restaurant, this.rank});

  final Restaurant restaurant;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rating = restaurant.averageRating;
    final image = restaurant.coverUrl ?? restaurant.logoUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Material(
        color: theme.colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(Routes.restaurantPath(restaurant.id)),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: image != null
                        ? CachedNetworkImage(imageUrl: image, fit: BoxFit.cover)
                        : const ColoredBox(
                            color: AppColors.primaryLight,
                            child: Icon(
                              Icons.storefront_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (rank != null)
                        Text(
                          'No. $rank',
                          style: GoogleFonts.sourceSans3(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accentDark,
                          ),
                        ),
                      Text(
                        restaurant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.fraunces(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (rating != null) ...[
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: AppColors.ratingStar,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              rating.toStringAsFixed(1),
                              style: theme.textTheme.labelLarge,
                            ),
                            Text(
                              '  ·  ',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                          Flexible(
                            child: Text(
                              [
                                if (restaurant.city != null) restaurant.city!,
                                if (restaurant.isClaimed) 'Verified',
                                '${Formatters.compactCount(restaurant.followerCount)} followers',
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
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
      ),
    );
  }
}

/// User row used in search results.
class UserTile extends StatelessWidget {
  const UserTile({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryLight,
        backgroundImage: user.photoUrl != null
            ? CachedNetworkImageProvider(user.photoUrl!)
            : null,
        child: user.photoUrl == null
            ? Text(
                user.displayName.isNotEmpty
                    ? user.displayName[0].toUpperCase()
                    : '?',
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: AppColors.primaryDark),
              )
            : null,
      ),
      title: Text(user.displayName),
      subtitle: Text(
        [
          user.role == UserRole.restaurantOwner ? 'Restaurant owner' : 'Member',
          if (user.username != null && user.username!.isNotEmpty)
            '@${user.username}',
          '${Formatters.compactCount(user.followerCount)} followers',
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      onTap: () => context.push(Routes.userPath(user.uid)),
    );
  }
}
