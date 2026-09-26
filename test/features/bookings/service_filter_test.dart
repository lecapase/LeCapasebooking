import 'package:flutter_test/flutter_test.dart';
import 'package:lecapase_booking/features/bookings/service_filter.dart';

void main() {
  test('today defaults to lunch before 16:00 and dinner from 16:00', () {
    final date = DateTime(2026, 9, 27);
    for (final hour in [0, 12, 15, 16, 20, 23]) {
      expect(
        initialServiceFilter(date, DateTime(2026, 9, 27, hour, 59)),
        hour < 16 ? 'lunch' : 'dinner',
      );
    }
    expect(initialServiceFilter(date, DateTime(2026, 9, 27, 16)), 'dinner');
  });
  test('past and future dates default to all, including across years', () {
    final now = DateTime(2026, 1, 1, 20, 30);
    for (final date in [
      DateTime(2025, 12, 31),
      DateTime(2026, 1, 2),
      DateTime(2027, 1, 1),
    ]) {
      expect(initialServiceFilter(date, now), 'all');
    }
  });
}
