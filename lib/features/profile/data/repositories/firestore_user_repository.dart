import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../feed/data/models/post_model.dart';
import '../../../feed/domain/entities/post.dart';
import '../../../feed/domain/repositories/feed_repository.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_repository.dart';

class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
    MediaUploadService? uploads,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance,
        _uploads = uploads ?? MediaUploadService();

  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;
  final MediaUploadService _uploads;

  static const _pageSize = 12;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AppException('Not signed in');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  @override
  Future<UserProfile> getById(String uid) async {
    final results = await Future.wait([
      _users.doc(uid).get(),
      _users.doc(uid).collection('followers').doc(_uid).get(),
    ]);
    if (!results[0].exists) throw const AppException('User not found');
    return UserProfile(
      user: UserModel.fromDoc(results[0]),
      isFollowedByMe: results[1].exists,
    );
  }

  @override
  Future<FeedPage> fetchUserPosts(
    String uid, {
    Object? cursor,
    int limit = _pageSize,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('posts')
        .where('authorId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (cursor is DocumentSnapshot) query = query.startAfterDocument(cursor);

    final snap = await query.get();
    if (snap.docs.isEmpty) return const FeedPage(posts: [], hasMore: false);

    final me = _uid;
    final results = await Future.wait([
      Future.wait(
        snap.docs.map((d) => d.reference.collection('likes').doc(me).get()),
      ),
      Future.wait(
        snap.docs.map(
          (d) => _users.doc(me).collection('bookmarks').doc(d.id).get(),
        ),
      ),
    ]);

    final posts = <Post>[];
    for (var i = 0; i < snap.docs.length; i++) {
      posts.add(
        PostModel.fromDoc(
          snap.docs[i],
          isLikedByMe: results[0][i].exists,
          isBookmarkedByMe: results[1][i].exists,
        ),
      );
    }
    return FeedPage(
      posts: posts,
      cursor: snap.docs.last,
      hasMore: snap.docs.length == limit,
    );
  }

  @override
  Future<void> setFollowing(
    String targetUid, {
    required bool following,
  }) async {
    final me = _uid;
    if (me == targetUid) throw const AppException("You can't follow yourself");

    // Single canonical edge write. A Cloud Function mirrors the reverse
    // `followers` edge and maintains both counters.
    final myFollowingRef =
        _users.doc(me).collection('following').doc(targetUid);
    if (following) {
      await myFollowingRef.set({'createdAt': FieldValue.serverTimestamp()});
    } else {
      await myFollowingRef.delete();
    }
  }

  @override
  Future<void> updateProfile({String? displayName, String? bio}) async {
    final user = _auth.currentUser;
    if (user == null) throw const AppException('Not signed in');

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (displayName != null && displayName.trim().isNotEmpty) {
      updates['displayName'] = displayName.trim();
      updates['displayNameLower'] = displayName.trim().toLowerCase();
      await user.updateDisplayName(displayName.trim());
    }
    if (bio != null) updates['bio'] = bio.trim();

    await _users.doc(user.uid).update(updates);
  }

  @override
  Future<String> updateAvatar(XFile image) async {
    final user = _auth.currentUser;
    if (user == null) throw const AppException('Not signed in');

    final url = await _uploads.uploadAvatar(uid: user.uid, file: image);
    // Cache-bust: Storage keeps the same path, so append a version.
    final versioned =
        '$url${url.contains('?') ? '&' : '?'}v=${DateTime.now().millisecondsSinceEpoch}';
    await Future.wait([
      user.updatePhotoURL(versioned),
      _users.doc(user.uid).update({
        'photoUrl': versioned,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    ]);
    return versioned;
  }
}
