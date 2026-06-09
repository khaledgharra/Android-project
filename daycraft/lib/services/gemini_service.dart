import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_keys.dart';

class GeminiService {
  // Using OpenRouter API with free AI models
  static String get _apiKey => openRouterApiKey;
  static String? _lastError;

  /// Get the last error message (if any)
  static String? get lastError => _lastError;

  static const String _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  // Free models to try in order of preference (fast & reliable)
  static const List<String> _freeModels = [
    'poolside/laguna-xs.2:free',
    'google/gemma-4-26b-a4b-it:free',
    'nvidia/nemotron-3-super-120b-a12b:free',
  ];

  /// Generate study subtasks from a complex goal/exam description
  /// Returns a list of 3-5 actionable study tasks
  static Future<List<String>> generateStudyPlan(String goal) async {
    _lastError = null;

    if (_apiKey.isEmpty) {
      debugPrint('OpenRouter API key not configured');
      _lastError = 'API key not configured';
      return _getFallbackTasks(goal);
    }

    final prompt = '''You are a study planning assistant. A student needs to prepare for the following academic goal:

"$goal"

Break this down into exactly 3-5 specific, actionable micro-tasks that the student can complete one at a time. Each task should be:
- Concrete and clear (not vague)
- Completable in 30-90 minutes
- Ordered logically (foundations first, then advanced)

Respond ONLY with a JSON array of strings. No explanation, no markdown, just the JSON array.
Example format: ["Task 1", "Task 2", "Task 3"]''';

    // Try each free model until one works
    for (final model in _freeModels) {
      try {
        final response = await http.post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'user', 'content': prompt}
            ],
            'temperature': 0.7,
            'max_tokens': 500,
          }),
        ).timeout(const Duration(seconds: 25));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = data['choices']?[0]?['message']?['content'] ?? '';
          if (text.isNotEmpty) {
            final tasks = _parseTaskList(text);
            if (tasks.isNotEmpty) {
              debugPrint('AI response from model: $model');
              return tasks;
            }
          }
        } else if (response.statusCode == 429) {
          debugPrint('Model $model rate limited, trying next...');
          continue;
        } else {
          debugPrint('Model $model error: ${response.statusCode}');
          continue;
        }
      } catch (e) {
        debugPrint('Model $model exception: $e');
        continue;
      }
    }

    // All models failed
    _lastError = 'All AI models temporarily unavailable. Please try again in a moment.';
    return _getFallbackTasks(goal);
  }

  /// Parse the AI response into a clean list of tasks
  static List<String> _parseTaskList(String text) {
    final cleanedText = text.trim();

    // Try direct JSON parse
    try {
      final List<dynamic> parsed = jsonDecode(cleanedText);
      return parsed.map((e) => e.toString()).toList();
    } catch (_) {}

    // Try to extract JSON array from surrounding text
    final jsonMatch = RegExp(r'\[.*?\]', dotAll: true).firstMatch(cleanedText);
    if (jsonMatch != null) {
      try {
        final List<dynamic> parsed = jsonDecode(jsonMatch.group(0)!);
        return parsed.map((e) => e.toString()).toList();
      } catch (_) {}
    }

    // Fallback: split by newlines and clean up
    final lines = cleanedText
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'^[\d\.\-\*]+\s*'), '').trim())
        .where((line) => line.isNotEmpty && line.length > 5)
        .toList();

    if (lines.isNotEmpty) return lines.take(5).toList();

    return [];
  }

  /// Fallback tasks when API is unavailable
  static List<String> _getFallbackTasks(String goal) {
    final lowerGoal = goal.toLowerCase();

    if (lowerGoal.contains('exam') || lowerGoal.contains('test')) {
      return [
        'Review lecture notes and highlight key topics',
        'Summarize each chapter into bullet points',
        'Solve 2-3 practice problems from past exams',
        'Create flashcards for important definitions',
        'Do a timed mock quiz to test yourself',
      ];
    } else if (lowerGoal.contains('assignment') || lowerGoal.contains('homework')) {
      return [
        'Read the assignment requirements carefully',
        'Break the problem into smaller sub-parts',
        'Research and gather needed references',
        'Write a first draft / initial solution',
        'Review and polish before submission',
      ];
    } else {
      return [
        'Identify the main topics to cover',
        'Review foundational concepts first',
        'Practice with examples or exercises',
        'Summarize what you\'ve learned',
        'Test yourself on the material',
      ];
    }
  }

  /// Check if the API key has been configured
  static bool get isConfigured => _apiKey.isNotEmpty;
}
