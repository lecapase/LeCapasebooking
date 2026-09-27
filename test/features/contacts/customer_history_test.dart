import 'package:flutter_test/flutter_test.dart';
import 'package:lecapase_booking/features/contacts/customer_history.dart';

void main() {
  test('normalizes Italian mobile and international prefix consistently', () {
    for (final phone in ['333 1234567', '+39 3331234567', '00393331234567']) {
      expect(customerIdentity({'telefono': phone}, 'a'), 'phone_393331234567');
    }
    expect(
      customerIdentity({'telefono': '+44 2012345678'}, 'a'),
      'phone_442012345678',
    );
  });
  test('uses email fallback and never merges unidentified names', () {
    expect(
      customerIdentity({'email': ' A@Example.COM '}, 'a'),
      'email_a@example.com',
    );
    expect(
      customerIdentity({'nome': 'Mario'}, 'a'),
      isNot(customerIdentity({'nome': 'Mario'}, 'b')),
    );
    expect(
      customerIdentity({'telefono': '123', 'email': 'a@b.it'}, 'a'),
      'phone_123',
    );
  });
  test(
    'groups manual and public bookings and uses current statuses for totals',
    () {
      final records = <String, Map<String, dynamic>>{};
      final statuses = [
        'arrived',
        'released',
        'completed',
        'cancelled',
        'no_show',
        'booked',
        'rejected',
      ];
      for (var i = 0; i < statuses.length; i++) {
        records['$i'] = {
          'telefono': '3331234567',
          'nome': 'Mario',
          'dateKey': '2026-09-${10 + i}',
          'status': statuses[i],
          'source': i.isEven ? 'customer' : 'admin',
        };
      }
      final customer = CustomerHistory.group(records).single;
      expect(customer.visits, 3);
      expect(customer.cancellations, 1);
      expect(customer.noShows, 1);
      expect(customer.lastVisit, '2026-09-12');
      expect(customer.bookings.first['status'], 'rejected');
      records['4']!['status'] = 'released';
      final corrected = CustomerHistory.group(records).single;
      expect(corrected.noShows, 0);
      expect(corrected.visits, 4);
      expect(corrected.lastVisit, '2026-09-14');
    },
  );
  test('does not merge distinct phone numbers sharing an email', () {
    expect(
      CustomerHistory.group({
        'a': {'telefono': '123', 'email': 'same@example.com'},
        'b': {'telefono': '456', 'email': 'same@example.com'},
      }),
      hasLength(2),
    );
  });
}
