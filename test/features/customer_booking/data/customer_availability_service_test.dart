import 'package:flutter_test/flutter_test.dart';
import 'package:lecapase_booking/features/availability/models/service_availability.dart';
import 'package:lecapase_booking/features/customer_booking/data/customer_availability_service.dart';

void main() {
  ServiceAvailability service({
    bool isOpen = true,
    String startTime = '19:00',
    String endTime = '20:00',
    int interval = 15,
    List<BlockedTimeRange> blockedRanges = const [],
  }) {
    return ServiceAvailability(
      id: 'dinner',
      name: 'Cena',
      isOpen: isOpen,
      startTime: startTime,
      endTime: endTime,
      maxOnlineGuests: 80,
      slotIntervalMinutes: interval,
      blockedRanges: blockedRanges,
    );
  }

  group('CustomerAvailabilityService.generateAvailableTimes', () {
    final futureDate = DateTime(2100, 1, 1);

    test('genera gli slot includendo inizio e fine del servizio', () {
      final times = CustomerAvailabilityService.generateAvailableTimes(
        service(),
        date: futureDate,
      );

      expect(times, ['19:00', '19:15', '19:30', '19:45', '20:00']);
    });

    test('restituisce una lista vuota per un servizio chiuso', () {
      final times = CustomerAvailabilityService.generateAvailableTimes(
        service(isOpen: false),
        date: futureDate,
      );

      expect(times, isEmpty);
    });

    test('restituisce una lista vuota quando la fine precede l’inizio', () {
      final times = CustomerAvailabilityService.generateAvailableTimes(
        service(startTime: '20:00', endTime: '19:00'),
        date: futureDate,
      );

      expect(times, isEmpty);
    });

    test('usa quindici minuti quando l’intervallo non è positivo', () {
      final times = CustomerAvailabilityService.generateAvailableTimes(
        service(interval: 0),
        date: futureDate,
      );

      expect(times, ['19:00', '19:15', '19:30', '19:45', '20:00']);
    });

    test('esclude gli slot nelle fasce bloccate con fine esclusiva', () {
      final times = CustomerAvailabilityService.generateAvailableTimes(
        service(
          blockedRanges: const [
            BlockedTimeRange(startTime: '19:15', endTime: '19:45'),
          ],
        ),
        date: futureDate,
      );

      expect(times, ['19:00', '19:45', '20:00']);
    });
  });

  group('CustomerAvailabilityService.isTimeBlocked', () {
    test('blocca un orario precedente all’inizio', () {
      expect(
        CustomerAvailabilityService.isTimeBlocked(
          service: service(),
          time: '18:45',
        ),
        isTrue,
      );
    });

    test('blocca un orario non allineato all’intervallo', () {
      expect(
        CustomerAvailabilityService.isTimeBlocked(
          service: service(interval: 30),
          time: '19:15',
        ),
        isTrue,
      );
    });

    test('considera bloccato l’inizio ma non la fine di una fascia', () {
      final configuredService = service(
        blockedRanges: const [
          BlockedTimeRange(startTime: '19:15', endTime: '19:45'),
        ],
      );

      expect(
        CustomerAvailabilityService.isTimeBlocked(
          service: configuredService,
          time: '19:15',
        ),
        isTrue,
      );
      expect(
        CustomerAvailabilityService.isTimeBlocked(
          service: configuredService,
          time: '19:45',
        ),
        isFalse,
      );
    });
  });
}
