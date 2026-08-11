import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Client-side social notification fan-out (in-app feed).
///
/// Push delivery still depends on the Cloud Function that watches new
/// notification docs; this writer guarantees the in-app bell works even when
/// counter/notify triggers aren't deployed.
class SocialNotificationWriter {
  SocialNotificationWriter({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;

  Future<void> notify({
    required String recipientUid,
    required String type, // like | comment | follow
    String? postId,
    String? postMediaUrl,
    String? text,
  }) async {
    final me = _auth.currentUser;
    if (me == null || me.uid == recipientUid) return;

    await _firestore.collection('users').doc(recipientUid).collection('notifications').add({
      'type': type,
      'actorId': me.uid,
      'actorName': me.displayName ?? 'Someone',
      'actorPhotoUrl': me.photoURL,
      'postId': postId,
      'postMediaUrl': postMediaUrl,
      'text': text,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
