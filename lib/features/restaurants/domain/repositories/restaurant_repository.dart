import '../../../../core/services/places_search_service.dart';
import '../../../feed/domain/repositories/feed_repository.dart';
import '../claim_matcher.dart';
import '../entities/restaurant.dart';

abstract interface class RestaurantRepository {
  /// Restaurant profile + whether the viewer follows it.
  Future<Restaurant> getById(String id);

  /// Paginated posts tagged with this restaurant, newest first.
  Future<FeedPage> fetchPosts(String restaurantId, {Object? cursor, int limit});

  Future<void> setFollowing(String restaurantId, {required bool following});

  Future<void> saveBusinessDetails({
    required String businessName,
    required String address,
    required String phone,
    String? businessEmail,
  });

  Future<ClaimResult> claimFromPlace(PlaceSuggestion place);

  Future<ClaimResult> claimRestaurant(String restaurantId);

  /// Converts a leftover pending claim into an immediate verified claim.
  Future<void> finalizePendingClaim();

  Future<void> updatePage({
    required String restaurantId,
    String? description,
    String? website,
    String? phone,
    String? menuNotes,
    String? logoUrl,
    String? coverUrl,
  });
}
