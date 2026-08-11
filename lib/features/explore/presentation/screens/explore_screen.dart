import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/cuisines.dart';
import '../../../../core/widgets/async_error_view.dart';
import '../../../feed/domain/entities/post.dart';
import '../providers/explore_providers.dart';
import '../widgets/nearby_map_tab.dart';
import '../widgets/result_tiles.dart';

/// Explore: search entry + Trending / Top Rated / Map.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String? _cuisineFilter;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nearbyActive = _tabs.index == 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.navExplore),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(nearbyActive ? 104 : 152),
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
              if (!nearbyActive)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: _cuisineFilter == null,
                          onSelected: (_) =>
                              setState(() => _cuisineFilter = null),
                        ),
                        for (final cuisine in Cuisines.all.take(3))
                          Padding(
                            padding:
                                const EdgeInsets.only(left: AppSpacing.xs),
                            child: FilterChip(
                              label: Text(cuisine),
                              selected: _cuisineFilter == cuisine,
                              onSelected: (_) => setState(
                                () => _cuisineFilter =
                                    _cuisineFilter == cuisine ? null : cuisine,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.xs),
                          child: ActionChip(
                            label: const Text('See more'),
                            onPressed: () {
                              showModalBottomSheet<void>(
                                context: context,
                                showDragHandle: true,
                                builder: (ctx) => SafeArea(
                                  child: Padding(
                                    padding: const EdgeInsets.all(AppSpacing.md),
                                    child: Wrap(
                                      spacing: AppSpacing.xs,
                                      runSpacing: AppSpacing.xs,
                                      children: [
                                        for (final cuisine in Cuisines.all)
                                          ChoiceChip(
                                            label: Text(cuisine),
                                            selected:
                                                _cuisineFilter == cuisine,
                                            onSelected: (_) {
                                              setState(() =>
                                                  _cuisineFilter = cuisine);
                                              Navigator.pop(ctx);
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                  ),
                ),
              TabBar(
                controller: _tabs,
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
      body: TabBarView(
        controller: _tabs,
        // Disable horizontal swipe on Nearby so map pan/zoom wins.
        physics: nearbyActive
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        children: [
          _TrendingTab(cuisineFilter: _cuisineFilter),
          const _TopRatedTab(),
          NearbyMapTab(isActive: nearbyActive),
        ],
      ),
    );
  }
}

class _TrendingTab extends ConsumerWidget {
  const _TrendingTab({this.cuisineFilter});

  final String? cuisineFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingAsync = ref.watch(trendingPostsProvider);

    return trendingAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      error: (error, stack) => AsyncErrorView(
        error: error,
        stackTrace: stack,
        title: 'Couldn\'t load trending',
        onRetry: () => ref.invalidate(trendingPostsProvider),
      ),
      data: (posts) {
        final filtered = cuisineFilter == null
            ? posts
            : posts
                .where(
                  (p) => p.tags.any(
                    (t) =>
                        t.toLowerCase() == cuisineFilter!.toLowerCase() ||
                        t.toLowerCase().contains(cuisineFilter!.toLowerCase()),
                  ),
                )
                .toList();
        if (filtered.isEmpty) {
          return Center(
            child: Text(
              cuisineFilter == null
                  ? 'Nothing trending yet — start posting!'
                  : 'No $cuisineFilter posts yet. Tag a post with this cuisine.',
              textAlign: TextAlign.center,
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
            itemCount: filtered.length,
            itemBuilder: (context, i) => _TrendingTile(post: filtered[i]),
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
      error: (error, stack) => AsyncErrorView(
        error: error,
        stackTrace: stack,
        title: 'Couldn\'t load top rated',
        onRetry: () => ref.invalidate(topRatedRestaurantsProvider),
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
