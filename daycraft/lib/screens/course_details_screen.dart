import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class CourseDetailsScreen extends StatefulWidget {
  final String courseName;

  const CourseDetailsScreen({super.key, required this.courseName});

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen> {
  List<Map<String, dynamic>> courseDeadlines = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadCourseDeadlines();
  }

  Future<void> loadCourseDeadlines() async {
    final deadlines = await StorageService.loadDeadlines();
    if (!mounted) return;
    setState(() {
      courseDeadlines = deadlines.where((d) => d["course"] == widget.courseName).toList()
        ..sort((a, b) {
          final da = _parseDate(a["date"]?.toString() ?? "");
          final db = _parseDate(b["date"]?.toString() ?? "");
          if (da == null || db == null) return 0;
          return da.compareTo(db);
        });
      isLoading = false;
    });
  }

  DateTime? _parseDate(String s) {
    try { return DateTime.parse(s); } catch (_) {}
    try {
      final p = s.split("/");
      if (p.length == 3) return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
    } catch (_) {}
    return null;
  }

  String _countdown(String dateStr) {
    final date = _parseDate(dateStr);
    if (date == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = date.difference(today).inDays;
    if (diff < 0) return 'Overdue';
    if (diff == 0) return 'Today!';
    if (diff == 1) return 'Tomorrow';
    return '$diff days left';
  }

  Color _countdownColor(String c) {
    if (c == 'Overdue') return Colors.red.shade700;
    if (c == 'Today!') return Colors.red;
    if (c == 'Tomorrow') return Colors.orange;
    final d = int.tryParse(c.split(' ')[0]) ?? 999;
    if (d <= 3) return Colors.orange;
    if (d <= 7) return Colors.amber.shade700;
    return Colors.green;
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'Exam': return Colors.red;
      case 'Quiz': return Colors.blue;
      default: return Colors.orange;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Exam': return Icons.school_rounded;
      case 'Quiz': return Icons.quiz_rounded;
      default: return Icons.assignment_rounded;
    }
  }

  IconData _getCourseIcon() {
    final n = widget.courseName.toLowerCase();
    if (n.contains('algorithm') || n.contains('data structure')) return Icons.account_tree_rounded;
    if (n.contains('program') || n.contains('software') || n.contains('code')) return Icons.code_rounded;
    if (n.contains('network') || n.contains('protocol')) return Icons.wifi_rounded;
    if (n.contains('database') || n.contains('sql')) return Icons.storage_rounded;
    if (n.contains('security') || n.contains('cyber')) return Icons.security_rounded;
    if (n.contains('calculus') || n.contains('differential')) return Icons.functions_rounded;
    if (n.contains('math') || n.contains('algebra') || n.contains('linear') || n.contains('discrete')) return Icons.calculate_rounded;
    if (n.contains('statistic') || n.contains('probability')) return Icons.bar_chart_rounded;
    if (n.contains('physics') || n.contains('quantum')) return Icons.science_rounded;
    if (n.contains('machine learning') || n.contains('ai') || n.contains('neural')) return Icons.psychology_rounded;
    if (n.contains('operating system') || n.contains('linux')) return Icons.computer_rounded;
    if (n.contains('web') || n.contains('html')) return Icons.language_rounded;
    if (n.contains('mobile') || n.contains('android')) return Icons.phone_android_rounded;
    if (n.contains('engineer')) return Icons.engineering_rounded;
    return Icons.school_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final icon = _getCourseIcon();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Gradient App Bar ──
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF5C35C9), Color(0xFF3B6FE8)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 50, 24, 20),
                    child: Row(
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(icon, color: Colors.white, size: 30),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.courseName,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text(
                                courseDeadlines.isEmpty
                                    ? 'No deadlines'
                                    : '${courseDeadlines.length} deadline${courseDeadlines.length == 1 ? '' : 's'}',
                                style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            backgroundColor: const Color(0xFF5C35C9),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // ── Body ──
          isLoading
              ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              : courseDeadlines.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_outlined, size: 56, color: Colors.grey.shade300),
                            const SizedBox(height: 14),
                            Text("No deadlines for this course",
                                style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                            const SizedBox(height: 6),
                            Text("Add one from the Courses tab",
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = courseDeadlines[index];
                            final type = item["type"] ?? "Homework";
                            final typeColor = _typeColor(type);
                            final countdown = _countdown(item["date"]?.toString() ?? "");
                            final countdownColor = _countdownColor(countdown);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(color: typeColor.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4)),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [typeColor.withOpacity(0.08), typeColor.withOpacity(0.02)],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(left: 0, top: 0, bottom: 0,
                                      child: Container(
                                        width: 4,
                                        decoration: BoxDecoration(
                                          color: typeColor,
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(18), bottomLeft: Radius.circular(18),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 44, height: 44,
                                            decoration: BoxDecoration(
                                              color: typeColor.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(_typeIcon(type), color: typeColor, size: 22),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(item["title"] ?? "",
                                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                                const SizedBox(height: 4),
                                                Row(children: [
                                                  Icon(Icons.event_rounded, size: 12, color: Colors.grey.shade500),
                                                  const SizedBox(width: 4),
                                                  Text(item["date"] ?? "",
                                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                                ]),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              // Type chip
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: typeColor.withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Text(type,
                                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: typeColor)),
                                              ),
                                              if (countdown.isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: countdownColor.withOpacity(0.12),
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Text(countdown,
                                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: countdownColor)),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: courseDeadlines.length,
                        ),
                      ),
                    ),
        ],
      ),
    );
  }
}
