import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class DeadlinesScreen extends StatefulWidget {
  const DeadlinesScreen({super.key});

  @override
  State<DeadlinesScreen> createState() => _DeadlinesScreenState();
}

class _DeadlinesScreenState extends State<DeadlinesScreen> {
  List<Map<String, String>> deadlines = [];
  @override
  void initState() {
    super.initState();

    loadDeadlines();
  }

  Future<void> loadDeadlines() async {
    final loaded = await StorageService.loadDeadlines();

    setState(() {
      deadlines = loaded;
    });
  }

  final titleController = TextEditingController();

  DateTime? selectedDate;

  TimeOfDay? selectedTime;

  String priority = "Medium";

  Future<void> addDeadline() async {
    if (titleController.text.isEmpty ||
        selectedDate == null ||
        selectedTime == null) {
      return;
    }

    setState(() {
      deadlines.add({
        "title": titleController.text,

        "date":
            "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",

        "time": selectedTime!.format(context),

        "priority": priority,
      });
    });
    await StorageService.saveDeadlines(deadlines);

    titleController.clear();

    selectedDate = null;
    selectedTime = null;
    priority = "Medium";

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

                    const SizedBox(height: 20),

                    DropdownButton<String>(
                      value: priority,

                      items: const [
                        DropdownMenuItem(value: "High", child: Text("High")),

                        DropdownMenuItem(
                          value: "Medium",
                          child: Text("Medium"),
                        ),

                        DropdownMenuItem(value: "Low", child: Text("Low")),
                      ],

                      onChanged: (value) {
                        setDialogState(() {
                          priority = value!;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Deadlines")),

      floatingActionButton: FloatingActionButton(
        onPressed: showAddDialog,

        child: const Icon(Icons.add),
      ),

      body: ListView.builder(
        padding: const EdgeInsets.all(20),

        itemCount: deadlines.length,

        itemBuilder: (context, index) {
          final item = deadlines[index];

          return Container(
            margin: const EdgeInsets.only(bottom: 16),

            padding: const EdgeInsets.all(20),

            decoration: BoxDecoration(
              color: getPriorityColor(item["priority"]!).withValues(alpha: 0.15),

              borderRadius: BorderRadius.circular(20),
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

                Text(item["time"]!),

                const SizedBox(height: 8),

                Text(
                  item["priority"]!,
                  style: TextStyle(
                    color: getPriorityColor(item["priority"]!),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
