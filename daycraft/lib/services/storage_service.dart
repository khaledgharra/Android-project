import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static Future<void> saveSchedule(List<Map<String, String>> schedule) async {
    final prefs = await SharedPreferences.getInstance();

    prefs.setString("schedule", jsonEncode(schedule));
  }

  static Future<List<Map<String, String>>> loadSchedule() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString("schedule");

    if (data == null) {
      return [];
    }

    final decoded = List<Map<String, dynamic>>.from(jsonDecode(data));

    return decoded.map((e) {
      return Map<String, String>.from(e);
    }).toList();
  }

  static Future<void> saveDeadlines(List<Map<String, String>> deadlines) async {
    final prefs = await SharedPreferences.getInstance();

    prefs.setString("deadlines", jsonEncode(deadlines));
  }

  static Future<List<Map<String, String>>> loadDeadlines() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString("deadlines");

    if (data == null) {
      return [];
    }

    final decoded = List<Map<String, dynamic>>.from(jsonDecode(data));

    return decoded.map((e) {
      return Map<String, String>.from(e);
    }).toList();
  }
}
