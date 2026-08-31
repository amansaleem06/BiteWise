import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/error_text.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../feed/presentation/widgets/feed_shimmer.dart';
import '../../../reservations/presentation/widgets/booking_sheet.dart';
import '../../../stories/presentation/screens/story_edit_screen.dart';
import '../../domain/entities/restaurant.dart';
import '../providers/page_identity_provider.dart';
import '../providers/restaurant_providers.dart';
import '../widgets/claim_status_badge.dart';
import '../widgets/page_identity_bar.dart';
import '../widgets/restaurant_mentions_tab.dart';
import '../widgets/restaurant_posts_grid.dart';
import '../widgets/restaurant_ratings_tab.dart';

/// Restaurant profile: cover header, identity, follow, Posts/About tabs.
class RestaurantScreen extends ConsumerWidget {
  const RestaurantScreen({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurantAsync =
        ref.watch(restaurantControllerProvider(restaurantId));

    return Scaffold(
      body: restaurantAsync.when(
        loading: () => const FeedShimmer(itemCount: 2),
        error: (_, __) => _ErrorView(
          onRetry: () =>
              ref.invalidate(restaurantControllerProvider(restaurantId)),
        ),
        data: (restaurant) => _RestaurantBody(
          restaurant: restaurant,
          onToggleFollow: () => ref
              .read(restaurantControllerProvider(restaurantId).notifier)
              .toggleFollow(),
        ),
      ),
    );
  }
}

class _RestaurantBody extends StatelessWidget {
  const _RestaurantBody({
    required this.restaurant,
    required this.onToggleFollow,
  });

  final Restaurant restaurant;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          _CoverAppBar(restaurant: restaurant),
          SliverToBoxAdapter(
            child: _IdentitySection(
              restaurant: restaurant,
              onToggleFollow: onToggleFollow,
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                labelStyle: Theme.of(context).textTheme.titleSmall,
                indicatorSize: TabBarIndicatorSize.label,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'Posts'),
                  Tab(text: 'Mentions'),
                  Tab(text: 'Ratings'),
                  Tab(text: 'About'),
                ],
              ),
              Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
        ],
        body: TabBarView(
          children: [
            RestaurantPostsGrid(restaurantId: restaurant.id),
            RestaurantMentionsTab(restaurant: restaurant),
            RestaurantRatingsTab(restaurantId: restaurant.id),
            _AboutTab(restaurant: restaurant),
          ],
        ),
      ),
    );
  }
}

class _CoverAppBar extends StatelessWidget {
  const _CoverAppBar({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      flexibleSpace: FlexibleSpaceBar(
        background: restaurant.coverUrl != null
            ? CachedNetworkImage(
                imageUrl: restaurant.coverUrl!,
                fit: BoxFit.cover,
              )
            : Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.brandGradient,
                ),
                child: const Center(
                  child: Icon(
                    Icons.restaurant_rounded,
                    size: 56,
                    color: Colors.white54,
                  ),
                ),
              ),
      ),
    );
  }
}

class _IdentitySection extends ConsumerWidget {
  const _IdentitySection({
    required this.restaurant,
    required this.onToggleFollow,
  });

  final Restaurant restaurant;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rating = restaurant.averageRating;
    final me = ref.watch(currentUserProvider);
    final canClaim = me != null &&
        me.isBusiness &&
        restaurant.isUnclaimed &&
        (me.ownedRestaurantId == null || me.ownedRestaurantId!.isEmpty);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: restaurant.logoUrl != null
                    ? CachedNetworkImageProvider(restaurant.logoUrl!)
                    : null,
                child: restaurant.logoUrl == null
                    ? const Icon(
                        Icons.storefront_rounded,
                        size: 30,
                        color: AppColors.primaryDark,
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(restaurant.name,
                        style: theme.textTheme.headlineMedium,),
                    const SizedBox(height: AppSpacing.xxs),
                    ClaimStatusBadge(restaurant: restaurant),
                    if (restaurant.city != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(restaurant.city!, style: theme.textTheme.bodySmall),
                    ],
                    const SizedBox(height: AppSpacing.xxs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xxs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (rating != null) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: AppColors.ratingStar,
                          ),
                          Text(
                            '${rating.toStringAsFixed(1)} '
                            '(${Formatters.compactCount(restaurant.ratingCount)})',
                            style: theme.textTheme.titleSmall,
                          ),
                        ],
                        if (restaurant.priceLevelDisplay != null)
                          Text(
                            restaurant.priceLevelDisplay!,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: AppColors.accent,
                            ),
                          ),
                        Text(
                          '${Formatters.compactCount(restaurant.followerCount)} followers',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (restaurant.cuisines.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final cuisine in restaurant.cuisines.take(4))
                  Chip(
                    label: Text(cuisine),
                    labelStyle: theme.textTheme.labelMedium,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (me != null && restaurant.ownerId == me.uid) ...[
            const PageIdentityBar(),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      ref
                          .read(pageIdentityProvider.notifier)
                          .setPreferPersonal(false);
                      context.go(Routes.create);
                    },
                    icon: const Icon(Icons.campaign_outlined, size: 18),
                    label: const Text('Post'),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                OutlinedButton(
                  onPressed: () async {
                    final image = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 90,
                    );
                    if (image == null || !context.mounted) return;
                    await context.push(
                      Routes.storyEdit,
                      extra: StoryEditArgs(image),
                    );
                  },
                  child: const Icon(Icons.auto_awesome_outlined),
                ),
                const SizedBox(width: AppSpacing.xs),
                OutlinedButton(
                  onPressed: () => context.push(
                    Routes.restaurantEditPath(restaurant.id),
                  ),
                  child: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (canClaim) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  try {
                    await ref
                        .read(restaurantRepositoryProvider)
                        .claimRestaurant(restaurant.id);
                    ref.invalidate(authStateProvider);
                    ref.invalidate(
                      restaurantControllerProvider(restaurant.id),
                    );
                    if (!context.mounted) return;
                    AppSnackbar.success(
                      context,
                      'This is now your restaurant page. You post as ${restaurant.name}.',
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    AppSnackbar.error(context, userMessageFrom(e));
                  }
                },
                icon: const Icon(Icons.storefront_rounded),
                label: const Text('This is my restaurant'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              Expanded(
                child: restaurant.isFollowedByMe
                    ? OutlinedButton(
                        onPressed: onToggleFollow,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                        child: const Text('Following'),
                      )
                    : FilledButton(
                        onPressed: onToggleFollow,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                        child: const Text('Follow'),
                      ),
              ),
              const SizedBox(width: AppSpacing.xs),
              OutlinedButton(
                onPressed: () => BookingSheet.show(context, restaurant),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                ),
                child: const Text('Reserve'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.restaurant});

  final Restaurant restaurant;

  static const _days = [
    ('mon', 'Monday'),
    ('tue', 'Tuesday'),
    ('wed', 'Wednesday'),
    ('thu', 'Thursday'),
    ('fri', 'Friday'),
    ('sat', 'Saturday'),
    ('sun', 'Sunday'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAnyInfo = restaurant.description != null ||
        restaurant.menuNotes != null ||
        restaurant.address != null ||
        restaurant.phone != null ||
        restaurant.website != null ||
        restaurant.openingHours.isNotEmpty;

    if (!hasAnyInfo) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.storefront_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.md),
              Text('No details yet', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                restaurant.isClaimed
                    ? 'This restaurant hasn\'t added details yet.'
                    : restaurant.isPendingClaim
                        ? 'This listing is claimed. Ratings already on this page stay here.'
                        : 'Unclaimed Maps listing — ratings here are from TasteWise diners, with no verified owner. Are you the owner? Claim it from your business profile.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (restaurant.menuNotes != null &&
            restaurant.menuNotes!.trim().isNotEmpty) ...[
          Text('Menu & specials', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(restaurant.menuNotes!, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (restaurant.description != null) ...[
          Text('About', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(restaurant.description!, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (restaurant.address != null)
          _InfoRow(icon: Icons.place_outlined, text: restaurant.address!),
        if (restaurant.phone != null)
          _InfoRow(icon: Icons.phone_outlined, text: restaurant.phone!),
        if (restaurant.website != null)
          _InfoRow(icon: Icons.language_rounded, text: restaurant.website!),
        if (restaurant.openingHours.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Opening hours', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          for (final (key, label) in _days)
            if (restaurant.openingHours[key] != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(label, style: theme.textTheme.bodyMedium),
                    ),
                    Text(
                      restaurant.openingHours[key]!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryDark),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate(this.tabBar, this.background);

  final TabBar tabBar;
  final Color background;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) =>
      ColoredBox(color: background, child: tabBar);

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar;
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: BackButton(onPressed: () => Navigator.of(context).pop()),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Couldn\'t load this restaurant',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: onRetry,
                    child: const Text(AppStrings.retry),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
