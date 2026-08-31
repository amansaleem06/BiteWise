import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/social_notification_writer.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/feed_repository.dart';
import '../models/post_model.dart';

class FirestoreFeedRepository implements FeedRepository {
  FirestoreFeedRepository({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
    SocialNotificationWriter? notifications,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance,
        _notifications = notifications ?? SocialNotificationWriter();

  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;
  final SocialNotificationWriter _notifications;

  static const _pageSize = 10;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _firestore.collection('posts');

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AppException('Not signed in');
    return uid;
  }

  @override
  Future<Post> getPostById(String postId) async {
    final uid = _uid;
    final results = await Future.wait([
      _posts.doc(postId).get(),
      _posts.doc(postId).collection('likes').doc(uid).get(),
      _firestore
          .collection('users')
          .doc(uid)
          .collection('bookmarks')
          .doc(postId)
          .get(),
      _firestore
          .collection('users')
          .doc(uid)
          .collection('reposts')
          .doc(postId)
          .get(),
    ]);
    if (!results[0].exists) throw const AppException('Post not found');
    return PostModel.fromDoc(
      results[0],
      isLikedByMe: results[1].exists,
      isBookmarkedByMe: results[2].exists,
      isRepostedByMe: results[3].exists,
    );
  }

  @override
  Future<FeedPage> fetchForYou({Object? cursor, int limit = _pageSize}) {
    Query<Map<String, dynamic>> query =
        _posts.orderBy('createdAt', descending: true).limit(limit);
    if (cursor is DocumentSnapshot) query = query.startAfterDocument(cursor);
    return _runPageQuery(query, limit);
  }

  @override
  Future<FeedPage> fetchFollowing({Object? cursor, int limit = _pageSize}) async {
    final following = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('following')
        .limit(30)
        .get();
    if (following.docs.isEmpty) {
      return const FeedPage(posts: [], hasMore: false);
    }

    Query<Map<String, dynamic>> query = _posts
        .where('authorId', whereIn: following.docs.map((d) => d.id).toList())
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (cursor is DocumentSnapshot) query = query.startAfterDocument(cursor);
    return _runPageQuery(query, limit);
  }

  @override
  Future<FeedPage> fetchBookmarks({Object? cursor, int limit = _pageSize}) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .doc(_uid)
        .collection('bookmarks')
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (cursor is DocumentSnapshot) query = query.startAfterDocument(cursor);
    final snap = await query.get();
    if (snap.docs.isEmpty) return const FeedPage(posts: [], hasMore: false);

    final posts = <Post>[];
    for (final edge in snap.docs) {
      final postSnap = await _posts.doc(edge.id).get();
      if (!postSnap.exists) continue;
      posts.add(
        PostModel.fromDoc(
          postSnap,
          isBookmarkedByMe: true,
        ),
      );
    }
    return FeedPage(
      posts: posts,
      cursor: snap.docs.last,
      hasMore: snap.docs.length == limit,
    );
  }

  Future<FeedPage> _runPageQuery(
    Query<Map<String, dynamic>> query,
    int limit,
  ) async {
    final snap = await query.get();
    if (snap.docs.isEmpty) return const FeedPage(posts: [], hasMore: false);

    final uid = _uid;
    final postIds = snap.docs.map((d) => d.id).toList();

    final results = await Future.wait([
      Future.wait(
        postIds.map((id) => _posts.doc(id).collection('likes').doc(uid).get()),
      ),
      Future.wait(
        postIds.map(
          (id) => _firestore
              .collection('users')
              .doc(uid)
              .collection('bookmarks')
              .doc(id)
              .get(),
        ),
      ),
      Future.wait(
        postIds.map(
          (id) => _firestore
              .collection('users')
              .doc(uid)
              .collection('reposts')
              .doc(id)
              .get(),
        ),
      ),
    ]);
    final likeDocs = results[0];
    final bookmarkDocs = results[1];
    final repostDocs = results[2];

    final posts = <Post>[];
    for (var i = 0; i < snap.docs.length; i++) {
      posts.add(
        PostModel.fromDoc(
          snap.docs[i],
          isLikedByMe: likeDocs[i].exists,
          isBookmarkedByMe: bookmarkDocs[i].exists,
          isRepostedByMe: repostDocs[i].exists,
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
  Future<void> setLiked(String postId, {required bool liked}) async {
    final likeRef = _posts.doc(postId).collection('likes').doc(_uid);
    final postRef = _posts.doc(postId);
    final batch = _firestore.batch();
    if (liked) {
      batch.set(likeRef, {'createdAt': FieldValue.serverTimestamp()});
      batch.update(postRef, {'likeCount': FieldValue.increment(1)});
    } else {
      batch.delete(likeRef);
      batch.update(postRef, {'likeCount': FieldValue.increment(-1)});
    }
    await batch.commit();

    if (liked) {
      final post = await postRef.get();
      final authorId = post.data()?['authorId'] as String?;
      final media = post.data()?['media'];
      String? mediaUrl;
      if (media is List && media.isNotEmpty) {
        final first = media.first;
        if (first is Map && first['url'] is String) {
          mediaUrl = first['url'] as String;
        }
      }
      if (authorId != null) {
        await _notifications.notify(
          recipientUid: authorId,
          type: 'like',
          postId: postId,
          postMediaUrl: mediaUrl,
        );
      }
    }
  }

  @override
  Future<void> setBookmarked(String postId, {required bool bookmarked}) async {
    final ref = _firestore
        .collection('users')
        .doc(_uid)
        .collection('bookmarks')
        .doc(postId);
    if (bookmarked) {
      await ref.set({
        'createdAt': FieldValue.serverTimestamp(),
        'postId': postId,
      });
    } else {
      await ref.delete();
    }
  }

  @override
  Future<void> recordShare(String postId) async {
    await _posts.doc(postId).update({
      'shareCount': FieldValue.increment(1),
    });
  }

  @override
  Future<void> setReposted(String postId, {required bool reposted}) async {
    final ref = _firestore
        .collection('users')
        .doc(_uid)
        .collection('reposts')
        .doc(postId);
    if (reposted) {
      await ref.set({
        'createdAt': FieldValue.serverTimestamp(),
        'postId': postId,
      });
      final post = await _posts.doc(postId).get();
      final authorId = post.data()?['authorId'] as String?;
      if (authorId != null && authorId != _uid) {
        await _notifications.notify(
          recipientUid: authorId,
          type: 'repost',
          postId: postId,
        );
      }
    } else {
      await ref.delete();
    }
  }

  @override
  Future<void> deletePost(String postId) async {
    final uid = _uid;
    final postRef = _posts.doc(postId);
    final snap = await postRef.get();
    if (!snap.exists) throw const AppException('Post not found');
    final data = snap.data() ?? {};
    if (data['authorId'] != uid) {
      throw const AppException('You can only delete your own posts.');
    }

    final restaurantId = data['restaurantId'] as String?;
    final rating = (data['rating'] as num?)?.toDouble();
    final media = data['media'] as List?;

    await postRef.delete();

    if (restaurantId != null && restaurantId.isNotEmpty) {
      final restaurantRef =
          _firestore.collection('restaurants').doc(restaurantId);
      await _firestore.runTransaction((tx) async {
        final r = await tx.get(restaurantRef);
        if (!r.exists) return;
        final d = r.data() ?? {};
        final postCount = ((d['postCount'] as num?)?.toInt() ?? 1) - 1;
        final updates = <String, dynamic>{
          'postCount': postCount < 0 ? 0 : postCount,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (rating != null) {
          final ratingSum =
              ((d['ratingSum'] as num?)?.toDouble() ?? 0) - rating;
          final ratingCount = ((d['ratingCount'] as num?)?.toInt() ?? 1) - 1;
          final nextCount = ratingCount < 0 ? 0 : ratingCount;
          final nextSum = ratingSum < 0 ? 0.0 : ratingSum;
          updates['ratingSum'] = nextSum;
          updates['ratingCount'] = nextCount;
          updates['ratingAvg'] = nextCount == 0 ? 0 : nextSum / nextCount;
        }
        tx.update(restaurantRef, updates);
      });
    }

    if (media != null) {
      for (final item in media) {
        if (item is! Map) continue;
        final url = item['url'];
        if (url is! String || url.isEmpty) continue;
        try {
          await FirebaseStorage.instance.refFromURL(url).delete();
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> moderateMention(
    String postId, {
    required bool approved,
    required bool hidden,
  }) async {
    await _posts.doc(postId).update({
      'mentionApproved': approved,
      'mentionHidden': hidden,
    });
  }

  @override
  Future<void> setRestaurantVerified(
    String postId, {
    required bool verified,
  }) async {
    if (verified) {
      await _posts.doc(postId).update({
        'restaurantVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': _uid,
      });
    } else {
      await _posts.doc(postId).update({
        'restaurantVerified': false,
        'verifiedAt': FieldValue.delete(),
        'verifiedBy': FieldValue.delete(),
      });
    }
  }
}
