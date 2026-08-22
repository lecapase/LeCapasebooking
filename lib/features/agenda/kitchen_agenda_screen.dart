import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class KitchenAgendaScreen extends StatefulWidget {
  const KitchenAgendaScreen({super.key});

  @override
  State<KitchenAgendaScreen> createState() => _KitchenAgendaScreenState();
}

class _KitchenAgendaScreenState extends State<KitchenAgendaScreen> {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  DateTime _selectedDate = DateTime.now();

  static const List<String> _weekdays = [
    'Lun',
    'Mar',
    'Mer',
    'Gio',
    'Ven',
    'Sab',
    'Dom',
  ];

  static const List<String> _months = [
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

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');

    final month = date.month.toString().padLeft(2, '0');

    final day = date.day.toString().padLeft(2, '0');

    return year + '-' + month + '-' + day;
  }

  Future<List<Map<String, dynamic>>> _loadAgenda(String dateKey) async {
    final result = await _functions.httpsCallable('getKitchenAgenda').call(
      <String, dynamic>{'dateKey': dateKey},
    );

    final data = result.data;

    if (data is! Map) {
      throw StateError('Risposta Agenda non valida.');
    }

    final rawBookings = data['bookings'];

    if (rawBookings is! List) {
      throw StateError('Elenco Agenda non valido.');
    }

    return rawBookings
        .whereType<Map>()
        .map((booking) => Map<String, dynamic>.from(booking))
        .toList();
  }

  DateTime _normalized(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  int _readInteger(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  String _fullDate(DateTime date) {
    return _weekdays[date.weekday - 1] +
        ' ' +
        date.day.toString() +
        ' ' +
        _months[date.month - 1] +
        ' ' +
        date.year.toString();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'booked':
        return 'Prenotata';
      case 'confirmed':
        return 'Confermata';
      case 'arrived':
        return 'Arrivata';
      case 'pending':
        return 'In attesa';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
      case 'booked':
        return Colors.green;
      case 'arrived':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _openCalendar() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      locale: const Locale('it', 'IT'),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDate = _normalized(selected);
    });
  }

  void _moveDay(int days) {
    setState(() {
      _selectedDate = _normalized(_selectedDate.add(Duration(days: days)));
    });
  }

  Widget _dayStrip() {
    final today = _normalized(DateTime.now());

    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: 14,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final date = today.add(Duration(days: index));

          final selected = _dateKey(date) == _dateKey(_selectedDate);

          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _selectedDate = date;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 60,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFC8A45D)
                    : const Color(0xFF191919),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? const Color(0xFFC8A45D) : Colors.white12,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekdays[date.weekday - 1],
                    style: TextStyle(
                      color: selected ? Colors.black : Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      color: selected ? Colors.black : Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _summary(List<Map<String, dynamic>> bookings) {
    final guests = bookings.fold<int>(
      0,
      (total, booking) => total + _readInteger(booking['guests']),
    );

    final lunchGuests = bookings
        .where((booking) => booking['service'] == 'lunch')
        .fold<int>(
          0,
          (total, booking) => total + _readInteger(booking['guests']),
        );

    final dinnerGuests = guests - lunchGuests;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: _summaryValue(
                'Prenotazioni',
                bookings.length,
                Icons.event_note_outlined,
              ),
            ),
            Expanded(
              child: _summaryValue('Coperti', guests, Icons.people_outline),
            ),
            Expanded(
              child: _summaryValue(
                'Pranzo',
                lunchGuests,
                Icons.light_mode_outlined,
              ),
            ),
            Expanded(
              child: _summaryValue(
                'Cena',
                dinnerGuests,
                Icons.nightlight_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryValue(String label, int value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFC8A45D)),
        const SizedBox(height: 5),
        Text(
          value.toString(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _serviceSection(
    String title,
    IconData icon,
    List<Map<String, dynamic>> bookings,
  ) {
    if (bookings.isEmpty) {
      return const SizedBox.shrink();
    }

    final guests = bookings.fold<int>(
      0,
      (total, booking) => total + _readInteger(booking['guests']),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFC8A45D), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                bookings.length.toString() +
                    ' pren. - ' +
                    guests.toString() +
                    ' coperti',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...bookings.map(_bookingCard),
        ],
      ),
    );
  }

  Widget _bookingCard(Map<String, dynamic> booking) {
    final firstName = (booking['nome'] ?? '').toString();

    final lastName = (booking['cognome'] ?? '').toString();

    final fullName = (firstName + ' ' + lastName).trim();

    final time = (booking['time'] ?? booking['orario'] ?? '').toString();

    final guests = _readInteger(booking['guests']);

    final notes = (booking['notes'] ?? '').toString();

    final occasion = (booking['occasion'] ?? '').toString();

    final status = (booking['status'] ?? 'pending').toString();

    final largeGroup = guests >= 8;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC8A45D),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    time.isEmpty ? '--:--' : time,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    fullName.isEmpty ? 'Prenotazione' : fullName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  guests.toString() + 'p',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(
                    Icons.circle,
                    size: 10,
                    color: _statusColor(status),
                  ),
                  label: Text(
                    _statusLabel(status),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                if (largeGroup)
                  const Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(Icons.groups_outlined, size: 15),
                    label: Text(
                      'Gruppo numeroso',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                if (occasion.isNotEmpty && occasion != 'Nessuna')
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.celebration_outlined, size: 15),
                    label: Text(occasion, style: const TextStyle(fontSize: 10)),
                  ),
              ],
            ),
            if (notes.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.sticky_note_2_outlined,
                      color: Colors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(notes, style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedKey = _dateKey(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          IconButton(
            tooltip: 'Calendario',
            onPressed: _openCalendar,
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _moveDay(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _openCalendar,
                    icon: const Icon(Icons.calendar_today, size: 17),
                    label: Text(
                      _fullDate(_selectedDate),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _moveDay(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          _dayStrip(),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadAgenda(selectedKey),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Impossibile caricare l\'agenda.'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final bookings = List<Map<String, dynamic>>.from(snapshot.data!)
                  ..sort((first, second) {
                    final firstTime = (first['time'] ?? first['orario'] ?? '')
                        .toString();

                    final secondTime =
                        (second['time'] ?? second['orario'] ?? '').toString();

                    return firstTime.compareTo(secondTime);
                  });

                final lunch = bookings
                    .where((booking) => booking['service'] == 'lunch')
                    .toList();

                final dinner = bookings
                    .where((booking) => booking['service'] == 'dinner')
                    .toList();

                if (bookings.isEmpty) {
                  return ListView(
                    children: [
                      _summary(bookings),
                      const SizedBox(height: 100),
                      const Icon(
                        Icons.event_available_outlined,
                        size: 54,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Nessuna prenotazione per questa data',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  );
                }

                return ListView(
                  padding: const EdgeInsets.only(bottom: 28),
                  children: [
                    _summary(bookings),
                    _serviceSection('Pranzo', Icons.light_mode_outlined, lunch),
                    _serviceSection('Cena', Icons.nightlight_outlined, dinner),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
