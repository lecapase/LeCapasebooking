import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreCapacityRepository {
  FirestoreCapacityRepository._();

  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static const String _collectionName =
      'availability_counters';

  // =========================================================
  // COPERTI PRENOTATI PER DATA + SERVIZIO
  // =========================================================

  static Future<int> getBookedGuests({
    required DateTime date,
    required String service,
  }) async {
    final document = await _firestore
        .collection(_collectionName)
        .doc(
          _counterId(
            date: date,
            service: service,
          ),
        )
        .get();

    if (!document.exists) {
      return 0;
    }

    final data = document.data();

    if (data == null) {
      return 0;
    }

    return data['bookedGuests'] as int? ?? 0;
  }

  // =========================================================
  // COPERTI RIMANENTI
  // =========================================================

  static Future<int> getRemainingGuests({
    required DateTime date,
    required String service,
    required int maxGuests,
  }) async {
    final bookedGuests = await getBookedGuests(
      date: date,
      service: service,
    );

    final remaining =
        maxGuests - bookedGuests;

    if (remaining <= 0) {
      return 0;
    }

    return remaining;
  }

  // =========================================================
  // AGGIUNGE COPERTI AL CONTATORE
  // =========================================================

  static Future<void> addGuests({
    required DateTime date,
    required String service,
    required int guests,
  }) async {
    final reference = _firestore
        .collection(_collectionName)
        .doc(
          _counterId(
            date: date,
            service: service,
          ),
        );

    await _firestore.runTransaction(
      (transaction) async {
        final snapshot =
            await transaction.get(reference);

        int currentGuests = 0;

        if (snapshot.exists) {
          final data = snapshot.data();

          currentGuests =
              data?['bookedGuests'] as int? ?? 0;
        }

        final newTotal =
            currentGuests + guests;

        transaction.set(
          reference,
          {
            'dateKey': _dateKey(date),
            'service': service,
            'bookedGuests': newTotal,
            'updatedAt':
                FieldValue.serverTimestamp(),
          },
          SetOptions(
            merge: true,
          ),
        );
      },
    );
  }

  // =========================================================
  // RIMUOVE COPERTI
  //
  // Ci servirà quando una prenotazione viene
  // annullata o rifiutata.
  // =========================================================

  static Future<void> removeGuests({
    required DateTime date,
    required String service,
    required int guests,
  }) async {
    final reference = _firestore
        .collection(_collectionName)
        .doc(
          _counterId(
            date: date,
            service: service,
          ),
        );

    await _firestore.runTransaction(
      (transaction) async {
        final snapshot =
            await transaction.get(reference);

        if (!snapshot.exists) {
          return;
        }

        final data = snapshot.data();

        final currentGuests =
            data?['bookedGuests'] as int? ?? 0;

        var newTotal =
            currentGuests - guests;

        if (newTotal < 0) {
          newTotal = 0;
        }

        transaction.update(
          reference,
          {
            'bookedGuests': newTotal,
            'updatedAt':
                FieldValue.serverTimestamp(),
          },
        );
      },
    );
  }

  // =========================================================
  // ID CONTATORE
  //
  // esempio:
  // 2026-08-10_dinner
  // =========================================================

  static String _counterId({
    required DateTime date,
    required String service,
  }) {
    return '${_dateKey(date)}_$service';
  }

  static String _dateKey(
    DateTime date,
  ) {
    final year =
        date.year.toString().padLeft(4, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    final day =
        date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}