import 'package:flutter/material.dart';
import 'today_timeline_screen.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import 'deadlines_screen.dart';
import 'courses_screen.dart';
import 'package:daycraft/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<DashboardTabState> _dashboardKey =
      GlobalKey<DashboardTabState>();
  final GlobalKey<TodayTimelineScreenState> _calendarKey =
      GlobalKey<TodayTimelineScreenState>();
  final GlobalKey<CoursesScreenState> _coursesKey =
      GlobalKey<CoursesScreenState>();
  final GlobalKey<DeadlinesScreenState> _deadlinesKey =
      GlobalKey<DeadlinesScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardTab(key: _dashboardKey),
      TodayTimelineScreen(key: _calendarKey),
      CoursesScreen(key: _coursesKey),
      DeadlinesScreen(key: _deadlinesKey),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, "Home"),
                _buildNavItem(1, Icons.calendar_today_rounded, "Calendar"),
                _buildNavItem(2, Icons.school_rounded, "Courses"),
                _buildNavItem(3, Icons.assignment_rounded, "Deadlines"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        // Refresh the target tab's data on switch
        switch (index) {
          case 0:
            _dashboardKey.currentState?.loadTodayTasks();
            _dashboardKey.currentState?.loadUpcomingDeadlines();
            break;
          case 1:
            _calendarKey.currentState?.loadTodayEvents();
            break;
          case 2:
            _coursesKey.currentState?.loadCourses();
            break;
          case 3:
            _deadlinesKey.currentState?.loadDeadlines();
            break;
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.deepPurple.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? Colors.deepPurple : Colors.grey.shade400,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.deepPurple,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The Dashboard / Home tab with greetings, urgent deadlines, and today's quick summary
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => DashboardTabState();
}

class DashboardTabState extends State<DashboardTab> {
  List<Map<String, dynamic>> todayTasks = [];
  List<Map<String, dynamic>> upcomingDeadlines = [];

  final Color backgroundColor = const Color(0xFFFDFBF7);
  final Color primaryAccent = Colors.deepPurple;
  final Color cardColor = Colors.white;

  @override
  void initState() {
    super.initState();
    loadTodayTasks();
    loadUpcomingDeadlines();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- TOP ROW: GREETINGS & LOGOUT ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          getGreeting(),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getUserDisplayName(),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.settings_rounded,
                          color: Colors.grey,
                        ),
                        tooltip: "Settings",
                        onPressed: () async {
                          // 1. Wait for the user to visit and leave the Settings screen
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => SettingsScreen()),
                          );

                          // 2. The moment they come back, force this screen to redraw with the fresh data
                          setState(() {});
                        },
                      ),
                    ),

                    const SizedBox(
                      width: 12,
                    ), // Elegant spacing between the two buttons

                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: Colors.grey,
                        ),
                        tooltip: "Logout",
                        onPressed: _handleLogout,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Date Header
                Text(
                  getFormattedDate(),
                  style: TextStyle(
                    fontSize: 15,
                    color: primaryAccent.withValues(alpha: 0.8),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 28),

                // --- URGENT DEADLINES ---
                const Text(
                  "Urgent Deadlines ⚡",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 14),
                _buildDeadlinesCarousel(),
                const SizedBox(height: 32),

                // --- TODAY'S UPCOMING SCHEDULE ---
                const Text(
                  "Today's Schedule 📅",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 14),
                _buildTasksTimeline(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeadlinesCarousel() {
    if (upcomingDeadlines.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Text(
          "🎉 No urgent deadlines coming up!",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: upcomingDeadlines.take(5).length,
        itemBuilder: (context, index) {
          final item = upcomingDeadlines[index];
          return Container(
            width: 190,
            margin: const EdgeInsets.only(right: 14, bottom: 6),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.red.shade300, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item["title"]?.toString() ?? "Untitled",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item["date"]?.toString() ?? "N/A",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTasksTimeline() {
    if (todayTasks.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            "No more tasks today 🎉",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: todayTasks.length,
      itemBuilder: (context, index) {
        final task = todayTasks[index];
        return _scheduleCard(task);
      },
    );
  }

  Widget _scheduleCard(Map<String, dynamic> task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 45,
            decoration: BoxDecoration(
              color: primaryAccent.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task["title"] ?? "",
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "${task["start"] ?? ""} - ${task["end"] ?? ""}",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AuthService.signOut();
    }
  }

  // --- Helpers ---
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
    if (isPM && hour != 12) hour += 12;
    if (isAM && hour == 12) hour = 0;
    return (hour, minute);
  }

  Future<void> loadTodayTasks() async {
    final allTasks = await StorageService.loadSchedule();
    final now = DateTime.now();
    final currentDay = _getDayName(now.weekday);
    final currentHour = now.hour;
    final currentMinute = now.minute;

    List<Map<String, dynamic>> filtered = [];
    for (var task in allTasks) {
      if (task["day"] != currentDay) continue;
      if (task["start"] == null) continue;

      final (taskHour, taskMinute) = _parseTime(task["start"]!);
      final isUpcoming =
          taskHour > currentHour ||
          (taskHour == currentHour && taskMinute >= currentMinute);

      if (isUpcoming) {
        filtered.add(task);
      }
    }

    // Sort by start time
    filtered.sort((a, b) {
      final (aH, aM) = _parseTime(a["start"]!);
      final (bH, bM) = _parseTime(b["start"]!);
      return (aH * 60 + aM).compareTo(bH * 60 + bM);
    });

    if (!mounted) return;
    setState(() => todayTasks = filtered);
  }

  DateTime? _parseDeadlineDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (_) {}
    try {
      final parts = dateStr.split("/");
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      }
    } catch (_) {}
    return null;
  }

  Future<void> loadUpcomingDeadlines() async {
    final allDeadlines = await StorageService.loadDeadlines();
    final now = DateTime.now();

    final upcoming = allDeadlines.where((d) {
      final date = _parseDeadlineDate(d["date"]?.toString());
      if (date == null) return true;
      return date.isAfter(now.subtract(const Duration(days: 1)));
    }).toList();

    upcoming.sort((a, b) {
      final dateA = _parseDeadlineDate(a["date"]?.toString());
      final dateB = _parseDeadlineDate(b["date"]?.toString());
      if (dateA == null || dateB == null) return 0;
      return dateA.compareTo(dateB);
    });

    if (!mounted) return;
    setState(() {
      upcomingDeadlines = upcoming;
    });
  }

  String _getDayName(int weekday) {
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
    if (hour < 12) return "Good Morning ☀️";
    if (hour < 18) return "Good Afternoon 🌤";
    return "Good Evening 🌙";
  }

  String getFormattedDate() {
    final now = DateTime.now();
    final day = _getDayName(now.weekday);
    return "$day, ${now.day}/${now.month}/${now.year}";
  }

  String _getUserDisplayName() {
    final user = AuthService.currentUser;
    if (user == null) return "Student";
    if (user.displayName != null && user.displayName!.isNotEmpty)
      return user.displayName!;
    final email = user.email ?? "";
    if (email.contains("@")) return email.split("@")[0];
    return "Student";
  }
}
