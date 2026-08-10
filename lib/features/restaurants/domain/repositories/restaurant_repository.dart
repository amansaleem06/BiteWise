import '../../../feed/domain/repositories/feed_repository.dart';
import '../entities/restaurant.dart';

abstract interface class RestaurantRepository {
  /// Restaurant profile + whether the viewer follows it.
  Future<Restaurant> getById(String id);

  /// Paginated posts tagged with this restaurant, newest first.
  Future<FeedPage> fetchPosts(String restaurantId, {Object? cursor, int limit});

  Future<void> setFollowing(String restaurantId, {required bool following});
}
