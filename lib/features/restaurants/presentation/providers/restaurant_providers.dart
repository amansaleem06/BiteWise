import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../feed/presentation/providers/feed_providers.dart';
import '../../data/repositories/firestore_restaurant_repository.dart';
import '../../domain/entities/restaurant.dart';
import '../../domain/repositories/restaurant_repository.dart';

final restaurantRepositoryProvider = Provider<RestaurantRepository>(
  (ref) => FirestoreRestaurantRepository(),
);

/// Restaurant profile with optimistic follow/unfollow.
class RestaurantController
    extends AutoDisposeFamilyAsyncNotifier<Restaurant, String> {
  RestaurantRepository get _repo => ref.read(restaurantRepositoryProvider);

  @override
  Future<Restaurant> build(String restaurantId) => _repo.getById(restaurantId);

  Future<void> updatePage({
    required String description,
    required String website,
    required String phone,
    required String menuNotes,
    String? logoUrl,
    String? coverUrl,
  }) async {
    await _repo.updatePage(
      restaurantId: arg,
      description: description,
      website: website,
      phone: phone,
      menuNotes: menuNotes,
      logoUrl: logoUrl,
      coverUrl: coverUrl,
    );
    ref.invalidateSelf();
  }

  Future<void> toggleFollow() async {
    final current = state.valueOrNull;
    if (current == null) return;

    final next = current.copyWith(
      isFollowedByMe: !current.isFollowedByMe,
      followerCount: current.followerCount + (current.isFollowedByMe ? -1 : 1),
    );
    state = AsyncData(next);
    try {
      await _repo.setFollowing(arg, following: next.isFollowedByMe);
    } catch (_) {
      state = AsyncData(current); // roll back
    }
  }

  Future<void> setGuestFeedMode(GuestFeedMode mode) async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(guestFeedMode: mode));
    }
    try {
      await _repo.setGuestFeedMode(arg, mode);
    } catch (_) {
      if (current != null) state = AsyncData(current);
      rethrow;
    }
  }
}

final restaurantControllerProvider = AsyncNotifierProvider.autoDispose
    .family<RestaurantController, Restaurant, String>(RestaurantController.new);

/// Paginated posts for a restaurant (same FeedState machinery as Home).
class RestaurantPostsController
    extends AutoDisposeFamilyAsyncNotifier<FeedState, String> {
  RestaurantRepository get _repo => ref.read(restaurantRepositoryProvider);

  @override
  Future<FeedState> build(String restaurantId) async {
    final page = await _repo.fetchPosts(restaurantId);
    return FeedState(
      posts: page.posts,
      cursor: page.cursor,
      hasMore: page.hasMore,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await _repo.fetchPosts(arg, cursor: current.cursor);
      state = AsyncData(
        current.copyWith(
          posts: [...current.posts, ...page.posts],
          cursor: page.cursor,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}

final restaurantPostsProvider = AsyncNotifierProvider.autoDispose
    .family<RestaurantPostsController, FeedState, String>(
  RestaurantPostsController.new,
);
