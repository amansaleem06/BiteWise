import '../entities/post.dart';

class FeedPage {
  const FeedPage({required this.posts, this.cursor, required this.hasMore});

  final List<Post> posts;
  final Object? cursor;
  final bool hasMore;
}

abstract interface class FeedRepository {
  Future<Post> getPostById(String postId);

  Future<FeedPage> fetchForYou({Object? cursor, int limit});

  Future<FeedPage> fetchFollowing({Object? cursor, int limit});

  Future<FeedPage> fetchBookmarks({Object? cursor, int limit});

  Future<void> setLiked(String postId, {required bool liked});

  Future<void> setBookmarked(String postId, {required bool bookmarked});

  Future<void> recordShare(String postId);

  Future<void> setReposted(String postId, {required bool reposted});

  Future<void> deletePost(String postId);

  Future<void> setRestaurantVerified(String postId, {required bool verified});

  /// Owner moderation for diner tags on a restaurant page.
  Future<void> moderateMention(
    String postId, {
    required bool approved,
    required bool hidden,
  });
}
