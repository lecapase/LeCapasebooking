import 'package:cloud_firestore/cloud_firestore.dart';

/// Bound parallel requests while allowing each confirmed removal to update UI.
Future<void> deleteNotificationsConcurrently<T>(
  List<T> notifications, {
  required Future<bool> Function(T) remove,
  required void Function(T, bool) onComplete,
}) async {
  var next = 0;
  Future<void> worker() async {
    while (next < notifications.length) {
      final item = notifications[next++];
      var success = false;
      try {
        success = await remove(item);
      } catch (_) {
        // A failed item must not stop the rest of the selection.
      }
      onComplete(item, success);
    }
  }

  await Future.wait(
    List.generate(notifications.length.clamp(0, 6), (_) => worker()),
  );
}

/// Immediate UI acknowledgement while Firestore listeners catch up.
/// A different event is always evaluated from its own server state.
class NotificationReadState {
  final Map<String, Map<String, dynamic>> _readEvents = {};

  void mark(String id, Map<String, dynamic> event) {
    _readEvents[id] = Map.of(event);
  }

  void rollback(String id) => _readEvents.remove(id);

  bool unread(String id, Map<String, dynamic> event) {
    final read = _readEvents[id];
    if (read != null && sameNotificationEvent(read, event)) return false;
    return notificationVisible(event) && notificationEventUnread(event);
  }
}

bool notificationVisible(Map<String, dynamic> booking) {
  if (booking['source'] != 'customer') return false;
  final dismissed = booking['adminNotificationDismissedAt'];
  if (dismissed is Timestamp) {
    final newer =
        const [
          'adminNotificationCreatedAt',
          'reconfirmationWhatsappSentAt',
          'lastWhatsappReplyAt',
        ].any(
          (key) =>
              booking[key] is Timestamp &&
              (booking[key] as Timestamp).compareTo(dismissed) > 0,
        );
    if (!newer) return false;
  }
  return booking['adminNotificationRead'] is bool ||
      booking['reconfirmationResultRead'] is bool ||
      booking['reconfirmationStatus'] == 'pending' ||
      booking['status'] == 'pending';
}

bool notificationEventUnread(Map<String, dynamic> booking) {
  if (booking['reconfirmationResultRead'] == false &&
      const [
        'confirmed',
        'cancelled',
      ].contains(booking['reconfirmationStatus'])) {
    return true;
  }
  if (booking['adminNotificationRead'] == false) return true;
  if (booking['reconfirmationStatus'] == 'pending') {
    final sent = booking['reconfirmationWhatsappSentAt'];
    final read = booking['adminNotificationReadAt'];
    if (sent is Timestamp) {
      return read is! Timestamp || sent.compareTo(read) > 0;
    }
    return booking['adminNotificationRead'] != true;
  }
  // Older reply notifications may have only the reply read flag. Absence of
  // the original booking flag does not make an acknowledged reply unread.
  return booking['status'] == 'pending' &&
      booking['adminNotificationRead'] != true;
}

// Compare event identity, not updatedAt: reading or editing unrelated fields
// must not consume a reply that arrived after the operator saw the card.
bool sameNotificationEvent(
  Map<String, dynamic> seen,
  Map<String, dynamic> current,
) {
  return const [
    'status',
    'reconfirmationStatus',
    'lastWhatsappReplyAt',
    'reconfirmationWhatsappSentAt',
    'adminNotificationCreatedAt',
  ].every((key) => seen[key] == current[key]);
}

Future<bool> markBookingNotificationRead(
  FirebaseFirestore firestore,
  DocumentReference<Map<String, dynamic>> reference,
  Map<String, dynamic> seen, {
  bool dismiss = false,
}) => firestore.runTransaction((transaction) async {
  final snapshot = await transaction.get(reference);
  final current = snapshot.data();
  if (current == null || !sameNotificationEvent(seen, current)) {
    return false;
  }
  // An already acknowledged event is success, not a failed read. Another
  // device may have read it before this device received the updated snapshot.
  if (!dismiss && !notificationEventUnread(current)) return true;
  transaction.update(reference, {
    'adminNotificationRead': true,
    'adminNotificationRetained': !dismiss,
    if (dismiss) 'adminNotificationDismissedAt': FieldValue.serverTimestamp(),
    'adminNotificationReadAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    if (const [
      'confirmed',
      'cancelled',
    ].contains(current['reconfirmationStatus'])) ...{
      'reconfirmationResultRead': true,
      'reconfirmationResultReadAt': FieldValue.serverTimestamp(),
    },
  });
  return true;
});
