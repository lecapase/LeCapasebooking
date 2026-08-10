import 'dart:async';

import 'package:flutter/material.dart';

import 'data/availability_repository.dart';
import 'data/firestore_availability_repository.dart';
import 'models/service_availability.dart';

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  State<AvailabilityScreen> createState() =>
      _AvailabilityScreenState();
}

class _AvailabilityScreenState
    extends State<AvailabilityScreen> {
  int selectedDayIndex = 0;

  bool _isLoading = true;
  bool _showSaved = false;

  Timer? _saveTimer;
  Timer? _savedOverlayTimer;

  @override
  void initState() {
    super.initState();
    _loadFromFirebase();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _savedOverlayTimer?.cancel();
    super.dispose();
  }

  // =========================================================
  // CARICAMENTO FIREBASE
  // =========================================================

  Future<void> _loadFromFirebase() async {
    try {
      final weeklyDays =
          await FirestoreAvailabilityRepository.loadWeeklyDays();

      final exceptions =
          await FirestoreAvailabilityRepository.loadAllExceptions();

      if (weeklyDays.isNotEmpty) {
        AvailabilityRepository.replaceWeeklyDays(
          weeklyDays,
        );
      }

      AvailabilityRepository.replaceExceptions(
        exceptions,
      );
    } catch (error) {
      if (!mounted) return;

      _showSaveError();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // =========================================================
  // AUTOSALVATAGGIO SETTIMANALE
  // =========================================================

  void _scheduleWeeklySave(
    DayAvailability day,
  ) {
    _saveTimer?.cancel();

    _saveTimer = Timer(
      const Duration(milliseconds: 650),
      () async {
        try {
          await FirestoreAvailabilityRepository.saveWeeklyDay(
            day,
          );

          if (!mounted) return;

          _showSavedMessage();
        } catch (error) {
          if (!mounted) return;

          _showSaveError();
        }
      },
    );
  }

  // =========================================================
  // MESSAGGIO CENTRALE "SALVATO"
  // =========================================================

  void _showSavedMessage() {
    _savedOverlayTimer?.cancel();

    setState(() {
      _showSaved = true;
    });

    _savedOverlayTimer = Timer(
      const Duration(milliseconds: 1100),
      () {
        if (!mounted) return;

        setState(() {
          _showSaved = false;
        });
      },
    );
  }

  void _showSaveError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Salvataggio non riuscito. Riprova.',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final day =
        AvailabilityRepository.days[selectedDayIndex];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Indietro',
          onPressed: () {
            Navigator.of(context).maybePop();
          },
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
          ),
        ),
        title: const Text(
          'Disponibilità Online',
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadFromFirebase,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Regole settimanali',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  'Gestisci pranzo, cena, coperti e fasce prenotabili.',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 20),

                OutlinedButton.icon(
                  onPressed: _openDateException,
                  icon: const Icon(
                    Icons.event_available,
                  ),
                  label: const Text(
                    'Gestisci eccezione per una data',
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount:
                        AvailabilityRepository.days.length,
                    separatorBuilder: (_, _) {
                      return const SizedBox(
                        width: 8,
                      );
                    },
                    itemBuilder: (
                      context,
                      index,
                    ) {
                      final item =
                          AvailabilityRepository.days[index];

                      final selected =
                          index == selectedDayIndex;

                      return ChoiceChip(
                        label: Text(
                          item.name,
                        ),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            selectedDayIndex = index;
                          });
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  day.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                _buildServiceCard(
                  day,
                  day.lunch,
                ),

                const SizedBox(height: 16),

                _buildServiceCard(
                  day,
                  day.dinner,
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),

          if (_showSaved)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(
                        alpha: 0.82,
                      ),
                      borderRadius: BorderRadius.circular(
                        18,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.greenAccent,
                          size: 30,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Salvato',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================
  // CARD PRANZO / CENA
  // =========================================================

  Widget _buildServiceCard(
    DayAvailability day,
    ServiceAvailability service,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    service.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: service.isOpen,
                  onChanged: (value) {
                    setState(() {
                      service.isOpen = value;
                    });

                    _scheduleWeeklySave(day);
                  },
                ),
              ],
            ),

            Text(
              service.isOpen
                  ? 'Prenotazioni online aperte'
                  : 'Prenotazioni online chiuse',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: service.isOpen
                    ? Colors.green
                    : Colors.red,
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: _editableInfoBox(
                    label: 'Inizio',
                    value: service.startTime,
                    icon: Icons.schedule,
                    onTap: () {
                      _changeTime(
                        day: day,
                        service: service,
                        isStart: true,
                      );
                    },
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _editableInfoBox(
                    label: 'Fine',
                    value: service.endTime,
                    icon: Icons.schedule,
                    onTap: () {
                      _changeTime(
                        day: day,
                        service: service,
                        isStart: false,
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _editableInfoBox(
              label: 'Coperti massimi online',
              value: '${service.maxOnlineGuests}',
              icon: Icons.groups,
              onTap: () {
                _changeMaxGuests(
                  day,
                  service,
                );
              },
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Fasce bloccate',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    _addBlockedRange(
                      day,
                      service,
                    );
                  },
                  icon: const Icon(
                    Icons.add,
                  ),
                  label: const Text(
                    'Aggiungi',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (service.blockedRanges.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    14,
                  ),
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                ),
                child: const Text(
                  'Nessuna fascia bloccata',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ),

            ...service.blockedRanges.map(
              (range) {
                return Container(
                  margin: const EdgeInsets.only(
                    top: 8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      14,
                    ),
                    color: Colors.red.withValues(
                      alpha: 0.10,
                    ),
                    border: Border.all(
                      color: Colors.red.withValues(
                        alpha: 0.30,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.block,
                        color: Colors.red,
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          '${range.startTime} - ${range.endTime}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      IconButton(
                        onPressed: () {
                          setState(() {
                            service.blockedRanges.remove(
                              range,
                            );
                          });

                          _scheduleWeeklySave(day);
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // BOX MODIFICABILE
  // =========================================================

  Widget _editableInfoBox({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest,
        ),
        child: Row(
          children: [
            Icon(icon),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.edit_outlined,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // MODIFICA ORARIO
  // =========================================================

  Future<void> _changeTime({
    required DayAvailability day,
    required ServiceAvailability service,
    required bool isStart,
  }) async {
    final currentValue = isStart
        ? service.startTime
        : service.endTime;

    final initialTime = _parseTime(
      currentValue,
    );

    final result = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (result == null) return;

    setState(() {
      if (isStart) {
        service.startTime = _formatTime(result);
      } else {
        service.endTime = _formatTime(result);
      }
    });

    _scheduleWeeklySave(day);
  }

  // =========================================================
  // MODIFICA COPERTI
  // =========================================================

  Future<void> _changeMaxGuests(
    DayAvailability day,
    ServiceAvailability service,
  ) async {
    final controller = TextEditingController(
      text: '${service.maxOnlineGuests}',
    );

    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Coperti massimi online',
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Numero coperti',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Annulla',
              ),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(
                  controller.text.trim(),
                );

                Navigator.pop(
                  context,
                  value,
                );
              },
              child: const Text(
                'Salva',
              ),
            ),
          ],
        );
      },
    );

    if (result == null || result < 1) {
      return;
    }

    setState(() {
      service.maxOnlineGuests = result;
    });

    _scheduleWeeklySave(day);
  }

  // =========================================================
  // AGGIUNGI FASCIA BLOCCATA
  // =========================================================

  Future<void> _addBlockedRange(
    DayAvailability day,
    ServiceAvailability service,
  ) async {
    final startTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(
        hour: 20,
        minute: 15,
      ),
    );

    if (startTime == null) return;
    if (!mounted) return;

    final endTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(
        hour: 22,
        minute: 15,
      ),
    );

    if (endTime == null) return;

    final startMinutes =
        startTime.hour * 60 + startTime.minute;

    final endMinutes =
        endTime.hour * 60 + endTime.minute;

    if (endMinutes <= startMinutes) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'L’orario finale deve essere successivo a quello iniziale.',
          ),
        ),
      );

      return;
    }

    setState(() {
      service.blockedRanges.add(
        BlockedTimeRange(
          startTime: _formatTime(startTime),
          endTime: _formatTime(endTime),
        ),
      );
    });

    _scheduleWeeklySave(day);
  }

  // =========================================================
  // ECCEZIONI PER DATA
  // =========================================================

  Future<void> _openDateException() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(
        DateTime.now().year + 2,
      ),
    );

    if (selectedDate == null) return;
    if (!mounted) return;

    var exception =
        AvailabilityRepository.getException(
      selectedDate,
    );

    if (exception == null) {
      final firebaseException =
          await FirestoreAvailabilityRepository
              .loadException(
        selectedDate,
      );

      if (firebaseException != null) {
        AvailabilityRepository.exceptions.add(
          firebaseException,
        );

        exception = firebaseException;
      }
    }

    exception ??=
        AvailabilityRepository.createException(
      selectedDate,
    );

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DateExceptionScreen(
          exception: exception!,
        ),
      ),
    );

    if (!mounted) return;

    setState(() {});
  }

  // =========================================================
  // UTILITÀ
  // =========================================================

  TimeOfDay _parseTime(
    String value,
  ) {
    final parts = value.split(':');

    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  String _formatTime(
    TimeOfDay time,
  ) {
    final hour = time.hour
        .toString()
        .padLeft(2, '0');

    final minute = time.minute
        .toString()
        .padLeft(2, '0');

    return '$hour:$minute';
  }
}

// ===========================================================
// ECCEZIONE PER DATA
// ===========================================================

class DateExceptionScreen extends StatefulWidget {
  final DateAvailabilityException exception;

  const DateExceptionScreen({
    super.key,
    required this.exception,
  });

  @override
  State<DateExceptionScreen> createState() =>
      _DateExceptionScreenState();
}

class _DateExceptionScreenState
    extends State<DateExceptionScreen> {
  Timer? _saveTimer;
  Timer? _savedOverlayTimer;

  bool _showSaved = false;

  @override
  void dispose() {
    _saveTimer?.cancel();
    _savedOverlayTimer?.cancel();
    super.dispose();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();

    _saveTimer = Timer(
      const Duration(milliseconds: 650),
      () async {
        try {
          await FirestoreAvailabilityRepository.saveException(
            widget.exception,
          );

          if (!mounted) return;

          _showSavedMessage();
        } catch (error) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Salvataggio non riuscito. Riprova.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  void _showSavedMessage() {
    _savedOverlayTimer?.cancel();

    setState(() {
      _showSaved = true;
    });

    _savedOverlayTimer = Timer(
      const Duration(milliseconds: 1100),
      () {
        if (!mounted) return;

        setState(() {
          _showSaved = false;
        });
      },
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final exception = widget.exception;

    final dateText =
        '${exception.date.day.toString().padLeft(2, '0')}/'
        '${exception.date.month.toString().padLeft(2, '0')}/'
        '${exception.date.year}';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Indietro',
          onPressed: () {
            Navigator.of(context).maybePop();
          },
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
          ),
        ),
        title: const Text(
          'Eccezione data',
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                dateText,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Queste impostazioni sostituiscono le regole settimanali solo per questa data.',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 24),

              _serviceCard(
                exception.lunch,
              ),

              const SizedBox(height: 16),

              _serviceCard(
                exception.dinner,
              ),

              const SizedBox(height: 24),

              OutlinedButton.icon(
                onPressed: _deleteException,
                icon: const Icon(
                  Icons.restart_alt,
                ),
                label: const Text(
                  'Ripristina regole settimanali',
                ),
              ),
            ],
          ),

          if (_showSaved)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(
                        alpha: 0.82,
                      ),
                      borderRadius: BorderRadius.circular(
                        18,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.greenAccent,
                          size: 30,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Salvato',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _serviceCard(
    ServiceAvailability service,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    service.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: service.isOpen,
                  onChanged: (value) {
                    setState(() {
                      service.isOpen = value;
                    });

                    _scheduleSave();
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Orario inizio',
              ),
              trailing: Text(
                service.startTime,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                _changeTime(
                  service,
                  true,
                );
              },
            ),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Orario fine',
              ),
              trailing: Text(
                service.endTime,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                _changeTime(
                  service,
                  false,
                );
              },
            ),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Coperti massimi online',
              ),
              trailing: Text(
                '${service.maxOnlineGuests}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                _changeGuests(
                  service,
                );
              },
            ),

            const Divider(),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Fasce bloccate',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    _addBlockedRange(
                      service,
                    );
                  },
                  icon: const Icon(
                    Icons.add,
                  ),
                  label: const Text(
                    'Aggiungi',
                  ),
                ),
              ],
            ),

            if (service.blockedRanges.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 12,
                  ),
                  child: Text(
                    'Nessuna fascia bloccata',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),

            ...service.blockedRanges.map(
              (range) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.block,
                  color: Colors.red,
                ),
                title: Text(
                  '${range.startTime} - ${range.endTime}',
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                  ),
                  onPressed: () {
                    setState(() {
                      service.blockedRanges.remove(
                        range,
                      );
                    });

                    _scheduleSave();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeTime(
    ServiceAvailability service,
    bool start,
  ) async {
    final value = start
        ? service.startTime
        : service.endTime;

    final parts = value.split(':');

    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );

    if (result == null) return;

    setState(() {
      final formatted = _formatTime(
        result,
      );

      if (start) {
        service.startTime = formatted;
      } else {
        service.endTime = formatted;
      }
    });

    _scheduleSave();
  }

  Future<void> _changeGuests(
    ServiceAvailability service,
  ) async {
    final controller = TextEditingController(
      text: '${service.maxOnlineGuests}',
    );

    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Coperti massimi',
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Coperti',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Annulla',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  int.tryParse(
                    controller.text,
                  ),
                );
              },
              child: const Text(
                'Salva',
              ),
            ),
          ],
        );
      },
    );

    if (result == null || result < 1) {
      return;
    }

    setState(() {
      service.maxOnlineGuests = result;
    });

    _scheduleSave();
  }

  Future<void> _addBlockedRange(
    ServiceAvailability service,
  ) async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(
        hour: 20,
        minute: 15,
      ),
    );

    if (start == null || !mounted) return;

    final end = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(
        hour: 22,
        minute: 15,
      ),
    );

    if (end == null) return;

    final startMinutes =
        start.hour * 60 + start.minute;

    final endMinutes =
        end.hour * 60 + end.minute;

    if (endMinutes <= startMinutes) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'L’orario finale deve essere successivo a quello iniziale.',
          ),
        ),
      );

      return;
    }

    setState(() {
      service.blockedRanges.add(
        BlockedTimeRange(
          startTime: _formatTime(start),
          endTime: _formatTime(end),
        ),
      );
    });

    _scheduleSave();
  }

  Future<void> _deleteException() async {
    _saveTimer?.cancel();

    try {
      await FirestoreAvailabilityRepository.deleteException(
        widget.exception.date,
      );

      AvailabilityRepository.removeException(
        widget.exception.date,
      );

      if (!mounted) return;

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ripristino non riuscito. Riprova.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTime(
    TimeOfDay time,
  ) {
    final hour = time.hour
        .toString()
        .padLeft(2, '0');

    final minute = time.minute
        .toString()
        .padLeft(2, '0');

    return '$hour:$minute';
  }
}