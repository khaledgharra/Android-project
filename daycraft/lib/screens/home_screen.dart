import 'package:flutter/material.dart';
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
  
  final Set<String> _completedItemIds = {};

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

  Future<void> _loadDashboardStats() async {
    if (!mounted) return;
    setState(() => _isLoadingCounts = true);
    try {
      final results = await Future.wait([
        StorageService.loadSchedule(),
        StorageService.loadDeadlines(),
      ]);

      final rawSchedule = results[0];
      final rawDeadlines = results[1];

      final courses = rawSchedule.where((item) => item['type'] == 'Course').toList();
      final todayTasks = rawSchedule.where((item) => item['type'] != 'Course').toList();

      List<Map<String, dynamic>> sortedList = List.from(rawSchedule);
      sortedList.sort((a, b) {
        final String timeA = (a['startTime'] ?? a['start'] ?? a['time'] ?? '23:59').toString();
        final String timeB = (b['startTime'] ?? b['start'] ?? b['time'] ?? '23:59').toString();
        return timeA.compareTo(timeB);
      });

      if (mounted) {
        setState(() {
          _activeCoursesCount = courses.length;
          _upcomingDeadlinesCount = rawDeadlines.length;
          _todayTasksCount = todayTasks.length;
          _sortedTodaySchedule = sortedList;
          _isLoadingCounts = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading dashboard stats: $e");
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
      courses: _activeCoursesCount,
      scheduleList: _sortedTodaySchedule,
      completedIds: _completedItemIds,
      onRefreshProfile: () {
        // Triggers a refresh when coming back from Settings
        _loadDashboardStats();
      },
      onToggleDone: (id, isChecked) {
        setState(() {
          if (isChecked) {
            _completedItemIds.add(id);
          } else {
            _completedItemIds.remove(id);
          }
        });
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
  final int courses;
  final List<Map<String, dynamic>> scheduleList;
  final Set<String> completedIds;
  final VoidCallback onRefreshProfile;
  final Function(String, bool) onToggleDone;

  const _DashboardTabContent({
    required this.isLoading,
    required this.todayTasks,
    required this.deadlines,
    required this.courses,
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
        // --- High-Fidelity Soft Premium Header ---
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
                        color: Color(0xFF222222), // Fixed the compile error color here
                        letterSpacing: 0.0,
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
                      // Await navigation path completion so it re-renders immediately on back press
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

        // Balanced & Clean Overview Cards
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _BalancedInfoCard(title: 'Tasks Today', value: '$todayTasks', color: Colors.indigo)),
              const SizedBox(width: 8),
              Expanded(child: _BalancedInfoCard(title: 'Deadlines', value: '$deadlines', color: Colors.deepPurple)),
              const SizedBox(width: 8),
              Expanded(child: _BalancedInfoCard(title: 'Courses', value: '$courses', color: Colors.pink)),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        const Text(
          "Today's Schedule", 
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        const SizedBox(height: 14),
        
        // Checklist Schedule Stream 
        if (scheduleList.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36),
            alignment: Alignment.center,
            child: Text(
              'No items scheduled yet for today.',
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
            final String timeDisplay = (start.isNotEmpty && end.isNotEmpty) ? '$start - $end' : (start.isNotEmpty ? start : 'All Day');

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

// --- Corrected Structural Modern Stats Cards ---
class _BalancedInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _BalancedInfoCard({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title, 
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black54),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                value, 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: 18, 
            height: 3, 
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