import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/service_availability.dart';

class FirestoreAvailabilityRepository {
  FirestoreAvailabilityRepository._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _weeklyCollection = 'availability_weekly';

  static const String _exceptionsCollection = 'availability_exceptions';

  static const String _managedServicesCollection = 'managed_services';

  // =========================================================
  // SALVA REGOLA SETTIMANALE PRECEDENTE
  // =========================================================

  static Future<void> saveWeeklyDay(DayAvailability day) async {
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
  // SALVA TUTTA LA SETTIMANA PRECEDENTE
  // =========================================================

  static Future<void> saveAllWeeklyDays(List<DayAvailability> days) async {
    final batch = _firestore.batch();

    for (final day in days) {
      final reference = _firestore
          .collection(_weeklyCollection)
          .doc(day.weekday.toString());

      batch.set(reference, {
        'weekday': day.weekday,
        'name': day.name,
        'lunch': _serviceToMap(day.lunch),
        'dinner': _serviceToMap(day.dinner),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // =========================================================
  // CARICA REGOLE SETTIMANALI PRECEDENTI
  // =========================================================

  static Future<List<DayAvailability>> loadWeeklyDays() async {
    final snapshot = await _firestore
        .collection(_weeklyCollection)
        .orderBy('weekday')
        .get();

    return snapshot.docs.map((document) {
      final data = document.data();

      return DayAvailability(
        weekday: (data['weekday'] as num?)?.toInt() ?? 1,
        name: data['name'] as String? ?? '',
        lunch: _serviceFromMap(
          Map<String, dynamic>.from(data['lunch'] as Map? ?? {}),
        ),
        dinner: _serviceFromMap(
          Map<String, dynamic>.from(data['dinner'] as Map? ?? {}),
        ),
      );
    }).toList();
  }

  // =========================================================
  // SALVA ECCEZIONE PRECEDENTE
  // =========================================================

  static Future<void> saveException(DateAvailabilityException exception) async {
    final id = _dateId(exception.date);

    await _firestore.collection(_exceptionsCollection).doc(id).set({
      'date': Timestamp.fromDate(_normalizeDate(exception.date)),
      'lunch': _serviceToMap(exception.lunch),
      'dinner': _serviceToMap(exception.dinner),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // =========================================================
  // CARICA UNA ECCEZIONE PRECEDENTE
  // =========================================================

  static Future<DateAvailabilityException?> loadException(DateTime date) async {
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

    return _exceptionFromMap(data);
  }

  // =========================================================
  // CARICA TUTTE LE ECCEZIONI PRECEDENTI
  // =========================================================

  static Future<List<DateAvailabilityException>> loadAllExceptions() async {
    final snapshot = await _firestore
        .collection(_exceptionsCollection)
        .orderBy('date')
        .get();

    return snapshot.docs
        .map((document) => _exceptionFromMap(document.data()))
        .toList();
  }

  // =========================================================
  // ELIMINA ECCEZIONE PRECEDENTE
  // =========================================================

  static Future<void> deleteException(DateTime date) async {
    await _firestore
        .collection(_exceptionsCollection)
        .doc(_dateId(date))
        .delete();
  }

  // =========================================================
  // SALVA UN NUOVO SERVIZIO GESTITO
  // =========================================================

  static Future<void> saveManagedService(ManagedService service) async {
    await _firestore
        .collection(_managedServicesCollection)
        .doc(service.id)
        .set({
          ..._managedServiceToMap(service),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  // =========================================================
  // SALVA PIÙ SERVIZI GESTITI
  // =========================================================

  static Future<void> saveAllManagedServices(
    List<ManagedService> services,
  ) async {
    if (services.isEmpty) {
      return;
    }

    final batch = _firestore.batch();

    for (final service in services) {
      final reference = _firestore
          .collection(_managedServicesCollection)
          .doc(service.id);

      batch.set(reference, {
        ..._managedServiceToMap(service),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  // =========================================================
  // CARICA TUTTI I SERVIZI GESTITI
  // =========================================================

  static Future<List<ManagedService>> loadManagedServices() async {
    final snapshot = await _firestore
        .collection(_managedServicesCollection)
        .get();

    final services = snapshot.docs.map((document) {
      final data = document.data();

      return _managedServiceFromMap(document.id, data);
    }).toList();

    services.sort((first, second) {
      if (first.isAnnual && second.isSpecificDate) {
        return -1;
      }

      if (first.isSpecificDate && second.isAnnual) {
        return 1;
      }

      final firstDate = first.specificDate ?? first.startDate ?? DateTime(2100);

      final secondDate =
          second.specificDate ?? second.startDate ?? DateTime(2100);

      final dateComparison = firstDate.compareTo(secondDate);

      if (dateComparison != 0) {
        return dateComparison;
      }

      return first.startTime.compareTo(second.startTime);
    });

    return services;
  }

  // =========================================================
  // CARICA UN SINGOLO SERVIZIO GESTITO
  // =========================================================

  static Future<ManagedService?> loadManagedService(String serviceId) async {
    final document = await _firestore
        .collection(_managedServicesCollection)
        .doc(serviceId)
        .get();

    if (!document.exists) {
      return null;
    }

    final data = document.data();

    if (data == null) {
      return null;
    }

    return _managedServiceFromMap(document.id, data);
  }

  // =========================================================
  // ELIMINA UN SERVIZIO GESTITO
  // =========================================================

  static Future<void> deleteManagedService(String serviceId) async {
    await _firestore
        .collection(_managedServicesCollection)
        .doc(serviceId)
        .delete();
  }

  // =========================================================
  // ATTIVA O DISATTIVA UN SERVIZIO
  // =========================================================

  static Future<void> setManagedServiceActive({
    required String serviceId,
    required bool isActive,
  }) async {
    await _firestore.collection(_managedServicesCollection).doc(serviceId).set({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // =========================================================
  // SERVICE AVAILABILITY -> MAP
  // =========================================================

  static Map<String, dynamic> _serviceToMap(ServiceAvailability service) {
    return {
      'id': service.id,
      'name': service.name,
      'isOpen': service.isOpen,
      'startTime': service.startTime,
      'endTime': service.endTime,
      'maxOnlineGuests': service.maxOnlineGuests,
      'slotIntervalMinutes': service.slotIntervalMinutes,
      'blockedRanges': service.blockedRanges
          .map((range) => range.toMap())
          .toList(),
    };
  }

  // =========================================================
  // MAP -> SERVICE AVAILABILITY
  // =========================================================

  static ServiceAvailability _serviceFromMap(Map<String, dynamic> data) {
    return ServiceAvailability.fromMap(data);
  }

  // =========================================================
  // MAP -> ECCEZIONE PRECEDENTE
  // =========================================================

  static DateAvailabilityException _exceptionFromMap(
    Map<String, dynamic> data,
  ) {
    final dateValue = data['date'];

    return DateAvailabilityException(
      date: _dateTimeFromValue(dateValue) ?? DateTime.now(),
      lunch: _serviceFromMap(
        Map<String, dynamic>.from(data['lunch'] as Map? ?? {}),
      ),
      dinner: _serviceFromMap(
        Map<String, dynamic>.from(data['dinner'] as Map? ?? {}),
      ),
    );
  }

  // =========================================================
  // SERVIZIO GESTITO -> MAP
  // =========================================================

  static Map<String, dynamic> _managedServiceToMap(ManagedService service) {
    return {
      'id': service.id,
      'name': service.name,
      'scheduleType': service.scheduleType.name,
      'restaurantServiceType': service.restaurantServiceType.name,
      'isActive': service.isActive,
      'isOpen': service.isOpen,
      'startDate': service.startDate == null
          ? null
          : Timestamp.fromDate(_normalizeDate(service.startDate!)),
      'endDate': service.endDate == null
          ? null
          : Timestamp.fromDate(_normalizeDate(service.endDate!)),
      'specificDate': service.specificDate == null
          ? null
          : Timestamp.fromDate(_normalizeDate(service.specificDate!)),
      'weekdays': service.weekdays,
      'startTime': service.startTime,
      'endTime': service.endTime,
      'slotIntervalMinutes': service.slotIntervalMinutes,
      'maxOnlineGuests': service.maxOnlineGuests,
      'blockedRanges': service.blockedRanges
          .map((range) => range.toMap())
          .toList(),
    };
  }

  // =========================================================
  // MAP -> SERVIZIO GESTITO
  // =========================================================

  static ManagedService _managedServiceFromMap(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final weekdaysData = data['weekdays'] as List<dynamic>? ?? [];

    final blockedRangesData = data['blockedRanges'] as List<dynamic>? ?? [];

    return ManagedService(
      id: data['id'] as String? ?? documentId,
      name: data['name'] as String? ?? 'Servizio',
      scheduleType: _scheduleTypeFromText(data['scheduleType'] as String?),
      restaurantServiceType: _restaurantServiceTypeFromText(
        data['restaurantServiceType'] as String?,
      ),
      isActive: data['isActive'] as bool? ?? true,
      isOpen: data['isOpen'] as bool? ?? true,
      startDate: _dateTimeFromValue(data['startDate']),
      endDate: _dateTimeFromValue(data['endDate']),
      specificDate: _dateTimeFromValue(data['specificDate']),
      weekdays: weekdaysData.map((item) => (item as num).toInt()).toList(),
      startTime: data['startTime'] as String? ?? '19:00',
      endTime: data['endTime'] as String? ?? '23:30',
      slotIntervalMinutes: (data['slotIntervalMinutes'] as num?)?.toInt() ?? 15,
      maxOnlineGuests: (data['maxOnlineGuests'] as num?)?.toInt() ?? 80,
      blockedRanges: blockedRangesData
          .map(
            (item) => BlockedTimeRange.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  // =========================================================
  // CONVERSIONE TIPO PROGRAMMAZIONE
  // =========================================================

  static ServiceScheduleType _scheduleTypeFromText(String? value) {
    switch (value) {
      case 'specificDate':
        return ServiceScheduleType.specificDate;
      case 'annual':
      default:
        return ServiceScheduleType.annual;
    }
  }

  // =========================================================
  // CONVERSIONE TIPO SERVIZIO
  // =========================================================

  static RestaurantServiceType _restaurantServiceTypeFromText(String? value) {
    switch (value) {
      case 'lunch':
        return RestaurantServiceType.lunch;
      case 'dinner':
        return RestaurantServiceType.dinner;
      case 'custom':
      default:
        return RestaurantServiceType.custom;
    }
  }

  // =========================================================
  // CONVERSIONE DATA FIREBASE
  // =========================================================

  static DateTime? _dateTimeFromValue(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return _normalizeDate(value.toDate());
    }

    if (value is DateTime) {
      return _normalizeDate(value);
    }

    if (value is String) {
      final parsed = DateTime.tryParse(value);

      if (parsed == null) {
        return null;
      }

      return _normalizeDate(parsed);
    }

    return null;
  }

  // =========================================================
  // NORMALIZZA DATA
  // =========================================================

  static DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // =========================================================
  // ID DATA
  // =========================================================

  static String _dateId(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');

    final month = date.month.toString().padLeft(2, '0');

    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
