import 'package:image_picker/image_picker.dart';

import '../../../restaurants/domain/entities/restaurant_ref.dart';
import '../../../../core/services/places_search_service.dart';

/// Contract for composing and publishing a post.
abstract interface class CreatePostRepository {
  /// Prefix search over restaurant names already in Firestore.
  Future<List<RestaurantRef>> searchRestaurants(String query);

  /// Creates a minimal unclaimed restaurant document so the post has a real
  /// restaurantId to anchor to. Owners can claim it later.
  Future<RestaurantRef> createRestaurantStub(String name);

  /// Upserts a restaurant from a Google Places suggestion (by placeId).
  Future<RestaurantRef> upsertRestaurantFromPlace(PlaceSuggestion place);

  /// Uploads media then writes the post document.
  Future<void> publishPost({
    required List<XFile> images,
    RestaurantRef? restaurant,
    String? dishName,
    required String caption,
    double? rating,
    double? price,
    required List<String> tags,
    void Function(double progress)? onProgress,
  });
}

