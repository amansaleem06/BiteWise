import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/app_user.dart';

/// Firestore (de)serialization for [AppUser].
///
/// Document path: `users/{uid}`
abstract final class UserModel {
  static AppUser fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppUser(
      uid: doc.id,
      email: (data['email'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ?? '',
      role: UserRole.fromKey(data['role'] as String?),
      username: data['username'] as String?,
      photoUrl: data['photoUrl'] as String?,
      bio: data['bio'] as String?,
      businessName: data['businessName'] as String?,
      ownedRestaurantId: data['ownedRestaurantId'] as String?,
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
        if (ownedRestaurantId != null) 'ownedRestaurantId': ownedRestaurantId,
        'emailVerified': emailVerified,
        'followerCount': 0,
        'followingCount': 0,
        'postCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
