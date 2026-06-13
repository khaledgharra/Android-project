import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'deadlines_screen.dart';
import 'courses_screen.dart';
import 'today_timeline_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
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
  int _upcomingDeadlinesCount = 0;
  int _activeCoursesCount = 0;
  List<Map<String, dynamic>> _sortedTodaySchedule = [];

  List<Map<String, dynamic>> _reminders = [];
  static const String _remindersKey = 'user_reminders';

  Set<String> _completedItemIds = {};
  static const String _completedTasksKey = 'completed_tasks_ids';

  final GlobalKey<TodayTimelineScreenState> _calendarKey = GlobalKey<TodayTimelineScreenState>();
  final GlobalKey<CoursesScreenState> _coursesKey = GlobalKey<CoursesScreenState>();
  final GlobalKey<DeadlinesScreenState> _deadlinesKey = GlobalKey<DeadlinesScreenState>();

  late final List<Widget> _screens;

  Future<void> _loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_remindersKey);
    if (!mounted) return;
    setState(() {
      _reminders = raw == null ? [] : List<Map<String, dynamic>>.from(jsonDecode(raw));
    });
  }

  Future<void> _saveReminders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_remindersKey, jsonEncode(_reminders));
  }

  void _showRemindersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RemindersSheet(
        initialReminders: List.from(_reminders),
        onChanged: (updated) {
          setState(() => _reminders = updated);
          _saveReminders();
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadReminders();
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
      case 0: _loadDashboardStats(); _loadReminders(); break;
      case 1: _calendarKey.currentState?.loadTodayEvents(); break;
      case 2: _coursesKey.currentState?.loadCourses(); break;
      case 3: _deadlinesKey.currentState?.loadDeadlines(); break;
    }
  }

  Widget _buildDashboardTab() {
    return _DashboardTabContent(
      isLoading: _isLoadingCounts,
      remindersCount: _reminders.length,
      deadlines: _upcomingDeadlinesCount,
      courses: _activeCoursesCount,
      scheduleList: _sortedTodaySchedule,
      completedIds: _completedItemIds,
      onRefreshProfile: _loadDashboardStats,
      onDeadlinesTap: () => _onTabTapped(3),
      onCoursesTap: () => _onTabTapped(2),
      onScheduleTap: () => _onTabTapped(1),
      onRemindersTap: _showRemindersSheet,
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
  final int remindersCount;
  final int deadlines;
  final int courses;
  final List<Map<String, dynamic>> scheduleList;
  final Set<String> completedIds;
  final VoidCallback onRefreshProfile;
  final VoidCallback onDeadlinesTap;
  final VoidCallback onCoursesTap;
  final VoidCallback onScheduleTap;
  final VoidCallback onRemindersTap;
  final Function(String, bool) onToggleDone;

  const _DashboardTabContent({
    required this.isLoading,
    required this.remindersCount,
    required this.deadlines,
    required this.courses,
    required this.scheduleList,
    required this.completedIds,
    required this.onRefreshProfile,
    required this.onDeadlinesTap,
    required this.onCoursesTap,
    required this.onScheduleTap,
    required this.onRemindersTap,
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
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
                            onPressed: () async {
                              await AuthService.signOut();
                              if (context.mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                                  (route) => false,
                                );
                              }
                            },
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
                  title: 'Reminders',
                  value: '$remindersCount',
                  icon: Icons.notifications_rounded,
                  color: const Color(0xFF3B6FE8),
                  onTap: onRemindersTap,
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
              Text("Today's Schedule",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: onSurface)),
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
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onToggleDone(docId, !isDone);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isDone
                            ? (isDark ? Colors.grey.shade800 : Colors.grey.shade100)
                            : cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDone ? Colors.grey.shade700.withOpacity(0.4) : Colors.deepPurple.withOpacity(0.15),
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
                                      color: isDone ? Colors.grey.shade500 : onSurface,
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
          color: Theme.of(context).cardColor,
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
            Text(title, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Reminders Sheet
// ─────────────────────────────────────────────
class _RemindersSheet extends StatefulWidget {
  final List<Map<String, dynamic>> initialReminders;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  const _RemindersSheet({required this.initialReminders, required this.onChanged});

  @override
  State<_RemindersSheet> createState() => _RemindersSheetState();
}

class _RemindersSheetState extends State<_RemindersSheet> {
  late List<Map<String, dynamic>> _reminders;
  final _textController = TextEditingController();
  DateTime? _pickedDate;
  TimeOfDay? _pickedTime;

  @override
  void initState() {
    super.initState();
    _reminders = List.from(widget.initialReminders);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _addReminder() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final reminder = <String, dynamic>{'id': DateTime.now().millisecondsSinceEpoch.toString(), 'text': text};
    if (_pickedDate != null) reminder['date'] = '${_pickedDate!.day}/${_pickedDate!.month}/${_pickedDate!.year}';
    if (_pickedTime != null) reminder['time'] = _pickedTime!.format(context);
    setState(() {
      _reminders.add(reminder);
      _textController.clear();
      _pickedDate = null;
      _pickedTime = null;
    });
    widget.onChanged(List.from(_reminders));
  }

  void _deleteReminder(int index) {
    setState(() => _reminders.removeAt(index));
    widget.onChanged(List.from(_reminders));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A2E) : Colors.white;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: const Color(0xFF3B6FE8).withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.notifications_rounded, color: Color(0xFF3B6FE8), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Reminders', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (_reminders.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF3B6FE8).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Text('${_reminders.length}', style: const TextStyle(color: Color(0xFF3B6FE8), fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Add input area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          decoration: InputDecoration(
                            hintText: "What do you need to remember?",
                            hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                            filled: true,
                            fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                          onSubmitted: (_) => _addReminder(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _addReminder,
                        child: Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(color: const Color(0xFF3B6FE8), borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Optional date + time chips
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context, initialDate: _pickedDate ?? DateTime.now(),
                            firstDate: DateTime(2020), lastDate: DateTime(2030),
                          );
                          if (d != null) setState(() => _pickedDate = d);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: _pickedDate != null ? const Color(0xFF3B6FE8).withOpacity(0.12) : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _pickedDate != null ? const Color(0xFF3B6FE8).withOpacity(0.4) : Colors.transparent),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.calendar_today_rounded, size: 13, color: _pickedDate != null ? const Color(0xFF3B6FE8) : Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              _pickedDate != null ? '${_pickedDate!.day}/${_pickedDate!.month}/${_pickedDate!.year}' : 'Date (optional)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _pickedDate != null ? const Color(0xFF3B6FE8) : Colors.grey),
                            ),
                            if (_pickedDate != null) ...[
                              const SizedBox(width: 6),
                              GestureDetector(onTap: () => setState(() => _pickedDate = null), child: const Icon(Icons.close_rounded, size: 13, color: Color(0xFF3B6FE8))),
                            ],
                          ]),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context, initialTime: _pickedTime ?? TimeOfDay.now(),
                            initialEntryMode: TimePickerEntryMode.inputOnly,
                          );
                          if (t != null) setState(() => _pickedTime = t);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: _pickedTime != null ? const Color(0xFF3B6FE8).withOpacity(0.12) : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _pickedTime != null ? const Color(0xFF3B6FE8).withOpacity(0.4) : Colors.transparent),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.access_time_rounded, size: 13, color: _pickedTime != null ? const Color(0xFF3B6FE8) : Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              _pickedTime != null ? _pickedTime!.format(context) : 'Time (optional)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _pickedTime != null ? const Color(0xFF3B6FE8) : Colors.grey),
                            ),
                            if (_pickedTime != null) ...[
                              const SizedBox(width: 6),
                              GestureDetector(onTap: () => setState(() => _pickedTime = null), child: const Icon(Icons.close_rounded, size: 13, color: Color(0xFF3B6FE8))),
                            ],
                          ]),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey.shade200),
            // List
            Expanded(
              child: _reminders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none_rounded, size: 56, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('No reminders yet', style: TextStyle(fontSize: 16, color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text('Type above to add one', style: TextStyle(fontSize: 13, color: Colors.grey.shade300)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _reminders.length,
                      itemBuilder: (_, i) {
                        final r = _reminders[i];
                        final hasDate = r['date'] != null && r['date'].toString().isNotEmpty;
                        final hasTime = r['time'] != null && r['time'].toString().isNotEmpty;
                        return Dismissible(
                          key: ValueKey(r['id'] ?? i),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(16)),
                            child: const Icon(Icons.delete_rounded, color: Colors.white),
                          ),
                          onDismissed: (_) => _deleteReminder(i),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF3B6FE8).withOpacity(0.1)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8, height: 8,
                                  decoration: const BoxDecoration(color: Color(0xFF3B6FE8), shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(r['text'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                      if (hasDate || hasTime) ...[
                                        const SizedBox(height: 4),
                                        Row(children: [
                                          if (hasDate) ...[
                                            Icon(Icons.calendar_today_rounded, size: 11, color: Colors.grey.shade500),
                                            const SizedBox(width: 4),
                                            Text(r['date'], style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                            const SizedBox(width: 8),
                                          ],
                                          if (hasTime) ...[
                                            Icon(Icons.access_time_rounded, size: 11, color: Colors.grey.shade500),
                                            const SizedBox(width: 4),
                                            Text(r['time'], style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                          ],
                                        ]),
                                      ],
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _deleteReminder(i),
                                  child: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade400),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Animated Bottom Navigation
// ─────────────────────────────────────────────
class _CustomBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _CustomBottomNav({required this.currentIndex, required this.onTap});

  @override
  State<_CustomBottomNav> createState() => _CustomBottomNavState();
}

class _CustomBottomNavState extends State<_CustomBottomNav> with TickerProviderStateMixin {
  static const _tabs = [
    (icon: Icons.dashboard_rounded, label: 'Overview'),
    (icon: Icons.calendar_today_rounded, label: 'Schedule'),
    (icon: Icons.school_rounded, label: 'Courses'),
    (icon: Icons.assignment_rounded, label: 'Deadlines'),
  ];

  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _scales;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_tabs.length, (i) =>
      AnimationController(vsync: this, duration: const Duration(milliseconds: 200), value: i == widget.currentIndex ? 1.0 : 0.0));
    _scales = _controllers.map((c) =>
      Tween<double>(begin: 1.0, end: 1.25).animate(CurvedAnimation(parent: c, curve: Curves.easeOutBack))).toList();
  }

  @override
  void didUpdateWidget(_CustomBottomNav old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _controllers[old.currentIndex].reverse();
      _controllers[widget.currentIndex].forward();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final textColor = isDark ? Colors.white70 : Colors.grey.shade500;

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: bg,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final selected = widget.currentIndex == i;
          final tab = _tabs[i];
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onTap(i);
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _scales[i],
                    child: Icon(
                      tab.icon,
                      size: 22,
                      color: selected ? Colors.deepPurple : textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Colors.deepPurple : textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: selected ? 18 : 0,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
