import 'package:flutter/material.dart';
import '../models/task.dart';
import 'schedule_screen.dart';
import '../services/storage_service.dart';
import 'deadlines_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, String>> todayTasks = [];
  List<Map<String, String>> upcomingDeadlines = [];

  final TextEditingController taskController = TextEditingController();

  @override
  void initState() {
    super.initState();

    loadTodayTasks();
    loadUpcomingDeadlines();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,

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

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [
                    const Text(
                      "Khaled",

                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
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

  Widget scheduleCard(Map<String, String> task) {
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

  Future<void> loadTodayTasks() async {
    final allTasks = await StorageService.loadSchedule();

    final now = DateTime.now();

    final currentDay = getDayName(now.weekday);

    final currentHour = now.hour;
    final currentMinute = now.minute;

    List<Map<String, String>> filtered = [];

    for (var task in allTasks) {
      if (task["day"] != currentDay) {
        continue;
      }

      final start = task["start"]!.split(":");

      final taskHour = int.parse(start[0]);

      final taskMinute = int.parse(start[1]);

      final isUpcoming =
          taskHour > currentHour ||
          (taskHour == currentHour && taskMinute >= currentMinute);

      if (isUpcoming) {
        filtered.add(task);
      }
    }

    setState(() {
      todayTasks = filtered;
    });
  }

  Future<void> loadUpcomingDeadlines() async {
    final allDeadlines = await StorageService.loadDeadlines();

    allDeadlines.sort((a, b) {
      final aDate = a["date"]!.split("/");

      final bDate = b["date"]!.split("/");

      final aDateTime = DateTime(
        int.parse(aDate[2]),
        int.parse(aDate[1]),
        int.parse(aDate[0]),
      );

      final bDateTime = DateTime(
        int.parse(bDate[2]),
        int.parse(bDate[1]),
        int.parse(bDate[0]),
      );

      return aDateTime.compareTo(bDateTime);
    });

    setState(() {
      upcomingDeadlines = allDeadlines.take(3).toList();
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
}
