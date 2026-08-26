import 'package:equatable/equatable.dart';

import 'claim_status.dart';

/// Full restaurant profile.
///
/// Stub restaurants (created while posting) have most fields empty until
/// an owner claims and completes the profile.
class Restaurant extends Equatable {
  const Restaurant({
    required this.id,
    required this.name,
    this.description,
    this.coverUrl,
    this.logoUrl,
    this.city,
    this.address,
    this.phone,
    this.website,
    this.cuisines = const [],
    this.priceLevel,
    this.claimed = false,
    this.claimStatus = ClaimStatus.unclaimed,
    this.ownerId,
    this.googlePlaceId,
    this.followerCount = 0,
    this.postCount = 0,
    this.ratingSum = 0,
    this.ratingCount = 0,
    this.openingHours = const {},
    this.menuNotes,
    this.isFollowedByMe = false,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String? description;
  final String? coverUrl;
  final String? logoUrl;
  final String? city;
  final String? address;
  final String? phone;
  final String? website;
  final List<String> cuisines;

  /// 1–4 ($ to $$$$), null if unknown.
  final int? priceLevel;

  final bool claimed;
  final ClaimStatus claimStatus;
  final String? ownerId;
  final String? googlePlaceId;
  final int followerCount;
  final int postCount;

  /// Aggregated from post ratings (denormalized; maintained server-side later).
  final double ratingSum;
  final int ratingCount;

  /// e.g. {'mon': '11:00–22:00'} — keys: mon..sun. Empty = unknown.
  final Map<String, String> openingHours;
  final String? menuNotes;

  final bool isFollowedByMe;

  /// Coordinates, set when the restaurant was created with location or when
  /// an owner completes the profile. Null = not shown on the map.
  final double? latitude;
  final double? longitude;

  bool get isClaimed => claimStatus == ClaimStatus.claimed || claimed;
  bool get isPendingClaim => claimStatus == ClaimStatus.pending;
  bool get isUnclaimed =>
      claimStatus == ClaimStatus.unclaimed && !claimed;

  bool get hasLocation => latitude != null && longitude != null;

  double? get averageRating =>
      ratingCount > 0 ? ratingSum / ratingCount : null;

  String? get priceLevelDisplay =>
      priceLevel != null ? r'$' * priceLevel!.clamp(1, 4) : null;

  Restaurant copyWith({int? followerCount, bool? isFollowedByMe}) =>
      Restaurant(
        id: id,
        name: name,
        description: description,
        coverUrl: coverUrl,
        logoUrl: logoUrl,
        city: city,
        address: address,
        phone: phone,
        website: website,
        cuisines: cuisines,
        priceLevel: priceLevel,
        claimed: claimed,
        claimStatus: claimStatus,
        ownerId: ownerId,
        googlePlaceId: googlePlaceId,
        followerCount: followerCount ?? this.followerCount,
        postCount: postCount,
        ratingSum: ratingSum,
        ratingCount: ratingCount,
        openingHours: openingHours,
        menuNotes: menuNotes,
        isFollowedByMe: isFollowedByMe ?? this.isFollowedByMe,
        latitude: latitude,
        longitude: longitude,
      );

  @override
  List<Object?> get props => [
        id,
        name,
        claimed,
        claimStatus,
        ownerId,
        followerCount,
        isFollowedByMe,
      ];
}
