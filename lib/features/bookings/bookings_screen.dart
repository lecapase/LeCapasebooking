import 'package:flutter/material.dart';
import '../tables/tables_screen.dart';
import 'widgets/booking_form_dialog.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final List<Map<String, dynamic>> bookings = [
    {
      'nome': 'Mario Rossi',
      'persone': 4,
      'orario': '20:00',
      'tavolo': 'T12',
    },
    {
      'nome': 'John Smith',
      'persone': 2,
      'orario': '20:30',
      'tavolo': 'T5',
    },
  ];

  Future<void> _addBooking() async {
    final result = await showDialog(
      context: context,
      builder: (context) => const BookingFormDialog(),
    );

    if (result != null) {
      setState(() {
        bookings.add(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prenotazioni'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_restaurant),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TablesScreen(),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addBooking,
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final booking = bookings[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.person),
              ),
              title: Text(booking['nome']),
              subtitle: Text(
                '${booking['persone']} persone • Tavolo ${booking['tavolo']}',
              ),
              trailing: Text(
                booking['orario'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}