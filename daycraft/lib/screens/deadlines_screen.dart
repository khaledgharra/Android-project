import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'deadline_details_screen.dart';

class DeadlinesScreen extends StatefulWidget {
  const DeadlinesScreen({super.key});

  @override
  State<DeadlinesScreen> createState() => _DeadlinesScreenState();
}

class _DeadlinesScreenState extends State<DeadlinesScreen> {
  List<String> availableCourses = ["None"];
  final estimatedHoursController = TextEditingController();
  String sortOption = "Date";
  bool isEditing = false;
  int editingIndex = -1;
  List<Map<String, dynamic>> deadlines = [];
  @override
  void initState() {
    super.initState();
    loadCourses();
    loadDeadlines();
  }

  Future<void> loadDeadlines() async {
    final loaded = await StorageService.loadDeadlines();

    setState(() {
      deadlines = loaded;

      sortDeadlines();
    });
  }

  Future<void> loadCourses() async {
    final schedule = await StorageService.loadSchedule();

    final courses = schedule
        .where((item) {
          return item["type"] == "Course" && item["name"] != null;
        })
        .map<String>((item) {
          return item["name"];
        })
        .toSet()
        .toList();

    setState(() {
      availableCourses = ["None", ...courses];
    });
  }

  void sortDeadlines() {
    if (sortOption == "Date") {
      deadlines.sort((a, b) {
        final first = parseDeadlineDate(a["date"] ?? "");

        final second = parseDeadlineDate(b["date"] ?? "");

        if (first == null || second == null) {
          return 0;
        }

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
    try {
      return DateTime.parse(date);
    } catch (e) {
      return null;
    }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please choose a date")));

      return;
    }

    if (selectedTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please choose a time")));

      return;
    }
    final alreadyExists = deadlines.any((deadline) {
      return deadline["date"] ==
              "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}" &&
          deadline["time"] == selectedTime!.format(context);
    });

    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Another deadline already exists at this time"),
        ),
      );

      return;
    }

    setState(() {
      deadlines.add({
        "title": titleController.text,

        "date":
            "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",

        "time": selectedTime!.format(context),

        "type": selectedDeadlineType,

        "course": selectedCourse == "None" ? "" : selectedCourse,

        "estimatedHours": estimatedHoursController.text,
        "estimatedHours": estimatedHoursController.text,
      });
      sortDeadlines();
    });
    await StorageService.saveDeadlines(deadlines);

    titleController.clear();
    estimatedHoursController.clear();

    selectedDate = null;
    selectedTime = null;

    Navigator.pop(context);
  }

  void showAddDialog() {
    showDialog(
      context: context,

      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add Deadline"),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    TextField(
                      controller: titleController,

                      decoration: const InputDecoration(
                        hintText: "Assignment / Exam...",
                      ),
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
                            selectedDate = picked;
                          });
                        }
                      },

                      child: Text(
                        selectedDate == null
                            ? "Pick Date"
                            : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
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
                            selectedTime = picked;
                          });
                        }
                      },

                      child: Text(
                        selectedTime == null
                            ? "Pick Time"
                            : selectedTime!.format(context),
                      ),
                    ),

                    TextField(
                      controller: estimatedHoursController,

                      keyboardType: TextInputType.number,

                      decoration: const InputDecoration(
                        labelText: "Estimated Study Hours",
                      ),
                    ),

                    const SizedBox(height: 20),

                    DropdownButton<String>(
                      value: selectedCourse,

                      isExpanded: true,

                      items: availableCourses.map((course) {
                        return DropdownMenuItem(
                          value: course,

                          child: Text(course),
                        );
                      }).toList(),

                      onChanged: (value) {
                        setDialogState(() {
                          selectedCourse = value!;
                        });
                      },
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

  Color getPriorityColor(String priority) {
    switch (priority) {
      case "High":
        return Colors.red;

      case "Medium":
        return Colors.orange;

      default:
        return Colors.green;
    }
  }

  Color getDeadlineTypeColor(String type) {
    switch (type) {
      case "Exam":
        return Colors.red;

      case "Quiz":
        return Colors.blue;

      case "Homework":
        return Colors.orange;

      default:
        return Colors.deepPurple;
    }
  }

  IconData getDeadlineIcon(String type) {
    switch (type) {
      case "Exam":
        return Icons.school;

      case "Quiz":
        return Icons.quiz;

      case "Homework":
        return Icons.assignment;

      default:
        return Icons.event_note;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Deadlines"),

        actions: [
          DropdownButton<String>(
            value: sortOption,

            underline: const SizedBox(),

            items: const [
              DropdownMenuItem(value: "Date", child: Text("Sort by Date")),

              DropdownMenuItem(value: "Course", child: Text("Sort by Course")),
            ],

            onChanged: (value) {
              setState(() {
                sortOption = value!;

                sortDeadlines();
              });
            },
          ),

          const SizedBox(width: 12),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          clearDeadlineState();

          showAddDialog();
        },

        child: const Icon(Icons.add),
      ),

      body: ListView.builder(
        padding: const EdgeInsets.all(20),

        itemCount: deadlines.length,

        itemBuilder: (context, index) {
          final item = deadlines[index];

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,

                MaterialPageRoute(
                  builder: (context) => DeadlineDetailsScreen(
                    deadline: item,

                    deadlineIndex: index,
                  ),
                ),
              );
            },

            child: Container(
              margin: const EdgeInsets.only(bottom: 16),

              padding: const EdgeInsets.all(20),

              decoration: BoxDecoration(
                color: getDeadlineTypeColor(
                  item["type"] ?? "",
                ).withOpacity(0.12),

                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: getDeadlineTypeColor(
                    item["type"] ?? "",
                  ).withOpacity(0.35),
                ),
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    item["title"]!,

                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(item["date"]!),
                  if (item["course"] != null)
                    Text(
                      item["course"],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: getDeadlineTypeColor(item["type"] ?? ""),
                      ),
                    ),

                  if (item["time"] != null) Text(item["time"]),
                  if (item["estimatedHours"] != null &&
                      item["estimatedHours"].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),

                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 18,
                            color: Colors.grey,
                          ),

                          const SizedBox(width: 6),

                          Text("${item["estimatedHours"]}h preparation"),
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),

                    decoration: BoxDecoration(
                      color: getDeadlineTypeColor(
                        item["type"] ?? "",
                      ).withOpacity(0.15),

                      borderRadius: BorderRadius.circular(20),
                    ),

                    child: Row(
                      mainAxisSize: MainAxisSize.min,

                      children: [
                        Icon(
                          getDeadlineIcon(item["type"] ?? ""),

                          size: 18,

                          color: getDeadlineTypeColor(item["type"] ?? ""),
                        ),

                        const SizedBox(width: 6),

                        Text(
                          item["type"] ?? item["type"] ?? "",

                          style: TextStyle(
                            color: getDeadlineTypeColor(item["type"] ?? ""),

                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerRight,

                    child: Row(
                      mainAxisSize: MainAxisSize.min,

                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),

                          onPressed: () {
                            showEditDeadlineDialog(item, index);
                          },
                        ),

                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),

                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,

                              builder: (context) {
                                return AlertDialog(
                                  title: const Text("Delete Deadline"),

                                  content: Text("Delete ${item["title"]}?"),

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
                              deadlines.removeAt(index);
                            });

                            await StorageService.saveDeadlines(deadlines);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void showEditDeadlineDialog(Map<String, dynamic> item, int index) {
    isEditing = true;
    editingIndex = index;

    titleController.text = item["title"] ?? "";
    selectedDate = DateTime.parse(item["date"]);

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
              title: const Text("Edit Deadline"),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    TextField(
                      controller: titleController,

                      decoration: const InputDecoration(
                        hintText: "Deadline Title",
                      ),
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,

                          initialDate: selectedDate ?? DateTime.now(),

                          firstDate: DateTime.now(),

                          lastDate: DateTime(2030),
                        );

                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },

                      child: Text(
                        selectedDate == null
                            ? "Pick Date"
                            : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
                      ),
                    ),
                    const SizedBox(height: 10),

                    ElevatedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,

                          initialTime: selectedTime ?? TimeOfDay.now(),
                        );

                        if (picked != null) {
                          setDialogState(() {
                            selectedTime = picked;
                          });
                        }
                      },

                      child: Text(
                        selectedTime == null
                            ? "Pick Time"
                            : selectedTime!.format(context),
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      controller: estimatedHoursController,

                      keyboardType: TextInputType.number,

                      decoration: const InputDecoration(
                        labelText: "Estimated Study Hours",
                      ),
                    ),

                    DropdownButton<String>(
                      value: selectedCourse,

                      isExpanded: true,

                      items: availableCourses.map((course) {
                        return DropdownMenuItem(
                          value: course,

                          child: Text(course),
                        );
                      }).toList(),

                      onChanged: (value) {
                        setDialogState(() {
                          selectedCourse = value!;
                        });
                      },
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
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    clearDeadlineState();

                    Navigator.pop(context);
                  },

                  child: const Text("Cancel"),
                ),

                ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      deadlines[index]["title"] = titleController.text;
                      deadlines[index]["date"] =
                          "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}";

                      deadlines[index]["time"] = selectedTime!.format(context);

                      deadlines[index]["type"] = selectedDeadlineType;

                      deadlines[index]["course"] = selectedCourse == "None"
                          ? ""
                          : selectedCourse;

                      deadlines[index]["estimatedHours"] =
                          estimatedHoursController.text;
                      deadlines[index]["estimatedHours"] =
                          estimatedHoursController.text;
                      sortDeadlines();
                    });

                    await StorageService.saveDeadlines(deadlines);

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
