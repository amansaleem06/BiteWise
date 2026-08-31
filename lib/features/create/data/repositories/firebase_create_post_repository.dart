import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../../../core/services/places_search_service.dart';
import '../../../../core/services/restaurant_page_voice.dart';
import '../../../../core/utils/locale_currency.dart';
import '../../../feed/domain/entities/post.dart';
import '../../../restaurants/domain/entities/restaurant_ref.dart';
import '../../domain/repositories/create_post_repository.dart';

class FirebaseCreatePostRepository implements CreatePostRepository {
  FirebaseCreatePostRepository({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
    MediaUploadService? uploadService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance,
        _uploads = uploadService ?? MediaUploadService();

  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;
  final MediaUploadService _uploads;

  fb.User get _user {
    final user = _auth.currentUser;
    if (user == null) throw const AppException('Not signed in');
    return user;
  }

  @override
  Future<List<RestaurantRef>> searchRestaurants(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final snap = await _firestore
        .collection('restaurants')
        .where('nameLower', isGreaterThanOrEqualTo: q)
        .where('nameLower', isLessThan: '$q\uf8ff')
        .limit(10)
        .get();
    return snap.docs
        .map(
          (d) => RestaurantRef(
            id: d.id,
            name: (d.data()['name'] as String?) ?? '',
            city: d.data()['city'] as String?,
          ),
        )
        .toList();
  }

  @override
  Future<RestaurantRef> createRestaurantStub(String name) async {
    final trimmed = name.trim();
    final position = await LocationService().currentPosition();

    final doc = await _firestore.collection('restaurants').add({
      'name': trimmed,
      'nameLower': trimmed.toLowerCase(),
      'claimed': false,
      'claimStatus': 'unclaimed',
      'ownerId': null,
      'createdBy': _user.uid,
      'followerCount': 0,
      'postCount': 0,
      'ratingSum': 0,
      'ratingCount': 0,
      if (position != null) ...{
        'location': GeoPoint(position.latitude, position.longitude),
        'hasLocation': true,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
    return RestaurantRef(id: doc.id, name: trimmed);
  }

  @override
  Future<RestaurantRef> upsertRestaurantFromPlace(PlaceSuggestion place) async {
    final name = place.name.trim().length > 80
        ? place.name.trim().substring(0, 80)
        : place.name.trim();
    if (name.length < 2) {
      throw const AppException('Restaurant name is too short');
    }

    final existing = await _firestore
        .collection('restaurants')
        .where('googlePlaceId', isEqualTo: place.placeId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      final d = existing.docs.first;
      final data = d.data();
      return RestaurantRef(
        id: d.id,
        name: (data['name'] as String?) ?? name,
        city: (data['city'] as String?) ?? place.city,
      );
    }

    final hasCoords = place.latitude != null && place.longitude != null;
    final doc = await _firestore.collection('restaurants').add({
      'name': name,
      'nameLower': name.toLowerCase(),
      'googlePlaceId': place.placeId,
      if (place.address != null) 'address': place.address,
      if (place.city != null) 'city': place.city,
      'claimed': false,
      'claimStatus': 'unclaimed',
      'ownerId': null,
      'createdBy': _user.uid,
      'followerCount': 0,
      'postCount': 0,
      'ratingSum': 0,
      'ratingCount': 0,
      if (hasCoords) ...{
        'location': GeoPoint(place.latitude!, place.longitude!),
        'hasLocation': true,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    return RestaurantRef(
      id: doc.id,
      name: name,
      city: place.city,
    );
  }

  @override
  Future<void> publishPost({
    required List<XFile> images,
    RestaurantRef? restaurant,
    String? dishName,
    required String caption,
    double? rating,
    double? price,
    String? currencyCode,
    required List<String> tags,
    bool asRestaurantPage = false,
    PagePostKind pageKind = PagePostKind.plate,
    void Function(double progress)? onProgress,
  }) async {
    final user = _user;
    if (rating != null && restaurant == null) {
      throw const AppException('Tag a restaurant to publish a rating.');
    }

    final uploaded = await _uploads.uploadImages(
      uid: user.uid,
      files: images,
      onProgress: onProgress,
    );

    final restaurantId = restaurant?.id;
    RestaurantPageVoice? page;
    var postingAsPage = false;
    if (asRestaurantPage) {
      page = await RestaurantPageVoice.load(
        firestore: _firestore,
        auth: _auth,
      );
      postingAsPage = page != null;
      if (!postingAsPage && restaurantId != null && restaurantId.isNotEmpty) {
        final restSnap =
            await _firestore.collection('restaurants').doc(restaurantId).get();
        final data = restSnap.data();
        final ownerId = data?['ownerId'] as String?;
        final claimed = (data?['claimed'] as bool?) ?? false;
        final claimStatus = data?['claimStatus'] as String?;
        postingAsPage = ownerId == user.uid &&
            (claimed || claimStatus == 'claimed' || claimStatus == 'pending');
        if (postingAsPage) {
          page = RestaurantPageVoice(
            id: restaurantId,
            name: (data?['name'] as String?)?.trim() ?? restaurant?.name ?? '',
            logoUrl: data?['logoUrl'] as String? ?? restaurant?.logoUrl,
          );
        }
      }
    }

    final taggedId = page?.id ?? restaurant?.id ?? '';
    final taggedName = page?.name ?? restaurant?.name ?? '';
    await _firestore.collection('posts').add({
      'authorId': user.uid,
      'authorName': postingAsPage
          ? (page?.name.isNotEmpty == true
              ? page!.name
              : (taggedName.isNotEmpty ? taggedName : user.displayName ?? ''))
          : (user.displayName ?? ''),
      'authorPhotoUrl': postingAsPage ? page?.logoUrl : user.photoURL,
      'restaurantId': taggedId,
      'restaurantName': taggedName,
      if (postingAsPage && taggedId.isNotEmpty) 'asRestaurantId': taggedId,
      if (postingAsPage) 'pageKind': pageKind.key,
      if (!postingAsPage && taggedId.isNotEmpty) ...{
        'mentionApproved': false,
        'mentionHidden': false,
      },
      'dishId': null,
      'dishName': (dishName?.trim().isEmpty ?? true) ? null : dishName!.trim(),
      'caption': caption.trim(),
      'media': [
        for (final m in uploaded)
          {
            'url': m.url,
            'type': 'image',
            'aspectRatio': m.aspectRatio,
          },
      ],
      'rating': rating,
      'price': price,
      'currencyCode': (currencyCode != null && currencyCode.trim().isNotEmpty)
          ? currencyCode.trim().toUpperCase()
          : LocaleCurrency.code,
      'tags': tags,
      'likeCount': 0,
      'commentCount': 0,
      'shareCount': 0,
      'trendingScore': 0,
      'restaurantVerified': postingAsPage,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (taggedId.isEmpty) return;

    final restaurantRef =
        _firestore.collection('restaurants').doc(taggedId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(restaurantRef);
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      final postCount = ((data['postCount'] as num?)?.toInt() ?? 0) + 1;
      final updates = <String, dynamic>{
        'postCount': postCount,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (rating != null) {
        final ratingSum =
            ((data['ratingSum'] as num?)?.toDouble() ?? 0) + rating;
        final ratingCount = ((data['ratingCount'] as num?)?.toInt() ?? 0) + 1;
        updates['ratingSum'] = ratingSum;
        updates['ratingCount'] = ratingCount;
        updates['ratingAvg'] = ratingCount == 0 ? 0 : ratingSum / ratingCount;
      } else if (data['ratingAvg'] == null &&
          ((data['ratingCount'] as num?)?.toInt() ?? 0) > 0) {
        final sum = (data['ratingSum'] as num?)?.toDouble() ?? 0;
        final count = (data['ratingCount'] as num?)?.toInt() ?? 0;
        updates['ratingAvg'] = count == 0 ? 0 : sum / count;
      }
      tx.update(restaurantRef, updates);
    });
  }
}
