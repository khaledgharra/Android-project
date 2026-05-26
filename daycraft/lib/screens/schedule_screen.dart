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

    setState(() {
      schedule = loaded;
    });
  }

  Future<void> pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        startTime = picked;
      });
    }
  }

  Future<void> pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        endTime = picked;
      });
    }
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

      final existingStartTime = TimeOfDay(
        hour: int.parse(item["start"].split(":")[0]),

        minute: int.parse(item["start"].split(":")[1].split(" ")[0]),
      );

      final existingEndTime = TimeOfDay(
        hour: int.parse(item["end"].split(":")[0]),

        minute: int.parse(item["end"].split(":")[1].split(" ")[0]),
      );

      final existingStartMinutes =
          existingStartTime.hour * 60 + existingStartTime.minute;

      final existingEndMinutes =
          existingEndTime.hour * 60 + existingEndTime.minute;

      return !(newEnd <= existingStartMinutes ||
          newStart >= existingEndMinutes);
    });

    if (overlapping) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This activity overlaps with another schedule item"),
        ),
      );

      return;
    }

    setState(() {
      schedule.add({
        "title": titleController.text,
        "type": selectedType,
        "day": selectedDay,
        "start": "${startTime!.hour}:${startTime!.minute}",
        "end": "${endTime!.hour}:${endTime!.minute}",
      });
    });

    await StorageService.saveSchedule(schedule);

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

                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.now(),
                                    );

                                    if (picked != null) {
                                      setDialogState(() {
                                        startTime = picked;
                                      });
                                    }
                                  },

                                  child: Container(
                                    padding: const EdgeInsets.all(14),

                                    decoration: BoxDecoration(
                                      color: Colors.white,

                                      borderRadius: BorderRadius.circular(12),
                                    ),

                                    child: Text(
                                      startTime == null
                                          ? "Start Time"
                                          : startTime!.format(context),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 10),

                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.now(),
                                    );

                                    if (picked != null) {
                                      setDialogState(() {
                                        endTime = picked;
                                      });
                                    }
                                  },

                                  child: Container(
                                    padding: const EdgeInsets.all(14),

                                    decoration: BoxDecoration(
                                      color: Colors.white,

                                      borderRadius: BorderRadius.circular(12),
                                    ),

                                    child: Text(
                                      endTime == null
                                          ? "End Time"
                                          : endTime!.format(context),
                                    ),
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
      final aStart = a["start"]!.split(":");

      final bStart = b["start"]!.split(":");

      final aHour = int.parse(aStart[0]);

      final bHour = int.parse(bStart[0]);

      return aHour.compareTo(bHour);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = getFilteredSchedule();

    return Scaffold(
      appBar: AppBar(title: const Text("Weekly Schedule")),

      floatingActionButton: FloatingActionButton(
        onPressed: showAddDialog,
        child: const Icon(Icons.add),
      ),

      body: Column(
        children: [
          SizedBox(
            height: 70,

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
                    margin: const EdgeInsets.all(8),

                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),

                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.deepPurple
                          : Colors.grey.shade200,

                      borderRadius: BorderRadius.circular(20),
                    ),

                    child: Center(
                      child: Text(
                        day,

                        style: TextStyle(
                          color: selected ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),

              itemCount: 15,

              itemBuilder: (context, hourIndex) {
                final hour = 8 + hourIndex;

                final filtered = getFilteredSchedule();

                final events = filtered.where((event) {
                  final start = event["start"]!.split(":");

                  final eventHour = int.parse(start[0]);

                  return eventHour == hour;
                }).toList();

                return Container(
                  constraints: const BoxConstraints(minHeight: 140),

                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      SizedBox(
                        width: 60,

                        child: Text(
                          "${hour.toString().padLeft(2, '0')}:00",

                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      Expanded(
                        child: Column(
                          children: [
                            Container(height: 1, color: Colors.grey.shade300),

                            const SizedBox(height: 8),

                            ...events.map((event) {
                              return GestureDetector(
                                onLongPress: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,

                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text("Delete Event"),

                                        content: Text(
                                          "Delete ${event["title"]} ?",
                                        ),

                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context, false);
                                            },

                                            child: const Text("Cancel"),
                                          ),

                                          ElevatedButton(
                                            onPressed: () {
                                              Navigator.pop(context, true);
                                            },

                                            child: const Text("Delete"),
                                          ),
                                        ],
                                      );
                                    },
                                  );

                                  if (confirm != true) {
                                    return;
                                  }

                                  setState(() {
                                    schedule.remove(event);
                                  });

                                  await StorageService.saveSchedule(schedule);
                                },

                                child: Container(
                                  width: double.infinity,

                                  margin: const EdgeInsets.only(bottom: 8),

                                  padding: const EdgeInsets.all(12),

                                  decoration: BoxDecoration(
                                    color: Color(
                                      event["color"] ?? Colors.deepPurple.value,
                                    ),

                                    borderRadius: BorderRadius.circular(18),
                                  ),

                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,

                                    children: [
                                      Text(
                                        event["title"]!,

                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,

                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      Text(
                                        "${event["start"]} - ${event["end"]}",

                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
