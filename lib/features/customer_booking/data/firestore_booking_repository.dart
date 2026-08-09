import 'package:cloud_firestore/cloud_firestore.dart';

class BookingCapacityException implements Exception {
  final String message;

  const BookingCapacityException(this.message);

  @override
  String toString() => message;
}

class FirestoreBookingRepository {
  FirestoreBookingRepository._();

  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static const String _bookingsCollection = 'bookings';
  static const String _countersCollection = 'availability_counters';

  // =========================================================
  // CREA PRENOTAZIONE + AGGIORNA COPERTI
  // TUTTO NELLA STESSA TRANSAZIONE
  // =========================================================

  static Future<String> createBooking({
    required String nome,
    required String cognome,
    required String email,
    required String telefono,
    required DateTime date,
    required String time,
    required int guests,
    required String service,
    required String occasion,
    required String notes,
  }) async {
    final dateKey = _dateKey(date);

    final bookingReference =
        _firestore.collection(_bookingsCollection).doc();

    final counterReference = _firestore
        .collection(_countersCollection)
        .doc('${dateKey}_$service');

    final exceptionReference = _firestore
        .collection('availability_exceptions')
        .doc(dateKey);

    final weeklyReference = _firestore
        .collection('availability_weekly')
        .doc(date.weekday.toString());

    await _firestore.runTransaction(
      (transaction) async {
        // -----------------------------------------------------
        // 1. CERCA EVENTUALE ECCEZIONE PER LA DATA
        // -----------------------------------------------------

        final exceptionSnapshot =
            await transaction.get(exceptionReference);

        Map<String, dynamic>? serviceData;

        if (exceptionSnapshot.exists) {
          final exceptionData =
              exceptionSnapshot.data();

          if (exceptionData != null &&
              exceptionData[service] is Map) {
            serviceData = Map<String, dynamic>.from(
              exceptionData[service] as Map,
            );
          }
        }

        // -----------------------------------------------------
        // 2. SE NON C'È ECCEZIONE USA REGOLA SETTIMANALE
        // -----------------------------------------------------

        if (serviceData == null) {
          final weeklySnapshot =
              await transaction.get(weeklyReference);

          if (!weeklySnapshot.exists) {
            throw const BookingCapacityException(
              'Servizio non disponibile.',
            );
          }

          final weeklyData =
              weeklySnapshot.data();

          if (weeklyData == null ||
              weeklyData[service] is! Map) {
            throw const BookingCapacityException(
              'Servizio non disponibile.',
            );
          }

          serviceData = Map<String, dynamic>.from(
            weeklyData[service] as Map,
          );
        }

        // -----------------------------------------------------
        // 3. CONTROLLO SERVIZIO APERTO
        // -----------------------------------------------------

        final isOpen =
            serviceData['isOpen'] as bool? ?? false;

        if (!isOpen) {
          throw const BookingCapacityException(
            'Questo servizio non è più disponibile.',
          );
        }

        // -----------------------------------------------------
        // 4. MASSIMO COPERTI IMPOSTATO DAL GESTIONALE
        // -----------------------------------------------------

        final maxOnlineGuests =
            serviceData['maxOnlineGuests'] as int? ?? 0;

        if (maxOnlineGuests <= 0) {
          throw const BookingCapacityException(
            'Questo servizio non è disponibile.',
          );
        }

        // -----------------------------------------------------
        // 5. LEGGE COPERTI GIÀ OCCUPATI
        // -----------------------------------------------------

        final counterSnapshot =
            await transaction.get(counterReference);

        int bookedGuests = 0;

        if (counterSnapshot.exists) {
          final counterData =
              counterSnapshot.data();

          bookedGuests =
              counterData?['bookedGuests'] as int? ?? 0;
        }

        // -----------------------------------------------------
        // 6. CONTROLLO DISPONIBILITÀ
        // -----------------------------------------------------

        final newTotal =
            bookedGuests + guests;

        if (newTotal > maxOnlineGuests) {
          throw const BookingCapacityException(
            'Non ci sono abbastanza posti disponibili '
            'per questo servizio.',
          );
        }

        // -----------------------------------------------------
        // 7. CREA PRENOTAZIONE
        // -----------------------------------------------------

        transaction.set(
          bookingReference,
          {
            'nome': nome,
            'cognome': cognome,
            'email': email,
            'telefono': telefono,

            'date': Timestamp.fromDate(
              DateTime(
                date.year,
                date.month,
                date.day,
              ),
            ),

            'dateKey': dateKey,

            'weekday': date.weekday,

            'time': time,

            'service': service,

            'guests': guests,

            'occasion': occasion,

            'notes': notes,

            'status': 'pending',

            'source': 'customer',

            'createdAt':
                FieldValue.serverTimestamp(),

            'updatedAt':
                FieldValue.serverTimestamp(),
          },
        );

        // -----------------------------------------------------
        // 8. AGGIORNA CONTATORE COPERTI
        // -----------------------------------------------------

        transaction.set(
          counterReference,
          {
            'dateKey': dateKey,

            'weekday': date.weekday,

            'service': service,

            'bookedGuests': newTotal,

            'lastBookingId':
                bookingReference.id,

            'updatedAt':
                FieldValue.serverTimestamp(),
          },
          SetOptions(
            merge: true,
          ),
        );
      },
    );

    return bookingReference.id;
  }

  // =========================================================
  // LEGGE COPERTI OCCUPATI
  //
  // Il cliente NON vede questo numero.
  // Serve solo al motore disponibilità.
  // =========================================================

  static Future<int> getBookedGuests({
    required DateTime date,
    required String service,
  }) async {
    final dateKey = _dateKey(date);

    final snapshot = await _firestore
        .collection(_countersCollection)
        .doc('${dateKey}_$service')
        .get();

    if (!snapshot.exists) {
      return 0;
    }

    final data = snapshot.data();

    if (data == null) {
      return 0;
    }

    return data['bookedGuests'] as int? ?? 0;
  }

  // =========================================================
  // CONTROLLA SE IL SERVIZIO HA ANCORA POSTI
  // =========================================================

  static Future<bool> hasAvailability({
    required DateTime date,
    required String service,
    required int maxGuests,
  }) async {
    final bookedGuests =
        await getBookedGuests(
      date: date,
      service: service,
    );

    return bookedGuests < maxGuests;
  }

  // =========================================================
  // CONTROLLA SE C'È POSTO PER UN CERTO NUMERO DI PERSONE
  // =========================================================

  static Future<bool> hasCapacityForGuests({
    required DateTime date,
    required String service,
    required int maxGuests,
    required int requestedGuests,
  }) async {
    final bookedGuests =
        await getBookedGuests(
      date: date,
      service: service,
    );

    return bookedGuests + requestedGuests <=
        maxGuests;
  }

  // =========================================================
  // DATA KEY
  // =========================================================

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