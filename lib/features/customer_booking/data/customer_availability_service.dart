import '../../availability/data/availability_repository.dart';
import '../../availability/data/firestore_availability_repository.dart';
import '../../availability/models/service_availability.dart';

class CustomerAvailabilityService {
  CustomerAvailabilityService._();

  // =========================================================
  // DISPONIBILITÀ EFFETTIVA PER UNA DATA
  // =========================================================

  static Future<DayAvailability?> getAvailabilityForDate(DateTime date) async {
    final normalizedDate = AvailabilityRepository.normalizeDate(date);

    final managedServices =
        await FirestoreAvailabilityRepository.loadManagedServices();

    if (managedServices.isNotEmpty) {
      AvailabilityRepository.replaceManagedServices(managedServices);

      return _availabilityFromManagedServices(normalizedDate);
    }

    return _loadLegacyAvailability(normalizedDate);
  }

  // =========================================================
  // CONVERSIONE NUOVI SERVIZI -> DISPONIBILITÀ CLIENTE
  // =========================================================

  static DayAvailability _availabilityFromManagedServices(DateTime date) {
    final effectiveServices =
        AvailabilityRepository.getEffectiveServicesForDate(date);

    final lunch = _closedService(
      id: 'lunch',
      name: 'Pranzo',
      startTime: '12:30',
      endTime: '14:15',
    );

    final dinner = _closedService(
      id: 'dinner',
      name: 'Cena',
      startTime: '19:00',
      endTime: '23:30',
    );

    for (final managedService in effectiveServices) {
      if (!managedService.isActive) {
        continue;
      }

      switch (managedService.restaurantServiceType) {
        case RestaurantServiceType.lunch:
          _applyManagedService(source: managedService, destination: lunch);

        case RestaurantServiceType.dinner:
          _applyManagedService(source: managedService, destination: dinner);

        case RestaurantServiceType.custom:
          break;
      }
    }

    return DayAvailability(
      weekday: date.weekday,
      name: _dayName(date.weekday),
      lunch: lunch,
      dinner: dinner,
    );
  }

  // =========================================================
  // APPLICA SERVIZIO GESTITO
  // =========================================================

  static void _applyManagedService({
    required ManagedService source,
    required ServiceAvailability destination,
  }) {
    destination.isOpen = source.isActive && source.isOpen;

    destination.startTime = source.startTime;

    destination.endTime = source.endTime;

    destination.maxOnlineGuests = source.maxOnlineGuests;

    destination.slotIntervalMinutes = source.slotIntervalMinutes;

    destination.blockedRanges = source.blockedRanges
        .map((range) => range.copy())
        .toList();
  }

  // =========================================================
  // SERVIZIO CHIUSO
  // =========================================================

  static ServiceAvailability _closedService({
    required String id,
    required String name,
    required String startTime,
    required String endTime,
  }) {
    return ServiceAvailability(
      id: id,
      name: name,
      isOpen: false,
      startTime: startTime,
      endTime: endTime,
      maxOnlineGuests: 0,
      slotIntervalMinutes: 15,
    );
  }

  // =========================================================
  // SISTEMA PRECEDENTE
  // =========================================================

  static Future<DayAvailability?> _loadLegacyAvailability(DateTime date) async {
    final exception = await FirestoreAvailabilityRepository.loadException(date);

    if (exception != null) {
      return DayAvailability(
        weekday: date.weekday,
        name: _dayName(date.weekday),
        lunch: exception.lunch,
        dinner: exception.dinner,
      );
    }

    final weeklyDays = await FirestoreAvailabilityRepository.loadWeeklyDays();

    if (weeklyDays.isEmpty) {
      return null;
    }

    for (final day in weeklyDays) {
      if (day.weekday == date.weekday) {
        return day;
      }
    }

    return null;
  }

  // =========================================================
  // GENERA GLI ORARI PRENOTABILI
  // =========================================================

  static List<String> generateAvailableTimes(
    ServiceAvailability service, {
    required DateTime date,
  }) {
    if (!service.isOpen) {
      return [];
    }

    final startMinutes = _toMinutes(service.startTime);
    final endMinutes = _toMinutes(service.endTime);

    final interval = service.slotIntervalMinutes > 0
        ? service.slotIntervalMinutes
        : 15;

    if (endMinutes <= startMinutes) {
      return [];
    }

    final times = <String>[];

    final now = DateTime.now();

    final selectedDate = DateTime(date.year, date.month, date.day);

    final today = DateTime(now.year, now.month, now.day);

    final isToday = selectedDate == today;
    final currentMinutes = now.hour * 60 + now.minute;

    for (
      int minutes = startMinutes;
      minutes <= endMinutes;
      minutes += interval
    ) {
      final time = _fromMinutes(minutes);

      if (isToday && minutes <= currentMinutes) {
        continue;
      }

      if (!isTimeBlocked(service: service, time: time)) {
        times.add(time);
      }
    }

    return times;
  }

  // =========================================================
  // ORARIO BLOCCATO?
  //
  // Controlla:
  // 1. intervallo del servizio;
  // 2. fasce bloccate manualmente.
  // =========================================================

  static bool isTimeBlocked({
    required ServiceAvailability service,
    required String time,
  }) {
    final timeMinutes = _toMinutes(time);
    final startMinutes = _toMinutes(service.startTime);

    final interval = service.slotIntervalMinutes > 0
        ? service.slotIntervalMinutes
        : 15;

    if (timeMinutes < startMinutes) {
      return true;
    }

    final difference = timeMinutes - startMinutes;

    if (difference % interval != 0) {
      return true;
    }

    for (final range in service.blockedRanges) {
      final start = _toMinutes(range.startTime);

      final end = _toMinutes(range.endTime);

      if (timeMinutes >= start && timeMinutes < end) {
        return true;
      }
    }

    return false;
  }

  // =========================================================
  // CONVERSIONE ORARIO -> MINUTI
  // =========================================================

  static int _toMinutes(String value) {
    final parts = value.split(':');

    if (parts.length != 2) {
      return 0;
    }

    final hour = int.tryParse(parts[0]) ?? 0;

    final minute = int.tryParse(parts[1]) ?? 0;

    return hour * 60 + minute;
  }

  // =========================================================
  // CONVERSIONE MINUTI -> ORARIO
  // =========================================================

  static String _fromMinutes(int value) {
    final hour = value ~/ 60;
    final minute = value % 60;

    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  // =========================================================
  // NOME DEL GIORNO
  // =========================================================

  static String _dayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Lunedì';

      case DateTime.tuesday:
        return 'Martedì';

      case DateTime.wednesday:
        return 'Mercoledì';

      case DateTime.thursday:
        return 'Giovedì';

      case DateTime.friday:
        return 'Venerdì';

      case DateTime.saturday:
        return 'Sabato';

      case DateTime.sunday:
        return 'Domenica';

      default:
        return '';
    }
  }
}
