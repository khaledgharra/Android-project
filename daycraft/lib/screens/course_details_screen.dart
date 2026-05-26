import 'package:flutter/material.dart';

import '../services/storage_service.dart';

class CourseDetailsScreen extends StatefulWidget {

  final String courseName;

  const CourseDetailsScreen({
    super.key,
    required this.courseName,
  });

  @override
  State<CourseDetailsScreen> createState() =>
      _CourseDetailsScreenState();
}

class _CourseDetailsScreenState
    extends State<CourseDetailsScreen> {

  List<Map<String, dynamic>>
      courseDeadlines = [];

  @override
  void initState() {
    super.initState();

    loadCourseDeadlines();
  }

  Future<void> loadCourseDeadlines() async {

    final deadlines =
        await StorageService
            .loadDeadlines();

    final filtered =
        deadlines.where((item) {

      return item["course"] ==
          widget.courseName;
    }).toList();

    setState(() {
      courseDeadlines = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: Text(
          widget.courseName,
        ),
      ),

      body: courseDeadlines.isEmpty

          ? const Center(
              child: Text(
                "No deadlines yet",
              ),
            )

          : ListView.builder(

              padding:
                  const EdgeInsets.all(20),

              itemCount:
                  courseDeadlines.length,

              itemBuilder:
                  (context, index) {

                final item =
                    courseDeadlines[index];

                return Container(

                  margin:
                      const EdgeInsets.only(
                    bottom: 16,
                  ),

                  padding:
                      const EdgeInsets.all(20),

                  decoration: BoxDecoration(
                    color: Colors.deepPurple
                        .withOpacity(0.1),

                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),

                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                    children: [

                      Text(
                        item["title"] ?? "",

                        style:
                            const TextStyle(
                          fontSize: 20,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      Text(
                        item["date"] ?? "",
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      Text(
                        item["type"] ??
                            "",
                        style:
                            const TextStyle(
                          color:
                              Colors.deepPurple,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}