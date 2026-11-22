import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecapase_booking/features/bookings/calendar_totals.dart';
import 'package:lecapase_booking/features/bookings/widgets/monthly_booking_calendar.dart';

void main() {
  final bookings = [
    for (final (service, status, guests) in [
      ('lunch', 'confirmed', 4),
      ('dinner', 'booked', 2),
      ('lunch', 'completed', 3),
      ('dinner', 'released', 5),
      ('lunch', 'pending', 6),
      ('dinner', 'pending', 8),
      ('lunch', 'cancelled', 10),
      ('dinner', 'no_show', 10),
      ('lunch', 'rejected', 10),
    ])
      {
        'dateKey': '2026-11-25',
        'service': service,
        'status': status,
        'guests': guests,
      },
  ];
  test('separates services and pending; retains completed visits', () {
    final day = calendarTotals(bookings)['2026-11-25']!;
    expect(day.lunch.covers, 7);
    expect(day.dinner.covers, 7);
    expect(day.lunch.reservations, 2);
    expect(day.dinner.reservations, 2);
    expect(day.lunch.pendingCovers, 6);
    expect(day.dinner.pendingCovers, 8);
    expect(day.lunch.pendingReservations, 1);
  });
  testWidgets('calendar fits mobile and desktop and opens the selected day', (
    tester,
  ) async {
    for (final width in [390.0, 1200.0]) {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      DateTime? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MonthlyBookingCalendar(
              selectedDate: DateTime(2026, 11, 24),
              bookings: bookings,
              onMonth: (_) {},
              onDay: (date) => opened = date,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Totale mese: 14 coperti'), findsOneWidget);
      await tester.ensureVisible(find.text('25'));
      await tester.tap(find.text('25'));
      expect(opened, DateTime(2026, 11, 25));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
