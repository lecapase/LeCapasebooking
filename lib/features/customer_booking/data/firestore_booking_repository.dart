import 'package:cloud_firestore/cloud_firestore.dart';

import '../../availability/data/booking_slot_closures_repository.dart';
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
  // 1-4 persone:
  // stato "booked" = Prenotata automaticamente.
  //
  // Da 5 persone:
  // stato "pending" = In attesa di conferma.
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
    bool bookingWhatsappConsent = false,
    bool marketingEmailConsent = false,
    bool marketingWhatsappConsent = false,
  }) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    final cleanName = nome.trim();
    final cleanSurname = cognome.trim();
    final cleanEmail = email.trim();
    final cleanPhone = telefono.trim();

    final normalizedEmail = _normalizeEmail(cleanEmail);

    final normalizedPhone = _normalizePhone(cleanPhone);

    final customerKey = _customerKey(
      normalizedPhone: normalizedPhone,
      normalizedEmail: normalizedEmail,
    );

    // =======================================================
    // CONTROLLO DATI DI BASE
    // =======================================================

    if (guests < 1) {
      throw const BookingCapacityException(
        'Il numero di persone non è valido.',
      );
    }

    if (service != 'lunch' && service != 'dinner') {
      throw const BookingCapacityException('Servizio non valido.');
    }

    if (cleanName.isEmpty) {
      throw const BookingCapacityException('Inserisci il nome.');
    }

    if (cleanEmail.isEmpty) {
      throw const BookingCapacityException('Inserisci un indirizzo email.');
    }

    if (cleanPhone.isEmpty) {
      throw const BookingCapacityException('Inserisci un numero di telefono.');
    }

    // =======================================================
    // LEGGE IL SERVIZIO EFFETTIVO DELLA DATA
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
    // CONTROLLO ORARIO
    // =======================================================

    final availableTimes = CustomerAvailabilityService.generateAvailableTimes(
      selectedService,
      date: normalizedDate,
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
    // CONTROLLO CAPIENZA DEL SERVIZIO
    // =======================================================

    final maxOnlineGuests = selectedService.maxOnlineGuests;

    if (maxOnlineGuests < 1) {
      throw const BookingCapacityException(
        'Questo servizio non accetta prenotazioni online.',
      );
    }

    final dateKey = _dateKey(normalizedDate);

    final autoBooked = guests <= 4;

    final initialStatus = autoBooked ? 'booked' : 'pending';

    final bookingReference = _firestore.collection(_bookingsCollection).doc();

    final counterReference = _firestore
        .collection(_countersCollection)
        .doc('${dateKey}_$service');

    final closureReference = BookingSlotClosuresRepository.reference(
      date: normalizedDate,
      service: service,
      time: time,
    );

    final serviceClosureReference =
        BookingSlotClosuresRepository.serviceReference(
          date: normalizedDate,
          service: service,
        );

    // =======================================================
    // TRANSAZIONE FIRESTORE
    //
    // La verifica dei coperti e il salvataggio
    // avvengono insieme, evitando overbooking.
    // =======================================================

    await _firestore.runTransaction((transaction) async {
      final serviceClosureSnapshot = await transaction.get(
        serviceClosureReference,
      );

      if (serviceClosureSnapshot.exists) {
        throw const BookingCapacityException(
          'Servizio completo. Seleziona un altro servizio.',
        );
      }

      final closureSnapshot = await transaction.get(closureReference);

      if (closureSnapshot.exists) {
        throw const BookingCapacityException(
          'Fascia oraria completa. Seleziona un altro orario.',
        );
      }
      final counterSnapshot = await transaction.get(counterReference);

      var bookedGuests = 0;

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

      // =================================================
      // CREA PRENOTAZIONE
      // =================================================

      transaction.set(bookingReference, {
        'nome': cleanName,

        'cognome': cleanSurname,

        'email': cleanEmail,

        'normalizedEmail': normalizedEmail,

        'telefono': cleanPhone,

        'normalizedPhone': normalizedPhone,

        'customerKey': customerKey,

        'date': Timestamp.fromDate(normalizedDate),

        'dateKey': dateKey,

        'weekday': normalizedDate.weekday,

        'time': time,

        'service': service,

        'guests': guests,

        'occasion': occasion,

        'notes': notes.trim(),

        'status': initialStatus,

        'autoBooked': autoBooked,

        'autoConfirmed': autoBooked,

        'requiresManualConfirmation': !autoBooked,

        'source': 'customer',

        // =============================================
        // CONSENSI MARKETING
        //
        // Sono separati dalla prenotazione.
        // Verranno gestiti successivamente
        // nella sezione Contatti e Marketing.
        // =============================================
        'bookingWhatsappConsent': bookingWhatsappConsent,
        'bookingWhatsappConsentVersion': '1.0',
        'bookingWhatsappConsentSource': 'customer_booking_submit',
        'bookingWhatsappConsentRecordedAt': FieldValue.serverTimestamp(),
        'marketingEmailConsent': marketingEmailConsent,

        'marketingWhatsappConsent': marketingWhatsappConsent,

        'marketingConsentVersion': '1.0',

        'marketingConsentSource': 'customer_booking',

        'marketingConsentRecordedAt': FieldValue.serverTimestamp(),

        // =============================================
        // EMAIL OPERATIVE
        // =============================================
        'requestReceivedEmailSent': false,

        'confirmationEmailSent': false,

        'cancellationEmailSent': false,

        'rejectionEmailSent': false,

        // =============================================
        // WHATSAPP OPERATIVO
        // =============================================
        'confirmationWhatsappSent': false,

        'cancellationWhatsappSent': false,

        'rejectionWhatsappSent': false,

        // =============================================
        // NOTIFICA GESTIONALE
        // =============================================
        'adminNotificationSent': false,

        // =============================================
        // STORICO STATO
        // =============================================
        'bookedAt': autoBooked ? FieldValue.serverTimestamp() : null,

        'bookedBy': autoBooked ? 'automatic' : null,

        'confirmedAt': null,

        'confirmedBy': null,

        'cancelledAt': null,

        'cancelledBy': null,

        'noShowAt': null,

        'noShowBy': null,

        'noShowRecorded': false,

        'createdAt': FieldValue.serverTimestamp(),

        'updatedAt': FieldValue.serverTimestamp(),
      });

      // =================================================
      // AGGIORNA CONTATORE COPERTI
      //
      // Anche le richieste in attesa bloccano
      // temporaneamente i coperti.
      // =================================================

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
  // NORMALIZZA EMAIL
  // =========================================================

  static String _normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  // =========================================================
  // NORMALIZZA NUMERO TELEFONICO
  //
  // Conserva soltanto le cifre.
  // Se il numero italiano non contiene il prefisso,
  // aggiunge automaticamente 39.
  // =========================================================

  static String _normalizePhone(String phone) {
    var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.startsWith('00') && digits.length > 2) {
      digits = digits.substring(2);
    }

    if (digits.length == 10 && digits.startsWith('3')) {
      digits = '39$digits';
    }

    return digits;
  }

  // =========================================================
  // IDENTIFICATORE CLIENTE
  //
  // Prima scelta: telefono normalizzato.
  // Seconda scelta: email normalizzata.
  // =========================================================

  static String _customerKey({
    required String normalizedPhone,
    required String normalizedEmail,
  }) {
    if (normalizedPhone.isNotEmpty) {
      return 'phone_$normalizedPhone';
    }

    return 'email_$normalizedEmail';
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
