// ===========================================================
// TIPO DI PROGRAMMAZIONE
// ===========================================================

enum ServiceScheduleType { annual, specificDate }

// ===========================================================
// TIPO DI SERVIZIO
// ===========================================================

enum RestaurantServiceType { lunch, dinner, custom }

// ===========================================================
// FASCIA ORARIA BLOCCATA
// ===========================================================

class BlockedTimeRange {
  final String startTime;
  final String endTime;

  const BlockedTimeRange({required this.startTime, required this.endTime});

  BlockedTimeRange copy() {
    return BlockedTimeRange(startTime: startTime, endTime: endTime);
  }

  Map<String, dynamic> toMap() {
    return {'startTime': startTime, 'endTime': endTime};
  }

  factory BlockedTimeRange.fromMap(Map<String, dynamic> map) {
    return BlockedTimeRange(
      startTime: map['startTime'] as String? ?? '',
      endTime: map['endTime'] as String? ?? '',
    );
  }
}

// ===========================================================
// DISPONIBILITÀ DI PRANZO O CENA
// Manteniamo questa classe per compatibilità con le funzioni
// già presenti nell'app.
// ===========================================================

class ServiceAvailability {
  final String id;
  final String name;

  bool isOpen;
  String startTime;
  String endTime;
  int maxOnlineGuests;
  int slotIntervalMinutes;

  List<BlockedTimeRange> blockedRanges;

  ServiceAvailability({
    required this.id,
    required this.name,
    required this.isOpen,
    required this.startTime,
    required this.endTime,
    required this.maxOnlineGuests,
    this.slotIntervalMinutes = 15,
    List<BlockedTimeRange>? blockedRanges,
  }) : blockedRanges = blockedRanges ?? [];

  ServiceAvailability copy() {
    return ServiceAvailability(
      id: id,
      name: name,
      isOpen: isOpen,
      startTime: startTime,
      endTime: endTime,
      maxOnlineGuests: maxOnlineGuests,
      slotIntervalMinutes: slotIntervalMinutes,
      blockedRanges: blockedRanges.map((range) => range.copy()).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isOpen': isOpen,
      'startTime': startTime,
      'endTime': endTime,
      'maxOnlineGuests': maxOnlineGuests,
      'slotIntervalMinutes': slotIntervalMinutes,
      'blockedRanges': blockedRanges.map((range) => range.toMap()).toList(),
    };
  }

  factory ServiceAvailability.fromMap(Map<String, dynamic> map) {
    final blockedRangesData = map['blockedRanges'] as List<dynamic>? ?? [];

    return ServiceAvailability(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      isOpen: map['isOpen'] as bool? ?? true,
      startTime: map['startTime'] as String? ?? '',
      endTime: map['endTime'] as String? ?? '',
      maxOnlineGuests: (map['maxOnlineGuests'] as num?)?.toInt() ?? 80,
      slotIntervalMinutes: (map['slotIntervalMinutes'] as num?)?.toInt() ?? 15,
      blockedRanges: blockedRangesData
          .map(
            (item) => BlockedTimeRange.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

// ===========================================================
// DISPONIBILITÀ DI UN GIORNO DELLA SETTIMANA
// Manteniamo questa classe per compatibilità.
// ===========================================================

class DayAvailability {
  final int weekday;
  final String name;

  ServiceAvailability lunch;
  ServiceAvailability dinner;

  DayAvailability({
    required this.weekday,
    required this.name,
    required this.lunch,
    required this.dinner,
  });

  DayAvailability copy() {
    return DayAvailability(
      weekday: weekday,
      name: name,
      lunch: lunch.copy(),
      dinner: dinner.copy(),
    );
  }
}

// ===========================================================
// ECCEZIONE PER DATA
// Manteniamo questa classe per compatibilità.
// ===========================================================

class DateAvailabilityException {
  final DateTime date;

  ServiceAvailability lunch;
  ServiceAvailability dinner;

  DateAvailabilityException({
    required this.date,
    required this.lunch,
    required this.dinner,
  });
}

// ===========================================================
// NUOVO SERVIZIO GESTITO
// Questa è la struttura simile alla logica di TheFork Manager.
// ===========================================================

class ManagedService {
  final String id;

  String name;
  ServiceScheduleType scheduleType;
  RestaurantServiceType restaurantServiceType;

  bool isActive;
  bool isOpen;

  DateTime? startDate;
  DateTime? endDate;
  DateTime? specificDate;

  List<int> weekdays;

  String startTime;
  String endTime;

  int slotIntervalMinutes;
  int maxOnlineGuests;

  List<BlockedTimeRange> blockedRanges;

  ManagedService({
    required this.id,
    required this.name,
    required this.scheduleType,
    required this.restaurantServiceType,
    required this.isActive,
    required this.isOpen,
    required this.startTime,
    required this.endTime,
    required this.slotIntervalMinutes,
    required this.maxOnlineGuests,
    this.startDate,
    this.endDate,
    this.specificDate,
    List<int>? weekdays,
    List<BlockedTimeRange>? blockedRanges,
  }) : weekdays = weekdays ?? [],
       blockedRanges = blockedRanges ?? [];

  bool get isAnnual {
    return scheduleType == ServiceScheduleType.annual;
  }

  bool get isSpecificDate {
    return scheduleType == ServiceScheduleType.specificDate;
  }

  bool appliesToDate(DateTime date) {
    if (!isActive) {
      return false;
    }

    final normalizedDate = DateTime(date.year, date.month, date.day);

    if (isSpecificDate) {
      if (specificDate == null) {
        return false;
      }

      return _isSameDate(specificDate!, normalizedDate);
    }

    if (startDate != null) {
      final normalizedStartDate = DateTime(
        startDate!.year,
        startDate!.month,
        startDate!.day,
      );

      if (normalizedDate.isBefore(normalizedStartDate)) {
        return false;
      }
    }

    if (endDate != null) {
      final normalizedEndDate = DateTime(
        endDate!.year,
        endDate!.month,
        endDate!.day,
      );

      if (normalizedDate.isAfter(normalizedEndDate)) {
        return false;
      }
    }

    return weekdays.contains(normalizedDate.weekday);
  }

  ManagedService copy() {
    return ManagedService(
      id: id,
      name: name,
      scheduleType: scheduleType,
      restaurantServiceType: restaurantServiceType,
      isActive: isActive,
      isOpen: isOpen,
      startDate: startDate == null
          ? null
          : DateTime(startDate!.year, startDate!.month, startDate!.day),
      endDate: endDate == null
          ? null
          : DateTime(endDate!.year, endDate!.month, endDate!.day),
      specificDate: specificDate == null
          ? null
          : DateTime(
              specificDate!.year,
              specificDate!.month,
              specificDate!.day,
            ),
      weekdays: List<int>.from(weekdays),
      startTime: startTime,
      endTime: endTime,
      slotIntervalMinutes: slotIntervalMinutes,
      maxOnlineGuests: maxOnlineGuests,
      blockedRanges: blockedRanges.map((range) => range.copy()).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'scheduleType': scheduleType.name,
      'restaurantServiceType': restaurantServiceType.name,
      'isActive': isActive,
      'isOpen': isOpen,
      'startDate': _dateToText(startDate),
      'endDate': _dateToText(endDate),
      'specificDate': _dateToText(specificDate),
      'weekdays': weekdays,
      'startTime': startTime,
      'endTime': endTime,
      'slotIntervalMinutes': slotIntervalMinutes,
      'maxOnlineGuests': maxOnlineGuests,
      'blockedRanges': blockedRanges.map((range) => range.toMap()).toList(),
    };
  }

  factory ManagedService.fromMap(Map<String, dynamic> map) {
    final weekdaysData = map['weekdays'] as List<dynamic>? ?? [];

    final blockedRangesData = map['blockedRanges'] as List<dynamic>? ?? [];

    return ManagedService(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Servizio',
      scheduleType: _scheduleTypeFromText(map['scheduleType'] as String?),
      restaurantServiceType: _restaurantServiceTypeFromText(
        map['restaurantServiceType'] as String?,
      ),
      isActive: map['isActive'] as bool? ?? true,
      isOpen: map['isOpen'] as bool? ?? true,
      startDate: _dateFromValue(map['startDate']),
      endDate: _dateFromValue(map['endDate']),
      specificDate: _dateFromValue(map['specificDate']),
      weekdays: weekdaysData.map((item) => (item as num).toInt()).toList(),
      startTime: map['startTime'] as String? ?? '19:00',
      endTime: map['endTime'] as String? ?? '23:30',
      slotIntervalMinutes: (map['slotIntervalMinutes'] as num?)?.toInt() ?? 15,
      maxOnlineGuests: (map['maxOnlineGuests'] as num?)?.toInt() ?? 80,
      blockedRanges: blockedRangesData
          .map(
            (item) => BlockedTimeRange.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  static ServiceScheduleType _scheduleTypeFromText(String? value) {
    switch (value) {
      case 'specificDate':
        return ServiceScheduleType.specificDate;
      case 'annual':
      default:
        return ServiceScheduleType.annual;
    }
  }

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

  static String? _dateToText(DateTime? date) {
    if (date == null) {
      return null;
    }

    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  static DateTime? _dateFromValue(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return DateTime(value.year, value.month, value.day);
    }

    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  static bool _isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
