import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  // API key loaded from .env file
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  /// Generate study subtasks from a complex goal/exam description
  /// Returns a list of 3-5 actionable study tasks
  static Future<List<String>> generateStudyPlan(String goal) async {
    if (_apiKey.isEmpty) {
      debugPrint('Gemini API key not configured in .env file');
      return _getFallbackTasks(goal);
    }

    final prompt = '''
You are a study planning assistant. A student needs to prepare for the following academic goal:

"$goal"

Break this down into exactly 3-5 specific, actionable micro-tasks that the student can complete one at a time. Each task should be:
- Concrete and clear (not vague)
- Completable in 30-90 minutes
- Ordered logically (foundations first, then advanced)

Respond ONLY with a JSON array of strings. No explanation, no markdown, just the JSON array.
Example format: ["Task 1", "Task 2", "Task 3"]
''';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 500,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';

        // Parse the JSON array from the response
        return _parseTaskList(text);
      } else {
        debugPrint('Gemini API error: ${response.statusCode} - ${response.body}');
        return _getFallbackTasks(goal);
      }
    } catch (e) {
      debugPrint('Gemini API exception: $e');
      return _getFallbackTasks(goal);
    }
  }

  /// Parse the AI response into a clean list of tasks
  static List<String> _parseTaskList(String text) {
    // Try to find JSON array in the response
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

    return ['Review key concepts', 'Practice problems', 'Summarize notes'];
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
