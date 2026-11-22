import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecapase_booking/features/bookings/widgets/notification_slide_card.dart';
import 'package:lecapase_booking/features/bookings/notification_policy.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  test('read remains visible, explicit dismissal hides until a new event', () {
    final booking = <String, dynamic>{'source': 'customer', 'adminNotificationRead': true};
    expect(notificationVisible(booking), isTrue);
    booking['adminNotificationDismissedAt'] = Timestamp(200, 0);
    expect(notificationVisible(booking), isFalse);
    booking['lastWhatsappReplyAt'] = Timestamp(300, 0);
    expect(notificationVisible(booking), isTrue);
  });

  testWidgets('swipe only reveals delete; explicit tap deletes', (tester) async {
    var deletes = 0;
    var opens = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: NotificationSlideCard(
      unread: false,
      onTap: () => opens++,
      onDelete: () async { deletes++; },
      child: const SizedBox(height: 150, width: 350, child: Text('Notifica')),
    ))));
    expect(find.text('ELIMINA'), findsNothing);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.65);
    await tester.tap(find.text('Notifica'));
    expect(opens, 1);
    await tester.drag(find.text('Notifica'), const Offset(-130, 0));
    await tester.pumpAndSettle();
    expect(find.text('ELIMINA'), findsOneWidget);
    expect(deletes, 0);
    expect(opens, 1);
    await tester.tap(find.text('ELIMINA'));
    await tester.pumpAndSettle();
    expect(deletes, 1);
    expect(opens, 1);
  });
}
