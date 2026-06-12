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
      // 1. Fetch backend layout models concurrently
      final results = await Future.wait([
        StorageService.loadSchedule(),
        StorageService.loadDeadlines(),
      ]);

      final rawSchedule = results[0] as List;
      final rawDeadlines = results[1] as List;

      // 2. Fetch local storage checkbox memory preferences
      final prefs = await SharedPreferences.getInstance();
      final List<String> savedCompletedList = prefs.getStringList(_completedTasksKey) ?? [];

      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);

      // 3. Keep only genuine task types (ignoring course objects completely)
      final globalTasks = rawSchedule.where((item) {
        final String type = (item['type'] ?? '').toString().toLowerCase();
        return type != 'course' && !item.containsKey('courseCode') && !item.containsKey('subject');
      }).toList();

      // 4. Narrow down arrays strictly to today's date context
      final todayOnlyTasks = globalTasks.where((item) => _isItemForToday(item, todayMidnight)).toList();

      // 5. Build sorted stream map array for display timeline
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
          _sortedTodaySchedule = sortedList;
          _completedItemIds = savedCompletedList.toSet(); 
          _isLoadingCounts = false;
        });
      }
    } catch (e) {
      debugPrint("Error pipeline overview parsing layout: $e");
      if (mounted) {
        setState(() => _isLoadingCounts = false);
      }
    }
  }

  void _onTabTapped(int idx) {
    setState(() => _currentIndex = idx);
    
    switch (idx) {
      case 0:
        _loadDashboardStats(); 
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
  }

  Widget _buildDashboardTab() {
    return _DashboardTabContent(
      isLoading: _isLoadingCounts,
      todayTasks: _todayTasksCount,
      deadlines: _upcomingDeadlinesCount,
      scheduleList: _sortedTodaySchedule,
      completedIds: _completedItemIds,
      onRefreshProfile: () {
        _loadDashboardStats();
      },
      onToggleDone: (id, isChecked) async {
        setState(() {
          if (isChecked) {
            _completedItemIds.add(id);
          } else {
            _completedItemIds.remove(id);
          }
        });
        
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList(_completedTasksKey, _completedItemIds.toList());
        } catch (e) {
          debugPrint("Failed to persist item state transformation check: $e");
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
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

// --- Dynamic Overview Content Area ---
class _DashboardTabContent extends StatelessWidget {
  final bool isLoading;
  final int todayTasks;
  final int deadlines;
  final List<Map<String, dynamic>> scheduleList;
  final Set<String> completedIds;
  final VoidCallback onRefreshProfile;
  final Function(String, bool) onToggleDone;

  const _DashboardTabContent({
    required this.isLoading,
    required this.todayTasks,
    required this.deadlines,
    required this.scheduleList,
    required this.completedIds,
    required this.onRefreshProfile,
    required this.onToggleDone,
  });

  String _getFormattedDate() {
    final now = DateTime.now();
    final weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    String dayName = weekdays[now.weekday % 7];
    String monthName = months[now.month - 1];
    
    return "$dayName, $monthName ${now.day}".toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.deepPurple),
      );
    }

    final user = AuthService.currentUser;
    final displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : (user?.email?.split('@').first ?? 'Student');

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      physics: const BouncingScrollPhysics(),
      children: [
        // --- Premium Header ---
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, $displayName', 
                      style: const TextStyle(
                        fontFamily: 'Avenir', 
                        fontSize: 23, 
                        fontWeight: FontWeight.w500, 
                        color: Color(0xFF222222), 
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getFormattedDate(),
                      style: TextStyle(
                        fontFamily: 'Avenir',
                        fontSize: 11, 
                        fontWeight: FontWeight.w600, 
                        color: Colors.deepPurple.shade300,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.settings_rounded, color: Colors.grey.shade600, size: 23),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                      onRefreshProfile();
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.logout_rounded, color: Colors.grey.shade600, size: 23),
                    onPressed: () async {
                      await AuthService.signOut();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // Shrunk Low-Profile Stats Bar Deck
        SizedBox(
          height: 75, // Lock uniform low profile height profile frame
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _BalancedInfoCard(title: 'Tasks Today', value: '$todayTasks', color: Colors.indigo)),
              const SizedBox(width: 12),
              Expanded(child: _BalancedInfoCard(title: 'Deadlines', value: '$deadlines', color: Colors.deepPurple)),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        const Text(
          "Today's Schedule", 
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        const SizedBox(height: 14),
        
        // Checklist Stream
        if (scheduleList.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36),
            alignment: Alignment.center,
            child: Text(
              'No tasks scheduled for today.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          )
        else
          ...scheduleList.map((item) {
            final String docId = item['id']?.toString() ?? UniqueKey().toString();
            final bool isDone = completedIds.contains(docId);
            final String name = item['name'] ?? item['title'] ?? 'Scheduled Item';

            final String start = (item['start'] ?? item['startTime'] ?? '').toString();
            final String end = (item['end'] ?? item['endTime'] ?? '').toString();
            
            String formatTimeString(String raw) {
              if (raw.contains('T') || raw.contains(' ')) {
                try {
                  final p = DateTime.parse(raw);
                  return "${p.hour.toString().padLeft(2, '0')}:${p.minute.toString().padLeft(2, '0')}";
                } catch (_) {}
              }
              return raw;
            }

            final String cleanStart = formatTimeString(start);
            final String cleanEnd = formatTimeString(end);
            final String timeDisplay = (cleanStart.isNotEmpty && cleanEnd.isNotEmpty) ? '$cleanStart - $cleanEnd' : (cleanStart.isNotEmpty ? cleanStart : 'All Day');

            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              key: ValueKey(docId),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isDone ? Colors.grey.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CheckboxListTile(
                  value: isDone,
                  activeColor: Colors.deepPurple,
                  checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  onChanged: (val) => onToggleDone(docId, val ?? false),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(
                    name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDone ? Colors.grey.shade400 : Colors.black87,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 14, color: isDone ? Colors.grey.shade400 : Colors.deepPurple.withOpacity(0.6)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            timeDisplay,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDone ? Colors.grey.shade400 : Colors.deepPurple.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

// --- Compacted, Lower Profile Stats Card Components ---
class _BalancedInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _BalancedInfoCard({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0), // Tightened inner vertical spacing
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title, 
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value, 
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: color),
                ),
              ],
            ),
          ),
          // Moved the color bar from bottom to side vertical pillar format for spatial efficiency
          Container(
            width: 3, 
            height: 24, 
            decoration: BoxDecoration(
              color: color, 
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Bottom Navigation View ---
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
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded, size: 22), label: 'Overview'),
        BottomNavigationBarItem(icon: Icon(Icons.calendar_today_rounded, size: 20), label: 'Schedule'),
        BottomNavigationBarItem(icon: Icon(Icons.school_rounded, size: 22), label: 'Courses'),
        BottomNavigationBarItem(icon: Icon(Icons.assignment_rounded, size: 22), label: 'Deadlines'),
      ],
    );
  }
}