import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StorageService {

  // =========================
  // Schedule / Courses
  // =========================

  static Future<void> saveSchedule(
    List<Map<String, dynamic>> schedule,
  ) async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      "schedule",
      jsonEncode(schedule),
    );
  }

  static Future<List<Map<String, dynamic>>> loadSchedule() async {

    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString("schedule");

    if (data == null) {
      return [];
    }

    return List<Map<String, dynamic>>.from(
      jsonDecode(data),
    );
  }

  // =========================
  // Deadlines
  // =========================

  static Future<void> saveDeadlines(
    List<Map<String, dynamic>> deadlines,
  ) async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      "deadlines",
      jsonEncode(deadlines),
    );
  }

  static Future<List<Map<String, dynamic>>> loadDeadlines() async {

    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString("deadlines");

    if (data == null) {
      return [];
    }

    final decoded = List<Map<String, dynamic>>.from(
      jsonDecode(data),
    );

    return decoded.map((e) {
      return Map<String, dynamic>.from(e);
    }).toList();
  }
}