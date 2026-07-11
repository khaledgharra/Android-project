import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<Map<String, dynamic>> schedule = [];

  String currentViewDay = "Sunday";
  late DateTime _currentWeekSunday;

  double _hourHeight = 60.0;
  double _scaleStartHeight = 60.0;

  final TextEditingController titleController = TextEditingController();
  final TextEditingController _startTimeCtrl = TextEditingController();
  final TextEditingController _endTimeCtrl = TextEditingController();

  String selectedDay = "Sunday";
  String selectedType = "Activity";
  String _selectedRecurrence = 'Once'; // 'Once' or 'Weekly'

  final List<String> days = [
    "Sunday",
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
  ];

  @override
  void initState() {
    super.initState();
    _currentWeekSunday = _weekSunday(DateTime.now());
    currentViewDay = days[DateTime.now().weekday % 7];
    loadSchedule();
  }

  static DateTime _weekSunday(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday % 7));
  }

  DateTime get _currentViewDate =>
      _currentWeekSunday.add(Duration(days: days.indexOf(currentViewDay)));

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _weekLabel() {
    final end = _currentWeekSunday.add(const Duration(days: 6));
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    if (_currentWeekSunday.month == end.month) {
      return '${m[_currentWeekSunday.month - 1]} ${_currentWeekSunday.day}–${end.day}';
    }
    return '${m[_currentWeekSunday.month - 1]} ${_currentWeekSunday.day} – ${m[end.month - 1]} ${end.day}';
  }

  @override
  void dispose() {
    titleController.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    super.dispose();
  }

  Future<void> loadSchedule() async {
    final loaded = await StorageService.loadSchedule();
    if (!mounted) return;
    setState(() {
      schedule = loaded;
    });
  }

  (int, int) _parseTimeToHourMinute(String time) {
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

  Future<void> addSchedule() async {
    final startStr = _startTimeCtrl.text.trim();
    final endStr = _endTimeCtrl.text.trim();

    if (titleController.text.isEmpty || startStr.isEmpty || endStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in title, start time, and end time")),
      );
      return;
    }

    int newStart, newEnd;
    try {
      final (sh, sm) = _parseTimeToHourMinute(startStr);
      final (eh, em) = _parseTimeToHourMinute(endStr);
      newStart = sh * 60 + sm;
      newEnd = eh * 60 + em;
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid time — use 24h format like 14:00")),
      );
      return;
    }

    if (newEnd <= newStart) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("End time must be after start time")),
      );
      return;
    }

    final overlapping = schedule.any((item) {
      if (item["day"] != selectedDay || item["start"] == null || item["end"] == null) return false;
      final (existingStartHour, existingStartMin) = _parseTimeToHourMinute(item["start"]);
      final (existingEndHour, existingEndMin) = _parseTimeToHourMinute(item["end"]);
      final existingStart = existingStartHour * 60 + existingStartMin;
      final existingEnd = existingEndHour * 60 + existingEndMin;
      return !(newEnd <= existingStart || newStart >= existingEnd);
    });

    if (overlapping) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This activity overlaps with another schedule item")),
      );
      return;
    }

    final newItem = <String, dynamic>{
      "title": titleController.text,
      "type": selectedType,
      "day": selectedDay,
      "start": startStr,
      "end": endStr,
      if (_selectedRecurrence == 'Once')
        "date": _fmtDate(_currentWeekSunday.add(Duration(days: days.indexOf(selectedDay)))),
    };

    final docId = await StorageService.addScheduleItem(newItem);
    if (docId != null) newItem['id'] = docId;

    if (!mounted) return;
    setState(() => schedule.add(newItem));

    titleController.clear();
    _startTimeCtrl.clear();
    _endTimeCtrl.clear();
    Navigator.pop(context);
  }

  void showAddDialog() {
    titleController.clear();
    _startTimeCtrl.clear();
    _endTimeCtrl.clear();
    selectedType = "Activity";
    selectedDay = currentViewDay;
    _selectedRecurrence = 'Once';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final fillColor = isDark ? Colors.grey.shade700 : Colors.white;

            Widget _chip({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
              return GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 13, color: color),
                      const SizedBox(width: 4),
                      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                      const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              );
            }

            IconData _typeIcon(String t) => t == 'Course' ? Icons.cast_for_education_rounded : Icons.directions_run_rounded;
            Color _typeColor(String t) => t == 'Course' ? Colors.deepPurple : Colors.teal;

            return Padding(
              padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text("Add Event", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: "Lecture / Gym / Study...",
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: fillColor,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _chip(
                        label: selectedType,
                        icon: _typeIcon(selectedType),
                        color: _typeColor(selectedType),
                        onTap: () async {
                          FocusScope.of(ctx).unfocus();
                          final picked = await showModalBottomSheet<String>(
                            context: ctx,
                            builder: (c) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Padding(padding: EdgeInsets.all(14), child: Text("Type", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                  for (final t in ['Course', 'Activity'])
                                    ListTile(leading: Icon(_typeIcon(t), color: _typeColor(t)), title: Text(t), onTap: () => Navigator.pop(c, t)),
                                ],
                              ),
                            ),
                          );
                          if (picked != null) setSheetState(() => selectedType = picked);
                        },
                      ),
                      const SizedBox(width: 8),
                      _chip(
                        label: selectedDay,
                        icon: Icons.calendar_today_rounded,
                        color: Colors.grey.shade600,
                        onTap: () async {
                          FocusScope.of(ctx).unfocus();
                          final picked = await showModalBottomSheet<String>(
                            context: ctx,
                            builder: (c) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Padding(padding: EdgeInsets.all(14), child: Text("Day", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                  ...days.map((d) => ListTile(title: Text(d), onTap: () => Navigator.pop(c, d))),
                                ],
                              ),
                            ),
                          );
                          if (picked != null) setSheetState(() => selectedDay = picked);
                        },
                      ),
                      const SizedBox(width: 8),
                      _chip(
                        label: _selectedRecurrence,
                        icon: _selectedRecurrence == 'Weekly' ? Icons.repeat_rounded : Icons.looks_one_rounded,
                        color: _selectedRecurrence == 'Weekly' ? Colors.indigo : Colors.teal,
                        onTap: () async {
                          FocusScope.of(ctx).unfocus();
                          final picked = await showModalBottomSheet<String>(
                            context: ctx,
                            builder: (c) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Padding(padding: EdgeInsets.all(14), child: Text("Recurrence", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                  ListTile(leading: const Icon(Icons.repeat_rounded, color: Colors.indigo), title: const Text('Weekly'), subtitle: const Text('Repeats every week on this day'), onTap: () => Navigator.pop(c, 'Weekly')),
                                  ListTile(leading: const Icon(Icons.looks_one_rounded, color: Colors.teal), title: const Text('Once'), subtitle: const Text('One time only on this date'), onTap: () => Navigator.pop(c, 'Once')),
                                ],
                              ),
                            ),
                          );
                          if (picked != null) setSheetState(() => _selectedRecurrence = picked);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _startTimeCtrl,
                          decoration: InputDecoration(labelText: "Start", hintText: "09:00", isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: fillColor),
                        ),
                      ),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey)),
                      Expanded(
                        child: TextField(
                          controller: _endTimeCtrl,
                          decoration: InputDecoration(labelText: "End", hintText: "10:30", isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: fillColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async => await addSchedule(),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: const Text("Add Event", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> getFilteredSchedule() {
    final viewDateStr = _fmtDate(_currentViewDate);
    List<Map<String, dynamic>> filtered = schedule.where((item) {
      if (item["day"] == null || item["start"] == null || item["end"] == null) return false;
      if (item["day"] != currentViewDay) return false;
      final itemDate = item["date"]?.toString();
      if (itemDate != null && itemDate.isNotEmpty) return itemDate == viewDateStr;
      final semEnd = StorageService.currentSemesterEndDate;
      if (semEnd != null) {
        final viewDay = DateTime(_currentViewDate.year, _currentViewDate.month, _currentViewDate.day);
        final endDay = DateTime(semEnd.year, semEnd.month, semEnd.day);
        if (viewDay.isAfter(endDay)) return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      final (aHour, aMin) = _parseTimeToHourMinute(a["start"]!);
      final (bHour, bMin) = _parseTimeToHourMinute(b["start"]!);
      return (aHour * 60 + aMin).compareTo(bHour * 60 + bMin);
    });

    return filtered;
  }

  DateTime parseTime(String time) {
    final cleaned = time.trim().toUpperCase();
    final parts = cleaned.split(' ');
    final timePart = parts[0];
    String? period = parts.length > 1 ? parts[1] : null;

    final hm = timePart.split(':');
    int hour = int.parse(hm[0]);
    int minute = hm.length > 1 ? int.parse(hm[1]) : 0;

    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;

    return DateTime(2025, 1, 1, hour, minute);
  }

  @override
  Widget build(BuildContext context) {
    const int startHour = 0;
    const int endHour = 24;
    const int totalHours = endHour - startHour;
    final double totalHeight = totalHours * _hourHeight;
    const double timeColumnWidth = 50.0;

    final filtered = getFilteredSchedule();

    return Scaffold(
      appBar: AppBar(title: const Text("Weekly Schedule")),
      floatingActionButton: FloatingActionButton(heroTag: "schedule_fab", onPressed: showAddDialog, child: const Icon(Icons.add)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.chevron_left), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, onPressed: () => setState(() => _currentWeekSunday = _currentWeekSunday.subtract(const Duration(days: 7)))),
                Expanded(child: Center(child: Text(_weekLabel(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)))),
                IconButton(icon: const Icon(Icons.chevron_right), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, onPressed: () => setState(() => _currentWeekSunday = _currentWeekSunday.add(const Duration(days: 7)))),
              ],
            ),
          ),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day = days[index];
                final selected = day == currentViewDay;
                final chipDate = _currentWeekSunday.add(Duration(days: index));
                final isToday = _fmtDate(chipDate) == _fmtDate(DateTime.now());

                return GestureDetector(
                  onTap: () => setState(() => currentViewDay = day),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? Colors.deepPurple : (isToday ? Colors.deepPurple.shade50 : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(20),
                      border: isToday && !selected ? Border.all(color: Colors.deepPurple.shade200) : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(day.substring(0, 3), style: TextStyle(color: selected ? Colors.white : (isToday ? Colors.deepPurple : Colors.black), fontWeight: selected || isToday ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
                        Text('${chipDate.day}', style: TextStyle(color: selected ? Colors.white70 : Colors.grey.shade500, fontSize: 11)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: GestureDetector(
              onScaleStart: (_) => _scaleStartHeight = _hourHeight,
              onScaleUpdate: (d) {
                if (d.pointerCount >= 2) {
                  setState(() => _hourHeight = (_scaleStartHeight * d.scale).clamp(30.0, 200.0));
                }
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 20),
                child: SizedBox(
                  height: totalHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: timeColumnWidth,
                        height: totalHeight,
                        child: Stack(
                          children: List.generate(totalHours + 1, (index) {
                            final hour = startHour + index;
                            return Positioned(
                              top: index * _hourHeight - 8,
                              left: 0, right: 0,
                              child: Text("${hour.toString().padLeft(2, '0')}:00", style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                            );
                          }),
                        ),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: totalHeight,
                          child: Stack(
                            children: [
                              ...List.generate(totalHours + 1, (index) {
                                return Positioned(top: index * _hourHeight, left: 0, right: 0, child: Container(height: 0.5, color: Colors.grey.shade300));
                              }),
                              ...filtered.map((event) {
                                final start = parseTime(event["start"]);
                                final end = parseTime(event["end"]);
                                final startMinutes = (start.hour - startHour) * 60 + start.minute;
                                final durationMinutes = end.difference(start).inMinutes;

                                final top = startMinutes * (_hourHeight / 60);
                                final height = durationMinutes * (_hourHeight / 60);

                                return Positioned(
                                  top: top, left: 4, right: 4,
                                  child: GestureDetector(
                                    onLongPress: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) {
                                          return AlertDialog(
                                            title: const Text("Delete Event"),
                                            content: Text("Delete ${event["title"]}?"),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                                              ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Delete")),
                                            ],
                                          );
                                        },
                                      );
                                      if (confirm != true) return;
                                      final docId = event['id'];
                                      if (docId != null) {
                                        await StorageService.deleteScheduleItem(docId);
                                      }
                                      if (!mounted) return;
                                      setState(() { schedule.remove(event); });
                                    },
                                    child: Container(
                                      height: height < 30 ? 30 : height,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: Color(event["color"] ?? Colors.deepPurple.value), borderRadius: BorderRadius.circular(12)),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(event["title"] ?? "", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          if (height > 40)
                                            Text("${event["start"]} - ${event["end"]}", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}