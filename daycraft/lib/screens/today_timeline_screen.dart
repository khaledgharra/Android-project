import 'dart:async';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class TodayTimelineScreen extends StatefulWidget {
  const TodayTimelineScreen({super.key});

  @override
  State<TodayTimelineScreen> createState() => TodayTimelineScreenState();
}

class TodayTimelineScreenState extends State<TodayTimelineScreen> {
  List<Map<String, dynamic>> allSchedule = [];
  List<Map<String, dynamic>> dayEvents = [];
  bool isLoading = true;
  Timer? _timeUpdateTimer;

  /// The currently viewed date
  DateTime selectedDate = DateTime.now();

  // Study session state
  Map<String, dynamic>? activeStudyWindow;
  String? studyObjective;
  bool isTimerRunning = false;
  bool isTimerPaused = false;
  int remainingSeconds = 0;
  int totalSessionSeconds = 0;
  Timer? _countdownTimer;
  Set<String> completedWindows = {};

  // Timeline constants
  static const double hourHeight = 80.0;
  static const int startHour = 6;
  static const int endHour = 24;
  static const int totalHours = endHour - startHour;
  static const double totalHeight = totalHours * hourHeight;
  static const double timeColumnWidth = 55.0;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    loadTodayEvents();
    _timeUpdateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timeUpdateTimer?.cancel();
    _countdownTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isToday {
    final now = DateTime.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return "Monday";
      case 2: return "Tuesday";
      case 3: return "Wednesday";
      case 4: return "Thursday";
      case 5: return "Friday";
      case 6: return "Saturday";
      case 7: return "Sunday";
      default: return "";
    }
  }

  (int, int) _parseTime(String time) {
    final cleaned = time.trim().toUpperCase();
    final isPM = cleaned.contains("PM");
    final isAM = cleaned.contains("AM");
    final withoutPeriod = cleaned.replaceAll("AM", "").replaceAll("PM", "").trim();
    final parts = withoutPeriod.split(":");
    int hour = int.parse(parts[0].trim());
    int minute = parts.length > 1 ? int.parse(parts[1].trim()) : 0;
    if (isPM && hour != 12) hour += 12;
    if (isAM && hour == 12) hour = 0;
    return (hour, minute);
  }

  Future<void> loadTodayEvents() async {
    final loaded = await StorageService.loadSchedule();
    if (!mounted) return;
    setState(() {
      allSchedule = loaded;
    });
    _filterEventsForSelectedDay();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isToday) _scrollToCurrentTime();
    });
  }

  void _filterEventsForSelectedDay() {
    final dayName = _getDayName(selectedDate.weekday);

    final filtered = allSchedule.where((item) {
      return item["day"] == dayName &&
          item["start"] != null &&
          item["end"] != null;
    }).toList();

    filtered.sort((a, b) {
      final (aH, aM) = _parseTime(a["start"]!);
      final (bH, bM) = _parseTime(b["start"]!);
      return (aH * 60 + aM).compareTo(bH * 60 + bM);
    });

    setState(() {
      dayEvents = filtered;
      isLoading = false;
    });
  }

  void _goToPreviousDay() {
    setState(() {
      selectedDate = selectedDate.subtract(const Duration(days: 1));
    });
    _filterEventsForSelectedDay();
  }

  void _goToNextDay() {
    setState(() {
      selectedDate = selectedDate.add(const Duration(days: 1));
    });
    _filterEventsForSelectedDay();
  }

  void _goToToday() {
    setState(() {
      selectedDate = DateTime.now();
    });
    _filterEventsForSelectedDay();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentTime();
    });
  }

  void _scrollToCurrentTime() {
    final now = DateTime.now();
    final currentMinutes = (now.hour - startHour) * 60 + now.minute;
    final targetScroll = (currentMinutes * (hourHeight / 60)) - 150;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        targetScroll.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
  }

  /// Compute study windows (gaps ≥ 30 min between events)
  List<Map<String, dynamic>> _computeStudyWindows() {
    List<Map<String, dynamic>> windows = [];

    List<(int, int)> occupiedSlots = [];
    for (var event in dayEvents) {
      final (startH, startM) = _parseTime(event["start"]!);
      final (endH, endM) = _parseTime(event["end"]!);
      occupiedSlots.add((startH * 60 + startM, endH * 60 + endM));
    }
    occupiedSlots.sort((a, b) => a.$1.compareTo(b.$1));

    int searchStart = startHour * 60;
    int searchEnd = endHour * 60;

    List<(int, int)> merged = [];
    for (var slot in occupiedSlots) {
      if (merged.isEmpty || slot.$1 > merged.last.$2) {
        merged.add(slot);
      } else {
        final last = merged.removeLast();
        merged.add((last.$1, slot.$2 > last.$2 ? slot.$2 : last.$2));
      }
    }

    int prevEnd = searchStart;
    for (var slot in merged) {
      if (slot.$1 > prevEnd) {
        final gapDuration = slot.$1 - prevEnd;
        if (gapDuration >= 30) {
          windows.add({
            "startMinutes": prevEnd,
            "endMinutes": slot.$1,
            "duration": gapDuration,
          });
        }
      }
      prevEnd = slot.$2;
    }

    if (prevEnd < searchEnd) {
      final gapDuration = searchEnd - prevEnd;
      if (gapDuration >= 30) {
        windows.add({
          "startMinutes": prevEnd,
          "endMinutes": searchEnd,
          "duration": gapDuration,
        });
      }
    }

    return windows;
  }

  String _formatDuration(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins == 0) return "$hours ${hours == 1 ? 'Hour' : 'Hours'} Free";
      return "$hours:${mins.toString().padLeft(2, '0')} Hours Free";
    }
    return "$minutes Min Free";
  }

  String _formatMinutesToTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final period = h >= 12 ? "PM" : "AM";
    final displayH = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return "$displayH:${m.toString().padLeft(2, '0')} $period";
  }

  void _showStudyObjectiveDialog(Map<String, dynamic> window) {
    final controller = TextEditingController();
    final windowKey = "${window["startMinutes"]}-${window["endMinutes"]}";

    if (completedWindows.contains(windowKey)) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("📚 Set Study Objective"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${_formatMinutesToTime(window["startMinutes"])} — ${_formatMinutesToTime(window["endMinutes"])}",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            Text(
              _formatDuration(window["duration"]),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "e.g., Read Chapter 4...",
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              setState(() {
                activeStudyWindow = window;
                studyObjective = controller.text.trim();
                remainingSeconds = window["duration"] * 60;
                totalSessionSeconds = window["duration"] * 60;
                isTimerRunning = false;
                isTimerPaused = false;
              });
            },
            child: const Text("Set Goal"),
          ),
        ],
      ),
    );
  }

  void _startTimer() {
    setState(() {
      isTimerRunning = true;
      isTimerPaused = false;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (remainingSeconds <= 0) { timer.cancel(); _completeSession(); return; }
      setState(() { remainingSeconds--; });
    });
  }

  void _pauseTimer() {
    _countdownTimer?.cancel();
    setState(() { isTimerPaused = true; isTimerRunning = false; });
  }

  void _resumeTimer() { _startTimer(); }

  void _completeSession() {
    _countdownTimer?.cancel();
    final windowKey = "${activeStudyWindow!["startMinutes"]}-${activeStudyWindow!["endMinutes"]}";
    setState(() {
      completedWindows.add(windowKey);
      activeStudyWindow = null;
      studyObjective = null;
      isTimerRunning = false;
      isTimerPaused = false;
      remainingSeconds = 0;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🎉 Study session completed!"), backgroundColor: Colors.green),
      );
    }
  }

  void _moveToNextGap(Map<String, dynamic> missedWindow) {
    final studyWindows = _computeStudyWindows();
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final missedKey = "${missedWindow["startMinutes"]}-${missedWindow["endMinutes"]}";

    Map<String, dynamic>? nextWindow;
    for (var window in studyWindows) {
      final windowKey = "${window["startMinutes"]}-${window["endMinutes"]}";
      if (windowKey == missedKey) continue;
      if (completedWindows.contains(windowKey)) continue;
      if ((window["startMinutes"] as int) > currentMinutes) { nextWindow = window; break; }
    }

    if (nextWindow != null) {
      setState(() {
        activeStudyWindow = nextWindow;
        remainingSeconds = nextWindow!["duration"] * 60;
        totalSessionSeconds = nextWindow["duration"] * 60;
        isTimerRunning = false;
        isTimerPaused = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("📦 Moved to ${_formatMinutesToTime(nextWindow["startMinutes"])} — ${_formatMinutesToTime(nextWindow["endMinutes"])}"),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ No available study windows left today"), backgroundColor: Colors.red),
      );
    }
  }

  String _formatCountdown(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayName = _getDayName(selectedDate.weekday);
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === DATE HEADER with navigation arrows (Google Calendar style) ===
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  // Left arrow
                  IconButton(
                    onPressed: _goToPreviousDay,
                    icon: const Icon(Icons.chevron_left_rounded, size: 28),
                    color: Colors.grey.shade700,
                  ),

                  // Date display
                  Expanded(
                    child: GestureDetector(
                      onTap: _isToday ? null : _goToToday,
                      child: Column(
                        children: [
                          Text(
                            dayName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _isToday ? Colors.deepPurple : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Day number in circle (purple if today)
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isToday ? Colors.deepPurple : Colors.transparent,
                            ),
                            child: Center(
                              child: Text(
                                "${selectedDate.day}",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _isToday ? Colors.white : Colors.grey.shade800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${months[selectedDate.month - 1]} ${selectedDate.year}",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Right arrow
                  IconButton(
                    onPressed: _goToNextDay,
                    icon: const Icon(Icons.chevron_right_rounded, size: 28),
                    color: Colors.grey.shade700,
                  ),
                ],
              ),
            ),

            // "Today" button if not on today
            if (!_isToday)
              Center(
                child: TextButton.icon(
                  onPressed: _goToToday,
                  icon: const Icon(Icons.today, size: 16),
                  label: const Text("Go to Today"),
                  style: TextButton.styleFrom(foregroundColor: Colors.deepPurple),
                ),
              ),

            const SizedBox(height: 8),

            // Active study session banner (only on today)
            if (activeStudyWindow != null && _isToday) _buildStudySessionBanner(),

            // Timeline
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : dayEvents.isEmpty
                      ? _buildEmptyState()
                      : _buildTimeline(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "No events for this day",
            style: TextStyle(fontSize: 18, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            "Add activities in the Week tab",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildStudySessionBanner() {
    final progress = totalSessionSeconds > 0
        ? 1.0 - (remainingSeconds / totalSessionSeconds)
        : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.green.shade400, Colors.teal.shade400]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.green.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_stories, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  studyObjective ?? "",
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              _formatCountdown(remainingSeconds),
              style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w300, fontFamily: "monospace"),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress, minHeight: 5,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isTimerRunning && !isTimerPaused)
                _controlButton(Icons.play_arrow_rounded, "Start", _startTimer),
              if (isTimerRunning)
                _controlButton(Icons.pause_rounded, "Pause", _pauseTimer),
              if (isTimerPaused)
                _controlButton(Icons.play_arrow_rounded, "Resume", _resumeTimer),
              const SizedBox(width: 10),
              _controlButton(Icons.check_circle_rounded, "Done", _completeSession),
              const SizedBox(width: 10),
              _controlButton(Icons.skip_next_rounded, "Move", () => _moveToNextGap(activeStudyWindow!)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _controlButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(24)),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    final now = DateTime.now();
    final currentMinutes = (now.hour - startHour) * 60 + now.minute;
    final currentTimeTop = currentMinutes * (hourHeight / 60);
    final studyWindows = _isToday ? _computeStudyWindows() : <Map<String, dynamic>>[];

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 40),
      child: SizedBox(
        height: totalHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time labels
            SizedBox(
              width: timeColumnWidth,
              height: totalHeight,
              child: Stack(
                children: List.generate(totalHours + 1, (index) {
                  final hour = startHour + index;
                  return Positioned(
                    top: index * hourHeight - 8,
                    left: 0, right: 0,
                    child: Text(
                      "${hour.toString().padLeft(2, '0')}:00",
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  );
                }),
              ),
            ),

            // Events + indicators
            Expanded(
              child: SizedBox(
                height: totalHeight,
                child: Stack(
                  children: [
                    // Hour grid lines
                    ...List.generate(totalHours + 1, (index) {
                      return Positioned(
                        top: index * hourHeight,
                        left: 0, right: 0,
                        child: Container(height: 0.5, color: Colors.grey.shade200),
                      );
                    }),

                    // Study windows (only on today)
                    if (_isToday)
                      ...studyWindows.map((window) {
                        final windowStartMinutes = window["startMinutes"] as int;
                        final windowEndMinutes = window["endMinutes"] as int;
                        final duration = window["duration"] as int;
                        final windowKey = "$windowStartMinutes-$windowEndMinutes";
                        final isCompleted = completedWindows.contains(windowKey);
                        final isActive = activeStudyWindow != null &&
                            activeStudyWindow!["startMinutes"] == windowStartMinutes;

                        final top = (windowStartMinutes - startHour * 60) * (hourHeight / 60);
                        final height = duration * (hourHeight / 60);

                        return Positioned(
                          top: top, left: 4, right: 4,
                          child: GestureDetector(
                            onTap: isCompleted || isActive ? null : () => _showStudyObjectiveDialog(window),
                            child: Container(
                              height: height < 40 ? 40 : height,
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : isActive
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.blue.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: isCompleted
                                    ? Border.all(color: Colors.green.withValues(alpha: 0.4), width: 1.5)
                                    : null,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isCompleted)
                                      Icon(Icons.check_circle, color: Colors.green.shade400, size: 22)
                                    else if (isActive)
                                      Icon(Icons.auto_stories, color: Colors.green.shade400, size: 18)
                                    else
                                      Icon(Icons.add_circle_outline, color: Colors.blue.shade300, size: 18),
                                    const SizedBox(height: 3),
                                    Text(
                                      isCompleted ? "Completed ✓"
                                          : isActive ? studyObjective ?? "Studying..."
                                          : "Available Study Window",
                                      style: TextStyle(
                                        color: isCompleted ? Colors.green.shade600
                                            : isActive ? Colors.green.shade600
                                            : Colors.blue.shade400,
                                        fontSize: 11, fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (!isCompleted && !isActive)
                                      Text(
                                        _formatDuration(duration),
                                        style: TextStyle(color: Colors.blue.shade300, fontSize: 10),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                    // Event blocks
                    ...dayEvents.map((event) {
                      final (startH, startM) = _parseTime(event["start"]!);
                      final (endH, endM) = _parseTime(event["end"]!);

                      final eventStartMinutes = (startH - startHour) * 60 + startM;
                      final durationMinutes = (endH * 60 + endM) - (startH * 60 + startM);

                      final top = eventStartMinutes * (hourHeight / 60);
                      final height = durationMinutes * (hourHeight / 60);

                      final color = Color(event["color"] ?? Colors.deepPurple.toARGB32());

                      return Positioned(
                        top: top, left: 4, right: 4,
                        child: Container(
                          height: height < 35 ? 35 : height,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                event["title"] ?? event["name"] ?? "",
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                              if (height > 50)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    "${event["start"]} — ${event["end"]}",
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),

                    // Current time red line (ONLY on today)
                    if (_isToday && currentMinutes >= 0 && currentMinutes <= totalHours * 60)
                      Positioned(
                        top: currentTimeTop,
                        left: 0, right: 0,
                        child: Row(
                          children: [
                            Container(
                              width: 10, height: 10,
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            ),
                            Expanded(child: Container(height: 2, color: Colors.red)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
