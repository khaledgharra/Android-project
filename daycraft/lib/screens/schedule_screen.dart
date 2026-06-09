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

  final TextEditingController titleController = TextEditingController();

  String selectedDay = "Sunday";
  String selectedType = "Activity";

  TimeOfDay? startTime;
  TimeOfDay? endTime;

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
    loadSchedule();
  }

  Future<void> loadSchedule() async {
    final loaded = await StorageService.loadSchedule();
    if (!mounted) return;
    setState(() {
      schedule = loaded;
    });
  }

  /// Parses a time string like "8:30 AM", "1:30 PM", or "13:30" into (hour, minute) in 24-hour format
  (int, int) _parseTimeToHourMinute(String time) {
    final cleaned = time.trim().toUpperCase();
    final isPM = cleaned.contains("PM");
    final isAM = cleaned.contains("AM");
    final withoutPeriod = cleaned
        .replaceAll("AM", "")
        .replaceAll("PM", "")
        .trim();
    final parts = withoutPeriod.split(":");
    int hour = int.parse(parts[0].trim());
    int minute = parts.length > 1 ? int.parse(parts[1].trim()) : 0;

    if (isPM && hour != 12) {
      hour += 12;
    }
    if (isAM && hour == 12) {
      hour = 0;
    }
    return (hour, minute);
  }

  Future<void> addSchedule() async {
    if (titleController.text.isEmpty || startTime == null || endTime == null) {
      return;
    }
    final newStart = startTime!.hour * 60 + startTime!.minute;
    final newEnd = endTime!.hour * 60 + endTime!.minute;

    final overlapping = schedule.any((item) {
      if (item["day"] != selectedDay) {
        return false;
      }

      if (item["start"] == null || item["end"] == null) {
        return false;
      }

      final (existingStartHour, existingStartMin) = _parseTimeToHourMinute(item["start"]);
      final (existingEndHour, existingEndMin) = _parseTimeToHourMinute(item["end"]);

      final existingStartMinutes = existingStartHour * 60 + existingStartMin;
      final existingEndMinutes = existingEndHour * 60 + existingEndMin;

      return !(newEnd <= existingStartMinutes || newStart >= existingEndMinutes);
    });

    if (overlapping) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This activity overlaps with another schedule item"),
        ),
      );
      return;
    }

    final newItem = {
      "title": titleController.text,
      "type": selectedType,
      "day": selectedDay,
      "start": startTime!.format(context),
      "end": endTime!.format(context),
    };

    // Add to Firestore and get the document ID
    final docId = await StorageService.addScheduleItem(newItem);
    if (docId != null) {
      newItem['id'] = docId;
    }

    if (!mounted) return;
    setState(() {
      schedule.add(newItem);
    });

    titleController.clear();
    Navigator.pop(context);
  }

  void showAddDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add Schedule"),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        hintText: "Lecture / Gym / Prayer...",
                      ),
                    ),
                    const SizedBox(height: 20),

                    DropdownButton<String>(
                      value: selectedType,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: "Course",
                          child: Text("Course"),
                        ),
                        DropdownMenuItem(
                          value: "Activity",
                          child: Text("Activity"),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedType = value!;
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    DropdownButton<String>(
                      value: selectedDay,
                      isExpanded: true,

                      items: days.map((day) {
                        return DropdownMenuItem(value: day, child: Text(day));
                      }).toList(),

                      onChanged: (value) {
                        setDialogState(() {
                          selectedDay = value!;
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),

                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            "Selected Day: $selectedDay",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),

                          const SizedBox(height: 16),

                          // Single tap chains start → end
                          GestureDetector(
                            onTap: () async {
                              final pickedStart = await showTimePicker(
                                context: context,
                                initialTime: startTime ?? const TimeOfDay(hour: 8, minute: 0),
                                initialEntryMode: TimePickerEntryMode.inputOnly,
                                helpText: "START TIME",
                              );
                              if (pickedStart == null) return;
                              setDialogState(() => startTime = pickedStart);
                              final pickedEnd = await showTimePicker(
                                context: context,
                                initialTime: endTime ?? pickedStart,
                                initialEntryMode: TimePickerEntryMode.inputOnly,
                                helpText: "END TIME",
                              );
                              if (pickedEnd != null) setDialogState(() => endTime = pickedEnd);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: (startTime != null && endTime != null) ? Colors.deepPurple.shade200 : Colors.grey.shade300,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.schedule_rounded, size: 18, color: startTime != null ? Colors.deepPurple : Colors.grey),
                                  const SizedBox(width: 10),
                                  Text(
                                    startTime != null && endTime != null
                                        ? "${startTime!.format(context)}  →  ${endTime!.format(context)}"
                                        : startTime != null
                                            ? "${startTime!.format(context)}  →  End?"
                                            : "Set time...",
                                    style: TextStyle(
                                      fontWeight: startTime != null ? FontWeight.w600 : FontWeight.normal,
                                      color: startTime != null ? Colors.black87 : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),

                ElevatedButton(
                  onPressed: addSchedule,
                  child: const Text("Add"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> getFilteredSchedule() {
    List<Map<String, dynamic>> filtered = schedule.where((item) {
      return item["day"] != null &&
          item["start"] != null &&
          item["end"] != null &&
          item["day"] == currentViewDay;
    }).toList();

    filtered.sort((a, b) {
      final (aHour, aMin) = _parseTimeToHourMinute(a["start"]!);
      final (bHour, bMin) = _parseTimeToHourMinute(b["start"]!);
      final aTotal = aHour * 60 + aMin;
      final bTotal = bHour * 60 + bMin;
      return aTotal.compareTo(bTotal);
    });

    return filtered;
  }

  DateTime parseTime(String time) {
    final cleaned = time.trim().toUpperCase();

    final parts = cleaned.split(' ');

    final timePart = parts[0];

    String? period;

    if (parts.length > 1) {
      period = parts[1];
    }

    final hm = timePart.split(':');

    int hour = int.parse(hm[0]);

    int minute = hm.length > 1 ? int.parse(hm[1]) : 0;

    if (period == 'PM' && hour != 12) {
      hour += 12;
    }

    if (period == 'AM' && hour == 12) {
      hour = 0;
    }

    return DateTime(2025, 1, 1, hour, minute);
  }

  @override
  Widget build(BuildContext context) {
    // Constants for the timeline
    const double hourHeight = 60.0; // pixels per hour
    const int startHour = 0;
    const int endHour = 24;
    const int totalHours = endHour - startHour; // 24 hours
    const double totalHeight = totalHours * hourHeight;
    const double timeColumnWidth = 50.0;

    final filtered = getFilteredSchedule();

    return Scaffold(
      appBar: AppBar(title: const Text("Weekly Schedule")),

      floatingActionButton: FloatingActionButton(
        heroTag: "schedule_fab",
        onPressed: showAddDialog,
        child: const Icon(Icons.add),
      ),

      body: Column(
        children: [
          // Day selector
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day = days[index];
                final selected = day == currentViewDay;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      currentViewDay = day;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? Colors.deepPurple : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        day.substring(0, 3),
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.black,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Timeline
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 20),
              child: SizedBox(
                height: totalHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time labels column
                    SizedBox(
                      width: timeColumnWidth,
                      height: totalHeight,
                      child: Stack(
                        children: List.generate(totalHours + 1, (index) {
                          final hour = startHour + index;
                          return Positioned(
                            top: index * hourHeight - 8,
                            left: 0,
                            right: 0,
                            child: Text(
                              "${hour.toString().padLeft(2, '0')}:00",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }),
                      ),
                    ),

                    // Events area
                    Expanded(
                      child: SizedBox(
                        height: totalHeight,
                        child: Stack(
                          children: [
                            // Hour grid lines
                            ...List.generate(totalHours + 1, (index) {
                              return Positioned(
                                top: index * hourHeight,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 0.5,
                                  color: Colors.grey.shade300,
                                ),
                              );
                            }),

                            // Event blocks
                            ...filtered.map((event) {
                              final start = parseTime(event["start"]);
                              final end = parseTime(event["end"]);

                              final startMinutes = (start.hour - startHour) * 60 + start.minute;
                              final durationMinutes = end.difference(start).inMinutes;

                              final top = startMinutes * (hourHeight / 60);
                              final height = durationMinutes * (hourHeight / 60);

                              return Positioned(
                                top: top,
                                left: 4,
                                right: 4,
                                child: GestureDetector(
                                  onLongPress: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          title: const Text("Delete Event"),
                                          content: Text("Delete ${event["title"]}?"),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text("Cancel"),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                              child: const Text("Delete"),
                                            ),
                                          ],
                                        );
                                      },
                                    );

                                    if (confirm != true) return;

                                    // Delete from Firestore using document ID
                                    final docId = event['id'];
                                    if (docId != null) {
                                      await StorageService.deleteScheduleItem(docId);
                                    }

                                    if (!mounted) return;
                                    setState(() {
                                      schedule.remove(event);
                                    });
                                  },
                                  child: Container(
                                    height: height < 30 ? 30 : height,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Color(event["color"] ?? Colors.deepPurple.value),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          event["title"] ?? "",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (height > 40)
                                          Text(
                                            "${event["start"]} - ${event["end"]}",
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
                                            ),
                                          ),
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
        ],
      ),
    );
  }
}
