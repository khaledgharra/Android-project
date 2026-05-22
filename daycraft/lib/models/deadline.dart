class Deadline {

  final String title;
  final String date;
  final String time;
  final String priority;
  final bool completed;

  Deadline({
    required this.title,
    required this.date,
    required this.time,
    this.priority = "Medium",
    this.completed = false,
  });
}