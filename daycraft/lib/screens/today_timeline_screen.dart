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

  String viewMode = "Day";
  DateTime selectedDate = DateTime.now();

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
    setState(() { allSchedule = loaded; });
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
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: color ?? Colors.black87)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        decoration: InputDecoration(filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
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
              // Time picker — single tap chains start → end
              GestureDetector(
                onTap: () async {
                  final pickedStart = await showTimePicker(context: context, initialTime: startTime ?? const TimeOfDay(hour: 8, minute: 0), initialEntryMode: TimePickerEntryMode.inputOnly, helpText: "START TIME");
                  if (pickedStart == null) return;
                  setDialogState(() => startTime = pickedStart);
                  final pickedEnd = await showTimePicker(context: context, initialTime: endTime ?? pickedStart, initialEntryMode: TimePickerEntryMode.inputOnly, helpText: "END TIME");
                  if (pickedEnd != null) setDialogState(() => endTime = pickedEnd);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: (startTime != null && endTime != null) ? Colors.deepPurple.shade200 : Colors.grey.shade200)),
                  child: Row(children: [
                    Icon(Icons.schedule_rounded, size: 18, color: startTime != null ? Colors.deepPurple : Colors.grey),
                    const SizedBox(width: 10),
                    Text(
                      startTime != null && endTime != null
                          ? "${startTime!.format(context)}  →  ${endTime!.format(context)}"
                          : startTime != null
                              ? "${startTime!.format(context)}  →  End?"
                              : "Set time...",
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: startTime != null ? Colors.black87 : Colors.grey),
                    ),
                  ]),
                ),
              ),
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
                          Text(dayName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _isToday ? Colors.deepPurple : Colors.grey.shade700)),
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: _isToday ? Colors.deepPurple : Colors.transparent),
                            child: Center(child: Text("${selectedDate.day}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _isToday ? Colors.white : Colors.grey.shade800))),
                          ),
                          Text("${months[selectedDate.month - 1]} ${selectedDate.year}", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ]),
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
      const SizedBox(height: 8),
      Text("Tap + to add an event", style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
    ]));
  }

  // =================== DAY VIEW ===================
  Widget _buildDayTimeline() {
    final now = DateTime.now();
    final currentMinutes = (now.hour - startHour) * 60 + now.minute;
    final currentTimeTop = currentMinutes * (hourHeight / 60);

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 40),
      child: SizedBox(height: totalHeight + 16, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Time labels
        SizedBox(width: timeColumnWidth, height: totalHeight + 16, child: Stack(children: List.generate(totalHours, (i) {
          final hour = startHour + i + 1;
          if (hour >= endHour) return const SizedBox.shrink();
          return Positioned(top: (i + 1) * hourHeight - 7, left: 0, right: 0,
            child: Text("${hour.toString().padLeft(2, '0')}:00", style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w500), textAlign: TextAlign.center));
        }))),
        // Events area
        Expanded(child: SizedBox(height: totalHeight, child: Stack(children: [
          // Grid lines
          ...List.generate(totalHours + 1, (i) => Positioned(top: i * hourHeight, left: 0, right: 0, child: Container(height: 0.5, color: Colors.grey.shade200))),
          // Event blocks
          ...dayEvents.map((event) {
            final (sH, sM) = _parseTime(event["start"]!);
            final (eH, eM) = _parseTime(event["end"]!);
            final sMins = (sH - startHour) * 60 + sM;
            final dur = (eH * 60 + eM) - (sH * 60 + sM);
            final top = sMins * (hourHeight / 60);
            final h = dur * (hourHeight / 60);
            final color = Color(event["color"] ?? Colors.deepPurple.toARGB32());
            return Positioned(top: top, left: 4, right: 4, child: GestureDetector(
              onTap: () => _showEventEditSheet(event),
              child: Container(
                height: h < 32 ? 32 : h, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(event["title"] ?? event["name"] ?? "", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
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
        ]))),
      ])),
    );
  }

  // =================== WEEK VIEW ===================
  Widget _buildWeekView() {
    const double weekHourHeight = 50.0;
    const double headerHeight = 36.0;
    final now = DateTime.now();
    final todayWeekday = now.weekday;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(children: [
        Row(children: [
          SizedBox(width: timeColumnWidth, height: headerHeight),
          ...List.generate(7, (i) {
            final dartWeekday = i == 0 ? 7 : i;
            final isToday = dartWeekday == todayWeekday;
            return Expanded(child: Container(
              height: headerHeight,
              decoration: BoxDecoration(
                color: isToday ? Colors.deepPurple.withValues(alpha: 0.1) : Colors.transparent,
                border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 0.5)),
              ),
              child: Center(child: Text(weekDays[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isToday ? Colors.deepPurple : Colors.grey.shade600))),
            ));
          }),
        ]),
        SizedBox(
          height: totalHours * weekHourHeight,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: timeColumnWidth, height: totalHours * weekHourHeight,
              child: Stack(children: List.generate(totalHours + 1, (i) {
                return Positioned(top: i * weekHourHeight - 7, left: 0, right: 0,
                  child: Text("${(startHour + i).toString().padLeft(2, '0')}:00", style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.w600), textAlign: TextAlign.center));
              }))),
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
                  ...List.generate(totalHours + 1, (i) => Positioned(top: i * weekHourHeight, left: 0, right: 0, child: Container(height: 0.5, color: Colors.grey.shade200))),
                  ...daySchedule.map((event) {
                    final (sH, sM) = _parseTime(event["start"]!);
                    final (eH, eM) = _parseTime(event["end"]!);
                    final sMins = (sH - startHour) * 60 + sM;
                    final dur = (eH * 60 + eM) - (sH * 60 + sM);
                    final top = sMins * (weekHourHeight / 60);
                    final h = dur * (weekHourHeight / 60);
                    final color = Color(event["color"] ?? Colors.deepPurple.toARGB32());
                    return Positioned(top: top, left: 1, right: 1, child: Container(
                      height: h < 18 ? 18 : h, padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                      child: Text(event["title"] ?? event["name"] ?? "", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
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
      ]),
    );
  }
}
