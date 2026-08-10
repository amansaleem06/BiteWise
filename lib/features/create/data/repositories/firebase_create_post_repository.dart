import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/media_upload_service.dart';
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
    // Prefix search on the lowercase name field.
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

    // Capture the creator's location so the restaurant appears on the
    // Nearby map. Best-effort: null if permission is denied.
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
