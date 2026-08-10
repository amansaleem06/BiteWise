import '../../../auth/domain/entities/app_user.dart';
import '../../../feed/domain/entities/post.dart';
import '../../../restaurants/domain/entities/restaurant.dart';

/// Discovery surface: trending content, rankings, and universal search.
abstract interface class ExploreRepository {
  /// Most-liked posts. Time-windowed trending scores arrive with the
  /// Cloud Functions milestone; the API shape stays the same.
  Future<List<Post>> fetchTrendingPosts({int limit});

  /// Restaurants ranked by average post rating (min 1 rating).
  Future<List<Restaurant>> fetchTopRatedRestaurants({int limit});

  Future<List<AppUser>> searchUsers(String query, {int limit});

  Future<List<Restaurant>> searchRestaurants(String query, {int limit});

  /// Posts carrying a tag, newest first.
  Future<List<Post>> searchByTag(String tag, {int limit});

  /// Restaurants with coordinates, sorted by distance from the viewer.
  /// (Geohash-bounded queries replace this client-side sort at scale.)
  Future<List<Restaurant>> fetchNearbyRestaurants({
    required double latitude,
    required double longitude,
    int limit,
  });
}
