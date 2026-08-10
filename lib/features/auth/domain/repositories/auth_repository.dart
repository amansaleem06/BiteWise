import '../entities/app_user.dart';

/// Contract for authentication and account lifecycle.
///
/// The presentation layer depends only on this abstraction; the Firebase
/// implementation lives in the data layer.
abstract interface class AuthRepository {
  /// Emits the current user (with Firestore profile) or null when signed out.
  Stream<AppUser?> authStateChanges();

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AppUser> signUpWithEmail({
    required String displayName,
    required String email,
    required String password,
    UserRole role = UserRole.user,
    String? businessName,
  });

  Future<AppUser> signInWithGoogle();

  /// Native Sign in with Apple (iOS). Required by App Review because the
  /// app also offers Google sign-in.
  Future<AppUser> signInWithApple();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> sendEmailVerification();

  /// Reloads the Firebase user and returns true if the email is now verified.
  Future<bool> refreshEmailVerification();

  Future<void> signOut();

  /// Permanently deletes the signed-in account and associated personal data.
  ///
  /// [password] is required when the account uses email/password so Firebase
  /// can reauthenticate (Apple Guideline 5.1.1(v)).
  Future<void> deleteAccount({String? password});
}
