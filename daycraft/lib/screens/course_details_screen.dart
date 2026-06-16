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

  // Add-deadline form state
  final _titleCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  String _type = 'Homework';
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    loadCourseDeadlines();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _hoursCtrl.dispose();
    super.dispose();
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

  void _showAddDeadlineDialog() {
    _titleCtrl.clear();
    _hoursCtrl.clear();
    _type = 'Homework';
    _date = null;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? Colors.grey.shade800 : Colors.grey.shade50;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    Text("Add Deadline — ${widget.courseName}",
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    // Title
                    TextField(
                      controller: _titleCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: "Assignment / Exam...",
                        filled: true, fillColor: fill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Date picker
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: sheetCtx,
                          initialDate: _date ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setSheet(() => _date = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _date != null ? Colors.deepPurple.shade200 : Colors.grey.shade600.withOpacity(0.3),
                          ),
                        ),
                        child: Row(children: [
                          Icon(Icons.event_rounded, size: 18, color: _date != null ? Colors.deepPurple : Colors.grey),
                          const SizedBox(width: 10),
                          Text(
                            _date != null
                                ? "${_date!.day}/${_date!.month}/${_date!.year}"
                                : "Set due date...",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _date != null ? Theme.of(context).colorScheme.onSurface : Colors.grey,
                            ),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Type picker
                    GestureDetector(
                      onTap: () async {
                        final picked = await showModalBottomSheet<String>(
                          context: sheetCtx,
                          builder: (c) => SafeArea(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              const Padding(padding: EdgeInsets.all(12),
                                  child: Text("Deadline Type", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                              ListTile(
                                leading: const Icon(Icons.assignment, color: Colors.orange),
                                title: const Text("Homework"),
                                onTap: () => Navigator.pop(c, "Homework"),
                              ),
                              ListTile(
                                leading: const Icon(Icons.school, color: Colors.red),
                                title: const Text("Exam"),
                                onTap: () => Navigator.pop(c, "Exam"),
                              ),
                            ]),
                          ),
                        );
                        if (picked != null) setSheet(() => _type = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade600.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          Icon(_typeIcon(_type), size: 16, color: _typeColor(_type)),
                          const SizedBox(width: 10),
                          Text(_type, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Estimated hours
                    TextField(
                      controller: _hoursCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: "Estimated Study Hours",
                        filled: true, fillColor: fill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Buttons
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Cancel"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            if (_titleCtrl.text.trim().isEmpty || _date == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Please enter a title and date")),
                              );
                              return;
                            }
                            final newDeadline = {
                              "title": _titleCtrl.text.trim(),
                              "course": widget.courseName,
                              "type": _type,
                              "date": "${_date!.year}-${_date!.month.toString().padLeft(2, '0')}-${_date!.day.toString().padLeft(2, '0')}",
                              "estimatedHours": _hoursCtrl.text.trim(),
                            };
                            await StorageService.addDeadline(newDeadline);
                            if (!mounted) return;
                            Navigator.pop(sheetCtx);
                            await loadCourseDeadlines();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Deadline added ✓")),
                            );
                          },
                          child: const Text("Add"),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final icon = _getCourseIcon();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: "course_details_fab",
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        onPressed: _showAddDeadlineDialog,
        child: const Icon(Icons.add_rounded),
      ),
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
                            Text("Tap + to add one",
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = courseDeadlines[index];
                            final type = item["type"] ?? "Homework";
                            final typeColor = _typeColor(type);
                            final countdown = _countdown(item["date"]?.toString() ?? "");
                            final countdownColor = _countdownColor(countdown);
                            final cardBg = Theme.of(context).cardColor;

                            return Dismissible(
                              key: ValueKey(item['id'] ?? '${item['title']}_$index'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade400,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(Icons.delete_rounded, color: Colors.white, size: 26),
                              ),
                              confirmDismiss: (_) async => await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text("Delete Deadline"),
                                  content: Text('Delete "${item["title"]}"?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                      child: const Text("Delete"),
                                    ),
                                  ],
                                ),
                              ),
                              onDismissed: (_) async {
                                final docId = item['id'];
                                setState(() => courseDeadlines.removeAt(index));
                                if (docId != null) await StorageService.deleteDeadline(docId);
                              },
                              child: Container(
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
                                      Positioned(
                                        left: 0, top: 0, bottom: 0,
                                        child: Container(
                                          width: 4,
                                          decoration: BoxDecoration(
                                            color: typeColor,
                                            borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(18),
                                              bottomLeft: Radius.circular(18),
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
                                                    if (item["estimatedHours"] != null && item["estimatedHours"].toString().isNotEmpty) ...[
                                                      const SizedBox(width: 8),
                                                      Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade500),
                                                      const SizedBox(width: 4),
                                                      Text("${item["estimatedHours"]}h",
                                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                                    ],
                                                  ]),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
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
