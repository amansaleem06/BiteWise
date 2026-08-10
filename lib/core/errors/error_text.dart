import '../constants/app_strings.dart';
import 'app_exception.dart';

/// Extracts a user-presentable message from any thrown error.
String userMessageFrom(Object? error) {
  if (error is AppException) return error.message;
  return AppStrings.genericError;
}
