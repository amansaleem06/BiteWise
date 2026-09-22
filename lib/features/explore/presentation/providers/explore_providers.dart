import '../../../safety/presentation/providers/safety_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/recent_searches_service.dart';
import '../../../../core/utils/dietary_ranking.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../feed/domain/entities/post.dart';
import '../../../restaurants/domain/entities/restaurant.dart';
import '../../data/repositories/firestore_explore_repository.dart';
import '../../domain/repositories/explore_repository.dart';

final exploreRepositoryProvider = Provider<ExploreRepository>(
  (ref) => FirestoreExploreRepository(),
);

final recentSearchesServiceProvider =
    Provider<RecentSearchesService>((ref) => RecentSearchesService());

final trendingPostsProvider = StreamProvider.autoDispose<List<Post>>(
  (ref) async* {
    final blockedState = ref.watch(blockedUserIdsProvider);
    final blocked = blockedState.valueOrNull ??
        await ref.watch(blockedUserIdsProvider.future);
    yield* ref.read(exploreRepositoryProvider).watchTrendingPosts().map(
        (posts) =>
            posts.where((post) => !blocked.contains(post.authorId)).toList());
  },
);

final topRatedRestaurantsProvider =
    FutureProvider.autoDispose<List<Restaurant>>(
  (ref) async {
    final restaurants =
        await ref.read(exploreRepositoryProvider).fetchTopRatedRestaurants();
    final preferences =
        ref.watch(currentUserProvider)?.dietaryPreferences ?? const [];
    return DietaryRanking.rankRestaurants(restaurants, preferences);
  },
);

final rankedRestaurantsProvider =
    FutureProvider.autoDispose.family<List<Restaurant>, RankingPeriod>(
  (ref, period) => ref
      .read(exploreRepositoryProvider)
      .fetchRankedRestaurants(period: period),
);

/// Combined results for one query.
class SearchResults {
  const SearchResults({
    this.restaurants = const [],
    this.users = const [],
    this.tagPosts = const [],
  });

  final List<Restaurant> restaurants;
  final List<AppUser> users;
  final List<Post> tagPosts;

  bool get isEmpty => restaurants.isEmpty && users.isEmpty && tagPosts.isEmpty;
}

/// Debounced universal search across restaurants, users, and tags.
final searchResultsProvider =
    FutureProvider.autoDispose.family<SearchResults, String>(
  (ref, query) async {
    final blocked = await ref.watch(blockedUserIdsProvider.future);
    final q = query.trim();
    if (q.length < 2) return const SearchResults();

    var disposed = false;
    ref.onDispose(() => disposed = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (disposed) return const SearchResults();

    final repo = ref.read(exploreRepositoryProvider);
    final tag = q.startsWith('#') ? q.substring(1) : q;

    // Isolate failures so a missing tag composite index can't hide
    // restaurant/people matches.
    final settled = await Future.wait([
      repo.searchRestaurants(q).catchError((_) => <Restaurant>[]),
      repo.searchUsers(q).catchError((_) => <AppUser>[]),
      repo.searchByTag(tag).catchError((_) => <Post>[]),
    ]);
    if (disposed) return const SearchResults();

    return SearchResults(
      restaurants: settled[0] as List<Restaurant>,
      users: (settled[1] as List<AppUser>)
          .where((u) => !blocked.contains(u.uid))
          .toList(),
      tagPosts: (settled[2] as List<Post>)
          .where((p) => !blocked.contains(p.authorId))
          .toList(),
    );
  },
);

/// Recent search history with mutation helpers.
class RecentSearchesController extends AutoDisposeAsyncNotifier<List<String>> {
  RecentSearchesService get _service => ref.read(recentSearchesServiceProvider);

  @override
  Future<List<String>> build() => _service.load();

  Future<void> add(String query) async =>
      state = AsyncData(await _service.add(query));

  Future<void> remove(String query) async =>
      state = AsyncData(await _service.remove(query));

  Future<void> clear() async {
    await _service.clear();
    state = const AsyncData([]);
  }
}

final recentSearchesProvider =
    AsyncNotifierProvider.autoDispose<RecentSearchesController, List<String>>(
  RecentSearchesController.new,
);
