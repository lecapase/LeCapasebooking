// SDK interfaces are faked only here to exercise transactions without production data.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecapase_booking/features/bookings/notification_policy.dart';
import 'package:lecapase_booking/features/bookings/widgets/notification_slide_card.dart';

class _Snapshot<T> extends Fake implements DocumentSnapshot<T> {
  _Snapshot(this.value);
  final T? value;
  @override
  T? data() => value;
}

class _Reference extends Fake
    implements DocumentReference<Map<String, dynamic>> {}

class _Transaction extends Fake implements Transaction {
  _Transaction(this.current);
  Map<String, dynamic>? current;
  int writes = 0;
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async => _Snapshot<T>(current as T?);
  @override
  Transaction update(DocumentReference reference, Map<Object, Object?> data) {
    writes++;
    current = {
      ...current!,
      for (final entry in data.entries)
        entry.key as String: entry.value is FieldValue
            ? Timestamp(500, 0)
            : entry.value,
    };
    return this;
  }
}

class _Firestore extends Fake implements FirebaseFirestore {
  _Firestore(this.transaction);
  final _Transaction transaction;
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) => handler(transaction);
}

void main() {
  final event = <String, dynamic>{
    'source': 'customer',
    'status': 'booked',
    'adminNotificationRead': false,
    'adminNotificationCreatedAt': Timestamp(100, 0),
  };

  test(
    'single read already saved remotely succeeds instead of restoring badge',
    () async {
      final transaction = _Transaction({
        ...event,
        'adminNotificationRead': true,
      });
      expect(
        await markBookingNotificationRead(
          _Firestore(transaction),
          _Reference(),
          event,
        ),
        isTrue,
      );
      expect(transaction.writes, 0);
    },
  );

  test(
    'acknowledged legacy reply does not add unread items on month navigation',
    () {
      final legacy = <String, dynamic>{
        'source': 'customer',
        'status': 'released',
        'reconfirmationStatus': 'confirmed',
        'reconfirmationResultRead': true,
      };
      expect(notificationVisible(legacy), isTrue);
      expect(notificationEventUnread(legacy), isFalse);
    },
  );

  test(
    'a changed reply is preserved rather than acknowledged from a stale card',
    () async {
      final transaction = _Transaction({
        ...event,
        'lastWhatsappReplyAt': Timestamp(300, 0),
      });
      expect(
        await markBookingNotificationRead(
          _Firestore(transaction),
          _Reference(),
          event,
        ),
        isFalse,
      );
      expect(transaction.writes, 0);
    },
  );

  testWidgets(
    'individual card taps persist reads and decrement 2 to 1 to 0 without bulk action',
    (tester) async {
      final state = NotificationReadState();
      final transactions = [
        _Transaction(Map.of(event)),
        _Transaction(Map.of(event)),
      ];
      var serviceOpen = false;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              final count = [
                0,
                1,
              ].where((i) => state.unread('$i', event)).length;
              return Scaffold(
                body: Column(
                  children: [
                    Text('Da leggere: $count'),
                    if (serviceOpen)
                      TextButton(
                        onPressed: () => setState(() => serviceOpen = false),
                        child: const Text('Notifiche'),
                      )
                    else
                      for (final i in [0, 1])
                        NotificationSlideCard(
                          unread: state.unread('$i', event),
                          onTap: () async {
                            setState(() => state.mark('$i', event));
                            final saved = await markBookingNotificationRead(
                              _Firestore(transactions[i]),
                              _Reference(),
                              event,
                            );
                            setState(() {
                              if (!saved) state.rollback('$i');
                              serviceOpen = true;
                            });
                          },
                          child: SizedBox(
                            width: 300,
                            height: 70,
                            child: Text('Scheda $i'),
                          ),
                        ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      expect(find.text('Da leggere: 2'), findsOneWidget);
      for (final i in [0, 1]) {
        await tester.tap(find.text('Scheda $i'));
        await tester.pumpAndSettle();
        expect(find.text('Da leggere: ${1 - i}'), findsOneWidget);
        expect(transactions[i].current!['adminNotificationRead'], isTrue);
        expect(notificationEventUnread(transactions[i].current!), isFalse);
        await tester.tap(find.text('Notifiche'));
        await tester.pumpAndSettle();
        expect(find.text('Scheda $i'), findsOneWidget);
      }
    },
  );
}
