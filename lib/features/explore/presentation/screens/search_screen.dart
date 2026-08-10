import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../feed/domain/entities/post.dart';
import '../providers/explore_providers.dart';
import '../widgets/result_tiles.dart';

/// Universal search: restaurants, people, and tags with recent history.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setQuery(String value) => setState(() => _query = value);

  void _commit(String value) {
    if (value.trim().length >= 2) {
      ref.read(recentSearchesProvider.notifier).add(value);
    }
  }

  void _useRecent(String value) {
    _controller.text = value;
    _setQuery(value);
  }

  @override
  Widget build(BuildContext context) {
    final showResults = _query.trim().length >= 2;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Restaurants, people, #tags…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _controller.clear();
                        _setQuery('');
                      },
                    )
                  : null,
              isDense: true,
            ),
            onChanged: _setQuery,
            onSubmitted: _commit,
          ),
        ),
      ),
      body: showResults ? _Results(query: _query) : const _RecentSearches(),
    );
  }
}

class _RecentSearches extends ConsumerWidget {
  const _RecentSearches();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recents = ref.watch(recentSearchesProvider).valueOrNull ?? const [];
    final parent =
        context.findAncestorStateOfType<_SearchScreenState>()!;

    if (recents.isEmpty) {
      return Center(
        child: Text(
          'Search restaurants, food lovers, or #tags.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
            0,
          ),
          child: Row(
            children: [
              Text('Recent', style: theme.textTheme.titleMedium),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    ref.read(recentSearchesProvider.notifier).clear(),
                child: const Text('Clear all'),
              ),
            ],
          ),
        ),
        for (final term in recents)
          ListTile(
            leading: const Icon(Icons.history_rounded),
            title: Text(term),
            trailing: IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () =>
                  ref.read(recentSearchesProvider.notifier).remove(term),
            ),
            onTap: () => parent._useRecent(term),
          ),
      ],
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final resultsAsync = ref.watch(searchResultsProvider(query));

    return resultsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      error: (_, __) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(searchResultsProvider(query)),
          child: const Text('Search failed — retry'),
        ),
      ),
      data: (results) {
        if (results.isEmpty) {
          return Center(
            child: Text(
              'No results for "$query"',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          );
        }
        return ListView(
          children: [
            if (results.restaurants.isNotEmpty) ...[
              const _SectionHeader('Restaurants'),
              for (final r in results.restaurants) RestaurantTile(restaurant: r),
            ],
            if (results.users.isNotEmpty) ...[
              const _SectionHeader('People'),
              for (final u in results.users) UserTile(user: u),
            ],
            if (results.tagPosts.isNotEmpty) ...[
              _SectionHeader('#${query.trim().toLowerCase().replaceFirst('#', '')}'),
              _TagPostsGrid(posts: results.tagPosts),
            ],
            const SizedBox(height: AppSpacing.xl),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _TagPostsGrid extends StatelessWidget {
  const _TagPostsGrid({required this.posts});

  final List<Post> posts;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: posts.length,
      itemBuilder: (context, i) {
        final post = posts[i];
        final media = post.media.isNotEmpty ? post.media.first : null;
        return GestureDetector(
          onTap: () => context.push(Routes.postPath(post.id)),
          child: media == null
              ? const ColoredBox(color: AppColors.primaryLight)
              : CachedNetworkImage(
                  imageUrl: media.type == MediaType.video
                      ? (media.thumbnailUrl ?? media.url)
                      : media.url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: AppColors.primaryLight.withValues(alpha: 0.3),
                  ),
                ),
        );
      },
    );
  }
}
