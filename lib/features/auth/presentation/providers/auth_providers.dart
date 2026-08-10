import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../data/repositories/firebase_auth_repository.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Dependency injection: swap implementation in tests via overrides.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(),
);

/// Reactive auth state — the single source of truth for who is signed in.
final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

final currentUserProvider = Provider<AppUser?>(
  (ref) => ref.watch(authStateProvider).valueOrNull,
);

/// Handles auth actions and exposes loading/error state to forms.
class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<bool> signIn(String email, String password) =>
      _run(() => _repo.signInWithEmail(email: email, password: password));

  Future<bool> signUp(String name, String email, String password) => _run(
        () => _repo.signUpWithEmail(
          displayName: name,
          email: email,
          password: password,
        ),
      );

  Future<bool> signInWithGoogle() => _run(() async {
        try {
          await _repo.signInWithGoogle();
        } on AppException catch (e) {
          if (e.code == 'cancelled') return; // user dismissed, not an error
          rethrow;
        }
      });

  Future<bool> signInWithApple() => _run(() async {
        try {
          await _repo.signInWithApple();
        } on AppException catch (e) {
          if (e.code == 'canceled' || e.code == 'web-context-canceled') {
            return; // user dismissed the sheet
          }
          rethrow;
        }
      });

  Future<bool> sendPasswordReset(String email) =>
      _run(() => _repo.sendPasswordResetEmail(email));

  Future<bool> resendVerification() =>
      _run(() => _repo.sendEmailVerification());

  Future<bool> checkVerified() async {
    return _repo.refreshEmailVerification();
  }

  Future<void> signOut() async {
    // Stop push delivery to this device before the session ends.
    await ref.read(pushNotificationServiceProvider).unregister();
    await _repo.signOut();
  }

  Future<bool> deleteAccount({String? password}) => _run(() async {
        await ref.read(pushNotificationServiceProvider).unregister();
        try {
          await _repo.deleteAccount(password: password);
        } on AppException catch (e) {
          if (e.code == 'cancelled') return;
          rethrow;
        }
      });

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    return !state.hasError;
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);
