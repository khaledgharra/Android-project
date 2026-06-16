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
    'meta-llama/llama-3.1-8b-instruct:free',
    'mistralai/mistral-7b-instruct:free',
    'google/gemma-2-9b-it:free',
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
    String? lastApiError;
    for (final model in _freeModels) {
      try {
        final response = await http.post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
            'HTTP-Referer': 'https://daycraft.app',
            'X-Title': 'DayCraft',
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

        debugPrint('AI [$model] status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = data['choices']?[0]?['message']?['content'] ?? '';
          if (text.isNotEmpty) {
            final tasks = _parseTaskList(text);
            if (tasks.isNotEmpty) {
              debugPrint('AI response from model: $model');
              return tasks;
            }
            lastApiError = 'Unparseable response';
          }
        } else if (response.statusCode == 429) {
          lastApiError = 'Rate limited (429)';
          debugPrint('Model $model rate limited, trying next...');
          continue;
        } else if (response.statusCode == 401) {
          lastApiError = 'Invalid API key (401)';
          break;
        } else if (response.statusCode == 402) {
          lastApiError = 'Insufficient credits (402)';
          break;
        } else {
          lastApiError = 'HTTP ${response.statusCode}';
          debugPrint('Model $model error body: ${response.body}');
          continue;
        }
      } catch (e) {
        lastApiError = e.toString();
        debugPrint('Model $model exception: $e');
        continue;
      }
    }

    // All models failed
    _lastError = lastApiError ?? 'All AI models temporarily unavailable.';
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

  /// Parse a date string in "d/M/yyyy" or ISO "yyyy-MM-dd" format
  static DateTime? parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    try { return DateTime.parse(s); } catch (_) {}
    try {
      final parts = s.split('/');
      if (parts.length == 3) return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
    } catch (_) {}
    return null;
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Generate a multi-day study schedule across all deadlines.
  /// Returns sessions: [{deadlineTitle, sessionTitle, date, startTime, endTime}]
  static Future<List<Map<String, dynamic>>> generateSchedulePlan({
    required List<Map<String, dynamic>> deadlines,
    required List<Map<String, dynamic>> schedule,
    required DateTime today,
  }) async {
    _lastError = null;

    final todayStr = _fmtDate(today);

    // Format deadlines for the prompt
    final deadlineLines = deadlines.map((d) {
      final due = parseDate(d['date']?.toString());
      return '- "${d['title']}" (${d['type'] ?? 'Task'}, due ${due != null ? _fmtDate(due) : d['date']}, ${d['estimatedHours']}h needed, course: ${d['course'] ?? 'N/A'})';
    }).join('\n');

    // Format busy slots from existing schedule
    final busy = <String>[];
    for (final item in schedule) {
      if (item['type'] == 'Course') {
        final name = item['name']?.toString() ?? 'Class';
        final lec = item['lecture'] as Map?;
        if (lec != null && lec['day'] != null && lec['start'] != null)
          busy.add('${lec['day']}: ${lec['start']}-${lec['end']} ($name lecture)');
        final tut = item['tutorial'] as Map?;
        if (tut != null && tut['day'] != null && tut['start'] != null)
          busy.add('${tut['day']}: ${tut['start']}-${tut['end']} ($name tutorial)');
      } else if (item['day'] != null && item['start'] != null) {
        busy.add('${item['day']}: ${item['start']}-${item['end']} (${item['name'] ?? 'Task'})');
      }
    }

    final prompt = '''You are a student schedule optimizer.
Today: $todayStr

Upcoming deadlines that need study time:
$deadlineLines

Recurring busy times to avoid:
${busy.isEmpty ? 'None' : busy.join('\n')}

Generate a realistic study plan from today until each deadline.
Rules:
- Each session is 1.5 or 2 hours
- Max 2 study sessions per day total across all deadlines
- Prefer afternoons 14:00-20:00 or evenings 19:00-21:00
- Spread sessions evenly; do NOT cram everything the day before
- Use the estimated hours to decide how many sessions to create
- Prioritize deadlines that are sooner

Respond with ONLY a raw JSON array, nothing else before or after it:
[{"deadlineTitle":"exact title","sessionTitle":"brief task description","date":"YYYY-MM-DD","startTime":"HH:MM","endTime":"HH:MM"}]''';

    if (_apiKey.isNotEmpty) {
      String? lastApiError;
      for (final model in _freeModels) {
        try {
          final response = await http.post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
              'HTTP-Referer': 'https://daycraft.app',
              'X-Title': 'DayCraft',
            },
            body: jsonEncode({
              'model': model,
              'messages': [{'role': 'user', 'content': prompt}],
              'temperature': 0.4,
              'max_tokens': 2000,
            }),
          ).timeout(const Duration(seconds: 35));

          debugPrint('Schedule AI [$model] status: ${response.statusCode}');

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final text = data['choices']?[0]?['message']?['content'] ?? '';
            if (text.isNotEmpty) {
              final sessions = _parseSessionList(text);
              if (sessions.isNotEmpty) {
                debugPrint('Schedule AI success with model: $model');
                return sessions;
              }
              lastApiError = 'Model returned unparseable response';
            }
          } else if (response.statusCode == 429) {
            lastApiError = 'Rate limited (429)';
            continue;
          } else if (response.statusCode == 401) {
            lastApiError = 'Invalid API key (401)';
            break; // No point retrying with same key
          } else if (response.statusCode == 402) {
            lastApiError = 'Insufficient credits (402)';
            break;
          } else {
            lastApiError = 'HTTP ${response.statusCode}';
            debugPrint('Schedule AI [$model] error body: ${response.body}');
            continue;
          }
        } catch (e) {
          lastApiError = e.toString();
          debugPrint('Schedule AI error ($model): $e');
          continue;
        }
      }
      _lastError = lastApiError ?? 'AI temporarily unavailable';
    }

    return _getFallbackSchedulePlan(deadlines, today);
  }

  static List<Map<String, dynamic>> _parseSessionList(String text) {
    try {
      final match = RegExp(r'\[.*\]', dotAll: true).firstMatch(text.trim());
      if (match != null) {
        final parsed = jsonDecode(match.group(0)!) as List;
        return parsed.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  static List<Map<String, dynamic>> _getFallbackSchedulePlan(
    List<Map<String, dynamic>> deadlines,
    DateTime today,
  ) {
    final sessions = <Map<String, dynamic>>[];
    // Track slot count per date so sessions on the same day get staggered times
    final slotsPerDate = <String, int>{};

    for (final d in deadlines) {
      final due = parseDate(d['date']?.toString());
      if (due == null) continue;
      final hours = double.tryParse(d['estimatedHours']?.toString() ?? '2') ?? 2;
      final sessionsNeeded = (hours / 2).ceil().clamp(1, 10);
      final daysAvail = due.difference(today).inDays;
      if (daysAvail <= 0) continue;

      for (int i = 0; i < sessionsNeeded; i++) {
        final offset = ((daysAvail * i) / sessionsNeeded).floor().clamp(0, daysAvail - 1);
        final sessionDate = today.add(Duration(days: offset));
        final dateStr = _fmtDate(sessionDate);
        final slot = slotsPerDate[dateStr] ?? 0;
        slotsPerDate[dateStr] = slot + 1;
        // Alternate morning / afternoon / evening slots
        final startH = [9, 14, 19][slot % 3];
        final endH = startH + 2;
        sessions.add({
          'deadlineTitle': d['title'],
          'sessionTitle': 'Study for ${d['title']}',
          'date': dateStr,
          'startTime': '$startH:00',
          'endTime': '$endH:00',
        });
      }
    }
    return sessions;
  }

  /// Check if the API key has been configured
  static bool get isConfigured => _apiKey.isNotEmpty;
}
