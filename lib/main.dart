import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:logger/logger.dart';
import 'core/config/env_config.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/onboarding/splash_screen.dart';

final logger = Logger(
  printer: PrettyPrinter(methodCount: 2, errorMethodCount: 5),
);

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Lock orientation
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Status bar style
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    // Environment setup
    const env = String.fromEnvironment('ENV', defaultValue: 'dev');
    switch (env) {
      case 'prod':
        EnvConfig.init(Environment.prod);
        break;
      case 'staging':
        EnvConfig.init(Environment.staging);
        break;
      default:
        EnvConfig.init(Environment.dev);
    }

    // Initialize Firebase
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      logger.i('Firebase initialized');
    } catch (e) {
      logger.w('Firebase init failed: $e');
    }

    // Global error handling — show errors on screen in debug mode
    FlutterError.onError = (details) {
      logger.e('Flutter error', error: details.exception, stackTrace: details.stack);
      FlutterError.presentError(details);
    };

    runApp(const ProviderScope(child: NearKartApp()));
  }, (error, stackTrace) {
    logger.f('Unhandled error', error: error, stackTrace: stackTrace);
  });
}

class NearKartApp extends StatelessWidget {
  const NearKartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NearKart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
