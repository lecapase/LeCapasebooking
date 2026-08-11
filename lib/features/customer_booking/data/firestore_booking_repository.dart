import 'package:cloud_firestore/cloud_firestore.dart';

import '../../availability/models/service_availability.dart';
import 'customer_availability_service.dart';

class BookingCapacityException implements Exception {
  final String message;

  const BookingCapacityException(this.message);

  @override
  String toString() => message;
}

class FirestoreBookingRepository {
  FirestoreBookingRepository._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _bookingsCollection = 'bookings';

  static const String _countersCollection = 'availability_counters';

  // =========================================================
  // CREA PRENOTAZIONE E AGGIORNA I COPERTI
  //
  // 1 - 4 persone:
  // conferma automatica.
  //
  // 5+ persone:
  // conferma manuale dal gestionale.
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
    final normalizedDate = DateTime(date.year, date.month, date.day);

    // =======================================================
    // 1. CONTROLLO DATI DI BASE
    // =======================================================

    if (guests < 1) {
      throw const BookingCapacityException(
        'Il numero di persone non è valido.',
      );
    }

    if (service != 'lunch' && service != 'dinner') {
      throw const BookingCapacityException('Servizio non valido.');
    }

    // =======================================================
    // 2. LEGGE IL SERVIZIO EFFETTIVO DELLA DATA
    //
    // Una data specifica ha la precedenza
    // sulla programmazione annuale.
    // =======================================================

    final dayAvailability =
        await CustomerAvailabilityService.getAvailabilityForDate(
          normalizedDate,
        );

    if (dayAvailability == null) {
      throw const BookingCapacityException(
        'Nessun servizio disponibile per questa data.',
      );
    }

    final selectedService = _serviceForId(
      dayAvailability: dayAvailability,
      serviceId: service,
    );

    if (selectedService == null || !selectedService.isOpen) {
      throw const BookingCapacityException(
        'Questo servizio non è disponibile.',
      );
    }

    // =======================================================
    // 3. CONTROLLO ORARIO
    // =======================================================

    final availableTimes = CustomerAvailabilityService.generateAvailableTimes(
      selectedService,
    );

    if (!availableTimes.contains(time)) {
      throw const BookingCapacityException(
        'L’orario selezionato non è più disponibile.',
      );
    }

    if (CustomerAvailabilityService.isTimeBlocked(
      service: selectedService,
      time: time,
    )) {
      throw const BookingCapacityException(
        'L’orario selezionato è stato bloccato.',
      );
    }

    // =======================================================
    // 4. CONTROLLO CAPIENZA DEL SERVIZIO
    // =======================================================

    final maxOnlineGuests = selectedService.maxOnlineGuests;

    if (maxOnlineGuests < 1) {
      throw const BookingCapacityException(
        'Questo servizio non accetta prenotazioni online.',
      );
    }

    final dateKey = _dateKey(normalizedDate);

    final autoConfirmed = guests <= 4;

    final initialStatus = autoConfirmed ? 'confirmed' : 'pending';

    final bookingReference = _firestore.collection(_bookingsCollection).doc();

    final counterReference = _firestore
        .collection(_countersCollection)
        .doc('${dateKey}_$service');

    // =======================================================
    // 5. TRANSAZIONE FIRESTORE
    //
    // La verifica dei coperti e il salvataggio
    // avvengono insieme, evitando overbooking.
    // =======================================================

    await _firestore.runTransaction((transaction) async {
      final counterSnapshot = await transaction.get(counterReference);

      int bookedGuests = 0;

      if (counterSnapshot.exists) {
        final counterData = counterSnapshot.data();

        bookedGuests = (counterData?['bookedGuests'] as num?)?.toInt() ?? 0;
      }

      final newTotal = bookedGuests + guests;

      if (newTotal > maxOnlineGuests) {
        throw const BookingCapacityException(
          'Non ci sono abbastanza posti disponibili '
          'per questo servizio.',
        );
      }

      // ===================================================
      // CREA PRENOTAZIONE
      // ===================================================

      transaction.set(bookingReference, {
        'nome': nome.trim(),
        'cognome': cognome.trim(),
        'email': email.trim(),
        'telefono': telefono.trim(),

        'date': Timestamp.fromDate(normalizedDate),

        'dateKey': dateKey,
        'weekday': normalizedDate.weekday,
        'time': time,
        'service': service,
        'guests': guests,

        'occasion': occasion,
        'notes': notes.trim(),

        'status': initialStatus,
        'autoConfirmed': autoConfirmed,
        'requiresManualConfirmation': !autoConfirmed,

        'source': 'customer',

        'confirmationEmailSent': false,
        'confirmationWhatsappSent': false,
        'rejectionEmailSent': false,
        'rejectionWhatsappSent': false,
        'adminNotificationSent': false,

        'confirmedAt': autoConfirmed ? FieldValue.serverTimestamp() : null,

        'confirmedBy': autoConfirmed ? 'automatic' : null,

        'createdAt': FieldValue.serverTimestamp(),

        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ===================================================
      // AGGIORNA CONTATORE COPERTI
      //
      // Anche le prenotazioni in attesa bloccano
      // temporaneamente i coperti.
      // ===================================================

      transaction.set(counterReference, {
        'dateKey': dateKey,
        'weekday': normalizedDate.weekday,
        'service': service,
        'bookedGuests': newTotal,
        'lastBookingId': bookingReference.id,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    return bookingReference.id;
  }

  // =========================================================
  // SELEZIONA PRANZO O CENA
  // =========================================================

  static ServiceAvailability? _serviceForId({
    required DayAvailability dayAvailability,
    required String serviceId,
  }) {
    switch (serviceId) {
      case 'lunch':
        return dayAvailability.lunch;

      case 'dinner':
        return dayAvailability.dinner;

      default:
        return null;
    }
  }

  // =========================================================
  // COPERTI GIÀ OCCUPATI
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

    return (data['bookedGuests'] as num?)?.toInt() ?? 0;
  }

  // =========================================================
  // SERVIZIO CON ALMENO UN POSTO DISPONIBILE
  // =========================================================

  static Future<bool> hasAvailability({
    required DateTime date,
    required String service,
    required int maxGuests,
  }) async {
    final bookedGuests = await getBookedGuests(date: date, service: service);

    return bookedGuests < maxGuests;
  }

  // =========================================================
  // POSTI SUFFICIENTI PER IL GRUPPO RICHIESTO
  // =========================================================

  static Future<bool> hasCapacityForGuests({
    required DateTime date,
    required String service,
    required int maxGuests,
    required int requestedGuests,
  }) async {
    final bookedGuests = await getBookedGuests(date: date, service: service);

    return bookedGuests + requestedGuests <= maxGuests;
  }

  // =========================================================
  // DATA KEY: 2026-08-15
  // =========================================================

  static String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');

    final month = date.month.toString().padLeft(2, '0');

    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
