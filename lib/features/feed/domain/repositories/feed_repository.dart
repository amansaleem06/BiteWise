import '../entities/post.dart';

/// A page of posts plus an opaque cursor for fetching the next page.
class FeedPage {
  const FeedPage({required this.posts, this.cursor, required this.hasMore});

  final List<Post> posts;

  /// Opaque pagination token (implementation detail of the data layer).
  final Object? cursor;
  final bool hasMore;
}

abstract interface class FeedRepository {
  /// Single post with the viewer's like/bookmark state.
  Future<Post> getPostById(String postId);

  /// Recent posts, newest first. Personalized ranking comes later via
  /// Cloud Functions; the API shape won't change.
  Future<FeedPage> fetchForYou({Object? cursor, int limit});

  /// Posts from accounts the viewer follows.
  Future<FeedPage> fetchFollowing({Object? cursor, int limit});

  Future<void> setLiked(String postId, {required bool liked});

  Future<void> setBookmarked(String postId, {required bool bookmarked});
}
