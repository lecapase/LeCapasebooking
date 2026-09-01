import '../availability/data/booking_slot_closures_repository.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'data/customer_availability_service.dart';
import 'data/firestore_booking_repository.dart';
import 'booking_language.dart';
import 'privacy_policy_screen.dart';

class CustomerBookingScreen extends StatefulWidget {
  const CustomerBookingScreen({super.key});

  @override
  State<CustomerBookingScreen> createState() => _CustomerBookingScreenState();
}

class _CustomerBookingScreenState extends State<CustomerBookingScreen> {
  static const Color gold = Color(0xFFC8A45D);
  static const Color ivory = Color(0xFFF7F3EB);
  static const Color dark = Color(0xFF171717);
  static const Color muted = Color(0xFF777777);
  static const Color border = Color(0xFFD8D0C2);
  static const Color surface = Color(0xFFFFFDF8);
  static const Color softGold = Color(0xFFF2E6C9);

  final nomeController = TextEditingController();
  final cognomeController = TextEditingController();
  final emailController = TextEditingController();
  final telefonoController = TextEditingController();
  final noteController = TextEditingController();

  DateTime? selectedDate;
  String? selectedTime;
  String? selectedService;

  int persone = 2;
  int currentStep = 0;

  String selectedOccasione = 'none';

  bool _loadingAvailability = false;
  bool _saving = false;
  bool marketingConsent = false;
  bool privacyNoticeAccepted = false;
  bool healthDataConsent = false;

  List<String> lunchTimes = [];
  List<String> dinnerTimes = [];

  Set<String> closedLunchTimes = {};
  Set<String> closedDinnerTimes = {};

  final List<String> occasioni = [
    'none',
    'birthday',
    'anniversary',
    'romantic_dinner',
    'business_event',
  ];

  String _t(String italian, String english) =>
      bookingText(context, italian, english);

  bool get _notesContainHealthData =>
      FirestoreBookingRepository.notesContainHealthData(noteController.text);

  String _occasionLabel(String code) {
    switch (code) {
      case 'birthday':
        return _t('Compleanno', 'Birthday');
      case 'anniversary':
        return _t('Anniversario', 'Anniversary');
      case 'romantic_dinner':
        return _t('Cena romantica', 'Romantic dinner');
      case 'business_event':
        return _t('Evento aziendale', 'Business event');
      default:
        return _t('Nessuna', 'None');
    }
  }

  String _occasionItalianValue(String code) {
    switch (code) {
      case 'birthday':
        return 'Compleanno';
      case 'anniversary':
        return 'Anniversario';
      case 'romantic_dinner':
        return 'Cena romantica';
      case 'business_event':
        return 'Evento aziendale';
      default:
        return 'Nessuna';
    }
  }

  String get _bookingOrigin {
    final source = (Uri.base.queryParameters['utm_source'] ?? '')
        .trim()
        .toLowerCase();

    if (source == 'google' || source == 'google_business') {
      return 'google';
    }

    if (source == 'instagram' || source == 'ig') {
      return 'instagram';
    }

    if (source == 'whatsapp' || source == 'wa' || source == 'whats_app') {
      return 'whatsapp';
    }

    return 'direct';
  }

  @override
  void dispose() {
    nomeController.dispose();
    cognomeController.dispose();
    emailController.dispose();
    telefonoController.dispose();
    noteController.dispose();

    super.dispose();
  }

  DateTime _restaurantNow() {
    final utcNow = DateTime.now().toUtc();

    final dstStart = _lastSundayOfMonthUtc(utcNow.year, DateTime.march);
    final dstEnd = _lastSundayOfMonthUtc(utcNow.year, DateTime.october);

    final isDst = !utcNow.isBefore(dstStart) && utcNow.isBefore(dstEnd);

    final shifted = utcNow.add(Duration(hours: isDst ? 2 : 1));

    // Ora civile di Cisternino/Roma, indipendente dal fuso del cliente.
    return DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
    );
  }

  DateTime _lastSundayOfMonthUtc(int year, int month) {
    final lastDayAtTransitionHour = DateTime.utc(year, month + 1, 0, 1);

    return lastDayAtTransitionHour.subtract(
      Duration(days: lastDayAtTransitionHour.weekday % 7),
    );
  }

  bool _isBookableTime(DateTime date, String time) {
    final now = _restaurantNow();

    final selectedDay = DateTime(date.year, date.month, date.day);

    final today = DateTime(now.year, now.month, now.day);

    if (selectedDay.isBefore(today)) {
      return false;
    }

    if (selectedDay.isAfter(today)) {
      return true;
    }

    final parts = time.split(':');

    if (parts.length != 2) {
      return false;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return false;
    }

    var slotMinutes = (hour * 60) + minute;
    final nowMinutes = (now.hour * 60) + now.minute;

    // Eventuali fasce dopo mezzanotte appartengono alla cena del giorno scelto.
    if (hour < 6 && now.hour >= 6) {
      slotMinutes += 24 * 60;
    }

    return slotMinutes > nowMinutes;
  }

  List<String> _filterBookableTimes(DateTime date, List<String> times) {
    return times.where((time) => _isBookableTime(date, time)).toList();
  }

  Future<void> _selectDate(DateTime date) async {
    if (_loadingAvailability) {
      return;
    }

    final normalizedDate = DateTime(date.year, date.month, date.day);

    setState(() {
      selectedDate = normalizedDate;
      selectedTime = null;
      selectedService = null;
      lunchTimes = [];
      dinnerTimes = [];
      _loadingAvailability = true;
    });

    try {
      final availability =
          await CustomerAvailabilityService.getAvailabilityForDate(
            normalizedDate,
          );

      if (!mounted) {
        return;
      }

      if (availability == null) {
        setState(() {
          lunchTimes = [];
          dinnerTimes = [];
        });

        return;
      }

      final loadedLunchTimes = availability.lunch.isOpen
          ? CustomerAvailabilityService.generateAvailableTimes(
              availability.lunch,
              date: normalizedDate,
            )
          : <String>[];

      final loadedDinnerTimes = availability.dinner.isOpen
          ? CustomerAvailabilityService.generateAvailableTimes(
              availability.dinner,
              date: normalizedDate,
            )
          : <String>[];

      final loadedClosures = await Future.wait([
        BookingSlotClosuresRepository.loadClosedTimes(
          date: normalizedDate,
          service: 'lunch',
        ),
        BookingSlotClosuresRepository.loadClosedTimes(
          date: normalizedDate,
          service: 'dinner',
        ),
      ]);

      final closedServices = await Future.wait([
        BookingSlotClosuresRepository.isServiceClosed(
          date: normalizedDate,
          service: 'lunch',
        ),
        BookingSlotClosuresRepository.isServiceClosed(
          date: normalizedDate,
          service: 'dinner',
        ),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        lunchTimes = _filterBookableTimes(normalizedDate, loadedLunchTimes);
        dinnerTimes = _filterBookableTimes(normalizedDate, loadedDinnerTimes);
        closedLunchTimes = {
          ...loadedClosures[0],
          if (closedServices[0]) ...loadedLunchTimes,
        };
        closedDinnerTimes = {
          ...loadedClosures[1],
          if (closedServices[1]) ...loadedDinnerTimes,
        };

        if (lunchTimes.isNotEmpty || dinnerTimes.isNotEmpty) {
          currentStep = 1;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _message(
        _t('Errore disponibilità: $error', 'Availability error: $error'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingAvailability = false;
        });
      }
    }
  }

  void _selectGuests(int value) {
    setState(() {
      persone = value.clamp(1, 20);
      selectedTime = null;
      selectedService = null;
    });
  }

  void _continueFromGuests() {
    setState(() {
      selectedTime = null;
      selectedService = null;
      currentStep = 2;
    });
  }

  void _selectTime({required String time, required String service}) {
    if (selectedDate == null || !_isBookableTime(selectedDate!, time)) {
      setState(() {
        if (selectedDate != null) {
          lunchTimes = _filterBookableTimes(selectedDate!, lunchTimes);
          dinnerTimes = _filterBookableTimes(selectedDate!, dinnerTimes);
        }
      });

      _message(
        _t(
          'Questo orario non è più prenotabile. Scegli un orario successivo.',
          'This time can no longer be booked. Please choose a later time.',
        ),
      );
      return;
    }

    setState(() {
      selectedTime = time;
      selectedService = service;
      currentStep = 3;
    });
  }

  void _goBack() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
      });

      return;
    }

    Navigator.of(context).maybePop();
  }

  void _goToPreviousStep(int step) {
    if (step >= currentStep) {
      return;
    }

    setState(() {
      currentStep = step;
    });
  }

  void _reviewBooking() {
    final nome = nomeController.text.trim();
    final cognome = cognomeController.text.trim();
    final email = emailController.text.trim();
    final telefono = telefonoController.text.trim();

    if (nome.isEmpty || cognome.isEmpty || email.isEmpty || telefono.isEmpty) {
      _message(
        _t(
          'Compila Nome, Cognome, Email e Telefono.',
          'Enter your first name, last name, email and phone number.',
        ),
      );

      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      _message(
        _t(
          'Inserisci un indirizzo email valido.',
          'Enter a valid email address.',
        ),
      );

      return;
    }

    if (!privacyNoticeAccepted) {
      _message(
        _t(
          'Per continuare, conferma di aver letto l’Informativa Privacy.',
          'To continue, confirm that you have read the Privacy Notice.',
        ),
      );
      return;
    }

    if (_notesContainHealthData && !healthDataConsent) {
      _message(
        _t(
          'Per continuare, esprimi il consenso al trattamento delle informazioni sanitarie inserite nelle Note.',
          'To continue, consent to the processing of the health information entered in Notes.',
        ),
      );
      return;
    }

    setState(() {
      currentStep = 4;
    });
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _showHealthDataDetails() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('Trattamento delle Note', 'Processing of Notes')),
        content: Text(
          _t(
            'Le informazioni sanitarie eventualmente inserite nelle Note sono utilizzate esclusivamente per gestire questa prenotazione. Il consenso è facoltativo: puoi rimuovere tali informazioni e continuare a prenotare. Le Note vengono cancellate automaticamente al termine del servizio o in caso di annullamento o rifiuto.',
            'Any health information entered in Notes is used solely to manage this booking. Consent is optional: you may remove that information and continue booking. Notes are automatically deleted after the service or if the booking is cancelled or rejected.',
          ),
          style: const TextStyle(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_t('CHIUDI', 'CLOSE')),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBooking() async {
    if (_saving) {
      return;
    }

    if (selectedDate == null ||
        selectedTime == null ||
        selectedService == null) {
      _message(
        _t(
          'Data, persone o orario non selezionato.',
          'Date, number of guests or time not selected.',
        ),
      );

      return;
    }

    if (!_isBookableTime(selectedDate!, selectedTime!)) {
      setState(() {
        lunchTimes = _filterBookableTimes(selectedDate!, lunchTimes);
        dinnerTimes = _filterBookableTimes(selectedDate!, dinnerTimes);
        selectedTime = null;
        selectedService = null;
        currentStep = 2;
      });

      _message(
        _t(
          'Questo orario non è più disponibile. Scegli un nuovo orario.',
          'This time is no longer available. Please choose another time.',
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await FirestoreBookingRepository.createBooking(
        nome: nomeController.text.trim(),
        cognome: cognomeController.text.trim(),
        email: emailController.text.trim(),
        telefono: telefonoController.text.trim(),
        date: selectedDate!,
        time: selectedTime!,
        guests: persone,
        service: selectedService!,
        occasion: _occasionItalianValue(selectedOccasione),
        occasionCode: selectedOccasione,
        language: bookingIsItalian(context) ? 'it' : 'en',
        bookingOrigin: _bookingOrigin,
        notes: noteController.text.trim(),
        privacyNoticeAccepted: privacyNoticeAccepted,
        healthDataConsent: healthDataConsent,
        bookingWhatsappConsent: true,
        marketingEmailConsent: marketingConsent,
        marketingWhatsappConsent: marketingConsent,
      );

      if (!mounted) {
        return;
      }

      final autoConfirmed = persone <= 4;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: Colors.white,
            icon: Icon(
              autoConfirmed
                  ? Icons.check_circle_rounded
                  : Icons.schedule_rounded,
              color: gold,
              size: 56,
            ),
            title: Text(
              autoConfirmed
                  ? _t('Prenotazione confermata', 'Booking confirmed')
                  : _t('Richiesta ricevuta', 'Request received'),
              textAlign: TextAlign.center,
              style: GoogleFonts.libreBaskerville(
                color: dark,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              autoConfirmed
                  ? _t(
                      'Grazie per aver scelto Le Capase.\n\nLa tua prenotazione è confermata.',
                      'Thank you for choosing Le Capase.\n\nYour booking is confirmed.',
                    )
                  : _t(
                      'Grazie per aver scelto Le Capase.\n\nLa richiesta è in attesa di conferma. Riceverai una risposta appena possibile.',
                      'Thank you for choosing Le Capase.\n\nYour request is awaiting confirmation. We will reply as soon as possible.',
                    ),
              textAlign: TextAlign.center,
              style: GoogleFonts.libreBaskerville(color: dark, height: 1.5),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: Text(_t('CHIUDI', 'CLOSE')),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).maybePop();
    } on BookingCapacityException catch (error) {
      if (!mounted) {
        return;
      }

      _message(_localizedRepositoryError(error.message));
    } catch (error) {
      if (!mounted) {
        return;
      }

      _message(_t('Errore tecnico: $error', 'Technical error: $error'));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);

    return Theme(
      data: baseTheme.copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          prefixIconColor: const Color(0xFF8A6726),
          labelStyle: const TextStyle(color: muted),
          floatingLabelStyle: const TextStyle(
            color: Color(0xFF8A6726),
            fontWeight: FontWeight.w700,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: gold, width: 1.6),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: ivory,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: 76,
          backgroundColor: ivory,
          foregroundColor: dark,
          elevation: 0,
          leadingWidth: 72,
          leading: Padding(
            padding: const EdgeInsets.only(left: 14, top: 10, bottom: 10),
            child: Material(
              color: surface,
              shape: const CircleBorder(),
              elevation: 1,
              child: IconButton(
                tooltip: _t('Indietro', 'Back'),
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
              ),
            ),
          ),
          title: Container(
            height: 58,
            width: 118,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF12100D),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: gold.withValues(alpha: 0.45)),
            ),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          centerTitle: true,
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(child: BookingLanguageToggle(compact: true)),
            ),
          ],
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF7F3EB), Color(0xFFFBF8F1)],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  children: [
                    _buildProgress(),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final showSidebar =
                              constraints.maxWidth >= 960 && currentStep > 0;

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 260),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  child: SingleChildScrollView(
                                    key: ValueKey(currentStep),
                                    padding: EdgeInsets.fromLTRB(
                                      showSidebar ? 30 : 20,
                                      12,
                                      showSidebar ? 18 : 20,
                                      42,
                                    ),
                                    child: Column(
                                      children: [
                                        if (!showSidebar &&
                                            currentStep > 0) ...[
                                          _buildSelectionStrip(),
                                          const SizedBox(height: 22),
                                        ],
                                        _buildCurrentStep(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (showSidebar)
                                SizedBox(
                                  width: 320,
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      12,
                                      30,
                                      42,
                                    ),
                                    child: _buildBookingSidebar(),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final steps = [
      (icon: Icons.calendar_today_outlined, label: _t('Data', 'Date')),
      (icon: Icons.groups_outlined, label: _t('Persone', 'Guests')),
      (icon: Icons.schedule_outlined, label: _t('Orario', 'Time')),
      (icon: Icons.person_outline_rounded, label: _t('Dati', 'Details')),
      (icon: Icons.receipt_long_outlined, label: _t('Riepilogo', 'Summary')),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border.withValues(alpha: 0.75)),
          boxShadow: [
            BoxShadow(
              color: dark.withValues(alpha: 0.05),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  _t('La tua prenotazione', 'Your reservation'),
                  style: const TextStyle(
                    color: dark,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  _t(
                    'Passaggio ${currentStep + 1} di ${steps.length}',
                    'Step ${currentStep + 1} of ${steps.length}',
                  ),
                  style: const TextStyle(
                    color: muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(steps.length, (index) {
                final active = index == currentStep;
                final completed = index < currentStep;

                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: completed ? () => _goToPreviousStep(index) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 4,
                            decoration: BoxDecoration(
                              color: active || completed
                                  ? gold
                                  : const Color(0xFFE8E1D6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                completed
                                    ? Icons.check_circle_rounded
                                    : steps[index].icon,
                                size: 15,
                                color: active || completed ? gold : muted,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  steps[index].label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: active ? dark : muted,
                                    fontSize: 10,
                                    fontWeight: active || completed
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionStrip() {
    final items = <({IconData icon, String text})>[
      if (selectedDate != null)
        (
          icon: Icons.calendar_today_rounded,
          text: _formattedDate(selectedDate!),
        ),
      (icon: Icons.group_rounded, text: '$persone'),
      if (selectedTime != null)
        (
          icon: selectedService == 'lunch'
              ? Icons.wb_sunny_rounded
              : Icons.nightlight_round,
          text: selectedTime!,
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: softGold.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withValues(alpha: 0.42)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: items
            .map(
              (item) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, size: 16, color: const Color(0xFF8A6726)),
                  const SizedBox(width: 6),
                  Text(
                    item.text,
                    style: const TextStyle(
                      color: dark,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildBookingSidebar() {
    final serviceText = selectedService == null
        ? _t('Da scegliere', 'To be selected')
        : selectedService == 'lunch'
        ? _t('Pranzo', 'Lunch')
        : _t('Cena', 'Dinner');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF191713),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: gold.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: dark.withValues(alpha: 0.13),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Il tuo tavolo', 'Your table'),
            style: GoogleFonts.libreBaskerville(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _t(
              'Il riepilogo si aggiorna mentre scegli.',
              'Your summary updates as you choose.',
            ),
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 20),
          _sidebarRow(
            Icons.calendar_today_rounded,
            _t('Data', 'Date'),
            selectedDate == null ? '—' : _formattedDate(selectedDate!),
          ),
          _sidebarRow(Icons.group_rounded, _t('Ospiti', 'Guests'), '$persone'),
          _sidebarRow(
            Icons.restaurant_rounded,
            _t('Servizio', 'Service'),
            serviceText,
          ),
          _sidebarRow(
            Icons.schedule_rounded,
            _t('Orario', 'Time'),
            selectedTime ?? '—',
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.place_outlined, color: gold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _t('Cisternino · Puglia', 'Cisternino · Puglia'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sidebarRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: gold, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (currentStep) {
      case 0:
        return _buildDateStep();

      case 1:
        return _buildGuestsStep();

      case 2:
        return _buildTimeStep();

      case 3:
        return _buildDetailsStep();

      case 4:
        return _buildSummaryStep();

      default:
        return _buildDateStep();
    }
  }

  Widget _buildDateStep() {
    final today = DateTime.now();

    final firstDate = DateTime(today.year, today.month, today.day);

    return _section(
      title: _t('Quando vuoi venire?', 'When would you like to visit?'),
      subtitle: _t(
        'Tocca una data per continuare.',
        'Select a date to continue.',
      ),
      child: Column(
        children: [
          Card(
            elevation: 0,
            color: surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: border.withValues(alpha: 0.85)),
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: dark.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: const Color(0xFF9B741F),
                    onPrimary: Colors.white,
                    surface: surface,
                  ),
                ),
                child: CalendarDatePicker(
                  initialDate: selectedDate ?? firstDate,
                  firstDate: firstDate,
                  lastDate: DateTime(today.year + 2, 12, 31),
                  onDateChanged: _selectDate,
                ),
              ),
            ),
          ),
          if (_loadingAvailability) ...[
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: gold),
            const SizedBox(height: 10),
            Text(
              _t('Controllo disponibilità…', 'Checking availability…'),
              style: const TextStyle(color: muted),
            ),
          ],
          if (!_loadingAvailability &&
              selectedDate != null &&
              lunchTimes.isEmpty &&
              dinnerTimes.isEmpty) ...[
            const SizedBox(height: 20),
            _notice(
              text: _t(
                'Non ci sono orari prenotabili per questa data.',
                'There are no available times for this date.',
              ),
              icon: Icons.event_busy_outlined,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGuestsStep() {
    return _section(
      title: _t('Quante persone?', 'How many guests?'),
      subtitle: _t(
        'Tocca il numero degli ospiti.',
        'Select the number of guests.',
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: border.withValues(alpha: 0.85)),
              boxShadow: [
                BoxShadow(
                  color: dark.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: softGold,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.table_restaurant_rounded,
                    color: Color(0xFF8A6726),
                    size: 29,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _guestCounterButton(
                      icon: Icons.remove_rounded,
                      enabled: persone > 1,
                      onPressed: () => _selectGuests(persone - 1),
                    ),
                    SizedBox(
                      width: 126,
                      child: Column(
                        children: [
                          Text(
                            '$persone',
                            style: GoogleFonts.libreBaskerville(
                              color: dark,
                              fontSize: 48,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            persone == 1
                                ? _t('persona', 'guest')
                                : _t('persone', 'guests'),
                            style: const TextStyle(
                              color: muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _guestCounterButton(
                      icon: Icons.add_rounded,
                      enabled: persone < 20,
                      onPressed: () => _selectGuests(persone + 1),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  _t('Selezione rapida', 'Quick selection'),
                  style: const TextStyle(
                    color: muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [1, 2, 4, 6, 8, 10]
                      .map(
                        (value) => ChoiceChip(
                          label: Text('$value'),
                          selected: persone == value,
                          onSelected: (_) => _selectGuests(value),
                          selectedColor: gold,
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: persone == value ? gold : border,
                          ),
                          labelStyle: const TextStyle(
                            color: dark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _t(
              'Per gruppi superiori a 20 persone contattaci direttamente.',
              'For groups of more than 20 guests, please contact us directly.',
            ),
            textAlign: TextAlign.center,
            style: GoogleFonts.libreBaskerville(
              color: muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          _primaryAction(
            label: _t('SCEGLI L’ORARIO', 'CHOOSE A TIME'),
            icon: Icons.arrow_forward_rounded,
            onPressed: _continueFromGuests,
          ),
        ],
      ),
    );
  }

  Widget _guestCounterButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: enabled ? dark : const Color(0xFFE5E0D7),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon),
        color: Colors.white,
        disabledColor: Colors.white70,
        iconSize: 26,
        padding: const EdgeInsets.all(15),
      ),
    );
  }

  Widget _primaryAction({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: dark,
          disabledBackgroundColor: const Color(0xFFE1D9C8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildTimeStep() {
    return _section(
      title: _t('Scegli un orario disponibile', 'Choose an available time'),
      subtitle: selectedDate == null
          ? ''
          : '${_formattedDate(selectedDate!)}'
                ' · $persone '
                '${persone == 1 ? _t('persona', 'guest') : _t('persone', 'guests')}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lunchTimes.isNotEmpty)
            _serviceTimes(
              icon: Icons.wb_sunny_outlined,
              title: _t('PRANZO', 'LUNCH'),
              times: lunchTimes,
              service: 'lunch',
            ),
          if (lunchTimes.isNotEmpty && dinnerTimes.isNotEmpty)
            const SizedBox(height: 24),
          if (dinnerTimes.isNotEmpty)
            _serviceTimes(
              icon: Icons.nightlight_outlined,
              title: _t('CENA', 'DINNER'),
              times: dinnerTimes,
              service: 'dinner',
            ),
          if (lunchTimes.isEmpty && dinnerTimes.isEmpty)
            _notice(
              text: _t('Nessun orario disponibile.', 'No times available.'),
              icon: Icons.schedule_outlined,
            ),
        ],
      ),
    );
  }

  Widget _serviceTimes({
    required IconData icon,
    required String title,
    required List<String> times,
    required String service,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: dark.withValues(alpha: 0.055),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: softGold,
                child: Icon(icon, color: const Color(0xFF8A6726)),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.libreBaskerville(
                  color: dark,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EEE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _t('${times.length} orari', '${times.length} times'),
                  style: const TextStyle(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 360 ? 3 : 4;
              const spacing = 9.0;
              final itemWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: times.map((time) {
                  final isClosed = service == 'lunch'
                      ? closedLunchTimes.contains(time)
                      : closedDinnerTimes.contains(time);

                  return SizedBox(
                    width: itemWidth,
                    height: 52,
                    child: Material(
                      color: isClosed ? const Color(0xFFF2EFE9) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          if (isClosed) {
                            _message(
                              _t(
                                'Fascia oraria completa. Seleziona un altro orario.',
                                'This time slot is full. Please choose another time.',
                              ),
                            );
                            return;
                          }

                          _selectTime(time: time, service: service);
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isClosed
                                  ? const Color(0xFFE4DED3)
                                  : gold.withValues(alpha: 0.55),
                            ),
                          ),
                          child: Text(
                            time,
                            style: TextStyle(
                              color: isClosed ? Colors.grey : dark,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              decoration: isClosed
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    return _section(
      title: _t('I tuoi dati', 'Your details'),
      subtitle: _t(
        'Inserisci i dati necessari per la prenotazione.',
        'Enter the details needed for your booking.',
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border.withValues(alpha: 0.85)),
          boxShadow: [
            BoxShadow(
              color: dark.withValues(alpha: 0.055),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            TextField(
              controller: nomeController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.givenName],
              decoration: InputDecoration(
                labelText: _t('Nome *', 'First name *'),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: cognomeController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.familyName],
              decoration: InputDecoration(
                labelText: _t('Cognome *', 'Last name *'),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: 'Email *',
                prefixIcon: const Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: telefonoController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              decoration: InputDecoration(
                labelText: _t('Telefono *', 'Phone *'),
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
            ),

            DropdownButtonFormField<String>(
              initialValue: selectedOccasione,
              decoration: InputDecoration(
                labelText: _t('Occasione', 'Occasion'),
                prefixIcon: const Icon(Icons.celebration_outlined),
              ),
              items: occasioni
                  .map(
                    (occasion) => DropdownMenuItem(
                      value: occasion,
                      child: Text(_occasionLabel(occasion)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  selectedOccasione = value;
                });
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: noteController,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                setState(() {
                  if (!_notesContainHealthData) healthDataConsent = false;
                });
              },
              decoration: InputDecoration(
                labelText: _t('Note (facoltative)', 'Notes (optional)'),
                hintText: _t(
                  'Inserisci eventuali richieste per la prenotazione',
                  'Enter any requests for your booking',
                ),
                prefixIcon: const Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0x14C8A45D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x66C8A45D)),
              ),
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: privacyNoticeAccepted,
                onChanged: (value) {
                  setState(() {
                    privacyNoticeAccepted = value ?? false;
                  });
                },
                title: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _t(
                        'Dichiaro di aver letto l’',
                        'I confirm that I have read the ',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const PrivacyPolicyScreen(),
                          ),
                        );
                      },
                      child: Text(
                        _t('Informativa Privacy *', 'Privacy Notice *'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_notesContainHealthData) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x14C8A45D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x66C8A45D)),
                ),
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: healthDataConsent,
                  onChanged: (value) {
                    setState(() {
                      healthDataConsent = value ?? false;
                    });
                  },
                  title: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _t(
                          'Acconsento esplicitamente al trattamento delle informazioni sanitarie inserite nelle Note, esclusivamente per gestire questa prenotazione. *',
                          'I explicitly consent to the processing of the health information entered in Notes solely to manage this booking. *',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextButton(
                        onPressed: _showHealthDataDetails,
                        child: Text(_t('Dettagli', 'Details')),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0x14C8A45D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x66C8A45D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: marketingConsent,
                    onChanged: (value) {
                      setState(() {
                        marketingConsent = value ?? false;
                      });
                    },
                    title: Text(
                      _t(
                        'Desidero ricevere offerte, eventi e promozioni di Le Capase tramite email e WhatsApp (facoltativo).',
                        'I would like to receive Le Capase offers, events and promotions by email and WhatsApp (optional).',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 12,
                      right: 12,
                      bottom: 6,
                    ),
                    child: Text(
                      _t(
                        'Le comunicazioni operative sulla prenotazione tramite email e WhatsApp sono necessarie alla gestione del servizio e sono descritte nell’Informativa Privacy.',
                        'Operational booking updates by email and WhatsApp are necessary to manage the service and are described in the Privacy Notice.',
                      ),
                      style: const TextStyle(fontSize: 12, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _primaryAction(
              label: _t('RIVEDI PRENOTAZIONE', 'REVIEW BOOKING'),
              icon: Icons.arrow_forward_rounded,
              onPressed: _reviewBooking,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStep() {
    final serviceText = selectedService == 'lunch'
        ? _t('Pranzo', 'Lunch')
        : _t('Cena', 'Dinner');

    return _section(
      title: _t('Riepilogo', 'Summary'),
      subtitle: _t(
        'Controlla i dati prima di prenotare.',
        'Check your details before booking.',
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                _summaryRow(
                  icon: Icons.calendar_today_outlined,
                  label: _t('Data', 'Date'),
                  value: selectedDate == null
                      ? '-'
                      : _formattedDate(selectedDate!),
                ),
                _summaryDivider(),
                _summaryRow(
                  icon: Icons.groups_outlined,
                  label: _t('Persone', 'Guests'),
                  value: '$persone',
                ),
                _summaryDivider(),
                _summaryRow(
                  icon: Icons.restaurant_outlined,
                  label: _t('Servizio', 'Service'),
                  value: serviceText,
                ),
                _summaryDivider(),
                _summaryRow(
                  icon: Icons.schedule_outlined,
                  label: _t('Orario', 'Time'),
                  value: selectedTime ?? '-',
                ),
                _summaryDivider(),
                _summaryRow(
                  icon: Icons.person_outline_rounded,
                  label: _t('Cliente', 'Guest'),
                  value:
                      '${nomeController.text.trim()} '
                      '${cognomeController.text.trim()}',
                ),
                _summaryDivider(),
                _summaryRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: emailController.text.trim(),
                ),
                _summaryDivider(),
                _summaryRow(
                  icon: Icons.phone_outlined,
                  label: _t('Telefono', 'Phone'),
                  value: telefonoController.text.trim(),
                ),
                if (selectedOccasione != 'none') ...[
                  _summaryDivider(),
                  _summaryRow(
                    icon: Icons.celebration_outlined,
                    label: _t('Occasione', 'Occasion'),
                    value: _occasionLabel(selectedOccasione),
                  ),
                ],
                if (noteController.text.trim().isNotEmpty) ...[
                  _summaryDivider(),
                  _summaryRow(
                    icon: Icons.notes_outlined,
                    label: _t('Note', 'Notes'),
                    value: noteController.text.trim(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          _confirmationNotice(),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton.icon(
              onPressed: _saving ? null : _saveBooking,
              icon: _saving
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: dark,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(
                _saving
                    ? _t('INVIO IN CORSO…', 'SENDING…')
                    : persone <= 4
                    ? _t('CONFERMA PRENOTAZIONE', 'CONFIRM BOOKING')
                    : _t('INVIA RICHIESTA', 'SEND REQUEST'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              _t(
                'I dati personali saranno trattati nel rispetto della normativa vigente sulla privacy e utilizzati esclusivamente per la gestione della prenotazione e, previo consenso, per comunicazioni promozionali di Le Capase.',
                'Personal data will be processed in accordance with applicable privacy laws and used only to manage the booking and, with consent, for Le Capase promotional communications.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, height: 1.4, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _confirmationNotice() {
    final automatic = persone <= 4;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: automatic
            ? Colors.green.withValues(alpha: 0.10)
            : gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: automatic
              ? Colors.green.withValues(alpha: 0.35)
              : gold.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          Icon(
            automatic ? Icons.check_circle_outline : Icons.schedule_outlined,
            color: automatic ? Colors.green : const Color(0xFF8A6726),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              automatic
                  ? _t(
                      'La prenotazione sarà confermata immediatamente.',
                      'Your booking will be confirmed immediately.',
                    )
                  : _t(
                      'Le richieste da 5 persone in su devono essere confermate dal ristorante.',
                      'Requests for 5 or more guests must be confirmed by the restaurant.',
                    ),
              style: const TextStyle(
                color: dark,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final compact = MediaQuery.sizeOf(context).width < 600;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 780),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(width: 28, height: 2, color: gold),
              const SizedBox(width: 9),
              Text(
                _t('LE CAPASE · PRENOTAZIONI', 'LE CAPASE · RESERVATIONS'),
                style: const TextStyle(
                  color: Color(0xFF8A6726),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.25,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.left,
            style: GoogleFonts.libreBaskerville(
              color: dark,
              fontSize: compact ? 27 : 32,
              fontWeight: FontWeight.w700,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: muted,
              fontSize: compact ? 14 : 15,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }

  Widget _notice({required String text, required IconData icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: gold),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(color: dark, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: gold, size: 21),
        const SizedBox(width: 12),
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: const TextStyle(color: muted, fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: dark,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 13),
      child: Divider(height: 1, color: Color(0xFFE8E1D6)),
    );
  }

  String _localizedRepositoryError(String message) {
    if (bookingIsItalian(context)) return message;

    const translations = <String, String>{
      'Il numero di persone non è valido.': 'The number of guests is invalid.',
      'Servizio non valido.': 'Invalid service.',
      'Inserisci il nome.': 'Enter your first name.',
      'Inserisci un indirizzo email.': 'Enter an email address.',
      'Inserisci un numero di telefono.': 'Enter a phone number.',
      'È necessario leggere l’Informativa Privacy.':
          'You must read the Privacy Notice.',
      'Le Note non possono superare 500 caratteri.':
          'Notes cannot exceed 500 characters.',
      'È necessario il consenso per le informazioni sanitarie inserite nelle Note.':
          'Consent is required for health information entered in Notes.',
      'Nessun servizio disponibile per questa data.':
          'No service is available for this date.',
      'Questo servizio non è disponibile.': 'This service is not available.',
      'L’orario selezionato non è più disponibile.':
          'The selected time is no longer available.',
      'L’orario selezionato è stato bloccato.':
          'The selected time has been blocked.',
      'Questo servizio non accetta prenotazioni online.':
          'This service is not accepting online bookings.',
      'Servizio completo. Seleziona un altro servizio.':
          'This service is full. Please select another service.',
      'Fascia oraria completa. Seleziona un altro orario.':
          'This time slot is full. Please select another time.',
      'Non ci sono abbastanza posti disponibili per questo servizio.':
          'There are not enough places available for this service.',
    };

    return translations[message] ?? message;
  }

  String _formattedDate(DateTime date) {
    final weekdayNames = bookingIsItalian(context)
        ? const [
            'Lunedì',
            'Martedì',
            'Mercoledì',
            'Giovedì',
            'Venerdì',
            'Sabato',
            'Domenica',
          ]
        : const [
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
            'Saturday',
            'Sunday',
          ];

    final monthNames = bookingIsItalian(context)
        ? const [
            'gennaio',
            'febbraio',
            'marzo',
            'aprile',
            'maggio',
            'giugno',
            'luglio',
            'agosto',
            'settembre',
            'ottobre',
            'novembre',
            'dicembre',
          ]
        : const [
            'January',
            'February',
            'March',
            'April',
            'May',
            'June',
            'July',
            'August',
            'September',
            'October',
            'November',
            'December',
          ];

    return '${weekdayNames[date.weekday - 1]} '
        '${date.day} '
        '${monthNames[date.month - 1]} '
        '${date.year}';
  }
}
