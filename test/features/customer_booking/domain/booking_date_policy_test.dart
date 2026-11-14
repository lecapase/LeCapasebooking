import 'package:flutter_test/flutter_test.dart';
import 'package:lecapase_booking/features/customer_booking/domain/booking_date_policy.dart';

void main() {
  group('BookingDatePolicy.endOfDay', () {
    test('conserva il giorno e usa l’ultimo istante locale', () {
      final result = BookingDatePolicy.endOfDay(DateTime(2026, 11, 14, 8, 30));

      expect(result, DateTime(2026, 11, 14, 23, 59, 59, 999, 999));
      expect(result.isUtc, isFalse);
    });

    test('non sposta la data alla giornata successiva', () {
      final result = BookingDatePolicy.endOfDay(DateTime(2026, 12, 31, 23, 59));

      expect(result.year, 2026);
      expect(result.month, 12);
      expect(result.day, 31);
    });
  });
}
