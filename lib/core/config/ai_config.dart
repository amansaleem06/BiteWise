/// Compile-time configuration for AI features (Gemini).
///
/// SECURITY: same pattern as [MapsConfig] — no keys in source control.
/// Inject at build time:
///
///   flutter run --dart-define=GEMINI_API_KEY=AIza...
///   flutter build ipa --dart-define=GEMINI_API_KEY=AIza...
///
/// Create the key in Google AI Studio (aistudio.google.com) and restrict it
/// to the Generative Language API. CI (Codemagic) injects it from the same
/// secure group as PLACES_API_KEY.
abstract final class AiConfig {
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  static bool get hasGeminiKey => geminiApiKey.trim().isNotEmpty;

  /// Flash Lite for photo checks. 2.0 Flash for plans — higher free-tier
  /// room than 2.5, which is what was returning 429 "busy".
  static const String visionModel = 'gemini-2.0-flash';
  static const String planModel = 'gemini-2.0-flash';

  static const List<String> visionFallbacks = [
    'gemini-flash-lite-latest',
    'gemini-2.5-flash-lite',
    'gemini-flash-latest',
  ];
  static const List<String> planFallbacks = [
    'gemini-flash-latest',
    'gemini-2.5-flash',
  ];
}
