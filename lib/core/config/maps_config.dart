import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Google Maps / Places API keys used by the app.
///
/// Maps SDK keys live in platform manifests; Places HTTP calls need the same
/// Google Cloud project with **Places API** enabled. If a restricted key
/// rejects HTTP, we fall back to the Firebase Web API key.
abstract final class MapsConfig {
  static const _iosMapsKey = 'AIzaSyCzQ_QdA7nJ9MnOHfZYj1ZnLx2VA0XTVX8';
  static const _androidMapsKey = 'AIzaSyC-qlh313FPRv9gbsvqQGLC1kVPUe4s5K0';

  static String get placesApiKey {
    if (kIsWeb) return DefaultFirebaseOptions.web.apiKey;
    try {
      if (Platform.isIOS) return _iosMapsKey;
      if (Platform.isAndroid) return _androidMapsKey;
    } catch (_) {}
    return DefaultFirebaseOptions.currentPlatform.apiKey;
  }

  static String get placesApiKeyFallback =>
      DefaultFirebaseOptions.currentPlatform.apiKey;
}
