import '../../firebase_options.dart';

/// Google Maps / Places API keys used by the app.
///
/// Maps SDK keys (in AndroidManifest / AppDelegate) are usually restricted to
/// iOS/Android apps and **cannot** call Places over HTTP from Flutter.
///
/// For restaurant search we try keys that typically allow REST:
/// 1. Optional compile-time `PLACES_API_KEY` (--dart-define)
/// 2. Firebase Web API key
/// 3. Platform Firebase API key
abstract final class MapsConfig {
  /// Pass a dedicated Places REST key:
  /// `flutter run --dart-define=PLACES_API_KEY=AIza...`
  static const String _dartDefinePlacesKey = String.fromEnvironment(
    'PLACES_API_KEY',
  );

  /// Ordered keys to try for Places HTTP (New).
  static List<String> get placesApiKeys {
    final keys = <String>[
      if (_dartDefinePlacesKey.isNotEmpty) _dartDefinePlacesKey,
      // Web key is the best default for server-style HTTP Places calls.
      DefaultFirebaseOptions.web.apiKey,
      DefaultFirebaseOptions.currentPlatform.apiKey,
    ];
    // De-dupe while preserving order.
    final seen = <String>{};
    return [
      for (final k in keys)
        if (seen.add(k)) k,
    ];
  }
}
