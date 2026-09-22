import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'dart:convert';
import 'dart:async';

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
    final id = base64Url.encode(utf8.encode('${type.name}:$targetId'));
    final report = _firestore.collection('reports').doc('${uid}_$id');
    await _firestore.runTransaction((transaction) async {
      if ((await transaction.get(report)).exists) return;
      transaction.set(report, {
        'reporterId': uid,
        'targetType': type.name,
        'targetId': targetId,
        'targetUserId': targetUserId,
        'reason': reason,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> blockUser(String uid) async {
    final me = _uid;
    if (uid == me) {
      throw const AppException('You cannot block yourself.');
    }
    final batch = _firestore.batch();
    batch.set(_blocked.doc(uid), {'createdAt': FieldValue.serverTimestamp()});
    batch.set(
      _firestore.doc('users/$uid/blockedBy/$me'),
      {'createdAt': FieldValue.serverTimestamp()},
    );
    await batch.commit();
  }

  @override
  Future<void> unblockUser(String uid) async {
    final batch = _firestore.batch();
    batch.delete(_blocked.doc(uid));
    batch.delete(_firestore.doc('users/$uid/blockedBy/$_uid'));
    await batch.commit();
  }

  @override
  Stream<Set<String>> watchBlockedUserIds() async* {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      yield const {};
      return;
    }
    yield* Stream<Set<String>>.multi((controller) {
      Set<String>? outgoing;
      Set<String>? incoming;
      void emit() {
        if (outgoing != null && incoming != null) {
          controller.add({...outgoing!, ...incoming!});
        }
      }

      final a = _firestore
          .collection('users')
          .doc(uid)
          .collection('blocked')
          .snapshots()
          .listen(
        (snap) {
          outgoing = snap.docs.map((d) => d.id).toSet();
          emit();
        },
        onError: controller.addError,
      );
      final b = _firestore
          .collection('users')
          .doc(uid)
          .collection('blockedBy')
          .snapshots()
          .listen(
        (snap) {
          incoming = snap.docs.map((d) => d.id).toSet();
          emit();
        },
        onError: controller.addError,
      );
      controller.onCancel = () async {
        await a.cancel();
        await b.cancel();
      };
    });
  }
}
