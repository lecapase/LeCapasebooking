import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _selectedSection = 0;
  DateTime _selectedDate = DateTime.now();
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

  String _statusLabel(String status) {
    switch (status) {
      case 'booked':
        return 'Prenotata';
      case 'confirmed':
        return 'Confermata';
      case 'cancelled':
        return 'Annullata';
      case 'no_show':
        return 'No-show';
      case 'released':
        return 'Liberato';
      case 'pending':
        return 'In attesa di conferma';
      case 'arrived':
        return 'Arrivata';
      case 'completed':
        return 'Completata';
      case 'rejected':
        return 'Rifiutata';
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
      case 'cancelled':
        return Colors.red;
      case 'no_show':
        return Colors.deepPurple;
      case 'released':
        return Colors.teal;
      case 'pending':
        return Colors.orange;
      case 'arrived':
        return Colors.blue;
      case 'completed':
        return Colors.blueGrey;
      case 'rejected':
        return Colors.redAccent;
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
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'no_show':
        return Icons.person_off_outlined;
      case 'released':
        return Icons.table_restaurant_outlined;
      case 'pending':
        return Icons.schedule_outlined;
      case 'arrived':
        return Icons.login;
      case 'completed':
        return Icons.task_alt;
      case 'rejected':
        return Icons.block;
      default:
        return Icons.flag_outlined;
    }
  }

  bool _countsForCapacity(String status) {
    return status != 'cancelled' &&
        status != 'rejected' &&
        status != 'no_show' &&
        status != 'released' &&
        status != 'completed';
  }

  bool _isPastStatus(String status) {
    return _pastStatuses.contains(status);
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

  String _italianDate(DateTime date) {
    const weekdays = ['lun', 'mar', 'mer', 'gio', 'ven', 'sab', 'dom'];

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

    return '${weekdays[date.weekday - 1]} ${date.day} '
        '${months[date.month - 1]} ${date.year}';
  }

  String _monthLabel(DateTime date) {
    const months = [
      'Gennaio',
      'Febbraio',
      'Marzo',
      'Aprile',
      'Maggio',
      'Giugno',
      'Luglio',
      'Agosto',
      'Settembre',
      'Ottobre',
      'Novembre',
      'Dicembre',
    ];

    return '${months[date.month - 1]} ${date.year}';
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

  DateTime _firstDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month);
  }

  DateTime _previousMonth(DateTime date) {
    return DateTime(date.year, date.month - 1);
  }

  DateTime _nextMonth(DateTime date) {
    return DateTime(date.year, date.month + 1);
  }

  bool _sameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  Future<bool> _confirmStatusChange({
    required String oldStatus,
    required String newStatus,
    required String customerName,
  }) async {
    String title;
    String message;
    String confirmLabel;

    final color = _statusColor(newStatus);

    switch (newStatus) {
      case 'booked':
        title = 'Segna come prenotata';
        message =
            'Vuoi impostare la prenotazione di $customerName come Prenotata?';

        if (!_countsForCapacity(oldStatus)) {
          message +=
              '\n\nI coperti verranno reinseriti nella disponibilitÃƒÂ .';
        }

        confirmLabel = 'Prenotata';
        break;

      case 'confirmed':
        title = 'Conferma prenotazione';
        message = 'Vuoi confermare la prenotazione di $customerName?';

        if (oldStatus == 'pending') {
          message +=
              '\n\nIl cliente riceverÃƒÂ  automaticamente lÃ¢â‚¬â„¢email di conferma.';
        }

        if (!_countsForCapacity(oldStatus)) {
          message +=
              '\n\nI coperti verranno reinseriti nella disponibilitÃƒÂ  e il '
              'cliente riceverÃƒÂ  una nuova comunicazione.';
        }

        confirmLabel = 'Conferma';
        break;

      case 'cancelled':
        title = 'Annulla prenotazione';

        if (oldStatus == 'pending') {
          message =
              'Vuoi annullare la richiesta di $customerName?'
              '\n\nIl cliente riceverÃƒÂ  una email che comunica che la richiesta '
              'non ÃƒÂ¨ stata accettata.';
        } else {
          message =
              'Vuoi annullare la prenotazione di $customerName?'
              '\n\nIl cliente riceverÃƒÂ  automaticamente lÃ¢â‚¬â„¢email di annullamento.';
        }

        confirmLabel = 'Annulla';
        break;

      case 'no_show':
        title = 'Segna come No-show';
        message =
            'Confermi che $customerName non si ÃƒÂ¨ presentato?'
            '\n\nLÃ¢â‚¬â„¢episodio verrÃƒÂ  registrato nello storico del cliente. '
            'Non verrÃƒÂ  inviata alcuna email.';

        confirmLabel = 'No-show';
        break;

      case 'released':
        title = 'Segna come Liberato';
        message =
            'Confermi che il tavolo di $customerName ÃƒÂ¨ stato liberato?'
            '\n\nI coperti torneranno disponibili e la prenotazione sarÃƒÂ  '
            'spostata tra le passate. Non verrÃƒÂ  inviata alcuna email.';

        confirmLabel = 'Liberato';
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
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Indietro'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
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

    final nome = booking['nome'] as String? ?? '';
    final cognome = booking['cognome'] as String? ?? '';
    final fullName = '$nome $cognome'.trim();

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
            final counter = counterSnapshot.data();
            current = _readInteger(counter?['bookedGuests']);
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
        SnackBar(content: Text('Nuovo stato: ${_statusLabel(newStatus)}')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore durante lÃ¢â‚¬â„¢aggiornamento: $error'),
        ),
      );
    }
  }

  Future<void> _openCalendar(Map<String, int> guestsByDate) async {
    DateTime visibleMonth = _firstDayOfMonth(_selectedDate);
    DateTime temporaryDate = _selectedDate;

    final selectedDate = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final firstDay = _firstDayOfMonth(visibleMonth);
            final daysInMonth = DateTime(
              visibleMonth.year,
              visibleMonth.month + 1,
              0,
            ).day;

            final firstWeekday = firstDay.weekday - 1;
            final totalCells = firstWeekday + daysInMonth;
            final totalRows = (totalCells / 7).ceil();

            return AlertDialog(
              insetPadding: const EdgeInsets.all(14),
              contentPadding: const EdgeInsets.fromLTRB(14, 16, 14, 4),
              titlePadding: const EdgeInsets.fromLTRB(18, 16, 10, 0),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      _monthLabel(visibleMonth),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Mese precedente',
                    onPressed: () {
                      setDialogState(() {
                        visibleMonth = _previousMonth(visibleMonth);
                      });
                    },
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    tooltip: 'Mese successivo',
                    onPressed: () {
                      setDialogState(() {
                        visibleMonth = _nextMonth(visibleMonth);
                      });
                    },
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      children: [
                        _CalendarWeekday('L'),
                        _CalendarWeekday('M'),
                        _CalendarWeekday('M'),
                        _CalendarWeekday('G'),
                        _CalendarWeekday('V'),
                        _CalendarWeekday('S'),
                        _CalendarWeekday('D'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...List.generate(totalRows, (rowIndex) {
                      return Row(
                        children: List.generate(7, (columnIndex) {
                          final cellIndex = rowIndex * 7 + columnIndex;
                          final day = cellIndex - firstWeekday + 1;

                          if (day < 1 || day > daysInMonth) {
                            return const Expanded(child: SizedBox(height: 54));
                          }

                          final date = DateTime(
                            visibleMonth.year,
                            visibleMonth.month,
                            day,
                          );

                          final key = _dateKey(date);
                          final guests = guestsByDate[key] ?? 0;
                          final selected = _sameDate(date, temporaryDate);
                          final today = _sameDate(date, DateTime.now());

                          return Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                setDialogState(() {
                                  temporaryDate = date;
                                });
                              },
                              child: Container(
                                height: 54,
                                margin: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFFC8A45D)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                  border: today && !selected
                                      ? Border.all(
                                          color: const Color(0xFFC8A45D),
                                        )
                                      : null,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$day',
                                      style: TextStyle(
                                        color: selected ? Colors.black : null,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (guests > 0)
                                      Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? Colors.black.withValues(
                                                  alpha: 0.15,
                                                )
                                              : const Color(
                                                  0xFFC8A45D,
                                                ).withValues(alpha: 0.20),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          '${guests}p',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: selected
                                                ? Colors.black
                                                : const Color(0xFFC8A45D),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      );
                    }),
                    const SizedBox(height: 8),
                    Text(
                      'I numeri indicano i coperti prenotati.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('ANNULLA'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, temporaryDate),
                  child: const Text('SELEZIONA'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDate = selectedDate;
    });
  }

  void _changeDay(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
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
                  : 'Cliente con $noShowCount no-show precedenti',
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
        return _selectableStatuses
            .map(
              (status) => PopupMenuItem<String>(
                value: status,
                enabled: status != currentStatus,
                child: Row(
                  children: [
                    Icon(_statusIcon(status), color: _statusColor(status)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_statusLabel(status))),
                    if (status == currentStatus)
                      const Icon(Icons.check, size: 18),
                  ],
                ),
              ),
            )
            .toList();
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

  Widget _dateNavigator(Map<String, int> guestsByDate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF3A342B))),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Giorno precedente',
            onPressed: () => _changeDay(-1),
            icon: const Icon(Icons.chevron_left, size: 34),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _openCalendar(guestsByDate),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 21),
                    const SizedBox(width: 9),
                    Text(
                      _italianDate(_selectedDate),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Giorno successivo',
            onPressed: () => _changeDay(1),
            icon: const Icon(Icons.chevron_right, size: 34),
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
        final today = _dateKey(DateTime.now());
        final selectedDay = _dateKey(_selectedDate);

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

  Widget _buildBookingCard(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final booking = document.data();

    final nome = booking['nome'] as String? ?? '';
    final cognome = booking['cognome'] as String? ?? '';
    final email = booking['email'] as String? ?? '';
    final telefono = booking['telefono'] as String? ?? '';
    final service = booking['service'] as String? ?? '';
    final occasion = booking['occasion'] as String? ?? '';
    final notes = booking['notes'] as String? ?? '';
    final status = booking['status'] as String? ?? 'pending';
    final source = booking['source'] as String? ?? '';
    final guests = _readInteger(booking['guests']);
    final noShowCount = _readInteger(booking['customerNoShowCount']);

    final fullName = '$nome $cognome'.trim();

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
                '${_serviceLabel(service)} • $guests '
                '${guests == 1 ? 'persona' : 'persone'}',
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRow(icon: Icons.email_outlined, text: email),
          ],
          if (telefono.isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRow(icon: Icons.phone_outlined, text: telefono),
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
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC8A45D),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      time,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${group.length} '
                      '${group.length == 1 ? 'prenotazione' : 'prenotazioni'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.person_outline, size: 18),
                  const SizedBox(width: 3),
                  Text(
                    '${guests}p',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
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
                  'Errore nel caricamento delle prenotazioni:\n'
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

          for (final document in allBookings) {
            final booking = document.data();
            final status = booking['status'] as String? ?? 'pending';
            final dateKey = booking['dateKey'] as String? ?? '';

            if (dateKey.isEmpty || !_countsForCapacity(status)) {
              continue;
            }

            guestsByDate.update(dateKey, (currentGuests) {
              return currentGuests + _readInteger(booking['guests']);
            }, ifAbsent: () => _readInteger(booking['guests']));
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

            final correctService =
                _selectedService == 'all' ||
                booking['service'] == _selectedService;

            return correctService && _matchesQuickFilter(booking);
          }).toList();

          final allGuests = _guestTotal(activeForDate, 'all');
          final lunchGuests = _guestTotal(activeForDate, 'lunch');
          final dinnerGuests = _guestTotal(activeForDate, 'dinner');

          return Column(
            children: [
              _dateNavigator(guestsByDate),
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

class _CalendarWeekday extends StatelessWidget {
  final String label;

  const _CalendarWeekday(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFC8A45D),
          ),
        ),
      ),
    );
  }
}
