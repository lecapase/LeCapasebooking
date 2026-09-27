import 'package:cloud_firestore/cloud_firestore.dart';

Future<Map<String, Map<String, dynamic>>> loadBookingHistory() async {
  final records = <String, Map<String, dynamic>>{};
  final query = FirebaseFirestore.instance
      .collection('bookings')
      .orderBy(FieldPath.documentId)
      .limit(500);
  QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
  while (true) {
    final page =
        await (cursor == null ? query : query.startAfterDocument(cursor)).get(
          const GetOptions(source: Source.server),
        );
    for (final doc in page.docs) {
      records[doc.id] = doc.data();
    }
    if (page.docs.length < 500) break;
    cursor = page.docs.last;
  }
  return records;
}
