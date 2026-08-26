import 'package:cloud_firestore/cloud_firestore.dart';

class BookingSlotClosuresRepository {
  BookingSlotClosuresRepository._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String collectionName = 'booking_slot_closures';

  static String dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  static String documentId({
    required DateTime date,
    required String service,
    required String time,
  }) {
    return '${dateKey(date)}_${service}_$time';
  }

  static DocumentReference<Map<String, dynamic>> reference({
    required DateTime date,
    required String service,
    required String time,
  }) {
    return _firestore
        .collection(collectionName)
        .doc(documentId(date: date, service: service, time: time));
  }

  static Future<Set<String>> loadClosedTimes({
    required DateTime date,
    required String service,
  }) async {
    final snapshot = await _firestore
        .collection(collectionName)
        .where('dateKey', isEqualTo: dateKey(date))
        .where('service', isEqualTo: service)
        .get();

    return snapshot.docs
        .map((document) => document.data()['time'] as String? ?? '')
        .where((time) => time.isNotEmpty)
        .toSet();
  }

  static Future<bool> isClosed({
    required DateTime date,
    required String service,
    required String time,
  }) async {
    final snapshot = await reference(
      date: date,
      service: service,
      time: time,
    ).get();

    return snapshot.exists;
  }

  static Future<void> setClosed({
    required DateTime date,
    required String service,
    required String time,
    required bool closed,
  }) async {
    final documentReference = reference(
      date: date,
      service: service,
      time: time,
    );

    if (!closed) {
      await documentReference.delete();
      return;
    }

    await documentReference.set({
      'dateKey': dateKey(date),
      'service': service,
      'time': time,
      'closed': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
