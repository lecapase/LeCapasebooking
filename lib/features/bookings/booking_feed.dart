import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

typedef BookingDocument = QueryDocumentSnapshot<Map<String, dynamic>>;

/// Keep the visible month/week and outstanding notifications live, not the archive.
Stream<List<BookingDocument>> watchBookingFeed(
  FirebaseFirestore firestore,
  DateTime selectedDate,
) {
  String key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final start = DateTime(
    selectedDate.year,
    selectedDate.month,
    1,
  ).subtract(const Duration(days: 7));
  final end = DateTime(
    selectedDate.year,
    selectedDate.month + 1,
    1,
  ).add(const Duration(days: 7));
  final bookings = firestore.collection('bookings');
  final queries = [
    bookings
        .where('dateKey', isGreaterThanOrEqualTo: key(start))
        .where('dateKey', isLessThan: key(end)),
    bookings.where('adminNotificationRead', isEqualTo: false),
    bookings.where('adminNotificationRetained', isEqualTo: true),
    bookings.where('status', isEqualTo: 'pending'),
    bookings.where('reconfirmationResultRead', isEqualTo: false),
    bookings.where('reconfirmationStatus', isEqualTo: 'pending'),
  ];
  final pages = <int, List<BookingDocument>>{};
  final subscriptions =
      <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
  late final StreamController<List<BookingDocument>> controller;
  controller = StreamController<List<BookingDocument>>(
    onListen: () {
      for (var index = 0; index < queries.length; index++) {
        final source = index;
        subscriptions.add(
          queries[index].snapshots().listen((snapshot) {
            pages[source] = snapshot.docs;
            if (pages.length != queries.length || controller.isClosed) return;
            final unique = <String, BookingDocument>{};
            for (final page in pages.values) {
              for (final doc in page) {
                final previous = unique[doc.id];
                final timestamp = doc.data()['updatedAt'];
                final previousTimestamp = previous?.data()['updatedAt'];
                if (previous == null ||
                    previousTimestamp is! Timestamp ||
                    (timestamp is Timestamp &&
                        timestamp.compareTo(previousTimestamp) >= 0)) {
                  unique[doc.id] = doc;
                }
              }
            }
            controller.add(unique.values.toList());
          }, onError: controller.addError),
        );
      }
    },
    onCancel: () async {
      await Future.wait(
        subscriptions.map((subscription) => subscription.cancel()),
      );
    },
  );
  return controller.stream;
}
