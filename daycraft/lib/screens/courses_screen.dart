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

  DateTime? selectedDeadlineDate;

  String selectedDeadlineType = "Homework";
  List<Map<String, dynamic>> courses = [];
  final courseNameController = TextEditingController();
  Color selectedColor = Colors.deepPurple;
  bool isEditing = false;
  int editingIndex = -1;

  String lectureDay = "Sunday";
  TimeOfDay? lectureStart;
  TimeOfDay? lectureEnd;

  String tutorialDay = "Sunday";
  TimeOfDay? tutorialStart;
  TimeOfDay? tutorialEnd;

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
      appBar: AppBar(title: const Text("Courses")),
      floatingActionButton: FloatingActionButton(
        heroTag: "courses_fab",
        onPressed: () {
          clearControllers();

          showAddCourseDialog();
        },
        child: const Icon(Icons.add),
      ),

      body: courses.isEmpty
          ? const Center(child: Text("No courses yet"))
          : ListView.builder(
              itemCount: courses.length,
              itemBuilder: (context, index) {
                final course = courses[index];

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,

                      MaterialPageRoute(
                        builder: (context) =>
                            CourseDetailsScreen(courseName: course["name"]),
                      ),
                    );
                  },

                  child: Container(
                    margin: const EdgeInsets.all(12),

                    padding: const EdgeInsets.all(16),

                    decoration: BoxDecoration(
                      color: Color(
                        course["color"] ?? Colors.deepPurple.value,
                      ).withOpacity(0.15),

                      borderRadius: BorderRadius.circular(20),

                      border: Border.all(
                        color: Color(
                          course["color"] ?? Colors.deepPurple.value,
                        ).withOpacity(0.4),
                      ),

                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),

                    child: ListTile(
                      leading: Icon(
                        Icons.school,
                        color: Color(
                          course["color"] ?? Colors.deepPurple.value,
                        ),
                      ),

                      title: Text(course["name"] ?? ""),

                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          if (course["lecture"] != null)
                            Text(
                              "Lecture: "
                              "${course["lecture"]["day"]} "
                              "${course["lecture"]["start"]} - "
                              "${course["lecture"]["end"]}",
                            ),

                          if (course["tutorial"] != null)
                            Text(
                              "Tutorial: "
                              "${course["tutorial"]["day"]} "
                              "${course["tutorial"]["start"]} - "
                              "${course["tutorial"]["end"]}",
                            ),
                        ],
                      ),

                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,

                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.assignment,
                              color: Colors.deepPurple,
                            ),

                            onPressed: () {
                              showAddDeadlineDialog(course);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),

                            onPressed: () {
                              clearControllers();

                              showEditCourseDialog(course, index);
                            },
                          ),

                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),

                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,

                                builder: (context) {
                                  return AlertDialog(
                                    title: const Text("Delete Course"),

                                    content: Text(
                                      "Are you sure you want to delete ${course["name"]}?",
                                    ),

                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context, false);
                                        },

                                        child: const Text("Cancel"),
                                      ),

                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(context, true);
                                        },

                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),

                                        child: const Text("Delete"),
                                      ),
                                    ],
                                  );
                                },
                              );

                              if (confirm != true) {
                                return;
                              }

                              setState(() {
                                courses.removeAt(index);
                              });

                              final loaded =
                                  await StorageService.loadSchedule();

                              loaded.removeWhere((item) {
                                return item["type"] == "Course" &&
                                    (item["name"] == course["name"] ||
                                        item["courseName"] == course["name"]);
                              });

                              await StorageService.saveSchedule(loaded);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
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
                    const Text(
                      "Choose Course Color",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,

                      children:
                          [
                            Colors.deepPurple,
                            Colors.blue,
                            Colors.green,
                            Colors.orange,
                            Colors.red,
                          ].map((color) {
                            final selected = selectedColor == color;

                            return GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  selectedColor = color;
                                });
                              },

                              child: Container(
                                width: 36,
                                height: 36,

                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,

                                  border: selected
                                      ? Border.all(
                                          color: Colors.black,
                                          width: 3,
                                        )
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                    ),

                    // --- LECTURE SCHEDULE ---
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Lecture", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.deepPurple)),
                          const SizedBox(height: 10),
                          // Day row
                          _timeFieldRow(
                            icon: Icons.calendar_today,
                            label: "Day",
                            value: lectureDay,
                            onTap: () async {
                              final picked = await showModalBottomSheet<String>(
                                context: context,
                                builder: (ctx) => _dayPickerSheet(ctx, days),
                              );
                              if (picked != null) setDialogState(() => lectureDay = picked);
                            },
                          ),
                          const Divider(height: 16),
                          // Time row — single tap chains start → end
                          _timeFieldRow(
                            icon: Icons.schedule_rounded,
                            label: "Time",
                            value: lectureStart != null && lectureEnd != null
                                ? "${lectureStart!.format(context)} → ${lectureEnd!.format(context)}"
                                : "Set time...",
                            onTap: () async {
                              final pickedStart = await showTimePicker(context: context, initialTime: lectureStart ?? const TimeOfDay(hour: 8, minute: 0), initialEntryMode: TimePickerEntryMode.inputOnly, helpText: "LECTURE START");
                              if (pickedStart == null) return;
                              setDialogState(() => lectureStart = pickedStart);
                              final pickedEnd = await showTimePicker(context: context, initialTime: lectureEnd ?? pickedStart, initialEntryMode: TimePickerEntryMode.inputOnly, helpText: "LECTURE END");
                              if (pickedEnd != null) setDialogState(() => lectureEnd = pickedEnd);
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // --- TUTORIAL SCHEDULE ---
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Tutorial (Optional)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal)),
                          const SizedBox(height: 10),
                          _timeFieldRow(
                            icon: Icons.calendar_today,
                            label: "Day",
                            value: tutorialDay,
                            onTap: () async {
                              final picked = await showModalBottomSheet<String>(
                                context: context,
                                builder: (ctx) => _dayPickerSheet(ctx, days),
                              );
                              if (picked != null) setDialogState(() => tutorialDay = picked);
                            },
                          ),
                          const Divider(height: 16),
                          _timeFieldRow(
                            icon: Icons.schedule_rounded,
                            label: "Time",
                            value: tutorialStart != null && tutorialEnd != null
                                ? "${tutorialStart!.format(context)} → ${tutorialEnd!.format(context)}"
                                : "Set time...",
                            onTap: () async {
                              final pickedStart = await showTimePicker(context: context, initialTime: tutorialStart ?? const TimeOfDay(hour: 8, minute: 0), initialEntryMode: TimePickerEntryMode.inputOnly, helpText: "TUTORIAL START");
                              if (pickedStart == null) return;
                              setDialogState(() => tutorialStart = pickedStart);
                              final pickedEnd = await showTimePicker(context: context, initialTime: tutorialEnd ?? pickedStart, initialEntryMode: TimePickerEntryMode.inputOnly, helpText: "TUTORIAL END");
                              if (pickedEnd != null) setDialogState(() => tutorialEnd = pickedEnd);
                            },
                          ),
                        ],
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

    if (course["lecture"] != null) {
      lectureDay = course["lecture"]["day"];

      lectureStart = parseTime(course["lecture"]["start"]);

      lectureEnd = parseTime(course["lecture"]["end"]);
    }

    if (course["tutorial"] != null) {
      tutorialDay = course["tutorial"]["day"];

      tutorialStart = parseTime(course["tutorial"]["start"]);

      tutorialEnd = parseTime(course["tutorial"]["end"]);
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
                        filled: true, fillColor: Colors.grey.shade50,
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
                            ListTile(leading: const Icon(Icons.quiz, color: Colors.blue), title: const Text("Quiz"), onTap: () => Navigator.pop(ctx, "Quiz")),
                          ])),
                        );
                        if (picked != null) setDialogState(() => selectedDeadlineType = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
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
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selectedDeadlineDate != null ? Colors.deepPurple.shade200 : Colors.grey.shade200)),
                        child: Row(children: [
                          Icon(Icons.event_rounded, size: 18, color: selectedDeadlineDate != null ? Colors.deepPurple : Colors.grey),
                          const SizedBox(width: 10),
                          Text(
                            selectedDeadlineDate != null
                                ? "${selectedDeadlineDate!.day}/${selectedDeadlineDate!.month}/${selectedDeadlineDate!.year}"
                                : "Set due date...",
                            style: TextStyle(fontWeight: FontWeight.w600, color: selectedDeadlineDate != null ? Colors.black87 : Colors.grey),
                          ),
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
                  onPressed: () async {
                    if (deadlineTitleController.text.trim().isEmpty || selectedDeadlineDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please choose a date and title")));
                      return;
                    }
                    final deadlines = await StorageService.loadDeadlines();
                    deadlines.add({
                      "title": deadlineTitleController.text,
                      "course": course["name"],
                      "type": selectedDeadlineType,
                      "date": selectedDeadlineDate!.toString().split(" ")[0],
                    });
                    await StorageService.saveDeadlines(deadlines);
                    deadlineTitleController.clear();
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
    if (courseNameController.text.trim().isEmpty) {
      return;
    }
    final loadedSchedule = await StorageService.loadSchedule();
    bool overlaps(String day, String start, String end) {
      final startTime = parseTime(start);

      final endTime = parseTime(end);

      final newStart = startTime.hour * 60 + startTime.minute;

      final newEnd = endTime.hour * 60 + endTime.minute;

      return loadedSchedule.any((item) {
        if (item["day"] != day ||
            item["start"] == null ||
            item["end"] == null) {
          return false;
        }

        final existingStart = parseTime(item["start"]);

        final existingEnd = parseTime(item["end"]);

        final existingStartMinutes =
            existingStart.hour * 60 + existingStart.minute;

        final existingEndMinutes = existingEnd.hour * 60 + existingEnd.minute;

        return !(newEnd <= existingStartMinutes ||
            newStart >= existingEndMinutes);
      });
    }

    if (isEditing) {
      final oldCourseName = courses[editingIndex]["name"];

      loadedSchedule.removeWhere((item) {
        return item["type"] == "Course" &&
            (item["name"] == oldCourseName ||
                item["courseName"] == oldCourseName);
      });

      courses.removeAt(editingIndex);
    }

    final course = {
      "name": courseNameController.text,
      "type": "Course",
      "color": selectedColor.value,

      "lecture": lectureStart != null && lectureEnd != null
          ? {
              "day": lectureDay,
              "start": lectureStart!.format(context),
              "end": lectureEnd!.format(context),
            }
          : null,

      "tutorial": tutorialStart != null && tutorialEnd != null
          ? {
              "day": tutorialDay,
              "start": tutorialStart!.format(context),
              "end": tutorialEnd!.format(context),
            }
          : null,
    };

    loadedSchedule.add(course);

    if (course["lecture"] != null) {
      final lecture = course["lecture"] as Map<String, dynamic>;

      if (overlaps(lecture["day"], lecture["start"], lecture["end"])) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Lecture overlaps with another schedule item"),
          ),
        );

        return;
      }

      loadedSchedule.add({
        "title": "${course["name"]} Lecture",
        "type": "Course",
        "courseName": course["name"],
        "day": lecture["day"],
        "start": lecture["start"],
        "end": lecture["end"],
        "color": course["color"],
      });
    }

    if (course["tutorial"] != null) {
      final tutorial = course["tutorial"] as Map<String, dynamic>;

      if (overlaps(tutorial["day"], tutorial["start"], tutorial["end"])) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Tutorial overlaps with another schedule item"),
          ),
        );

        return;
      }

      loadedSchedule.add({
        "title": "${course["name"]} Tutorial",
        "type": "Course",
        "courseName": course["name"],
        "day": tutorial["day"],
        "start": tutorial["start"],
        "end": tutorial["end"],
        "color": course["color"],
      });
    }

    await StorageService.saveSchedule(loadedSchedule);

    setState(() {
      courses.add(course);
    });

    Navigator.pop(context);

    clearControllers();
  }

  Widget _timeFieldRow({required IconData icon, required String label, required String value, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: value != "—" ? Colors.deepPurple.shade100 : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: value != "—" ? Colors.deepPurple : Colors.grey),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: value != "—" ? Colors.black87 : Colors.grey)),
              ],
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

  void clearControllers() {
    lectureStart = null;
    lectureEnd = null;

    tutorialStart = null;
    tutorialEnd = null;

    lectureDay = "Sunday";
    tutorialDay = "Sunday";

    courseNameController.clear();
    isEditing = false;
    editingIndex = -1;

    selectedColor = Colors.deepPurple;
  }
}
