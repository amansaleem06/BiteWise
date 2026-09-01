import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/theme/app_theme.dart';
import 'core/widgets/firebase_setup_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseReady = await _initFirebase();

  runApp(
    firebaseReady
        ? const ProviderScope(child: TasteWiseApp())
        : const _SetupApp(),
  );
}

/// Initializes Firebase from the flutterfire-generated options.
Future<bool> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await _activateAppCheck();
    return true;
  } catch (e, st) {
    debugPrintStack(
      stackTrace: st,
      label: 'Firebase init failed — run `flutterfire configure`. $e',
    );
    return false;
  }
}

/// Requests Firebase App Check tokens without enforcing them client-side.
///
/// Enforcement is controlled in Firebase Console and must remain off until
/// App Check metrics confirm that release builds are receiving valid tokens.
Future<void> _activateAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode
          ? AppleProvider.debug
          : AppleProvider.appAttest,
    );
  } catch (e, st) {
    // Do not prevent startup while App Check is in monitor mode. Once console
    // enforcement is enabled, unverified Firebase requests will fail closed.
    debugPrintStack(stackTrace: st, label: 'App Check activation failed: $e');
  }
}

/// Friendly guidance instead of a crash when Firebase isn't configured yet.
class _SetupApp extends StatelessWidget {
  const _SetupApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const FirebaseSetupScreen(),
    );
  }
}
