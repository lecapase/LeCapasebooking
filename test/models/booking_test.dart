import 'package:flutter_test/flutter_test.dart';
import 'package:lecapase_booking/models/booking.dart';

void main() {
  group('Booking', () {
    test('serializza e ricostruisce tutti i campi', () {
      final booking = Booking(
        nome: 'Mario',
        cognome: 'Rossi',
        email: 'mario@example.com',
        telefono: '+39 333 1234567',
        persone: 4,
        data: '2026-09-12',
        orario: '20:30',
        occasione: 'Compleanno',
        note: 'Tavolo tranquillo',
        stato: 'Confermata',
      );

      final json = booking.toJson();
      final restored = Booking.fromJson(json);

      expect(restored.nome, booking.nome);
      expect(restored.cognome, booking.cognome);
      expect(restored.email, booking.email);
      expect(restored.telefono, booking.telefono);
      expect(restored.persone, booking.persone);
      expect(restored.data, booking.data);
      expect(restored.orario, booking.orario);
      expect(restored.occasione, booking.occasione);
      expect(restored.note, booking.note);
      expect(restored.stato, booking.stato);
    });

    test('usa valori predefiniti per i campi mancanti', () {
      final booking = Booking.fromJson(const <String, dynamic>{});

      expect(booking.nome, isEmpty);
      expect(booking.cognome, isEmpty);
      expect(booking.email, isEmpty);
      expect(booking.telefono, isEmpty);
      expect(booking.persone, 1);
      expect(booking.data, isEmpty);
      expect(booking.orario, isEmpty);
      expect(booking.occasione, 'Nessuna');
      expect(booking.note, isEmpty);
      expect(booking.stato, 'Da confermare');
    });
  });
}
