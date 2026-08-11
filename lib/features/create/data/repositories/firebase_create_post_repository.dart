import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../../../core/services/places_search_service.dart';
import '../../../../core/utils/locale_currency.dart';
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
    required RestaurantRef restaurant,
    String? dishName,
    required String caption,
    double? rating,
    double? price,
    required List<String> tags,
    void Function(double progress)? onProgress,
  }) async {
    final user = _user;

    final uploaded = await _uploads.uploadImages(
      uid: user.uid,
      files: images,
      onProgress: onProgress,
    );

    await _firestore.collection('posts').add({
      'authorId': user.uid,
      'authorName': user.displayName ?? '',
      'authorPhotoUrl': user.photoURL,
      'restaurantId': restaurant.id,
      'restaurantName': restaurant.name,
      'dishId': null, // dish entities arrive with the Dishes milestone
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
      'currencyCode': LocaleCurrency.code,
      'tags': tags,
      'likeCount': 0,
      'commentCount': 0,
      'trendingScore': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
