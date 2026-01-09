import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'dart:async';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';

// Top-level function for background handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // To build for production: flutter build apk --dart-define=ENV=prod
    const env = String.fromEnvironment('ENV', defaultValue: 'dev');
    await dotenv.load(fileName: ".env.$env");
    
    try {
      await Firebase.initializeApp();
      
      // Pass all uncaught "fatal" errors from the framework to Crashlytics
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

      // Register background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Initialize Notification Service
      await NotificationService().initialize();
      
    } catch (e) {
      print("Initialization Error: $e");
    }

    runApp(const SaiApp());
  }, (error, stack) => FirebaseCrashlytics.instance.recordError(error, stack, fatal: true));
}

class SaiApp extends StatelessWidget {
  const SaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'S.AI',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

