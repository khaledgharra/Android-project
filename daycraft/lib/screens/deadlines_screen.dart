import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'deadline_details_screen.dart';

class DeadlinesScreen extends StatefulWidget {
  const DeadlinesScreen({super.key});

  @override
  State<DeadlinesScreen> createState() => DeadlinesScreenState();
}

class DeadlinesScreenState extends State<DeadlinesScreen> {
  List<String> availableCourses = ["None"];
  List<Map<String, dynamic>> _coursesList = [];
  final estimatedHoursController = TextEditingController();
  String sortOption = "Date";
  bool isEditing = false;
  int editingIndex = -1;
  List<Map<String, dynamic>> deadlines = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final results = await Future.wait([
      StorageService.loadSchedule(),
      StorageService.loadDeadlines(),
    ]);

    final schedule = results[0] as List<Map<String, dynamic>>;
    final loadedDeadlines = results[1] as List<Map<String, dynamic>>;

    final mainCourses = schedule
        .where((item) => item["type"] == "Course" && item["name"] != null)
        .toList();

    // Build name→colorInt map from courses
    final colorMap = <String, int>{};
    for (final c in mainCourses) {
      final name = c["name"]?.toString();
      final v = c["color"];
      if (name != null && v != null) {
        try { colorMap[name] = (v as num).toInt(); } catch (_) {}
      }
    }

    // Attach courseColor int directly to each deadline in memory
    final enriched = loadedDeadlines.map((d) {
      final courseName = d["course"]?.toString() ?? "";
      if (courseName.isEmpty || d["courseColor"] != null) return d;
      final colorInt = colorMap[courseName];
      if (colorInt == null) return d;
      return Map<String, dynamic>.from(d)..["courseColor"] = colorInt;
    }).toList();

    if (!mounted) return;
    setState(() {
      _coursesList = mainCourses;
      availableCourses = ["None", ...mainCourses.map((c) => c["name"].toString()).toSet().toList()];
      deadlines = enriched;
      sortDeadlines();
    });
  }

  Future<void> loadDeadlines() async {
    await _loadAll();
  }

  void sortDeadlines() {
    if (sortOption == "Date") {
      deadlines.sort((a, b) {
        final first = parseDeadlineDate(a["date"] ?? "");
        final second = parseDeadlineDate(b["date"] ?? "");
        if (first == null || second == null) return 0;
        return first.compareTo(second);
      });
    } else {
      deadlines.sort((a, b) {
        final first = a["course"] ?? "";
        final second = b["course"] ?? "";
        return first.compareTo(second);
      });
    }
  }

  DateTime? parseDeadlineDate(String date) {
    // Try ISO format first (yyyy-MM-dd)
    try {
      return DateTime.parse(date);
    } catch (_) {}
    // Try d/M/yyyy format
    try {
      final parts = date.split("/");
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return null;
  }

  final titleController = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  String selectedDeadlineType = "Homework";
  String selectedCourse = "None";

  Future<void> addDeadline() async {
    if (titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a deadline title")),
      );
      return;
    }

    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please choose a date")),
      );
      return;
    }

    if (selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please choose a time")),
      );
      return;
    }

    // Format time before popping dialog (context may become invalid after pop)
    final timeStr = selectedTime!.format(context);

    final newDeadline = {
      "title": titleController.text,
      "date": "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
      "time": timeStr,
      "type": selectedDeadlineType,
      "course": selectedCourse == "None" ? "" : selectedCourse,
      "estimatedHours": estimatedHoursController.text,
    };

    Navigator.pop(context);

    // Add to Firestore and get document ID
    final docId = await StorageService.addDeadline(newDeadline);
    if (docId != null) {
      newDeadline['id'] = docId;
    }

    if (!mounted) return;
    setState(() {
      deadlines.add(newDeadline);
      sortDeadlines();
    });

    titleController.clear();
    estimatedHoursController.clear();
    selectedDate = null;
    selectedTime = null;
  }

  void showAddDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Add Deadline"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: "Assignment / Exam...",
                        filled: true, fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Date & Time — single tap chains date → time
                    GestureDetector(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context, initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now(), lastDate: DateTime(2030),
                        );
                        if (pickedDate == null) return;
                        setDialogState(() => selectedDate = pickedDate);
                        final pickedTime = await showTimePicker(
                          context: context, initialTime: selectedTime ?? const TimeOfDay(hour: 23, minute: 59),
                          initialEntryMode: TimePickerEntryMode.inputOnly, helpText: "DUE TIME",
                        );
                        if (pickedTime != null) setDialogState(() => selectedTime = pickedTime);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50, borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selectedDate != null ? Colors.deepPurple.shade200 : Colors.grey.shade600.withOpacity(0.3))),
                        child: Row(children: [
                          Icon(Icons.event_rounded, size: 18, color: selectedDate != null ? Colors.deepPurple : Colors.grey),
                          const SizedBox(width: 10),
                          Text(
                            selectedDate != null
                                ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}${selectedTime != null ? '  ${selectedTime!.format(context)}' : ''}"
                                : "Set due date & time...",
                            style: TextStyle(fontWeight: FontWeight.w600, color: selectedDate != null ? Theme.of(context).colorScheme.onSurface : Colors.grey),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: estimatedHoursController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Estimated Study Hours",
                        filled: true, fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Course picker
                    GestureDetector(
                      onTap: () async {
                        final picked = await showModalBottomSheet<String>(
                          context: context,
                          builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Padding(padding: EdgeInsets.all(12), child: Text("Select Course", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                            ...availableCourses.map((c) => ListTile(title: Text(c), onTap: () => Navigator.pop(ctx, c))),
                          ])),
                        );
                        if (picked != null) setDialogState(() => selectedCourse = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade600.withOpacity(0.3))),
                        child: Row(children: [
                          const Icon(Icons.school_rounded, size: 16, color: Colors.deepPurple),
                          const SizedBox(width: 10),
                          Text(selectedCourse, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Type picker
                    GestureDetector(
                      onTap: () async {
                        final picked = await showModalBottomSheet<String>(
                          context: context,
                          builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Padding(padding: EdgeInsets.all(12), child: Text("Deadline Type", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                            ListTile(leading: const Icon(Icons.assignment, color: Colors.orange), title: const Text("Homework"), onTap: () => Navigator.pop(ctx, "Homework")),
                            ListTile(leading: const Icon(Icons.school, color: Colors.red), title: const Text("Exam"), onTap: () => Navigator.pop(ctx, "Exam")),
                            ListTile(leading: const Icon(Icons.quiz, color: Colors.blue), title: const Text("Quiz"), onTap: () => Navigator.pop(ctx, "Quiz")),
                          ])),
                        );
                        if (picked != null) setDialogState(() => selectedDeadlineType = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade600.withOpacity(0.3))),
                        child: Row(children: [
                          Icon(getDeadlineIcon(selectedDeadlineType), size: 16, color: getDeadlineTypeColor(selectedDeadlineType)),
                          const SizedBox(width: 10),
                          Text(selectedDeadlineType, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: addDeadline,
                  child: const Text("Add"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color getDeadlineTypeColor(String type) {
    switch (type) {
      case "Exam": return Colors.red;
      case "Quiz": return Colors.blue;
      case "Homework": return Colors.orange;
      default: return Colors.deepPurple;
    }
  }

  IconData getDeadlineIcon(String type) {
    switch (type) {
      case "Exam": return Icons.school_rounded;
      case "Quiz": return Icons.quiz_rounded;
      case "Homework": return Icons.assignment_rounded;
      default: return Icons.event_note_rounded;
    }
  }

  String _countdown(String dateStr) {
    final date = parseDeadlineDate(dateStr);
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

  Future<void> _deleteDeadlineItem(Map<String, dynamic> item) async {
    final docId = item['id'];
    if (docId != null) await StorageService.deleteDeadline(docId);
    if (!mounted) return;
    setState(() {
      deadlines.removeWhere((d) {
        if (docId != null) return d['id'] == docId;
        return d['title'] == item['title'] && d['date'] == item['date'];
      });
    });
  }

  List<Map<String, dynamic>> _tabItems(int tabIndex) {
    switch (tabIndex) {
      case 1: return deadlines.where((d) => d["type"] == "Exam").toList();
      case 2: return deadlines.where((d) => d["type"] == "Homework").toList();
      case 3: return deadlines.where((d) => d["type"] == "Quiz").toList();
      default: return List.from(deadlines);
    }
  }

  int _daysBetween(String date1, String date2) {
    final d1 = parseDeadlineDate(date1);
    final d2 = parseDeadlineDate(date2);
    if (d1 == null || d2 == null) return 0;
    return d2.difference(d1).inDays;
  }

  Widget _buildGapSeparator(int days) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.swap_vert_rounded, size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  '$days day${days == 1 ? '' : 's'} apart',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300, height: 1)),
        ],
      ),
    );
  }

  Widget _buildDeadlineCard(Map<String, dynamic> item) {
    final cardBg = Theme.of(context).cardColor;
    final type = item["type"] ?? "Homework";
    final typeColor = getDeadlineTypeColor(type);
    Color cardColor = typeColor;
    final storedColor = item["courseColor"];
    if (storedColor != null) {
      try { cardColor = Color((storedColor as num).toInt()); } catch (_) {}
    }
    final countdown = _countdown(item["date"]?.toString() ?? "");
    final countdownColor = _countdownColor(countdown);
    final globalIndex = deadlines.indexWhere((d) {
      if (item['id'] != null) return d['id'] == item['id'];
      return d['title'] == item['title'] && d['date'] == item['date'];
    });

    return Dismissible(
      key: ValueKey('${item['id'] ?? item['title']}_${item['date']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 14),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(18)),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text('Delete', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
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
        );
      },
      onDismissed: (_) => _deleteDeadlineItem(item),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DeadlineDetailsScreen(deadline: item, deadlineIndex: globalIndex)),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: cardColor.withOpacity(0.14), blurRadius: 14, offset: const Offset(0, 5))],
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
                        colors: [cardColor.withOpacity(0.07), cardColor.withOpacity(0.01)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0, top: 0, bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), bottomLeft: Radius.circular(18)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(color: cardColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                            child: Icon(getDeadlineIcon(type), color: cardColor, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item["title"] ?? "", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 3),
                                Row(children: [
                                  Icon(Icons.event_rounded, size: 12, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(item["date"] ?? "", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                  if (item["time"] != null && item["time"].toString().isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(item["time"].toString(), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                  ],
                                ]),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: typeColor, borderRadius: BorderRadius.circular(20)),
                            child: Text(type, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (item["course"] != null && item["course"].toString().isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: cardColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.school_rounded, size: 10, color: cardColor),
                                const SizedBox(width: 4),
                                Text(item["course"].toString(), style: TextStyle(fontSize: 11, color: cardColor, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (item["estimatedHours"] != null && item["estimatedHours"].toString().isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.access_time_rounded, size: 10, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text("${item["estimatedHours"]}h prep", style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                              ]),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (countdown.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: countdownColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                              child: Text(countdown, style: TextStyle(fontSize: 11, color: countdownColor, fontWeight: FontWeight.w700)),
                            ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => showEditDeadlineDialog(item),
                            child: Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.edit_rounded, size: 16, color: Colors.blue),
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
  }

  Widget _buildDeadlineList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text("Nothing here", style: TextStyle(fontSize: 18, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text("Tap + to add a deadline", style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    final widgets = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      widgets.add(_buildDeadlineCard(items[i]));
      if (i < items.length - 1) {
        final gap = _daysBetween(items[i]["date"]?.toString() ?? "", items[i + 1]["date"]?.toString() ?? "");
        if (gap > 0) widgets.add(_buildGapSeparator(gap));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: widgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Deadlines"),
              const SizedBox(width: 8),
              if (deadlines.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.deepPurple, borderRadius: BorderRadius.circular(12)),
                  child: Text('${deadlines.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort_rounded),
              onSelected: (value) => setState(() { sortOption = value; sortDeadlines(); }),
              itemBuilder: (_) => [
                const PopupMenuItem(value: "Date", child: Text("Sort by Date")),
                const PopupMenuItem(value: "Course", child: Text("Sort by Course")),
              ],
            ),
            const SizedBox(width: 4),
          ],
          bottom: TabBar(
            labelColor: Colors.deepPurple,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.deepPurple,
            indicatorWeight: 3,
            tabs: [
              const Tab(text: "All"),
              Tab(text: "Exams${deadlines.where((d) => d["type"] == "Exam").isNotEmpty ? ' (${deadlines.where((d) => d["type"] == "Exam").length})' : ''}"),
              Tab(text: "HW${deadlines.where((d) => d["type"] == "Homework").isNotEmpty ? ' (${deadlines.where((d) => d["type"] == "Homework").length})' : ''}"),
              Tab(text: "Quiz${deadlines.where((d) => d["type"] == "Quiz").isNotEmpty ? ' (${deadlines.where((d) => d["type"] == "Quiz").length})' : ''}"),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: "deadlines_fab",
          onPressed: () { clearDeadlineState(); showAddDialog(); },
          child: const Icon(Icons.add_rounded),
        ),
        body: TabBarView(
          children: [
            _buildDeadlineList(_tabItems(0)),
            _buildDeadlineList(_tabItems(1)),
            _buildDeadlineList(_tabItems(2)),
            _buildDeadlineList(_tabItems(3)),
          ],
        ),
      ),
    );
  }

  void showEditDeadlineDialog(Map<String, dynamic> item) {
    isEditing = true;
    editingIndex = deadlines.indexWhere((d) {
      if (item['id'] != null) return d['id'] == item['id'];
      return d['title'] == item['title'] && d['date'] == item['date'];
    });

    titleController.text = item["title"] ?? "";
    selectedDate = parseDeadlineDate(item["date"] ?? "") ?? DateTime.now();
    selectedTime = TimeOfDay.now();
    estimatedHoursController.text = item["estimatedHours"] ?? "";
    selectedDeadlineType = item["type"] ?? "Homework";
    selectedCourse = item["course"] == null || item["course"] == ""
        ? "None"
        : item["course"];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Edit Deadline"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        hintText: "Deadline Title",
                        filled: true, fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Date & Time chained
                    GestureDetector(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context, initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now(), lastDate: DateTime(2030),
                        );
                        if (pickedDate == null) return;
                        setDialogState(() => selectedDate = pickedDate);
                        final pickedTime = await showTimePicker(
                          context: context, initialTime: selectedTime ?? const TimeOfDay(hour: 23, minute: 59),
                          initialEntryMode: TimePickerEntryMode.inputOnly, helpText: "DUE TIME",
                        );
                        if (pickedTime != null) setDialogState(() => selectedTime = pickedTime);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50, borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selectedDate != null ? Colors.deepPurple.shade200 : Colors.grey.shade600.withOpacity(0.3))),
                        child: Row(children: [
                          Icon(Icons.event_rounded, size: 18, color: selectedDate != null ? Colors.deepPurple : Colors.grey),
                          const SizedBox(width: 10),
                          Text(
                            selectedDate != null
                                ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}${selectedTime != null ? '  ${selectedTime!.format(context)}' : ''}"
                                : "Set due date & time...",
                            style: TextStyle(fontWeight: FontWeight.w600, color: selectedDate != null ? Theme.of(context).colorScheme.onSurface : Colors.grey),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: estimatedHoursController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Estimated Study Hours",
                        filled: true, fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showModalBottomSheet<String>(
                          context: context,
                          builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Padding(padding: EdgeInsets.all(12), child: Text("Select Course", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                            ...availableCourses.map((c) => ListTile(title: Text(c), onTap: () => Navigator.pop(ctx, c))),
                          ])),
                        );
                        if (picked != null) setDialogState(() => selectedCourse = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade600.withOpacity(0.3))),
                        child: Row(children: [
                          const Icon(Icons.school_rounded, size: 16, color: Colors.deepPurple),
                          const SizedBox(width: 10),
                          Text(selectedCourse, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showModalBottomSheet<String>(
                          context: context,
                          builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Padding(padding: EdgeInsets.all(12), child: Text("Deadline Type", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                            ListTile(leading: const Icon(Icons.assignment, color: Colors.orange), title: const Text("Homework"), onTap: () => Navigator.pop(ctx, "Homework")),
                            ListTile(leading: const Icon(Icons.school, color: Colors.red), title: const Text("Exam"), onTap: () => Navigator.pop(ctx, "Exam")),
                            ListTile(leading: const Icon(Icons.quiz, color: Colors.blue), title: const Text("Quiz"), onTap: () => Navigator.pop(ctx, "Quiz")),
                          ])),
                        );
                        if (picked != null) setDialogState(() => selectedDeadlineType = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade600.withOpacity(0.3))),
                        child: Row(children: [
                          Icon(getDeadlineIcon(selectedDeadlineType), size: 16, color: getDeadlineTypeColor(selectedDeadlineType)),
                          const SizedBox(width: 10),
                          Text(selectedDeadlineType, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () { clearDeadlineState(); Navigator.pop(context); }, child: const Text("Cancel")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    final updatedData = {
                      "title": titleController.text,
                      "date": "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
                      "time": selectedTime!.format(context),
                      "type": selectedDeadlineType,
                      "course": selectedCourse == "None" ? "" : selectedCourse,
                      "estimatedHours": estimatedHoursController.text,
                    };

                    final docId = item['id'];
                    if (docId != null) {
                      await StorageService.updateDeadline(docId, updatedData);
                      updatedData['id'] = docId;
                    }

                    if (!mounted) return;
                    setState(() { if (editingIndex >= 0) deadlines[editingIndex] = updatedData; sortDeadlines(); });
                    clearDeadlineState();
                    Navigator.pop(context);
                  },
                  child: const Text("Update"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void clearDeadlineState() {
    estimatedHoursController.clear();
    titleController.clear();
    selectedCourse = "None";
    selectedDate = null;
    selectedTime = null;
    selectedDeadlineType = "Homework";
    isEditing = false;
    editingIndex = -1;
  }
}
