import 'package:flutter/material.dart';

import '../availability/models/service_availability.dart';
import 'data/customer_availability_service.dart';
import 'data/firestore_booking_repository.dart';

class CustomerBookingScreen extends StatefulWidget {
  const CustomerBookingScreen({super.key});

  @override
  State<CustomerBookingScreen> createState() =>
      _CustomerBookingScreenState();
}

class _CustomerBookingScreenState extends State<CustomerBookingScreen> {
  static const Color gold = Color(0xFFC8A45D);
  static const Color ivory = Color(0xFFF7F3EB);
  static const Color dark = Color(0xFF171717);

  final nomeController = TextEditingController();
  final cognomeController = TextEditingController();
  final emailController = TextEditingController();
  final telefonoController = TextEditingController();
  final noteController = TextEditingController();

  DateTime? selectedDate;

  String? selectedTime;

  // lunch oppure dinner
  String? selectedService;

  int persone = 2;
  int currentStep = 0;

  String selectedOccasione = 'Nessuna';

  bool _loadingAvailability = false;
  bool _saving = false;

  List<String> lunchTimes = [];
  List<String> dinnerTimes = [];

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

  // =========================================================
  // DATA
  // =========================================================

  Future<void> _selectDate() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(
        now.year,
        now.month,
        now.day,
      ),
      lastDate: DateTime(
        now.year + 2,
        12,
        31,
      ),
    );

    if (date == null) {
      return;
    }

    setState(() {
      selectedDate = date;
      selectedTime = null;
      selectedService = null;
      lunchTimes = [];
      dinnerTimes = [];
    });

    await _loadAvailability(date);

    if (!mounted) {
      return;
    }

    if (lunchTimes.isNotEmpty || dinnerTimes.isNotEmpty) {
      setState(() {
        currentStep = 1;
      });
    }
  }

  // =========================================================
  // FIREBASE - DISPONIBILITÀ
  // =========================================================

  Future<void> _loadAvailability(
    DateTime date,
  ) async {
    setState(() {
      _loadingAvailability = true;

      selectedTime = null;
      selectedService = null;

      lunchTimes = [];
      dinnerTimes = [];
    });

    try {
      final availability =
          await CustomerAvailabilityService
              .getAvailabilityForDate(
        date,
      );

      if (!mounted) {
        return;
      }

      if (availability == null) {
        return;
      }

      final loadedLunchTimes = <String>[];
      final loadedDinnerTimes = <String>[];

      if (availability.lunch.isOpen) {
        loadedLunchTimes.addAll(
          _generateTimes(
            availability.lunch,
          ),
        );
      }

      if (availability.dinner.isOpen) {
        loadedDinnerTimes.addAll(
          _generateTimes(
            availability.dinner,
          ),
        );
      }

      setState(() {
        lunchTimes = loadedLunchTimes;
        dinnerTimes = loadedDinnerTimes;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossibile caricare gli orari disponibili.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingAvailability = false;
        });
      }
    }
  }

  // =========================================================
  // GENERA GLI ORARI
  // =========================================================

  List<String> _generateTimes(
    ServiceAvailability service,
  ) {
    final result = <String>[];

    final start = _toMinutes(
      service.startTime,
    );

    final end = _toMinutes(
      service.endTime,
    );

    var current = start;

    while (current <= end) {
      final time = _minutesToTime(
        current,
      );

      final blocked =
          CustomerAvailabilityService
              .isTimeBlocked(
        service: service,
        time: time,
      );

      if (!blocked) {
        result.add(time);
      }

      current += 15;
    }

    return result;
  }

  int _toMinutes(
    String value,
  ) {
    final parts = value.split(':');

    return int.parse(parts[0]) * 60 +
        int.parse(parts[1]);
  }

  String _minutesToTime(
    int minutes,
  ) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;

    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  // =========================================================
  // NAVIGAZIONE
  // =========================================================

  void _goToStep(
    int step,
  ) {
    if (step < currentStep) {
      setState(() {
        currentStep = step;
      });
    }
  }

  void _continueFromTime() {
    if (selectedTime == null ||
        selectedService == null) {
      _message(
        'Seleziona un orario.',
      );

      return;
    }

    setState(() {
      currentStep = 2;
    });
  }

  void _continueFromGuests() {
    setState(() {
      currentStep = 3;
    });
  }

  void _continueFromDetails() {
    if (nomeController.text.trim().isEmpty ||
        cognomeController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        telefonoController.text.trim().isEmpty) {
      _message(
        'Compila Nome, Cognome, Email e Telefono.',
      );

      return;
    }

    final email = emailController.text.trim();

    if (!email.contains('@') ||
        !email.contains('.')) {
      _message(
        'Inserisci un indirizzo email valido.',
      );

      return;
    }

    setState(() {
      currentStep = 4;
    });
  }

  void _message(
    String text,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
      ),
    );
  }

  // =========================================================
  // SALVA PRENOTAZIONE SU FIRESTORE
  // =========================================================

  Future<void> _salvaPrenotazione() async {
    if (_saving) {
      return;
    }

    if (selectedDate == null ||
        selectedTime == null ||
        selectedService == null) {
      _message(
        'Data, servizio o orario non selezionato.',
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
        occasion: selectedOccasione,
        notes: noteController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            icon: const Icon(
              Icons.check_circle,
              color: gold,
              size: 52,
            ),
            title: const Text(
              'Richiesta ricevuta',
              textAlign: TextAlign.center,
            ),
            content: const Text(
              'Grazie per aver scelto Le Capase.\n\n'
              'La tua richiesta di prenotazione è stata ricevuta '
              'ed è in attesa di conferma.',
              textAlign: TextAlign.center,
            ),
            actionsAlignment:
                MainAxisAlignment.center,
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'OK',
                ),
              ),
            ],
          );
        },
      );

      _resetForm();
    } catch (_) {
      if (!mounted) {
        return;
      }

      _message(
        'Non è stato possibile inviare la prenotazione. Riprova.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _resetForm() {
    nomeController.clear();
    cognomeController.clear();
    emailController.clear();
    telefonoController.clear();
    noteController.clear();

    setState(() {
      selectedDate = null;
      selectedTime = null;
      selectedService = null;

      lunchTimes = [];
      dinnerTimes = [];

      persone = 2;

      selectedOccasione = 'Nessuna';

      currentStep = 0;
    });
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: ivory,
        colorScheme: ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.light,
        ),
        inputDecorationTheme:
            InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(
            color: Color(
              0xFF555555,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
            borderSide:
                const BorderSide(
              color: Color(
                0xFFD8D0C2,
              ),
            ),
          ),
          enabledBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
            borderSide:
                const BorderSide(
              color: Color(
                0xFFD8D0C2,
              ),
            ),
          ),
          focusedBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
            borderSide:
                const BorderSide(
              color: gold,
              width: 2,
            ),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: ivory,
        appBar: AppBar(
          backgroundColor: dark,
          foregroundColor:
              Colors.white,
          centerTitle: true,
          title: const Text(
            'LE CAPASE',
            style: TextStyle(
              fontWeight:
                  FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 720,
              ),
              child: Column(
                children: [
                  _buildHeader(),
                  _buildProgress(),

                  Expanded(
                    child:
                        AnimatedSwitcher(
                      duration:
                          const Duration(
                        milliseconds: 250,
                      ),
                      child:
                          SingleChildScrollView(
                        key: ValueKey(
                          currentStep,
                        ),
                        padding:
                            const EdgeInsets
                                .fromLTRB(
                          22,
                          10,
                          22,
                          30,
                        ),
                        child:
                            _buildCurrentStep(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        8,
      ),
      child: Column(
        children: [
          Text(
            'Prenota il tuo tavolo',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color: dark,
              fontSize: 28,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          SizedBox(
            height: 5,
          ),

          Text(
            'Ristorante Pizzeria Le Capase',
            style: TextStyle(
              color: Color(
                0xFF777777,
              ),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // PROGRESS
  // =========================================================

  Widget _buildProgress() {
    final labels = [
      'Data',
      'Orario',
      'Persone',
      'Dati',
      'Riepilogo',
    ];

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16,
      ),
      child: Row(
        children:
            List.generate(
          labels.length,
          (index) {
            final active =
                index <= currentStep;

            return Expanded(
              child: InkWell(
                onTap: () {
                  _goToStep(index);
                },
                child: Column(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment:
                          Alignment.center,
                      decoration:
                          BoxDecoration(
                        shape:
                            BoxShape.circle,
                        color: active
                            ? gold
                            : Colors.white,
                        border:
                            Border.all(
                          color: active
                              ? gold
                              : const Color(
                                  0xFFD5CEC2,
                                ),
                        ),
                      ),
                      child: Text(
                        '${index + 1}',
                        style:
                            TextStyle(
                          color: active
                              ? Colors.black
                              : Colors.grey,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      labels[index],
                      textAlign:
                          TextAlign.center,
                      style:
                          TextStyle(
                        fontSize: 11,
                        color: active
                            ? dark
                            : Colors.grey,
                        fontWeight:
                            active
                                ? FontWeight.w600
                                : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // =========================================================
  // STEP ATTUALE
  // =========================================================

  Widget _buildCurrentStep() {
    switch (currentStep) {
      case 0:
        return _buildDateStep();

      case 1:
        return _buildTimeStep();

      case 2:
        return _buildGuestsStep();

      case 3:
        return _buildDetailsStep();

      case 4:
        return _buildSummaryStep();

      default:
        return _buildDateStep();
    }
  }

  // =========================================================
  // STEP DATA
  // =========================================================

  Widget _buildDateStep() {
    return _section(
      icon:
          Icons.calendar_month_outlined,
      title:
          'Quando vuoi venire?',
      subtitle:
          'Scegli la data della tua prenotazione.',
      child: Column(
        children: [
          _bigSelectionButton(
            text:
                selectedDate == null
                    ? 'Scegli una data'
                    : _formattedDate(
                        selectedDate!,
                      ),
            onTap: _selectDate,
          ),

          if (_loadingAvailability) ...[
            const SizedBox(
              height: 25,
            ),
            const CircularProgressIndicator(),
          ],

          if (!_loadingAvailability &&
              selectedDate != null &&
              lunchTimes.isEmpty &&
              dinnerTimes.isEmpty) ...[
            const SizedBox(
              height: 20,
            ),
            _notice(
              'Non ci sono orari prenotabili online per questa data.',
              Icons.event_busy_outlined,
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================
  // STEP ORARIO
  // =========================================================

  Widget _buildTimeStep() {
    return _section(
      icon:
          Icons.schedule_outlined,
      title:
          'Scegli l’orario',
      subtitle:
          selectedDate == null
              ? ''
              : _formattedDate(
                  selectedDate!,
                ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          if (lunchTimes.isNotEmpty)
            _serviceTimeSection(
              icon:
                  Icons.wb_sunny_outlined,
              title:
                  'PRANZO',
              subtitle:
                  'Seleziona un orario per il pranzo',
              times:
                  lunchTimes,
              service:
                  'lunch',
            ),

          if (lunchTimes.isNotEmpty &&
              dinnerTimes.isNotEmpty)
            const SizedBox(
              height: 28,
            ),

          if (dinnerTimes.isNotEmpty)
            _serviceTimeSection(
              icon:
                  Icons.nightlight_outlined,
              title:
                  'CENA',
              subtitle:
                  'Seleziona un orario per la cena',
              times:
                  dinnerTimes,
              service:
                  'dinner',
            ),

          if (lunchTimes.isEmpty &&
              dinnerTimes.isEmpty)
            _notice(
              'Nessun orario disponibile.',
              Icons.schedule_outlined,
            ),

          const SizedBox(
            height: 30,
          ),

          _primaryButton(
            text:
                'CONTINUA',
            onPressed:
                selectedTime == null
                    ? null
                    : _continueFromTime,
          ),

          _backButton(),
        ],
      ),
    );
  }

  Widget _serviceTimeSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<String> times,
    required String service,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration: BoxDecoration(
        color: ivory,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: const Color(
            0xFFE1D7C7,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration:
                    const BoxDecoration(
                  color:
                      Color(
                    0xFFF2E5C8,
                  ),
                  shape:
                      BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color:
                      const Color(
                    0xFF8A6726,
                  ),
                  size: 21,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        color: dark,
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),

                    Text(
                      subtitle,
                      style:
                          const TextStyle(
                        color:
                            Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 18,
          ),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                times.map(
              (time) {
                final selected =
                    time ==
                            selectedTime &&
                        service ==
                            selectedService;

                return ChoiceChip(
                  label: Padding(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    child: Text(
                      time,
                      style:
                          TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w600,
                        color: selected
                            ? Colors.black
                            : dark,
                      ),
                    ),
                  ),
                  selected:
                      selected,
                  selectedColor:
                      gold,
                  backgroundColor:
                      Colors.white,
                  side:
                      BorderSide(
                    color: selected
                        ? gold
                        : const Color(
                            0xFFD8D0C2,
                          ),
                  ),
                  onSelected: (_) {
                    setState(() {
                      selectedTime =
                          time;

                      selectedService =
                          service;
                    });
                  },
                );
              },
            ).toList(),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // STEP PERSONE
  // =========================================================

  Widget _buildGuestsStep() {
    return _section(
      icon:
          Icons.groups_outlined,
      title:
          'Quante persone?',
      subtitle:
          'Indica il numero di ospiti.',
      child: Column(
        children: [
          const SizedBox(
            height: 10,
          ),

          Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              _roundButton(
                icon:
                    Icons.remove,
                enabled:
                    persone > 1,
                onTap: () {
                  if (persone <= 1) {
                    return;
                  }

                  setState(() {
                    persone--;
                  });
                },
              ),

              SizedBox(
                width: 120,
                child: Column(
                  children: [
                    Text(
                      '$persone',
                      style:
                          const TextStyle(
                        fontSize: 54,
                        height: 1,
                        color: dark,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Text(
                      persone == 1
                          ? 'persona'
                          : 'persone',
                      style:
                          const TextStyle(
                        color:
                            Colors.grey,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),

              _roundButton(
                icon:
                    Icons.add,
                enabled:
                    true,
                onTap: () {
                  setState(() {
                    persone++;
                  });
                },
              ),
            ],
          ),

          const SizedBox(
            height: 35,
          ),

          _primaryButton(
            text:
                'CONTINUA',
            onPressed:
                _continueFromGuests,
          ),

          _backButton(),
        ],
      ),
    );
  }

  // =========================================================
  // STEP DATI
  // =========================================================

  Widget _buildDetailsStep() {
    return _section(
      icon:
          Icons.person_outline,
      title:
          'I tuoi dati',
      subtitle:
          'Inserisci i dati per la richiesta di prenotazione.',
      child: Column(
        children: [
          TextField(
            controller:
                nomeController,
            textCapitalization:
                TextCapitalization.words,
            decoration:
                const InputDecoration(
              labelText:
                  'Nome *',
              prefixIcon:
                  Icon(
                Icons.person_outline,
              ),
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          TextField(
            controller:
                cognomeController,
            textCapitalization:
                TextCapitalization.words,
            decoration:
                const InputDecoration(
              labelText:
                  'Cognome *',
              prefixIcon:
                  Icon(
                Icons.person_outline,
              ),
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          TextField(
            controller:
                emailController,
            keyboardType:
                TextInputType.emailAddress,
            decoration:
                const InputDecoration(
              labelText:
                  'Email *',
              prefixIcon:
                  Icon(
                Icons.email_outlined,
              ),
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          TextField(
            controller:
                telefonoController,
            keyboardType:
                TextInputType.phone,
            decoration:
                const InputDecoration(
              labelText:
                  'Telefono *',
              prefixIcon:
                  Icon(
                Icons.phone_outlined,
              ),
            ),
          ),

          const SizedBox(
            height: 22,
          ),

          DropdownButtonFormField<
              String>(
            initialValue:
                selectedOccasione,
            decoration:
                const InputDecoration(
              labelText:
                  'Occasione speciale',
              prefixIcon:
                  Icon(
                Icons
                    .celebration_outlined,
              ),
            ),
            items:
                occasioni.map(
              (item) {
                return DropdownMenuItem<
                    String>(
                  value:
                      item,
                  child:
                      Text(
                    item,
                  ),
                );
              },
            ).toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }

              setState(() {
                selectedOccasione =
                    value;
              });
            },
          ),

          const SizedBox(
            height: 14,
          ),

          TextField(
            controller:
                noteController,
            maxLines: 3,
            decoration:
                const InputDecoration(
              labelText:
                  'Richieste particolari / Note',
              alignLabelWithHint:
                  true,
              prefixIcon:
                  Icon(
                Icons.notes_outlined,
              ),
            ),
          ),

          const SizedBox(
            height: 28,
          ),

          _primaryButton(
            text:
                'CONTINUA',
            onPressed:
                _continueFromDetails,
          ),

          _backButton(),
        ],
      ),
    );
  }

  // =========================================================
  // STEP RIEPILOGO
  // =========================================================

  Widget _buildSummaryStep() {
    final serviceText =
        selectedService == 'lunch'
            ? 'Pranzo'
            : 'Cena';

    return _section(
      icon:
          Icons.check_circle_outline,
      title:
          'Riepilogo',
      subtitle:
          'Controlla i dati prima di inviare la richiesta.',
      child: Column(
        children: [
          _summaryRow(
            Icons.calendar_today_outlined,
            'Data',
            selectedDate == null
                ? '-'
                : _formattedDate(
                    selectedDate!,
                  ),
          ),

          _summaryRow(
            selectedService ==
                    'lunch'
                ? Icons.wb_sunny_outlined
                : Icons.nightlight_outlined,
            'Servizio',
            serviceText,
          ),

          _summaryRow(
            Icons.schedule_outlined,
            'Orario',
            selectedTime ?? '-',
          ),

          _summaryRow(
            Icons.groups_outlined,
            'Persone',
            '$persone',
          ),

          _summaryRow(
            Icons.person_outline,
            'Nome',
            '${nomeController.text.trim()} '
                '${cognomeController.text.trim()}',
          ),

          _summaryRow(
            Icons.email_outlined,
            'Email',
            emailController.text.trim(),
          ),

          _summaryRow(
            Icons.phone_outlined,
            'Telefono',
            telefonoController.text.trim(),
          ),

          if (selectedOccasione !=
              'Nessuna')
            _summaryRow(
              Icons.celebration_outlined,
              'Occasione',
              selectedOccasione,
            ),

          if (noteController.text
              .trim()
              .isNotEmpty)
            _summaryRow(
              Icons.notes_outlined,
              'Note',
              noteController.text.trim(),
            ),

          const SizedBox(
            height: 28,
          ),

          _primaryButton(
            text:
                _saving
                    ? 'INVIO IN CORSO...'
                    : 'INVIA RICHIESTA',
            icon:
                Icons.check,
            onPressed:
                _saving
                    ? null
                    : _salvaPrenotazione,
          ),

          _backButton(),
        ],
      ),
    );
  }

  // =========================================================
  // COMPONENTI
  // =========================================================

  Widget _section({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        24,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          24,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFE3DDD2,
          ),
        ),
        boxShadow:
            const [
          BoxShadow(
            color:
                Color(
              0x12000000,
            ),
            blurRadius:
                20,
            offset:
                Offset(
              0,
              7,
            ),
          ),
        ],
      ),
      child:
          Column(
        children: [
          Container(
            width:
                54,
            height:
                54,
            decoration:
                const BoxDecoration(
              color:
                  Color(
                0xFFF2E5C8,
              ),
              shape:
                  BoxShape.circle,
            ),
            child:
                Icon(
              icon,
              color:
                  const Color(
                0xFF8A6726,
              ),
              size:
                  28,
            ),
          ),

          const SizedBox(
            height:
                14,
          ),

          Text(
            title,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color:
                  dark,
              fontSize:
                  24,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          if (subtitle.isNotEmpty) ...[
            const SizedBox(
              height:
                  6,
            ),
            Text(
              subtitle,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    Colors.grey,
                fontSize:
                    14,
              ),
            ),
          ],

          const SizedBox(
            height:
                26,
          ),

          child,
        ],
      ),
    );
  }

  Widget _bigSelectionButton({
    required String text,
    required VoidCallback onTap,
  }) {
    return Material(
      color:
          ivory,
      borderRadius:
          BorderRadius.circular(
        16,
      ),
      child:
          InkWell(
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        onTap:
            onTap,
        child:
            Container(
          width:
              double.infinity,
          padding:
              const EdgeInsets.all(
            20,
          ),
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              16,
            ),
            border:
                Border.all(
              color:
                  const Color(
                0xFFD8D0C2,
              ),
            ),
          ),
          child:
              Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                color:
                    gold,
                size:
                    28,
              ),

              const SizedBox(
                width:
                    14,
              ),

              Expanded(
                child:
                    Text(
                  text,
                  style:
                      const TextStyle(
                    color:
                        dark,
                    fontSize:
                        17,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),

              const Icon(
                Icons.chevron_right,
                color:
                    gold,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
  }) {
    return SizedBox(
      width:
          double.infinity,
      height:
          56,
      child:
          FilledButton.icon(
        style:
            FilledButton.styleFrom(
          backgroundColor:
              dark,
          foregroundColor:
              gold,
          disabledBackgroundColor:
              Colors.grey.shade300,
          disabledForegroundColor:
              Colors.grey.shade500,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              15,
            ),
          ),
        ),
        onPressed:
            onPressed,
        icon:
            Icon(
          icon ??
              Icons.arrow_forward,
        ),
        label:
            Text(
          text,
          style:
              const TextStyle(
            fontSize:
                16,
            fontWeight:
                FontWeight.bold,
            letterSpacing:
                .5,
          ),
        ),
      ),
    );
  }

  Widget _backButton() {
    if (currentStep == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding:
          const EdgeInsets.only(
        top:
            8,
      ),
      child:
          TextButton.icon(
        onPressed:
            () {
          setState(
            () {
              currentStep--;
            },
          );
        },
        icon:
            const Icon(
          Icons.arrow_back,
        ),
        label:
            const Text(
          'Indietro',
        ),
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return IconButton.filled(
      style:
          IconButton.styleFrom(
        backgroundColor:
            enabled
                ? gold
                : Colors.grey.shade300,
        foregroundColor:
            enabled
                ? Colors.black
                : Colors.grey,
        minimumSize:
            const Size(
          54,
          54,
        ),
      ),
      onPressed:
          enabled
              ? onTap
              : null,
      icon:
          Icon(
        icon,
      ),
    );
  }

  Widget _notice(
    String text,
    IconData icon,
  ) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration:
          BoxDecoration(
        color:
            ivory,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
      ),
      child:
          Row(
        children: [
          Icon(
            icon,
            color:
                gold,
          ),

          const SizedBox(
            width:
                12,
          ),

          Expanded(
            child:
                Text(
              text,
              style:
                  const TextStyle(
                color:
                    dark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom:
            10,
      ),
      padding:
          const EdgeInsets.all(
        15,
      ),
      decoration:
          BoxDecoration(
        color:
            ivory,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
      ),
      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color:
                gold,
          ),

          const SizedBox(
            width:
                12,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:
                      const TextStyle(
                    color:
                        Colors.grey,
                    fontSize:
                        12,
                  ),
                ),

                const SizedBox(
                  height:
                      2,
                ),

                Text(
                  value,
                  style:
                      const TextStyle(
                    color:
                        dark,
                    fontSize:
                        16,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // FORMATO DATA
  // =========================================================

  String _formattedDate(
    DateTime date,
  ) {
    const months = [
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

    const days = [
      'lunedì',
      'martedì',
      'mercoledì',
      'giovedì',
      'venerdì',
      'sabato',
      'domenica',
    ];

    return '${days[date.weekday - 1]} '
        '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
  }
}