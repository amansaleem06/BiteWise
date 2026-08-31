/// Compile-time configuration for Google Maps / Places.
///
/// SECURITY: no API keys live in source control. The Places REST key is
/// injected at build time:
///
///   flutter run --dart-define=PLACES_API_KEY=AIza...
///   flutter build ipa --dart-define=PLACES_API_KEY=AIza...
///
/// CI (Codemagic) injects it from a secure environment variable — see
/// codemagic.yaml. The native Maps SDK keys stay in AndroidManifest.xml /
/// AppDelegate.swift and MUST be restricted in Google Cloud to this app's
/// package + SHA-1 (Android) and bundle id (iOS), so they are useless to
/// anyone who extracts them.
abstract final class MapsConfig {
  /// Places REST key from --dart-define. Empty when not provided.
  static const String placesApiKey = String.fromEnvironment('PLACES_API_KEY');

  /// Whether restaurant search via Google Places is available in this build.
  static bool get hasPlacesKey => placesApiKey.isNotEmpty;

  /// Ordered keys to try for Places HTTP calls.
  static List<String> get placesApiKeys =>
      [if (hasPlacesKey) placesApiKey];
}
