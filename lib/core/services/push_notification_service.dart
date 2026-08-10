import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// FCM token lifecycle: request permission, register the device token under
/// users/{uid}/tokens/{token}, keep it fresh, remove on sign-out.
class PushNotificationService {
  PushNotificationService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;

  String? _registeredToken;

  /// Call after sign-in (and on app start when signed in).
  Future<void> register() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    try {
      final token = await _messaging.getToken();
      if (token != null) await _saveToken(uid, token);
      _messaging.onTokenRefresh.listen((t) => _saveToken(uid, t));
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    _registeredToken = token;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('tokens')
        .doc(token)
        .set({
      'platform': kIsWeb
          ? 'web'
          : Platform.isIOS
              ? 'ios'
              : 'android',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Call before sign-out so this device stops receiving pushes.
  Future<void> unregister() async {
    final uid = _auth.currentUser?.uid;
    final token = _registeredToken;
    if (uid == null || token == null) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('tokens')
        .doc(token)
        .delete()
        .catchError((_) => null);
  }
}
