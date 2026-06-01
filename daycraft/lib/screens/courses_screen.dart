import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'course_details_screen.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
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

                    const Text(
                      "Lecture Time (Optional)",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 10),

                    DropdownButton<String>(
                      value: lectureDay,
                      isExpanded: true,

                      items: days.map((day) {
                        return DropdownMenuItem(value: day, child: Text(day));
                      }).toList(),

                      onChanged: (value) {
                        setDialogState(() {
                          lectureDay = value!;
                        });
                      },
                    ),

                    const SizedBox(height: 10),

                    ElevatedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );

                        if (picked != null) {
                          setDialogState(() {
                            lectureStart = picked;
                          });
                        }
                      },

                      child: Text(
                        lectureStart == null
                            ? "Select Lecture Start"
                            : lectureStart!.format(context),
                      ),
                    ),

                    const SizedBox(height: 10),

                    ElevatedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );

                        if (picked != null) {
                          setDialogState(() {
                            lectureEnd = picked;
                          });
                        }
                      },

                      child: Text(
                        lectureEnd == null
                            ? "Select Lecture End"
                            : lectureEnd!.format(context),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      "Tutorial Time (Optional)",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 10),

                    DropdownButton<String>(
                      value: tutorialDay,
                      isExpanded: true,

                      items: days.map((day) {
                        return DropdownMenuItem(value: day, child: Text(day));
                      }).toList(),

                      onChanged: (value) {
                        setDialogState(() {
                          tutorialDay = value!;
                        });
                      },
                    ),

                    const SizedBox(height: 10),

                    ElevatedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );

                        if (picked != null) {
                          setDialogState(() {
                            tutorialStart = picked;
                          });
                        }
                      },

                      child: Text(
                        tutorialStart == null
                            ? "Select Tutorial Start"
                            : tutorialStart!.format(context),
                      ),
                    ),

                    const SizedBox(height: 10),

                    ElevatedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );

                        if (picked != null) {
                          setDialogState(() {
                            tutorialEnd = picked;
                          });
                        }
                      },

                      child: Text(
                        tutorialEnd == null
                            ? "Select Tutorial End"
                            : tutorialEnd!.format(context),
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
              title: Text("Add Deadline"),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    Text(
                      course["name"],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      controller: deadlineTitleController,

                      decoration: const InputDecoration(
                        labelText: "Deadline Title",
                      ),
                    ),

                    const SizedBox(height: 20),

                    DropdownButton<String>(
                      value: selectedDeadlineType,

                      isExpanded: true,

                      items: const [
                        DropdownMenuItem(
                          value: "Homework",

                          child: Text("Homework"),
                        ),

                        DropdownMenuItem(value: "Exam", child: Text("Exam")),

                        DropdownMenuItem(value: "Quiz", child: Text("Quiz")),
                      ],

                      onChanged: (value) {
                        setDialogState(() {
                          selectedDeadlineType = value!;
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,

                          initialDate: DateTime.now(),

                          firstDate: DateTime.now(),

                          lastDate: DateTime(2030),
                        );

                        if (picked != null) {
                          setDialogState(() {
                            selectedDeadlineDate = picked;
                          });
                        }
                      },

                      child: Text(
                        selectedDeadlineDate == null
                            ? "Choose Date"
                            : selectedDeadlineDate!.toString().split(" ")[0],
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },

                  child: const Text("Cancel"),
                ),

                ElevatedButton(
                  onPressed: () async {
                    if (deadlineTitleController.text.trim().isEmpty ||
                        selectedDeadlineDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please choose a date and title"),
                        ),
                      );

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

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Deadline added")),
                    );
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
