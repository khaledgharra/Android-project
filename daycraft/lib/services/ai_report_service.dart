import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AIReportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> submitReport({
    required String feature,
    required String reason,
    required String generatedContent,
    required String userPrompt,
    String? comment,
  }) async {
    String? appVersion;
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      appVersion = null;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final platform = defaultTargetPlatform.name;

    await _firestore.collection('ai_reports').add({
      'feature': feature,
      'reason': reason,
      'comment': comment ?? '',
      'generatedContent': generatedContent,
      'userPrompt': userPrompt,
      'timestamp': FieldValue.serverTimestamp(),
      'appVersion': appVersion,
      'platform': platform,
      'uid': uid,
    });
  }
}
