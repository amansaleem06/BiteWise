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
    // Prefer denormalized ratingAvg (written on publish / by Cloud Functions).
    try {
      final snap = await _firestore
          .collection('restaurants')
          .where('ratingAvg', isGreaterThan: 0)
          .orderBy('ratingAvg', descending: true)
          .limit(limit)
          .get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map(RestaurantModel.fromDoc).toList();
      }
    } catch (_) {
      // Fall through — field/index may be missing on older docs.
    }

    try {
      final snap = await _firestore
          .collection('restaurants')
          .where('ratingCount', isGreaterThan: 0)
          .orderBy('ratingCount', descending: true)
          .limit(limit * 3)
          .get();
      final ranked = snap.docs.map(RestaurantModel.fromDoc).toList()
        ..sort((a, b) {
          final ar = a.averageRating ?? 0;
          final br = b.averageRating ?? 0;
          final byAvg = br.compareTo(ar);
          if (byAvg != 0) return byAvg;
          return b.ratingCount.compareTo(a.ratingCount);
        });
      if (ranked.isNotEmpty) return ranked.take(limit).toList();
    } catch (_) {
      // Fall through to post-derived ranking.
    }

    // Last resort: aggregate from rated posts so Top Rated isn't empty when
    // restaurant docs never got ratingSum/ratingCount/ratingAvg backfilled.
    return _topRatedFromPosts(limit: limit);
  }

  Future<List<Restaurant>> _topRatedFromPosts({required int limit}) async {
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _firestore
          .collection('posts')
          .where('rating', isGreaterThan: 0)
          .orderBy('rating', descending: true)
          .limit(250)
          .get();
    } catch (_) {
      snap = await _firestore.collection('posts').limit(250).get();
    }

    final sums = <String, double>{};
    final counts = <String, int>{};
    final names = <String, String>{};

    for (final doc in snap.docs) {
      final data = doc.data();
      final restaurantId = (data['restaurantId'] as String?)?.trim() ?? '';
      final rating = (data['rating'] as num?)?.toDouble();
      if (restaurantId.isEmpty || rating == null || rating <= 0) continue;
      sums[restaurantId] = (sums[restaurantId] ?? 0) + rating;
      counts[restaurantId] = (counts[restaurantId] ?? 0) + 1;
      final name = (data['restaurantName'] as String?)?.trim();
      if (name != null && name.isNotEmpty) {
        names[restaurantId] = name;
      }
    }

    if (counts.isEmpty) return const [];

    final rankedIds = counts.keys.toList()
      ..sort((a, b) {
        final ar = (sums[a] ?? 0) / (counts[a] ?? 1);
        final br = (sums[b] ?? 0) / (counts[b] ?? 1);
        final byAvg = br.compareTo(ar);
        if (byAvg != 0) return byAvg;
        return (counts[b] ?? 0).compareTo(counts[a] ?? 0);
      });

    final take = rankedIds.take(limit).toList(growable: false);
    final restaurantSnaps = await Future.wait(
      take.map((id) => _firestore.collection('restaurants').doc(id).get()),
    );

    final byId = <String, Restaurant>{};
    for (final doc in restaurantSnaps) {
      if (!doc.exists) continue;
      byId[doc.id] = RestaurantModel.fromDoc(doc);
    }

    return [
      for (final id in take)
        if (byId.containsKey(id))
          Restaurant(
            id: id,
            name: byId[id]!.name,
            description: byId[id]!.description,
            coverUrl: byId[id]!.coverUrl,
            logoUrl: byId[id]!.logoUrl,
            city: byId[id]!.city,
            address: byId[id]!.address,
            phone: byId[id]!.phone,
            website: byId[id]!.website,
            cuisines: byId[id]!.cuisines,
            priceLevel: byId[id]!.priceLevel,
            claimed: byId[id]!.claimed,
            ownerId: byId[id]!.ownerId,
            followerCount: byId[id]!.followerCount,
            postCount: byId[id]!.postCount,
            ratingSum: sums[id] ?? byId[id]!.ratingSum,
            ratingCount: counts[id] ?? byId[id]!.ratingCount,
            openingHours: byId[id]!.openingHours,
            latitude: byId[id]!.latitude,
            longitude: byId[id]!.longitude,
          )
        else
          Restaurant(
            id: id,
            name: names[id] ?? 'Restaurant',
            ratingSum: sums[id] ?? 0,
            ratingCount: counts[id] ?? 0,
          ),
    ];
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
        .map(RestaurantModel.fromDoc)
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
