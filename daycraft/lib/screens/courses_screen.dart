import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'course_details_screen.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => CoursesScreenState();
}

class CoursesScreenState extends State<CoursesScreen> {
  final deadlineTitleController = TextEditingController();
  final deadlineEstimatedHoursController = TextEditingController();

  DateTime? selectedDeadlineDate;

  String selectedDeadlineType = "Homework";
  List<Map<String, dynamic>> courses = [];
  final courseNameController = TextEditingController();
  Color selectedColor = Colors.deepPurple;
  bool isEditing = false;
  int editingIndex = -1;

  bool _isSavingCourse = false;

  // Course events: each map has 'type', 'day', 'startCtrl' (TextEditingController), 'endCtrl' (TextEditingController)
  List<Map<String, dynamic>> _courseEvents = [];
  static const List<String> _eventTypes = ['Lecture', 'Tutorial', 'Workshop', 'Lab', 'Other'];

  final List<String> days = [
    "Sunday",
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
  ];

  @override
  void initState() {
    super.initState();
    loadCourses();
  }

  Future<void> loadCourses() async {
    final loaded = await StorageService.loadSchedule();
    if (!mounted) return;

    final onlyCourses = loaded
        .where((item) => item["type"] == "Course" && item["name"] != null)
        .toList();

    setState(() {
      courses = onlyCourses;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: "courses_fab",
        onPressed: () {
          clearControllers();
          showAddCourseDialog();
        },
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("My Courses",
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                      ],
                    ),
                  ),
                  if (courses.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${courses.length}",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Body ──
            Expanded(
              child: courses.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: courses.length,
                      itemBuilder: (context, index) => _buildCourseCard(context, index),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school_rounded, size: 44, color: Colors.deepPurple),
          ),
          const SizedBox(height: 20),
          Text("No courses yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text("Tap the button below to add your first course", style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildCourseCard(BuildContext context, int index) {
    final course = courses[index];
    final courseColor = Color(course["color"] ?? Colors.deepPurple.value);
    final themeIcon = _getCourseTheme(course["name"] ?? "");

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseDetailsScreen(courseName: course["name"]),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: courseColor.withOpacity(0.18), blurRadius: 16, offset: const Offset(0, 5)),
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // Gradient background
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [courseColor.withOpacity(0.13), courseColor.withOpacity(0.03)],
                    ),
                  ),
                ),
              ),
              // Large watermark icon
              Positioned(
                right: -10, top: -10,
                child: Icon(themeIcon, size: 100, color: courseColor.withOpacity(0.07)),
              ),
              // Left accent bar
              Positioned(
                left: 0, top: 0, bottom: 0,
                child: Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: courseColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(22),
                      bottomLeft: Radius.circular(22),
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon badge
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: courseColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: courseColor.withOpacity(0.2), width: 1),
                      ),
                      child: Icon(themeIcon, color: courseColor, size: 27),
                    ),
                    const SizedBox(width: 14),
                    // Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course["name"] ?? "",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                          ),
                          ...() {
                            final result = <Widget>[];
                            final events = course["events"];
                            if (events is List && events.isNotEmpty) {
                              for (final e in events.cast<Map>()) {
                                final t = e['type'] as String? ?? 'Lecture';
                                result.addAll([
                                  const SizedBox(height: 4),
                                  _scheduleChip(icon: _eventTypeIcon(t), label: "$t  ${e['day']}  ${e['start']} – ${e['end']}", color: _eventTypeColor(t)),
                                ]);
                              }
                              return result;
                            }
                            // Backward compat: old lectures + tutorial format
                            final rawLec = course["lectures"];
                            final lectures = (rawLec is List && rawLec.isNotEmpty) ? rawLec.cast<Map>() : course["lecture"] != null ? [course["lecture"] as Map] : <Map>[];
                            for (final lec in lectures) {
                              result.addAll([const SizedBox(height: 4), _scheduleChip(icon: Icons.cast_for_education_rounded, label: "Lecture  ${lec['day']}  ${lec['start']} – ${lec['end']}", color: courseColor)]);
                            }
                            if (course["tutorial"] != null) {
                              final t = course["tutorial"] as Map;
                              result.addAll([const SizedBox(height: 4), _scheduleChip(icon: Icons.people_rounded, label: "Tutorial  ${t['day']}  ${t['start']} – ${t['end']}", color: Colors.teal)]);
                            }
                            return result;
                          }(),
                        ],
                      ),
                    ),
                    // Actions
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _actionButton(Icons.assignment_rounded, Colors.deepPurple, () => showAddDeadlineDialog(course)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _actionButton(Icons.edit_rounded, Colors.blue, () {
                              clearControllers();
                              showEditCourseDialog(course, index);
                            }),
                            _actionButton(Icons.delete_rounded, Colors.red, () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text("Delete Course"),
                                  content: Text("Delete \"${course["name"]}\"?"),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      child: const Text("Delete"),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;
                              setState(() => courses.removeAt(index));
                              // Delete schedule items for this course
                              final loaded = await StorageService.loadSchedule();
                              loaded.removeWhere((item) =>
                                item["type"] == "Course" &&
                                (item["name"] == course["name"] || item["courseName"] == course["name"]));
                              await StorageService.saveSchedule(loaded);
                              // Delete all deadlines belonging to this course
                              final deadlines = await StorageService.loadDeadlines();
                              for (final d in deadlines) {
                                if (d["course"] == course["name"] && d["id"] != null) {
                                  await StorageService.deleteDeadline(d["id"]);
                                }
                              }
                            }),
                          ],
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
    );
  }

  Widget _scheduleChip({required IconData icon, required String label, required Color color}) {
    return Row(
      children: [
        Icon(icon, size: 11, color: color.withOpacity(0.8)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(label,
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _actionButton(IconData icon, Color color, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: color, size: 20),
      onPressed: onTap,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }


  void showAddCourseDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? "Edit Course" : "Add Course"),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    TextField(
                      controller: courseNameController,
                      decoration: const InputDecoration(
                        labelText: "Course Name",
                      ),
                    ),

                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showModalBottomSheet<Color>(
                          context: context,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          builder: (ctx) => _colorPickerSheet(ctx, selectedColor),
                        );
                        if (picked != null) setDialogState(() => selectedColor = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selectedColor.withOpacity(0.5), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: selectedColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: selectedColor.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text("Course Color", style: TextStyle(fontWeight: FontWeight.w600)),
                            const Spacer(),
                            const Text("Change", style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_ios, size: 13, color: Colors.deepPurple),
                          ],
                        ),
                      ),
                    ),

                    // --- COURSE EVENTS (lectures, tutorials, labs, workshops, etc.) ---
                    const SizedBox(height: 14),
                    ..._courseEvents.asMap().entries.map((entry) {
                      final i = entry.key;
                      final lt = entry.value;
                      final evtColor = _eventTypeColor(lt['type'] as String);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: evtColor.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Type picker chip
                                GestureDetector(
                                  onTap: () async {
                                    final picked = await showModalBottomSheet<String>(
                                      context: context,
                                      builder: (ctx) => SafeArea(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Padding(padding: EdgeInsets.all(14), child: Text("Event Type", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                            ...CoursesScreenState._eventTypes.map((t) => ListTile(
                                              leading: Icon(_eventTypeIcon(t), color: _eventTypeColor(t)),
                                              title: Text(t),
                                              onTap: () => Navigator.pop(ctx, t),
                                            )),
                                          ],
                                        ),
                                      ),
                                    );
                                    if (picked != null) setDialogState(() => _courseEvents[i]['type'] = picked);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(color: evtColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(_eventTypeIcon(lt['type'] as String), size: 13, color: evtColor),
                                        const SizedBox(width: 4),
                                        Text(lt['type'] as String, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: evtColor)),
                                        const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Day picker chip
                                GestureDetector(
                                  onTap: () async {
                                    final picked = await showModalBottomSheet<String>(
                                      context: context,
                                      builder: (ctx) => _dayPickerSheet(ctx, days),
                                    );
                                    if (picked != null) setDialogState(() => _courseEvents[i]['day'] = picked);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(color: Colors.grey.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text(lt['day'] as String, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                                        const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (_courseEvents.length > 1)
                                  GestureDetector(
                                    onTap: () => setDialogState(() => _courseEvents.removeAt(i)),
                                    child: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: lt['startCtrl'] as TextEditingController,
                                    decoration: InputDecoration(
                                      labelText: "Start",
                                      hintText: "09:00",
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      filled: true,
                                      fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade700 : Colors.white,
                                    ),
                                    keyboardType: TextInputType.datetime,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: lt['endCtrl'] as TextEditingController,
                                    decoration: InputDecoration(
                                      labelText: "End",
                                      hintText: "10:30",
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      filled: true,
                                      fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade700 : Colors.white,
                                    ),
                                    keyboardType: TextInputType.datetime,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setDialogState(() => _courseEvents.add({
                          'type': 'Lecture',
                          'day': 'Sunday',
                          'startCtrl': TextEditingController(),
                          'endCtrl': TextEditingController(),
                        })),
                        icon: const Icon(Icons.add_rounded, size: 16, color: Colors.deepPurple),
                        label: const Text("Add Event", style: TextStyle(color: Colors.deepPurple, fontSize: 13, fontWeight: FontWeight.w600)),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    clearControllers();
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),

                ElevatedButton(
                  onPressed: addCourse,
                  child: Text(isEditing ? "Update" : "Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void showEditCourseDialog(Map<String, dynamic> course, int index) {
    isEditing = true;
    editingIndex = index;

    courseNameController.text = course["name"] ?? "";

    selectedColor = Color(course["color"] ?? Colors.deepPurple.value);

    // Load events — support new "events" list and old "lectures"/"lecture" + "tutorial" formats
    _courseEvents.clear();
    final rawEvents = course["events"];
    if (rawEvents is List && rawEvents.isNotEmpty) {
      for (final e in rawEvents.cast<Map>()) {
        _courseEvents.add({
          'type': e['type'] ?? 'Lecture',
          'day': e['day'] ?? 'Sunday',
          'startCtrl': TextEditingController(text: e['start'] ?? ''),
          'endCtrl': TextEditingController(text: e['end'] ?? ''),
        });
      }
    } else {
      final rawLectures = course["lectures"];
      if (rawLectures is List && rawLectures.isNotEmpty) {
        for (final l in rawLectures.cast<Map>()) {
          _courseEvents.add({
            'type': 'Lecture',
            'day': l['day'] ?? 'Sunday',
            'startCtrl': TextEditingController(text: l['start'] != null ? _todToStr(parseTime(l['start'])) : ''),
            'endCtrl': TextEditingController(text: l['end'] != null ? _todToStr(parseTime(l['end'])) : ''),
          });
        }
      } else if (course["lecture"] != null) {
        final lec = course["lecture"] as Map;
        _courseEvents.add({
          'type': 'Lecture',
          'day': lec['day'] ?? 'Sunday',
          'startCtrl': TextEditingController(text: lec['start'] != null ? _todToStr(parseTime(lec['start'])) : ''),
          'endCtrl': TextEditingController(text: lec['end'] != null ? _todToStr(parseTime(lec['end'])) : ''),
        });
      }
      if (course["tutorial"] != null) {
        final tut = course["tutorial"] as Map;
        _courseEvents.add({
          'type': 'Tutorial',
          'day': tut['day'] ?? 'Sunday',
          'startCtrl': TextEditingController(text: tut['start'] != null ? _todToStr(parseTime(tut['start'])) : ''),
          'endCtrl': TextEditingController(text: tut['end'] != null ? _todToStr(parseTime(tut['end'])) : ''),
        });
      }
      if (_courseEvents.isEmpty) {
        _courseEvents.add({'type': 'Lecture', 'day': 'Sunday', 'startCtrl': TextEditingController(), 'endCtrl': TextEditingController()});
      }
    }

    showAddCourseDialog();
  }

  void showAddDeadlineDialog(Map<String, dynamic> course) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text("Add Deadline — ${course["name"]}"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: deadlineTitleController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: "Assignment / Exam...",
                        filled: true, fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
                          ])),
                        );
                        if (picked != null) setDialogState(() => selectedDeadlineType = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade700.withOpacity(0.3))),
                        child: Row(children: [
                          const Icon(Icons.category_rounded, size: 16, color: Colors.deepPurple),
                          const SizedBox(width: 10),
                          Text(selectedDeadlineType, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Date picker
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context, initialDate: DateTime.now(),
                          firstDate: DateTime.now(), lastDate: DateTime(2030),
                        );
                        if (picked != null) setDialogState(() => selectedDeadlineDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50, borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selectedDeadlineDate != null ? Colors.deepPurple.shade200 : Colors.grey.shade600.withOpacity(0.3))),
                        child: Row(children: [
                          Icon(Icons.event_rounded, size: 18, color: selectedDeadlineDate != null ? Colors.deepPurple : Colors.grey),
                          const SizedBox(width: 10),
                          Text(
                            selectedDeadlineDate != null
                                ? "${selectedDeadlineDate!.day}/${selectedDeadlineDate!.month}/${selectedDeadlineDate!.year}"
                                : "Set due date...",
                            style: TextStyle(fontWeight: FontWeight.w600, color: selectedDeadlineDate != null ? Theme.of(context).colorScheme.onSurface : Colors.grey),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: deadlineEstimatedHoursController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Estimated Study Hours",
                        filled: true, fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () { deadlineTitleController.clear(); deadlineEstimatedHoursController.clear(); Navigator.pop(context); }, child: const Text("Cancel")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    if (deadlineTitleController.text.trim().isEmpty || selectedDeadlineDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please choose a date and title")));
                      return;
                    }
                    final newDeadline = {
                      "title": deadlineTitleController.text,
                      "course": course["name"],
                      "type": selectedDeadlineType,
                      "date": selectedDeadlineDate!.toString().split(" ")[0],
                      "estimatedHours": deadlineEstimatedHoursController.text,
                    };
                    await StorageService.addDeadline(newDeadline);
                    deadlineTitleController.clear();
                    deadlineEstimatedHoursController.clear();
                    selectedDeadlineDate = null;
                    selectedDeadlineType = "Homework";
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deadline added ✓")));
                  },
                  child: const Text("Add"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  TimeOfDay parseTime(String time) {
    final cleaned = time.trim();

    final isPM = cleaned.contains("PM");
    final isAM = cleaned.contains("AM");

    final withoutPeriod = cleaned
        .replaceAll("AM", "")
        .replaceAll("PM", "")
        .trim();

    final parts = withoutPeriod.split(":");

    int hour = int.parse(parts[0]);
    int minute = int.parse(parts[1]);

    if (isPM && hour != 12) {
      hour += 12;
    }

    if (isAM && hour == 12) {
      hour = 0;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> addCourse() async {
    if (_isSavingCourse) return;
    if (courseNameController.text.trim().isEmpty) return;
    _isSavingCourse = true;

    try {
      final loadedSchedule = await StorageService.loadSchedule();

      bool overlaps(String day, String start, String end) {
        try {
          final newStart = _parseAnyTimeToMinutes(start);
          final newEnd = _parseAnyTimeToMinutes(end);
          return loadedSchedule.any((item) {
            if (item["day"] != day || item["start"] == null || item["end"] == null) return false;
            try {
              final es = _parseAnyTimeToMinutes(item["start"]);
              final ee = _parseAnyTimeToMinutes(item["end"]);
              return !(newEnd <= es || newStart >= ee);
            } catch (_) { return false; }
          });
        } catch (_) { return false; }
      }

      String? oldCourseName;
      int? removingIndex;

      if (isEditing) {
        oldCourseName = courses[editingIndex]["name"];
        removingIndex = editingIndex;
        loadedSchedule.removeWhere((item) =>
            item["type"] == "Course" &&
            (item["name"] == oldCourseName || item["courseName"] == oldCourseName));
      }

      // Collect and validate events from controllers
      final validEvents = <Map<String, String>>[];
      for (final evt in _courseEvents) {
        final startStr = (evt['startCtrl'] as TextEditingController).text.trim();
        final endStr = (evt['endCtrl'] as TextEditingController).text.trim();
        if (startStr.isEmpty || endStr.isEmpty) continue;
        if (!RegExp(r'^\d{1,2}:\d{2}$').hasMatch(startStr) || !RegExp(r'^\d{1,2}:\d{2}$').hasMatch(endStr)) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid time for ${evt['type']}: use HH:MM (e.g. 09:00)')));
          return;
        }
        validEvents.add({'type': evt['type'] as String, 'day': evt['day'] as String, 'start': startStr, 'end': endStr});
      }

      final course = {
        "name": courseNameController.text.trim(),
        "type": "Course",
        "color": selectedColor.value,
        "events": validEvents.isNotEmpty ? validEvents : null,
      };

      // Check overlaps
      for (final evt in validEvents) {
        if (overlaps(evt['day']!, evt['start']!, evt['end']!)) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Time Conflict"),
              content: Text("${evt['type']} (${evt['day']}  ${evt['start']} – ${evt['end']}) overlaps with another item."),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Add Anyway"),
                ),
              ],
            ),
          );
          if (proceed != true) return;
        }
      }

      loadedSchedule.add(course);
      for (final evt in validEvents) {
        loadedSchedule.add({
          "title": "${course["name"]} ${evt['type']}",
          "type": "Course",
          "courseName": course["name"],
          "day": evt['day'],
          "start": evt['start'],
          "end": evt['end'],
          "color": course["color"],
        });
      }

      await StorageService.saveSchedule(loadedSchedule);

      if (!mounted) return;
      setState(() {
        if (removingIndex != null) courses.removeAt(removingIndex);
        courses.add(course);
      });

      Navigator.pop(context);
      clearControllers();
    } finally {
      _isSavingCourse = false;
    }
  }

  Widget _timeFieldRow({required BuildContext context, required IconData icon, required String label, required String value, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: value != "—" ? Colors.deepPurple.shade200 : Colors.grey.shade400),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: value != "—" ? Colors.deepPurple : Colors.grey),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: value != "—" ? Theme.of(context).colorScheme.onSurface : Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorPickerSheet(BuildContext ctx, Color current) {
    final List<Color> colors = [
      // Purples
      Colors.deepPurple, Colors.purple, Colors.purpleAccent,
      const Color(0xFF7B2FBE), const Color(0xFF9B59B6), const Color(0xFFD7BDE2),
      // Blues
      Colors.blue, Colors.blueAccent, Colors.lightBlue,
      Colors.indigo, Colors.indigoAccent, const Color(0xFF2980B9),
      // Greens
      Colors.green, Colors.teal, Colors.tealAccent,
      Colors.lightGreen, const Color(0xFF1ABC9C), const Color(0xFF27AE60),
      // Reds / Pinks
      Colors.red, Colors.redAccent, Colors.pink,
      Colors.pinkAccent, const Color(0xFFE74C3C), const Color(0xFFC0392B),
      // Oranges / Yellows
      Colors.orange, Colors.orangeAccent, Colors.amber,
      Colors.yellow, const Color(0xFFF39C12), const Color(0xFFE67E22),
      // Neutrals / Others
      Colors.brown, Colors.blueGrey, const Color(0xFF2C3E50),
      const Color(0xFF7F8C8D), const Color(0xFF34495E), Colors.cyan,
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text("Choose Color", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: colors.map((color) {
                final isSelected = current.value == color.value;
                return GestureDetector(
                  onTap: () => Navigator.pop(ctx, color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.black87, width: 3)
                          : Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(color: color.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayPickerSheet(BuildContext ctx, List<String> days) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text("Select Day", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ...days.map((day) => ListTile(
              title: Text(day),
              leading: const Icon(Icons.calendar_today_outlined, size: 18),
              onTap: () => Navigator.pop(ctx, day),
            )),
          ],
        ),
      ),
    );
  }

  IconData _getCourseTheme(String name) {
    final n = name.toLowerCase();
    if (n.contains('algorithm') || n.contains('data structure') || n.contains('complexity')) return Icons.account_tree_rounded;
    if (n.contains('program') || n.contains('software') || n.contains('code') || n.contains('oop') || n.contains('object oriented')) return Icons.code_rounded;
    if (n.contains('web') || n.contains('html') || n.contains('javascript') || n.contains('frontend')) return Icons.language_rounded;
    if (n.contains('mobile') || n.contains('android') || n.contains('ios') || n.contains('flutter')) return Icons.phone_android_rounded;
    if (n.contains('database') || n.contains('sql')) return Icons.storage_rounded;
    if (n.contains('network') || n.contains('protocol') || n.contains('tcp') || n.contains('communication')) return Icons.wifi_rounded;
    if (n.contains('security') || n.contains('cyber') || n.contains('crypto')) return Icons.security_rounded;
    if (n.contains('machine learning') || n.contains('deep learning') || n.contains('neural') || n.contains('artificial intelligence')) return Icons.psychology_rounded;
    if (n.contains('operating system') || n.contains('kernel') || n.contains(' os ') || n.contains('linux')) return Icons.computer_rounded;
    if (n.contains('calculus') || n.contains('differential') || n.contains('integral')) return Icons.functions_rounded;
    if (n.contains('math') || n.contains('algebra') || n.contains('linear') || n.contains('discrete') || n.contains('geometry') || n.contains('topology') || n.contains('number theory')) return Icons.calculate_rounded;
    if (n.contains('statistic') || n.contains('probability') || n.contains('stochastic')) return Icons.bar_chart_rounded;
    if (n.contains('physics') || n.contains('mechanic') || n.contains('quantum') || n.contains('optic') || n.contains('electro')) return Icons.science_rounded;
    if (n.contains('chemistry') || n.contains('organic') || n.contains('biochem')) return Icons.biotech_rounded;
    if (n.contains('biology') || n.contains('genetic') || n.contains('molecular') || n.contains('cell')) return Icons.coronavirus_rounded;
    if (n.contains('electric') || n.contains('circuit') || n.contains('signal') || n.contains('digital system') || n.contains('analog')) return Icons.electrical_services_rounded;
    if (n.contains('econom') || n.contains('finance') || n.contains('business') || n.contains('accounting') || n.contains('management')) return Icons.trending_up_rounded;
    if (n.contains('english') || n.contains('language') || n.contains('literature') || n.contains('writing')) return Icons.menu_book_rounded;
    if (n.contains('history') || n.contains('civilization')) return Icons.history_edu_rounded;
    if (n.contains('philosoph') || n.contains('ethic') || n.contains('logic')) return Icons.lightbulb_rounded;
    if (n.contains('engineer') || n.contains('material') || n.contains('civil') || n.contains('mechanical') || n.contains('structural')) return Icons.engineering_rounded;
    if (n.contains('design') || n.contains('graphic') || n.contains('ui') || n.contains('ux') || n.contains('art')) return Icons.palette_rounded;
    if (n.contains('project') || n.contains('agile') || n.contains('scrum')) return Icons.assignment_rounded;
    if (n.contains('cloud') || n.contains('devops') || n.contains('docker') || n.contains('kubernetes')) return Icons.cloud_rounded;
    if (n.contains('computer') || n.contains('computation')) return Icons.laptop_rounded;
    return Icons.school_rounded;
  }

  String _todToStr(TimeOfDay tod) =>
      '${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}';

  int _parseAnyTimeToMinutes(String s) {
    final s2 = s.trim();
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s2);
    if (m != null) return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
    final tod = parseTime(s2);
    return tod.hour * 60 + tod.minute;
  }

  IconData _eventTypeIcon(String type) {
    switch (type) {
      case 'Tutorial': return Icons.people_rounded;
      case 'Workshop': return Icons.build_rounded;
      case 'Lab': return Icons.science_rounded;
      default: return Icons.cast_for_education_rounded;
    }
  }

  Color _eventTypeColor(String type) {
    switch (type) {
      case 'Tutorial': return Colors.teal;
      case 'Workshop': return Colors.orange;
      case 'Lab': return Colors.green;
      case 'Other': return Colors.blueGrey;
      default: return Colors.deepPurple;
    }
  }

  void clearControllers() {
    _courseEvents = [{'type': 'Lecture', 'day': 'Sunday', 'startCtrl': TextEditingController(), 'endCtrl': TextEditingController()}];

    courseNameController.clear();
    isEditing = false;
    editingIndex = -1;

    selectedColor = Colors.deepPurple;
  }
}
