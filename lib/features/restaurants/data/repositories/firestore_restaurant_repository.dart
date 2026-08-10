import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../../core/errors/app_exception.dart';
import '../../../feed/data/models/post_model.dart';
import '../../../feed/domain/entities/post.dart';
import '../../../feed/domain/repositories/feed_repository.dart';
import '../../domain/entities/restaurant.dart';
import '../../domain/repositories/restaurant_repository.dart';
import '../models/restaurant_model.dart';

class FirestoreRestaurantRepository implements RestaurantRepository {
  FirestoreRestaurantRepository({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;

  static const _pageSize = 12;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AppException('Not signed in');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _restaurants =>
      _firestore.collection('restaurants');

  @override
  Future<Restaurant> getById(String id) async {
    final results = await Future.wait([
      _restaurants.doc(id).get(),
      _restaurants.doc(id).collection('followers').doc(_uid).get(),
    ]);
    final doc = results[0];
    if (!doc.exists) throw const AppException('Restaurant not found');
    return RestaurantModel.fromDoc(doc, isFollowedByMe: results[1].exists);
  }

  @override
  Future<FeedPage> fetchPosts(
    String restaurantId, {
    Object? cursor,
    int limit = _pageSize,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('posts')
        .where('restaurantId', isEqualTo: restaurantId)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (cursor is DocumentSnapshot) query = query.startAfterDocument(cursor);

    final snap = await query.get();
    if (snap.docs.isEmpty) return const FeedPage(posts: [], hasMore: false);

    // Viewer like/bookmark state for this page.
    final uid = _uid;
    final results = await Future.wait([
      Future.wait(
        snap.docs.map(
          (d) => d.reference.collection('likes').doc(uid).get(),
        ),
      ),
      Future.wait(
        snap.docs.map(
          (d) => _firestore
              .collection('users')
              .doc(uid)
              .collection('bookmarks')
              .doc(d.id)
              .get(),
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
    String restaurantId, {
    required bool following,
  }) async {
    // Single edge write — followerCount is maintained by Cloud Functions.
    final followerRef =
        _restaurants.doc(restaurantId).collection('followers').doc(_uid);
    if (following) {
      await followerRef.set({'createdAt': FieldValue.serverTimestamp()});
    } else {
      await followerRef.delete();
    }
  }
}
