import 'package:firebase_core/firebase_core.dart';
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
        ? const ProviderScope(child: BiteWiseApp())
        : const _SetupApp(),
  );
}

/// Initializes Firebase from the flutterfire-generated options.
Future<bool> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return true;
  } catch (e, st) {
    debugPrintStack(
      stackTrace: st,
      label: 'Firebase init failed — run `flutterfire configure`. $e',
    );
    return false;
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
