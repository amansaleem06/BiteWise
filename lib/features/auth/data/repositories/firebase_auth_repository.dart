import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

/// Firebase-backed [AuthRepository].
///
/// Auth identity lives in Firebase Auth; the richer profile lives in
/// Firestore at `users/{uid}`. This class keeps the two in sync.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    fb.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? fb.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  @override
  Stream<AppUser?> authStateChanges() {
    return _auth.authStateChanges().asyncExpand((fbUser) {
      if (fbUser == null) return Stream<AppUser?>.value(null);
      // Live profile stream so role/profile edits propagate instantly.
      return _users.doc(fbUser.uid).snapshots().map((doc) {
        if (!doc.exists) {
          // Profile doc not created yet (e.g. mid-signup); fall back to auth data.
          return AppUser(
            uid: fbUser.uid,
            email: fbUser.email ?? '',
            displayName: fbUser.displayName ?? '',
            role: UserRole.user,
            emailVerified: fbUser.emailVerified,
          );
        }
        // Trust either source: the Auth flag, or the Firestore flag written by
        // refreshEmailVerification() (which re-triggers this stream).
        return UserModel.fromDoc(doc)
            .copyWith(emailVerified: fbUser.emailVerified ? true : null);
      });
    });
  }

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _loadOrCreateProfile(cred.user!);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  @override
  Future<AppUser> signUpWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;
      await user.updateDisplayName(displayName.trim());
      await _users.doc(user.uid).set(
            UserModel.newUser(
              email: email.trim(),
              displayName: displayName.trim(),
              emailVerified: true, // verification gate disabled by product decision
            ),
          );
      return _loadOrCreateProfile(user);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw const AppException('Sign-in cancelled', code: 'cancelled');
      }
      final googleAuth = await googleUser.authentication;
      final cred = await _auth.signInWithCredential(
        fb.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        ),
      );
      return _loadOrCreateProfile(cred.user!);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  @override
  Future<AppUser> signInWithApple() async {
    try {
      final provider = fb.AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      final cred = await _auth.signInWithProvider(provider);
      return _loadOrCreateProfile(cred.user!);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on fb.FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw const AppException('Not signed in');
    await user.sendEmailVerification();
  }

  @override
  Future<bool> refreshEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final verified = _auth.currentUser?.emailVerified ?? false;
    if (verified) {
      await _users.doc(user.uid).set(
        {'emailVerified': true, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    }
    return verified;
  }

  @override
  Future<void> signOut() async {
    await Future.wait([
      _googleSignIn.signOut().catchError((_) => null),
      _auth.signOut(),
    ]);
  }

  @override
  Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) throw const AppException('Not signed in');

    try {
      await _reauthenticateForDeletion(user, password: password);
      await _deleteOwnedClientData(user.uid);
      await user.delete();
      await _googleSignIn.signOut().catchError((_) => null);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  Future<void> _reauthenticateForDeletion(
    fb.User user, {
    String? password,
  }) async {
    final providers = user.providerData.map((p) => p.providerId).toSet();

    if (providers.contains('password')) {
      final email = user.email;
      if (email == null || password == null || password.isEmpty) {
        throw const AppException(
          'Enter your password to confirm account deletion.',
          code: 'requires-password',
        );
      }
      await user.reauthenticateWithCredential(
        fb.EmailAuthProvider.credential(email: email, password: password),
      );
      return;
    }

    if (providers.contains('google.com')) {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw const AppException('Sign-in cancelled', code: 'cancelled');
      }
      final googleAuth = await googleUser.authentication;
      await user.reauthenticateWithCredential(
        fb.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        ),
      );
      return;
    }

    if (providers.contains('apple.com')) {
      final provider = fb.AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      await user.reauthenticateWithProvider(provider);
      return;
    }

    // Fallback: attempt delete without reauth; Firebase may still require it.
  }

  /// Best-effort client cleanup before Auth deletion. Server-side cascade
  /// continues in Cloud Functions (`onAuthUserDeleted`).
  Future<void> _deleteOwnedClientData(String uid) async {
    final batch = _firestore.batch();
    final userRef = _users.doc(uid);

    Future<void> deleteSubcollection(String name) async {
      final snap = await userRef.collection(name).limit(400).get();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
    }

    await deleteSubcollection('tokens');
    await deleteSubcollection('bookmarks');
    await deleteSubcollection('notifications');
    await deleteSubcollection('following');
    batch.delete(userRef);
    await batch.commit();
  }

  /// Ensures a Firestore profile exists (creates one on first social sign-in).
  Future<AppUser> _loadOrCreateProfile(fb.User fbUser) async {
    final ref = _users.doc(fbUser.uid);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set(
        UserModel.newUser(
          email: fbUser.email ?? '',
          displayName: fbUser.displayName ?? 'Food lover',
          photoUrl: fbUser.photoURL,
          emailVerified: fbUser.emailVerified,
        ),
      );
      return UserModel.fromDoc(await ref.get())
          .copyWith(emailVerified: fbUser.emailVerified);
    }
    return UserModel.fromDoc(doc).copyWith(emailVerified: fbUser.emailVerified);
  }

  AppException _mapAuthError(fb.FirebaseAuthException e) {
    final message = switch (e.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' =>
        'Incorrect email or password.',
      'email-already-in-use' => 'An account already exists with this email.',
      'invalid-email' => 'That email address is invalid.',
      'weak-password' => 'Please choose a stronger password.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      'network-request-failed' => 'Network error. Check your connection.',
      'user-disabled' => 'This account has been disabled.',
      'requires-recent-login' =>
          'For security, sign in again before deleting your account.',
      // Surface the raw code for unexpected failures so issues are diagnosable.
      _ => 'Authentication failed (${e.code}). Please try again.',
    };
    return AppException(message, code: e.code);
  }
}
