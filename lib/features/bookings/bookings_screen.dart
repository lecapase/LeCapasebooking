import '../availability/data/booking_slot_closures_repository.dart';
import '../customer_booking/data/customer_availability_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../services/push_notification_service.dart';

import '../availability/availability_screen.dart';
import '../contacts/contacts_marketing_screen.dart';
import '../settings/settings_screen.dart';
import '../staff/staff_users_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({
    super.key,
    this.onLock,
    this.onLogout,
    required this.displayName,
    required this.email,
    required this.userRole,
  });

  final Future<void> Function()? onLock;
  final Future<void> Function()? onLogout;

  final String displayName;
  final String email;
  final String userRole;

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool get _isAdmin => widget.userRole == 'admin';

  bool get _isManager => _isAdmin || widget.userRole == 'manager';

  bool get _isSupervisor => _isManager || widget.userRole == 'supervisor';

  String get _roleLabel {
    switch (widget.userRole) {
      case 'admin':
        return 'Amministratore';
      case 'manager':
        return 'Manager';
      case 'supervisor':
        return 'Supervisor';
      case 'staff':
        return 'Staff';
      default:
        return widget.userRole;
    }
  }

  DateTime _selectedDate = DateTime.now();

  int _selectedSection = 0;
  String _selectedService = 'all';
  String _selectedFilter = 'all';
  int _bottomIndex = 0;

  bool _savingManualBooking = false;

  final TextEditingController _manualFirstNameController =
      TextEditingController();
  final TextEditingController _manualLastNameController =
      TextEditingController();
  final TextEditingController _manualPhoneController = TextEditingController();
  final TextEditingController _manualEmailController = TextEditingController();
  final TextEditingController _manualNotesController = TextEditingController();

  int _manualGuests = 2;
  String _manualService = 'dinner';

  TimeOfDay _manualTime = const TimeOfDay(hour: 20, minute: 0);

  static const List<String> _selectableStatuses = [
    'booked',
    'confirmed',
    'arrived',
    'released',
    'cancelled',
    'no_show',
  ];

  static const Set<String> _pastStatuses = {
    'cancelled',
    'no_show',
    'released',
    'completed',
    'rejected',
  };

  static const List<String> _monthNames = [
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

  static const List<String> _weekdayNames = [
    'lun',
    'mar',
    'mer',
    'gio',
    'ven',
    'sab',
    'dom',
  ];

  @override
  void dispose() {
    _manualFirstNameController.dispose();
    _manualLastNameController.dispose();
    _manualPhoneController.dispose();
    _manualEmailController.dispose();
    _manualNotesController.dispose();
    super.dispose();
  }

  int _readInteger(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse('$value') ?? 0;
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  bool _isDatePast(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final normalizedDate = DateTime(date.year, date.month, date.day);

    return normalizedDate.isBefore(today);
  }

  bool _isBookingPast(Map<String, dynamic> booking) {
    final dateKey = booking['dateKey'] as String? ?? '';
    final parts = dateKey.split('-');

    if (parts.length != 3) {
      return false;
    }

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);

    if (year == null || month == null || day == null) {
      return false;
    }

    return _isDatePast(DateTime(year, month, day));
  }

  void _showArchivedDayMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Le giornate passate sono in sola consultazione.'),
      ),
    );
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);

    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  void _changeWeek(int numberOfWeeks) {
    setState(() {
      final currentWeekStart = _startOfWeek(_selectedDate);

      _selectedDate = currentWeekStart.add(Duration(days: numberOfWeeks * 7));
      _selectedSection = 0;
      _selectedFilter = 'all';
    });
  }

  String _weekLabel(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));

    if (weekStart.month == weekEnd.month) {
      return '${weekStart.day}–${weekEnd.day} '
          '${_monthNames[weekStart.month - 1]} '
          '${weekStart.year}';
    }

    return '${weekStart.day} '
        '${_monthNames[weekStart.month - 1]} – '
        '${weekEnd.day} '
        '${_monthNames[weekEnd.month - 1]} '
        '${weekEnd.year}';
  }

  String _fullDateLabel(DateTime date) {
    return '${_weekdayNames[date.weekday - 1]} '
        '${date.day} '
        '${_monthNames[date.month - 1]} '
        '${date.year}';
  }

  String _italianDateFromKey(String dateKey) {
    final parts = dateKey.split('-');

    if (parts.length != 3) {
      return dateKey;
    }

    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  bool _countsAsConfirmedCover(String status) {
    return status == 'booked' || status == 'confirmed' || status == 'arrived';
  }

  bool _isPastStatus(String status) {
    return _pastStatuses.contains(status);
  }

  bool _countsForCapacity(String status) {
    return status != 'cancelled' &&
        status != 'rejected' &&
        status != 'no_show' &&
        status != 'released' &&
        status != 'completed';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'booked':
        return 'Prenotata';

      case 'confirmed':
        return 'Confermata';

      case 'pending':
        return 'In attesa';

      case 'cancelled':
        return 'Annullata';

      case 'rejected':
        return 'Rifiutata';

      case 'arrived':
        return 'Arrivata';

      case 'no_show':
        return 'No-show';

      case 'released':
        return 'Liberato';

      case 'completed':
        return 'Completata';

      default:
        return 'Stato sconosciuto';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'booked':
        return const Color(0xFFC8A45D);

      case 'confirmed':
        return Colors.green;

      case 'pending':
        return Colors.orange;

      case 'cancelled':
        return Colors.red;

      case 'rejected':
        return Colors.redAccent;

      case 'arrived':
        return Colors.blue;

      case 'no_show':
        return Colors.deepPurple;

      case 'released':
        return Colors.teal;

      case 'completed':
        return Colors.blueGrey;

      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'booked':
        return Icons.event_available_outlined;

      case 'confirmed':
        return Icons.check_circle_outline;

      case 'pending':
        return Icons.schedule_outlined;

      case 'cancelled':
        return Icons.cancel_outlined;

      case 'rejected':
        return Icons.block;

      case 'arrived':
        return Icons.login;

      case 'no_show':
        return Icons.person_off_outlined;

      case 'released':
        return Icons.table_restaurant_outlined;

      case 'completed':
        return Icons.task_alt;

      default:
        return Icons.flag_outlined;
    }
  }

  String _serviceLabel(String service) {
    switch (service) {
      case 'lunch':
        return 'Pranzo';

      case 'dinner':
        return 'Cena';

      default:
        return service;
    }
  }

  Future<void> _openCalendar() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
      locale: const Locale('it', 'IT'),
      helpText: 'Seleziona una data',
      cancelText: 'ANNULLA',
      confirmText: 'SELEZIONA',
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDate = selectedDate;
      _selectedSection = 0;
      _selectedFilter = 'all';
      _bottomIndex = 0;
    });
  }

  Future<void> _selectManualDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _isDatePast(_selectedDate) ? today : _selectedDate,
      firstDate: today,
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
      locale: const Locale('it', 'IT'),
      helpText: 'Data della prenotazione',
      cancelText: 'ANNULLA',
      confirmText: 'SELEZIONA',
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDate = selectedDate;
    });
  }

  Future<void> _selectManualTime() async {
    var pendingTime = _manualTime;

    final selectedTime = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: const Color(0xFF201D18),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: 330,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('ANNULLA'),
                      ),
                      const Expanded(
                        child: Text(
                          'Seleziona l’orario',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop(pendingTime);
                        },
                        child: const Text('FATTO'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: CupertinoTheme(
                    data: const CupertinoThemeData(
                      brightness: Brightness.dark,
                      primaryColor: Color(0xFFC8A45D),
                      textTheme: CupertinoTextThemeData(
                        dateTimePickerTextStyle: TextStyle(
                          color: Color(0xFFE9E1D2),
                          fontSize: 22,
                        ),
                      ),
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      use24hFormat: true,
                      minuteInterval: 15,
                      initialDateTime: DateTime(
                        2026,
                        1,
                        1,
                        _manualTime.hour,
                        _manualTime.minute,
                      ),
                      onDateTimeChanged: (value) {
                        pendingTime = TimeOfDay(
                          hour: value.hour,
                          minute: value.minute,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedTime == null || !mounted) {
      return;
    }

    setState(() {
      _manualTime = selectedTime;
      _manualService = selectedTime.hour < 17 ? 'lunch' : 'dinner';
    });
  }

  TimeOfDay _currentQuarterHour() {
    final now = DateTime.now();
    final roundedMinutes = ((now.minute + 14) ~/ 15) * 15;
    final hour = (now.hour + (roundedMinutes ~/ 60)) % 24;

    return TimeOfDay(hour: hour, minute: roundedMinutes % 60);
  }

  String _manualTimeValue() {
    final hour = _manualTime.hour.toString().padLeft(2, '0');
    final minute = _manualTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  Future<void> _saveManualBooking() async {
    if (!_isManager) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Solo Manager e Amministratore possono aggiungere prenotazioni.',
          ),
        ),
      );
      return;
    }
    if (_isDatePast(_selectedDate)) {
      _showArchivedDayMessage();
      return;
    }

    final firstName = _manualFirstNameController.text.trim();

    if (firstName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci il nome del cliente.')),
      );
      return;
    }

    setState(() {
      _savingManualBooking = true;
    });

    final normalizedDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    final dateKey = _dateKey(normalizedDate);

    final bookingReference = _firestore.collection('bookings').doc();

    final counterReference = _firestore
        .collection('availability_counters')
        .doc('${dateKey}_$_manualService');

    try {
      await _firestore.runTransaction((transaction) async {
        final counterSnapshot = await transaction.get(counterReference);

        final currentGuests = counterSnapshot.exists
            ? _readInteger(counterSnapshot.data()?['bookedGuests'])
            : 0;

        transaction.set(bookingReference, {
          'nome': firstName,
          'cognome': _manualLastNameController.text.trim(),
          'email': _manualEmailController.text.trim(),
          'telefono': _manualPhoneController.text.trim(),
          'date': Timestamp.fromDate(normalizedDate),
          'dateKey': dateKey,
          'weekday': normalizedDate.weekday,
          'time': _manualTimeValue(),
          'service': _manualService,
          'guests': _manualGuests,
          'occasion': 'Nessuna',
          'notes': _manualNotesController.text.trim(),
          'status': 'booked',
          'autoBooked': false,
          'autoConfirmed': false,
          'requiresManualConfirmation': false,
          'source': 'admin',
          'manualBooking': true,
          'bookedAt': FieldValue.serverTimestamp(),
          'bookedBy': 'admin',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.set(counterReference, {
          'dateKey': dateKey,
          'weekday': normalizedDate.weekday,
          'service': _manualService,
          'bookedGuests': currentGuests + _manualGuests,
          'lastBookingId': bookingReference.id,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      _manualFirstNameController.clear();
      _manualLastNameController.clear();
      _manualPhoneController.clear();
      _manualEmailController.clear();
      _manualNotesController.clear();

      if (!mounted) {
        return;
      }

      setState(() {
        _savingManualBooking = false;
        _bottomIndex = 0;
        _selectedSection = 0;
        _selectedService = _manualService;
        _selectedFilter = 'all';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Prenotazione aggiunta.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _savingManualBooking = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Salvataggio non riuscito: $error')),
      );
    }
  }

  Future<bool> _confirmStatusChange({
    required String oldStatus,
    required String newStatus,
    required String customerName,
  }) async {
    String title;
    String message;
    String buttonLabel;

    switch (newStatus) {
      case 'booked':
        title = 'Segna come prenotata';
        message =
            'Vuoi impostare la prenotazione di '
            '$customerName come Prenotata?';

        if (!_countsForCapacity(oldStatus)) {
          message +=
              '\n\nI coperti verranno reinseriti '
              'nella disponibilità.';
        }

        buttonLabel = 'Prenotata';
        break;

      case 'confirmed':
        title = 'Conferma prenotazione';
        message =
            'Vuoi confermare la prenotazione di '
            '$customerName?';

        if (oldStatus == 'pending') {
          message +=
              '\n\nIl cliente riceverà automaticamente '
              'l’email di conferma.';
        }

        if (!_countsForCapacity(oldStatus)) {
          message +=
              '\n\nI coperti verranno reinseriti '
              'nella disponibilità.';
        }

        buttonLabel = 'Conferma';
        break;

      case 'cancelled':
        title = 'Annulla prenotazione';
        message =
            'Vuoi annullare la prenotazione di '
            '$customerName?';

        if (_countsForCapacity(oldStatus)) {
          message +=
              '\n\nI coperti verranno liberati '
              'dalla disponibilità.';
        }

        message +=
            '\n\nSe presente, il cliente riceverà '
            'l’email di annullamento.';

        buttonLabel = 'Annulla';
        break;

      case 'rejected':
        title = 'Rifiuta prenotazione';
        message =
            'Vuoi rifiutare la richiesta di '
            '$customerName?';

        if (_countsForCapacity(oldStatus)) {
          message +=
              '\n\nI coperti verranno liberati '
              'dalla disponibilità.';
        }

        message +=
            '\n\nSe presente, il cliente riceverà '
            'l’email di rifiuto.';

        buttonLabel = 'Rifiuta';
        break;

      case 'arrived':
        title = 'Cliente arrivato';
        message =
            'Vuoi segnare la prenotazione di '
            '$customerName come Arrivata?';

        if (!_countsForCapacity(oldStatus)) {
          message +=
              '\n\nI coperti verranno reinseriti '
              'nella disponibilità.';
        }

        buttonLabel = 'Arrivata';
        break;

      case 'no_show':
        title = 'Segna come no-show';
        message =
            'Vuoi segnalare che $customerName '
            'non si è presentato?';

        if (_countsForCapacity(oldStatus)) {
          message +=
              '\n\nI coperti verranno liberati '
              'dalla disponibilità.';
        }

        message +=
            '\n\nIl cliente sarà contrassegnato '
            'nello storico come possibile cliente a rischio.';

        buttonLabel = 'No-show';
        break;

      case 'released':
        title = 'Segna come liberato';
        message =
            'Vuoi segnare il tavolo di '
            '$customerName come Liberato?';

        if (_countsForCapacity(oldStatus)) {
          message +=
              '\n\nI coperti verranno liberati '
              'dalla disponibilità.';
        }

        buttonLabel = 'Liberato';
        break;

      default:
        return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('INDIETRO'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(buttonLabel.toUpperCase()),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  Future<void> _changeStatus(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
    String newStatus,
  ) async {
    final booking = document.data();

    if (_isBookingPast(booking)) {
      _showArchivedDayMessage();
      return;
    }
    final oldStatus = booking['status'] as String? ?? 'pending';

    if (!_isSupervisor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Il tuo ruolo consente solo la consultazione delle prenotazioni.',
          ),
        ),
      );
      return;
    }

    if (widget.userRole == 'supervisor') {
      const allowed = {'confirmed', 'cancelled', 'rejected'};

      if (oldStatus != 'pending' || !allowed.contains(newStatus)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Il Supervisor può gestire solo le richieste in attesa.',
            ),
          ),
        );
        return;
      }
    }

    if (oldStatus == newStatus) {
      return;
    }

    final firstName = booking['nome'] as String? ?? '';
    final lastName = booking['cognome'] as String? ?? '';

    final customerName = '$firstName $lastName'.trim().isEmpty
        ? 'questo cliente'
        : '$firstName $lastName'.trim();

    final confirmed = newStatus == 'cancelled'
        ? await _confirmStatusChange(
            oldStatus: oldStatus,
            newStatus: newStatus,
            customerName: customerName,
          )
        : true;

    if (!confirmed || !mounted) {
      return;
    }

    final guests = _readInteger(booking['guests']);
    final service = booking['service'] as String? ?? '';
    final dateKey = booking['dateKey'] as String? ?? '';

    final oldCounts = _countsForCapacity(oldStatus);
    final newCounts = _countsForCapacity(newStatus);

    final bookingReference = document.reference;

    final counterReference = _firestore
        .collection('availability_counters')
        .doc('${dateKey}_$service');

    try {
      await _firestore.runTransaction((transaction) async {
        final bookingSnapshot = await transaction.get(bookingReference);

        if (!bookingSnapshot.exists) {
          throw Exception('Prenotazione non trovata.');
        }

        int guestsDifference = 0;

        if (oldCounts && !newCounts) {
          guestsDifference = -guests;
        } else if (!oldCounts && newCounts) {
          guestsDifference = guests;
        }

        if (guestsDifference != 0 && dateKey.isNotEmpty && service.isNotEmpty) {
          final counterSnapshot = await transaction.get(counterReference);

          final currentGuests = counterSnapshot.exists
              ? _readInteger(counterSnapshot.data()?['bookedGuests'])
              : 0;

          final updatedGuests = (currentGuests + guestsDifference).clamp(
            0,
            100000,
          );

          transaction.set(counterReference, {
            'dateKey': dateKey,
            'service': service,
            'bookedGuests': updatedGuests,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        final updates = <String, dynamic>{
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        switch (newStatus) {
          case 'booked':
            updates['bookedAt'] = FieldValue.serverTimestamp();
            updates['bookedBy'] = 'admin';
            break;

          case 'confirmed':
            updates['confirmedAt'] = FieldValue.serverTimestamp();
            updates['confirmedBy'] = 'admin';
            break;

          case 'arrived':
            updates['arrivedAt'] = FieldValue.serverTimestamp();
            updates['arrivedBy'] = 'admin';
            break;

          case 'cancelled':
            updates['cancelledAt'] = FieldValue.serverTimestamp();
            updates['cancelledBy'] = 'admin';
            break;

          case 'rejected':
            updates['rejectedAt'] = FieldValue.serverTimestamp();
            updates['rejectedBy'] = 'admin';
            break;

          case 'no_show':
            updates['noShowAt'] = FieldValue.serverTimestamp();
            updates['noShowBy'] = 'admin';
            break;

          case 'released':
            updates['releasedAt'] = FieldValue.serverTimestamp();
            updates['releasedBy'] = 'admin';
            break;
        }

        transaction.update(bookingReference, updates);
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stato aggiornato: ${_statusLabel(newStatus)}.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aggiornamento non riuscito: $error')),
      );
    }
  }

  Widget _weeklyCalendar({
    required Map<String, int> guestsByDate,
    required Set<String> pendingDates,
  }) {
    final weekStart = _startOfWeek(_selectedDate);

    final weekDays = List.generate(
      7,
      (index) => weekStart.add(Duration(days: index)),
    );

    const weekdayLabels = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 3),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF3A342B))),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 30,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Settimana precedente',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  onPressed: () {
                    _changeWeek(-1);
                  },
                  icon: const Icon(Icons.chevron_left, size: 14),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _openCalendar,
                    borderRadius: BorderRadius.circular(7),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 14),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _weekLabel(weekStart),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Settimana successiva',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  onPressed: () {
                    _changeWeek(1);
                  },
                  icon: const Icon(Icons.chevron_right, size: 14),
                ),
              ],
            ),
          ),
          Row(
            children: List.generate(7, (index) {
              final date = weekDays[index];
              final key = _dateKey(date);
              final selected = key == _dateKey(_selectedDate);
              final hasBookings = guestsByDate.containsKey(key);
              final hasPending = pendingDates.contains(key);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(7),
                    onTap: () {
                      setState(() {
                        _selectedDate = date;
                        _selectedSection = 0;
                        _selectedFilter = 'all';
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFC8A45D)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Column(
                        children: [
                          Text(
                            weekdayLabels[index],
                            style: TextStyle(
                              color: selected
                                  ? Colors.black
                                  : Colors.grey.shade500,
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              color: selected ? Colors.black : Colors.white,
                              fontSize: 11,
                              height: 1.1,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 11,
                            child: hasBookings
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? Colors.black.withValues(alpha: 0.18)
                                          : const Color(0xFF2F775F),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: FittedBox(
                                      child: Text(
                                        '${guestsByDate[key]}p',
                                        style: TextStyle(
                                          color: selected
                                              ? Colors.black
                                              : Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  )
                                : hasPending
                                ? const Center(
                                    child: SizedBox(
                                      width: 6,
                                      height: 6,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _serviceButton({
    required String value,
    required String label,
    required IconData icon,
    required int guests,
    VoidCallback? onSettings,
    bool forceSelected = false,
  }) {
    final selected = _selectedService == value || forceSelected;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Container(
          height: 34,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFC8A45D) : Colors.transparent,
            border: Border.all(
              color: selected
                  ? const Color(0xFFE7C97F)
                  : const Color(0xFF6C5733),
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(7),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFFC8A45D).withValues(alpha: 0.22),
                      blurRadius: 7,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(7),
                  onTap: () {
                    setState(() {
                      _selectedService = value;
                    });
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        selected ? Icons.check_circle : icon,
                        size: 14,
                        color: selected
                            ? Colors.black
                            : const Color(0xFFC8A45D),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: FittedBox(
                          child: Text(
                            '$label ${guests}p',
                            style: TextStyle(
                              color: selected
                                  ? Colors.black
                                  : const Color(0xFFC8A45D),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (onSettings != null) ...[
                Container(width: 1, height: 20, color: const Color(0xFF6C5733)),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 32),
                  tooltip: 'Gestisci servizio',
                  onPressed: () {
                    setState(() {
                      _selectedService = value;
                    });
                    onSettings();
                  },
                  icon: Icon(
                    Icons.settings_outlined,
                    size: 17,
                    color: selected ? Colors.black : const Color(0xFFC8A45D),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _serviceSelector({
    required int allGuests,
    required int lunchGuests,
    required int dinnerGuests,
  }) {
    return FutureBuilder(
      future: CustomerAvailabilityService.getAvailabilityForDate(_selectedDate),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 40);
        }

        final availability = snapshot.data;
        final hasLunch = availability?.lunch.isOpen ?? false;
        final hasDinner = availability?.dinner.isOpen ?? false;
        final serviceCount = (hasLunch ? 1 : 0) + (hasDinner ? 1 : 0);

        final selectedServiceUnavailable =
            (_selectedService == 'lunch' && !hasLunch) ||
            (_selectedService == 'dinner' && !hasDinner);

        if (selectedServiceUnavailable) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _selectedService = 'all');
            }
          });
        }

        if (serviceCount == 0) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
          child: Row(
            children: [
              if (serviceCount > 1)
                _serviceButton(
                  value: 'all',
                  label: 'Tutti',
                  icon: Icons.restaurant,
                  guests: allGuests,
                ),
              if (hasLunch)
                _serviceButton(
                  value: 'lunch',
                  label: 'Pranzo',
                  icon: Icons.light_mode_outlined,
                  guests: lunchGuests,
                  forceSelected: serviceCount == 1 && _selectedService == 'all',
                  onSettings: _isManager && !_isDatePast(_selectedDate)
                      ? () => _openSlotClosures('lunch')
                      : null,
                ),
              if (hasDinner)
                _serviceButton(
                  value: 'dinner',
                  label: 'Cena',
                  icon: Icons.dark_mode_outlined,
                  guests: dinnerGuests,
                  forceSelected: serviceCount == 1 && _selectedService == 'all',
                  onSettings: _isManager && !_isDatePast(_selectedDate)
                      ? () => _openSlotClosures('dinner')
                      : null,
                ),
            ],
          ),
        );
      },
    );
  }

  Future<int?> _confirmServiceClosure({
    required String service,
    required String serviceLabel,
  }) async {
    final reasonController = TextEditingController();
    var submitting = false;

    final result = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              icon: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 48,
              ),
              title: Text(
                'CHIUSURA $serviceLabel',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Stai chiudendo l’intero servizio. Tutte le prenotazioni '
                      'attive verranno annullate automaticamente e i clienti '
                      'riceveranno la motivazione indicata.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: reasonController,
                      enabled: !submitting,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 500,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Motivazione obbligatoria',
                        hintText: 'Esempio: chiusura straordinaria per guasto…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('ANNULLA'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: submitting
                      ? null
                      : () async {
                          final reason = reasonController.text.trim();

                          if (reason.length < 8) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Inserisci una motivazione di almeno 8 caratteri.',
                                ),
                              ),
                            );
                            return;
                          }

                          setDialogState(() => submitting = true);

                          try {
                            final callable = FirebaseFunctions.instanceFor(
                              region: 'europe-west1',
                            ).httpsCallable('closeBookingService');
                            final response = await callable.call({
                              'dateKey': BookingSlotClosuresRepository.dateKey(
                                _selectedDate,
                              ),
                              'service': service,
                              'reason': reason,
                            });
                            final data = Map<String, dynamic>.from(
                              response.data as Map,
                            );

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(
                                (data['cancelledBookings'] as num?)?.toInt() ??
                                    0,
                              );
                            }
                          } catch (error) {
                            setDialogState(() => submitting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Chiusura servizio non riuscita: $error',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  icon: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.power_settings_new),
                  label: const Text('CHIUDI IL SERVIZIO'),
                ),
              ],
            );
          },
        );
      },
    );

    reasonController.dispose();
    return result;
  }

  Future<void> _openSlotClosures(String service) async {
    if (!_isManager) {
      return;
    }

    if (_isDatePast(_selectedDate)) {
      _showArchivedDayMessage();
      return;
    }

    final serviceLabel = service == 'lunch' ? 'Pranzo' : 'Cena';

    try {
      final availability =
          await CustomerAvailabilityService.getAvailabilityForDate(
            _selectedDate,
          );

      if (!mounted) {
        return;
      }

      if (availability == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nessun servizio disponibile per questa data.'),
          ),
        );
        return;
      }

      final selectedAvailability = service == 'lunch'
          ? availability.lunch
          : availability.dinner;

      if (!selectedAvailability.isOpen) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$serviceLabel non disponibile per questa data.'),
          ),
        );
        return;
      }

      final times = CustomerAvailabilityService.generateAvailableTimes(
        selectedAvailability,
        date: _selectedDate,
      );

      final closedTimes = await BookingSlotClosuresRepository.loadClosedTimes(
        date: _selectedDate,
        service: service,
      );

      var serviceClosure =
          await BookingSlotClosuresRepository.loadServiceClosure(
            date: _selectedDate,
            service: service,
          );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text('$serviceLabel · ${_fullDateLabel(_selectedDate)}'),
                content: SizedBox(
                  width: 420,
                  height: 520,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final currentlyClosed = serviceClosure != null;

                                try {
                                  await BookingSlotClosuresRepository.setServiceOnlineDisabled(
                                    date: _selectedDate,
                                    service: service,
                                    disabled: !currentlyClosed,
                                  );

                                  setDialogState(() {
                                    serviceClosure = currentlyClosed
                                        ? null
                                        : {
                                            'mode': 'online_disabled',
                                            'closed': true,
                                          };
                                  });
                                } catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Modifica servizio non riuscita: $error',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      serviceClosure == null
                                          ? Icons.public
                                          : Icons.public_off_outlined,
                                      color: serviceClosure == null
                                          ? const Color(0xFFC8A45D)
                                          : Colors.grey,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      serviceClosure == null
                                          ? 'Disattiva online'
                                          : serviceClosure?['mode'] ==
                                                'service_closed'
                                          ? 'Riapri servizio'
                                          : 'Riattiva online',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.redAccent),
                              ),
                              onPressed:
                                  serviceClosure?['mode'] == 'service_closed'
                                  ? null
                                  : () async {
                                      final cancelled =
                                          await _confirmServiceClosure(
                                            service: service,
                                            serviceLabel: serviceLabel,
                                          );

                                      if (cancelled == null ||
                                          !context.mounted) {
                                        return;
                                      }

                                      Navigator.of(dialogContext).pop();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Servizio chiuso. Prenotazioni annullate: $cancelled.',
                                          ),
                                        ),
                                      );
                                    },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.power_settings_new,
                                      color: Colors.redAccent,
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Chiudi servizio',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 4),
                      Expanded(
                        child: times.isEmpty
                            ? const Center(
                                child: Text(
                                  'Nessuna fascia oraria disponibile.',
                                ),
                              )
                            : ListView.separated(
                                itemCount: times.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final time = times[index];
                                  final closed =
                                      serviceClosure != null ||
                                      closedTimes.contains(time);

                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      time,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        decoration: closed
                                            ? TextDecoration.lineThrough
                                            : TextDecoration.none,
                                        color: closed ? Colors.grey : null,
                                      ),
                                    ),
                                    subtitle: Text(
                                      closed
                                          ? 'Fascia completa'
                                          : 'Prenotabile online',
                                    ),
                                    trailing: IconButton(
                                      tooltip: closed
                                          ? 'Riapri fascia online'
                                          : 'Chiudi fascia online',
                                      icon: Icon(
                                        closed
                                            ? Icons.public_off_outlined
                                            : Icons.public,
                                        color: closed
                                            ? Colors.grey
                                            : const Color(0xFFC8A45D),
                                      ),
                                      onPressed: serviceClosure != null
                                          ? null
                                          : () async {
                                              try {
                                                await BookingSlotClosuresRepository.setClosed(
                                                  date: _selectedDate,
                                                  service: service,
                                                  time: time,
                                                  closed: !closed,
                                                );

                                                if (!mounted) {
                                                  return;
                                                }

                                                setDialogState(() {
                                                  if (closed) {
                                                    closedTimes.remove(time);
                                                  } else {
                                                    closedTimes.add(time);
                                                  }
                                                });
                                              } catch (error) {
                                                if (!context.mounted) {
                                                  return;
                                                }

                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Modifica fascia non riuscita: $error',
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('CHIUDI'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Caricamento fasce non riuscito: $error')),
      );
    }
  }

  Widget _sectionButton({
    required int value,
    required String label,
    required IconData icon,
    required int count,
  }) {
    final selected = _selectedSection == value;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 34),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            backgroundColor: selected
                ? const Color(0xFFC8A45D)
                : Colors.transparent,
            foregroundColor: selected ? Colors.black : const Color(0xFFC8A45D),
            padding: const EdgeInsets.symmetric(vertical: 3),
            side: BorderSide(
              color: selected ? const Color(0xFFC8A45D) : Colors.grey.shade600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          onPressed: () {
            setState(() {
              _selectedSection = value;
            });
          },
          icon: Icon(icon, size: 14),
          label: FittedBox(
            child: Text(
              '$label ($count)',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionSelector({required int activeCount, required int pastCount}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      child: Row(
        children: [
          _sectionButton(
            value: 0,
            label: 'Attive',
            icon: Icons.event_available_outlined,
            count: activeCount,
          ),
          _sectionButton(
            value: 1,
            label: 'Passate',
            icon: Icons.history,
            count: pastCount,
          ),
        ],
      ),
    );
  }

  Widget _quickFilters() {
    const filters = <(String, String, IconData)>[
      ('all', 'Tutte', Icons.tune),
      ('upcoming', 'Imminenti', Icons.schedule),
      ('pending', 'In attesa', Icons.hourglass_top),
      ('notes', 'Con note', Icons.sticky_note_2_outlined),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
      child: Row(
        children: filters.map((filter) {
          final selected = _selectedFilter == filter.$1;

          return Padding(
            padding: const EdgeInsets.only(right: 5),
            child: FilterChip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _selectedFilter = filter.$1;
                });
              },
              avatar: Icon(filter.$3, size: 14),
              label: Text(filter.$2, style: const TextStyle(fontSize: 10)),
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _matchesQuickFilter(Map<String, dynamic> booking) {
    final status = booking['status'] as String? ?? 'pending';

    final notes = booking['notes'] as String? ?? '';

    switch (_selectedFilter) {
      case 'pending':
        return status == 'pending';

      case 'notes':
        return notes.trim().isNotEmpty;

      case 'upcoming':
        final selectedDay = _dateKey(_selectedDate);

        final today = _dateKey(DateTime.now());

        if (selectedDay != today) {
          return true;
        }

        final now = DateTime.now();

        final currentTime =
            '${now.hour.toString().padLeft(2, '0')}:'
            '${now.minute.toString().padLeft(2, '0')}';

        final bookingTime = booking['time'] as String? ?? '';

        return bookingTime.compareTo(currentTime) >= 0;

      default:
        return true;
    }
  }

  int _guestTotal(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> bookings,
    String service,
  ) {
    return bookings
        .where((document) {
          final booking = document.data();

          final status = booking['status'] as String? ?? 'pending';

          if (!_countsForCapacity(status)) {
            return false;
          }

          return service == 'all' || booking['service'] == service;
        })
        .fold<int>(0, (total, document) {
          return total + _readInteger(document.data()['guests']);
        });
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortBookings(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> bookings,
  ) {
    final sorted = [...bookings];

    sorted.sort((first, second) {
      final firstTime = first.data()['time'] as String? ?? '';

      final secondTime = second.data()['time'] as String? ?? '';

      return firstTime.compareTo(secondTime);
    });

    return sorted;
  }

  Widget _reconfirmationBadge(Map<String, dynamic> booking) {
    final status = booking['status'] as String? ?? '';

    final reconfirmationStatus =
        booking['reconfirmationStatus'] as String? ?? '';

    final reminderSent =
        booking['reconfirmationReminderTriggered'] == true ||
        booking['reconfirmationWhatsappSent'] == true;

    if (status == 'cancelled' &&
        booking['cancellationSource'] == 'whatsapp_reconfirmation') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_outlined, size: 14, color: Colors.red),
            SizedBox(width: 5),
            Text(
              'Annullata dal cliente',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (reconfirmationStatus == 'confirmed') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_outlined, size: 14, color: Colors.green),
            SizedBox(width: 5),
            Text(
              'Riconfermata WhatsApp',
              style: TextStyle(
                color: Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (reconfirmationStatus == 'pending' || reminderSent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_top_outlined, size: 14, color: Colors.orange),
            SizedBox(width: 5),
            Text(
              'Riconferma inviata',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            _statusLabel(status),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _onlineBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.language_outlined, size: 14, color: Colors.amber),
          SizedBox(width: 5),
          Text(
            'Online',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookingOriginLogo(String origin) {
    late final Color backgroundColor;
    late final Color borderColor;
    late final String assetPath;
    late final double logoSize;

    switch (origin) {
      case 'google':
        backgroundColor = Colors.white;
        borderColor = const Color(0xFF4285F4);
        assetPath = 'assets/images/booking_origins/google.svg';
        logoSize = 18;
        break;

      case 'instagram':
        backgroundColor = const Color(0xFFE1306C);
        borderColor = Colors.white;
        assetPath = 'assets/images/booking_origins/instagram.svg';
        logoSize = 18;
        break;

      case 'whatsapp':
        backgroundColor = const Color(0xFF25D366);
        borderColor = Colors.white;
        assetPath = 'assets/images/booking_origins/whatsapp.svg';
        logoSize = 18;
        break;

      case 'direct':
        backgroundColor = Colors.blueGrey;
        borderColor = Colors.white;
        assetPath = 'assets/images/booking_origins/direct.svg';
        logoSize = 18;
        break;

      default:
        return const SizedBox.shrink();
    }

    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor.withValues(alpha: 0.65)),
      ),
      child: SvgPicture.asset(
        assetPath,
        width: logoSize,
        height: logoSize,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _noShowWarning(int noShowCount) {
    if (noShowCount < 1) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.deepPurple),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.deepPurple),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              noShowCount == 1
                  ? 'Cliente con 1 no-show precedente'
                  : 'Cliente con $noShowCount '
                        'no-show precedenti',
              style: const TextStyle(
                color: Colors.deepPurple,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    );
  }

  Future<bool> _updateBookingGuests(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
    int newGuests,
  ) async {
    if (!_isManager) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo Admin e Manager possono modificare i coperti.'),
        ),
      );
      return false;
    }

    if (_isBookingPast(document.data())) {
      _showArchivedDayMessage();
      return false;
    }

    if (newGuests < 1) {
      return false;
    }

    try {
      await _firestore.runTransaction((transaction) async {
        final bookingSnapshot = await transaction.get(document.reference);

        if (!bookingSnapshot.exists) {
          throw Exception('Prenotazione non trovata.');
        }

        final booking = bookingSnapshot.data()!;
        final oldGuests = _readInteger(booking['guests']);
        final status = booking['status'] as String? ?? 'pending';
        final dateKey = booking['dateKey'] as String? ?? '';
        final service = booking['service'] as String? ?? '';

        if (oldGuests == newGuests) {
          return;
        }

        if (_countsForCapacity(status) &&
            dateKey.isNotEmpty &&
            service.isNotEmpty) {
          final counterReference = _firestore
              .collection('availability_counters')
              .doc('${dateKey}_$service');

          final counterSnapshot = await transaction.get(counterReference);

          final currentGuests = counterSnapshot.exists
              ? _readInteger(counterSnapshot.data()?['bookedGuests'])
              : 0;

          final updatedGuests = (currentGuests + newGuests - oldGuests).clamp(
            0,
            100000,
          );

          transaction.set(counterReference, {
            'dateKey': dateKey,
            'service': service,
            'bookedGuests': updatedGuests,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        transaction.update(document.reference, {
          'guests': newGuests,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Modifica coperti non riuscita: $error')),
        );
      }

      return false;
    }
  }

  Future<bool> _updateBookingTime(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
    String newTime,
  ) async {
    if (!_isManager) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo Admin e Manager possono modificare l’orario.'),
        ),
      );
      return false;
    }

    if (_isBookingPast(document.data())) {
      _showArchivedDayMessage();
      return false;
    }

    try {
      await document.reference.update({
        'time': newTime,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Modifica orario non riuscita: $error')),
        );
      }

      return false;
    }
  }

  String _shiftBookingTime(String value, int minutes) {
    final parts = value.split(':');

    if (parts.length != 2) {
      return value;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return value;
    }

    final currentMinutes = hour * 60 + minute;
    final shifted = (currentMinutes + minutes).clamp(0, 23 * 60 + 30);
    final newHour = shifted ~/ 60;
    final newMinute = shifted % 60;

    return '${newHour.toString().padLeft(2, '0')}:'
        '${newMinute.toString().padLeft(2, '0')}';
  }

  String _bookingSheetDateLabel(String dateKey) {
    final parts = dateKey.split('-');

    if (parts.length != 3) {
      return dateKey;
    }

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);

    if (year == null ||
        month == null ||
        month < 1 ||
        month > 12 ||
        day == null) {
      return dateKey;
    }

    final date = DateTime(year, month, day);
    final weekday = _weekdayNames[date.weekday - 1];
    final monthName = _monthNames[date.month - 1].substring(0, 3);

    return '$weekday $day $monthName $year';
  }

  Widget _quickEditControl({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback? onMinus,
    required VoidCallback? onPlus,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF202020),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A342B)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFC8A45D)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton.outlined(
            onPressed: onMinus,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 64,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton.outlined(
            onPressed: onPlus,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Future<void> _showBookingDetails(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final booking = document.data();
    if (_isNotificationUnread(booking)) {
      await _markNotificationRead(document);

      if (!mounted) {
        return;
      }
    }

    final firstName = booking['nome'] as String? ?? '';
    final lastName = booking['cognome'] as String? ?? '';
    final email = booking['email'] as String? ?? '';
    final phone = booking['telefono'] as String? ?? '';
    final service = booking['service'] as String? ?? '';
    final occasion = booking['occasion'] as String? ?? '';
    final notes = booking['notes'] as String? ?? '';
    final source = booking['source'] as String? ?? '';
    final bookingOrigin = booking['bookingOrigin'] as String? ?? '';
    final dateKey = booking['dateKey'] as String? ?? '';
    final isPastBooking = _isBookingPast(booking);
    final noShowCount = _readInteger(booking['customerNoShowCount']);
    final fullName = '$firstName $lastName'.trim();

    var currentGuests = _readInteger(booking['guests']);
    var currentTime = booking['time'] as String? ?? '--:--';
    var currentStatus = booking['status'] as String? ?? 'pending';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF171717),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            final canQuickEdit = _isManager && !isPastBooking;

            Future<void> changeGuests(int difference) async {
              final newGuests = currentGuests + difference;

              if (newGuests < 1) {
                return;
              }

              final updated = await _updateBookingGuests(document, newGuests);

              if (updated && sheetContext.mounted) {
                setModalState(() {
                  currentGuests = newGuests;
                });
              }
            }

            Future<void> changeTime(int difference) async {
              final newTime = _shiftBookingTime(currentTime, difference);

              if (newTime == currentTime) {
                return;
              }

              final updated = await _updateBookingTime(document, newTime);

              if (updated && sheetContext.mounted) {
                setModalState(() {
                  currentTime = newTime;
                });
              }
            }

            return FractionallySizedBox(
              heightFactor: 0.9,
              child: Column(
                children: [
                  const SizedBox(height: 9),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 10, 10),
                    child: Row(
                      children: [
                        const SizedBox(width: 42),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                fullName.isEmpty ? 'Cliente' : fullName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$currentGuests'
                                '${currentGuests == 1 ? ' persona' : ' persone'}'
                                ' · ${_bookingSheetDateLabel(dateKey)}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Chiudi',
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                          },
                          icon: const Icon(Icons.close, size: 27),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            isPastBooking
                                ? 'Prenotazione archiviata'
                                : 'Modifica prenotazione',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFC8A45D),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _quickEditControl(
                            icon: Icons.people_outline,
                            label: 'Persone',
                            value: '${currentGuests}p',
                            onMinus: canQuickEdit && currentGuests > 1
                                ? () {
                                    changeGuests(-1);
                                  }
                                : null,
                            onPlus: canQuickEdit
                                ? () {
                                    changeGuests(1);
                                  }
                                : null,
                          ),
                          const SizedBox(height: 10),
                          _quickEditControl(
                            icon: Icons.schedule,
                            label: 'Orario',
                            value: currentTime,
                            onMinus: canQuickEdit
                                ? () {
                                    changeTime(-30);
                                  }
                                : null,
                            onPlus: canQuickEdit
                                ? () {
                                    changeTime(30);
                                  }
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF202020),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                if (phone.isNotEmpty)
                                  _infoRow(
                                    icon: Icons.phone_outlined,
                                    text: phone,
                                  ),
                                if (phone.isNotEmpty && email.isNotEmpty)
                                  const SizedBox(height: 10),
                                if (email.isNotEmpty)
                                  _infoRow(
                                    icon: Icons.email_outlined,
                                    text: email,
                                  ),
                                if (service.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  _infoRow(
                                    icon: Icons.restaurant_outlined,
                                    text: _serviceLabel(service),
                                  ),
                                ],
                                if (occasion.isNotEmpty &&
                                    occasion != 'Nessuna') ...[
                                  const SizedBox(height: 10),
                                  _infoRow(
                                    icon: Icons.celebration_outlined,
                                    text: occasion,
                                  ),
                                ],
                                if (source == 'customer') ...[
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _onlineBadge(),
                                        if (bookingOrigin.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          _bookingOriginLogo(bookingOrigin),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (notes.trim().isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFC8A45D,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(
                                    0xFFC8A45D,
                                  ).withValues(alpha: 0.55),
                                ),
                              ),
                              child: _infoRow(
                                icon: Icons.sticky_note_2_outlined,
                                text: notes,
                              ),
                            ),
                          ],
                          if (noShowCount > 0) ...[
                            const SizedBox(height: 14),
                            _noShowWarning(noShowCount),
                          ],
                          const SizedBox(height: 22),
                          const Text(
                            'Modifica stato',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFC8A45D),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _selectableStatuses.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 9,
                                  mainAxisExtent: 48,
                                ),
                            itemBuilder: (context, index) {
                              final status = _selectableStatuses[index];
                              final selected = status == currentStatus;
                              final color = _statusColor(status);

                              return FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: selected
                                      ? color
                                      : color.withValues(alpha: 0.18),
                                  foregroundColor: selected
                                      ? Colors.white
                                      : color,
                                  disabledBackgroundColor: color.withValues(
                                    alpha: 0.28,
                                  ),
                                  disabledForegroundColor: color.withValues(
                                    alpha: 0.65,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                  ),
                                  side: BorderSide(color: color),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: isPastBooking || selected
                                    ? null
                                    : () async {
                                        await _changeStatus(document, status);

                                        final freshDocument = await document
                                            .reference
                                            .get();

                                        if (!sheetContext.mounted ||
                                            !freshDocument.exists) {
                                          return;
                                        }

                                        final freshStatus =
                                            freshDocument.data()?['status']
                                                as String? ??
                                            currentStatus;

                                        if (freshStatus == status) {
                                          Navigator.of(sheetContext).pop();
                                          return;
                                        }

                                        setModalState(() {
                                          currentStatus = freshStatus;
                                        });
                                      },
                                icon: Icon(_statusIcon(status), size: 17),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _statusLabel(status),
                                    maxLines: 1,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBookingCard(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final booking = document.data();

    final firstName = booking['nome'] as String? ?? '';
    final lastName = booking['cognome'] as String? ?? '';
    final notes = booking['notes'] as String? ?? '';
    final service = booking['service'] as String? ?? '';
    final status = booking['status'] as String? ?? 'pending';
    final guests = _readInteger(booking['guests']);
    final noShowCount = _readInteger(booking['customerNoShowCount']);
    final fullName = '$firstName $lastName'.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: const Color(0xFF191919),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: _statusColor(status).withValues(alpha: 0.42),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _showBookingDetails(document);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isEmpty ? 'Cliente' : fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 9,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_outline, size: 15),
                            const SizedBox(width: 3),
                            Text(
                              '${guests}p',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFC8A45D,
                            ).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(
                                0xFFC8A45D,
                              ).withValues(alpha: 0.65),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                service == 'lunch'
                                    ? Icons.light_mode_outlined
                                    : Icons.dark_mode_outlined,
                                size: 13,
                                color: const Color(0xFFC8A45D),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _serviceLabel(service),
                                style: const TextStyle(
                                  color: Color(0xFFC8A45D),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _statusBadge(status),
                        _reconfirmationBadge(booking),
                        if (noShowCount > 0)
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.deepPurpleAccent,
                            size: 21,
                          ),
                      ],
                    ),
                    if (notes.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFC8A45D,
                          ).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(
                              0xFFC8A45D,
                            ).withValues(alpha: 0.55),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.sticky_note_2_outlined,
                              color: Color(0xFFC8A45D),
                              size: 15,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                notes,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (status == 'pending' &&
                        _isSupervisor &&
                        !_isBookingPast(booking)) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                _changeStatus(document, 'rejected');
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFFF6B6B),
                                side: const BorderSide(
                                  color: Color(0xFFFF6B6B),
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text(
                                'Rifiuta',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                _changeStatus(document, 'confirmed');
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF4F8A54),
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text(
                                'Accetta',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptySection() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedSection == 0 ? Icons.event_busy_outlined : Icons.history,
              size: 52,
              color: Colors.grey,
            ),
            const SizedBox(height: 14),
            Text(
              _selectedSection == 0
                  ? 'Nessuna prenotazione attiva '
                        'per questa data'
                  : 'Nessuna prenotazione passata '
                        'per questa data',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookingList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> bookings,
  ) {
    if (bookings.isEmpty) {
      return _emptySection();
    }

    final groups =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};

    for (final booking in bookings) {
      final time = booking.data()['time'] as String? ?? 'Orario non indicato';

      groups.putIfAbsent(time, () => []).add(booking);
    }

    final times = groups.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      itemCount: times.length,
      itemBuilder: (context, index) {
        final time = times[index];
        final group = groups[time]!;

        final guests = group.fold<int>(0, (total, document) {
          return total + _readInteger(document.data()['guests']);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFC8A45D),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '$time • ${guests}p',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            ...group.map(_buildBookingCard),
          ],
        );
      },
    );
  }

  Widget _manualBookingForm() {
    InputDecoration decoration(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        isDense: true,
        border: const OutlineInputBorder(),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        const Text(
          'Inserimento manuale',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Per clienti telefonici o persone di passaggio.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _selectManualDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 17),
                label: Text(
                  _fullDateLabel(_selectedDate),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _selectManualTime,
                icon: const Icon(Icons.schedule_outlined, size: 17),
                label: Text(
                  _manualTimeValue(),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment<String>(
              value: 'lunch',
              label: Text('Pranzo', style: TextStyle(fontSize: 12)),
              icon: Icon(Icons.wb_sunny_outlined, size: 17),
            ),
            ButtonSegment<String>(
              value: 'dinner',
              label: Text('Cena', style: TextStyle(fontSize: 12)),
              icon: Icon(Icons.nightlight_outlined, size: 17),
            ),
          ],
          selected: {_manualService},
          onSelectionChanged: (selection) {
            setState(() {
              _manualService = selection.first;
            });
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          initialValue: _manualGuests,
          decoration: decoration('Numero di persone', Icons.people_outline),
          items: List.generate(20, (index) {
            final guests = index + 1;

            return DropdownMenuItem<int>(
              value: guests,
              child: Text(
                '$guests '
                '${guests == 1 ? 'persona' : 'persone'}',
                style: const TextStyle(fontSize: 13),
              ),
            );
          }),
          onChanged: (value) {
            if (value == null) {
              return;
            }

            setState(() {
              _manualGuests = value;
            });
          },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _manualFirstNameController,
          textCapitalization: TextCapitalization.words,
          decoration: decoration('Nome', Icons.person_outline),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _manualLastNameController,
          textCapitalization: TextCapitalization.words,
          decoration: decoration('Cognome', Icons.person_outline),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _manualPhoneController,
          keyboardType: TextInputType.phone,
          decoration: decoration('Telefono facoltativo', Icons.phone_outlined),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _manualEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: decoration('Email facoltativa', Icons.email_outlined),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _manualNotesController,
          minLines: 2,
          maxLines: 4,
          decoration: decoration('Note', Icons.notes_outlined),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _savingManualBooking || _isDatePast(_selectedDate)
              ? null
              : _saveManualBooking,
          icon: _savingManualBooking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add, size: 18),
          label: Text(
            _savingManualBooking ? 'Salvataggio...' : 'Aggiungi prenotazione',
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  DateTime? _bookingDateTime(Map<String, dynamic> booking) {
    final dateKey = booking['dateKey'] as String? ?? '';

    final time = booking['time'] as String? ?? '';

    final dateParts = dateKey.split('-');

    final timeParts = time.split(':');

    if (dateParts.length != 3 || timeParts.length < 2) {
      return null;
    }

    final year = int.tryParse(dateParts[0]);

    final month = int.tryParse(dateParts[1]);

    final day = int.tryParse(dateParts[2]);

    final hour = int.tryParse(timeParts[0]);

    final minute = int.tryParse(timeParts[1]);

    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null) {
      return null;
    }

    return DateTime(year, month, day, hour, minute);
  }

  bool _reconfirmationWaiting(Map<String, dynamic> booking) {
    final status = booking['status'] as String? ?? '';

    final reconfirmationStatus =
        booking['reconfirmationStatus'] as String? ?? '';

    return reconfirmationStatus == 'pending' &&
        (status == 'booked' || status == 'confirmed');
  }

  bool _unreadReconfirmationResult(Map<String, dynamic> booking) {
    final reconfirmationStatus =
        booking['reconfirmationStatus'] as String? ?? '';

    if (reconfirmationStatus != 'confirmed' &&
        reconfirmationStatus != 'cancelled') {
      return false;
    }

    return booking['reconfirmationResultRead'] == false;
  }

  bool _shouldShowNotification(Map<String, dynamic> booking) {
    final source = booking['source'] as String? ?? '';

    if (source != 'customer') {
      return false;
    }

    final status = booking['status'] as String? ?? 'pending';

    // Risposta ricevuta alla riconferma:
    // resta finché viene aperta.
    if (_unreadReconfirmationResult(booking)) {
      return true;
    }

    // Richiesta di riconferma ancora senza risposta.
    if (_reconfirmationWaiting(booking)) {
      return true;
    }

    // Richiesta >4 persone:
    // rimane finché viene gestita.
    if (status == 'pending') {
      return true;
    }

    // Se una richiesta manuale è stata gestita,
    // non deve restare nelle notifiche.
    if (booking['requiresManualConfirmation'] == true) {
      return false;
    }

    // Stati già conclusi o cliente già arrivato.
    if (_isPastStatus(status) || status == 'arrived') {
      return false;
    }

    // Normale prenotazione online nuova:
    // soltanto quelle create dopo questo aggiornamento.
    return booking['adminNotificationRead'] == false;
  }

  String _notificationTitle(Map<String, dynamic> booking) {
    final status = booking['status'] as String? ?? 'pending';

    final reconfirmationStatus =
        booking['reconfirmationStatus'] as String? ?? '';

    if (_unreadReconfirmationResult(booking)) {
      if (reconfirmationStatus == 'confirmed') {
        return 'Cliente ha riconfermato';
      }

      return 'Cliente ha annullato';
    }

    if (_reconfirmationWaiting(booking)) {
      final reservationTime = _bookingDateTime(booking);

      if (reservationTime != null && DateTime.now().isAfter(reservationTime)) {
        return 'Riconferma non ricevuta';
      }

      return 'Riconferma richiesta';
    }

    if (status == 'pending') {
      return 'Richiesta da confermare';
    }

    return 'Nuova prenotazione';
  }

  IconData _notificationIcon(Map<String, dynamic> booking) {
    final title = _notificationTitle(booking);

    switch (title) {
      case 'Cliente ha riconfermato':
        return Icons.verified_outlined;

      case 'Cliente ha annullato':
        return Icons.cancel_outlined;

      case 'Riconferma non ricevuta':
        return Icons.warning_amber_rounded;

      case 'Riconferma richiesta':
        return Icons.schedule_outlined;

      case 'Richiesta da confermare':
        return Icons.pending_actions_outlined;

      default:
        return Icons.notifications_active_outlined;
    }
  }

  Color _notificationColor(Map<String, dynamic> booking) {
    final title = _notificationTitle(booking);

    switch (title) {
      case 'Cliente ha riconfermato':
        return Colors.green;

      case 'Cliente ha annullato':
        return Colors.red;

      case 'Riconferma non ricevuta':
        return Colors.deepOrange;

      case 'Riconferma richiesta':
        return Colors.orange;

      case 'Richiesta da confermare':
        return const Color(0xFFC8A45D);

      default:
        return Colors.blue;
    }
  }

  DateTime _notificationSortTime(Map<String, dynamic> booking) {
    dynamic value;

    if (_unreadReconfirmationResult(booking)) {
      value = booking['lastWhatsappReplyAt'];
    } else if (_reconfirmationWaiting(booking)) {
      value =
          booking['reconfirmationReminderTriggeredAt'] ??
          booking['reconfirmationWhatsappSentAt'];
    } else {
      value = booking['adminNotificationCreatedAt'] ?? booking['createdAt'];
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _markNotificationRead(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final booking = document.data();

    final reconfirmationStatus =
        booking['reconfirmationStatus'] as String? ?? '';

    final updates = <String, dynamic>{
      'adminNotificationRead': true,
      'adminNotificationReadAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (reconfirmationStatus == 'confirmed' ||
        reconfirmationStatus == 'cancelled') {
      updates['reconfirmationResultRead'] = true;

      updates['reconfirmationResultReadAt'] = FieldValue.serverTimestamp();
    }

    try {
      await document.reference.set(updates, SetOptions(merge: true));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile aggiornare la notifica: $error')),
      );
    }
  }

  bool _isNotificationUnread(Map<String, dynamic> booking) {
    if (!_shouldShowNotification(booking)) {
      return false;
    }

    if (_unreadReconfirmationResult(booking)) {
      return true;
    }

    return booking['adminNotificationRead'] != true;
  }

  Future<void> _markAllNotificationsRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) async {
    final unreadDocuments = documents.where((document) {
      return _isNotificationUnread(document.data());
    }).toList();

    if (unreadDocuments.isEmpty) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tutte le notifiche sono già lette.')),
      );
      return;
    }

    try {
      const batchLimit = 400;

      for (var start = 0; start < unreadDocuments.length; start += batchLimit) {
        final end = start + batchLimit < unreadDocuments.length
            ? start + batchLimit
            : unreadDocuments.length;

        final batch = _firestore.batch();

        for (final document in unreadDocuments.sublist(start, end)) {
          final booking = document.data();

          final reconfirmationStatus =
              booking['reconfirmationStatus'] as String? ?? '';

          final updates = <String, dynamic>{
            'adminNotificationRead': true,
            'adminNotificationReadAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };

          if (reconfirmationStatus == 'confirmed' ||
              reconfirmationStatus == 'cancelled') {
            updates['reconfirmationResultRead'] = true;
            updates['reconfirmationResultReadAt'] =
                FieldValue.serverTimestamp();
          }

          batch.set(document.reference, updates, SetOptions(merge: true));
        }

        await batch.commit();
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${unreadDocuments.length} notifiche segnate come lette.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossibile segnare tutte le notifiche come lette: $error',
          ),
        ),
      );
    }
  }

  Widget _notificationsPage(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> bookings,
  ) {
    final notifications = bookings.where((document) {
      return _shouldShowNotification(document.data());
    }).toList();

    notifications.sort((first, second) {
      final firstTime = _notificationSortTime(first.data());

      final secondTime = _notificationSortTime(second.data());

      return secondTime.compareTo(firstTime);
    });

    if (notifications.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_none, size: 44, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'Nessuna notifica da gestire',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      itemCount: notifications.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          final unreadCount = notifications.where((document) {
            return _isNotificationUnread(document.data());
          }).length;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: unreadCount == 0
                    ? null
                    : () {
                        _markAllNotificationsRead(notifications);
                      },
                icon: const Icon(Icons.done_all, size: 18),
                label: Text(
                  unreadCount == 0
                      ? 'Tutte lette'
                      : 'Segna tutte come lette ($unreadCount)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }
        final document = notifications[index - 1];

        final booking = document.data();

        final firstName = booking['nome'] as String? ?? '';

        final lastName = booking['cognome'] as String? ?? '';

        final fullName = '$firstName $lastName'.trim();

        final dateKey = booking['dateKey'] as String? ?? '';

        final time = booking['time'] as String? ?? '--:--';

        final guests = _readInteger(booking['guests']);

        final notes = booking['notes'] as String? ?? '';

        final service = booking['service'] as String? ?? '';

        final status = booking['status'] as String? ?? 'pending';

        final notificationTitle = _notificationTitle(booking);

        final notificationColor = _notificationColor(booking);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _notificationIcon(booking),
                      color: notificationColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notificationTitle,
                        style: TextStyle(
                          color: notificationColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        fullName.isEmpty ? 'Cliente' : fullName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${guests}p',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${_italianDateFromKey(dateKey)} · '
                  '$time · ${_serviceLabel(service)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _statusColor(status),
                    ),
                  ),
                ),
                if (notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
                if (status == 'pending' &&
                    _isSupervisor &&
                    !_isBookingPast(booking)) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _changeStatus(document, 'rejected');
                          },
                          child: const Text(
                            'Rifiuta',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            _changeStatus(document, 'confirmed');
                          },
                          child: const Text(
                            'Conferma',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      final parts = dateKey.split('-');

                      if (parts.length != 3) {
                        return;
                      }

                      final year = int.tryParse(parts[0]);

                      final month = int.tryParse(parts[1]);

                      final day = int.tryParse(parts[2]);

                      if (year == null || month == null || day == null) {
                        return;
                      }

                      await _markNotificationRead(document);

                      if (!mounted) {
                        return;
                      }

                      setState(() {
                        _selectedDate = DateTime(year, month, day);

                        _bottomIndex = 0;
                        _selectedSection = 0;
                        _selectedFilter = 'all';
                      });
                    },
                    child: const Text(
                      'Apri nel servizio',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _setNotificationsEnabled(bool value) async {
    final success = value
        ? await PushNotificationService.enableWebNotifications()
        : await PushNotificationService.disableCurrentDeviceNotifications();

    if (!mounted) {
      return;
    }

    if (success) {
      setState(() {});
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? value
                    ? 'Notifiche attivate su questo dispositivo.'
                    : 'Notifiche disattivate su questo dispositivo.'
              : value
              ? 'Impossibile attivare le notifiche. Controlla i permessi del dispositivo.'
              : 'Impossibile disattivare le notifiche.',
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Uscire dal gestionale?'),
          content: const Text(
            'Il logout richiederà nuovamente '
            'email e password al prossimo accesso.\n\n'
            'Se vuoi soltanto proteggere il gestionale, '
            'usa \u201CBlocca gestionale\u201D.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('ANNULLA'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('LOGOUT'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final logout = widget.onLogout;

    if (logout != null) {
      await logout();
    }
  }

  Widget _morePage() {
    Widget item({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      Color color = const Color(0xFFC8A45D),
    }) {
      return ListTile(
        dense: true,
        leading: Icon(icon, size: 21, color: color),
        title: Text(
          title,
          style: TextStyle(
            color: color == Colors.redAccent ? Colors.redAccent : null,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(8, 4, 8, 14),
          child: ListTile(
            leading: const Icon(
              Icons.account_circle_outlined,
              color: Color(0xFFC8A45D),
              size: 34,
            ),
            title: Text(
              widget.displayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              widget.email.isEmpty
                  ? _roleLabel
                  : '${widget.email}\n$_roleLabel',
            ),
            isThreeLine: widget.email.isNotEmpty,
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Text(
            'PRENOTAZIONI',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        item(
          icon: Icons.history,
          title: 'Prenotazioni passate',
          subtitle: 'Apri l’archivio della data selezionata',
          onTap: () {
            setState(() {
              _bottomIndex = 0;
              _selectedSection = 1;
              _selectedFilter = 'all';
            });
          },
        ),
        if (_isManager)
          if (_isAdmin)
            item(
              icon: Icons.campaign_outlined,
              title: 'Contatti e Marketing',
              subtitle: 'Clienti consenzienti, email e WhatsApp',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ContactsMarketingScreen(),
                  ),
                );
              },
            ),
        const Divider(),
        if (_isManager)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Text(
              'GESTIONE',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        if (_isManager)
          item(
            icon: Icons.calendar_month_outlined,
            title: 'Gestione servizi',
            subtitle:
                'Calendario, disponibilità, orari, '
                'coperti e chiusure',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AvailabilityScreen()),
              );
            },
          ),
        if (_isAdmin)
          item(
            icon: Icons.manage_accounts_outlined,
            title: 'Utenti e permessi',
            subtitle: 'Gestisci staff, ruoli e accessi al gestionale',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StaffUsersScreen()),
              );
            },
          ),
        if (_isAdmin)
          item(
            icon: Icons.settings_outlined,
            title: 'Impostazioni',
            subtitle: 'Notifiche, sicurezza e preferenze',
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        FutureBuilder<bool>(
          future: PushNotificationService.isCurrentDeviceEnabled(),
          builder: (context, snapshot) {
            final enabled = snapshot.data ?? false;
            final loading = snapshot.connectionState == ConnectionState.waiting;

            return ListTile(
              dense: true,
              leading: const Icon(
                Icons.notifications_active_outlined,
                size: 21,
                color: Color(0xFFC8A45D),
              ),
              title: const Text(
                'Notifiche',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                enabled
                    ? 'Avvisi nuove prenotazioni attivi'
                    : 'Avvisi nuove prenotazioni disattivati',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: Switch.adaptive(
                value: enabled,
                onChanged: loading
                    ? null
                    : (value) {
                        _setNotificationsEnabled(value);
                      },
              ),
            );
          },
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Text(
            'SICUREZZA',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        item(
          icon: Icons.lock_outline_rounded,
          title: 'Blocca gestionale',
          subtitle: 'Proteggi l’accesso senza effettuare il logout',
          onTap: () async {
            final lock = widget.onLock;

            if (lock != null) {
              await lock();
            }
          },
        ),
        item(
          icon: Icons.logout_rounded,
          title: 'Logout',
          subtitle: 'Esci dal tuo account',
          color: Colors.redAccent,
          onTap: _confirmLogout,
        ),
        const Padding(
          padding: EdgeInsets.only(top: 18, bottom: 12),
          child: Center(
            child: Text(
              'Versione 2.1.0',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ),
        ),
      ],
    );
  }

  Widget _monthlyCalendar({
    required Map<String, int> confirmedGuestsByDate,
    required Set<String> pendingDates,
  }) {
    final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);

    final nextMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);

    final daysInMonth = nextMonth.subtract(const Duration(days: 1)).day;

    final leadingEmptyDays = firstDay.weekday - 1;

    final cellCount = leadingEmptyDays + daysInMonth;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Mese precedente',
              onPressed: () {
                setState(() {
                  _selectedDate = DateTime(
                    _selectedDate.year,
                    _selectedDate.month - 1,
                    1,
                  );
                });
              },
              icon: const Icon(Icons.chevron_left, size: 24),
            ),
            Expanded(
              child: Text(
                '${_monthNames[_selectedDate.month - 1]} '
                '${_selectedDate.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Mese successivo',
              onPressed: () {
                setState(() {
                  _selectedDate = DateTime(
                    _selectedDate.year,
                    _selectedDate.month + 1,
                    1,
                  );
                });
              },
              icon: const Icon(Icons.chevron_right, size: 24),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Row(
          children: [
            _CalendarWeekday('Lun'),
            _CalendarWeekday('Mar'),
            _CalendarWeekday('Mer'),
            _CalendarWeekday('Gio'),
            _CalendarWeekday('Ven'),
            _CalendarWeekday('Sab'),
            _CalendarWeekday('Dom'),
          ],
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 64,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: cellCount,
          itemBuilder: (context, index) {
            if (index < leadingEmptyDays) {
              return const SizedBox.shrink();
            }

            final day = index - leadingEmptyDays + 1;

            final date = DateTime(_selectedDate.year, _selectedDate.month, day);

            final key = _dateKey(date);

            final guests = confirmedGuestsByDate[key] ?? 0;

            final hasPending = pendingDates.contains(key);

            final selected = key == _dateKey(_selectedDate);

            final isPast = _isDatePast(date);

            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() {
                  _selectedDate = date;
                  _bottomIndex = 0;
                  _selectedSection = 0;
                  _selectedFilter = 'all';
                });
              },
              child: Opacity(
                opacity: isPast ? 0.48 : 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: isPast
                        ? const Color(0xFF303030)
                        : selected
                        ? const Color(0xFFC8A45D).withValues(alpha: 0.22)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFC8A45D)
                          : const Color(0xFF3A342B),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 6,
                        left: 0,
                        right: 0,
                        child: Text(
                          '$day',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (guests > 0)
                        Positioned(
                          right: 3,
                          bottom: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC8A45D),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${guests}p',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      if (hasPending)
                        const Positioned(
                          left: 5,
                          bottom: 6,
                          child: CircleAvatar(
                            radius: 3,
                            backgroundColor: Colors.orange,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CalendarLegend(color: Color(0xFFC8A45D), label: 'Coperti'),
            SizedBox(width: 18),
            _CalendarLegend(color: Colors.orange, label: 'Da confermare'),
          ],
        ),
      ],
    );
  }

  Widget _bottomNavigation(int pendingCount) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF201D18),
        border: Border(top: BorderSide(color: Color(0xFFC8A45D), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: NavigationBar(
        height: 62,
        backgroundColor: const Color(0xFF201D18),
        indicatorColor: const Color(0xFFC8A45D),
        selectedIndex: _bottomIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: _selectDestination,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.menu_book_outlined, color: Color(0xFFE9E1D2)),
            selectedIcon: Icon(Icons.menu_book, color: Colors.black),
            label: 'Servizio',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined, color: Color(0xFFE9E1D2)),
            selectedIcon: Icon(Icons.calendar_month, color: Colors.black),
            label: 'Calendario',
          ),
          if (_isManager)
            const NavigationDestination(
              icon: Icon(
                Icons.add_circle_outline,
                color: Color(0xFFE9E1D2),
                size: 28,
              ),
              selectedIcon: Icon(
                Icons.add_circle,
                color: Colors.black,
                size: 28,
              ),
              label: 'Aggiungi',
            )
          else
            const NavigationDestination(
              icon: SizedBox.shrink(),
              selectedIcon: SizedBox.shrink(),
              label: '',
            ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text('$pendingCount'),
              child: const Icon(
                Icons.notifications_none,
                color: Color(0xFFE9E1D2),
              ),
            ),
            selectedIcon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text('$pendingCount'),
              child: const Icon(Icons.notifications, color: Colors.black),
            ),
            label: 'Notifiche',
          ),
          const NavigationDestination(
            icon: Icon(Icons.more_horiz, color: Color(0xFFE9E1D2)),
            selectedIcon: Icon(Icons.more_horiz, color: Colors.black),
            label: 'Altro',
          ),
        ],
      ),
    );
  }

  void _selectDestination(int index) {
    if (index == 2 && !_isManager) {
      return;
    }

    setState(() {
      _bottomIndex = index;

      if (index == 2) {
        if (_isDatePast(_selectedDate)) {
          _selectedDate = DateTime.now();
        }

        _manualTime = _currentQuarterHour();
        _manualService = _manualTime.hour < 17 ? 'lunch' : 'dinner';
      }

      if (index == 0) {
        _selectedDate = DateTime.now();
        _selectedSection = 0;
        _selectedService = 'all';
        _selectedFilter = 'all';
      }
    });
  }

  Widget _desktopNavigation(int pendingCount) {
    return Container(
      width: 238,
      decoration: const BoxDecoration(
        color: Color(0xFF11100E),
        border: Border(right: BorderSide(color: Color(0xFF2D2923))),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/logo_gestionale.png',
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LE CAPASE',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Gestionale',
                          style: TextStyle(
                            color: Color(0xFF8F887E),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: NavigationRail(
                backgroundColor: Colors.transparent,
                extended: true,
                minExtendedWidth: 238,
                selectedIndex: _bottomIndex,
                onDestinationSelected: _selectDestination,
                labelType: NavigationRailLabelType.none,
                groupAlignment: -0.9,
                indicatorColor: const Color(0xFFC8A45D),
                selectedIconTheme: const IconThemeData(color: Colors.black),
                selectedLabelTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                unselectedIconTheme: const IconThemeData(
                  color: Color(0xFFAAA399),
                ),
                unselectedLabelTextStyle: const TextStyle(
                  color: Color(0xFFAAA399),
                ),
                destinations: [
                  const NavigationRailDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    selectedIcon: Icon(Icons.menu_book),
                    label: Text('Servizio'),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month),
                    label: Text('Calendario'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(
                      _isManager
                          ? Icons.add_circle_outline
                          : Icons.lock_outline,
                    ),
                    selectedIcon: const Icon(Icons.add_circle),
                    label: Text(
                      _isManager ? 'Nuova prenotazione' : 'Riservato',
                    ),
                  ),
                  NavigationRailDestination(
                    icon: Badge(
                      isLabelVisible: pendingCount > 0,
                      label: Text('$pendingCount'),
                      child: const Icon(Icons.notifications_none),
                    ),
                    selectedIcon: Badge(
                      isLabelVisible: pendingCount > 0,
                      label: Text('$pendingCount'),
                      child: const Icon(Icons.notifications),
                    ),
                    label: const Text('Notifiche'),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.grid_view_outlined),
                    selectedIcon: Icon(Icons.grid_view_rounded),
                    label: Text('Altro'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1815),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF302C26)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 17,
                      backgroundColor: Color(0xFFC8A45D),
                      child: Icon(
                        Icons.person_outline,
                        color: Colors.black,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _roleLabel,
                            style: const TextStyle(
                              color: Color(0xFF8F887E),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Logout',
                      onPressed: widget.onLogout == null
                          ? null
                          : () async {
                              await widget.onLogout!();
                            },
                      style: IconButton.styleFrom(
                        foregroundColor: const Color(0xFFC8A45D),
                        backgroundColor: const Color(
                          0xFFC8A45D,
                        ).withValues(alpha: 0.10),
                        minimumSize: const Size(36, 36),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktopTopBar(String title) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      decoration: const BoxDecoration(
        color: Color(0xFF151411),
        border: Border(bottom: BorderSide(color: Color(0xFF2D2923))),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (_bottomIndex == 0)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedDate = DateTime.now();
                  _selectedSection = 0;
                  _selectedFilter = 'all';
                });
              },
              icon: const Icon(Icons.today_outlined, size: 19),
              label: const Text('Oggi'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const titles = [
      'Servizio',
      'Calendario',
      'Nuova prenotazione',
      'Notifiche',
      'Altro',
    ];

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('bookings').snapshots(),
      builder: (context, snapshot) {
        final allBookings = snapshot.data?.docs ?? [];

        final allCapacityGuestsByDate = <String, int>{};

        final confirmedGuestsByDate = <String, int>{};

        final pendingDates = <String>{};

        for (final document in allBookings) {
          final booking = document.data();

          final status = booking['status'] as String? ?? 'pending';

          final dateKey = booking['dateKey'] as String? ?? '';

          final guests = _readInteger(booking['guests']);

          if (dateKey.isEmpty) {
            continue;
          }

          if (_countsForCapacity(status)) {
            allCapacityGuestsByDate.update(
              dateKey,
              (current) => current + guests,
              ifAbsent: () => guests,
            );
          }

          if (_countsAsConfirmedCover(status)) {
            confirmedGuestsByDate.update(
              dateKey,
              (current) => current + guests,
              ifAbsent: () => guests,
            );
          }

          if (status == 'pending') {
            pendingDates.add(dateKey);
          }
        }

        final pendingCount = allBookings.where((document) {
          return _isNotificationUnread(document.data());
        }).length;

        Widget body;

        if (snapshot.hasError) {
          body = Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Errore nel caricamento '
                'delle prenotazioni:\n'
                '${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        } else if (snapshot.connectionState == ConnectionState.waiting) {
          body = const Center(child: CircularProgressIndicator());
        } else if (_bottomIndex == 1) {
          body = _monthlyCalendar(
            confirmedGuestsByDate: confirmedGuestsByDate,
            pendingDates: pendingDates,
          );
        } else if (_bottomIndex == 2) {
          body = _manualBookingForm();
        } else if (_bottomIndex == 3) {
          body = _notificationsPage(allBookings);
        } else if (_bottomIndex == 4) {
          body = _morePage();
        } else {
          final selectedDateKey = _dateKey(_selectedDate);

          final dateBookings = allBookings.where((document) {
            return document.data()['dateKey'] == selectedDateKey;
          }).toList();

          final activeForDate = _sortBookings(
            dateBookings.where((document) {
              final status = document.data()['status'] as String? ?? 'pending';

              return !_isPastStatus(status);
            }).toList(),
          );

          final pastForDate = _sortBookings(
            dateBookings.where((document) {
              final status = document.data()['status'] as String? ?? 'pending';

              return _isPastStatus(status);
            }).toList(),
          );

          final sectionBookings = _selectedSection == 0
              ? activeForDate
              : pastForDate;

          final visibleBookings = sectionBookings.where((document) {
            final booking = document.data();

            final serviceMatches =
                _selectedService == 'all' ||
                booking['service'] == _selectedService;

            return serviceMatches && _matchesQuickFilter(booking);
          }).toList();

          final allGuests = _guestTotal(activeForDate, 'all');

          final lunchGuests = _guestTotal(activeForDate, 'lunch');

          final dinnerGuests = _guestTotal(activeForDate, 'dinner');

          body = Column(
            children: [
              _weeklyCalendar(
                guestsByDate: allCapacityGuestsByDate,
                pendingDates: pendingDates,
              ),
              _serviceSelector(
                allGuests: allGuests,
                lunchGuests: lunchGuests,
                dinnerGuests: dinnerGuests,
              ),
              _sectionSelector(
                activeCount: activeForDate.length,
                pastCount: pastForDate.length,
              ),
              _quickFilters(),
              Expanded(child: _bookingList(visibleBookings)),
            ],
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 980;

            if (desktop) {
              return Scaffold(
                body: Row(
                  children: [
                    _desktopNavigation(pendingCount),
                    Expanded(
                      child: Column(
                        children: [
                          _desktopTopBar(titles[_bottomIndex]),
                          Expanded(
                            child: Container(
                              color: const Color(0xFF0F0E0C),
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1180,
                                ),
                                child: body,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                toolbarHeight: 52,
                titleSpacing: 18,
                title: Text(
                  titles[_bottomIndex],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                actions: [
                  if (_bottomIndex == 0)
                    IconButton(
                      tooltip: 'Vai a oggi',
                      onPressed: () {
                        setState(() {
                          _selectedDate = DateTime.now();
                          _selectedSection = 0;
                          _selectedFilter = 'all';
                        });
                      },
                      icon: const Icon(Icons.today_outlined, size: 21),
                    ),
                ],
              ),
              body: body,
              bottomNavigationBar: _bottomNavigation(pendingCount),
            );
          },
        );
      },
    );
  }
}

class _CalendarWeekday extends StatelessWidget {
  const _CalendarWeekday(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
