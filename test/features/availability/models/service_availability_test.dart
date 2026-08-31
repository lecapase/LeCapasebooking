import 'package:flutter_test/flutter_test.dart';
import 'package:lecapase_booking/features/availability/models/service_availability.dart';

void main() {
  group('BlockedTimeRange', () {
    test('mantiene gli orari nella conversione mappa', () {
      const range = BlockedTimeRange(startTime: '20:00', endTime: '20:30');

      final restored = BlockedTimeRange.fromMap(range.toMap());

      expect(restored.startTime, '20:00');
      expect(restored.endTime, '20:30');
    });
  });

  group('ServiceAvailability', () {
    test('esegue il round trip completo', () {
      final service = ServiceAvailability(
        id: 'dinner',
        name: 'Cena',
        isOpen: true,
        startTime: '19:00',
        endTime: '23:30',
        maxOnlineGuests: 80,
        slotIntervalMinutes: 30,
        blockedRanges: const [
          BlockedTimeRange(startTime: '20:00', endTime: '20:30'),
        ],
      );

      final restored = ServiceAvailability.fromMap(service.toMap());

      expect(restored.id, 'dinner');
      expect(restored.name, 'Cena');
      expect(restored.isOpen, isTrue);
      expect(restored.startTime, '19:00');
      expect(restored.endTime, '23:30');
      expect(restored.maxOnlineGuests, 80);
      expect(restored.slotIntervalMinutes, 30);
      expect(restored.blockedRanges, hasLength(1));
      expect(restored.blockedRanges.single.startTime, '20:00');
    });

    test('la copia non condivide la lista delle fasce bloccate', () {
      final original = ServiceAvailability(
        id: 'lunch',
        name: 'Pranzo',
        isOpen: true,
        startTime: '12:00',
        endTime: '15:00',
        maxOnlineGuests: 40,
        blockedRanges: const [
          BlockedTimeRange(startTime: '13:00', endTime: '13:15'),
        ],
      );

      final copied = original.copy()..blockedRanges.clear();

      expect(original.blockedRanges, hasLength(1));
      expect(copied.blockedRanges, isEmpty);
    });
  });

  group('ManagedService.appliesToDate', () {
    ManagedService annualService({
      bool isActive = true,
      DateTime? startDate,
      DateTime? endDate,
      List<int>? weekdays,
    }) {
      return ManagedService(
        id: 'annual-dinner',
        name: 'Cena annuale',
        scheduleType: ServiceScheduleType.annual,
        restaurantServiceType: RestaurantServiceType.dinner,
        isActive: isActive,
        isOpen: true,
        startDate: startDate,
        endDate: endDate,
        weekdays: weekdays ?? const [5, 6],
        startTime: '19:00',
        endTime: '23:30',
        slotIntervalMinutes: 15,
        maxOnlineGuests: 80,
      );
    }

    test('accetta un giorno configurato dentro l’intervallo inclusivo', () {
      final service = annualService(
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
      );

      expect(service.appliesToDate(DateTime(2026, 9, 4, 22)), isTrue);
      expect(service.appliesToDate(DateTime(2026, 9, 5)), isTrue);
    });

    test('rifiuta giorni non configurati o esterni all’intervallo', () {
      final service = annualService(
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
      );

      expect(service.appliesToDate(DateTime(2026, 9, 3)), isFalse);
      expect(service.appliesToDate(DateTime(2026, 8, 29)), isFalse);
      expect(service.appliesToDate(DateTime(2026, 10, 2)), isFalse);
    });

    test('rifiuta sempre un servizio non attivo', () {
      final service = annualService(isActive: false);

      expect(service.appliesToDate(DateTime(2026, 9, 4)), isFalse);
    });

    test('la data specifica ignora l’orario ma non il giorno', () {
      final service = ManagedService(
        id: 'special-lunch',
        name: 'Pranzo speciale',
        scheduleType: ServiceScheduleType.specificDate,
        restaurantServiceType: RestaurantServiceType.lunch,
        isActive: true,
        isOpen: true,
        specificDate: DateTime(2026, 12, 25),
        startTime: '12:00',
        endTime: '15:00',
        slotIntervalMinutes: 15,
        maxOnlineGuests: 50,
      );

      expect(service.appliesToDate(DateTime(2026, 12, 25, 23, 59)), isTrue);
      expect(service.appliesToDate(DateTime(2026, 12, 24)), isFalse);
    });

    test('una data specifica mancante non è applicabile', () {
      final service = ManagedService(
        id: 'invalid-special',
        name: 'Speciale',
        scheduleType: ServiceScheduleType.specificDate,
        restaurantServiceType: RestaurantServiceType.custom,
        isActive: true,
        isOpen: true,
        startTime: '18:00',
        endTime: '20:00',
        slotIntervalMinutes: 15,
        maxOnlineGuests: 20,
      );

      expect(service.appliesToDate(DateTime(2026, 9, 1)), isFalse);
    });
  });

  group('ManagedService conversione', () {
    test('preserva configurazione, date e fasce bloccate', () {
      final service = ManagedService(
        id: 'summer-lunch',
        name: 'Pranzo estivo',
        scheduleType: ServiceScheduleType.annual,
        restaurantServiceType: RestaurantServiceType.lunch,
        isActive: true,
        isOpen: true,
        startDate: DateTime(2026, 6, 1, 14),
        endDate: DateTime(2026, 9, 30, 22),
        weekdays: const [1, 2, 3, 4, 5],
        startTime: '12:00',
        endTime: '15:00',
        slotIntervalMinutes: 30,
        maxOnlineGuests: 60,
        blockedRanges: const [
          BlockedTimeRange(startTime: '13:00', endTime: '13:30'),
        ],
      );

      final map = service.toMap();
      final restored = ManagedService.fromMap(map);

      expect(map['startDate'], '2026-06-01');
      expect(map['endDate'], '2026-09-30');
      expect(restored.id, service.id);
      expect(restored.scheduleType, ServiceScheduleType.annual);
      expect(restored.restaurantServiceType, RestaurantServiceType.lunch);
      expect(restored.weekdays, [1, 2, 3, 4, 5]);
      expect(restored.startDate, DateTime(2026, 6, 1));
      expect(restored.endDate, DateTime(2026, 9, 30));
      expect(restored.slotIntervalMinutes, 30);
      expect(restored.maxOnlineGuests, 60);
      expect(restored.blockedRanges, hasLength(1));
    });

    test('usa valori predefiniti per una mappa vuota', () {
      final service = ManagedService.fromMap(const <String, dynamic>{});

      expect(service.id, isEmpty);
      expect(service.name, 'Servizio');
      expect(service.scheduleType, ServiceScheduleType.annual);
      expect(service.restaurantServiceType, RestaurantServiceType.custom);
      expect(service.isActive, isTrue);
      expect(service.isOpen, isTrue);
      expect(service.startTime, '19:00');
      expect(service.endTime, '23:30');
      expect(service.slotIntervalMinutes, 15);
      expect(service.maxOnlineGuests, 80);
      expect(service.weekdays, isEmpty);
      expect(service.blockedRanges, isEmpty);
    });

    test('la copia mantiene liste e date indipendenti', () {
      final original = ManagedService(
        id: 'copy-test',
        name: 'Copia',
        scheduleType: ServiceScheduleType.annual,
        restaurantServiceType: RestaurantServiceType.custom,
        isActive: true,
        isOpen: true,
        startDate: DateTime(2026, 1, 1, 18),
        weekdays: const [1, 2],
        startTime: '18:00',
        endTime: '20:00',
        slotIntervalMinutes: 15,
        maxOnlineGuests: 10,
        blockedRanges: const [
          BlockedTimeRange(startTime: '19:00', endTime: '19:15'),
        ],
      );

      final copied = original.copy()
        ..weekdays.add(3)
        ..blockedRanges.clear();

      expect(copied.startDate, DateTime(2026, 1, 1));
      expect(original.weekdays, [1, 2]);
      expect(copied.weekdays, [1, 2, 3]);
      expect(original.blockedRanges, hasLength(1));
      expect(copied.blockedRanges, isEmpty);
    });
  });
}
