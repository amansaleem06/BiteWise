import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/switch_latest.dart';
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
  CollectionReference<Map<String, dynamic>> get _publicProfiles =>
      _firestore.collection('publicProfiles');

  @override
  Stream<AppUser?> authStateChanges() {
    return switchLatest(_auth.userChanges(), (fb.User? fbUser) async* {
      if (fbUser == null) {
        yield null;
        return;
      }
      yield _userFromAuth(fbUser);
      yield* _users.doc(fbUser.uid).snapshots().map((doc) {
        if (!doc.exists) return _userFromAuth(fbUser);
        return UserModel.fromDoc(doc).copyWith(
          emailVerified: fbUser.emailVerified,
          needsEmailVerification: _needsVerification(fbUser),
        );
      });
    });
  }

  bool _needsVerification(fb.User user) =>
      !user.emailVerified &&
      user.providerData.any((p) => p.providerId == 'password');

  AppUser _userFromAuth(fb.User fbUser) => AppUser(
        uid: fbUser.uid,
        email: fbUser.email ?? '',
        displayName: fbUser.displayName ?? '',
        role: UserRole.user,
        photoUrl: fbUser.photoURL,
        emailVerified: fbUser.emailVerified,
        needsEmailVerification: _needsVerification(fbUser),
      );

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
      return await _loadOrCreateProfile(cred.user!);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  @override
  Future<AppUser> signUpWithEmail({
    required String displayName,
    required String email,
    required String password,
    UserRole role = UserRole.user,
    String? businessName,
  }) async {
    try {
      final emailError = Validators.email(email);
      if (emailError != null) {
        throw AppException(emailError, code: 'invalid-email');
      }
      final nameError = Validators.displayName(displayName);
      if (nameError != null) throw AppException(nameError);
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;
      final name = displayName.trim();
      await user.updateDisplayName(name);

      String? restaurantId;
      if (role == UserRole.restaurantOwner) {
        // Restaurant pages are claimed from the Maps listing after signup —
        // never invented here. Ratings already on that listing carry over.
      }

      final userData = UserModel.newUser(
        email: email.trim(),
        displayName: name,
        role: role,
        businessName: role == UserRole.restaurantOwner
            ? (businessName ?? name).trim()
            : null,
        ownedRestaurantId: restaurantId,
        emailVerified: user.emailVerified,
      );
      await (_firestore.batch()
            ..set(_users.doc(user.uid), userData)
            ..set(
              _publicProfiles.doc(user.uid),
              UserModel.publicProfile(userData),
            ))
          .commit();
      // A delivery failure must not report account creation as failed. The
      // verification screen offers retry without creating a second account.
      try {
        await user.sendEmailVerification();
      } catch (_) {}
      return await _loadOrCreateProfile(user);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    try {
      // Clear a stale Google session so the account picker can appear again.
      await _googleSignIn
          .signOut()
          .timeout(const Duration(seconds: 5))
          .catchError((_) => null);
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw const AppException('Sign-in cancelled', code: 'cancelled');
      }
      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw const AppException(
          'Google sign-in is unavailable. Please contact support.',
          code: 'missing-google-token',
        );
      }
      final cred = await _auth.signInWithCredential(
        fb.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        ),
      );
      return await _loadOrCreateProfile(cred.user!);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_canceled' || e.code == 'sign_in_cancelled') {
        throw const AppException('Sign-in cancelled', code: 'cancelled');
      }
      throw AppException(
        e.code == 'network_error'
            ? 'Network error. Check your connection and try again.'
            : 'Google sign-in could not complete. Please try again or contact support.',
        code: e.code,
      );
    }
  }

  @override
  Future<AppUser> signInWithApple() async {
    try {
      final provider = fb.AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      final cred = await _auth.signInWithProvider(provider);
      return await _loadOrCreateProfile(cred.user!);
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
      final updatedAt = FieldValue.serverTimestamp();
      await (_firestore.batch()
            ..set(
              _users.doc(user.uid),
              {'emailVerified': true, 'updatedAt': updatedAt},
              SetOptions(merge: true),
            )
            ..set(
              _publicProfiles.doc(user.uid),
              {'updatedAt': updatedAt},
              SetOptions(merge: true),
            ))
          .commit();
    }
    return verified;
  }

  @override
  Future<void> signOut() async {
    // Auth first so UI can leave the shell immediately; Google cleanup is
    // best-effort and must never block the session clear.
    await _auth.signOut();
    try {
      await _googleSignIn.signOut().timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Google signOut ignored: $e');
    }
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
  }

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

  Future<AppUser> _loadOrCreateProfile(fb.User fbUser) async {
    final ref = _users.doc(fbUser.uid);
    // Read and create atomically: concurrent logins never overwrite a profile.
    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(ref);
      if (!doc.exists) {
        final name = (fbUser.displayName ?? 'Food lover').trim();
        final userData = UserModel.newUser(
          email: fbUser.email ?? '',
          displayName: name.length > 50 ? name.substring(0, 50) : name,
          photoUrl: fbUser.photoURL,
          emailVerified: fbUser.emailVerified,
        );
        transaction.set(ref, userData);
        transaction.set(
          _publicProfiles.doc(fbUser.uid),
          UserModel.publicProfile(userData),
        );
      } else {
        final publicRef = _publicProfiles.doc(fbUser.uid);
        final publicDoc = await transaction.get(publicRef);
        if (!publicDoc.exists) {
          transaction.set(publicRef, UserModel.publicProfile(doc.data()!));
        }
      }
    });
    return UserModel.fromDoc(await ref.get()).copyWith(
      emailVerified: fbUser.emailVerified,
      needsEmailVerification: _needsVerification(fbUser),
    );
  }

  AppException _mapAuthError(fb.FirebaseAuthException e) {
    final message = switch (e.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' =>
        'Incorrect email or password.',
      'account-exists-with-different-credential' =>
        'This email uses another sign-in method. Sign in with that method to keep your existing account.',
      'email-already-in-use' => 'An account already exists with this email.',
      'invalid-email' => 'That email address is invalid.',
      'weak-password' => 'Please choose a stronger password.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      'network-request-failed' => 'Network error. Check your connection.',
      'user-disabled' => 'This account has been disabled.',
      'requires-recent-login' =>
        'For security, sign in again before deleting your account.',
      _ => 'Authentication failed (${e.code}). Please try again.',
    };
    return AppException(message, code: e.code);
  }
}
