import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';

class AISchedulePlannerScreen extends StatefulWidget {
  const AISchedulePlannerScreen({super.key});

  @override
  State<AISchedulePlannerScreen> createState() =>
      _AISchedulePlannerScreenState();
}

class _AISchedulePlannerScreenState extends State<AISchedulePlannerScreen> {
  bool _loadingData = true;
  bool _generating = false;
  bool _saving = false;
  bool _hasGenerated = false;

  List<Map<String, dynamic>> _deadlines = [];
  List<Map<String, dynamic>> _schedule = [];
  List<Map<String, dynamic>> _sessions = [];
  Set<int> _selected = {};

  // Track which deadlines the user wants the AI to schedule
  Set<String> _selectedDeadlineIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      StorageService.loadDeadlines(),
      StorageService.loadSchedule(),
    ]);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final all = results[0] as List<Map<String, dynamic>>;
    final filtered = all
        .where((d) {
          final date = GeminiService.parseDate(d['date']?.toString());
          return date != null && !date.isBefore(today);
        })
        .map((d) {
          final hours =
              double.tryParse(d['estimatedHours']?.toString() ?? '0') ?? 0;
          if (hours > 0) return d;
          final type = d['type']?.toString() ?? 'Homework';
          final defaultHours = type == 'Exam' ? 6.0 : 2.0;
          return Map<String, dynamic>.from(d)
            ..['estimatedHours'] = defaultHours;
        })
        .toList();

    filtered.sort((a, b) {
      final da = GeminiService.parseDate(a['date']?.toString());
      final db = GeminiService.parseDate(b['date']?.toString());
      if (da == null || db == null) return 0;
      return da.compareTo(db);
    });

    if (!mounted) return;
    setState(() {
      _deadlines = filtered;
      _schedule = results[1] as List<Map<String, dynamic>>;
      // Default select all deadlines initially
      _selectedDeadlineIds = Set.from(
        filtered.map((d) => d['id']?.toString() ?? d['title'] ?? ''),
      );
      _loadingData = false;
    });
  }

  (int, int) _parseTimeToHourMinute(String time) {
    final cleaned = time
        .trim()
        .toUpperCase()
        .replaceAll("AM", "")
        .replaceAll("PM", "")
        .trim();
    final parts = cleaned.split(":");
    int hour = int.parse(parts[0].trim());
    int minute = parts.length > 1 ? int.parse(parts[1].trim()) : 0;
    return (hour, minute);
  }

  bool _isOverlappingWithExistingSchedule(Map<String, dynamic> session) {
    final sessionDateStr = session['date']?.toString();
    final sessionStartStr = session['startTime']?.toString();
    final sessionEndStr = session['endTime']?.toString();
    if (sessionDateStr == null ||
        sessionStartStr == null ||
        sessionEndStr == null)
      return false;

    try {
      final sessionDate = DateTime.parse(sessionDateStr);
      const daysOfWeek = [
        "Sunday",
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
      ];
      final sessionDayName = daysOfWeek[sessionDate.weekday % 7];

      final (sh, sm) = _parseTimeToHourMinute(sessionStartStr);
      final (eh, em) = _parseTimeToHourMinute(sessionEndStr);
      final newStart = sh * 60 + sm;
      final newEnd = eh * 60 + em;

      for (final item in _schedule) {
        if (item["day"] != sessionDayName) continue;

        final itemDate = item["date"]?.toString();
        if (itemDate != null &&
            itemDate.isNotEmpty &&
            itemDate != sessionDateStr)
          continue;

        if (item["start"] == null || item["end"] == null) continue;
        final (exStartHour, exStartMin) = _parseTimeToHourMinute(item["start"]);
        final (exEndHour, exEndMin) = _parseTimeToHourMinute(item["end"]);
        final existingStart = exStartHour * 60 + exStartMin;
        final existingEnd = exEndHour * 60 + exEndMin;

        if (!(newEnd <= existingStart || newStart >= existingEnd)) {
          return true; // Overlap detected
        }
      }
    } catch (_) {}
    return false;
  }

  Future<void> _generate() async {
    if (_selectedDeadlineIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one deadline to plan.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _generating = true;
      _hasGenerated = false;
      _sessions = [];
      _selected = {};
    });

    final now = DateTime.now();

    // Only pass deadlines the user explicitly checked
    final chosenDeadlines = _deadlines.where((d) {
      final id = d['id']?.toString() ?? d['title'] ?? '';
      return _selectedDeadlineIds.contains(id);
    }).toList();

    final rawSessions = await GeminiService.generateSchedulePlan(
      deadlines: chosenDeadlines,
      schedule: _schedule,
      today:
          now, // Pass full continuous timestamp so AI knows current exact time
    );

    final List<Map<String, dynamic>> validatedSessions = [];
    int overlapCount = 0;
    int pastCount = 0;

    for (final s in rawSessions) {
      try {
        final dateStr = s['date']?.toString();
        final startStr = s['startTime']?.toString();
        if (dateStr == null || startStr == null) continue;

        final parsedDate = DateTime.parse(dateStr);
        final (hour, minute) = _parseTimeToHourMinute(startStr);
        final sessionStartTimestamp = DateTime(
          parsedDate.year,
          parsedDate.month,
          parsedDate.day,
          hour,
          minute,
        );

        if (sessionStartTimestamp.isBefore(now)) {
          pastCount++;
          continue;
        }

        if (_isOverlappingWithExistingSchedule(s)) {
          overlapCount++;
          // Instead of skipping entirely, we can mark it as conflicted so the user sees it
          final conflictedSession = Map<String, dynamic>.from(s)
            ..['isConflicted'] = true;
          validatedSessions.add(conflictedSession);
          continue;
        }

        validatedSessions.add(s);
      } catch (_) {
        validatedSessions.add(s);
      }
    }

    if (!mounted) return;

    // Alert the user if the AI forced an overlap or old time
    if (overlapCount > 0 || pastCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'AI suggested $overlapCount overlapping or $pastCount past sessions. Review flagged items.',
          ),
          backgroundColor: Colors.amber.shade900,
        ),
      );
    }

    if (!mounted) return;

    final error = GeminiService.lastError;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ $error'),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    setState(() {
      _sessions = validatedSessions;
      _selected = Set.from(List.generate(validatedSessions.length, (i) => i));
      _generating = false;
      _hasGenerated = true;
    });
  }

  Future<void> _addToCalendar() async {
    if (_selected.isEmpty) return;
    setState(() => _saving = true);

    final colorMap = <String, int>{};
    for (final d in _deadlines) {
      final title = d['title']?.toString();
      final c = d['courseColor'];
      if (title != null && c != null) {
        try {
          colorMap[title] = (c as num).toInt();
        } catch (_) {}
      }
    }

    final toAdd = _selected.toList()..sort();
    int count = 0;
    for (final i in toAdd) {
      final s = _sessions[i];
      final date = GeminiService.parseDate(s['date']?.toString());
      if (date == null) continue;

      final dayName = _dayName(date.weekday);
      final color = colorMap[s['deadlineTitle']] ?? Colors.deepPurple.value;

      await StorageService.addScheduleItem({
        'name': s['deadlineTitle'] ?? 'Study Session',
        'type': 'Study Session',
        'day': dayName,
        'date': s['date'], // Ensure this is standard YYYY-MM-DD
        'start': s['startTime'] ?? '14:00',
        'end': s['endTime'] ?? '16:00',
        'color': color,
        'aiGenerated': true,
        'repeat': 'once', // Force a single-instance flag for database clarity
      });
      count++;
    }

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✅ $count study session${count == 1 ? '' : 's'} added to your calendar!',
        ),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context, true);
  }

  String _dayName(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[(weekday - 1).clamp(0, 6)];
  }

  String _fmtDisplayDate(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final d = DateTime.parse(isoDate);
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
    } catch (_) {
      return isoDate;
    }
  }

  Map<String, List<_IndexedSession>> _grouped() {
    final map = <String, List<_IndexedSession>>{};
    for (int i = 0; i < _sessions.length; i++) {
      final date = _sessions[i]['date']?.toString() ?? '';
      map.putIfAbsent(date, () => []).add(_IndexedSession(i, _sessions[i]));
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Schedule Planner'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5C35C9), Color(0xFF3B6FE8)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                SizedBox(width: 5),
                Text(
                  'AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _loadingData
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            )
          : _deadlines.isEmpty
          ? _buildEmptyState()
          : _buildContent(isDark),
      bottomNavigationBar: _hasGenerated && !_generating && _sessions.isNotEmpty
          ? _buildBottomBar()
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.hourglass_empty_rounded,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No upcoming deadlines',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Add deadlines with future due dates and the AI will build a study plan for you.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF5C35C9), Color(0xFF3B6FE8)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Smart Study Planner',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Select which deadlines you want to plan. AI will spread sessions across your free days avoiding your calendar slots.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Text(
          'Select Deadlines to Plan',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 10),

        // Render selectable interactive items for your deadlines
        ..._deadlines.map((d) {
          final id = d['id']?.toString() ?? d['title'] ?? '';
          final isChecked = _selectedDeadlineIds.contains(id);
          final color = d['courseColor'] != null
              ? Color((d['courseColor'] as num).toInt())
              : Colors.deepPurple;
          final hours = d['estimatedHours']?.toString() ?? '?';

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isChecked
                    ? color.withOpacity(0.4)
                    : Colors.grey.withOpacity(0.15),
                width: 1.5,
              ),
            ),
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
            child: CheckboxListTile(
              activeColor: color,
              value: isChecked,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedDeadlineIds.add(id);
                  } else {
                    _selectedDeadlineIds.remove(id);
                  }
                });
              },
              title: Text(
                d['title'] ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                'Due ${d['date']}  ·  ${d['course'] ?? ''}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              secondary: Container(
                width: 4,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              controlAffinity: ListTileControlAffinity.trailing,
            ),
          );
        }),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _generating ? null : _generate,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _generating
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'AI is planning your schedule...',
                        style: TextStyle(fontSize: 15),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _hasGenerated
                            ? 'Regenerate Schedule'
                            : 'Generate Study Schedule',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        if (_hasGenerated && !_generating) ...[
          if (_sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No valid, free sessions could be generated.',
                  style: TextStyle(color: Colors.grey.shade400),
                ),
              ),
            )
          else ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  'Suggested Sessions',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    if (_selected.length == _sessions.length)
                      _selected.clear();
                    else
                      _selected = Set.from(
                        List.generate(_sessions.length, (i) => i),
                      );
                  }),
                  child: Text(
                    _selected.length == _sessions.length
                        ? 'Deselect all'
                        : 'Select all',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._buildGroupedSessions(isDark),
          ],
        ],
      ],
    );
  }

  List<Widget> _buildGroupedSessions(bool isDark) {
    final grouped = _grouped();
    final sortedDates = grouped.keys.toList()..sort();
    final widgets = <Widget>[];

    for (final date in sortedDates) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _fmtDisplayDate(date),
                  style: const TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Divider(color: Colors.grey.shade200)),
            ],
          ),
        ),
      );

      for (final indexedSession in grouped[date]!) {
        final i = indexedSession.index;
        final s = indexedSession.session;
        final isSelected = _selected.contains(i);
        final isConflicted = s['isConflicted'] == true;

        widgets.add(
          GestureDetector(
            onTap: () => setState(
              () => isSelected ? _selected.remove(i) : _selected.add(i),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isConflicted
                    ? Colors.red.withOpacity(0.08)
                    : (isSelected
                          ? Colors.deepPurple.withOpacity(0.06)
                          : (isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade50)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isConflicted
                      ? Colors.red.shade400
                      : (isSelected ? Colors.deepPurple : Colors.transparent),
                  width: isConflicted ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? Colors.deepPurple
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? Colors.deepPurple
                            : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s['sessionTitle'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: Colors.deepPurple.shade300,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${s['startTime']} – ${s['endTime']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.deepPurple.shade400,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              Icons.assignment_rounded,
                              size: 12,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                s['deadlineTitle'] ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: (_selected.isEmpty || _saving) ? null : _addToCalendar,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  _selected.isEmpty
                      ? 'Select sessions to add'
                      : '📅 Add ${_selected.length} session${_selected.length == 1 ? '' : 's'} to Calendar',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

class _IndexedSession {
  final int index;
  final Map<String, dynamic> session;
  _IndexedSession(this.index, this.session);
}
