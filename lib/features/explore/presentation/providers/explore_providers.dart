import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/recent_searches_service.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../feed/domain/entities/post.dart';
import '../../../restaurants/domain/entities/restaurant.dart';
import '../../data/repositories/firestore_explore_repository.dart';
import '../../domain/repositories/explore_repository.dart';

final exploreRepositoryProvider = Provider<ExploreRepository>(
  (ref) => FirestoreExploreRepository(),
);

final recentSearchesServiceProvider =
    Provider<RecentSearchesService>((ref) => RecentSearchesService());

final trendingPostsProvider = FutureProvider.autoDispose<List<Post>>(
  (ref) => ref.read(exploreRepositoryProvider).fetchTrendingPosts(),
);

final topRatedRestaurantsProvider =
    FutureProvider.autoDispose<List<Restaurant>>(
  (ref) => ref.read(exploreRepositoryProvider).fetchTopRatedRestaurants(),
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
    final q = query.trim();
    if (q.length < 2) return const SearchResults();
    // Debounce: autoDispose cancels stale lookups while typing.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final repo = ref.read(exploreRepositoryProvider);
    final results = await Future.wait([
      repo.searchRestaurants(q),
      repo.searchUsers(q),
      repo.searchByTag(q),
    ]);
    return SearchResults(
      restaurants: results[0] as List<Restaurant>,
      users: results[1] as List<AppUser>,
      tagPosts: results[2] as List<Post>,
    );
  },
);

/// Recent search history with mutation helpers.
class RecentSearchesController
    extends AutoDisposeAsyncNotifier<List<String>> {
  RecentSearchesService get _service =>
      ref.read(recentSearchesServiceProvider);

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
