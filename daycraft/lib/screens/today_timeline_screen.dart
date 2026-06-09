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

  /// Day or Week view
  String viewMode = "Day"; // "Day" or "Week"

  /// The currently viewed date (for day view)
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
  static const int startHour = 0;
  static const int endHour = 24;
  static const int totalHours = endHour - startHour;
  static const double totalHeight = totalHours * hourHeight;
  static const double timeColumnWidth = 45.0;

  final ScrollController _scrollController = ScrollController();

  static const List<String> weekDays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  static const List<String> fullDayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

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
    return selectedDate.year == now.year && selectedDate.month == now.month && selectedDate.day == now.day;
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
      return item["day"] == dayName && item["start"] != null && item["end"] != null;
    }).toList();
    filtered.sort((a, b) {
      final (aH, aM) = _parseTime(a["start"]!);
      final (bH, bM) = _parseTime(b["start"]!);
      return (aH * 60 + aM).compareTo(bH * 60 + bM);
    });
    setState(() { dayEvents = filtered; isLoading = false; });
  }

  void _goToPreviousDay() {
    setState(() { selectedDate = selectedDate.subtract(const Duration(days: 1)); });
    _filterEventsForSelectedDay();
  }

  void _goToNextDay() {
    setState(() { selectedDate = selectedDate.add(const Duration(days: 1)); });
    _filterEventsForSelectedDay();
  }

  void _goToToday() {
    setState(() { selectedDate = DateTime.now(); });
    _filterEventsForSelectedDay();
    WidgetsBinding.instance.addPostFrameCallback((_) { _scrollToCurrentTime(); });
  }

  void _scrollToCurrentTime() {
    final now = DateTime.now();
    final currentMinutes = (now.hour - startHour) * 60 + now.minute;
    final targetScroll = (currentMinutes * (hourHeight / 60)) - 150;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        targetScroll.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500), curve: Curves.easeOut,
      );
    }
  }

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
      if (merged.isEmpty || slot.$1 > merged.last.$2) { merged.add(slot); }
      else { final last = merged.removeLast(); merged.add((last.$1, slot.$2 > last.$2 ? slot.$2 : last.$2)); }
    }
    int prevEnd = searchStart;
    for (var slot in merged) {
      if (slot.$1 > prevEnd && slot.$1 - prevEnd >= 30) {
        windows.add({"startMinutes": prevEnd, "endMinutes": slot.$1, "duration": slot.$1 - prevEnd});
      }
      prevEnd = slot.$2;
    }
    if (prevEnd < searchEnd && searchEnd - prevEnd >= 30) {
      windows.add({"startMinutes": prevEnd, "endMinutes": searchEnd, "duration": searchEnd - prevEnd});
    }
    return windows;
  }

  String _formatDuration(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins == 0) return "$hours ${hours == 1 ? 'Hr' : 'Hrs'}";
      return "${hours}h ${mins}m";
    }
    return "${minutes}m";
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
            Text("${_formatMinutesToTime(window["startMinutes"])} — ${_formatMinutesToTime(window["endMinutes"])}",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            Text(_formatDuration(window["duration"]), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 16),
            TextField(controller: controller, autofocus: true, decoration: InputDecoration(
              hintText: "e.g., Read Chapter 4...", filled: true, fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            )),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              setState(() {
                activeStudyWindow = window; studyObjective = controller.text.trim();
                remainingSeconds = window["duration"] * 60; totalSessionSeconds = window["duration"] * 60;
                isTimerRunning = false; isTimerPaused = false;
              });
            },
            child: const Text("Set Goal"),
          ),
        ],
      ),
    );
  }

  void _startTimer() {
    setState(() { isTimerRunning = true; isTimerPaused = false; });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (remainingSeconds <= 0) { timer.cancel(); _completeSession(); return; }
      setState(() { remainingSeconds--; });
    });
  }
  void _pauseTimer() { _countdownTimer?.cancel(); setState(() { isTimerPaused = true; isTimerRunning = false; }); }
  void _resumeTimer() { _startTimer(); }
  void _completeSession() {
    _countdownTimer?.cancel();
    final windowKey = "${activeStudyWindow!["startMinutes"]}-${activeStudyWindow!["endMinutes"]}";
    setState(() { completedWindows.add(windowKey); activeStudyWindow = null; studyObjective = null; isTimerRunning = false; isTimerPaused = false; remainingSeconds = 0; });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🎉 Study session completed!"), backgroundColor: Colors.green));
  }

  String _formatCountdown(int seconds) {
    final m = seconds ~/ 60; final s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  // =================== ADD EVENT DIALOG ===================
  void _showAddEventDialog() {
    final titleController = TextEditingController();
    String selectedDay = _getDayName(selectedDate.weekday);
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Add Event"),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Event name...",
                  filled: true, fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              // Day picker
              GestureDetector(
                onTap: () async {
                  final picked = await showModalBottomSheet<String>(
                    context: context,
                    builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Padding(padding: EdgeInsets.all(12), child: Text("Select Day", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                      ...fullDayNames.map((d) => ListTile(title: Text(d), onTap: () => Navigator.pop(ctx, d))),
                    ])),
                  );
                  if (picked != null) setDialogState(() => selectedDay = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                  child: Row(children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.deepPurple),
                    const SizedBox(width: 10),
                    Text(selectedDay, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              // Time pickers
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: startTime ?? const TimeOfDay(hour: 8, minute: 0), initialEntryMode: TimePickerEntryMode.input);
                    if (picked != null) setDialogState(() => startTime = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: startTime != null ? Colors.deepPurple.shade200 : Colors.grey.shade200)),
                    child: Row(children: [
                      Icon(Icons.play_arrow_rounded, size: 16, color: startTime != null ? Colors.deepPurple : Colors.grey),
                      const SizedBox(width: 6),
                      Text(startTime?.format(context) ?? "Start", style: TextStyle(fontWeight: FontWeight.w600, color: startTime != null ? Colors.black87 : Colors.grey)),
                    ]),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: endTime ?? startTime ?? const TimeOfDay(hour: 9, minute: 0), initialEntryMode: TimePickerEntryMode.input);
                    if (picked != null) setDialogState(() => endTime = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: endTime != null ? Colors.deepPurple.shade200 : Colors.grey.shade200)),
                    child: Row(children: [
                      Icon(Icons.stop_rounded, size: 16, color: endTime != null ? Colors.deepPurple : Colors.grey),
                      const SizedBox(width: 6),
                      Text(endTime?.format(context) ?? "End", style: TextStyle(fontWeight: FontWeight.w600, color: endTime != null ? Colors.black87 : Colors.grey)),
                    ]),
                  ),
                )),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                if (titleController.text.trim().isEmpty || startTime == null || endTime == null) return;
                final newItem = {
                  "title": titleController.text.trim(),
                  "type": "Activity",
                  "day": selectedDay,
                  "start": startTime!.format(context),
                  "end": endTime!.format(context),
                };
                final docId = await StorageService.addScheduleItem(newItem);
                if (docId != null) newItem['id'] = docId;
                if (!mounted) return;
                Navigator.pop(context);
                setState(() { allSchedule.add(newItem); });
                _filterEventsForSelectedDay();
              },
              child: const Text("Add"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayName = _getDayName(selectedDate.weekday);
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      floatingActionButton: FloatingActionButton(
        heroTag: "calendar_fab",
        backgroundColor: Colors.deepPurple,
        onPressed: _showAddEventDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // === HEADER: View mode dropdown + date navigation ===
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  // View mode dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: viewMode,
                        isDense: true,
                        style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w600, fontSize: 14),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.deepPurple),
                        items: const [
                          DropdownMenuItem(value: "Day", child: Text("Day")),
                          DropdownMenuItem(value: "Week", child: Text("Week")),
                        ],
                        onChanged: (v) => setState(() => viewMode = v!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Day navigation (only in Day view)
                  if (viewMode == "Day") ...[
                    IconButton(onPressed: _goToPreviousDay, icon: const Icon(Icons.chevron_left_rounded), iconSize: 24, color: Colors.grey.shade700),
                    Expanded(
                      child: GestureDetector(
                        onTap: _isToday ? null : _goToToday,
                        child: Column(
                          children: [
                            Text(dayName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _isToday ? Colors.deepPurple : Colors.grey.shade700)),
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: _isToday ? Colors.deepPurple : Colors.transparent),
                              child: Center(child: Text("${selectedDate.day}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _isToday ? Colors.white : Colors.grey.shade800))),
                            ),
                            Text("${months[selectedDate.month - 1]} ${selectedDate.year}", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                    ),
                    IconButton(onPressed: _goToNextDay, icon: const Icon(Icons.chevron_right_rounded), iconSize: 24, color: Colors.grey.shade700),
                  ] else ...[
                    const Expanded(child: Center(child: Text("Week View", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple)))),
                  ],
                ],
              ),
            ),

            if (viewMode == "Day" && !_isToday)
              TextButton.icon(onPressed: _goToToday, icon: const Icon(Icons.today, size: 14), label: const Text("Today", style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: Colors.deepPurple, padding: EdgeInsets.zero, minimumSize: const Size(0, 30))),

            const SizedBox(height: 4),

            // Study session banner
            if (activeStudyWindow != null && _isToday && viewMode == "Day") _buildStudyBanner(),

            // Body: Day view or Week view
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : viewMode == "Day"
                      ? (dayEvents.isEmpty ? _buildEmptyState() : _buildDayTimeline())
                      : _buildWeekView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.event_busy_rounded, size: 56, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text("No events for this day", style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
    ]));
  }

  Widget _buildStudyBanner() {
    final progress = totalSessionSeconds > 0 ? 1.0 - (remainingSeconds / totalSessionSeconds) : 0.0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.green.shade400, Colors.teal.shade400]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.auto_stories, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Expanded(child: Text(studyObjective ?? "", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 8),
        Center(child: Text(_formatCountdown(remainingSeconds), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w300, fontFamily: "monospace"))),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(Colors.white))),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (!isTimerRunning && !isTimerPaused) _btn(Icons.play_arrow_rounded, "Start", _startTimer),
          if (isTimerRunning) _btn(Icons.pause_rounded, "Pause", _pauseTimer),
          if (isTimerPaused) _btn(Icons.play_arrow_rounded, "Resume", _resumeTimer),
          const SizedBox(width: 8),
          _btn(Icons.check_circle_rounded, "Done", _completeSession),
        ]),
      ]),
    );
  }

  Widget _btn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [Icon(icon, color: Colors.white, size: 16), const SizedBox(width: 4), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12))]),
    ));
  }

  // =================== DAY VIEW ===================
  Widget _buildDayTimeline() {
    final now = DateTime.now();
    final currentMinutes = (now.hour - startHour) * 60 + now.minute;
    final currentTimeTop = currentMinutes * (hourHeight / 60);
    final studyWindows = _isToday ? _computeStudyWindows() : <Map<String, dynamic>>[];

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 40),
      child: SizedBox(height: totalHeight + 16, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Time labels
        SizedBox(width: timeColumnWidth, height: totalHeight + 16, child: Stack(children: List.generate(totalHours, (i) {
          // Skip 00:00 (first) and 24:00 (last) — like Google Calendar
          final hour = startHour + i + 1;
          if (hour >= endHour) return const SizedBox.shrink();
          return Positioned(top: (i + 1) * hourHeight - 7, left: 0, right: 0,
            child: Text("${hour.toString().padLeft(2, '0')}:00", style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w500), textAlign: TextAlign.center));
        }))),
        // Events
        Expanded(child: SizedBox(height: totalHeight, child: Stack(children: [
          ...List.generate(totalHours + 1, (i) => Positioned(top: i * hourHeight, left: 0, right: 0, child: Container(height: 0.5, color: Colors.grey.shade200))),
          // Study windows
          if (_isToday) ...studyWindows.map((w) {
            final sMin = w["startMinutes"] as int; final eMin = w["endMinutes"] as int; final dur = w["duration"] as int;
            final key = "$sMin-$eMin"; final done = completedWindows.contains(key);
            final active = activeStudyWindow != null && activeStudyWindow!["startMinutes"] == sMin;
            final top = (sMin - startHour * 60) * (hourHeight / 60); final h = dur * (hourHeight / 60);
            return Positioned(top: top, left: 4, right: 4, child: GestureDetector(
              onTap: done || active ? null : () => _showStudyObjectiveDialog(w),
              child: Container(height: h < 36 ? 36 : h, decoration: BoxDecoration(
                color: done ? Colors.green.withValues(alpha: 0.12) : Colors.blue.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10),
                border: done ? Border.all(color: Colors.green.withValues(alpha: 0.4)) : null),
                child: Center(child: Text(done ? "✓" : "+  ${_formatDuration(dur)}", style: TextStyle(color: done ? Colors.green.shade600 : Colors.blue.shade400, fontSize: 11, fontWeight: FontWeight.w600))))));
          }),
          // Events
          ...dayEvents.map((event) {
            final (sH, sM) = _parseTime(event["start"]!); final (eH, eM) = _parseTime(event["end"]!);
            final sMins = (sH - startHour) * 60 + sM; final dur = (eH * 60 + eM) - (sH * 60 + sM);
            final top = sMins * (hourHeight / 60); final h = dur * (hourHeight / 60);
            final color = Color(event["color"] ?? Colors.deepPurple.toARGB32());
            return Positioned(top: top, left: 4, right: 4, child: Container(
              height: h < 32 ? 32 : h, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(event["title"] ?? event["name"] ?? "", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (h > 45) Text("${event["start"]} — ${event["end"]}", style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ])));
          }),
          // Red line
          if (_isToday && currentMinutes >= 0 && currentMinutes <= totalHours * 60)
            Positioned(top: currentTimeTop, left: 0, right: 0, child: Row(children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
              Expanded(child: Container(height: 1.5, color: Colors.red)),
            ])),
        ]))),
      ])),
    );
  }

  // =================== WEEK VIEW (Table) ===================
  Widget _buildWeekView() {
    const double weekHourHeight = 50.0;
    const double headerHeight = 36.0;
    final now = DateTime.now();
    final todayWeekday = now.weekday; // 1=Mon...7=Sun

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(children: [
        // Day headers row
        Row(children: [
          SizedBox(width: timeColumnWidth, height: headerHeight),
          ...List.generate(7, (i) {
            // Map to weekday: Sun=0 → 7, Mon=1 → 1, etc.
            final dartWeekday = i == 0 ? 7 : i; // Sun=7 for Dart
            final isToday = dartWeekday == todayWeekday;
            return Expanded(child: Container(
              height: headerHeight,
              decoration: BoxDecoration(
                color: isToday ? Colors.deepPurple.withValues(alpha: 0.1) : Colors.transparent,
                border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 0.5)),
              ),
              child: Center(child: Text(weekDays[i], style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold,
                color: isToday ? Colors.deepPurple : Colors.grey.shade600,
              ))),
            ));
          }),
        ]),
        // Timeline grid
        SizedBox(
          height: totalHours * weekHourHeight,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Time labels
            SizedBox(width: timeColumnWidth, height: totalHours * weekHourHeight,
              child: Stack(children: List.generate(totalHours + 1, (i) {
                return Positioned(top: i * weekHourHeight - 7, left: 0, right: 0,
                  child: Text("${(startHour + i).toString().padLeft(2, '0')}:00",
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.w600), textAlign: TextAlign.center));
              }))),
            // 7 day columns
            ...List.generate(7, (dayIndex) {
              final dayFullName = fullDayNames[dayIndex];
              final dartWeekday = dayIndex == 0 ? 7 : dayIndex;
              final isToday = dartWeekday == todayWeekday;
              final daySchedule = allSchedule.where((item) => item["day"] == dayFullName && item["start"] != null && item["end"] != null).toList();

              return Expanded(child: Container(
                height: totalHours * weekHourHeight,
                decoration: BoxDecoration(
                  color: isToday ? Colors.deepPurple.withValues(alpha: 0.03) : Colors.transparent,
                  border: Border(left: BorderSide(color: Colors.grey.shade200, width: 0.5)),
                ),
                child: Stack(children: [
                  // Grid lines
                  ...List.generate(totalHours + 1, (i) => Positioned(
                    top: i * weekHourHeight, left: 0, right: 0,
                    child: Container(height: 0.5, color: Colors.grey.shade200))),
                  // Events
                  ...daySchedule.map((event) {
                    final (sH, sM) = _parseTime(event["start"]!);
                    final (eH, eM) = _parseTime(event["end"]!);
                    final sMins = (sH - startHour) * 60 + sM;
                    final dur = (eH * 60 + eM) - (sH * 60 + sM);
                    final top = sMins * (weekHourHeight / 60);
                    final h = dur * (weekHourHeight / 60);
                    final color = Color(event["color"] ?? Colors.deepPurple.toARGB32());
                    return Positioned(top: top, left: 1, right: 1, child: Container(
                      height: h < 18 ? 18 : h,
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                      child: Text(event["title"] ?? event["name"] ?? "",
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ));
                  }),
                  // Red line for today
                  if (isToday) Positioned(
                    top: ((now.hour - startHour) * 60 + now.minute) * (weekHourHeight / 60),
                    left: 0, right: 0,
                    child: Container(height: 1.5, color: Colors.red),
                  ),
                ]),
              ));
            }),
          ]),
        ),
      ]),
    );
  }
}
