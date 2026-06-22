import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorageService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// The currently active semester ID. Must be set before any data operations.
  static String currentSemesterId = '';

  /// End date of the active semester (null = no limit).
  static DateTime? currentSemesterEndDate;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static DocumentReference? get _userDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  }

  /// Reference to the active semester document.
  static DocumentReference? get _semesterDoc {
    final userDoc = _userDoc;
    if (userDoc == null || currentSemesterId.isEmpty) return null;
    return userDoc.collection('semesters').doc(currentSemesterId);
  }

  static CollectionReference? get _scheduleCol =>
      _semesterDoc?.collection('schedule');

  static CollectionReference? get _deadlinesCol =>
      _semesterDoc?.collection('deadlines');

  /// Per-semester preferences (reminders, completedTaskIds).
  static DocumentReference? get _prefsDoc =>
      _semesterDoc?.collection('preferences').doc('data');

  /// Global (cross-semester) preferences: semester list + active semester ID.
  static DocumentReference? get _globalPrefsDoc =>
      _userDoc?.collection('preferences').doc('global');

  // =========================
  // Semester management
  // =========================

  static Future<List<Map<String, dynamic>>> loadSemesters() async {
    final doc = _globalPrefsDoc;
    if (doc == null) return [];
    final snap = await doc.get();
    if (!snap.exists) return [];
    final data = snap.data() as Map<String, dynamic>?;
    final raw = data?['semesters'];
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(
      (raw as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  static Future<void> saveSemesters(List<Map<String, dynamic>> semesters) async {
    final doc = _globalPrefsDoc;
    if (doc == null) return;
    await doc.set({'semesters': semesters}, SetOptions(merge: true));
  }

  static Future<String?> loadActiveSemesterId() async {
    final doc = _globalPrefsDoc;
    if (doc == null) return null;
    final snap = await doc.get();
    if (!snap.exists) return null;
    final data = snap.data() as Map<String, dynamic>?;
    return data?['activeSemesterId'] as String?;
  }

  static Future<void> saveActiveSemesterId(String id) async {
    final doc = _globalPrefsDoc;
    if (doc == null) return;
    await doc.set({'activeSemesterId': id}, SetOptions(merge: true));
  }

  /// Creates a new semester, saves it to Firestore, and returns its generated ID.
  static Future<String?> createSemester(String name, {String? endDate}) async {
    final userDoc = _userDoc;
    if (userDoc == null) return null;
    final semRef = userDoc.collection('semesters').doc();
    final docData = <String, dynamic>{'name': name, 'createdAt': FieldValue.serverTimestamp()};
    if (endDate != null) docData['endDate'] = endDate;
    await semRef.set(docData);
    final semesters = await loadSemesters();
    final entry = <String, dynamic>{'id': semRef.id, 'name': name};
    if (endDate != null) entry['endDate'] = endDate;
    semesters.add(entry);
    await saveSemesters(semesters);
    return semRef.id;
  }

  /// Updates the end date of an existing semester (null clears it).
  static Future<void> updateSemesterEndDate(String semId, String? endDate) async {
    final semesters = await loadSemesters();
    for (final s in semesters) {
      if (s['id'] == semId) {
        if (endDate != null) {
          s['endDate'] = endDate;
        } else {
          s.remove('endDate');
        }
        break;
      }
    }
    await saveSemesters(semesters);
  }

  /// Deletes a semester document AND all its subcollection data in one batch.
  static Future<void> deleteSemester(String semId) async {
    final userDoc = _userDoc;
    if (userDoc == null) return;
    final semDoc = userDoc.collection('semesters').doc(semId);

    // Delete all subcollection docs in a batch
    final batch = _firestore.batch();
    for (final col in ['schedule', 'deadlines']) {
      final snap = await semDoc.collection(col).get();
      for (final d in snap.docs) batch.delete(d.reference);
    }
    final prefsSnap = await semDoc.collection('preferences').get();
    for (final d in prefsSnap.docs) batch.delete(d.reference);
    batch.delete(semDoc);
    await batch.commit();

    // Remove from the semesters list
    final semesters = await loadSemesters();
    semesters.removeWhere((s) => s['id'] == semId);
    await saveSemesters(semesters);
  }

  // =========================
  // Schedule
  // =========================

  static Future<void> saveSchedule(List<Map<String, dynamic>> schedule) async {
    final col = _scheduleCol;
    if (col == null) return;
    final existing = await col.get();
    final batch = _firestore.batch();
    for (var doc in existing.docs) batch.delete(doc.reference);
    for (var item in schedule) {
      final clean = Map<String, dynamic>.from(item)..remove('id');
      batch.set(col.doc(), clean);
    }
    await batch.commit();
  }

  static Future<void> replaceScheduleItems({
    required List<String> deleteIds,
    required List<Map<String, dynamic>> addItems,
  }) async {
    final col = _scheduleCol;
    if (col == null) return;
    final batch = _firestore.batch();
    for (final id in deleteIds) batch.delete(col.doc(id));
    for (final item in addItems) {
      final clean = Map<String, dynamic>.from(item)..remove('id');
      batch.set(col.doc(), clean);
    }
    await batch.commit();
  }

  static Future<void> addScheduleItemsBatch(List<Map<String, dynamic>> items) async {
    final col = _scheduleCol;
    if (col == null) return;
    final batch = _firestore.batch();
    for (final item in items) {
      final clean = Map<String, dynamic>.from(item)..remove('id');
      batch.set(col.doc(), clean);
    }
    await batch.commit();
  }

  static Future<List<Map<String, dynamic>>> loadSchedule() async {
    final col = _scheduleCol;
    if (col == null) return [];
    final snapshot = await col.get();
    return snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data() as Map);
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  static Future<String?> addScheduleItem(Map<String, dynamic> item) async {
    final col = _scheduleCol;
    if (col == null) return null;
    final docRef = await col.add(item);
    return docRef.id;
  }

  static Future<void> deleteScheduleItem(String docId) async {
    await _scheduleCol?.doc(docId).delete();
  }

  static Future<void> updateScheduleItem(String docId, Map<String, dynamic> data) async {
    final clean = Map<String, dynamic>.from(data)..remove('id');
    await _scheduleCol?.doc(docId).update(clean);
  }

  // =========================
  // Deadlines
  // =========================

  static Future<void> saveDeadlines(List<Map<String, dynamic>> deadlines) async {
    final col = _deadlinesCol;
    if (col == null) return;
    final existing = await col.get();
    final batch = _firestore.batch();
    for (var doc in existing.docs) batch.delete(doc.reference);
    for (var item in deadlines) {
      final clean = Map<String, dynamic>.from(item)..remove('id');
      batch.set(col.doc(), clean);
    }
    await batch.commit();
  }

  static Future<List<Map<String, dynamic>>> loadDeadlines() async {
    final col = _deadlinesCol;
    if (col == null) return [];
    final snapshot = await col.get();
    return snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data() as Map);
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  static Future<String?> addDeadline(Map<String, dynamic> item) async {
    final col = _deadlinesCol;
    if (col == null) return null;
    final docRef = await col.add(item);
    return docRef.id;
  }

  static Future<void> deleteDeadline(String docId) async {
    await _deadlinesCol?.doc(docId).delete();
  }

  static Future<void> updateDeadline(String docId, Map<String, dynamic> data) async {
    final clean = Map<String, dynamic>.from(data)..remove('id');
    await _deadlinesCol?.doc(docId).update(clean);
  }

  // =========================
  // Reminders (per-semester)
  // =========================

  static Future<void> saveReminders(List<Map<String, dynamic>> reminders) async {
    final doc = _prefsDoc;
    if (doc == null) return;
    await doc.set({'reminders': reminders}, SetOptions(merge: true));
  }

  static Future<List<Map<String, dynamic>>> loadReminders() async {
    final doc = _prefsDoc;
    if (doc == null) return [];
    final snap = await doc.get();
    if (!snap.exists) return [];
    final data = snap.data() as Map<String, dynamic>?;
    final raw = data?['reminders'];
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(
      (raw as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  // =========================
  // Completed task IDs (per-semester)
  // =========================

  static Future<void> saveCompletedTaskIds(List<String> ids) async {
    final doc = _prefsDoc;
    if (doc == null) return;
    await doc.set({'completedTaskIds': ids}, SetOptions(merge: true));
  }

  static Future<List<String>> loadCompletedTaskIds() async {
    final doc = _prefsDoc;
    if (doc == null) return [];
    final snap = await doc.get();
    if (!snap.exists) return [];
    final data = snap.data() as Map<String, dynamic>?;
    final raw = data?['completedTaskIds'];
    if (raw == null) return [];
    return List<String>.from(raw as List);
  }
}
