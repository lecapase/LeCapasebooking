import 'package:cloud_firestore/cloud_firestore.dart';

class BookingSlotClosuresRepository {
  BookingSlotClosuresRepository._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String collectionName = 'booking_slot_closures';
  static const String serviceCollectionName = 'booking_service_closures';

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

  static DocumentReference<Map<String, dynamic>> serviceReference({
    required DateTime date,
    required String service,
  }) {
    return _firestore
        .collection(serviceCollectionName)
        .doc('${dateKey(date)}_$service');
  }

  static Future<Map<String, dynamic>?> loadServiceClosure({
    required DateTime date,
    required String service,
  }) async {
    final snapshot = await serviceReference(date: date, service: service).get();

    return snapshot.data();
  }

  static Future<bool> isServiceClosed({
    required DateTime date,
    required String service,
  }) async {
    final snapshot = await serviceReference(date: date, service: service).get();

    return snapshot.exists;
  }

  static Future<void> setServiceOnlineDisabled({
    required DateTime date,
    required String service,
    required bool disabled,
  }) async {
    final documentReference = serviceReference(date: date, service: service);

    if (!disabled) {
      await documentReference.delete();
      return;
    }

    await documentReference.set({
      'dateKey': dateKey(date),
      'service': service,
      'mode': 'online_disabled',
      'closed': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
