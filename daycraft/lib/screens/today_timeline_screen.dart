import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/storage_service.dart';

class TodayTimelineScreen extends StatefulWidget {
  const TodayTimelineScreen({super.key});

  @override
  State<TodayTimelineScreen> createState() => TodayTimelineScreenState();
}

class TodayTimelineScreenState extends State<TodayTimelineScreen> {
  List<Map<String, dynamic>> allSchedule = [];
  List<Map<String, dynamic>> dayEvents = [];
  List<Map<String, dynamic>> allDeadlines = [];
  List<Map<String, dynamic>> dayDeadlines = [];
  bool isLoading = true;
  Timer? _timeUpdateTimer;

  String viewMode = "Day";
  DateTime selectedDate = DateTime.now();

  static const double hourHeight = 80.0;
  int startHour = 6;
  static const int endHour = 24;
  int get totalHours => endHour - startHour;
  double get totalHeight => totalHours * hourHeight;
  static const double timeColumnWidth = 45.0;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _addEventTitleCtrl = TextEditingController();
  final TextEditingController _addEventStartCtrl = TextEditingController();
  final TextEditingController _addEventEndCtrl = TextEditingController();

  static const List<String> weekDays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  static const List<String> fullDayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

  @override
  void initState() {
    super.initState();
    _loadStartHour();
    loadTodayEvents();
    _timeUpdateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadStartHour() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('calendar_start_hour');
    if (saved != null && mounted) setState(() => startHour = saved);
  }

  Future<void> _saveStartHour(int hour) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('calendar_start_hour', hour);
  }

  void _showStartHourPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.75,
        builder: (ctx, scrollController) => SafeArea(
          child: Column(
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text("Day Start Time", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: 13,
                  itemBuilder: (_, i) {
                    final label = i == 0 ? "12:00 AM (midnight)" : i < 12 ? "${i.toString().padLeft(2,'0')}:00 AM" : "12:00 PM";
                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.schedule_rounded, size: 18, color: i == startHour ? Colors.deepPurple : Colors.grey.shade400),
                      title: Text(label, style: TextStyle(fontWeight: i == startHour ? FontWeight.bold : FontWeight.normal, color: i == startHour ? Colors.deepPurple : null)),
                      trailing: i == startHour ? const Icon(Icons.check_rounded, color: Colors.deepPurple, size: 18) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => startHour = i);
                        _saveStartHour(i);
                        WidgetsBinding.instance.addPostFrameCallback((_) { if (_isToday) _scrollToCurrentTime(); });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timeUpdateTimer?.cancel();
    _scrollController.dispose();
    _addEventTitleCtrl.dispose();
    _addEventStartCtrl.dispose();
    _addEventEndCtrl.dispose();
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
    final deadlines = await StorageService.loadDeadlines();
    if (!mounted) return;
    setState(() { allSchedule = loaded; allDeadlines = deadlines; });
    _filterEventsForSelectedDay();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isToday) _scrollToCurrentTime();
    });
  }

  DateTime? _parseDeadlineDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try { return DateTime.parse(dateStr); } catch (_) {}
    try {
      final parts = dateStr.split("/");
      if (parts.length == 3) {
        return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
    } catch (_) {}
    return null;
  }

  void _filterEventsForSelectedDay() {
    final dayName = _getDayName(selectedDate.weekday);
    final dateStr = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

    final filtered = allSchedule.where((item) {
      if (item["day"] != dayName || item["start"] == null || item["end"] == null) return false;

      // Check if this date is in the exceptions list (skipped occurrence)
      final exceptions = item["exceptions"];
      if (exceptions is List && exceptions.contains(dateStr)) return false;

      // If event has repeat == "once" and a specific date, only show on that date
      final repeat = item["repeat"] ?? "weekly"; // default to weekly for backward compat
      if (repeat == "once") {
        final eventDate = item["date"];
        if (eventDate != null && eventDate != dateStr) return false;
      }
      return true;
    }).toList();
    filtered.sort((a, b) {
      final (aH, aM) = _parseTime(a["start"]!);
      final (bH, bM) = _parseTime(b["start"]!);
      return (aH * 60 + aM).compareTo(bH * 60 + bM);
    });

    // Filter deadlines for the selected date
    final filteredDeadlines = allDeadlines.where((d) {
      final date = _parseDeadlineDate(d["date"]?.toString());
      if (date == null) return false;
      return date.year == selectedDate.year && date.month == selectedDate.month && date.day == selectedDate.day;
    }).toList();

    setState(() { dayEvents = filtered; dayDeadlines = filteredDeadlines; isLoading = false; });
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

  // =================== WEEK NAVIGATION ===================
  DateTime get _weekStart {
    // Week starts on Sunday
    final weekday = selectedDate.weekday % 7; // Sunday = 0
    return selectedDate.subtract(Duration(days: weekday));
  }

  void _goToPreviousWeek() {
    setState(() { selectedDate = selectedDate.subtract(const Duration(days: 7)); });
  }

  void _goToNextWeek() {
    setState(() { selectedDate = selectedDate.add(const Duration(days: 7)); });
  }

  String _getWeekRangeLabel() {
    final start = _weekStart;
    final end = start.add(const Duration(days: 6));
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    if (start.month == end.month) {
      return "${start.day} – ${end.day} ${months[start.month - 1]} ${start.year}";
    } else if (start.year == end.year) {
      return "${start.day} ${months[start.month - 1]} – ${end.day} ${months[end.month - 1]}";
    } else {
      return "${start.day} ${months[start.month - 1]} ${start.year} – ${end.day} ${months[end.month - 1]} ${end.year}";
    }
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

  // =================== EVENT EDIT BOTTOM SHEET ===================
  void _showEventEditSheet(Map<String, dynamic> event) {
    final eventColor = Color(event["color"] ?? Colors.deepPurple.toARGB32());
    final eventTitle = event["title"] ?? event["name"] ?? "Untitled";

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            // Event header
            Row(children: [
              Container(width: 14, height: 14, decoration: BoxDecoration(color: eventColor, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(child: Text(eventTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerLeft, child: Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text("${event["start"]} — ${event["end"]}  •  ${event["day"] ?? ""}", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            )),
            const SizedBox(height: 20),
            // Actions
            _editOption(Icons.edit_rounded, "Edit name", () async {
              Navigator.pop(ctx);
              _editEventName(event);
            }),
            _editOption(Icons.schedule_rounded, "Change time", () async {
              Navigator.pop(ctx);
              _editEventTime(event);
            }),
            _editOption(Icons.palette_rounded, "Change color", () async {
              Navigator.pop(ctx);
              _editEventColor(event);
            }),
            _editOption(Icons.delete_rounded, "Delete", () async {
              Navigator.pop(ctx);
              _deleteEvent(event);
            }, color: Colors.red),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Widget _editOption(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.grey.shade700, size: 22),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: color ?? Theme.of(context).colorScheme.onSurface)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Colors.transparent,
      onTap: onTap,
    );
  }

  // --- Edit name ---
  void _editEventName(Map<String, dynamic> event) {
    final controller = TextEditingController(text: event["title"] ?? event["name"] ?? "");
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("Edit Name"),
      content: TextField(controller: controller, autofocus: true,
        decoration: InputDecoration(filled: true, fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () async {
            if (controller.text.trim().isEmpty) return;
            event["title"] = controller.text.trim();
            final docId = event["id"];
            if (docId != null) await StorageService.updateScheduleItem(docId, {"title": event["title"]});
            Navigator.pop(ctx);
            setState(() {});
          },
          child: const Text("Save"),
        ),
      ],
    ));
  }

  // --- Edit time ---
  void _editEventTime(Map<String, dynamic> event) async {
    final (sH, sM) = _parseTime(event["start"]!);
    final (eH, eM) = _parseTime(event["end"]!);
    final pickedStart = await showTimePicker(context: context, initialTime: TimeOfDay(hour: sH, minute: sM), initialEntryMode: TimePickerEntryMode.inputOnly, helpText: "START TIME");
    if (pickedStart == null || !mounted) return;
    final pickedEnd = await showTimePicker(context: context, initialTime: TimeOfDay(hour: eH, minute: eM), initialEntryMode: TimePickerEntryMode.inputOnly, helpText: "END TIME");
    if (pickedEnd == null || !mounted) return;
    event["start"] = pickedStart.format(context);
    event["end"] = pickedEnd.format(context);
    final docId = event["id"];
    if (docId != null) await StorageService.updateScheduleItem(docId, {"start": event["start"], "end": event["end"]});
    setState(() {});
    _filterEventsForSelectedDay();
  }

  // --- Edit color ---
  void _editEventColor(Map<String, dynamic> event) {
    final colors = [Colors.deepPurple, Colors.blue, Colors.teal, Colors.green, Colors.orange, Colors.red, Colors.pink, Colors.indigo];
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Choose Color", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          Wrap(spacing: 16, runSpacing: 16, children: colors.map((c) => GestureDetector(
            onTap: () async {
              event["color"] = c.toARGB32();
              final docId = event["id"];
              if (docId != null) await StorageService.updateScheduleItem(docId, {"color": c.toARGB32()});
              Navigator.pop(ctx);
              setState(() {});
            },
            child: Container(width: 44, height: 44, decoration: BoxDecoration(color: c, shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))])),
          )).toList()),
        ]),
      )),
    );
  }

  // --- Delete event ---
  void _deleteEvent(Map<String, dynamic> event) async {
    final repeat = event["repeat"] ?? "weekly";
    final isCourse = event["type"] == "Course" || event["courseName"] != null;
    final isRecurring = repeat == "weekly" || isCourse;
    final dateStr = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

    if (isRecurring) {
      // For course events: only "skip this occurrence"
      // For other recurring events: "skip this occurrence" or "delete all"
      final choice = await showModalBottomSheet<String>(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text("Delete \"${event["title"] ?? event["name"] ?? ""}\"", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.event_busy_rounded, color: Colors.orange),
              title: const Text("Skip this occurrence"),
              subtitle: const Text("Remove only for this week"),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: Colors.transparent,
              onTap: () => Navigator.pop(ctx, "skip"),
            ),
            if (!isCourse) ...[
              const SizedBox(height: 4),
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                title: const Text("Delete all occurrences"),
                subtitle: const Text("Remove from every week"),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: Colors.transparent,
                onTap: () => Navigator.pop(ctx, "all"),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ]),
        )),
      );

      if (choice == null || !mounted) return;

      if (choice == "skip") {
        // Add date to exceptions list
        final exceptions = List<String>.from(event["exceptions"] ?? []);
        exceptions.add(dateStr);
        event["exceptions"] = exceptions;
        final docId = event["id"];
        if (docId != null) await StorageService.updateScheduleItem(docId, {"exceptions": exceptions});
        setState(() {});
        _filterEventsForSelectedDay();
      } else if (choice == "all") {
        final docId = event["id"];
        if (docId != null) await StorageService.deleteScheduleItem(docId);
        setState(() { allSchedule.remove(event); });
        _filterEventsForSelectedDay();
      }
    } else {
      // One-time event: simple delete
      final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Event"),
        content: Text("Delete \"${event["title"] ?? event["name"] ?? ""}\"?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete")),
        ],
      ));
      if (confirm != true || !mounted) return;
      final docId = event["id"];
      if (docId != null) await StorageService.deleteScheduleItem(docId);
      setState(() { allSchedule.remove(event); });
      _filterEventsForSelectedDay();
    }
  }

  // =================== ADD EVENT DIALOG ===================
  void _showAddEventDialog() {
    _addEventTitleCtrl.clear();
    _addEventStartCtrl.clear();
    _addEventEndCtrl.clear();
    DateTime eventDate = selectedDate;
    String repeatMode = "once"; // "once" or "weekly"

    String _formatEventDate(DateTime date) {
      const dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
      const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
      return "${dayNames[date.weekday - 1]}, ${date.day} ${monthNames[date.month - 1]}";
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final fillColor = isDark ? Colors.grey.shade800 : Colors.grey.shade50;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Add Event"),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: _addEventTitleCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "Event name...",
                    filled: true, fillColor: fillColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                // Date picker
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: eventDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setDialogState(() => eventDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.deepPurple.shade200)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.deepPurple),
                      const SizedBox(width: 10),
                      Text(_formatEventDate(eventDate), style: const TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                // Repeat toggle
                GestureDetector(
                  onTap: () {
                    setDialogState(() => repeatMode = repeatMode == "once" ? "weekly" : "once");
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: repeatMode == "weekly" ? Colors.deepPurple.shade200 : Colors.grey.shade200)),
                    child: Row(children: [
                      Icon(Icons.repeat_rounded, size: 16, color: repeatMode == "weekly" ? Colors.deepPurple : Colors.grey),
                      const SizedBox(width: 10),
                      Text(repeatMode == "weekly" ? "Repeats every week" : "Once (this date only)", style: TextStyle(fontWeight: FontWeight.w600, color: repeatMode == "weekly" ? Colors.deepPurple : Colors.grey.shade700)),
                      const Spacer(),
                      Icon(repeatMode == "weekly" ? Icons.check_circle : Icons.circle_outlined, size: 20, color: repeatMode == "weekly" ? Colors.deepPurple : Colors.grey.shade400),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                // Start → End time text boxes (same as courses)
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _addEventStartCtrl,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText: "Start",
                        hintText: "09:00",
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: fillColor,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _addEventEndCtrl,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText: "End",
                        hintText: "10:30",
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: fillColor,
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  final startStr = _addEventStartCtrl.text.trim();
                  final endStr = _addEventEndCtrl.text.trim();
                  if (_addEventTitleCtrl.text.trim().isEmpty || startStr.isEmpty || endStr.isEmpty) return;
                  try { _parseTime(startStr); _parseTime(endStr); } catch (_) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid time — use format like 09:00")));
                    return;
                  }
                  final dayName = _getDayName(eventDate.weekday);
                  if (_hasTimeOverlap(dayName, startStr, endStr)) {
                  final proceed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text("Time Conflict"),
                      content: const Text("This event overlaps with another item in your schedule. Add anyway?"),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text("Add Anyway"),
                        ),
                      ],
                    ),
                  );
                  if (proceed != true) return;
                }
                final dateStr = "${eventDate.year}-${eventDate.month.toString().padLeft(2, '0')}-${eventDate.day.toString().padLeft(2, '0')}";
                final newItem = <String, dynamic>{
                  "title": _addEventTitleCtrl.text.trim(),
                  "type": "Activity",
                  "day": _getDayName(eventDate.weekday),
                  "start": startStr,
                  "end": endStr,
                  "repeat": repeatMode,
                  "date": dateStr,
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
        );   // end AlertDialog
        }    // end StatefulBuilder block
      ),     // end StatefulBuilder
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayName = _getDayName(selectedDate.weekday);
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: "calendar_fab",
        backgroundColor: Colors.deepPurple,
        onPressed: _showAddEventDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.deepPurple.shade50, borderRadius: BorderRadius.circular(20)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: viewMode, isDense: true,
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
                  if (viewMode == "Day") ...[
                    IconButton(onPressed: _goToPreviousDay, icon: const Icon(Icons.chevron_left_rounded), iconSize: 24, color: Colors.grey.shade700),
                    Expanded(
                      child: GestureDetector(
                        onTap: _isToday ? null : _goToToday,
                        child: Column(children: [
                          Text(dayName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _isToday ? Colors.deepPurple : Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: _isToday ? Colors.deepPurple : Colors.transparent),
                            child: Center(child: Text("${selectedDate.day}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _isToday ? Colors.white : Theme.of(context).colorScheme.onSurface))),
                          ),
                          Text("${months[selectedDate.month - 1]} ${selectedDate.year}", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ]),
                      ),
                    ),
                    IconButton(onPressed: _goToNextDay, icon: const Icon(Icons.chevron_right_rounded), iconSize: 24, color: Colors.grey.shade700),
                  ] else ...[
                    IconButton(onPressed: _goToPreviousWeek, icon: const Icon(Icons.chevron_left_rounded), iconSize: 24, color: Colors.grey.shade700),
                    Expanded(child: Center(child: Text(_getWeekRangeLabel(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.deepPurple)))),
                    IconButton(onPressed: _goToNextWeek, icon: const Icon(Icons.chevron_right_rounded), iconSize: 24, color: Colors.grey.shade700),
                  ],
                  GestureDetector(
                    onTap: _showStartHourPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.schedule_rounded, size: 13, color: Colors.deepPurple.shade300),
                        const SizedBox(width: 4),
                        Text("${startHour.toString().padLeft(2, '0')}:00", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.deepPurple.shade400)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            if (viewMode == "Day" && !_isToday)
              TextButton.icon(onPressed: _goToToday, icon: const Icon(Icons.today, size: 14), label: const Text("Today", style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: Colors.deepPurple, padding: EdgeInsets.zero, minimumSize: const Size(0, 30))),
            const SizedBox(height: 4),
            // Deadline banners at top (like Google Calendar all-day events)
            if (viewMode == "Day" && dayDeadlines.isNotEmpty)
              _buildDeadlineBanners(),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : viewMode == "Day"
                      ? (dayEvents.isEmpty && dayDeadlines.isEmpty ? _buildEmptyState() : _buildDayTimeline())
                      : _buildWeekView(),
            ),
          ],
        ),
      ),
    );
  }

  // =================== DEADLINE BANNERS ===================
  Widget _buildDeadlineBanners() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: dayDeadlines.map((deadline) {
          final title = deadline["title"] ?? "Untitled";
          final type = deadline["type"] ?? "";
          final color = type == "Exam" ? Colors.red : type == "Quiz" ? Colors.blue : Colors.orange;
          return GestureDetector(
            onTap: () => _showDeadlineEditSheet(deadline),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border(left: BorderSide(color: color, width: 3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.assignment_late_rounded, size: 14, color: color),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  // =================== DEADLINE EDIT BOTTOM SHEET ===================
  void _showDeadlineEditSheet(Map<String, dynamic> deadline) {
    final title = deadline["title"] ?? "Untitled";
    final date = deadline["date"] ?? "";
    final course = deadline["course"] ?? "";
    final type = deadline["type"] ?? "";
    final typeColor = type == "Exam" ? Colors.red : type == "Quiz" ? Colors.blue : Colors.orange;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(children: [
              Icon(Icons.assignment_late_rounded, size: 18, color: typeColor),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerLeft, child: Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text("$date${course.isNotEmpty ? '  •  $course' : ''}${type.isNotEmpty ? '  •  $type' : ''}", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            )),
            const SizedBox(height: 20),
            _editOption(Icons.edit_rounded, "Edit name", () {
              Navigator.pop(ctx);
              _editDeadlineName(deadline);
            }),
            _editOption(Icons.event_rounded, "Change date", () {
              Navigator.pop(ctx);
              _editDeadlineDate(deadline);
            }),
            _editOption(Icons.delete_rounded, "Delete", () {
              Navigator.pop(ctx);
              _deleteDeadline(deadline);
            }, color: Colors.red),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  void _editDeadlineName(Map<String, dynamic> deadline) {
    final controller = TextEditingController(text: deadline["title"] ?? "");
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("Edit Deadline Name"),
      content: TextField(controller: controller, autofocus: true,
        decoration: InputDecoration(filled: true, fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () async {
            if (controller.text.trim().isEmpty) return;
            deadline["title"] = controller.text.trim();
            final docId = deadline["id"];
            if (docId != null) await StorageService.updateDeadline(docId, {"title": deadline["title"]});
            Navigator.pop(ctx);
            setState(() {});
          },
          child: const Text("Save"),
        ),
      ],
    ));
  }

  void _editDeadlineDate(Map<String, dynamic> deadline) async {
    final currentDate = _parseDeadlineDate(deadline["date"]?.toString()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context, initialDate: currentDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2030),
    );
    if (picked == null || !mounted) return;
    final newDate = "${picked.day}/${picked.month}/${picked.year}";
    deadline["date"] = newDate;
    final docId = deadline["id"];
    if (docId != null) await StorageService.updateDeadline(docId, {"date": newDate});
    setState(() {});
    _filterEventsForSelectedDay();
  }

  void _deleteDeadline(Map<String, dynamic> deadline) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("Delete Deadline"),
      content: Text("Delete \"${deadline["title"] ?? ""}\"?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete")),
      ],
    ));
    if (confirm != true || !mounted) return;
    final docId = deadline["id"];
    if (docId != null) await StorageService.deleteDeadline(docId);
    setState(() { allDeadlines.remove(deadline); });
    _filterEventsForSelectedDay();
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.event_busy_rounded, size: 56, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text("No events for this day", style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
      const SizedBox(height: 8),
      Text("Tap + to add an event", style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
    ]));
  }

  // =================== OVERLAP LAYOUT ===================
  // Assigns each event a column so overlapping events are shown side by side.
  List<({Map<String, dynamic> event, int column, int totalColumns})> _computeEventLayout(List<Map<String, dynamic>> events) {
    if (events.isEmpty) return [];

    final laneEnds = <int>[]; // end-minute of last event placed in each lane
    final cols = <int>[];

    for (final event in events) {
      final (sH, sM) = _parseTime(event["start"]!);
      final (eH, eM) = _parseTime(event["end"]!);
      final startMin = sH * 60 + sM;
      final endMin = eH * 60 + eM;

      int lane = -1;
      for (int j = 0; j < laneEnds.length; j++) {
        if (laneEnds[j] <= startMin) { lane = j; laneEnds[j] = endMin; break; }
      }
      if (lane == -1) { lane = laneEnds.length; laneEnds.add(endMin); }
      cols.add(lane);
    }

    return List.generate(events.length, (i) {
      final (sH, sM) = _parseTime(events[i]["start"]!);
      final (eH, eM) = _parseTime(events[i]["end"]!);
      final startMin = sH * 60 + sM;
      final endMin = eH * 60 + eM;

      int maxCol = cols[i];
      for (int j = 0; j < events.length; j++) {
        if (j == i) continue;
        final (jsH, jsM) = _parseTime(events[j]["start"]!);
        final (jeH, jeM) = _parseTime(events[j]["end"]!);
        final jStart = jsH * 60 + jsM;
        final jEnd = jeH * 60 + jeM;
        if (jStart < endMin && jEnd > startMin && cols[j] > maxCol) maxCol = cols[j];
      }
      return (event: events[i], column: cols[i], totalColumns: maxCol + 1);
    });
  }

  bool _hasTimeOverlap(String dayName, String startStr, String endStr) {
    final (sH, sM) = _parseTime(startStr);
    final (eH, eM) = _parseTime(endStr);
    final newStart = sH * 60 + sM;
    final newEnd = eH * 60 + eM;
    return allSchedule.any((item) {
      if (item["day"] != dayName || item["start"] == null || item["end"] == null) return false;
      final (iH, iM) = _parseTime(item["start"]!);
      final (jH, jM) = _parseTime(item["end"]!);
      final itemStart = iH * 60 + iM;
      final itemEnd = jH * 60 + jM;
      return !(newEnd <= itemStart || newStart >= itemEnd);
    });
  }

  // =================== DAY VIEW ===================
  Widget _buildDayTimeline() {
    final now = DateTime.now();
    final currentMinutes = (now.hour - startHour) * 60 + now.minute;
    final currentTimeTop = currentMinutes * (hourHeight / 60);
    final eventLayouts = _computeEventLayout(dayEvents);

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 40),
      child: SizedBox(height: totalHeight + 16, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Time labels
        SizedBox(width: timeColumnWidth, height: totalHeight + 16, child: Stack(children: List.generate(totalHours, (i) {
          final hour = startHour + i + 1;
          if (hour >= endHour || hour <= startHour) return const SizedBox.shrink();
          return Positioned(top: (i + 1) * hourHeight - 7, left: 0, right: 0,
            child: Text("${hour.toString().padLeft(2, '0')}:00", style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w500), textAlign: TextAlign.center));
        }))),
        // Events area
        Expanded(child: LayoutBuilder(builder: (context, constraints) {
          final availWidth = constraints.maxWidth;
          return SizedBox(height: totalHeight, child: Stack(children: [
            // Hour lines (solid) + half-hour lines (dashed/lighter)
            ...List.generate(totalHours, (i) => [
              Positioned(top: i * hourHeight, left: 0, right: 0, child: Container(height: 1, color: Colors.grey.shade300)),
              Positioned(top: i * hourHeight + hourHeight / 2, left: 0, right: 0, child: Container(height: 0.5, color: Colors.grey.shade200)),
            ]).expand((x) => x),
            Positioned(top: totalHours * hourHeight, left: 0, right: 0, child: Container(height: 1, color: Colors.grey.shade300)),
            // Event blocks with side-by-side overlap layout
            ...eventLayouts.map((layout) {
              final event = layout.event;
              final (sH, sM) = _parseTime(event["start"]!);
              final (eH, eM) = _parseTime(event["end"]!);
              final sMins = (sH - startHour) * 60 + sM;
              final dur = (eH * 60 + eM) - (sH * 60 + sM);
              final top = sMins * (hourHeight / 60);
              final h = dur * (hourHeight / 60);
              final color = Color(event["color"] ?? Colors.deepPurple.toARGB32());
              final colWidth = (availWidth - 8) / layout.totalColumns;
              final left = 4.0 + layout.column * colWidth;
              return Positioned(top: top, left: left, width: colWidth - 3, child: GestureDetector(
                onTap: () => _showEventEditSheet(event),
                child: Container(
                  height: h < 32 ? 32 : h, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(event["title"] ?? event["name"] ?? "", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (h > 45) Text("${event["start"]} — ${event["end"]}", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  ]),
                ),
              ));
            }),
            // Red current time line (only today)
            if (_isToday && currentMinutes >= 0 && currentMinutes <= totalHours * 60)
              Positioned(top: currentTimeTop, left: 0, right: 0, child: Row(children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                Expanded(child: Container(height: 1.5, color: Colors.red)),
              ])),
          ]));
        })),
      ])),
    );
  }

  // =================== WEEK VIEW ===================
  Widget _buildWeekView() {
    const double weekHourHeight = 50.0;
    const double headerHeight = 50.0;
    final now = DateTime.now();

    // Calculate dates for each day of the week
    final weekStart = _weekStart;
    final weekDates = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    // Find deadlines for each day
    List<Map<String, dynamic>> _deadlinesForDate(DateTime date) {
      return allDeadlines.where((d) {
        final dDate = _parseDeadlineDate(d["date"]?.toString());
        if (dDate == null) return false;
        return dDate.year == date.year && dDate.month == date.month && dDate.day == date.day;
      }).toList();
    }

    return Column(children: [
      // Day headers with deadline dots (FIXED / STICKY)
      Row(children: [
        SizedBox(width: timeColumnWidth, height: headerHeight),
        ...List.generate(7, (i) {
          final date = weekDates[i];
          final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
          final dayDeadlinesForThis = _deadlinesForDate(date);
          final hasDeadline = dayDeadlinesForThis.isNotEmpty;
          return Expanded(child: Container(
            height: headerHeight,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade400, width: 1),
                left: i > 0 ? BorderSide(color: Colors.grey.shade400, width: 1) : BorderSide.none,
              ),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(weekDays[i], style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isToday ? Colors.deepPurple : Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday ? Colors.deepPurple : Colors.transparent,
                ),
                child: Center(child: Text("${date.day}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isToday ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.6)))),
              ),
              if (hasDeadline)
                Container(margin: const EdgeInsets.only(top: 2), width: 6, height: 6, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
            ]),
          ));
        }),
      ]),
      // Deadline banners row for the week (FIXED / STICKY)
      if (allDeadlines.any((d) {
        final dDate = _parseDeadlineDate(d["date"]?.toString());
        if (dDate == null) return false;
        return weekDates.any((wd) => wd.year == dDate.year && wd.month == dDate.month && wd.day == dDate.day);
      }))
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade400, width: 1))),
          child: Row(children: [
            SizedBox(width: timeColumnWidth),
            ...List.generate(7, (i) {
              final dayDl = _deadlinesForDate(weekDates[i]);
              if (dayDl.isEmpty) return const Expanded(child: SizedBox());
              return Expanded(child: Column(children: dayDl.take(2).map((dl) {
                final type = dl["type"] ?? "";
                final color = type == "Exam" ? Colors.red : type == "Quiz" ? Colors.blue : Colors.orange;
                return GestureDetector(
                  onTap: () => _showDeadlineEditSheet(dl),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                    child: Text(dl["title"] ?? "", style: TextStyle(fontSize: 7, fontWeight: FontWeight.w600, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                );
              }).toList()));
            }),
          ]),
        ),
      // Scrollable time grid
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 20),
        child: SizedBox(
          height: totalHours * weekHourHeight,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: timeColumnWidth, height: totalHours * weekHourHeight,
              child: Stack(children: List.generate(totalHours + 1, (i) {
                final hour = startHour + i;
                if (hour <= startHour || hour >= endHour) return const Positioned(top: 0, child: SizedBox.shrink());
                return Positioned(top: i * weekHourHeight - 7, left: 0, right: 0,
                  child: Text("${hour.toString().padLeft(2, '0')}:00", style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.w600), textAlign: TextAlign.center));
              }))),
            ...List.generate(7, (dayIndex) {
              final dayFullName = fullDayNames[dayIndex];
              final date = weekDates[dayIndex];
              final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
              final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
              final daySchedule = allSchedule.where((item) {
                if (item["day"] != dayFullName || item["start"] == null || item["end"] == null) return false;
                final exceptions = item["exceptions"];
                if (exceptions is List && exceptions.contains(dateStr)) return false;
                final repeat = item["repeat"] ?? "weekly";
                if (repeat == "once") {
                  final eventDate = item["date"];
                  if (eventDate != null && eventDate != dateStr) return false;
                }
                return true;
              }).toList();

              return Expanded(child: Container(
                height: totalHours * weekHourHeight,
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: Colors.grey.shade400, width: 1)),
                ),
                child: Stack(children: [
                  ...List.generate(totalHours, (i) => [
                    Positioned(top: i * weekHourHeight, left: 0, right: 0, child: Container(height: 1, color: Colors.grey.shade300)),
                    Positioned(top: i * weekHourHeight + weekHourHeight / 2, left: 0, right: 0, child: Container(height: 0.5, color: Colors.grey.shade200)),
                  ]).expand((x) => x),
                  Positioned(top: totalHours * weekHourHeight, left: 0, right: 0, child: Container(height: 1, color: Colors.grey.shade300)),
                  ...daySchedule.map((event) {
                    final (sH, sM) = _parseTime(event["start"]!);
                    final (eH, eM) = _parseTime(event["end"]!);
                    final sMins = (sH - startHour) * 60 + sM;
                    final dur = (eH * 60 + eM) - (sH * 60 + sM);
                    final top = sMins * (weekHourHeight / 60);
                    final h = dur * (weekHourHeight / 60);
                    final color = Color(event["color"] ?? Colors.deepPurple.toARGB32());
                    return Positioned(top: top, left: 1, right: 1, child: GestureDetector(
                      onTap: () => _showEventEditSheet(event),
                      child: Container(
                        height: h < 18 ? 18 : h, padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                        child: Text(event["title"] ?? event["name"] ?? "", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ));
                  }),
                  if (isToday) Positioned(
                    top: ((now.hour - startHour) * 60 + now.minute) * (weekHourHeight / 60),
                    left: 0, right: 0, child: Container(height: 1.5, color: Colors.red),
                  ),
                ]),
              ));
            }),
          ]),
        ),
      )),
    ]);
  }
}
