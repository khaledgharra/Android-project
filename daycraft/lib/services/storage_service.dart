import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorageService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Returns the current user's UID, or null if not logged in
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Reference to the current user's document
  static DocumentReference? get _userDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  }

  // =========================
  // Schedule (includes courses stored as type: "Course")
  // =========================

  static Future<void> saveSchedule(List<Map<String, dynamic>> schedule) async {
    final userDoc = _userDoc;
    if (userDoc == null) return;

    final collection = userDoc.collection('schedule');

    // Get existing documents
    final existing = await collection.get();

    // Delete all existing documents
    final batch = _firestore.batch();
    for (var doc in existing.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    // Add all new documents
    for (var item in schedule) {
      await collection.add(item);
    }
  }

  static Future<List<Map<String, dynamic>>> loadSchedule() async {
    final userDoc = _userDoc;
    if (userDoc == null) return [];

    final snapshot = await userDoc.collection('schedule').get();

    return snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id; // Include document ID for update/delete
      return data;
    }).toList();
  }

  /// Add a single schedule item and return its document ID
  static Future<String?> addScheduleItem(Map<String, dynamic> item) async {
    final userDoc = _userDoc;
    if (userDoc == null) return null;

    final docRef = await userDoc.collection('schedule').add(item);
    return docRef.id;
  }

  /// Delete a single schedule item by document ID
  static Future<void> deleteScheduleItem(String docId) async {
    final userDoc = _userDoc;
    if (userDoc == null) return;

    await userDoc.collection('schedule').doc(docId).delete();
  }

  /// Update a single schedule item by document ID
  static Future<void> updateScheduleItem(String docId, Map<String, dynamic> data) async {
    final userDoc = _userDoc;
    if (userDoc == null) return;

    // Remove the 'id' field before saving to Firestore
    final cleanData = Map<String, dynamic>.from(data);
    cleanData.remove('id');

    await userDoc.collection('schedule').doc(docId).update(cleanData);
  }

  // =========================
  // Deadlines
  // =========================

  static Future<void> saveDeadlines(List<Map<String, dynamic>> deadlines) async {
    final userDoc = _userDoc;
    if (userDoc == null) return;

    final collection = userDoc.collection('deadlines');

    // Get existing documents
    final existing = await collection.get();

    // Delete all existing documents
    final batch = _firestore.batch();
    for (var doc in existing.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    // Add all new documents (strip 'id' field if present)
    for (var item in deadlines) {
      final cleanItem = Map<String, dynamic>.from(item);
      cleanItem.remove('id');
      await collection.add(cleanItem);
    }
  }

  static Future<List<Map<String, dynamic>>> loadDeadlines() async {
    final userDoc = _userDoc;
    if (userDoc == null) return [];

    final snapshot = await userDoc.collection('deadlines').get();

    return snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id; // Include document ID for update/delete
      return data;
    }).toList();
  }

  /// Add a single deadline and return its document ID
  static Future<String?> addDeadline(Map<String, dynamic> item) async {
    final userDoc = _userDoc;
    if (userDoc == null) return null;

    final docRef = await userDoc.collection('deadlines').add(item);
    return docRef.id;
  }

  /// Delete a single deadline by document ID
  static Future<void> deleteDeadline(String docId) async {
    final userDoc = _userDoc;
    if (userDoc == null) return;

    await userDoc.collection('deadlines').doc(docId).delete();
  }

  /// Update a single deadline by document ID
  static Future<void> updateDeadline(String docId, Map<String, dynamic> data) async {
    final userDoc = _userDoc;
    if (userDoc == null) return;

    // Remove the 'id' field before saving to Firestore
    final cleanData = Map<String, dynamic>.from(data);
    cleanData.remove('id');

    await userDoc.collection('deadlines').doc(docId).update(cleanData);
  }
}
