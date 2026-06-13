class NotificationService {
  static Future<void> initialize() async {}

  static Future<void> scheduleDeadlineReminder({
    required String deadlineId,
    required String title,
    required DateTime deadlineDate,
    String? course,
  }) async {}

  static Future<void> cancelDeadlineReminder(String deadlineId) async {}

  static Future<void> scheduleAllDeadlineReminders() async {}
}
