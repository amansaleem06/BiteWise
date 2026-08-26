import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/places_search_service.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../explore/presentation/providers/explore_providers.dart';
import '../../../feed/presentation/providers/feed_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../restaurants/domain/entities/restaurant_ref.dart';
import '../../../restaurants/presentation/providers/page_identity_provider.dart';
import '../../../restaurants/presentation/providers/restaurant_providers.dart';
import '../../data/repositories/firebase_create_post_repository.dart';
import '../../domain/repositories/create_post_repository.dart';

final createPostRepositoryProvider = Provider<CreatePostRepository>(
  (ref) => FirebaseCreatePostRepository(),
);

final placesSearchServiceProvider = Provider<PlacesSearchService>(
  (ref) => PlacesSearchService(),
);

/// Debounced Google Places search for restaurant tagging.
final placesRestaurantSearchProvider =
    FutureProvider.autoDispose.family<List<PlaceSuggestion>, String>(
  (ref, query) async {
    if (query.trim().length < 2) return const [];
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return ref.read(placesSearchServiceProvider).searchRestaurants(query);
  },
);

/// Debounced restaurant search for the picker sheet (Firestore fallback).
final restaurantSearchProvider =
    FutureProvider.autoDispose.family<List<RestaurantRef>, String>(
  (ref, query) async {
    if (query.trim().length < 2) return const [];
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return ref.read(createPostRepositoryProvider).searchRestaurants(query);
  },
);

class CreatePostState {
  const CreatePostState({
    this.images = const [],
    this.restaurant,
    this.rating,
    this.isSubmitting = false,
    this.progress = 0,
  });

  final List<XFile> images;
  final RestaurantRef? restaurant;
  final double? rating;
  final bool isSubmitting;

  /// Upload progress 0..1 while submitting.
  final double progress;

  bool get canSubmit {
    if (images.isEmpty || isSubmitting) return false;
    // Rating always requires a restaurant; photo-only posts are fine.
    if (rating != null && restaurant == null) return false;
    return true;
  }

  String? get submitBlockedReason {
    if (isSubmitting) return null;
    if (images.isEmpty) return 'Add at least one photo to publish.';
    if (rating != null && restaurant == null) {
      return 'Tag a restaurant to publish a rating.';
    }
    return null;
  }

  CreatePostState copyWith({
    List<XFile>? images,
    RestaurantRef? restaurant,
    bool clearRestaurant = false,
    double? rating,
    bool clearRating = false,
    bool? isSubmitting,
    double? progress,
  }) =>
      CreatePostState(
        images: images ?? this.images,
        restaurant: clearRestaurant ? null : (restaurant ?? this.restaurant),
        rating: clearRating ? null : (rating ?? this.rating),
        isSubmitting: isSubmitting ?? this.isSubmitting,
        progress: progress ?? this.progress,
      );
}

class CreatePostController extends AutoDisposeNotifier<CreatePostState> {
  static const maxImages = 10;

  @override
  CreatePostState build() => const CreatePostState();

  final _picker = ImagePicker();

  Future<void> pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 95);
    if (picked.isEmpty) return;
    final merged = [...state.images, ...picked].take(maxImages).toList();
    state = state.copyWith(images: merged);
  }

  Future<void> takePhoto() async {
    final shot = await _picker.pickImage(source: ImageSource.camera);
    if (shot == null) return;
    state = state.copyWith(
      images: [...state.images, shot].take(maxImages).toList(),
    );
  }

  void removeImage(int index) {
    final images = [...state.images]..removeAt(index);
    state = state.copyWith(images: images);
  }

  void setRestaurant(RestaurantRef? restaurant) => state = restaurant == null
      ? state.copyWith(clearRestaurant: true)
      : state.copyWith(restaurant: restaurant);

  void setRating(double? rating) => state = rating == null
      ? state.copyWith(clearRating: true)
      : state.copyWith(rating: rating);

  Future<RestaurantRef> createRestaurant(String name) =>
      ref.read(createPostRepositoryProvider).createRestaurantStub(name);

  Future<RestaurantRef> upsertRestaurantFromPlace(PlaceSuggestion place) =>
      ref.read(createPostRepositoryProvider).upsertRestaurantFromPlace(place);

  /// Publishes the post. Returns null on success, or an error message.
  Future<String?> submit({
    String? dishName,
    required String caption,
    double? price,
    required List<String> tags,
  }) async {
    if (!state.canSubmit) {
      return state.submitBlockedReason ??
          'Add at least one photo to publish.';
    }
    if (state.rating != null && state.restaurant == null) {
      return 'Tag a restaurant to publish a rating.';
    }
    state = state.copyWith(isSubmitting: true, progress: 0);
    try {
      await ref.read(createPostRepositoryProvider).publishPost(
            images: state.images,
            restaurant: state.restaurant,
            dishName: dishName,
            caption: caption,
            rating: state.rating,
            price: price,
            tags: tags,
            asRestaurantPage: ref.read(pageIdentityProvider).actingAsPage,
            onProgress: (p) => state = state.copyWith(progress: p),
          );
      ref.invalidate(feedControllerProvider(FeedTab.forYou));
      ref.invalidate(topRatedRestaurantsProvider);
      final pageId = ref.read(pageIdentityProvider).ownedRestaurantId;
      if (pageId != null) {
        ref.invalidate(restaurantPostsProvider(pageId));
        ref.invalidate(restaurantControllerProvider(pageId));
      }
      final uid = ref.read(currentUserProvider)?.uid;
      if (uid != null) {
        ref.invalidate(userProfileProvider(uid));
        ref.invalidate(userPostsProvider(uid));
      }
      state = const CreatePostState();
      return null;
    } catch (e, st) {
      debugPrintStack(stackTrace: st, label: 'Create post failed: $e');
      state = state.copyWith(isSubmitting: false);
      final code = e is AppException
          ? e.code
          : e is FirebaseException
              ? e.code
              : null;
      if (code != null) {
        final mapped = switch (code) {
          'permission-denied' =>
            'Permission denied. Sign in again, or publish Firestore/Storage rules for bitewise-1d266.',
          'unauthorized' =>
            'Upload blocked. Enable Firebase Storage and publish storage.rules.',
          'object-not-found' =>
            'Storage bucket missing. Enable Firebase Storage in the console.',
          _ => null,
        };
        if (mapped != null) return mapped;
      }
      if (e is AppException) return e.message;
      if (e is FirebaseException) {
        return e.message?.isNotEmpty == true
            ? e.message!
            : 'Failed to publish (${e.code}). Please try again.';
      }
      return 'Failed to publish. Please try again.';
    }
  }
}

final createPostControllerProvider =
    NotifierProvider.autoDispose<CreatePostController, CreatePostState>(
  CreatePostController.new,
);
