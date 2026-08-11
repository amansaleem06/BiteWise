import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/social_notification_writer.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/feed_repository.dart';
import '../models/post_model.dart';

/// Firestore-backed feed.
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
    ]);
    if (!results[0].exists) throw const AppException('Post not found');
    return PostModel.fromDoc(
      results[0],
      isLikedByMe: results[1].exists,
      isBookmarkedByMe: results[2].exists,
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
    // NOTE: `whereIn` caps at 30 ids. Fine for early product; the backend
    // milestone replaces this with a fanned-out timeline per user.
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

  Future<FeedPage> _runPageQuery(
    Query<Map<String, dynamic>> query,
    int limit,
  ) async {
    final snap = await query.get();
    if (snap.docs.isEmpty) return const FeedPage(posts: [], hasMore: false);

    final uid = _uid;
    final postIds = snap.docs.map((d) => d.id).toList();

    // Resolve viewer state for this page in parallel.
    final results = await Future.wait([
      Future.wait(
        postIds.map(
          (id) => _posts.doc(id).collection('likes').doc(uid).get(),
        ),
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
    ]);
    final likeDocs = results[0];
    final bookmarkDocs = results[1];

    final posts = <Post>[];
    for (var i = 0; i < snap.docs.length; i++) {
      posts.add(
        PostModel.fromDoc(
          snap.docs[i],
          isLikedByMe: likeDocs[i].exists,
          isBookmarkedByMe: bookmarkDocs[i].exists,
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
    if (liked) {
      await likeRef.set({'createdAt': FieldValue.serverTimestamp()});
      final post = await _posts.doc(postId).get();
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
    } else {
      await likeRef.delete();
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
}
