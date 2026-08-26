import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/restaurant.dart';
import '../../domain/entities/claim_status.dart';

/// Firestore (de)serialization for [Restaurant].
///
/// Document path: `restaurants/{restaurantId}`
/// Follows:       `restaurants/{restaurantId}/followers/{uid}`
abstract final class RestaurantModel {
  static Restaurant fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    bool isFollowedByMe = false,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};
    final hoursRaw = (data['openingHours'] as Map?) ?? const {};
    final location = data['location'] as GeoPoint?;
    final ratingAvg = (data['ratingAvg'] as num?)?.toDouble();
    var ratingSum = (data['ratingSum'] as num?)?.toDouble() ?? 0;
    var ratingCount = (data['ratingCount'] as num?)?.toInt() ?? 0;
    // Older docs may only have ratingAvg; keep averageRating usable.
    if (ratingCount <= 0 && ratingAvg != null && ratingAvg > 0) {
      ratingCount = 1;
      ratingSum = ratingAvg;
    } else if (ratingCount > 0 && ratingSum <= 0 && ratingAvg != null) {
      ratingSum = ratingAvg * ratingCount;
    }
    return Restaurant(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      description: data['description'] as String?,
      coverUrl: data['coverUrl'] as String?,
      logoUrl: data['logoUrl'] as String?,
      city: data['city'] as String?,
      address: data['address'] as String?,
      phone: data['phone'] as String?,
      website: data['website'] as String?,
      cuisines:
          ((data['cuisines'] as List?) ?? const []).whereType<String>().toList(),
      priceLevel: (data['priceLevel'] as num?)?.toInt(),
      claimed: (data['claimed'] as bool?) ?? false,
      claimStatus: ClaimStatus.fromKey(
        data['claimStatus'] as String?,
        claimed: (data['claimed'] as bool?) ?? false,
      ),
      ownerId: data['ownerId'] as String?,
      googlePlaceId: data['googlePlaceId'] as String?,
      followerCount: (data['followerCount'] as num?)?.toInt() ?? 0,
      postCount: (data['postCount'] as num?)?.toInt() ?? 0,
      ratingSum: ratingSum,
      ratingCount: ratingCount,
      openingHours: {
        for (final e in hoursRaw.entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      },
      menuNotes: data['menuNotes'] as String?,
      isFollowedByMe: isFollowedByMe,
      latitude: location?.latitude,
      longitude: location?.longitude,
    );
  }
}
