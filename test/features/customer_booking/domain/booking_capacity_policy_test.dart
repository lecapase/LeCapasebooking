import 'package:flutter_test/flutter_test.dart';
import 'package:lecapase_booking/features/customer_booking/domain/booking_capacity_policy.dart';

void main() {
  group('BookingCapacityPolicy.remainingGuests', () {
    test('restituisce la differenza tra capienza e coperti occupati', () {
      expect(
        BookingCapacityPolicy.remainingGuests(maxGuests: 80, bookedGuests: 53),
        27,
      );
    });

    test('non restituisce valori negativi a capienza esaurita o superata', () {
      expect(
        BookingCapacityPolicy.remainingGuests(maxGuests: 80, bookedGuests: 80),
        0,
      );
      expect(
        BookingCapacityPolicy.remainingGuests(maxGuests: 80, bookedGuests: 84),
        0,
      );
    });
  });

  group('BookingCapacityPolicy.hasAvailability', () {
    test('è vero quando rimane almeno un posto', () {
      expect(
        BookingCapacityPolicy.hasAvailability(maxGuests: 80, bookedGuests: 79),
        isTrue,
      );
    });

    test('è falso quando il servizio è pieno o oltre capienza', () {
      expect(
        BookingCapacityPolicy.hasAvailability(maxGuests: 80, bookedGuests: 80),
        isFalse,
      );
      expect(
        BookingCapacityPolicy.hasAvailability(maxGuests: 80, bookedGuests: 81),
        isFalse,
      );
    });
  });

  group('BookingCapacityPolicy.hasCapacityForGuests', () {
    test('accetta un gruppo che raggiunge esattamente la capienza', () {
      expect(
        BookingCapacityPolicy.hasCapacityForGuests(
          maxGuests: 80,
          bookedGuests: 76,
          requestedGuests: 4,
        ),
        isTrue,
      );
    });

    test('rifiuta un gruppo che supera la capienza anche di un posto', () {
      expect(
        BookingCapacityPolicy.hasCapacityForGuests(
          maxGuests: 80,
          bookedGuests: 77,
          requestedGuests: 4,
        ),
        isFalse,
      );
    });
  });
}
