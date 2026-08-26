import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/cuisines.dart';
import '../../../../core/widgets/async_error_view.dart';
import '../../../feed/domain/entities/post.dart';
import '../../../restaurants/domain/entities/restaurant.dart';
import '../../domain/repositories/explore_repository.dart';
import '../providers/explore_providers.dart';
import '../widgets/nearby_map_tab.dart';
import '../widgets/plate_roulette_sheet.dart';
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
    _tabs = TabController(length: 3, vsync: this, initialIndex: 0);
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
    final mapActive = _tabs.index == 0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back to Feed',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(Routes.home),
        ),
        title: Text(
          'Explore',
          style: GoogleFonts.fraunces(
            fontWeight: FontWeight.w800,
            fontSize: 26,
            letterSpacing: -0.8,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.casino_outlined),
            tooltip: 'Plate Roulette — let fate pick dinner',
            onPressed: () => PlateRouletteSheet.show(context),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(mapActive ? 104 : 152),
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
              if (!mapActive)
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
                                              setState(() {
                                                _cuisineFilter = cuisine;
                                              });
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
                  Tab(text: 'Map'),
                  Tab(text: 'Trending'),
                  Tab(text: 'Top Rated'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        physics: mapActive
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        children: [
          NearbyMapTab(isActive: mapActive),
          _TrendingTab(cuisineFilter: _cuisineFilter),
          const _TopRatedTab(),
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
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 160),
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

class _TopRatedTab extends ConsumerStatefulWidget {
  const _TopRatedTab();

  @override
  ConsumerState<_TopRatedTab> createState() => _TopRatedTabState();
}

class _TopRatedTabState extends ConsumerState<_TopRatedTab> {
  var _period = RankingPeriod.month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rankedAsync = ref.watch(rankedRestaurantsProvider(_period));

    return rankedAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      error: (error, stack) => AsyncErrorView(
        error: error,
        stackTrace: stack,
        title: 'Couldn\'t load rankings',
        onRetry: () => ref.invalidate(rankedRestaurantsProvider(_period)),
      ),
      data: (restaurants) {
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async =>
              ref.invalidate(rankedRestaurantsProvider(_period)),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 160),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    for (final period in RankingPeriod.values) ...[
                      if (period != RankingPeriod.values.first)
                        const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(period.label),
                        selected: _period == period,
                        onSelected: (_) => setState(() => _period = period),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (restaurants.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    'No ratings in this window yet.\nRate a dish when you post!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else ...[
                _ChampionCard(
                  restaurant: restaurants.first,
                  title: _period.championTitle,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (var i = 1; i < restaurants.length; i++)
                  RestaurantTile(restaurant: restaurants[i], rank: i + 1),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ChampionCard extends StatelessWidget {
  const _ChampionCard({required this.restaurant, required this.title});

  final Restaurant restaurant;
  final String title;

  @override
  Widget build(BuildContext context) {
    final rating = restaurant.averageRating;
    final image = restaurant.coverUrl ?? restaurant.logoUrl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => context.push(Routes.restaurantPath(restaurant.id)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: image != null
                        ? CachedNetworkImage(imageUrl: image, fit: BoxFit.cover)
                        : const ColoredBox(
                            color: AppColors.primaryDark,
                            child: Icon(
                              Icons.emoji_events_outlined,
                              color: AppColors.cream,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: GoogleFonts.sourceSans3(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppColors.accent,
                        ),
                      ),
                      Text(
                        restaurant.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.fraunces(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.cream,
                        ),
                      ),
                      if (rating != null)
                        Text(
                          '★ ${rating.toStringAsFixed(1)}  ·  ${restaurant.ratingCount} ratings',
                          style: GoogleFonts.sourceSans3(
                            color: AppColors.cream.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                          ),
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
