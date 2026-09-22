import '../../../../core/services/content_visibility.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../../../core/services/social_notification_writer.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/domain/entities/app_user.dart';
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
    SocialNotificationWriter? notifications,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance,
        _uploads = uploads ?? MediaUploadService(),
        _notifications = notifications ?? SocialNotificationWriter();

  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;
  final MediaUploadService _uploads;
  final SocialNotificationWriter _notifications;

  static const _pageSize = 12;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AppException('Not signed in');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get _publicProfiles =>
      _firestore.collection('publicProfiles');

  @override
  Future<UserProfile> getById(String uid) async {
    // Followers may exist only as `users/*/following/{uid}` (legacy dual-write
    // gaps). Prefer collection-group discovery over the reverse subcollection.
    final results = await Future.wait([
      (uid == _uid ? _users : _publicProfiles).doc(uid).get(),
      _users.doc(_uid).collection('following').doc(uid).get(),
      _countPosts(uid),
      _countFollowers(uid),
      _countCollection(_users.doc(uid).collection('following')),
    ]);
    if (!(results[0] as DocumentSnapshot).exists) {
      throw const AppException('User not found');
    }

    // Opportunistically repair reverse edges for *my* following list so other
    // clients that only read `followers/` still see counts.
    if (uid == _uid) {
      // ignore: unawaited_futures
      _repairReverseFollowersFor(_uid);
    }

    final stored =
        UserModel.fromDoc(results[0] as DocumentSnapshot<Map<String, dynamic>>);
    final user = stored.copyWithCounts(
      postCount: results[2] as int,
      followerCount: results[3] as int,
      followingCount: results[4] as int,
    );
    return UserProfile(
      user: user,
      isFollowedByMe: (results[1] as DocumentSnapshot).exists,
    );
  }

  /// People who follow [uid]: every `users/{follower}/following/{uid}` edge.
  Future<int> _countFollowers(String uid) async {
    try {
      final agg = await _firestore
          .collectionGroup('following')
          .where(FieldPath.documentId, isEqualTo: uid)
          .count()
          .get();
      final fromEdges = agg.count ?? 0;
      if (fromEdges > 0) return fromEdges;
    } catch (_) {
      // Fall through — some projects need an index / older SDK quirks.
    }
    try {
      final snap = await _firestore
          .collectionGroup('following')
          .where(FieldPath.documentId, isEqualTo: uid)
          .limit(500)
          .get();
      if (snap.size > 0) return snap.size;
    } catch (_) {}
    return _countCollection(_users.doc(uid).collection('followers'));
  }

  /// Writes missing `followers/{me}` docs for people I already follow.
  Future<void> _repairReverseFollowersFor(String me) async {
    try {
      final edges =
          await _users.doc(me).collection('following').limit(200).get();
      if (edges.docs.isEmpty) return;
      final batch = _firestore.batch();
      var ops = 0;
      for (final edge in edges.docs) {
        final reverse = _users.doc(edge.id).collection('followers').doc(me);
        batch.set(
          reverse,
          {
            'createdAt': FieldValue.serverTimestamp(),
            'repairedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        ops++;
      }
      if (ops > 0) await batch.commit();
    } catch (_) {
      // Best-effort; list/count still work via collection group.
    }
  }

  Future<int> _countPosts(String uid) async {
    try {
      final agg = await _firestore
          .collection('posts')
          .where('authorId', isEqualTo: uid)
          .count()
          .get();
      return agg.count ?? 0;
    } catch (_) {
      final snap = await _firestore
          .collection('posts')
          .where('authorId', isEqualTo: uid)
          .limit(200)
          .get();
      return snap.size;
    }
  }

  Future<int> _countCollection(
    CollectionReference<Map<String, dynamic>> ref,
  ) async {
    try {
      final agg = await ref.count().get();
      return agg.count ?? 0;
    } catch (_) {
      final snap = await ref.limit(500).get();
      return snap.size;
    }
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

    final visibility = await ContentVisibility.load(_firestore);
    final posts = <Post>[];
    for (var i = 0; i < snap.docs.length; i++) {
      if (!visibility.allows(snap.docs[i])) continue;
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

    final myFollowingRef =
        _users.doc(me).collection('following').doc(targetUid);
    final theirFollowersRef =
        _users.doc(targetUid).collection('followers').doc(me);

    if (following) {
      final existing = await myFollowingRef.get();
      if (existing.exists) {
        // Ensure reverse edge exists even for older follows.
        await theirFollowersRef.set(
          {'createdAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
        return;
      }
      final batch = _firestore.batch()
        ..set(myFollowingRef, {
          'createdAt': FieldValue.serverTimestamp(),
          'targetUid': targetUid,
        })
        ..set(theirFollowersRef, {
          'createdAt': FieldValue.serverTimestamp(),
          'followerUid': me,
        });
      await batch.commit();
      await _notifications.notify(recipientUid: targetUid, type: 'follow');
    } else {
      final batch = _firestore.batch()
        ..delete(myFollowingRef)
        ..delete(theirFollowersRef);
      await batch.commit();
    }
  }

  @override
  Future<List<AppUser>> fetchFollowing(String uid, {int limit = 50}) async {
    if (uid == _uid) {
      await _repairReverseFollowersFor(uid);
    }
    return _usersFromEdge(uid, collection: 'following', limit: limit);
  }

  @override
  Future<List<AppUser>> fetchFollowers(String uid, {int limit = 50}) async {
    // Prefer reverse subcollection; fall back to collection-group on following.
    final reverse =
        await _users.doc(uid).collection('followers').limit(limit).get();
    if (reverse.docs.isNotEmpty) {
      return _hydrateUsers(reverse.docs.map((d) => d.id));
    }

    try {
      final edges = await _firestore
          .collectionGroup('following')
          .where(FieldPath.documentId, isEqualTo: uid)
          .limit(limit)
          .get();
      final followerIds = <String>[];
      for (final d in edges.docs) {
        final parent = d.reference.parent.parent;
        if (parent != null) followerIds.add(parent.id);
      }
      return await _hydrateUsers(followerIds);
    } catch (_) {
      return const [];
    }
  }

  Future<List<AppUser>> _usersFromEdge(
    String uid, {
    required String collection,
    required int limit,
  }) async {
    final edges =
        await _users.doc(uid).collection(collection).limit(limit).get();
    if (edges.docs.isEmpty) return const [];
    return _hydrateUsers(edges.docs.map((d) => d.id));
  }

  Future<List<AppUser>> _hydrateUsers(Iterable<String> uids) async {
    final visibility = await ContentVisibility.load(_firestore);
    final users = await Future.wait(
      uids.map((id) async {
        final snap =
            await (id == _uid ? _users : _publicProfiles).doc(id).get();
        if (!visibility.allows(snap)) return null;
        return UserModel.fromDoc(snap);
      }),
    );
    return users.whereType<AppUser>().toList();
  }

  @override
  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? phone,
    MessagePrivacy? messagePrivacy,
    List<DietaryPreference>? dietaryPreferences,
  }) async {
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
    if (bio != null) {
      final clean = bio
          .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
          .trim();
      if (clean.length > 160)
        throw const AppException('Bio must be 160 characters or fewer.');
      updates['bio'] = clean;
    }
    if (phone != null) updates['phone'] = phone.trim();
    if (messagePrivacy != null) {
      updates['messagePrivacy'] = messagePrivacy.name;
    }
    if (dietaryPreferences != null) {
      updates['dietaryPreferences'] =
          dietaryPreferences.map((preference) => preference.name).toList();
    }

    final publicUpdates = UserModel.publicProfile(updates);
    final batch = _firestore.batch()..update(_users.doc(user.uid), updates);
    if (publicUpdates.isNotEmpty) {
      batch.set(
        _publicProfiles.doc(user.uid),
        publicUpdates,
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  @override
  Future<String> updateAvatar(XFile image) async {
    final user = _auth.currentUser;
    if (user == null) throw const AppException('Not signed in');

    final profile = await _users.doc(user.uid).get();
    final previousUrl = profile.data()?['photoUrl'] as String?;
    final url = await _uploads.uploadAvatar(uid: user.uid, file: image);
    final updates = <String, dynamic>{
      'photoUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    try {
      await (_firestore.batch()
            ..update(_users.doc(user.uid), updates)
            ..set(
              _publicProfiles.doc(user.uid),
              updates,
              SetOptions(merge: true),
            ))
          .commit();
    } catch (error, stack) {
      // The new object is not referenced anywhere, so it is safe to remove.
      try {
        await _uploads.deleteOwnedAvatar(uid: user.uid, downloadUrl: url);
      } catch (cleanupError) {
        debugPrint('Avatar rollback cleanup failed: $cleanupError');
      }
      Error.throwWithStackTrace(error, stack);
    }
    // Firestore is the profile source of truth; Auth metadata is best effort.
    try {
      await user.updatePhotoURL(url);
    } catch (error) {
      debugPrint('Firebase Auth avatar sync failed: $error');
    }
    await _evictAvatar(previousUrl);
    return url;
  }

  @override
  Future<void> removeAvatar() async {
    final user = _auth.currentUser;
    if (user == null) throw const AppException('Not signed in');

    final profile = await _users.doc(user.uid).get();
    final previousUrl = profile.data()?['photoUrl'] as String?;
    if (previousUrl == null || previousUrl.isEmpty) return;

    final updates = <String, dynamic>{
      'photoUrl': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await (_firestore.batch()
          ..update(_users.doc(user.uid), updates)
          ..set(
            _publicProfiles.doc(user.uid),
            updates,
            SetOptions(merge: true),
          ))
        .commit();

    try {
      await user.updatePhotoURL(null);
    } catch (error) {
      debugPrint('Firebase Auth avatar removal sync failed: $error');
    }
    await _evictAvatar(previousUrl);
  }

  Future<void> _evictAvatar(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      await CachedNetworkImage.evictFromCache(url);
    } catch (error) {
      // Firestore already holds the new value. A local cache failure must not
      // turn a successful profile update into a reported upload failure.
      debugPrint('Avatar cache eviction failed: $error');
    }
  }
}
