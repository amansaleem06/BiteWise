import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../feed/presentation/providers/feed_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../restaurants/domain/entities/restaurant_ref.dart';
import '../../data/repositories/firebase_create_post_repository.dart';
import '../../domain/repositories/create_post_repository.dart';

final createPostRepositoryProvider = Provider<CreatePostRepository>(
  (ref) => FirebaseCreatePostRepository(),
);

/// Debounced restaurant search for the picker sheet.
final restaurantSearchProvider =
    FutureProvider.autoDispose.family<List<RestaurantRef>, String>(
  (ref, query) async {
    if (query.trim().length < 2) return const [];
    // Debounce: autoDispose cancels this if the user keeps typing.
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

  bool get canSubmit =>
      images.isNotEmpty && restaurant != null && !isSubmitting;

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

  /// Publishes the post. Returns null on success, or an error message.
  Future<String?> submit({
    String? dishName,
    required String caption,
    double? price,
    required List<String> tags,
  }) async {
    if (!state.canSubmit) return 'Add at least one photo and a restaurant.';
    state = state.copyWith(isSubmitting: true, progress: 0);
    try {
      await ref.read(createPostRepositoryProvider).publishPost(
            images: state.images,
            restaurant: state.restaurant!,
            dishName: dishName,
            caption: caption,
            rating: state.rating,
            price: price,
            tags: tags,
            onProgress: (p) => state = state.copyWith(progress: p),
          );
      // Fresh content + profile post count should appear immediately.
      ref.invalidate(feedControllerProvider(FeedTab.forYou));
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
