import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/app_notification.dart';

class NotificationPage {
  const NotificationPage({
    required this.items,
    this.cursor,
    required this.hasMore,
  });

  final List<AppNotification> items;
  final Object? cursor;
  final bool hasMore;
}

/// Notifications are written only by Cloud Functions; the client reads,
/// marks read, and deletes.
class FirestoreNotificationRepository {
  FirestoreNotificationRepository({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;

  static const _pageSize = 25;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AppException('Not signed in');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('users').doc(_uid).collection('notifications');

  Future<NotificationPage> fetch({Object? cursor, int limit = _pageSize}) async {
    Query<Map<String, dynamic>> query =
        _notifications.orderBy('createdAt', descending: true).limit(limit);
    if (cursor is DocumentSnapshot) query = query.startAfterDocument(cursor);
    final snap = await query.get();
    return NotificationPage(
      items: snap.docs.map(_fromDoc).toList(),
      cursor: snap.docs.isEmpty ? null : snap.docs.last,
      hasMore: snap.docs.length == limit,
    );
  }

  /// Whether any unread notifications exist (drives the bell badge).
  Stream<bool> hasUnread() => _notifications
      .where('read', isEqualTo: false)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isNotEmpty);

  Future<void> markAllRead() async {
    final unread =
        await _notifications.where('read', isEqualTo: false).limit(400).get();
    if (unread.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  AppNotification _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppNotification(
      id: doc.id,
      type: NotificationType.fromKey(data['type'] as String?),
      actorId: (data['actorId'] as String?) ?? '',
      actorName: (data['actorName'] as String?) ?? '',
      actorPhotoUrl: data['actorPhotoUrl'] as String?,
      postId: data['postId'] as String?,
      postMediaUrl: data['postMediaUrl'] as String?,
      text: data['text'] as String?,
      read: (data['read'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
