import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'deadlines_screen.dart';
import 'courses_screen.dart';
import 'today_timeline_screen.dart';
import 'settings_screen.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  bool _isLoadingCounts = true;
  int _todayTasksCount = 0;
  int _upcomingDeadlinesCount = 0;
  int _activeCoursesCount = 0;
  List<Map<String, dynamic>> _sortedTodaySchedule = [];

  Set<String> _completedItemIds = {};
  static const String _completedTasksKey = 'completed_tasks_ids';

  final GlobalKey<TodayTimelineScreenState> _calendarKey = GlobalKey<TodayTimelineScreenState>();
  final GlobalKey<CoursesScreenState> _coursesKey = GlobalKey<CoursesScreenState>();
  final GlobalKey<DeadlinesScreenState> _deadlinesKey = GlobalKey<DeadlinesScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
    _screens = [
      const SizedBox.shrink(),
      TodayTimelineScreen(key: _calendarKey),
      CoursesScreen(key: _coursesKey),
      DeadlinesScreen(key: _deadlinesKey),
    ];
  }

  bool _isItemForToday(Map<String, dynamic> item, DateTime today) {
    final dateVal = item['date']?.toString();
    if (dateVal != null && dateVal.isNotEmpty) {
      try {
        final parsed = DateTime.parse(dateVal);
        return parsed.year == today.year && parsed.month == today.month && parsed.day == today.day;
      } catch (_) {}
    }
    final startVal = item['start']?.toString() ?? '';
    if (startVal.isNotEmpty) {
      try {
        final dt = DateTime.parse(startVal);
        return dt.year == today.year && dt.month == today.month && dt.day == today.day;
      } catch (_) {}
    }
    return false;
  }

  Future<void> _loadDashboardStats() async {
    if (!mounted) return;
    setState(() => _isLoadingCounts = true);
    try {
      final results = await Future.wait([
        StorageService.loadSchedule(),
        StorageService.loadDeadlines(),
      ]);

      final rawSchedule = results[0] as List;
      final rawDeadlines = results[1] as List;

      final prefs = await SharedPreferences.getInstance();
      final List<String> savedCompletedList = prefs.getStringList(_completedTasksKey) ?? [];

      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);

      final courses = rawSchedule.where((item) {
        final String type = (item['type'] ?? '').toString().toLowerCase();
        return type == 'course' && item['name'] != null && !item.containsKey('courseName');
      }).toList();

      final globalTasks = rawSchedule.where((item) {
        final String type = (item['type'] ?? '').toString().toLowerCase();
        return type != 'course' && !item.containsKey('courseCode') && !item.containsKey('subject');
      }).toList();

      final todayOnlyTasks = globalTasks.where((item) => _isItemForToday(item, todayMidnight)).toList();

      List<Map<String, dynamic>> sortedList = List.from(todayOnlyTasks);
      sortedList.sort((a, b) {
        String parseTime(Map<String, dynamic> element) {
          final rawTime = element['startTime'] ?? element['start'] ?? element['time'] ?? '23:59';
          final timeStr = rawTime.toString().trim();
          if (timeStr.contains('T') || timeStr.contains(' ')) {
            try {
              final parsedDt = DateTime.parse(timeStr);
              return "${parsedDt.hour.toString().padLeft(2, '0')}:${parsedDt.minute.toString().padLeft(2, '0')}";
            } catch (_) {}
          }
          return timeStr.isNotEmpty ? timeStr : '23:59';
        }
        return parseTime(a).compareTo(parseTime(b));
      });

      if (mounted) {
        setState(() {
          _upcomingDeadlinesCount = rawDeadlines.length;
          _todayTasksCount = todayOnlyTasks.length;
          _activeCoursesCount = courses.length;
          _sortedTodaySchedule = sortedList;
          _completedItemIds = savedCompletedList.toSet();
          _isLoadingCounts = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading dashboard: $e");
      if (mounted) setState(() => _isLoadingCounts = false);
    }
  }

  void _onTabTapped(int idx) {
    setState(() => _currentIndex = idx);
    switch (idx) {
      case 0: _loadDashboardStats(); break;
      case 1: _calendarKey.currentState?.loadTodayEvents(); break;
      case 2: _coursesKey.currentState?.loadCourses(); break;
      case 3: _deadlinesKey.currentState?.loadDeadlines(); break;
    }
  }

  Widget _buildDashboardTab() {
    return _DashboardTabContent(
      isLoading: _isLoadingCounts,
      todayTasks: _todayTasksCount,
      deadlines: _upcomingDeadlinesCount,
      courses: _activeCoursesCount,
      scheduleList: _sortedTodaySchedule,
      completedIds: _completedItemIds,
      onRefreshProfile: _loadDashboardStats,
      onDeadlinesTap: () => _onTabTapped(3),
      onCoursesTap: () => _onTabTapped(2),
      onScheduleTap: () => _onTabTapped(1),
      onToggleDone: (id, isChecked) async {
        setState(() {
          if (isChecked) _completedItemIds.add(id);
          else _completedItemIds.remove(id);
        });
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList(_completedTasksKey, _completedItemIds.toList());
        } catch (e) {
          debugPrint("Failed to persist task state: $e");
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F3F8),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildDashboardTab(),
            _screens[1],
            _screens[2],
            _screens[3],
          ],
        ),
      ),
      bottomNavigationBar: _CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Dashboard Content
// ─────────────────────────────────────────────
class _DashboardTabContent extends StatelessWidget {
  final bool isLoading;
  final int todayTasks;
  final int deadlines;
  final int courses;
  final List<Map<String, dynamic>> scheduleList;
  final Set<String> completedIds;
  final VoidCallback onRefreshProfile;
  final VoidCallback onDeadlinesTap;
  final VoidCallback onCoursesTap;
  final VoidCallback onScheduleTap;
  final Function(String, bool) onToggleDone;

  const _DashboardTabContent({
    required this.isLoading,
    required this.todayTasks,
    required this.deadlines,
    required this.courses,
    required this.scheduleList,
    required this.completedIds,
    required this.onRefreshProfile,
    required this.onDeadlinesTap,
    required this.onCoursesTap,
    required this.onScheduleTap,
    required this.onToggleDone,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    const weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return "${weekdays[now.weekday % 7]}, ${months[now.month - 1]} ${now.day}";
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
    }

    final user = AuthService.currentUser;
    final displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : (user?.email?.split('@').first ?? 'Student');
    final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S';

    final doneCount = scheduleList.where((i) => completedIds.contains(i['id']?.toString())).length;
    final total = scheduleList.length;
    final progress = total > 0 ? doneCount / total : 0.0;

    return ListView(
      padding: EdgeInsets.zero,
      physics: const BouncingScrollPhysics(),
      children: [
        // ── Gradient Header Banner ──
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF5C35C9), Color(0xFF3B6FE8)],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_getGreeting()},',
                          style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w400),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          displayName,
                          style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getFormattedDate(),
                          style: const TextStyle(fontSize: 12, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  // Avatar + action icons
                  Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.settings_rounded, color: Colors.white70, size: 22),
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const SettingsScreen()),
                              );
                              onRefreshProfile();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 22),
                            onPressed: () => AuthService.signOut(),
                          ),
                        ],
                      ),
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
              // Progress bar (only when tasks exist)
              if (total > 0) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Today's progress", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    Text("$doneCount / $total done", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Stat Cards ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Tasks',
                  value: '$todayTasks',
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF3B6FE8),
                  onTap: onScheduleTap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Deadlines',
                  value: '$deadlines',
                  icon: Icons.assignment_late_rounded,
                  color: const Color(0xFF5C35C9),
                  onTap: onDeadlinesTap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Courses',
                  value: '$courses',
                  icon: Icons.school_rounded,
                  color: const Color(0xFFE83B8A),
                  onTap: onCoursesTap,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // ── Today's Schedule ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Today's Schedule",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87)),
              GestureDetector(
                onTap: onScheduleTap,
                child: Text("See all",
                    style: TextStyle(fontSize: 13, color: Colors.deepPurple.shade400, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (scheduleList.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.event_available_rounded, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text("No tasks today — enjoy your day!",
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: scheduleList.map((item) {
                final String docId = item['id']?.toString() ?? UniqueKey().toString();
                final bool isDone = completedIds.contains(docId);
                final String name = item['name'] ?? item['title'] ?? 'Scheduled Item';
                final String start = (item['start'] ?? item['startTime'] ?? '').toString();
                final String end = (item['end'] ?? item['endTime'] ?? '').toString();

                String fmt(String raw) {
                  if (raw.contains('T') || raw.contains(' ')) {
                    try {
                      final p = DateTime.parse(raw);
                      return "${p.hour.toString().padLeft(2, '0')}:${p.minute.toString().padLeft(2, '0')}";
                    } catch (_) {}
                  }
                  return raw;
                }

                final String timeDisplay = fmt(start).isNotEmpty && fmt(end).isNotEmpty
                    ? '${fmt(start)} – ${fmt(end)}'
                    : fmt(start).isNotEmpty ? fmt(start) : 'All Day';

                return Padding(
                  key: ValueKey(docId),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => onToggleDone(docId, !isDone),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isDone ? Colors.grey.shade100 : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDone ? Colors.grey.shade200 : Colors.deepPurple.withOpacity(0.15),
                          width: 1,
                        ),
                        boxShadow: isDone ? [] : [
                          BoxShadow(color: Colors.deepPurple.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            // Custom checkbox
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 24, height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDone ? Colors.deepPurple : Colors.transparent,
                                border: Border.all(
                                  color: isDone ? Colors.deepPurple : Colors.grey.shade400,
                                  width: 2,
                                ),
                              ),
                              child: isDone
                                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDone ? Colors.grey.shade400 : Colors.black87,
                                      decoration: isDone ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Icon(Icons.access_time_rounded, size: 12,
                                          color: isDone ? Colors.grey.shade400 : Colors.deepPurple.withOpacity(0.6)),
                                      const SizedBox(width: 4),
                                      Text(
                                        timeDisplay,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDone ? Colors.grey.shade400 : Colors.deepPurple.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

        const SizedBox(height: 30),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Stat Card
// ─────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Bottom Navigation
// ─────────────────────────────────────────────
class _CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _CustomBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: Colors.deepPurple,
      unselectedItemColor: Colors.grey.shade400,
      selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      elevation: 12,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded, size: 22), label: 'Overview'),
        BottomNavigationBarItem(icon: Icon(Icons.calendar_today_rounded, size: 20), label: 'Schedule'),
        BottomNavigationBarItem(icon: Icon(Icons.school_rounded, size: 22), label: 'Courses'),
        BottomNavigationBarItem(icon: Icon(Icons.assignment_rounded, size: 22), label: 'Deadlines'),
      ],
    );
  }
}
