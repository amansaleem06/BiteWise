import 'dart:async';
import 'consent_providers.dart';

import 'package:flutter/foundation.dart';
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

  Future<bool> signIn(String email, String password) => _authenticate(
      () => _repo.signInWithEmail(email: email, password: password));

  Future<bool> signUp(
    String name,
    String email,
    String password, {
    UserRole role = UserRole.user,
    String? businessName,
  }) =>
      _authenticate(
        () => _repo.signUpWithEmail(
          displayName: name,
          email: email,
          password: password,
          role: role,
          businessName: businessName,
        ),
      );

  Future<bool> signInWithGoogle() => _authenticate(_repo.signInWithGoogle);
  Future<bool> signInWithApple() => _authenticate(_repo.signInWithApple);

  Future<bool> _authenticate(Future<AppUser> Function() action) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      final user = await action();
      // The linked notice shown before every auth action makes continuing the
      // acceptance action. Existing users keep their original acceptance time.
      await recordTermsAcceptance(ref, user.uid);
      state = const AsyncData(null);
      return true;
    } on AppException catch (e, st) {
      if (['cancelled', 'canceled', 'web-context-canceled'].contains(e.code)) {
        state = const AsyncData(null);
      } else {
        state = AsyncError(e, st);
      }
      return false;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> acceptTerms() => _run(() async {
        if (!ref.read(termsCheckedProvider))
          throw const AppException('Please agree to the terms first.');
        final user = ref.read(currentUserProvider);
        if (user == null) throw const AppException('Please sign in again.');
        await recordTermsAcceptance(ref, user.uid);
      });

  Future<bool> sendPasswordReset(String email) =>
      _run(() => _repo.sendPasswordResetEmail(email));

  Future<bool> resendVerification() =>
      _run(() => _repo.sendEmailVerification());

  Future<bool> checkVerified() async {
    return _repo.refreshEmailVerification();
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      // Never block logout on push cleanup.
      unawaited(() async {
        try {
          await ref
              .read(pushNotificationServiceProvider)
              .unregister()
              .timeout(const Duration(seconds: 2));
        } catch (e) {
          debugPrint('Push unregister ignored: $e');
        }
      }());
      await _repo.signOut();
      ref.read(termsCheckedProvider.notifier).state = false;
      // Drop cached signed-in trees so the next session starts clean.
      ref.invalidate(authStateProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      debugPrintStack(stackTrace: st, label: 'Sign out failed: $e');
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<bool> deleteAccount({String? password}) => _run(() async {
        try {
          await ref
              .read(pushNotificationServiceProvider)
              .unregister()
              .timeout(const Duration(seconds: 2));
        } catch (e) {
          debugPrint('Push unregister ignored: $e');
        }
        try {
          await _repo.deleteAccount(password: password);
          ref.invalidate(authStateProvider);
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
