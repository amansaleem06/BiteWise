import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
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

    return ListTile(
      leading: rank != null
          ? SizedBox(
              width: 56,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(
                      '$rank',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: AppColors.primaryDark),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _logo(theme),
                ],
              ),
            )
          : _logo(theme),
      title: Text(restaurant.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          if (rating != null) ...[
            const Icon(Icons.star_rounded, size: 14, color: AppColors.ratingStar),
            Text(
              ' ${rating.toStringAsFixed(1)} · ',
              style: theme.textTheme.bodySmall,
            ),
          ],
          Flexible(
            child: Text(
              [
                if (restaurant.city != null) restaurant.city!,
                '${Formatters.compactCount(restaurant.followerCount)} followers',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
      onTap: () => context.push(Routes.restaurantPath(restaurant.id)),
    );
  }

  Widget _logo(ThemeData theme) => CircleAvatar(
        backgroundColor: AppColors.primaryLight,
        backgroundImage: restaurant.logoUrl != null
            ? CachedNetworkImageProvider(restaurant.logoUrl!)
            : null,
        child: restaurant.logoUrl == null
            ? const Icon(
                Icons.storefront_outlined,
                color: AppColors.primaryDark,
              )
            : null,
      );
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
        '${Formatters.compactCount(user.followerCount)} followers',
        style: theme.textTheme.bodySmall,
      ),
      onTap: () => context.push(Routes.userPath(user.uid)),
    );
  }
}
