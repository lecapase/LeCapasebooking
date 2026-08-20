import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime _selectedDate = DateTime.now();

  int _selectedSection = 0;

  String _selectedService = 'all';

  String _selectedFilter = 'all';

  static const List<String> _selectableStatuses = [
    'booked',
    'confirmed',
    'cancelled',
    'no_show',
    'released',
  ];

  static const Set<String> _pastStatuses = {
    'cancelled',
    'no_show',
    'released',
    'completed',
    'rejected',
  };

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

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);

    return normalized.subtract(Duration(days: normalized.weekday - 1));
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

  String _weekLabel(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));

    const months = [
      'gen',
      'feb',
      'mar',
      'apr',
      'mag',
      'giu',
      'lug',
      'ago',
      'set',
      'ott',
      'nov',
      'dic',
    ];

    if (weekStart.month == weekEnd.month) {
      return '${weekStart.day}–${weekEnd.day} '
          '${months[weekStart.month - 1]} '
          '${weekStart.year}';
    }

    return '${weekStart.day} '
        '${months[weekStart.month - 1]} – '
        '${weekEnd.day} '
        '${months[weekEnd.month - 1]} '
        '${weekEnd.year}';
  }

  void _changeWeek(int numberOfWeeks) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: numberOfWeeks * 7));
    });
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
    });
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

        if (oldStatus == 'pending') {
          message =
              'Vuoi annullare la richiesta di '
              '$customerName?'
              '\n\nIl cliente riceverà una comunicazione '
              'che la richiesta non è stata accettata.';
        } else {
          message =
              'Vuoi annullare la prenotazione di '
              '$customerName?'
              '\n\nIl cliente riceverà automaticamente '
              'l’email di annullamento.';
        }

        buttonLabel = 'Annulla';
        break;

      case 'no_show':
        title = 'Segna come No-show';
        message =
            'Confermi che $customerName non si è presentato?'
            '\n\nL’episodio verrà registrato nello storico '
            'del cliente e i coperti torneranno disponibili.';

        buttonLabel = 'No-show';
        break;

      case 'released':
        title = 'Segna come Liberato';
        message =
            'Confermi che il tavolo di $customerName '
            'è stato liberato?'
            '\n\nI coperti torneranno disponibili e '
            'la prenotazione passerà tra le passate.';

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
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Indietro'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _statusColor(newStatus),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(buttonLabel),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  Future<void> _requestStatusChange(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
    String newStatus,
  ) async {
    final booking = document.data();

    final oldStatus = booking['status'] as String? ?? 'pending';

    if (oldStatus == newStatus) {
      return;
    }

    final firstName = booking['nome'] as String? ?? '';

    final lastName = booking['cognome'] as String? ?? '';

    final fullName = '$firstName $lastName'.trim();

    final confirmed = await _confirmStatusChange(
      oldStatus: oldStatus,
      newStatus: newStatus,
      customerName: fullName.isEmpty ? 'il cliente' : fullName,
    );

    if (!confirmed) {
      return;
    }

    await _setStatus(document.reference, newStatus);
  }

  Future<void> _setStatus(
    DocumentReference<Map<String, dynamic>> bookingReference,
    String newStatus,
  ) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final bookingSnapshot = await transaction.get(bookingReference);

        if (!bookingSnapshot.exists) {
          return;
        }

        final booking = bookingSnapshot.data();

        if (booking == null) {
          return;
        }

        final oldStatus = booking['status'] as String? ?? 'pending';

        if (oldStatus == newStatus) {
          return;
        }

        final guests = _readInteger(booking['guests']);

        final dateKey = booking['dateKey'] as String? ?? '';

        final service = booking['service'] as String? ?? '';

        final oldCounts = _countsForCapacity(oldStatus);

        final newCounts = _countsForCapacity(newStatus);

        final counterReference = _firestore
            .collection('availability_counters')
            .doc('${dateKey}_$service');

        if (oldCounts &&
            !newCounts &&
            dateKey.isNotEmpty &&
            service.isNotEmpty) {
          final counterSnapshot = await transaction.get(counterReference);

          if (counterSnapshot.exists) {
            final counter = counterSnapshot.data();

            final current = _readInteger(counter?['bookedGuests']);

            var updated = current - guests;

            if (updated < 0) {
              updated = 0;
            }

            transaction.update(counterReference, {
              'bookedGuests': updated,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }

        if (!oldCounts &&
            newCounts &&
            dateKey.isNotEmpty &&
            service.isNotEmpty) {
          final counterSnapshot = await transaction.get(counterReference);

          var current = 0;

          if (counterSnapshot.exists) {
            current = _readInteger(counterSnapshot.data()?['bookedGuests']);
          }

          transaction.set(counterReference, {
            'dateKey': dateKey,
            'service': service,
            'bookedGuests': current + guests,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        final updateData = <String, dynamic>{
          'status': newStatus,
          'previousStatus': oldStatus,
          'statusChangedAt': FieldValue.serverTimestamp(),
          'statusChangedBy': 'admin',
          'updatedAt': FieldValue.serverTimestamp(),
        };

        switch (newStatus) {
          case 'booked':
            updateData.addAll({
              'bookedAt': FieldValue.serverTimestamp(),
              'bookedBy': 'admin',
              'requiresManualConfirmation': false,
            });
            break;

          case 'confirmed':
            updateData.addAll({
              'confirmedAt': FieldValue.serverTimestamp(),
              'confirmedBy': 'admin',
              'requiresManualConfirmation': false,
            });
            break;

          case 'cancelled':
            updateData.addAll({
              'cancelledAt': FieldValue.serverTimestamp(),
              'cancelledBy': 'admin',
            });
            break;

          case 'no_show':
            updateData.addAll({
              'noShowAt': FieldValue.serverTimestamp(),
              'noShowBy': 'admin',
            });
            break;

          case 'released':
            updateData.addAll({
              'releasedAt': FieldValue.serverTimestamp(),
              'releasedBy': 'admin',
            });
            break;
        }

        transaction.update(bookingReference, updateData);
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nuovo stato: '
            '${_statusLabel(newStatus)}',
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
            'Errore durante l’aggiornamento: '
            '$error',
          ),
        ),
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
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF3A342B))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Settimana precedente',
                onPressed: () {
                  _changeWeek(-1);
                },
                icon: const Icon(Icons.chevron_left, size: 32),
              ),
              Expanded(
                child: InkWell(
                  onTap: _openCalendar,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _weekLabel(weekStart),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Settimana successiva',
                onPressed: () {
                  _changeWeek(1);
                },
                icon: const Icon(Icons.chevron_right, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: List.generate(7, (index) {
              final date = weekDays[index];

              final key = _dateKey(date);

              final selected = key == _dateKey(_selectedDate);

              final hasBookings = guestsByDate.containsKey(key);

              final hasPending = pendingDates.contains(key);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      setState(() {
                        _selectedDate = date;
                        _selectedSection = 0;
                        _selectedFilter = 'all';
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFC8A45D)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            weekdayLabels[index],
                            style: TextStyle(
                              fontSize: 12,
                              color: selected ? Colors.black : null,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 17,
                              color: selected ? Colors.black : null,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: !hasBookings
                                  ? Colors.transparent
                                  : hasPending
                                  ? Colors.orange
                                  : selected
                                  ? Colors.black
                                  : const Color(0xFFC8A45D),
                            ),
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
  }) {
    final selected = _selectedService == value;

    const gold = Color(0xFFC8A45D);

    return ChoiceChip(
      selected: selected,
      onSelected: (_) {
        setState(() {
          _selectedService = value;
        });
      },
      avatar: Icon(icon, size: 18, color: selected ? Colors.black : gold),
      label: Text('$label  ${guests}p'),
      selectedColor: gold,
      labelStyle: TextStyle(
        color: selected ? Colors.black : null,
        fontWeight: FontWeight.bold,
      ),
      side: BorderSide(color: selected ? gold : const Color(0xFF62553E)),
    );
  }

  Widget _serviceSelector({
    required int allGuests,
    required int lunchGuests,
    required int dinnerGuests,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          _serviceButton(
            value: 'all',
            label: 'Tutti',
            icon: Icons.restaurant,
            guests: allGuests,
          ),
          const SizedBox(width: 8),
          _serviceButton(
            value: 'lunch',
            label: 'Pranzo',
            icon: Icons.wb_sunny_outlined,
            guests: lunchGuests,
          ),
          const SizedBox(width: 8),
          _serviceButton(
            value: 'dinner',
            label: 'Cena',
            icon: Icons.nightlight_outlined,
            guests: dinnerGuests,
          ),
        ],
      ),
    );
  }

  Widget _sectionButton({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final selected = _selectedSection == index;

    if (selected) {
      return FilledButton.icon(
        onPressed: () {
          setState(() {
            _selectedSection = index;
          });
        },
        icon: Icon(icon),
        label: Text(label),
      );
    }

    return OutlinedButton.icon(
      onPressed: () {
        setState(() {
          _selectedSection = index;
        });
      },
      icon: Icon(icon),
      label: Text(label),
    );
  }

  Widget _sectionSelector({required int activeCount, required int pastCount}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _sectionButton(
              index: 0,
              label: 'Attive ($activeCount)',
              icon: Icons.event_available_outlined,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _sectionButton(
              index: 1,
              label: 'Passate ($pastCount)',
              icon: Icons.history,
            ),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: filters.map((filter) {
          final selected = _selectedFilter == filter.$1;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _selectedFilter = filter.$1;
                });
              },
              avatar: Icon(filter.$3, size: 17),
              label: Text(filter.$2),
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
        Expanded(child: Text(text)),
      ],
    );
  }

  Widget _statusFlagMenu(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
    String currentStatus,
  ) {
    final color = _statusColor(currentStatus);

    return PopupMenuButton<String>(
      tooltip: 'Cambia stato',
      onSelected: (newStatus) {
        _requestStatusChange(document, newStatus);
      },
      itemBuilder: (context) {
        return _selectableStatuses.map((status) {
          return PopupMenuItem<String>(
            value: status,
            enabled: status != currentStatus,
            child: Row(
              children: [
                Icon(_statusIcon(status), color: _statusColor(status)),
                const SizedBox(width: 12),
                Expanded(child: Text(_statusLabel(status))),
                if (status == currentStatus) const Icon(Icons.check, size: 18),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_outlined, color: color),
            const SizedBox(width: 8),
            Text(
              'Cambia stato',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final booking = document.data();

    final firstName = booking['nome'] as String? ?? '';

    final lastName = booking['cognome'] as String? ?? '';

    final email = booking['email'] as String? ?? '';

    final phone = booking['telefono'] as String? ?? '';

    final service = booking['service'] as String? ?? '';

    final occasion = booking['occasion'] as String? ?? '';

    final notes = booking['notes'] as String? ?? '';

    final status = booking['status'] as String? ?? 'pending';

    final source = booking['source'] as String? ?? '';

    final guests = _readInteger(booking['guests']);

    final noShowCount = _readInteger(booking['customerNoShowCount']);

    final fullName = '$firstName $lastName'.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(18, 8, 10, 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          fullName.isEmpty ? 'Cliente' : fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 9,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline, size: 18),
                      const SizedBox(width: 3),
                      Text(
                        '${guests}p',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  _statusBadge(status),
                  if (noShowCount > 0)
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.deepPurpleAccent,
                      size: 21,
                    ),
                ],
              ),
              if (notes.trim().isNotEmpty) ...[
                const SizedBox(height: 9),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC8A45D).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFC8A45D).withValues(alpha: 0.55),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.sticky_note_2_outlined,
                        color: Color(0xFFC8A45D),
                        size: 18,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          notes,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        children: [
          const Divider(),
          const SizedBox(height: 8),
          _infoRow(
            icon: Icons.restaurant_outlined,
            text:
                '${_serviceLabel(service)} • '
                '$guests '
                '${guests == 1 ? 'persona' : 'persone'}',
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRow(icon: Icons.email_outlined, text: email),
          ],
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRow(icon: Icons.phone_outlined, text: phone),
          ],
          if (occasion.isNotEmpty && occasion != 'Nessuna') ...[
            const SizedBox(height: 8),
            _infoRow(icon: Icons.celebration_outlined, text: occasion),
          ],
          if (notes.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRow(icon: Icons.notes_outlined, text: notes),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusBadge(status),
              if (source == 'customer') _onlineBadge(),
            ],
          ),
          _noShowWarning(noShowCount),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: _statusFlagMenu(document, status),
          ),
        ],
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
                  ? 'Nessuna prenotazione attiva per questa data'
                  : 'Nessuna prenotazione passata per questa data',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
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
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFC8A45D),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  '$time — ${guests}p',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 17,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prenotazioni'),
        actions: [
          IconButton(
            tooltip: 'Vai a oggi',
            onPressed: () {
              setState(() {
                _selectedDate = DateTime.now();
                _selectedSection = 0;
                _selectedFilter = 'all';
              });
            },
            icon: const Icon(Icons.today_outlined),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('bookings').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
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
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allBookings = snapshot.data?.docs ?? [];

          final guestsByDate = <String, int>{};

          final pendingDates = <String>{};

          for (final document in allBookings) {
            final booking = document.data();

            final status = booking['status'] as String? ?? 'pending';

            final dateKey = booking['dateKey'] as String? ?? '';

            if (dateKey.isEmpty || !_countsForCapacity(status)) {
              continue;
            }

            if (status == 'pending') {
              pendingDates.add(dateKey);
            }

            guestsByDate.update(
              dateKey,
              (currentGuests) {
                return currentGuests + _readInteger(booking['guests']);
              },
              ifAbsent: () {
                return _readInteger(booking['guests']);
              },
            );
          }

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

          return Column(
            children: [
              _weeklyCalendar(
                guestsByDate: guestsByDate,
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
        },
      ),
    );
  }
}
