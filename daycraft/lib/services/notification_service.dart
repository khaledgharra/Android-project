import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'storage_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Initialize the notification plugin
  static Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    _initialized = true;

    // Request permissions on Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Schedule a notification for 24 hours before a deadline
  static Future<void> scheduleDeadlineReminder({
    required String deadlineId,
    required String title,
    required DateTime deadlineDate,
    String? course,
  }) async {
    await initialize();

    // Schedule 24 hours before the deadline
    final scheduledTime = deadlineDate.subtract(const Duration(hours: 24));

    // Don't schedule if it's already in the past
    if (scheduledTime.isBefore(DateTime.now())) return;

    final id = deadlineId.hashCode.abs() % 2147483647; // Ensure valid int ID

    final body = course != null && course.isNotEmpty
        ? "📚 $course: \"$title\" is due tomorrow!"
        : "📚 \"$title\" is due tomorrow!";

    await _plugin.zonedSchedule(
      id,
      "⏰ Deadline Tomorrow!",
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'deadline_reminders',
          'Deadline Reminders',
          channelDescription: '24-hour reminders before deadlines',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
    );
  }

  /// Cancel a specific deadline reminder
  static Future<void> cancelDeadlineReminder(String deadlineId) async {
    final id = deadlineId.hashCode.abs() % 2147483647;
    await _plugin.cancel(id);
  }

  /// Schedule reminders for all upcoming deadlines
  static Future<void> scheduleAllDeadlineReminders() async {
    await initialize();

    // Cancel all existing notifications first
    await _plugin.cancelAll();

    final deadlines = await StorageService.loadDeadlines();
    final now = DateTime.now();

    for (var deadline in deadlines) {
      final dateStr = deadline["date"]?.toString();
      if (dateStr == null) continue;

      DateTime? deadlineDate;
      try {
        deadlineDate = DateTime.parse(dateStr);
      } catch (_) {
        try {
          final parts = dateStr.split("/");
          if (parts.length == 3) {
            deadlineDate = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          }
        } catch (_) {}
      }

      if (deadlineDate == null) continue;

      // Add time if available
      DateTime finalDate = deadlineDate;
      final timeStr = deadline["time"]?.toString();
      if (timeStr != null && timeStr.isNotEmpty) {
        try {
          final timeParts = timeStr.split(":");
          finalDate = DateTime(
            deadlineDate.year,
            deadlineDate.month,
            deadlineDate.day,
            int.parse(timeParts[0]),
            timeParts.length > 1 ? int.parse(timeParts[1]) : 0,
          );
        } catch (_) {}
      }

      // Only schedule for future deadlines
      if (finalDate.isAfter(now)) {
        await scheduleDeadlineReminder(
          deadlineId: deadline["id"] ?? dateStr,
          title: deadline["title"] ?? "Untitled Deadline",
          deadlineDate: finalDate,
          course: deadline["course"]?.toString(),
        );
      }
    }
  }
}
