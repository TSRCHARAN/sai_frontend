import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // To build for production: flutter build apk --dart-define=ENV=prod
  const env = String.fromEnvironment('ENV', defaultValue: 'dev');
  await dotenv.load(fileName: ".env.$env"); // Loads .env.dev (default) or .env.prod
  
  await NotificationService().init();

  runApp(const SaiApp());
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

