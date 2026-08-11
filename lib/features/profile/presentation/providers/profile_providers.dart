import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/error_text.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../feed/presentation/providers/feed_providers.dart';
import '../../data/repositories/firestore_user_repository.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_repository.dart';

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => FirestoreUserRepository(),
);

/// Public profile with optimistic follow.
class UserProfileController
    extends AutoDisposeFamilyAsyncNotifier<UserProfile, String> {
  UserRepository get _repo => ref.read(userRepositoryProvider);

  @override
  Future<UserProfile> build(String uid) => _repo.getById(uid);

  /// Returns null on success, or a user-facing error message.
  Future<String?> toggleFollow() async {
    final current = state.valueOrNull;
    if (current == null) return 'Profile not loaded yet.';

    final delta = current.isFollowedByMe ? -1 : 1;
    final next = current.copyWith(
      isFollowedByMe: !current.isFollowedByMe,
      user: current.user.copyWithCounts(
        followerCount: (current.user.followerCount + delta).clamp(0, 1 << 30),
      ),
    );
    state = AsyncData(next);
    try {
      await _repo.setFollowing(arg, following: next.isFollowedByMe);
      // Following feed contents changed.
      ref.invalidate(feedControllerProvider(FeedTab.following));
      ref.invalidate(userProfileProvider(arg));
      final me = ref.read(currentUserProvider)?.uid;
      if (me != null) ref.invalidate(userProfileProvider(me));
      return null;
    } catch (e, st) {
      debugPrintStack(stackTrace: st, label: 'Follow failed: $e');
      state = AsyncData(current);
      return userMessageFrom(e);
    }
  }
}

final userProfileProvider = AsyncNotifierProvider.autoDispose
    .family<UserProfileController, UserProfile, String>(
  UserProfileController.new,
);

/// Paginated posts for a user (same FeedState machinery).
class UserPostsController
    extends AutoDisposeFamilyAsyncNotifier<FeedState, String> {
  UserRepository get _repo => ref.read(userRepositoryProvider);

  @override
  Future<FeedState> build(String uid) async {
    final page = await _repo.fetchUserPosts(uid);
    return FeedState(
      posts: page.posts,
      cursor: page.cursor,
      hasMore: page.hasMore,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await _repo.fetchUserPosts(arg, cursor: current.cursor);
      state = AsyncData(
        current.copyWith(
          posts: [...current.posts, ...page.posts],
          cursor: page.cursor,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}

final userPostsProvider = AsyncNotifierProvider.autoDispose
    .family<UserPostsController, FeedState, String>(UserPostsController.new);

/// Edit-profile form actions.
class EditProfileController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  final _picker = ImagePicker();

  /// Returns true on success.
  Future<bool> save({required String displayName, required String bio}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(userRepositoryProvider)
          .updateProfile(displayName: displayName, bio: bio),
    );
    return !state.hasError;
  }

  Future<bool> pickAndUploadAvatar() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (image == null) return false;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(userRepositoryProvider).updateAvatar(image),
    );
    return !state.hasError;
  }
}

final editProfileControllerProvider =
    AsyncNotifierProvider.autoDispose<EditProfileController, void>(
  EditProfileController.new,
);
