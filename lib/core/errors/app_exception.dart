/// Domain-level exception with a user-presentable message.
///
/// Repositories catch platform/SDK errors (FirebaseAuthException, network
/// failures, ...) and rethrow them as [AppException] so the presentation
/// layer never depends on SDK types.
class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'AppException($code): $message';
}
