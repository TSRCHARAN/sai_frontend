import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:io';
import 'dart:async';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final StreamController<String?> selectNotificationStream =
      StreamController<String?>.broadcast();

  Future<void> init() async {
    tz.initializeTimeZones();
    
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
    } catch (e) {
      print("Failed to set local timezone: $e");
      // Fallback to UTC or default if needed, but usually this works.
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true, // Show notification when app is open
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        selectNotificationStream.add(response.payload);
      },
    );
    
    if (Platform.isAndroid) {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // Ensure channel exists with the right importance (Android caches channel settings).
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'sai_reminders_v3', // Bumped version to reset settings
          'S.AI Reminders',
          description: 'Notifications for your plans and memories',
          importance: Importance.max,
        ),
      );

      final notifGranted = await androidPlugin?.requestNotificationsPermission();
      final exactGranted = await androidPlugin?.requestExactAlarmsPermission();

      if (kDebugMode) {
        print('DEBUG: Notifications permission granted? $notifGranted');
        print('DEBUG: Exact alarms permission granted? $exactGranted');
      }
    }
  }

  Future<NotificationResponse?> getLaunchNotification() async {
    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
      return notificationAppLaunchDetails?.notificationResponse;
    }
    return null;
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (scheduledTime.isBefore(DateTime.now())) {
        if (kDebugMode) {
            print("DEBUG: Skipped scheduling because time is in the past: $scheduledTime vs ${DateTime.now()}");
        }
        return;
    }

    // CRITICAL: Convert UTC DateTime to Local DateTime components before creating TZDateTime.
    // tz.TZDateTime.from() uses components as-is. 
    // If we pass 18:00 UTC, it creates 18:00 Local (which might be 12:30 UTC, i.e., in the past).
    final tzDateTime = tz.TZDateTime.from(scheduledTime.toLocal(), tz.local);

    if (kDebugMode) {
        print("DEBUG: Scheduling for Local: $tzDateTime (Original UTC: $scheduledTime)");
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'sai_reminders_v3',
        'S.AI Reminders',
        channelDescription: 'Notifications for your plans and memories',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        visibility: NotificationVisibility.public, // Shows content on lock screen
        category: AndroidNotificationCategory.reminder, // Helps OS prioritize
      ),
      iOS: DarwinNotificationDetails(),
    );

    // Production-safe scheduling:
    // - Prefer exact alarms when allowed
    // - Automatically fall back to inexact when the OS blocks exact alarms
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzDateTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: body,
      );
      if (kDebugMode) {
        print('DEBUG: Scheduled with exactAllowWhileIdle');
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('DEBUG: Exact schedule failed (${e.code}): ${e.message}');
      }
      // Common on Android 12+ when exact alarms are not permitted.
      if (e.code == 'exact_alarms_not_permitted') {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          tzDateTime,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: body,
        );
        if (kDebugMode) {
          print('DEBUG: Fallback scheduled with inexactAllowWhileIdle');
        }
      } else {
        rethrow;
      }
    }

    if (kDebugMode) {
      try {
        final pending = await flutterLocalNotificationsPlugin.pendingNotificationRequests();
        final hasThis = pending.any((p) => p.id == id);
        print('DEBUG: Pending notifications count=${pending.length}, contains id=$id? $hasThis');
      } catch (e) {
        print('DEBUG: pendingNotificationRequests failed: $e');
      }

      // Debug probe: if this does NOT show immediately, then the OS/app/channel is blocking notifications.
      // This isolates scheduling/alarm issues vs. notification permission/channel issues.
      try {
        await flutterLocalNotificationsPlugin.show(
          id + 1000000,
          'DEBUG: Notifications pipeline OK',
          'If you see this, the OS can display notifications. Scheduled reminder is set for $tzDateTime.',
          details,
        );
      } catch (e) {
        print('DEBUG: Immediate show() failed: $e');
      }
    }
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
  
  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  static Future<void> scheduleFromInsights(List<dynamic> insights) async {
    for (var item in insights) {
      if (item['target_time'] != null) {
        try {
          final DateTime scheduledTime = DateTime.parse(item['target_time']);
          final String content = item['content'] ?? "Reminder";
          
          // Generate a unique ID based on content hash (simple but effective for now)
          final int id = content.hashCode;
          
          await _instance.scheduleNotification(
            id: id,
            title: "S.AI Reminder",
            body: content,
            scheduledTime: scheduledTime,
          );
          
          if (kDebugMode) {
             print("DEBUG: Scheduled notification '$content' for $scheduledTime");
          }
        } catch (e) {
          print("Failed to schedule insight: $e");
        }
      }
    }
  }
}
