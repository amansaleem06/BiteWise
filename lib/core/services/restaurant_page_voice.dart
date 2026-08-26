import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Public restaurant-page identity the owner speaks through.
class RestaurantPageVoice {
  const RestaurantPageVoice({
    required this.id,
    required this.name,
    this.logoUrl,
  });

  final String id;
  final String name;
  final String? logoUrl;

  /// Loads the signed-in owner's claimed page, if they have one.
  static Future<RestaurantPageVoice?> load({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  }) async {
    final user = (auth ?? fb.FirebaseAuth.instance).currentUser;
    if (user == null) return null;
    final db = firestore ?? FirebaseFirestore.instance;
    final userSnap = await db.collection('users').doc(user.uid).get();
    final owned = userSnap.data()?['ownedRestaurantId'] as String?;
    if (owned == null || owned.isEmpty) return null;
    final rest = await db.collection('restaurants').doc(owned).get();
    final data = rest.data();
    if (data == null) return null;
    final name = (data['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;
    return RestaurantPageVoice(
      id: owned,
      name: name,
      logoUrl: data['logoUrl'] as String?,
    );
  }
}
