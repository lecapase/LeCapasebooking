import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecapase_booking/features/bookings/notification_policy.dart';

void main() {
  test(
    'counter drops immediately, stays read on stale snapshots and restores on failure',
    () {
      final state = NotificationReadState();
      final event = <String, dynamic>{
        'source': 'customer',
        'adminNotificationRead': false,
      };
      int count() => ['a', 'b'].where((id) => state.unread(id, event)).length;
      expect(count(), 2);
      state.mark('a', event);
      expect(count(), 1);
      expect(notificationVisible(event), isTrue);
      state.mark('a', event);
      expect(count(), 1);
      state.rollback('a');
      expect(count(), 2);
    },
  );
  test('a new reply counts again after the previous event was read', () {
    final state = NotificationReadState();
    final event = <String, dynamic>{
      'source': 'customer',
      'adminNotificationRead': false,
    };
    state.mark('a', event);
    expect(state.unread('a', event), isFalse);
    expect(
      state.unread('a', {
        ...event,
        'lastWhatsappReplyAt': Timestamp(300, 0),
        'reconfirmationStatus': 'confirmed',
        'reconfirmationResultRead': false,
      }),
      isTrue,
    );
  });
  test('new reminder is unread even when original booking was read', () {
    final booking = <String, dynamic>{
      'adminNotificationRead': true,
      'adminNotificationReadAt': Timestamp(100, 0),
      'reconfirmationStatus': 'pending',
      'reconfirmationWhatsappSentAt': Timestamp(200, 0),
    };
    expect(notificationEventUnread(booking), isTrue);
    booking['adminNotificationReadAt'] = Timestamp(300, 0);
    expect(notificationEventUnread(booking), isFalse);
  });
  test('unread reply survives a read booking', () {
    for (final status in ['confirmed', 'cancelled']) {
      expect(
        notificationEventUnread({
          'adminNotificationRead': true,
          'reconfirmationStatus': status,
          'reconfirmationResultRead': false,
        }),
        isTrue,
      );
    }
  });
  test('new reply or reminder cannot be consumed from an old card', () {
    final seen = <String, dynamic>{
      'status': 'booked',
      'lastWhatsappReplyAt': Timestamp(100, 0),
    };
    expect(
      sameNotificationEvent(seen, {
        ...seen,
        'lastWhatsappReplyAt': Timestamp(200, 0),
      }),
      isFalse,
    );
    expect(
      sameNotificationEvent(seen, {
        ...seen,
        'reconfirmationWhatsappSentAt': Timestamp(200, 0),
      }),
      isFalse,
    );
    expect(
      sameNotificationEvent(seen, {...seen, 'status': 'cancelled'}),
      isFalse,
    );
    expect(sameNotificationEvent(seen, {...seen, 'notes': 'changed'}), isTrue);
  });
}
