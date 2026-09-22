import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Shared filtering for every post collection, including bookmarks, restaurants
/// and search. Public UGC remains readable; blocking is an interaction boundary.
class ContentVisibility {
  ContentVisibility(this.blocked);
  final Set<String> blocked;
  static Future<ContentVisibility> load(FirebaseFirestore db) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return ContentVisibility({});
    final snapshots = await Future.wait([
      db.collection('users').doc(uid).collection('blocked').get(),
      db.collection('users').doc(uid).collection('blockedBy').get(),
    ]);
    return ContentVisibility({
      for (final snap in snapshots)
        for (final doc in snap.docs) doc.id
    });
  }

  bool allows(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return data != null &&
        data['moderationHidden'] != true &&
        data['suspended'] != true &&
        !blocked.contains(data['authorId'] ?? doc.id);
  }
}
