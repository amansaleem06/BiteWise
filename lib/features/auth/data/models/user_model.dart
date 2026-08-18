import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../restaurants/domain/entities/claim_status.dart';
import '../../domain/entities/app_user.dart';

/// Firestore (de)serialization for [AppUser].
///
/// Document path: `users/{uid}`
abstract final class UserModel {
  static AppUser fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final role = UserRole.fromKey(data['role'] as String?);
    final ownedId = data['ownedRestaurantId'] as String?;
    final stored = BusinessVerificationStatus.fromKey(
      data['businessVerificationStatus'] as String?,
    );
    final verification = stored ??
        (role == UserRole.restaurantOwner
            ? ((ownedId != null && ownedId.isNotEmpty)
                ? BusinessVerificationStatus.verified
                : BusinessVerificationStatus.pending)
            : null);

    return AppUser(
      uid: doc.id,
      email: (data['email'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ?? '',
      role: role,
      username: data['username'] as String?,
      photoUrl: data['photoUrl'] as String?,
      bio: data['bio'] as String?,
      businessName: data['businessName'] as String?,
      businessAddress: data['businessAddress'] as String?,
      businessPhone: data['businessPhone'] as String?,
      businessEmail: data['businessEmail'] as String?,
      businessVerificationStatus: verification,
      ownedRestaurantId: ownedId,
      pendingClaimRestaurantId: data['pendingClaimRestaurantId'] as String?,
      phone: data['phone'] as String?,
      messagePrivacy: MessagePrivacy.fromKey(data['messagePrivacy'] as String?),
      emailVerified: (data['emailVerified'] as bool?) ?? false,
      followerCount: (data['followerCount'] as num?)?.toInt() ?? 0,
      followingCount: (data['followingCount'] as num?)?.toInt() ?? 0,
      postCount: (data['postCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Payload for a brand-new user document.
  static Map<String, dynamic> newUser({
    required String email,
    required String displayName,
    String? photoUrl,
    UserRole role = UserRole.user,
    String? businessName,
    String? businessAddress,
    String? businessPhone,
    String? businessEmail,
    String? ownedRestaurantId,
    bool emailVerified = false,
  }) =>
      {
        'email': email,
        'displayName': displayName,
        'displayNameLower': displayName.toLowerCase(),
        'photoUrl': photoUrl,
        'role': role.name,
        if (businessName != null) 'businessName': businessName,
        if (businessAddress != null) 'businessAddress': businessAddress,
        if (businessPhone != null) 'businessPhone': businessPhone,
        if (businessEmail != null) 'businessEmail': businessEmail,
        if (role == UserRole.restaurantOwner)
          'businessVerificationStatus':
              (ownedRestaurantId != null && ownedRestaurantId.isNotEmpty)
                  ? BusinessVerificationStatus.verified.name
                  : BusinessVerificationStatus.pending.name,
        if (ownedRestaurantId != null) 'ownedRestaurantId': ownedRestaurantId,
        'messagePrivacy': MessagePrivacy.everyone.name,
        'emailVerified': emailVerified,
        'followerCount': 0,
        'followingCount': 0,
        'postCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
