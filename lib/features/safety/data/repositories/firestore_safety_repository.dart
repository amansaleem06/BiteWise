import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/repositories/safety_repository.dart';

class FirestoreSafetyRepository implements SafetyRepository {
  FirestoreSafetyRepository({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AppException('Not signed in');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _blocked =>
      _firestore.collection('users').doc(_uid).collection('blocked');

  @override
  Future<void> report({
    required ReportTargetType type,
    required String targetId,
    required String targetUserId,
    required String reason,
  }) async {
    final uid = _uid;
    if (targetUserId == uid) {
      throw const AppException('You cannot report your own account.');
    }
    await _firestore.collection('reports').add({
      'reporterId': uid,
      'targetType': type.name,
      'targetId': targetId,
      'targetUserId': targetUserId,
      'reason': reason,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> blockUser(String uid) async {
    final me = _uid;
    if (uid == me) {
      throw const AppException('You cannot block yourself.');
    }
    await _blocked.doc(uid).set({
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> unblockUser(String uid) async {
    await _blocked.doc(uid).delete();
  }

  @override
  Stream<Set<String>> watchBlockedUserIds() async* {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      yield const {};
      return;
    }
    try {
      await for (final snap in _firestore
          .collection('users')
          .doc(uid)
          .collection('blocked')
          .snapshots()) {
        yield snap.docs.map((d) => d.id).toSet();
      }
    } catch (e, st) {
      debugPrint('Blocked users stream failed: $e\n$st');
      yield const {};
    }
  }
}
