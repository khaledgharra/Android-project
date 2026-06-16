import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'ai_assistant_screen.dart';

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
  final _hoursController = TextEditingController();
  List<dynamic> subtasks = [];
  bool _savingHours = false;

  @override
  void initState() {
    super.initState();
    _hoursController.text = widget.deadline['estimatedHours']?.toString() ?? '';
    loadSubtasks();
  }

  @override
  void dispose() {
    subtaskController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> loadSubtasks() async {
    final deadlines = await StorageService.loadDeadlines();
    if (!mounted) return;

    Map<String, dynamic>? updatedDeadline;
    final docId = widget.deadline['id'];
    if (docId != null) {
      updatedDeadline = deadlines.firstWhere(
        (d) => d['id'] == docId,
        orElse: () => deadlines.isNotEmpty && widget.deadlineIndex < deadlines.length
            ? deadlines[widget.deadlineIndex]
            : {},
      );
    } else if (widget.deadlineIndex < deadlines.length) {
      updatedDeadline = deadlines[widget.deadlineIndex];
    }

    setState(() {
      subtasks = updatedDeadline?["subtasks"] ?? [];
      // Sync hours if not yet set locally
      final remoteHours = updatedDeadline?['estimatedHours']?.toString() ?? '';
      if (_hoursController.text.isEmpty && remoteHours.isNotEmpty) {
        _hoursController.text = remoteHours;
      }
    });
  }

  Future<void> _saveHours() async {
    final docId = widget.deadline['id'];
    if (docId == null) return;
    final val = _hoursController.text.trim();
    setState(() => _savingHours = true);
    await StorageService.updateDeadline(docId, {
      ...widget.deadline,
      'estimatedHours': val,
      'subtasks': subtasks,
    });
    if (!mounted) return;
    setState(() => _savingHours = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Estimated hours saved'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> saveSubtasks() async {
    final docId = widget.deadline['id'];
    if (docId != null) {
      await StorageService.updateDeadline(docId, {
        ...widget.deadline,
        "subtasks": subtasks,
      });
    } else {
      final deadlines = await StorageService.loadDeadlines();
      if (widget.deadlineIndex < deadlines.length) {
        deadlines[widget.deadlineIndex]["subtasks"] = subtasks;
        await StorageService.saveDeadlines(deadlines);
      }
    }
  }

  Future<void> addSubtask() async {
    if (subtaskController.text.trim().isEmpty) return;
    setState(() {
      subtasks.add({"title": subtaskController.text, "done": false});
    });
    subtaskController.clear();
    await saveSubtasks();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final type = widget.deadline['type'] ?? 'Homework';
    final course = widget.deadline['course'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deadline["title"] ?? "Deadline"),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Colors.deepPurple),
            tooltip: "AI Generate Tasks",
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AIAssistantScreen(
                    deadlineId: widget.deadline['id'],
                    deadlineTitle: widget.deadline['title'],
                    courseName: widget.deadline['course'],
                  ),
                ),
              );
              if (result == true) await loadSubtasks();
            },
          ),
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            tooltip: "Clear completed",
            onPressed: () async {
              setState(() => subtasks.removeWhere((t) => t["done"] == true));
              await saveSubtasks();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "deadline_details_fab",
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Add Subtask"),
              content: TextField(
                controller: subtaskController,
                autofocus: true,
                decoration: const InputDecoration(hintText: "Study chapter 5..."),
                onSubmitted: (_) async { await addSubtask(); Navigator.pop(context); },
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () async { await addSubtask(); Navigator.pop(context); },
                  child: const Text("Add"),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // ── Info + Estimated Hours card ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  if (type.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _typeColor(type).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(type, style: TextStyle(color: _typeColor(type), fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  if (course.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                      child: Text(course, style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                  ],
                  const Spacer(),
                  Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(widget.deadline['date'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ]),
                const SizedBox(height: 16),
                const Text('Estimated Study Hours',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _hoursController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: 'e.g. 4',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        filled: true,
                        fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        suffixText: 'hours',
                        suffixStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      ),
                      onSubmitted: (_) => _saveHours(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _savingHours ? null : _saveHours,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _savingHours
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                ]),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Subtasks header ──
          Row(children: [
            const Text('Subtasks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (subtasks.isNotEmpty)
              Text('${subtasks.where((t) => t["done"] == true).length}/${subtasks.length} done',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ]),

          const SizedBox(height: 10),

          if (subtasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(children: [
                  Icon(Icons.checklist_rounded, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('No subtasks yet', style: TextStyle(color: Colors.grey.shade400)),
                  const SizedBox(height: 4),
                  Text('Tap + or use AI to generate tasks', style: TextStyle(fontSize: 12, color: Colors.grey.shade300)),
                ]),
              ),
            )
          else
            ...List.generate(subtasks.length, (index) {
              final subtask = subtasks[index];
              return Dismissible(
                key: ValueKey("${subtask['title']}_$index"),
                direction: DismissDirection.endToStart,
                background: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.delete_rounded, color: Colors.white),
                ),
                onDismissed: (_) async {
                  setState(() => subtasks.removeAt(index));
                  await saveSubtasks();
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: Checkbox(
                      value: subtask["done"] ?? false,
                      activeColor: Colors.deepPurple,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      onChanged: (value) async {
                        setState(() => subtasks[index]["done"] = value);
                        await saveSubtasks();
                      },
                    ),
                    title: Text(
                      subtask["title"] ?? "",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        decoration: subtask["done"] == true ? TextDecoration.lineThrough : null,
                        color: subtask["done"] == true ? Colors.grey.shade400 : null,
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'Exam': return Colors.red;
      case 'Homework': return Colors.orange;
      default: return Colors.deepPurple;
    }
  }
}
