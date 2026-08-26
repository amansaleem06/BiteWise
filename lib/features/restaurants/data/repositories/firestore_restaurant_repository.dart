import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/places_search_service.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../create/data/repositories/firebase_create_post_repository.dart';
import '../../../feed/data/models/post_model.dart';
import '../../../feed/domain/entities/post.dart';
import '../../../feed/domain/repositories/feed_repository.dart';
import '../../domain/claim_matcher.dart';
import '../../domain/entities/claim_status.dart';
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

  @override
  Future<void> saveBusinessDetails({
    required String businessName,
    required String address,
    required String phone,
    String? businessEmail,
  }) async {
    final uid = _uid;
    await _firestore.collection('users').doc(uid).update({
      'businessName': businessName.trim(),
      'businessAddress': address.trim(),
      'businessPhone': phone.trim(),
      if (businessEmail != null && businessEmail.trim().isNotEmpty)
        'businessEmail': businessEmail.trim(),
      'businessVerificationStatus': BusinessVerificationStatus.pending.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<ClaimResult> claimFromPlace(PlaceSuggestion place) async {
    final createRepo = FirebaseCreatePostRepository(firestore: _firestore);
    final ref = await createRepo.upsertRestaurantFromPlace(place);
    return claimRestaurant(ref.id);
  }

  @override
  Future<ClaimResult> claimRestaurant(String restaurantId) async {
    final uid = _uid;
    final userSnap = await _firestore.collection('users').doc(uid).get();
    final user = userSnap.data() ?? {};
    if ((user['role'] as String?) != UserRole.restaurantOwner.name) {
      throw const AppException('Only business accounts can claim a restaurant.');
    }

    final owned = user['ownedRestaurantId'] as String?;
    if (owned != null && owned.isNotEmpty && owned != restaurantId) {
      throw const AppException(
        'You already have a claimed restaurant on this account.',
      );
    }

    final restaurantRef = _restaurants.doc(restaurantId);
    late ClaimStatus nextStatus;

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(restaurantRef);
      if (!snap.exists) {
        throw const AppException('Restaurant not found.');
      }
      final data = snap.data() ?? {};
      final existingOwner = data['ownerId'] as String?;
      final existingClaim = ClaimStatus.fromKey(
        data['claimStatus'] as String?,
        claimed: (data['claimed'] as bool?) ?? false,
      );

      if (existingClaim == ClaimStatus.claimed &&
          existingOwner != null &&
          existingOwner != uid) {
        throw const AppException(
          'This restaurant already has a verified owner.',
        );
      }
      if (existingClaim == ClaimStatus.pending &&
          existingOwner != null &&
          existingOwner != uid) {
        throw const AppException(
          'Another owner already submitted a claim for this listing.',
        );
      }

      nextStatus = ClaimStatus.claimed;

      tx.update(restaurantRef, {
        'ownerId': uid,
        'claimed': true,
        'claimStatus': ClaimStatus.claimed.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    final userUpdates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      'ownedRestaurantId': restaurantId,
      'pendingClaimRestaurantId': FieldValue.delete(),
      'businessVerificationStatus':
          BusinessVerificationStatus.verified.name,
    };
    await _firestore.collection('users').doc(uid).update(userUpdates);

    return ClaimResult(restaurantId: restaurantId, status: nextStatus);
  }

  @override
  Future<void> finalizePendingClaim() async {
    final uid = _uid;
    final userSnap = await _firestore.collection('users').doc(uid).get();
    final pending = userSnap.data()?['pendingClaimRestaurantId'] as String?;
    if (pending == null || pending.isEmpty) return;
    await claimRestaurant(pending);
  }
}
