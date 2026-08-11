import 'package:equatable/equatable.dart';

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
    this.ownedRestaurantId,
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
  final String? ownedRestaurantId;
  final bool emailVerified;
  final int followerCount;
  final int followingCount;
  final int postCount;
  final DateTime? createdAt;

  bool get isBusiness => role == UserRole.restaurantOwner;

  AppUser copyWith({
    String? displayName,
    String? username,
    String? photoUrl,
    String? bio,
    String? businessName,
    String? ownedRestaurantId,
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
        ownedRestaurantId: ownedRestaurantId ?? this.ownedRestaurantId,
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
        ownedRestaurantId: ownedRestaurantId,
        emailVerified: emailVerified,
        followerCount: followerCount ?? this.followerCount,
        followingCount: followingCount ?? this.followingCount,
        postCount: postCount ?? this.postCount,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [
        uid, email, displayName, role, username, photoUrl, bio,
        businessName, ownedRestaurantId,
        emailVerified, followerCount, followingCount, postCount,
      ];
}
