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
    if (!mounted) return;
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

    if (!mounted) return;
    setState(() {
      availableCourses = ["None", ...courses];
    });
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
                        filled: true, fillColor: Colors.grey.shade50,
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
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selectedDate != null ? Colors.deepPurple.shade200 : Colors.grey.shade200)),
                        child: Row(children: [
                          Icon(Icons.event_rounded, size: 18, color: selectedDate != null ? Colors.deepPurple : Colors.grey),
                          const SizedBox(width: 10),
                          Text(
                            selectedDate != null
                                ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}${selectedTime != null ? '  ${selectedTime!.format(context)}' : ''}"
                                : "Set due date & time...",
                            style: TextStyle(fontWeight: FontWeight.w600, color: selectedDate != null ? Colors.black87 : Colors.grey),
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
                        filled: true, fillColor: Colors.grey.shade50,
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
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
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
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
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
        heroTag: "deadlines_fab",
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
                color: getDeadlineTypeColor(item["type"] ?? "").withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: getDeadlineTypeColor(item["type"] ?? "").withOpacity(0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item["title"] ?? "",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(item["date"] ?? ""),
                  if (item["course"] != null && item["course"].toString().isNotEmpty)
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
                          const Icon(Icons.access_time, size: 18, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text("${item["estimatedHours"]}h preparation"),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: getDeadlineTypeColor(item["type"] ?? "").withOpacity(0.15),
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
                          item["type"] ?? "",
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
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text("Cancel"),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      child: const Text("Delete"),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirm != true) return;

                            // Delete from Firestore using document ID
                            final docId = item['id'];
                            if (docId != null) {
                              await StorageService.deleteDeadline(docId);
                            }

                            if (!mounted) return;
                            setState(() {
                              deadlines.removeAt(index);
                            });
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
                        filled: true, fillColor: Colors.grey.shade50,
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
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selectedDate != null ? Colors.deepPurple.shade200 : Colors.grey.shade200)),
                        child: Row(children: [
                          Icon(Icons.event_rounded, size: 18, color: selectedDate != null ? Colors.deepPurple : Colors.grey),
                          const SizedBox(width: 10),
                          Text(
                            selectedDate != null
                                ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}${selectedTime != null ? '  ${selectedTime!.format(context)}' : ''}"
                                : "Set due date & time...",
                            style: TextStyle(fontWeight: FontWeight.w600, color: selectedDate != null ? Colors.black87 : Colors.grey),
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
                        filled: true, fillColor: Colors.grey.shade50,
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
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
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
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
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
                    setState(() { deadlines[index] = updatedData; sortDeadlines(); });
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
