import 'package:flutter_test/flutter_test.dart';
import 'package:lecapase_booking/features/customer_booking/domain/booking_date_policy.dart';
import 'package:lecapase_booking/services/restaurant_clock.dart';

void main() {
  test('45 minute boundary, including seconds and a form left open', () {
    final date = DateTime(2026, 11, 23);
    final now = DateTime.utc(2026, 11, 23, 19); // 20:00 Rome
    expect(BookingDatePolicy.isBookable(date, '20:44', now: now), isFalse);
    expect(BookingDatePolicy.isBookable(date, '20:45', now: now), isTrue);
    expect(
      BookingDatePolicy.isBookable(
        date,
        '20:45',
        now: now.add(const Duration(seconds: 1)),
      ),
      isFalse,
    );
    expect(BookingDatePolicy.isBookable(date, '21:00', now: now), isTrue);
  });

  test('summer, midnight, past dates and invalid hours', () {
    final now = DateTime.utc(2026, 7, 1, 21, 30); // 23:30 Rome
    expect(
      BookingDatePolicy.isBookable(DateTime(2026, 7, 2), '00:15', now: now),
      isTrue,
    );
    expect(
      BookingDatePolicy.isBookable(DateTime(2026, 7, 2), '00:14', now: now),
      isFalse,
    );
    expect(
      BookingDatePolicy.isBookable(DateTime(2026, 6, 30), '23:30', now: now),
      isFalse,
    );
    expect(
      BookingDatePolicy.isBookable(DateTime(2027, 1, 1), '29:00', now: now),
      isFalse,
    );
  });

  test('Rome clock transitions and nonexistent spring hour', () {
    expect(RestaurantClock.civil(DateTime.utc(2026, 3, 29, 0, 59)).hour, 1);
    expect(RestaurantClock.civil(DateTime.utc(2026, 3, 29, 1)).hour, 3);
    expect(RestaurantClock.civil(DateTime.utc(2026, 10, 25, 0, 59)).hour, 2);
    expect(RestaurantClock.civil(DateTime.utc(2026, 10, 25, 1)).hour, 2);
    expect(RestaurantClock.appointment(DateTime(2026, 3, 29), '02:30'), isNull);
    expect(
      RestaurantClock.appointment(DateTime(2026, 10, 25), '02:30'),
      DateTime.utc(2026, 10, 25, 1, 30),
    );
  });

  test('creation label uses Rome time and correct date across midnight', () {
    expect(
      RestaurantClock.formatCreatedAt(DateTime.utc(2026, 11, 23, 23, 5)),
      '24/11/2026 alle 00:05',
    );
    expect(
      RestaurantClock.formatCreatedAt(DateTime.utc(2026, 7, 1, 18, 30)),
      '01/07/2026 alle 20:30',
    );
  });
}
