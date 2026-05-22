class ScheduleEvent {
  final String title;
  final String day;
  final String startTime;
  final String endTime;
  final bool isRecurring;

  ScheduleEvent({
    required this.title,
    required this.day,
    required this.startTime,
    required this.endTime,
    this.isRecurring = true,
  });
}