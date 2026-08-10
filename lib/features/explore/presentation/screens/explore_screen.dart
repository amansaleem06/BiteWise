import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../feed/domain/entities/post.dart';
import '../providers/explore_providers.dart';
import '../widgets/nearby_map_tab.dart';
import '../widgets/result_tiles.dart';

/// Explore: search entry + Trending / Top Rated / Map.
class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.navExplore),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(104),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: GestureDetector(
                    onTap: () => context.push(Routes.search),
                    child: AbsorbPointer(
                      child: TextField(
                        enabled: false,
                        decoration: InputDecoration(
                          hintText: 'Search restaurants, people, #tags…',
                          prefixIcon: const Icon(Icons.search_rounded),
                          isDense: true,
                          fillColor: theme.colorScheme.surface,
                        ),
                      ),
                    ),
                  ),
                ),
                TabBar(
                  labelStyle: theme.textTheme.titleSmall,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerHeight: 0.5,
                  dividerColor: theme.colorScheme.outline,
                  tabs: const [
                    Tab(text: 'Trending'),
                    Tab(text: 'Top Rated'),
                    Tab(text: 'Nearby'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: const TabBarView(
          children: [_TrendingTab(), _TopRatedTab(), NearbyMapTab()],
        ),
      ),
    );
  }
}

class _TrendingTab extends ConsumerWidget {
  const _TrendingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingAsync = ref.watch(trendingPostsProvider);

    return trendingAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      error: (_, __) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(trendingPostsProvider),
          child: const Text(AppStrings.retry),
        ),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Text(
              'Nothing trending yet — start posting!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          );
        }
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.invalidate(trendingPostsProvider),
          child: GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: posts.length,
            itemBuilder: (context, i) => _TrendingTile(post: posts[i]),
          ),
        );
      },
    );
  }
}

class _TrendingTile extends StatelessWidget {
  const _TrendingTile({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final media = post.media.isNotEmpty ? post.media.first : null;
    return GestureDetector(
      onTap: () => context.push(Routes.postPath(post.id)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (media != null)
            CachedNetworkImage(
              imageUrl: media.type == MediaType.video
                  ? (media.thumbnailUrl ?? media.url)
                  : media.url,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: AppColors.primaryLight.withValues(alpha: 0.3),
              ),
            )
          else
            const ColoredBox(color: AppColors.primaryLight),
          if (post.likeCount > 0)
            Positioned(
              bottom: 4,
              left: 6,
              child: Row(
                children: [
                  const Icon(
                    Icons.favorite_rounded,
                    size: 13,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${post.likeCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TopRatedTab extends ConsumerWidget {
  const _TopRatedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topRatedAsync = ref.watch(topRatedRestaurantsProvider);

    return topRatedAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      error: (_, __) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(topRatedRestaurantsProvider),
          child: const Text(AppStrings.retry),
        ),
      ),
      data: (restaurants) {
        if (restaurants.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'No rated restaurants yet.\nRate a dish when you post!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          );
        }
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.invalidate(topRatedRestaurantsProvider),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: restaurants.length,
            itemBuilder: (context, i) =>
                RestaurantTile(restaurant: restaurants[i], rank: i + 1),
          ),
        );
      },
    );
  }
}

