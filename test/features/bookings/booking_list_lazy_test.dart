// ignore_for_file: subtype_of_sealed_class
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecapase_booking/features/bookings/bookings_screen.dart';
import 'package:lecapase_booking/features/bookings/widgets/booking_card_heading.dart';

class _Booking extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Booking(this.index, this.date);
  final int index;
  final DateTime date;
  @override
  String get id => 'lazy-$index';
  @override
  Map<String, dynamic> data() => {
    'nome': 'Cliente',
    'cognome': index.toString().padLeft(3, '0'),
    'dateKey':
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    'time': '20:00',
    'service': date.hour < 16 ? 'lunch' : 'dinner',
    'status': 'confirmed',
    'guests': 2,
    'source': 'manual',
    'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 22, 17, 42)),
  };
}

class _Page extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  final records = List.generate(100, (i) => _Booking(i, DateTime.now()));
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => records;
}

void main() {
  testWidgets(
    'large slot builds only visible cards and exposes creation time',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final feed =
          StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
      await tester.pumpWidget(
        MaterialApp(
          home: BookingsScreen(
            displayName: 'Test',
            email: 'test@example.com',
            userRole: 'manager',
            bookingsStreamFactory: () => feed.stream,
          ),
        ),
      );
      feed.add(_Page());
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(
        find.byType(BookingCardHeading).evaluate().length,
        inInclusiveRange(1, 15),
      );
      expect(find.text('Prenotata il 22/11/2026 alle 18:42'), findsWidgets);
      expect(find.text('20:00 • 200p'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Cliente 090'),
        500,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cliente 090'), findsOneWidget);
      expect(find.byType(BookingCardHeading).evaluate().length, lessThan(20));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await feed.close();
    },
  );
}
