import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_strings.dart';
import 'app_exception.dart';

/// Extracts a user-presentable message from any thrown error.
String userMessageFrom(Object? error) {
  if (error == null) return AppStrings.genericError;
  if (error is AppException) return error.message;

  if (error is FirebaseException) {
    debugPrint('FirebaseException(${error.plugin}/${error.code}): ${error.message}');
    return switch (error.code) {
      'permission-denied' =>
        'Permission denied. Sign in again or check Firebase rules.',
      'unauthenticated' => 'Please sign in again.',
      'unavailable' => 'Network unavailable. Check your connection.',
      'deadline-exceeded' => 'Request timed out. Please try again.',
      'failed-precondition' =>
        'A database index may be missing. Check the debug console for a link.',
      'not-found' => 'That item was not found.',
      'already-exists' => 'That already exists.',
      'resource-exhausted' => 'Too many requests. Please wait a moment.',
      'cancelled' => 'Request was cancelled.',
      _ => error.message?.isNotEmpty == true
          ? error.message!
          : 'Firebase error (${error.code}). Please try again.',
    };
  }

  debugPrint('Unhandled error: $error');
  final text = error.toString();
  // Surface useful Firestore index / network hints when present.
  if (text.contains('FAILED_PRECONDITION') || text.contains('requires an index')) {
    return 'A database index is missing. Open the link in the debug console, then retry.';
  }
  if (text.contains('SocketException') || text.contains('network')) {
    return 'Network error. Check your connection and try again.';
  }
  return AppStrings.genericError;
}
