import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../auth/data/models/user_model.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../feed/data/models/post_model.dart';
import '../../../feed/domain/entities/post.dart';
import '../../../restaurants/data/models/restaurant_model.dart';
import '../../../restaurants/domain/entities/restaurant.dart';
import '../../domain/repositories/explore_repository.dart';

class FirestoreExploreRepository implements ExploreRepository {
  FirestoreExploreRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<List<Post>> fetchTrendingPosts({int limit = 30}) async {
    // trendingScore = time-decayed engagement, recomputed hourly by a
    // scheduled Cloud Function.
    final snap = await _firestore
        .collection('posts')
        .orderBy('trendingScore', descending: true)
        .limit(limit)
        .get();
    // Viewer like/bookmark state is skipped here deliberately: trending is
    // a browse surface; the post detail screen resolves exact state.
    return snap.docs.map(PostModel.fromDoc).toList();
  }

  @override
  Future<List<Restaurant>> fetchTopRatedRestaurants({int limit = 20}) async {
    try {
      final snap = await _firestore
          .collection('restaurants')
          .orderBy('ratingAvg', descending: true)
          .limit(limit)
          .get();
      final ranked = snap.docs
          .map(RestaurantModel.fromDoc)
          .where((r) => r.ratingCount > 0)
          .toList();
      if (ranked.isNotEmpty) return ranked;
    } catch (_) {
      // Fall through to client-side ranking when index/field is missing.
    }

    final snap = await _firestore.collection('restaurants').limit(80).get();
    final ranked = snap.docs
        .map(RestaurantModel.fromDoc)
        .where((r) => r.ratingCount > 0)
        .toList()
      ..sort((a, b) {
        final ar = a.averageRating ?? 0;
        final br = b.averageRating ?? 0;
        return br.compareTo(ar);
      });
    return ranked.take(limit).toList();
  }

  @override
  Future<List<AppUser>> searchUsers(String query, {int limit = 15}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final snap = await _firestore
        .collection('users')
        .where('displayNameLower', isGreaterThanOrEqualTo: q)
        .where('displayNameLower', isLessThan: '$q')
        .limit(limit)
        .get();
    return snap.docs.map(UserModel.fromDoc).toList();
  }

  @override
  Future<List<Restaurant>> searchRestaurants(
    String query, {
    int limit = 15,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final snap = await _firestore
        .collection('restaurants')
        .where('nameLower', isGreaterThanOrEqualTo: q)
        .where('nameLower', isLessThan: '$q')
        .limit(limit)
        .get();
    return snap.docs.map(RestaurantModel.fromDoc).toList();
  }

  @override
  Future<List<Restaurant>> fetchNearbyRestaurants({
    required double latitude,
    required double longitude,
    int limit = 50,
  }) async {
    final snap = await _firestore
        .collection('restaurants')
        .where('hasLocation', isEqualTo: true)
        .limit(200)
        .get();

    double squaredDistance(Restaurant r) {
      final dLat = (r.latitude ?? 0) - latitude;
      final dLng = (r.longitude ?? 0) - longitude;
      return dLat * dLat + dLng * dLng;
    }

    final restaurants = snap.docs
        .map((d) => RestaurantModel.fromDoc(d))
        .where((r) => r.hasLocation)
        .toList()
      ..sort((a, b) => squaredDistance(a).compareTo(squaredDistance(b)));
    return restaurants.take(limit).toList();
  }

  @override
  Future<List<Post>> searchByTag(String tag, {int limit = 30}) async {
    final t = tag.trim().toLowerCase().replaceFirst('#', '');
    if (t.isEmpty) return const [];
    final snap = await _firestore
        .collection('posts')
        .where('tags', arrayContains: t)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(PostModel.fromDoc).toList();
  }
}
