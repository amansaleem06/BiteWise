import 'package:equatable/equatable.dart';

import '../../../restaurants/domain/entities/claim_status.dart';

/// Who may start a new conversation with this account.
enum MessagePrivacy {
  everyone,
  followers,
  none;

  static MessagePrivacy fromKey(String? key) =>
      MessagePrivacy.values.where((s) => s.name == key).firstOrNull ??
      MessagePrivacy.everyone;

  String get label => switch (this) {
        MessagePrivacy.everyone => 'Anyone',
        MessagePrivacy.followers => 'Followers only',
        MessagePrivacy.none => 'Nobody new',
      };

  String get subtitle => switch (this) {
        MessagePrivacy.everyone => 'Anyone on TasteWise can send you a message',
        MessagePrivacy.followers => 'Only people who follow you can start a chat',
        MessagePrivacy.none =>
          'New chats are closed. Existing conversations stay open',
      };
}

/// Role determines permissions throughout the app and in Security Rules.
enum UserRole {
  user,
  restaurantOwner,
  admin;

  static UserRole fromKey(String? key) => UserRole.values.firstWhere(
        (r) => r.name == key,
        orElse: () => UserRole.user,
      );
}

/// Core user entity — the domain representation of a TasteWise account.
class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.username,
    this.photoUrl,
    this.bio,
    this.businessName,
    this.businessAddress,
    this.businessPhone,
    this.businessEmail,
    this.businessVerificationStatus,
    this.ownedRestaurantId,
    this.pendingClaimRestaurantId,
    this.phone,
    this.messagePrivacy = MessagePrivacy.everyone,
    this.emailVerified = false,
    this.followerCount = 0,
    this.followingCount = 0,
    this.postCount = 0,
    this.createdAt,
  });

  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? username;
  final String? photoUrl;
  final String? bio;

  /// Set for [UserRole.restaurantOwner] accounts.
  final String? businessName;
  final String? businessAddress;
  final String? businessPhone;
  final String? businessEmail;
  final BusinessVerificationStatus? businessVerificationStatus;
  final String? ownedRestaurantId;
  final String? pendingClaimRestaurantId;
  final String? phone;
  final MessagePrivacy messagePrivacy;
  final bool emailVerified;
  final int followerCount;
  final int followingCount;
  final int postCount;
  final DateTime? createdAt;

  bool get isBusiness => role == UserRole.restaurantOwner;

  bool get hasVerifiedBusiness =>
      isBusiness &&
      businessVerificationStatus == BusinessVerificationStatus.verified &&
      ownedRestaurantId != null &&
      ownedRestaurantId!.isNotEmpty;

  bool get needsBusinessDetails {
    if (!isBusiness) return false;
    if (ownedRestaurantId != null && ownedRestaurantId!.isNotEmpty) {
      return false;
    }
    final address = businessAddress?.trim() ?? '';
    final phone = businessPhone?.trim() ?? '';
    return address.isEmpty || phone.isEmpty;
  }

  AppUser copyWith({
    String? displayName,
    String? username,
    String? photoUrl,
    String? bio,
    String? businessName,
    String? businessAddress,
    String? businessPhone,
    String? businessEmail,
    BusinessVerificationStatus? businessVerificationStatus,
    String? ownedRestaurantId,
    String? pendingClaimRestaurantId,
    bool clearPendingClaim = false,
    String? phone,
    MessagePrivacy? messagePrivacy,
    bool? emailVerified,
  }) =>
      AppUser(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        role: role,
        username: username ?? this.username,
        photoUrl: photoUrl ?? this.photoUrl,
        bio: bio ?? this.bio,
        businessName: businessName ?? this.businessName,
        businessAddress: businessAddress ?? this.businessAddress,
        businessPhone: businessPhone ?? this.businessPhone,
        businessEmail: businessEmail ?? this.businessEmail,
        businessVerificationStatus:
            businessVerificationStatus ?? this.businessVerificationStatus,
        ownedRestaurantId: ownedRestaurantId ?? this.ownedRestaurantId,
        pendingClaimRestaurantId: clearPendingClaim
            ? null
            : (pendingClaimRestaurantId ?? this.pendingClaimRestaurantId),
        phone: phone ?? this.phone,
        messagePrivacy: messagePrivacy ?? this.messagePrivacy,
        emailVerified: emailVerified ?? this.emailVerified,
        followerCount: followerCount,
        followingCount: followingCount,
        postCount: postCount,
        createdAt: createdAt,
      );

  /// Counter-only copy (used for optimistic follower updates).
  AppUser copyWithCounts({
    int? followerCount,
    int? followingCount,
    int? postCount,
  }) =>
      AppUser(
        uid: uid,
        email: email,
        displayName: displayName,
        role: role,
        username: username,
        photoUrl: photoUrl,
        bio: bio,
        businessName: businessName,
        businessAddress: businessAddress,
        businessPhone: businessPhone,
        businessEmail: businessEmail,
        businessVerificationStatus: businessVerificationStatus,
        ownedRestaurantId: ownedRestaurantId,
        pendingClaimRestaurantId: pendingClaimRestaurantId,
        phone: phone,
        messagePrivacy: messagePrivacy,
        emailVerified: emailVerified,
        followerCount: followerCount ?? this.followerCount,
        followingCount: followingCount ?? this.followingCount,
        postCount: postCount ?? this.postCount,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [
        uid,
        email,
        displayName,
        role,
        username,
        photoUrl,
        bio,
        businessName,
        businessAddress,
        businessPhone,
        businessEmail,
        businessVerificationStatus,
        ownedRestaurantId,
        pendingClaimRestaurantId,
        phone,
        messagePrivacy,
        emailVerified,
        followerCount,
        followingCount,
        postCount,
      ];
}
