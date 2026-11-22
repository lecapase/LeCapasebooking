// ignore_for_file: subtype_of_sealed_class
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecapase_booking/features/bookings/bookings_screen.dart';

class _Booking extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Booking(this.index);
  final int index;
  @override
  String get id => 'booking-$index';
  @override
  Map<String, dynamic> data() => {
    'nome': 'Cliente',
    'cognome': '$index',
    'source': 'customer',
    'dateKey': '2026-10-25',
    'time': '20:00',
    'service': 'dinner',
    'status': 'confirmed',
    'guests': 2,
    'adminNotificationRead': false,
    'adminNotificationCreatedAt': Timestamp(10000 - index, 0),
  };
}

class _Page extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  final records = List.generate(60, _Booking.new);
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => records;
}

void main() {
  testWidgets(
    'selection and feed updates retain scroll; select all includes offscreen rows',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var listens = 0;
      final feed =
          StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast(
            onListen: () {
              listens++;
            },
          );
      final page = _Page();
      await tester.pumpWidget(
        MaterialApp(
          home: BookingsScreen(
            displayName: 'Test',
            email: 'test@example.com',
            userRole: 'manager',
            bookingsStreamFactory: () => feed.stream.map((page) => page),
          ),
        ),
      );
      feed.add(page);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notifiche').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seleziona'));
      await tester.pumpAndSettle();
      expect(listens, 1);
      final list = find.byKey(const PageStorageKey('booking-notifications'));
      final controller = tester.widget<ListView>(list).controller!;
      await tester.scrollUntilVisible(
        find.text('Cliente 35'),
        500,
        scrollable: find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        ),
      );
      final before = controller.offset;
      expect(before, greaterThan(1000));
      await tester.tap(find.text('Cliente 35'));
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(before, 1));
      expect(listens, 1);
      feed.add(page);
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(before, 1));
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('Elimina selezionate (1)'), findsOneWidget);
      await tester.tap(find.text('Seleziona tutte'));
      await tester.pumpAndSettle();
      expect(find.text('Elimina selezionate (60)'), findsOneWidget);
      expect(listens, 1);
      await tester.tap(find.text('Seleziona tutte'));
      await tester.pumpAndSettle();
      expect(find.text('Elimina selezionate (60)'), findsOneWidget);
      await tester.tap(find.text('Annulla selezione'));
      await tester.pumpAndSettle();
      expect(find.text('Segna tutte come lette (60)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await feed.close();
    },
  );
}
