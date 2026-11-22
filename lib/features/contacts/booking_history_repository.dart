import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<Map<String, Map<String, dynamic>>>? _cachedHistory;
String? _cachedUser;
DateTime? _cachedAt;

void clearBookingHistoryCache() {
  _cachedHistory = null;
  _cachedUser = null;
  _cachedAt = null;
}

Future<Map<String, Map<String, dynamic>>> loadBookingHistory({
  bool refresh = false,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    clearBookingHistoryCache();
    throw StateError('Accedi al gestionale.');
  }
  final now = DateTime.now();
  if (refresh ||
      _cachedUser != uid ||
      _cachedAt == null ||
      now.difference(_cachedAt!) >= const Duration(minutes: 2)) {
    clearBookingHistoryCache();
  }
  _cachedUser = uid;
  _cachedAt ??= now;
  final request = _cachedHistory ??= _fetchBookingHistory();
  try {
    final records = await request;
    // Callers may sort or edit their own copy without altering the shared cache.
    return records.map(
      (id, data) => MapEntry(id, Map<String, dynamic>.from(data)),
    );
  } catch (_) {
    if (identical(_cachedHistory, request)) clearBookingHistoryCache();
    rethrow;
  }
}

Future<Map<String, Map<String, dynamic>>> _fetchBookingHistory() async {
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
