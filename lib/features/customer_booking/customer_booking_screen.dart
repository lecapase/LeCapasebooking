import '../availability/data/booking_slot_closures_repository.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'data/customer_availability_service.dart';
import 'data/firestore_booking_repository.dart';

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

  String selectedOccasione = 'Nessuna';

  bool _loadingAvailability = false;
  bool _saving = false;
  bool _showMoreGuests = false;
  bool marketingConsent = false;

  List<String> lunchTimes = [];
  List<String> dinnerTimes = [];

  Set<String> closedLunchTimes = {};
  Set<String> closedDinnerTimes = {};

  final List<String> occasioni = [
    'Nessuna',
    'Compleanno',
    'Anniversario',
    'Cena romantica',
    'Evento aziendale',
  ];

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

      if (!mounted) {
        return;
      }

      setState(() {
        lunchTimes = _filterBookableTimes(normalizedDate, loadedLunchTimes);
        dinnerTimes = _filterBookableTimes(normalizedDate, loadedDinnerTimes);
        closedLunchTimes = loadedClosures[0];
        closedDinnerTimes = loadedClosures[1];

        if (lunchTimes.isNotEmpty || dinnerTimes.isNotEmpty) {
          currentStep = 1;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _message('Errore disponibilità: $error');
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
      persone = value;
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
        'Questo orario non è più prenotabile. Scegli un orario successivo.',
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
      _message('Compila Nome, Cognome, Email e Telefono.');

      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      _message('Inserisci un indirizzo email valido.');

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

  Future<void> _saveBooking() async {
    if (_saving) {
      return;
    }

    if (selectedDate == null ||
        selectedTime == null ||
        selectedService == null) {
      _message('Data, persone o orario non selezionato.');

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

      _message('Questo orario non è più disponibile. Scegli un nuovo orario.');
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
        occasion: selectedOccasione,
        notes: noteController.text.trim(),
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
              autoConfirmed ? 'Prenotazione confermata' : 'Richiesta ricevuta',
              textAlign: TextAlign.center,
              style: GoogleFonts.libreBaskerville(
                color: dark,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              autoConfirmed
                  ? 'Grazie per aver scelto Le Capase.\n\n'
                        'La tua prenotazione è confermata.'
                  : 'Grazie per aver scelto Le Capase.\n\n'
                        'La richiesta è in attesa di conferma. '
                        'Riceverai una risposta appena possibile.',
              textAlign: TextAlign.center,
              style: GoogleFonts.libreBaskerville(color: dark, height: 1.5),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('CHIUDI'),
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

      _message(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _message('Errore tecnico: $error');
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
    return Scaffold(
      backgroundColor: ivory,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: ivory,
        foregroundColor: dark,
        elevation: 0,
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14, top: 6, bottom: 6),
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Indietro',
              onPressed: _goBack,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            ),
          ),
        ),
        title: Image.asset(
          'assets/images/logo.png',
          height: 60,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                _buildProgress(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 230),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: SingleChildScrollView(
                      key: ValueKey(currentStep),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                      child: _buildCurrentStep(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    const steps = [
      (icon: Icons.calendar_today_outlined, label: 'Data'),
      (icon: Icons.groups_outlined, label: 'Persone'),
      (icon: Icons.schedule_outlined, label: 'Orario'),
      (icon: Icons.person_outline_rounded, label: 'Dati'),
      (icon: Icons.receipt_long_outlined, label: 'Riepilogo'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: border),
        ),
        child: Row(
          children: List.generate(steps.length, (index) {
            final active = index == currentStep;
            final completed = index < currentStep;

            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: completed
                    ? () {
                        _goToPreviousStep(index);
                      }
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 2,
                  ),
                  decoration: BoxDecoration(
                    color: active ? gold : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        completed ? Icons.check_rounded : steps[index].icon,
                        size: 19,
                        color: active
                            ? dark
                            : completed
                            ? gold
                            : muted,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        steps[index].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active ? dark : muted,
                          fontSize: 9,
                          fontWeight: active || completed
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
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
      title: 'Quando vuoi venire?',
      subtitle: 'Tocca una data per continuare.',
      child: Column(
        children: [
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: CalendarDatePicker(
                initialDate: selectedDate ?? firstDate,
                firstDate: firstDate,
                lastDate: DateTime(today.year + 2, 12, 31),
                onDateChanged: _selectDate,
              ),
            ),
          ),
          if (_loadingAvailability) ...[
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: gold),
            const SizedBox(height: 10),
            const Text(
              'Controllo disponibilità…',
              style: TextStyle(color: muted),
            ),
          ],
          if (!_loadingAvailability &&
              selectedDate != null &&
              lunchTimes.isEmpty &&
              dinnerTimes.isEmpty) ...[
            const SizedBox(height: 20),
            _notice(
              text: 'Non ci sono orari prenotabili per questa data.',
              icon: Icons.event_busy_outlined,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGuestsStep() {
    return _section(
      title: 'Quante persone?',
      subtitle: 'Tocca il numero degli ospiti.',
      child: Column(
        children: [
          _buildGuestsGrid(first: 1, last: 8),
          const SizedBox(height: 16),
          Material(
            color: gold,
            shape: const CircleBorder(),
            elevation: 3,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                setState(() {
                  _showMoreGuests = !_showMoreGuests;
                });
              },
              child: SizedBox(
                width: 52,
                height: 52,
                child: Icon(
                  _showMoreGuests ? Icons.remove_rounded : Icons.add_rounded,
                  color: dark,
                  size: 30,
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _showMoreGuests
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _buildGuestsGrid(first: 9, last: 20),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 18),
          Text(
            'Per gruppi superiori a 20 persone '
            'contattaci direttamente.',
            textAlign: TextAlign.center,
            style: GoogleFonts.libreBaskerville(
              color: muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestsGrid({required int first, required int last}) {
    final values = List<int>.generate(
      last - first + 1,
      (index) => first + index,
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: values.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, index) {
        final value = values[index];
        final selected = value == persone;

        return Material(
          color: selected ? gold : Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              _selectGuests(value);
            },
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: selected ? gold : border),
              ),
              child: Text(
                '$value',
                style: GoogleFonts.libreBaskerville(
                  color: dark,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeStep() {
    return _section(
      title: 'Scegli un orario disponibile',
      subtitle: selectedDate == null
          ? ''
          : '${_formattedDate(selectedDate!)}'
                ' · $persone '
                '${persone == 1 ? 'persona' : 'persone'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lunchTimes.isNotEmpty)
            _serviceTimes(
              icon: Icons.wb_sunny_outlined,
              title: 'PRANZO',
              times: lunchTimes,
              service: 'lunch',
            ),
          if (lunchTimes.isNotEmpty && dinnerTimes.isNotEmpty)
            const SizedBox(height: 24),
          if (dinnerTimes.isNotEmpty)
            _serviceTimes(
              icon: Icons.nightlight_outlined,
              title: 'CENA',
              times: dinnerTimes,
              service: 'dinner',
            ),
          if (lunchTimes.isEmpty && dinnerTimes.isEmpty)
            _notice(
              text: 'Nessun orario disponibile.',
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: gold.withValues(alpha: 0.20),
                child: Icon(icon, color: dark),
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
            ],
          ),
          const SizedBox(height: 18),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: times.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 9,
              mainAxisSpacing: 9,
              childAspectRatio: 1.55,
            ),
            itemBuilder: (context, index) {
              final time = times[index];

              final isClosed = service == 'lunch'
                  ? closedLunchTimes.contains(time)
                  : closedDinnerTimes.contains(time);

              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                child: InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: () {
                    if (isClosed) {
                      _message(
                        'Fascia oraria completa. Seleziona un altro orario.',
                      );
                      return;
                    }

                    _selectTime(time: time, service: service);
                  },
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: border),
                    ),
                    child: Text(
                      time,
                      style: TextStyle(
                        color: isClosed ? Colors.grey : dark,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        decoration: isClosed
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    return _section(
      title: 'I tuoi dati',
      subtitle: 'Inserisci i dati necessari per la prenotazione.',
      child: Column(
        children: [
          TextField(
            controller: nomeController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.givenName],
            decoration: const InputDecoration(
              labelText: 'Nome *',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: cognomeController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.familyName],
            decoration: const InputDecoration(
              labelText: 'Cognome *',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email *',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: telefonoController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
              labelText: 'Telefono *',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 8),
          const SizedBox(height: 4),
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
                  title: const Text(
                    'Desidero ricevere offerte, eventi e promozioni solo ed esclusivamente da Le Capase.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 12, right: 12, bottom: 6),
                  child: Text(
                    'Confermando la prenotazione si accetta di ricevere aggiornamenti in merito tramite WhatsApp/mail.',
                    style: TextStyle(fontSize: 12, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: selectedOccasione,
            decoration: const InputDecoration(
              labelText: 'Occasione',
              prefixIcon: Icon(Icons.celebration_outlined),
            ),
            items: occasioni
                .map(
                  (occasion) =>
                      DropdownMenuItem(value: occasion, child: Text(occasion)),
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
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Richieste particolari',
              hintText:
                  'Allergie, intolleranze '
                  'o altre richieste',
              prefixIcon: Icon(Icons.notes_outlined),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: _reviewBooking,
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('RIVEDI PRENOTAZIONE'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStep() {
    final serviceText = selectedService == 'lunch' ? 'Pranzo' : 'Cena';

    return _section(
      title: 'Riepilogo',
      subtitle: 'Controlla i dati prima di prenotare.',
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
                  label: 'Data',
                  value: selectedDate == null
                      ? '-'
                      : _formattedDate(selectedDate!),
                ),
                _summaryDivider(),
                _summaryRow(
                  icon: Icons.groups_outlined,
                  label: 'Persone',
                  value: '$persone',
                ),
                _summaryDivider(),
                _summaryRow(
                  icon: Icons.restaurant_outlined,
                  label: 'Servizio',
                  value: serviceText,
                ),
                _summaryDivider(),
                _summaryRow(
                  icon: Icons.schedule_outlined,
                  label: 'Orario',
                  value: selectedTime ?? '-',
                ),
                _summaryDivider(),
                _summaryRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Cliente',
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
                  label: 'Telefono',
                  value: telefonoController.text.trim(),
                ),
                if (selectedOccasione != 'Nessuna') ...[
                  _summaryDivider(),
                  _summaryRow(
                    icon: Icons.celebration_outlined,
                    label: 'Occasione',
                    value: selectedOccasione,
                  ),
                ],
                if (noteController.text.trim().isNotEmpty) ...[
                  _summaryDivider(),
                  _summaryRow(
                    icon: Icons.notes_outlined,
                    label: 'Richieste',
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
                    ? 'INVIO IN CORSO…'
                    : persone <= 4
                    ? 'CONFERMA PRENOTAZIONE'
                    : 'INVIA RICHIESTA',
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'I dati personali saranno trattati nel rispetto della normativa vigente sulla privacy e utilizzati esclusivamente per la gestione della prenotazione e, previo consenso, per comunicazioni promozionali di Le Capase.',
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
                  ? 'La prenotazione sarà confermata immediatamente.'
                  : 'Le richieste da 5 persone in su devono '
                        'essere confermate dal ristorante.',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.left,
          style: GoogleFonts.libreBaskerville(
            color: dark,
            fontSize: 27,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          subtitle,
          style: GoogleFonts.libreBaskerville(
            color: muted,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 22),
        child,
      ],
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

  String _formattedDate(DateTime date) {
    const weekdayNames = [
      'Lunedì',
      'Martedì',
      'Mercoledì',
      'Giovedì',
      'Venerdì',
      'Sabato',
      'Domenica',
    ];

    const monthNames = [
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
    ];

    return '${weekdayNames[date.weekday - 1]} '
        '${date.day} '
        '${monthNames[date.month - 1]} '
        '${date.year}';
  }
}
