import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/reservation.dart';
import '../../domain/repositories/reservation_repository.dart';

/// Top-level `reservations/{id}` collection — queryable both by user
/// (this app) and by restaurant (owner dashboard milestone).
class FirestoreReservationRepository implements ReservationRepository {
  FirestoreReservationRepository({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _reservations =>
      _firestore.collection('reservations');

  fb.User get _user {
    final user = _auth.currentUser;
    if (user == null) throw const AppException('Not signed in');
    return user;
  }

  @override
  Future<void> create({
    required String restaurantId,
    required String restaurantName,
    String? restaurantLogoUrl,
    required DateTime dateTime,
    required int partySize,
    String? note,
  }) async {
    if (!dateTime.isAfter(DateTime.now())) {
      throw const AppException('Please pick a time in the future.');
    }
    final user = _user;
    await _reservations.add({
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'restaurantLogoUrl': restaurantLogoUrl,
      'userId': user.uid,
      'userName': user.displayName ?? '',
      'userPhotoUrl': user.photoURL,
      'partySize': partySize,
      'dateTime': Timestamp.fromDate(dateTime),
      'note': (note?.trim().isEmpty ?? true) ? null : note!.trim(),
      'status': ReservationStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<List<Reservation>> watchMine({int limit = 100}) {
    return _reservations
        .where('userId', isEqualTo: _user.uid)
        .orderBy('dateTime', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  @override
  Future<void> cancel(String reservationId) async {
    await _reservations.doc(reservationId).update({
      'status': ReservationStatus.cancelled.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Reservation _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Reservation(
      id: doc.id,
      restaurantId: (data['restaurantId'] as String?) ?? '',
      restaurantName: (data['restaurantName'] as String?) ?? '',
      restaurantLogoUrl: data['restaurantLogoUrl'] as String?,
      userId: (data['userId'] as String?) ?? '',
      userName: (data['userName'] as String?) ?? '',
      partySize: (data['partySize'] as num?)?.toInt() ?? 2,
      dateTime:
          (data['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: data['note'] as String?,
      status: ReservationStatus.fromKey(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
