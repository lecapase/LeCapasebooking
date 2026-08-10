import 'package:cloud_firestore/cloud_firestore.dart';

class BookingCapacityException implements Exception {
  final String message;

  const BookingCapacityException(
    this.message,
  );

  @override
  String toString() => message;
}

class FirestoreBookingRepository {
  FirestoreBookingRepository._();

  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static const String _bookingsCollection =
      'bookings';

  static const String _countersCollection =
      'availability_counters';

  // =========================================================
  // CREA PRENOTAZIONE + AGGIORNA COPERTI
  //
  // REGOLA CONFERMA:
  //
  // 1 - 4 PERSONE
  // -> CONFERMATA AUTOMATICAMENTE
  //
  // 5+ PERSONE
  // -> DA CONFERMARE DAL GESTIONALE
  //
  // TUTTO NELLA STESSA TRANSAZIONE FIRESTORE
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
    final dateKey =
        _dateKey(date);

    // =======================================================
    // STATO INIZIALE
    // =======================================================

    final bool autoConfirmed =
        guests <= 4;

    final String initialStatus =
        autoConfirmed
            ? 'confirmed'
            : 'pending';

    final bookingReference =
        _firestore
            .collection(
              _bookingsCollection,
            )
            .doc();

    final counterReference =
        _firestore
            .collection(
              _countersCollection,
            )
            .doc(
              '${dateKey}_$service',
            );

    final exceptionReference =
        _firestore
            .collection(
              'availability_exceptions',
            )
            .doc(
              dateKey,
            );

    final weeklyReference =
        _firestore
            .collection(
              'availability_weekly',
            )
            .doc(
              date.weekday.toString(),
            );

    await _firestore.runTransaction(
      (transaction) async {
        // ===================================================
        // 1. EVENTUALE ECCEZIONE PER LA DATA
        // ===================================================

        final exceptionSnapshot =
            await transaction.get(
          exceptionReference,
        );

        Map<String, dynamic>? serviceData;

        if (exceptionSnapshot.exists) {
          final exceptionData =
              exceptionSnapshot.data();

          if (exceptionData != null &&
              exceptionData[service] is Map) {
            serviceData =
                Map<String, dynamic>.from(
              exceptionData[service]
                  as Map,
            );
          }
        }

        // ===================================================
        // 2. REGOLA SETTIMANALE
        // ===================================================

        if (serviceData == null) {
          final weeklySnapshot =
              await transaction.get(
            weeklyReference,
          );

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

          serviceData =
              Map<String, dynamic>.from(
            weeklyData[service]
                as Map,
          );
        }

        // ===================================================
        // 3. CONTROLLO SERVIZIO APERTO
        // ===================================================

        final bool isOpen =
            serviceData['isOpen']
                    as bool? ??
                false;

        if (!isOpen) {
          throw const BookingCapacityException(
            'Questo servizio non è più disponibile.',
          );
        }

        // ===================================================
        // 4. MASSIMO COPERTI ONLINE
        // ===================================================

        final int maxOnlineGuests =
            serviceData[
                        'maxOnlineGuests']
                    as int? ??
                0;

        if (maxOnlineGuests <= 0) {
          throw const BookingCapacityException(
            'Questo servizio non è disponibile.',
          );
        }

        // ===================================================
        // 5. COPERTI GIÀ OCCUPATI
        // ===================================================

        final counterSnapshot =
            await transaction.get(
          counterReference,
        );

        int bookedGuests = 0;

        if (counterSnapshot.exists) {
          final counterData =
              counterSnapshot.data();

          bookedGuests =
              counterData?[
                          'bookedGuests']
                      as int? ??
                  0;
        }

        // ===================================================
        // 6. CONTROLLO DISPONIBILITÀ
        // ===================================================

        final int newTotal =
            bookedGuests + guests;

        if (newTotal >
            maxOnlineGuests) {
          throw const BookingCapacityException(
            'Non ci sono abbastanza posti disponibili '
            'per questo servizio.',
          );
        }

        // ===================================================
        // 7. CREA PRENOTAZIONE
        // ===================================================

        transaction.set(
          bookingReference,
          {
            // -----------------------------------------------
            // CLIENTE
            // -----------------------------------------------

            'nome':
                nome.trim(),

            'cognome':
                cognome.trim(),

            'email':
                email.trim(),

            'telefono':
                telefono.trim(),

            // -----------------------------------------------
            // DATA
            // -----------------------------------------------

            'date':
                Timestamp.fromDate(
              DateTime(
                date.year,
                date.month,
                date.day,
              ),
            ),

            'dateKey':
                dateKey,

            'weekday':
                date.weekday,

            'time':
                time,

            'service':
                service,

            // -----------------------------------------------
            // PERSONE
            // -----------------------------------------------

            'guests':
                guests,

            // -----------------------------------------------
            // DETTAGLI
            // -----------------------------------------------

            'occasion':
                occasion,

            'notes':
                notes.trim(),

            // -----------------------------------------------
            // STATO
            // -----------------------------------------------

            'status':
                initialStatus,

            'autoConfirmed':
                autoConfirmed,

            'requiresManualConfirmation':
                !autoConfirmed,

            // -----------------------------------------------
            // ORIGINE
            // -----------------------------------------------

            'source':
                'customer',

            // -----------------------------------------------
            // COMUNICAZIONI
            //
            // Questi campi verranno usati nel prossimo step
            // per email e WhatsApp.
            // -----------------------------------------------

            'confirmationEmailSent':
                false,

            'confirmationWhatsappSent':
                false,

            'rejectionEmailSent':
                false,

            'rejectionWhatsappSent':
                false,

            // -----------------------------------------------
            // PUSH GESTIONALE
            // -----------------------------------------------

            'adminNotificationSent':
                false,

            // -----------------------------------------------
            // CONFERMA
            // -----------------------------------------------

            'confirmedAt':
                autoConfirmed
                    ? FieldValue
                        .serverTimestamp()
                    : null,

            'confirmedBy':
                autoConfirmed
                    ? 'automatic'
                    : null,

            // -----------------------------------------------
            // TIMESTAMP
            // -----------------------------------------------

            'createdAt':
                FieldValue
                    .serverTimestamp(),

            'updatedAt':
                FieldValue
                    .serverTimestamp(),
          },
        );

        // ===================================================
        // 8. AGGIORNA CONTATORE COPERTI
        //
        // ANCHE LE PRENOTAZIONI 5+ IN ATTESA BLOCCANO
        // I COPERTI, EVITANDO OVERBOOKING.
        // ===================================================

        transaction.set(
          counterReference,
          {
            'dateKey':
                dateKey,

            'weekday':
                date.weekday,

            'service':
                service,

            'bookedGuests':
                newTotal,

            'lastBookingId':
                bookingReference.id,

            'updatedAt':
                FieldValue
                    .serverTimestamp(),
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
  // IL CLIENTE NON VEDE QUESTO NUMERO.
  // =========================================================

  static Future<int> getBookedGuests({
    required DateTime date,
    required String service,
  }) async {
    final dateKey =
        _dateKey(date);

    final snapshot =
        await _firestore
            .collection(
              _countersCollection,
            )
            .doc(
              '${dateKey}_$service',
            )
            .get();

    if (!snapshot.exists) {
      return 0;
    }

    final data =
        snapshot.data();

    if (data == null) {
      return 0;
    }

    return data['bookedGuests']
            as int? ??
        0;
  }

  // =========================================================
  // SERVIZIO CON POSTI DISPONIBILI?
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

    return bookedGuests <
        maxGuests;
  }

  // =========================================================
  // POSTO PER IL NUMERO DI PERSONE RICHIESTO?
  // =========================================================

  static Future<bool>
      hasCapacityForGuests({
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

    return bookedGuests +
            requestedGuests <=
        maxGuests;
  }

  // =========================================================
  // DATA KEY
  // =========================================================

  static String _dateKey(
    DateTime date,
  ) {
    final year =
        date.year
            .toString()
            .padLeft(
              4,
              '0',
            );

    final month =
        date.month
            .toString()
            .padLeft(
              2,
              '0',
            );

    final day =
        date.day
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '$year-$month-$day';
  }
}