import 'package:flutter/material.dart';

import '../services/storage_service.dart';

class DeadlineDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> deadline;

  final int deadlineIndex;

  const DeadlineDetailsScreen({
    super.key,

    required this.deadline,

    required this.deadlineIndex,
  });

  @override
  State<DeadlineDetailsScreen> createState() => _DeadlineDetailsScreenState();
}

class _DeadlineDetailsScreenState extends State<DeadlineDetailsScreen> {
  final subtaskController = TextEditingController();

  List<dynamic> subtasks = [];

  @override
  void initState() {
    super.initState();

    loadSubtasks();
  }

  Future<void> loadSubtasks() async {
    final deadlines = await StorageService.loadDeadlines();

    final updatedDeadline = deadlines[widget.deadlineIndex];

    setState(() {
      subtasks = updatedDeadline["subtasks"] ?? [];
    });
  }

  Future<void> saveSubtasks() async {
    final deadlines = await StorageService.loadDeadlines();

    deadlines[widget.deadlineIndex]["subtasks"] = subtasks;

    await StorageService.saveDeadlines(deadlines);
  }

  Future<void> addSubtask() async {
    if (subtaskController.text.trim().isEmpty) {
      return;
    }

    setState(() {
      subtasks.add({"title": subtaskController.text, "done": false});
    });

    subtaskController.clear();

    await saveSubtasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deadline["title"]),

        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services),

            onPressed: () async {
              setState(() {
                subtasks.removeWhere((task) => task["done"] == true);
              });

              await saveSubtasks();
            },
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,

            builder: (context) {
              return AlertDialog(
                title: const Text("Add Subtask"),

                content: TextField(
                  controller: subtaskController,

                  decoration: const InputDecoration(
                    hintText: "Study chapter 5...",
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
                      await addSubtask();

                      Navigator.pop(context);
                    },

                    child: const Text("Add"),
                  ),
                ],
              );
            },
          );
        },

        child: const Icon(Icons.add),
      ),

      body: subtasks.isEmpty
          ? const Center(child: Text("No subtasks yet"))
          : ListView.builder(
              padding: const EdgeInsets.all(20),

              itemCount: subtasks.length,

              itemBuilder: (context, index) {
                final subtask = subtasks[index];

                return Dismissible(
                  key: ValueKey(subtask["title"]),
                  direction: DismissDirection.endToStart,

                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),

                  onDismissed: (direction) async {
                    setState(() {
                      subtasks.removeAt(index);
                    });

                    await saveSubtasks();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Subtask deleted')),
                    );
                  },

                  child: Card(
                    margin: const EdgeInsets.only(bottom: 10),

                    child: ListTile(
                      leading: Checkbox(
                        value: subtask["done"],
                        onChanged: (value) async {
                          setState(() {
                            subtasks[index]["done"] = value;
                          });

                          await saveSubtasks();
                        },
                      ),

                      title: Text(subtask["title"]),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
