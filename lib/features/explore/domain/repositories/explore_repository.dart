import '../../../auth/domain/entities/app_user.dart';
import '../../../feed/domain/entities/post.dart';
import '../../../restaurants/domain/entities/restaurant.dart';

enum RankingPeriod {
  day,
  month,
  year;

  String get label => switch (this) {
        RankingPeriod.day => 'Today',
        RankingPeriod.month => 'This month',
        RankingPeriod.year => 'This year',
      };

  String get championTitle => switch (this) {
        RankingPeriod.day => 'Restaurant of the Day',
        RankingPeriod.month => 'Restaurant of the Month',
        RankingPeriod.year => 'Restaurant of the Year',
      };

  Duration get window => switch (this) {
        RankingPeriod.day => const Duration(hours: 36),
        RankingPeriod.month => const Duration(days: 30),
        RankingPeriod.year => const Duration(days: 365),
      };
}

/// Discovery surface: trending content, rankings, and universal search.
abstract interface class ExploreRepository {
  /// Most-liked posts. Time-windowed trending scores arrive with the
  /// Cloud Functions milestone; the API shape stays the same.
  Future<List<Post>> fetchTrendingPosts({int limit});

  /// Restaurants ranked by average post rating (min 1 rating).
  Future<List<Restaurant>> fetchTopRatedRestaurants({int limit});

  /// Time-window ranking: Day / Month / Year.
  Future<List<Restaurant>> fetchRankedRestaurants({
    required RankingPeriod period,
    int limit,
  });

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
