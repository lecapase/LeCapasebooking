import 'package:flutter_test/flutter_test.dart';
import 'package:lecapase_booking/features/reports/monthly_report.dart';

Map<String, dynamic> booking(
  String date,
  String status, {
  String phone = '3331234567',
  dynamic guests = 2,
}) => {'dateKey': date, 'status': status, 'telefono': phone, 'guests': guests};

void main() {
  test('counts actual visits and covers, not open or cancelled bookings', () {
    final report = MonthlyReport.fromBookings({
      'a': booking('2026-09-01', 'arrived', guests: 3),
      'b': booking('2026-09-02', 'released', guests: '4'),
      'c': booking('2026-09-03', 'completed'),
      'd': booking('2026-09-04', 'cancelled', guests: 5),
      'e': booking('2026-09-05', 'no_show', guests: 6),
      'f': booking('2026-09-06', 'confirmed', guests: 20),
      'g': booking('2026-09-07', 'rejected'),
    }, DateTime(2026, 9));
    expect(report.bookings, 7);
    expect(report.visits, 3);
    expect(report.servedCovers, 9);
    expect(report.cancellations, 1);
    expect(report.cancelledCovers, 5);
    expect(report.noShows, 1);
    expect(report.noShowCovers, 6);
    expect(report.unresolved, 1);
    expect(report.rejected, 1);
    expect(report.newCustomers, 1);
  });
  test(
    'deduplicates visitors and only prior visits make returning customers',
    () {
      final report = MonthlyReport.fromBookings({
        'old': booking('2026-08-31', 'released'),
        'old-cancel': booking('2026-08-15', 'cancelled', phone: '222'),
        'a': booking('2026-09-01', 'completed'),
        'b': booking('2026-09-02', 'released', phone: '+39 3331234567'),
        'c': booking('2026-09-03', 'released', phone: '222'),
        'd': booking('2026-09-04', 'released', phone: '222'),
        'missing': booking('2026-09-04', 'released', phone: ''),
      }, DateTime(2026, 9));
      expect(report.returningCustomers, 1);
      expect(report.newCustomers, 1);
      expect(report.unidentifiedVisits, 1);
      expect(report.visits, 5);
    },
  );
  test('handles year boundaries and invalid dates without misattribution', () {
    final report = MonthlyReport.fromBookings({
      'before': booking('2025-12-31', 'released'),
      'start': booking('2026-01-01', 'released'),
      'end': booking('2026-01-31', 'released'),
      'after': booking('2026-02-01', 'released'),
      'invalid': booking('2026-01-32', 'released'),
      'missing': {'status': 'released'},
    }, DateTime(2026, 1));
    expect(report.visits, 2);
    expect(report.returningCustomers, 1);
    expect(report.invalidDates, 2);
  });
  test('historical status corrections recalculate no-shows and visits', () {
    final records = {'a': booking('2026-09-01', 'no_show')};
    expect(MonthlyReport.fromBookings(records, DateTime(2026, 9)).noShows, 1);
    records['a']!['status'] = 'released';
    final report = MonthlyReport.fromBookings(records, DateTime(2026, 9));
    expect(report.noShows, 0);
    expect(report.visits, 1);
    expect(report.newCustomers, 1);
  });
  test('empty months and invalid guest counts remain explicit', () {
    expect(MonthlyReport.fromBookings({}, DateTime(2026, 9)).bookings, 0);
    final report = MonthlyReport.fromBookings({
      'a': booking('2026-09-01', 'released', guests: -3),
      'b': booking('2026-09-02', 'released', guests: null),
    }, DateTime(2026, 9));
    expect(report.servedCovers, 0);
    expect(report.visitsWithoutCovers, 2);
  });
}
