import 'package:flutter/material.dart';
import 'schedule_screen.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import 'deadlines_screen.dart';
import 'courses_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> todayTasks = [];
  List<Map<String, dynamic>> upcomingDeadlines = [];

  final TextEditingController taskController = TextEditingController();

  @override
  void initState() {
    super.initState();

    loadTodayTasks();
    loadUpcomingDeadlines();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,

        type: BottomNavigationBarType.fixed,

        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,

        backgroundColor: Colors.white,

        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ScheduleScreen()),
            ).then((_) {
              loadTodayTasks();
            });
          }

          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CoursesScreen()),
            );
          }

          if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DeadlinesScreen()),
            ).then((_) {
              loadUpcomingDeadlines();
            });
          }
        },

        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),

          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: "Calendar",
          ),

          BottomNavigationBarItem(icon: Icon(Icons.school), label: "Courses"),

          BottomNavigationBarItem(
            icon: Icon(Icons.warning),
            label: "Deadlines",
          ),
        ],
      ),

      /*floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text("Add Task"),

                content: TextField(
                  controller: taskController,
                  decoration: const InputDecoration(
                    hintText: "Enter task name",
                  ),
                ),

                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text("Cancel"),
                  ),

                  ElevatedButton(
                    onPressed: () {
                      if (taskController.text.trim().isEmpty) {
                        return;
                      }

                      setState(() {
                        tasks.add(Task(title: taskController.text));
                      });

                      taskController.clear();

                      Navigator.pop(context);
                    },
                    child: const Text("Add"),
                  ),
                ],
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),*/
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                Text(
                  getGreeting(),
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),

                const SizedBox(height: 8),

                Text(
                  getFormattedDate(),
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),

                const SizedBox(height: 8),

                // Logout button
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.logout, color: Colors.grey),
                    tooltip: "Logout",
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Logout"),
                          content: const Text(
                            "Are you sure you want to logout?",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text("Cancel"),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text("Logout"),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await AuthService.signOut();
                      }
                    },
                  ),
                ),

                const SizedBox(height: 4),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [
                    Flexible(
                      child: Text(
                        _getUserDisplayName(),

                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        const Text(
                          "Upcoming Deadlines",

                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 2),

                        SizedBox(
                          height: 60,
                          width: 170,

                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,

                            itemCount: upcomingDeadlines.take(2).length,

                            itemBuilder: (context, index) {
                              final item = upcomingDeadlines[index];

                              return Container(
                                width: 80,

                                margin: const EdgeInsets.only(left: 4),

                                padding: const EdgeInsets.all(10),

                                decoration: BoxDecoration(
                                  color: Colors.red,

                                  borderRadius: BorderRadius.circular(16),
                                ),

                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,

                                  children: [
                                    Text(
                                      item["title"]!,

                                      maxLines: 1,

                                      overflow: TextOverflow.ellipsis,

                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    const Spacer(),

                                    Text(
                                      item["date"]!,

                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                const Text(
                  "Today's Tasks",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  height: 220,

                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),

                    itemCount: todayTasks.length,

                    itemBuilder: (context, index) {
                      final task = todayTasks[index];

                      return scheduleCard(task);
                    },
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget scheduleCard(Map<String, dynamic> task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(20),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task["title"]!,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text("${task["start"]} - ${task["end"]}"),
        ],
      ),
    );
  }

  /// Parses a time string like "8:30 AM", "1:30 PM", or "13:30" into 24-hour (hour, minute)
  (int, int) _parseTime(String time) {
    final cleaned = time.trim().toUpperCase();
    final isPM = cleaned.contains("PM");
    final isAM = cleaned.contains("AM");
    final withoutPeriod = cleaned
        .replaceAll("AM", "")
        .replaceAll("PM", "")
        .trim();
    final parts = withoutPeriod.split(":");
    int hour = int.parse(parts[0].trim());
    int minute = parts.length > 1 ? int.parse(parts[1].trim()) : 0;

    if (isPM && hour != 12) {
      hour += 12;
    }
    if (isAM && hour == 12) {
      hour = 0;
    }
    return (hour, minute);
  }

  Future<void> loadTodayTasks() async {
    final allTasks = await StorageService.loadSchedule();

    final now = DateTime.now();

    final currentDay = getDayName(now.weekday);

    final currentHour = now.hour;
    final currentMinute = now.minute;

    List<Map<String, dynamic>> filtered = [];

    for (var task in allTasks) {
      if (task["day"] != currentDay) {
        continue;
      }

      if (task["start"] == null) continue;

      final (taskHour, taskMinute) = _parseTime(task["start"]!);

      final isUpcoming =
          taskHour > currentHour ||
          (taskHour == currentHour && taskMinute >= currentMinute);

      if (isUpcoming) {
        filtered.add(task);
      }
    }

    if (!mounted) return;
    setState(() {
      todayTasks = filtered;
    });
  }

  /// Parses a date string in either "yyyy-MM-dd" or "d/M/yyyy" format
  DateTime? _parseDeadlineDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    // Try ISO format first (yyyy-MM-dd)
    try {
      return DateTime.parse(dateStr);
    } catch (_) {}
    // Try d/M/yyyy format
    try {
      final parts = dateStr.split("/");
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return null;
  }

  Future<void> loadUpcomingDeadlines() async {
    final allDeadlines = await StorageService.loadDeadlines();

    // Filter out deadlines with unparseable dates
    final withDates = allDeadlines.where((d) => _parseDeadlineDate(d["date"]) != null).toList();

    withDates.sort((a, b) {
      final aDate = _parseDeadlineDate(a["date"])!;
      final bDate = _parseDeadlineDate(b["date"])!;
      return aDate.compareTo(bDate);
    });

    if (!mounted) return;
    setState(() {
      upcomingDeadlines = withDates.take(3).toList();
    });
  }

  String getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return "Monday";
      case 2:
        return "Tuesday";
      case 3:
        return "Wednesday";
      case 4:
        return "Thursday";
      case 5:
        return "Friday";
      case 6:
        return "Saturday";
      case 7:
        return "Sunday";
      default:
        return "";
    }
  }

  String getGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return "Good Morning ☀️";
    }

    if (hour < 18) {
      return "Good Afternoon 🌤";
    }

    return "Good Evening 🌙";
  }

  String getFormattedDate() {
    final now = DateTime.now();

    final day = getDayName(now.weekday);

    return "$day, "
        "${now.day}/${now.month}/${now.year}";
  }

  String _getUserDisplayName() {
    final user = AuthService.currentUser;
    if (user == null) return "Student";
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!;
    }
    // Use the part before @ in email
    final email = user.email ?? "";
    if (email.contains("@")) {
      return email.split("@")[0];
    }
    return "Student";
  }
}
