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

      // Compatibilità con vecchie prenotazioni.
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
            'Vuoi impostare la prenotazione di '
            '$customerName come Prenotata?';

        if (!_countsForCapacity(oldStatus)) {
          message +=
              '\n\nI coperti verranno reinseriti '
              'nella disponibilità.';
        }

        confirmLabel = 'Prenotata';
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
              'nella disponibilità e il cliente '
              'riceverà una nuova comunicazione.';
        }

        confirmLabel = 'Conferma';
        break;

      case 'cancelled':
        title = 'Annulla prenotazione';

        if (oldStatus == 'pending') {
          message =
              'Vuoi annullare la richiesta di '
              '$customerName?'
              '\n\nIl cliente riceverà una email '
              'che comunica che la richiesta '
              'non è stata accettata.';
        } else {
          message =
              'Vuoi annullare la prenotazione di '
              '$customerName?'
              '\n\nIl cliente riceverà automaticamente '
              'l’email di annullamento.';
        }

        confirmLabel = 'Annulla';
        break;

      case 'no_show':
        title = 'Segna come No-show';

        message =
            'Confermi che $customerName '
            'non si è presentato?'
            '\n\nL’episodio verrà registrato nello '
            'storico del cliente. Non verrà inviata '
            'alcuna email.';

        confirmLabel = 'No-show';
        break;

      case 'released':
        title = 'Segna come Liberato';

        message =
            'Confermi che il tavolo di $customerName '
            'è stato liberato?'
            '\n\nI coperti torneranno disponibili e '
            'la prenotazione sarà spostata tra '
            'le passate. Non verrà inviata alcuna email.';

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
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Indietro'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
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

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();

      final day = date.day.toString().padLeft(2, '0');

      final month = date.month.toString().padLeft(2, '0');

      return '$day/$month/${date.year}';
    }

    if (value is String && value.isNotEmpty) {
      final parts = value.split('-');

      if (parts.length == 3) {
        return '${parts[2]}/'
            '${parts[1]}/'
            '${parts[0]}';
      }

      return value;
    }

    return '-';
  }

  String _bookingDate(Map<String, dynamic> booking) {
    final date = _formatDate(booking['date']);

    if (date != '-') {
      return date;
    }

    return _formatDate(booking['dateKey']);
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

  Widget _infoRow({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Expanded(child: Text(text)),
      ],
    );
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            _statusLabel(status),
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _onlineBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.language_outlined, size: 15, color: Colors.amber),
          SizedBox(width: 5),
          Text(
            'Online',
            style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
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
            Icon(Icons.flag, color: color),
            const SizedBox(width: 8),
            Text(
              'Cambia stato',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: color),
          ],
        ),
      ),
    );
  }

  Widget _sectionSelector({required int activeCount, required int pastCount}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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

  Widget _buildBookingCard(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final booking = document.data();

    final nome = booking['nome'] as String? ?? '';

    final cognome = booking['cognome'] as String? ?? '';

    final email = booking['email'] as String? ?? '';

    final telefono = booking['telefono'] as String? ?? '';

    final time = booking['time'] as String? ?? '';

    final service = booking['service'] as String? ?? '';

    final guests = _readInteger(booking['guests']);

    final occasion = booking['occasion'] as String? ?? '';

    final notes = booking['notes'] as String? ?? '';

    final status = booking['status'] as String? ?? 'pending';

    final source = booking['source'] as String? ?? '';

    final noShowCount = _readInteger(booking['customerNoShowCount']);

    final fullName = '$nome $cognome'.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: _statusColor(status),
              child: Icon(_statusIcon(status), color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName.isEmpty ? 'Cliente' : fullName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _infoRow(
                    icon: Icons.calendar_today_outlined,
                    text:
                        '${_bookingDate(booking)} '
                        '• $time',
                  ),
                  const SizedBox(height: 5),
                  _infoRow(
                    icon: Icons.restaurant_outlined,
                    text:
                        '${_serviceLabel(service)} '
                        '• $guests '
                        '${guests == 1 ? 'persona' : 'persone'}',
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    _infoRow(icon: Icons.email_outlined, text: email),
                  ],
                  if (telefono.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    _infoRow(icon: Icons.phone_outlined, text: telefono),
                  ],
                  if (occasion.isNotEmpty && occasion != 'Nessuna') ...[
                    const SizedBox(height: 7),
                    Text('Occasione: $occasion'),
                  ],
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text('Note: $notes'),
                  ],
                  const SizedBox(height: 12),
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
                  const Divider(),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _statusFlagMenu(document, status),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortedBookings(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> bookings, {
    required bool descending,
  }) {
    final sorted = [...bookings];

    sorted.sort((first, second) {
      final firstData = first.data();

      final secondData = second.data();

      final firstDate = firstData['dateKey'] as String? ?? '';

      final secondDate = secondData['dateKey'] as String? ?? '';

      var comparison = firstDate.compareTo(secondDate);

      if (comparison == 0) {
        final firstTime = firstData['time'] as String? ?? '';

        final secondTime = secondData['time'] as String? ?? '';

        comparison = firstTime.compareTo(secondTime);
      }

      return descending ? -comparison : comparison;
    });

    return sorted;
  }

  Widget _emptySection() {
    return Center(
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
                ? 'Nessuna prenotazione attiva'
                : 'Nessuna prenotazione passata',
            style: const TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prenotazioni')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('bookings').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Errore nel caricamento '
                      'delle prenotazioni',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allBookings = snapshot.data?.docs ?? [];

          final activeBookings = _sortedBookings(
            allBookings.where((document) {
              final status = document.data()['status'] as String? ?? 'pending';

              return !_isPastStatus(status);
            }).toList(),
            descending: false,
          );

          final pastBookings = _sortedBookings(
            allBookings.where((document) {
              final status = document.data()['status'] as String? ?? 'pending';

              return _isPastStatus(status);
            }).toList(),
            descending: true,
          );

          final visibleBookings = _selectedSection == 0
              ? activeBookings
              : pastBookings;

          return Column(
            children: [
              _sectionSelector(
                activeCount: activeBookings.length,
                pastCount: pastBookings.length,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: visibleBookings.isEmpty
                    ? _emptySection()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: visibleBookings.length,
                        itemBuilder: (context, index) {
                          return _buildBookingCard(visibleBookings[index]);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
