import '../../firebase_options.dart';

/// Google Maps / Places API keys used by the app.
///
/// Maps SDK keys stay in AndroidManifest / AppDelegate.
/// Restaurant search uses a dedicated Places REST key (Application
/// restrictions = None, API = Places only).
abstract final class MapsConfig {
  /// Dedicated Places REST key (Places API / Places API New).
  static const String placesRestKey =
      'AIzaSyBW-IvsG49beXJM153SR211R1jBJAe2xEs';

  /// Optional override: `flutter run --dart-define=PLACES_API_KEY=AIza...`
  static const String _dartDefinePlacesKey = String.fromEnvironment(
    'PLACES_API_KEY',
  );

  /// Ordered keys to try for Places HTTP.
  static List<String> get placesApiKeys {
    final keys = <String>[
      if (_dartDefinePlacesKey.isNotEmpty) _dartDefinePlacesKey,
      placesRestKey,
      DefaultFirebaseOptions.web.apiKey,
      DefaultFirebaseOptions.currentPlatform.apiKey,
    ];
    final seen = <String>{};
    return [for (final k in keys) if (seen.add(k)) k];
  }
}
