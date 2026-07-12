import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import '../widgets/ai_report_section.dart';

class AIAssistantScreen extends StatefulWidget {
  final String? deadlineId;
  final String? deadlineTitle;
  final String? courseName;

  const AIAssistantScreen({
    super.key,
    this.deadlineId,
    this.deadlineTitle,
    this.courseName,
  });

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final TextEditingController _goalController = TextEditingController();
  List<String> generatedTasks = [];
  Set<int> selectedIndices = {};
  bool isLoading = false;
  bool hasGenerated = false;
  String _lastPrompt = '';

  @override
  void initState() {
    super.initState();
    // Pre-fill with deadline info if available
    if (widget.deadlineTitle != null) {
      final course = widget.courseName ?? '';
      _goalController.text = course.isNotEmpty
          ? "Study for $course: ${widget.deadlineTitle}"
          : "Study for ${widget.deadlineTitle}";
    }
  }

  Future<void> _generatePlan() async {
    if (_goalController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please describe your study goal")),
      );
      return;
    }

    final promptText = _goalController.text.trim();
    setState(() {
      isLoading = true;
      hasGenerated = false;
      generatedTasks = [];
      selectedIndices = {};
      _lastPrompt = promptText;
    });

    final tasks = await GeminiService.generateStudyPlan(promptText);

    if (!mounted) return;
    setState(() {
      generatedTasks = tasks;
      selectedIndices = Set.from(
        List.generate(tasks.length, (i) => i),
      ); // Select all by default
      isLoading = false;
      hasGenerated = true;
    });

    // Show warning if API failed and fallback was used
    final error = GeminiService.lastError;
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "⚠️ AI unavailable: $error\nShowing suggested tasks instead.",
          ),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _saveToDeadline() async {
    if (widget.deadlineId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "No deadline linked. Tasks generated for reference only.",
          ),
        ),
      );
      Navigator.pop(context);
      return;
    }

    final selectedTasks = (selectedIndices.toList()..sort())
        .map((i) => generatedTasks[i])
        .toList();

    // Load current deadline data and add subtasks
    final deadlines = await StorageService.loadDeadlines();
    final deadlineIndex = deadlines.indexWhere(
      (d) => d['id'] == widget.deadlineId,
    );

    if (deadlineIndex >= 0) {
      final deadline = deadlines[deadlineIndex];
      final existingSubtasks = List<Map<String, dynamic>>.from(
        deadline['subtasks'] ?? [],
      );

      for (var i in selectedIndices.toList()..sort()) {
        existingSubtasks.add({"title": generatedTasks[i], "done": false});
      }

      await StorageService.updateDeadline(widget.deadlineId!, {
        'subtasks': existingSubtasks,
      });
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("✅ ${selectedIndices.length} tasks saved to deadline!"),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🧠 AI Study Assistant"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                "Break down your goal",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Describe what you need to study and AI will create an actionable checklist.",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 20),

              // Input field
              TextField(
                controller: _goalController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "e.g., Study for Introduction to Networks Exam...",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Colors.deepPurple,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Generate button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _generatePlan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          "✨ Generate Study Plan",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Loading animation
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.deepPurple,
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          "AI is thinking...",
                          style: TextStyle(
                            color: Colors.deepPurple,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Breaking down your goal into manageable tasks",
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),

              // Generated tasks checklist
              if (hasGenerated && !isLoading) ...[
                Row(
                  children: [
                    const Text(
                      "Generated Tasks",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (selectedIndices.length == generatedTasks.length) {
                            selectedIndices.clear();
                          } else {
                            selectedIndices = Set.from(
                              List.generate(generatedTasks.length, (i) => i),
                            );
                          }
                        });
                      },
                      child: Text(
                        selectedIndices.length == generatedTasks.length
                            ? "Deselect All"
                            : "Select All",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: generatedTasks.length,
                  itemBuilder: (context, index) {
                    final isSelected = selectedIndices.contains(index);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.deepPurple.withValues(alpha: 0.06)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? Colors.deepPurple.withValues(alpha: 0.3)
                              : Colors.grey.shade200,
                          width: 1.5,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              selectedIndices.remove(index);
                            } else {
                              selectedIndices.add(index);
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.deepPurple
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.deepPurple
                                        : Colors.grey.shade400,
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  generatedTasks[index],
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? Colors.black87
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                AIReportSection(
                  feature: 'study_assistant',
                  generatedContent: generatedTasks.join('\n'),
                  userPrompt: _lastPrompt,
                ),
                const SizedBox(height: 16),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: selectedIndices.isEmpty ? null : _saveToDeadline,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      widget.deadlineId != null
                          ? "💾 Save ${selectedIndices.length} Tasks to Deadline"
                          : "✅ Done",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }
}
