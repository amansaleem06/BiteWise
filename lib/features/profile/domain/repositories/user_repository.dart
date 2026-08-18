import 'package:image_picker/image_picker.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../feed/domain/repositories/feed_repository.dart';
import '../entities/user_profile.dart';

abstract interface class UserRepository {
  /// Profile + whether the viewer follows them.
  Future<UserProfile> getById(String uid);

  /// Paginated posts authored by [uid], newest first.
  Future<FeedPage> fetchUserPosts(String uid, {Object? cursor, int limit});

  /// Follow/unfollow: writes both following and followers edges.
  Future<void> setFollowing(String targetUid, {required bool following});

  /// Users this profile follows / users who follow this profile.
  Future<List<AppUser>> fetchFollowing(String uid, {int limit = 50});
  Future<List<AppUser>> fetchFollowers(String uid, {int limit = 50});

  /// Updates displayName/bio; also syncs Firebase Auth displayName so new
  /// posts/comments denormalize the fresh name.
  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? phone,
    MessagePrivacy? messagePrivacy,
  });

  /// Uploads a new avatar and updates Firestore + Auth photoUrl.
  Future<String> updateAvatar(XFile image);
}
