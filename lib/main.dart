import 'dart:async';

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
  runApp(const _BootstrapApp());
}

/// Draws the brand screen immediately while Firebase starts in the background.
class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  late final Future<bool> _firebaseReady = _initFirebase();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _firebaseReady,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return snapshot.data!
              ? const ProviderScope(child: TasteWiseApp())
              : const _SetupApp();
        }
        return const _StartupApp();
      },
    );
  }
}

class _StartupApp extends StatelessWidget {
  const _StartupApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TasteWise',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A0C0C),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'DISCOVER. TASTE. SHARE.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.2,
                  color: Color(0xFF6B5752),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Initializes Firebase from the flutterfire-generated options.
Future<bool> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // App Check is in monitor mode. Starting it must not hold the first app
    // screen while the native provider obtains a token.
    unawaited(_activateAppCheck());
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
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
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
