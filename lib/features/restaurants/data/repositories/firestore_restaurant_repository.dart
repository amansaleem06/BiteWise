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
  Future<ClaimResult> claimFromPlace(
    PlaceSuggestion place, {
    required String proofUrl,
  }) async {
    final createRepo = FirebaseCreatePostRepository(firestore: _firestore);
    final ref = await createRepo.upsertRestaurantFromPlace(place);
    return claimRestaurant(
      ref.id,
      proofUrl: proofUrl,
      placeDetails: place,
    );
  }

  @override
  Future<ClaimResult> claimRestaurant(
    String restaurantId, {
    required String proofUrl,
    PlaceSuggestion? placeDetails,
  }) async {
    final uid = _uid;
    if (proofUrl.trim().isEmpty) {
      throw const AppException(
        'Upload a photo of your storefront sign or business license.',
      );
    }

    final userSnap = await _firestore.collection('users').doc(uid).get();
    final user = userSnap.data() ?? {};
    if ((user['role'] as String?) != UserRole.restaurantOwner.name) {
      throw const AppException('Only business accounts can claim a restaurant.');
    }

    final owned = user['ownedRestaurantId'] as String?;
    if (owned != null && owned.isNotEmpty && owned != restaurantId) {
      throw const AppException(
        'You already have a verified restaurant on this account.',
      );
    }

    final pending = user['pendingClaimRestaurantId'] as String?;
    if (pending != null && pending.isNotEmpty && pending != restaurantId) {
      throw const AppException(
        'You already have a claim under review. Wait for that review, or '
        'email tastewise2026@gmail.com to cancel it.',
      );
    }

    final restaurantRef = _restaurants.doc(restaurantId);
    final snap = await restaurantRef.get();
    if (!snap.exists) {
      throw const AppException('Restaurant not found.');
    }
    final data = snap.data() ?? {};
    var details = placeDetails;
    final storedPlaceId = (data['googlePlaceId'] as String?) ?? '';
    if (details == null && storedPlaceId.isNotEmpty) {
      try {
        details = await PlacesSearchService().fetchPlaceDetails(storedPlaceId);
      } catch (_) {
        // Still accept the claim request; listing phone may be missing.
      }
    }
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

    final listingName =
        (details?.name.isNotEmpty == true
            ? details!.name
            : data['name'] as String?) ??
        '';
    final listingAddress = details?.address ?? data['address'] as String?;
    final listingPhone = details?.phone ?? data['phone'] as String?;

    final businessName =
        ((user['businessName'] as String?) ?? '').trim();
    final businessAddress =
        ((user['businessAddress'] as String?) ?? '').trim();
    final businessPhone =
        ((user['businessPhone'] as String?) ?? '').trim();
    final businessEmail =
        ((user['businessEmail'] as String?) ?? '').trim();

    if (businessName.isNotEmpty &&
        listingName.isNotEmpty &&
        !ClaimMatcher.isStrongMatch(
          businessName: businessName,
          businessAddress: businessAddress,
          restaurantName: listingName,
          restaurantAddress: listingAddress,
        )) {
      throw const AppException(
        'That Maps listing does not match the business name and address '
        'you entered. Check the spelling, or pick the listing that matches '
        'your signup details.',
      );
    }

    if (listingPhone != null &&
        listingPhone.trim().isNotEmpty &&
        businessPhone.isNotEmpty &&
        !ClaimMatcher.phonesMatch(businessPhone, listingPhone)) {
      throw AppException(
        'The phone on this Google listing is $listingPhone. '
        'Enter that same number in your business details — it is a check '
        'that you know the public listing, not a secret code.',
      );
    }

    final existingCode = user['pendingClaimCode'] as String?;
    final claimCode = (existingCode != null &&
            existingCode.startsWith('TW-') &&
            pending == restaurantId)
        ? existingCode
        : ClaimMatcher.generateCode();

    await restaurantRef.collection('claimRequests').doc(uid).set({
      'status': ClaimStatus.pending.name,
      'claimCode': claimCode,
      'proofUrl': proofUrl.trim(),
      'businessName': businessName,
      'businessAddress': businessAddress,
      'businessPhone': businessPhone,
      'businessEmail': businessEmail,
      'restaurantName': listingName,
      'mapsAddress': listingAddress,
      'mapsPhone': listingPhone,
      'googlePlaceId': details?.placeId ?? data['googlePlaceId'] as String?,
      'mapsWebsite': details?.website ?? data['website'] as String?,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('users').doc(uid).update({
      'pendingClaimRestaurantId': restaurantId,
      'pendingClaimCode': claimCode,
      'businessVerificationStatus':
          BusinessVerificationStatus.pending.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ClaimResult(
      restaurantId: restaurantId,
      status: ClaimStatus.pending,
      claimCode: claimCode,
    );
  }

  @override
  Future<void> finalizePendingClaim() async {
    // Instant approve on launch was the old trust hole. Claims stay
    // pending until TasteWise support marks the request approved.
  }

  @override
  Future<void> updatePage({
    required String restaurantId,
    String? description,
    String? website,
    String? phone,
    String? menuNotes,
    String? logoUrl,
    String? coverUrl,
  }) async {
    final uid = _uid;
    final snap = await _restaurants.doc(restaurantId).get();
    if (!snap.exists) throw const AppException('Restaurant not found.');
    if (snap.data()?['ownerId'] != uid) {
      throw const AppException('Only the page owner can edit this restaurant.');
    }
    await _restaurants.doc(restaurantId).update({
      if (description != null) 'description': description.trim(),
      if (website != null) 'website': website.trim(),
      if (phone != null) 'phone': phone.trim(),
      if (menuNotes != null) 'menuNotes': menuNotes.trim(),
      if (logoUrl != null) 'logoUrl': logoUrl,
      if (coverUrl != null) 'coverUrl': coverUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setGuestFeedMode(String restaurantId, GuestFeedMode mode) async {
    final uid = _uid;
    final snap = await _restaurants.doc(restaurantId).get();
    if (!snap.exists) throw const AppException('Restaurant not found.');
    if (snap.data()?['ownerId'] != uid) {
      throw const AppException('Only the page owner can change this setting.');
    }
    await _restaurants.doc(restaurantId).update({
      'guestFeedMode': mode.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
