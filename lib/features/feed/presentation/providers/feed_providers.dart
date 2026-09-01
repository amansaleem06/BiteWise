import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../safety/presentation/providers/safety_providers.dart';
import '../../data/repositories/firestore_feed_repository.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/feed_repository.dart';

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => FirestoreFeedRepository(),
);

enum FeedTab { forYou, following }

/// Immutable feed state with pagination bookkeeping.
class FeedState {
  const FeedState({
    this.posts = const [],
    this.cursor,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  final List<Post> posts;
  final Object? cursor;
  final bool hasMore;
  final bool isLoadingMore;

  FeedState copyWith({
    List<Post>? posts,
    Object? cursor,
    bool? hasMore,
    bool? isLoadingMore,
  }) =>
      FeedState(
        posts: posts ?? this.posts,
        cursor: cursor ?? this.cursor,
        hasMore: hasMore ?? this.hasMore,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      );
}

/// Paginated feed controller, one instance per tab (family).
///
/// Likes/bookmarks are optimistic: UI updates instantly, then the write
/// runs; on failure the change is rolled back.
class FeedController extends FamilyAsyncNotifier<FeedState, FeedTab> {
  FeedRepository get _repo => ref.read(feedRepositoryProvider);

  @override
  Future<FeedState> build(FeedTab tab) async {
    final blocked = await ref.watch(blockedUserIdsProvider.future);
    final page = await _fetch(null);
    return FeedState(
      posts: _withoutBlocked(page.posts, blocked),
      cursor: page.cursor,
      hasMore: page.hasMore,
    );
  }

  List<Post> _withoutBlocked(List<Post> posts, [Set<String>? blocked]) {
    final ids = blocked ?? ref.read(blockedUserIdsProvider).valueOrNull ?? {};
    if (ids.isEmpty) return posts;
    return posts.where((p) => !ids.contains(p.authorId)).toList();
  }

  Future<FeedPage> _fetch(Object? cursor) => switch (arg) {
        FeedTab.forYou => _repo.fetchForYou(cursor: cursor),
        FeedTab.following => _repo.fetchFollowing(cursor: cursor),
      };

  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      final page = await _fetch(null);
      return FeedState(
        posts: _withoutBlocked(page.posts),
        cursor: page.cursor,
        hasMore: page.hasMore,
      );
    });
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await _fetch(current.cursor);
      state = AsyncData(
        current.copyWith(
          posts: [...current.posts, ..._withoutBlocked(page.posts)],
          cursor: page.cursor,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      // Keep existing posts; allow retry on next scroll.
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> toggleLike(String postId) => _toggle(
        postId,
        apply: (p) => p.copyWith(
          isLikedByMe: !p.isLikedByMe,
          likeCount: p.likeCount + (p.isLikedByMe ? -1 : 1),
        ),
        write: (p) => _repo.setLiked(postId, liked: !p.isLikedByMe),
      );

  Future<void> toggleBookmark(String postId) => _toggle(
        postId,
        apply: (p) => p.copyWith(isBookmarkedByMe: !p.isBookmarkedByMe),
        write: (p) =>
            _repo.setBookmarked(postId, bookmarked: !p.isBookmarkedByMe),
      );

  Future<void> toggleRepost(String postId) => _toggle(
        postId,
        apply: (p) => p.copyWith(isRepostedByMe: !p.isRepostedByMe),
        write: (p) =>
            _repo.setReposted(postId, reposted: !p.isRepostedByMe),
      );

  Future<void> sharePost(String postId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final index = current.posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    final original = current.posts[index];
    final updated = [...current.posts]
      ..[index] = original.copyWith(shareCount: original.shareCount + 1);
    state = AsyncData(current.copyWith(posts: updated));
    try {
      await _repo.recordShare(postId);
    } catch (_) {
      final latest = state.valueOrNull;
      if (latest == null) return;
      final i = latest.posts.indexWhere((p) => p.id == postId);
      if (i == -1) return;
      final rolled = [...latest.posts]..[i] = original;
      state = AsyncData(latest.copyWith(posts: rolled));
    }
  }

  Future<void> deletePost(String postId) async {
    await _repo.deletePost(postId);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          posts: current.posts.where((p) => p.id != postId).toList(),
        ),
      );
    }
  }

  Future<void> _toggle(
    String postId, {
    required Post Function(Post) apply,
    required Future<void> Function(Post original) write,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final index = current.posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final original = current.posts[index];
    final updated = [...current.posts]..[index] = apply(original);
    state = AsyncData(current.copyWith(posts: updated));

    try {
      await write(original);
    } catch (_) {
      // Roll back on failure.
      final latest = state.valueOrNull;
      if (latest == null) return;
      final i = latest.posts.indexWhere((p) => p.id == postId);
      if (i == -1) return;
      final rolledBack = [...latest.posts]..[i] = original;
      state = AsyncData(latest.copyWith(posts: rolledBack));
    }
  }
}

final feedControllerProvider =
    AsyncNotifierProviderFamily<FeedController, FeedState, FeedTab>(
  FeedController.new,
);
