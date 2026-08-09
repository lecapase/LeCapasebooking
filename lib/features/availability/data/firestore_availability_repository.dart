import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/service_availability.dart';

class FirestoreAvailabilityRepository {
  FirestoreAvailabilityRepository._();

  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static const String _weeklyCollection =
      'availability_weekly';

  static const String _exceptionsCollection =
      'availability_exceptions';

  // =========================================================
  // SALVA REGOLA SETTIMANALE
  // =========================================================

  static Future<void> saveWeeklyDay(
    DayAvailability day,
  ) async {
    await _firestore
        .collection(_weeklyCollection)
        .doc(day.weekday.toString())
        .set({
      'weekday': day.weekday,
      'name': day.name,
      'lunch': _serviceToMap(day.lunch),
      'dinner': _serviceToMap(day.dinner),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // =========================================================
  // SALVA TUTTA LA SETTIMANA
  // =========================================================

  static Future<void> saveAllWeeklyDays(
    List<DayAvailability> days,
  ) async {
    final batch = _firestore.batch();

    for (final day in days) {
      final reference = _firestore
          .collection(_weeklyCollection)
          .doc(day.weekday.toString());

      batch.set(
        reference,
        {
          'weekday': day.weekday,
          'name': day.name,
          'lunch': _serviceToMap(day.lunch),
          'dinner': _serviceToMap(day.dinner),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }

    await batch.commit();
  }

  // =========================================================
  // CARICA REGOLE SETTIMANALI
  // =========================================================

  static Future<List<DayAvailability>>
      loadWeeklyDays() async {
    final snapshot = await _firestore
        .collection(_weeklyCollection)
        .orderBy('weekday')
        .get();

    return snapshot.docs.map((document) {
      final data = document.data();

      return DayAvailability(
        weekday: data['weekday'] as int,
        name: data['name'] as String,
        lunch: _serviceFromMap(
          Map<String, dynamic>.from(
            data['lunch'] as Map,
          ),
        ),
        dinner: _serviceFromMap(
          Map<String, dynamic>.from(
            data['dinner'] as Map,
          ),
        ),
      );
    }).toList();
  }

  // =========================================================
  // SALVA ECCEZIONE PER DATA
  // =========================================================

  static Future<void> saveException(
    DateAvailabilityException exception,
  ) async {
    final id = _dateId(exception.date);

    await _firestore
        .collection(_exceptionsCollection)
        .doc(id)
        .set({
      'date': Timestamp.fromDate(
        DateTime(
          exception.date.year,
          exception.date.month,
          exception.date.day,
        ),
      ),
      'lunch': _serviceToMap(exception.lunch),
      'dinner': _serviceToMap(exception.dinner),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // =========================================================
  // CARICA UNA ECCEZIONE
  // =========================================================

  static Future<DateAvailabilityException?>
      loadException(
    DateTime date,
  ) async {
    final id = _dateId(date);

    final document = await _firestore
        .collection(_exceptionsCollection)
        .doc(id)
        .get();

    if (!document.exists) {
      return null;
    }

    final data = document.data();

    if (data == null) {
      return null;
    }

    final timestamp = data['date'] as Timestamp;

    return DateAvailabilityException(
      date: timestamp.toDate(),
      lunch: _serviceFromMap(
        Map<String, dynamic>.from(
          data['lunch'] as Map,
        ),
      ),
      dinner: _serviceFromMap(
        Map<String, dynamic>.from(
          data['dinner'] as Map,
        ),
      ),
    );
  }

  // =========================================================
  // CARICA TUTTE LE ECCEZIONI
  // =========================================================

  static Future<List<DateAvailabilityException>>
      loadAllExceptions() async {
    final snapshot = await _firestore
        .collection(_exceptionsCollection)
        .orderBy('date')
        .get();

    return snapshot.docs.map((document) {
      final data = document.data();

      final timestamp = data['date'] as Timestamp;

      return DateAvailabilityException(
        date: timestamp.toDate(),
        lunch: _serviceFromMap(
          Map<String, dynamic>.from(
            data['lunch'] as Map,
          ),
        ),
        dinner: _serviceFromMap(
          Map<String, dynamic>.from(
            data['dinner'] as Map,
          ),
        ),
      );
    }).toList();
  }

  // =========================================================
  // ELIMINA ECCEZIONE
  // =========================================================

  static Future<void> deleteException(
    DateTime date,
  ) async {
    final id = _dateId(date);

    await _firestore
        .collection(_exceptionsCollection)
        .doc(id)
        .delete();
  }

  // =========================================================
  // SERVICE -> MAP
  // =========================================================

  static Map<String, dynamic> _serviceToMap(
    ServiceAvailability service,
  ) {
    return {
      'id': service.id,
      'name': service.name,
      'isOpen': service.isOpen,
      'startTime': service.startTime,
      'endTime': service.endTime,
      'maxOnlineGuests': service.maxOnlineGuests,
      'blockedRanges': service.blockedRanges
          .map(
            (range) => {
              'startTime': range.startTime,
              'endTime': range.endTime,
            },
          )
          .toList(),
    };
  }

  // =========================================================
  // MAP -> SERVICE
  // =========================================================

  static ServiceAvailability _serviceFromMap(
    Map<String, dynamic> data,
  ) {
    final ranges =
        data['blockedRanges'] as List<dynamic>? ?? [];

    return ServiceAvailability(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      isOpen: data['isOpen'] as bool? ?? true,
      startTime:
          data['startTime'] as String? ?? '',
      endTime:
          data['endTime'] as String? ?? '',
      maxOnlineGuests:
          data['maxOnlineGuests'] as int? ?? 80,
      blockedRanges: ranges.map((item) {
        final map =
            Map<String, dynamic>.from(item as Map);

        return BlockedTimeRange(
          startTime:
              map['startTime'] as String? ?? '',
          endTime:
              map['endTime'] as String? ?? '',
        );
      }).toList(),
    );
  }

  // =========================================================
  // ID DATA: 2026-08-15
  // =========================================================

  static String _dateId(DateTime date) {
    final year =
        date.year.toString().padLeft(4, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    final day =
        date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}