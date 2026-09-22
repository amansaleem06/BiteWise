import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_strings.dart';
import 'app_exception.dart';

/// Extracts a user-presentable message from any thrown error.
String userMessageFrom(Object? error) {
  if (error == null) return AppStrings.genericError;
  if (error is AppException) return error.message;

  if (error is FirebaseException) {
    debugPrint(
        'FirebaseException(${error.plugin}/${error.code}): ${error.message}');
    return switch (error.code) {
      'permission-denied' =>
        'We couldn\'t access this right now. Please try again or sign in again.',
      'unauthenticated' => 'Please sign in again.',
      'unavailable' => 'Network unavailable. Check your connection.',
      'deadline-exceeded' => 'Request timed out. Please try again.',
      'failed-precondition' =>
        'This content is temporarily unavailable. Please try again later.',
      'not-found' => 'That item was not found.',
      'already-exists' => 'That already exists.',
      'resource-exhausted' => 'Too many requests. Please wait a moment.',
      'cancelled' => 'Request was cancelled.',
      _ => AppStrings.genericError,
    };
  }

  debugPrint('Unhandled error: $error');
  final text = error.toString();
  // Keep internal diagnostics in the debug log rather than the UI.
  if (text.contains('FAILED_PRECONDITION') ||
      text.contains('requires an index')) {
    return 'This content is temporarily unavailable. Please try again later.';
  }
  if (text.contains('SocketException') || text.contains('network')) {
    return 'Network error. Check your connection and try again.';
  }
  return AppStrings.genericError;
}
