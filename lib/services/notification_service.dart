import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'user_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final UserService _userService = UserService();
  
  // Stream for handling notification taps
  final StreamController<String?> selectNotificationStream = StreamController<String?>.broadcast();

  static String get baseUrl => dotenv.env['API_URL'] ?? "http://10.0.2.2:8000";

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      tz.initializeTimeZones();
    } catch (e) {
      print("Timezone init error: $e");
    }

    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      print('User declined notification permission');
      // Continue anyway to allow local notifications
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        selectNotificationStream.add(response.payload);
      },
    );

    // Foreground Handler (FCM)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });

    try {
      // Check for supported platforms for FCM Token
      if (!kIsWeb) {
          // On Web, getToken requires VAPID key usually, checking if it works without
          String? token = await _firebaseMessaging.getToken();
          if (token != null) {
             await _sendTokenToBackend(token);
          }
           _firebaseMessaging.onTokenRefresh.listen((newToken) {
             _sendTokenToBackend(newToken);
          });
      } else {
          // Simplification for Web Demo: Skip FCM Token sync if configuration (VAPID) is missing
          // Use a dummy token or try-catch
          try {
             String? token = await _firebaseMessaging.getToken();
             if (token != null) await _sendTokenToBackend(token);
          } catch (e) {
             print("Web FCM Token skip: $e");
          }
      }
    } catch (e) {
      print("FCM Token Error: $e");
    }

    _isInitialized = true;
  }
  
  Future<void> syncTimezone() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _sendTokenToBackend(token);
      }
    } catch (e) {}
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'sai_proactive_channel', 
      'S.AI Messages', 
      channelDescription: 'Notifications from your AI friend',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    // Use a random ID or hashcode
    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? "S.AI",
      message.notification?.body,
      platformChannelSpecifics,
      payload: message.data['type'] ?? message.notification?.body,
    );
  }

  Future<void> _sendTokenToBackend(String token) async {
    final userId = await _userService.getUserId();
    
    String timezone = "UTC";
    try {
      dynamic tzResult = await FlutterTimezone.getLocalTimezone();
      timezone = tzResult.toString();
    } catch (e) {
      print("Failed to get timezone: $e");
    }
    
    try {
      await http.post(
        Uri.parse("$baseUrl/fcm_token"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "token": token,
          "timezone": timezone
        }),
      );
      print("FCM Token synced to server.");
    } catch (e) {
      print("Failed to sync FCM token: $e");
    }
  }

  Future<NotificationResponse?> getLaunchNotification() async {
    final details = await _localNotifications.getNotificationAppLaunchDetails();
    if (details != null && details.didNotificationLaunchApp) {
      return details.notificationResponse;
    }
    return null;
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    // Cross-Platform Schedule Strategy:
    // For this build, we use a simple Timer-based schedule which works on Web and Mobile.
    // This avoids compilation errors with 'zonedSchedule' and 'UILocalNotificationDateInterpretation'
    // which are missing or behave differently in the Web build of local_notifications.
    
    final delay = scheduledTime.difference(DateTime.now());
    if (!delay.isNegative) {
        Timer(delay, () async {
             const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
                'sai_reminders',
                'Reminders',
                channelDescription: 'Scheduled reminders',
                importance: Importance.high,
                priority: Priority.high,
            );
            const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

            await _localNotifications.show(
                id,
                title,
                body,
                platformDetails,
                payload: body
            );
        });
        print("Scheduled (Timer) notification $id in ${delay.inSeconds}s");
    }
  }

  Future<void> scheduleFromBackend(String content, String targetTimeStr) async {
    try {
        DateTime targetTime = DateTime.parse(targetTimeStr); 
        await scheduleNotification(
            id: targetTime.hashCode,
            title: "Reminder",
            body: content,
            scheduledTime: targetTime,
        );
    } catch (e) {
        print("Failed to schedule from backend: $e");
    }
  }
}
