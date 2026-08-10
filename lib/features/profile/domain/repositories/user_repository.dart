import 'package:image_picker/image_picker.dart';

import '../../../feed/domain/repositories/feed_repository.dart';
import '../entities/user_profile.dart';

abstract interface class UserRepository {
  /// Profile + whether the viewer follows them.
  Future<UserProfile> getById(String uid);

  /// Paginated posts authored by [uid], newest first.
  Future<FeedPage> fetchUserPosts(String uid, {Object? cursor, int limit});

  /// Follow/unfollow: maintains both edge docs and both counters atomically.
  Future<void> setFollowing(String targetUid, {required bool following});

  /// Updates displayName/bio; also syncs Firebase Auth displayName so new
  /// posts/comments denormalize the fresh name.
  Future<void> updateProfile({String? displayName, String? bio});

  /// Uploads a new avatar and updates Firestore + Auth photoUrl.
  Future<String> updateAvatar(XFile image);
}
