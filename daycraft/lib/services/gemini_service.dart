import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_keys.dart';

class GeminiService {
  // Use direct Google AI Studio API key tracking
  static String get _apiKey => ApiKeys.googleGeminiKey;
  static String? _lastError;

  /// Get the last error message (if any)
  static String? get lastError => _lastError;

  // Direct stable connection to Google's official Developer Endpoint
// Update the end of the URL string from gemini-2.5-flash to gemini-3.5-flash
  static const String _googleUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent';

  /// Generate study subtasks from a complex goal/exam description
  /// Returns a list of 3-5 actionable study tasks
  static Future<List<String>> generateStudyPlan(String goal) async {
    _lastError = null;

    if (_apiKey.isEmpty) {
      debugPrint('Google AI Studio API key not configured');
      _lastError = 'API key not configured';
      return _getFallbackTasks(goal);
    }

    final prompt =
        '''You are a study planning assistant. A student needs to prepare for the following academic goal:

"$goal"

Break this down into exactly 3-5 specific, actionable micro-tasks that the student can complete one at a time. Each task should be:
- Concrete and clear (not vague)
- Completable in 30-90 minutes
- Ordered logically (foundations first, then advanced)

Respond ONLY with a JSON array of strings. No explanation, no markdown, just the JSON array.
Example format: ["Task 1", "Task 2", "Task 3"]''';

    try {
      final response = await http
          .post(
            Uri.parse(_googleUrl),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': _apiKey, // Native header authentication parameter
            },
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
                'responseMimeType': 'application/json', // Native JSON restriction enforcement
              }
            }),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('AI Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates[0]['content']?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final String text = parts[0]['text'] ?? '';
            if (text.isNotEmpty) {
              final tasks = _parseTaskList(text);
              if (tasks.isNotEmpty) {
                return tasks;
              }
            }
          }
        }
        _lastError = 'Unparseable native response';
      } else if (response.statusCode == 429) {
        _lastError = 'Rate limited (429)';
      } else if (response.statusCode == 400) {
        _lastError = 'Bad request or invalid configuration (400)';
      } else {
        _lastError = 'HTTP ${response.statusCode}';
        debugPrint('Google API error body: ${response.body}');
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Google Native Exception: $e');
    }

    return _getFallbackTasks(goal);
  }

  /// Parse the AI response into a clean list of tasks
  static List<String> _parseTaskList(String text) {
    final cleanedText = text.trim();

    try {
      final List<dynamic> parsed = jsonDecode(cleanedText);
      return parsed.map((e) => e.toString()).toList();
    } catch (_) {}

    final jsonMatch = RegExp(r'\[.*?\]', dotAll: true).firstMatch(cleanedText);
    if (jsonMatch != null) {
      try {
        final List<dynamic> parsed = jsonDecode(jsonMatch.group(0)!);
        return parsed.map((e) => e.toString()).toList();
      } catch (_) {}
    }

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
    } else if (lowerGoal.contains('assignment') ||
        lowerGoal.contains('homework')) {
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
    try {
      return DateTime.parse(s);
    } catch (_) {}
    try {
      final parts = s.split('/');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      }
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

    if (_apiKey.isEmpty) {
      debugPrint('Google AI Studio API key not configured');
      _lastError = 'API key not configured';
      return _getFallbackSchedulePlan(deadlines, today);
    }

    final todayStr = _fmtDate(today);

    final deadlineLines = deadlines
        .map((d) {
          final due = parseDate(d['date']?.toString());
          return '- "${d['title']}" (${d['type'] ?? 'Task'}, due ${due != null ? _fmtDate(due) : d['date']}, ${d['estimatedHours']}h needed, course: ${d['course'] ?? 'N/A'})';
        })
        .join('\n');

    final busy = <String>[];
    for (final item in schedule) {
      if (item['type'] == 'Course') {
        final name = item['name']?.toString() ?? 'Class';
        final lec = item['lecture'] as Map?;
        if (lec != null && lec['day'] != null && lec['start'] != null) {
          busy.add(
            '${lec['day']}: ${lec['start']}-${lec['end']} ($name lecture)',
          );
        }
        final tut = item['tutorial'] as Map?;
        if (tut != null && tut['day'] != null && tut['start'] != null) {
          busy.add(
            '${tut['day']}: ${tut['start']}-${tut['end']} ($name tutorial)',
          );
        }
      } else if (item['day'] != null && item['start'] != null) {
        busy.add(
          '${item['day']}: ${item['start']}-${item['end']} (${item['name'] ?? 'Task'})',
        );
      }
    }

    final prompt =
        '''You are a student schedule optimizer.
Today: $todayStr

Upcoming deadlines that need study time:
$deadlineLines

Recurring busy times to avoid:
${busy.isEmpty ? 'None' : busy.join('\n')}

Generate a realistic study plan from today until each deadline.
Rules:
- You MUST schedule study blocks for EVERY SINGLE checked deadline provided in the list. Do not drop or omit any deadlines.
- Check the 'estimatedHours' for each deadline and break it down into 1.5 or 2 hour individual sessions until that capacity is fully met.
- Each session is 1.5 or 2 hours.
- Max 2 study sessions per day total across all deadlines.
- DO NOT default all sessions to 09:00-11:00. Dynamically spread sessions throughout the day: prefer afternoons 14:00-20:00 or evenings 19:00-21:00, or weekends.
- Strictly cross-check the 'Recurring busy times to avoid' list. If a day and time slot matches an entry on that list, that time is completely blocked. You must pick an alternate open slot.
- Spread sessions evenly; do NOT cram everything the day before.
- Prioritize deadlines that are sooner.

Respond with a raw JSON object containing a "sessions" key with the array, nothing else before or after it:
{
  "sessions": [{"deadlineTitle":"exact title","sessionTitle":"brief task description","date":"YYYY-MM-DD","startTime":"HH:MM","endTime":"HH:MM"}]
}''';

    try {
      final response = await http
          .post(
            Uri.parse(_googleUrl),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': _apiKey,
            },
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0.1,
                'responseMimeType': 'application/json',
              }
            }),
          )
          .timeout(const Duration(seconds: 45));

      debugPrint('Schedule AI status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates[0]['content']?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final String text = parts[0]['text'] ?? '';
            debugPrint('🤖 RAW AI TEXT NATIVE GEMINI:\n$text');
            if (text.isNotEmpty) {
              final sessions = _parseSessionList(text);
              if (sessions.isNotEmpty) {
                return sessions;
              }
              _lastError = 'Model returned unparseable response schema';
            }
          }
        }
      } else if (response.statusCode == 429) {
        _lastError = 'Rate limited (429)';
      } else {
        _lastError = 'HTTP ${response.statusCode}';
        debugPrint('Schedule AI native error body: ${response.body}');
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('❌ Schedule AI Native Exception: $e');
    }

    debugPrint('⚠️ AI Generation failed completely. Reason: $_lastError. Dropping down to fallback schedule.');
    return _getFallbackSchedulePlan(deadlines, today);
  }

// Helper list to map index to weekday names matching your scheduler layout
  static const List<String> _weekdays = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  ];

  static List<Map<String, dynamic>> _parseSessionList(String text) {
    String cleanedText = text.trim();

    // Local helper to format the item keys to perfectly match your scheduler Map schema
    // while keeping the original keys so the UI preview screen doesn't break.
    Map<String, dynamic> formatToSchedulerSchema(Map<String, dynamic> rawSession) {
      final String deadlineName = rawSession['deadlineTitle'] ?? 'Study Session';
      final String sessionTitle = rawSession['sessionTitle'] ?? deadlineName;
      final String dateStr = rawSession['date'] ?? '';
      
      String dayName = 'Sunday'; 
      try {
        if (dateStr.isNotEmpty) {
          final parsedDate = DateTime.parse(dateStr);
          // DateTime.weekday returns 1 (Monday) to 7 (Sunday)
          dayName = _weekdays[parsedDate.weekday % 7];
        }
      } catch (_) {}

      return {
        // --- KEYS FOR THE UI PREVIEW SCREEN ---
        'deadlineTitle': deadlineName,
        'sessionTitle': deadlineName,
        'date': dateStr,
        'startTime': rawSession['startTime'],
        'endTime': rawSession['endTime'],

        // --- KEYS FOR THE DATABASE SCHEDULER ---
        'title': deadlineName,             
        'type': 'Task',                    
        'day': dayName,                    
        'start': rawSession['startTime'],   
        'end': rawSession['endTime'],       
        '_selectedRecurrence': 'Once',     
      };
    }

    // 1. Direct object parse attempt
    try {
      final parsedJson = jsonDecode(cleanedText);
      if (parsedJson is Map && parsedJson.containsKey('sessions')) {
        return List<Map<String, dynamic>>.from(parsedJson['sessions'])
            .map((session) => formatToSchedulerSchema(session))
            .toList();
      }
      if (parsedJson is List) {
        return parsedJson
            .map((e) => formatToSchedulerSchema(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}

    // 2. Regular Expression Extraction Fallback
    try {
      final match = RegExp(r'\[.*\]', dotAll: true).firstMatch(cleanedText);
      if (match != null) {
        final parsed = jsonDecode(match.group(0)!) as List;
        return parsed
            .map((e) => formatToSchedulerSchema(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}

    // 3. String Manipulation Fallback
    final List<Map<String, dynamic>> sessions = [];
    try {
      final lines = cleanedText.split('\n');
      String currentDeadline = "Study Session";

      for (var line in lines) {
        String trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        if (trimmed.endsWith(':')) {
          currentDeadline = trimmed.substring(0, trimmed.length - 1).trim();
          continue;
        }

        final inlineMatch = RegExp(r'[-*+•]\s*(\d{4}-\d{2}-\d{2})\s*(\d{2}:\d{2})-(\d{2}:\d{2})').firstMatch(trimmed);
        if (inlineMatch != null) {
          sessions.add(formatToSchedulerSchema({
            'deadlineTitle': currentDeadline,
            'date': inlineMatch.group(1),
            'startTime': inlineMatch.group(2),
            'endTime': inlineMatch.group(3),
          }));
        }
      }
    } catch (e) {
      debugPrint('❌ Custom text extraction failed: $e');
    }

    return sessions;
  }

  static List<Map<String, dynamic>> _getFallbackSchedulePlan(
    List<Map<String, dynamic>> deadlines,
    DateTime today,
  ) {
    final sessions = <Map<String, dynamic>>[];
    final slotsPerDate = <String, int>{};

    for (final d in deadlines) {
      final due = parseDate(d['date']?.toString());
      if (due == null) continue;
      final hours =
          double.tryParse(d['estimatedHours']?.toString() ?? '2') ?? 2;
      final sessionsNeeded = (hours / 2).ceil().clamp(1, 10);
      final daysAvail = due.difference(today).inDays;
      if (daysAvail <= 0) continue;

      for (int i = 0; i < sessionsNeeded; i++) {
        final offset = ((daysAvail * i) / sessionsNeeded).floor().clamp(
          0,
          daysAvail - 1,
        );
        final sessionDate = today.add(Duration(days: offset));
        final dateStr = _fmtDate(sessionDate);
        final slot = slotsPerDate[dateStr] ?? 0;
        slotsPerDate[dateStr] = slot + 1;
        
        final startH = [9, 14, 19][slot % 3];
        final endH = startH + 2;

        sessions.add({
          'title': d['title'],
          'type': 'Task',
          'day': _weekdays[sessionDate.weekday % 7],
          'start': '$startH:00',
          'end': '$endH:00',
          'date': dateStr,
          '_selectedRecurrence': 'Once', // FIXED: Capitalized here too
        });
      }
    }
    return sessions;
  }
  /// Check if the API key has been configured
  static bool get isConfigured => _apiKey.isNotEmpty;
}