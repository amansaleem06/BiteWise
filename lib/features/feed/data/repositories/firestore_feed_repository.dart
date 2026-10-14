import 'dart:math' as math;

import '../../../../core/services/content_visibility.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/social_notification_writer.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/discovery_location.dart';
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
    final visibility = await ContentVisibility.load(_firestore);
    if (!visibility.allows(results[0])) {
      throw const AppException('Post not found');
    }
    return PostModel.fromDoc(
      results[0],
      isLikedByMe: results[1].exists,
      isBookmarkedByMe: results[2].exists,
      isRepostedByMe: results[3].exists,
    );
  }

  @override
  Future<FeedPage> fetchForYou({
    Object? cursor,
    int limit = _pageSize,
    DiscoveryLocation? location,
  }) async {
    if (location == null || location.scope == DiscoveryScope.global) {
      Query<Map<String, dynamic>> query =
          _posts.orderBy('createdAt', descending: true).limit(limit);
      if (cursor is DocumentSnapshot<Map<String, dynamic>>) {
        query = query.startAfterDocument(cursor);
      }
      return _runPageQuery(query, limit);
    }

    var restaurantIds = await _restaurantIdsFor(location);
    var local = await _fetchScopedDocs(restaurantIds, cursor, limit);

    if (location.scope == DiscoveryScope.nearby &&
        local.docs.length < limit &&
        location.latitude != null &&
        location.longitude != null) {
      for (final radiusKm in [75.0, 200.0]) {
        restaurantIds = await _restaurantIdsForNearby(
          location.latitude!,
          location.longitude!,
          radiusKm,
        );
        local = await _fetchScopedDocs(restaurantIds, cursor, limit);
        if (local.docs.length >= limit) break;
      }
    } else if (location.scope == DiscoveryScope.city &&
        local.docs.length < limit &&
        location.country?.isNotEmpty == true) {
      final countryIds = await _restaurantIdsForCountry(location.country!);
      restaurantIds = {...restaurantIds, ...countryIds}.toList();
      local = await _fetchScopedDocs(restaurantIds, cursor, limit);
    }

    final localDocs = local.docs.take(limit).toList();
    final remaining = limit - localDocs.length;
    final globalDocs = remaining == 0
        ? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]
        : await _fetchGlobalDocs(cursor, remaining);
    final localIds = localDocs.map((doc) => doc.id).toSet();
    final fallbackDocs =
        globalDocs.docs.where((doc) => !localIds.contains(doc.id)).toList();
    final combined = [...localDocs, ...fallbackDocs].take(limit).toList();
    if (combined.isEmpty) return const FeedPage(posts: [], hasMore: false);

    final page = await _pageFromDocs(combined);
    return FeedPage(
      posts: page.posts,
      cursor: combined.last,
      hasMore: local.hasMore || globalDocs.hasMore,
      primaryCount: localDocs.length,
    );
  }

  Future<List<String>> _restaurantIdsFor(DiscoveryLocation location) async {
    switch (location.scope) {
      case DiscoveryScope.city:
        final city = location.city?.trim() ?? '';
        if (city.isEmpty) return const [];
        final results = await Future.wait([
          _firestore
              .collection('restaurants')
              .where('city', isEqualTo: city)
              .limit(250)
              .get(),
          _firestore
              .collection('restaurants')
              .where('cityLower', isEqualTo: city.toLowerCase())
              .limit(250)
              .get(),
          _firestore.collection('restaurants').limit(500).get(),
        ]);
        final ids = <String>{
          ...results[0].docs.map((doc) => doc.id),
          ...results[1].docs.map((doc) => doc.id),
        };
        final normalizedCity = city.toLowerCase();
        final country = location.country?.trim().toLowerCase();
        for (final doc in results[2].docs) {
          final data = doc.data();
          final stored = (data['city'] as String?)?.trim().toLowerCase() ?? '';
          if (stored == normalizedCity &&
              (country == null ||
                  country.isEmpty ||
                  _matchesCountry(data, country))) {
            ids.add(doc.id);
          }
        }
        if (country != null && country.isNotEmpty) {
          final cityDocs = [...results[0].docs, ...results[1].docs];
          final cityDataById = {
            for (final doc in cityDocs) doc.id: doc.data(),
          };
          ids.removeWhere((id) =>
              cityDataById.containsKey(id) &&
              !_matchesCountry(cityDataById[id]!, country));
        }
        return ids.take(120).toList();
      case DiscoveryScope.country:
        return _restaurantIdsForCountry(location.country ?? '');
      case DiscoveryScope.nearby:
        if (location.latitude == null || location.longitude == null) {
          return const [];
        }
        return _restaurantIdsForNearby(
          location.latitude!,
          location.longitude!,
          25,
        );
      case DiscoveryScope.global:
        return const [];
    }
  }

  Future<List<String>> _restaurantIdsForCountry(String country) async {
    final normalized = country.trim().toLowerCase();
    if (normalized.isEmpty) return const [];
    final results = await Future.wait([
      _firestore
          .collection('restaurants')
          .where('countryLower', isEqualTo: normalized)
          .limit(250)
          .get(),
      _firestore
          .collection('restaurants')
          .where('country', isEqualTo: country.trim())
          .limit(250)
          .get(),
      _firestore.collection('restaurants').limit(500).get(),
    ]);
    final ids = <String>{};
    for (final doc in results[0].docs) {
      ids.add(doc.id);
    }
    for (final doc in results[1].docs) {
      ids.add(doc.id);
    }
    // Older restaurant records have no country field; their formatted address
    // still lets us match the country without changing existing data.
    for (final doc in results[2].docs) {
      if (_matchesCountry(doc.data(), normalized)) ids.add(doc.id);
    }
    return ids.take(120).toList();
  }

  bool _matchesCountry(Map<String, dynamic> data, String normalizedCountry) {
    final stored = (data['country'] as String?) ??
        (data['address'] as String?)?.split(',').last.trim();
    return stored?.trim().toLowerCase() == normalizedCountry;
  }

  Future<List<String>> _restaurantIdsForNearby(
    double latitude,
    double longitude,
    double radiusKm,
  ) async {
    final snap = await _firestore
        .collection('restaurants')
        .where('hasLocation', isEqualTo: true)
        .limit(500)
        .get();
    final matches = <({String id, double distance})>[];
    for (final doc in snap.docs) {
      final point = doc.data()['location'];
      if (point is! GeoPoint) continue;
      final distance = _distanceKm(
        latitude,
        longitude,
        point.latitude,
        point.longitude,
      );
      if (distance <= radiusKm) matches.add((id: doc.id, distance: distance));
    }
    matches.sort((a, b) => a.distance.compareTo(b.distance));
    return matches.take(120).map((item) => item.id).toList();
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = (lat2 - lat1) * 0.017453292519943295;
    final dLon = (lon2 - lon1) * 0.017453292519943295;
    final a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        math.cos(lat1 * 0.017453292519943295) *
            math.cos(lat2 * 0.017453292519943295) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  Future<
          ({
            List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
            bool hasMore
          })>
      _fetchScopedDocs(
          List<String> restaurantIds, Object? cursor, int limit) async {
    if (restaurantIds.isEmpty) {
      return (
        docs: <QueryDocumentSnapshot<Map<String, dynamic>>>[],
        hasMore: false,
      );
    }
    final queries = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
    for (var offset = 0; offset < restaurantIds.length; offset += 30) {
      final ids = restaurantIds.skip(offset).take(30).toList();
      Query<Map<String, dynamic>> query = _posts
          .where('restaurantId', whereIn: ids)
          .orderBy('createdAt', descending: true)
          .limit(limit);
      if (cursor is DocumentSnapshot<Map<String, dynamic>>) {
        query = query.startAfterDocument(cursor);
      }
      queries.add(query.get());
    }
    final snapshots = await Future.wait(queries);
    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[
      for (final snap in snapshots) ...snap.docs,
    ]..sort((a, b) {
        final aTime =
            (a.data()['createdAt'] as Timestamp?)?.microsecondsSinceEpoch ?? 0;
        final bTime =
            (b.data()['createdAt'] as Timestamp?)?.microsecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
    final unique = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in docs) {
      unique.putIfAbsent(doc.id, () => doc);
    }
    final uniqueDocs = unique.values.toList();
    return (
      docs: uniqueDocs,
      hasMore: uniqueDocs.length > limit ||
          snapshots.any((snap) => snap.docs.length == limit),
    );
  }

  Future<
      ({
        List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
        bool hasMore
      })> _fetchGlobalDocs(Object? cursor, int limit) async {
    Query<Map<String, dynamic>> query =
        _posts.orderBy('createdAt', descending: true).limit(limit);
    if (cursor is DocumentSnapshot<Map<String, dynamic>>) {
      query = query.startAfterDocument(cursor);
    }
    final snap = await query.get();
    return (docs: snap.docs, hasMore: snap.docs.length == limit);
  }

  Future<FeedPage> _pageFromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (docs.isEmpty) return const FeedPage(posts: [], hasMore: false);
    final uid = _uid;
    final postIds = docs.map((doc) => doc.id).toList();
    final results = await Future.wait([
      Future.wait(postIds
          .map((id) => _posts.doc(id).collection('likes').doc(uid).get())),
      Future.wait(postIds.map((id) => _firestore
          .collection('users')
          .doc(uid)
          .collection('bookmarks')
          .doc(id)
          .get())),
      Future.wait(postIds.map((id) => _firestore
          .collection('users')
          .doc(uid)
          .collection('reposts')
          .doc(id)
          .get())),
    ]);
    final visibility = await ContentVisibility.load(_firestore);
    final posts = <Post>[];
    for (var i = 0; i < docs.length; i++) {
      if (!visibility.allows(docs[i])) continue;
      posts.add(PostModel.fromDoc(
        docs[i],
        isLikedByMe: results[0][i].exists,
        isBookmarkedByMe: results[1][i].exists,
        isRepostedByMe: results[2][i].exists,
      ));
    }
    return FeedPage(
        posts: posts, cursor: docs.last, hasMore: docs.length == limit);
  }

  @override
  Future<FeedPage> fetchFollowing({
    Object? cursor,
    int limit = _pageSize,
  }) async {
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
  Future<FeedPage> fetchBookmarks({
    Object? cursor,
    int limit = _pageSize,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .doc(_uid)
        .collection('bookmarks')
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (cursor is DocumentSnapshot) query = query.startAfterDocument(cursor);
    final snap = await query.get();
    if (snap.docs.isEmpty) return const FeedPage(posts: [], hasMore: false);

    final visibility = await ContentVisibility.load(_firestore);
    final posts = <Post>[];
    for (final edge in snap.docs) {
      final postSnap = await _posts.doc(edge.id).get();
      if (!visibility.allows(postSnap)) continue;
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

    final visibility = await ContentVisibility.load(_firestore);
    final posts = <Post>[];
    for (var i = 0; i < snap.docs.length; i++) {
      if (!visibility.allows(snap.docs[i])) continue;
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
    final authorId = data['authorId'] as String?;
    final asRestaurantId = data['asRestaurantId'] as String?;
    final ownsOfficialPage = asRestaurantId != null &&
        asRestaurantId.isNotEmpty &&
        await _ownsRestaurant(asRestaurantId);
    if (authorId != uid && !ownsOfficialPage) {
      throw const AppException('You can only delete your own posts.');
    }

    final restaurantId = data['restaurantId'] as String?;
    final rating = (data['rating'] as num?)?.toDouble();
    final media = data['media'] as List?;

    await postRef.delete();

    if (restaurantId != null && restaurantId.isNotEmpty) {
      try {
        await _decrementRestaurantStats(
          restaurantId: restaurantId,
          rating: rating,
        );
      } catch (_) {}
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

  Future<bool> _ownsRestaurant(String restaurantId) async {
    final snap =
        await _firestore.collection('restaurants').doc(restaurantId).get();
    return snap.data()?['ownerId'] == _uid;
  }

  Future<void> _decrementRestaurantStats({
    required String restaurantId,
    required double? rating,
  }) async {
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
        final ratingSum = ((d['ratingSum'] as num?)?.toDouble() ?? 0) - rating;
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
