import 'package:flutter/material.dart';
import '../../models/booking.dart';
import '../../data/booking_repository.dart';
import 'widgets/booking_form_dialog.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  List<Booking> get bookings => BookingRepository.bookings;

  Future<void> _addBooking() async {
    final result = await showDialog(
      context: context,
      builder: (context) => const BookingFormDialog(),
    );

    if (result != null) {
      setState(() {
        BookingRepository.bookings.add(
          Booking(
            nome: result['nome'],
            telefono: result['telefono'],
            persone: result['persone'],
            data: result['data'],
            orario: result['orario'],
            note: result['note'],
            stato: 'Nuova',
          ),
        );
      });
    }
  }

  Color _statusColor(String stato) {
    switch (stato) {
      case 'Confermata':
        return Colors.green;
      case 'Arrivata':
        return Colors.blue;
      case 'Annullata':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prenotazioni'),
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
              leading: CircleAvatar(
                backgroundColor: _statusColor(booking.stato),
                child: const Icon(Icons.person),
              ),
              title: Text(booking.nome),
              subtitle: Text(
                '${booking.persone} persone • ${booking.data} • ${booking.orario}',
              ),
              trailing: Text(
                booking.stato,
                style: TextStyle(
                  color: _statusColor(booking.stato),
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(booking.nome),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Telefono: ${booking.telefono}'),
                        Text('Persone: ${booking.persone}'),
                        Text('Data: ${booking.data}'),
                        Text('Orario: ${booking.orario}'),
                        Text('Stato: ${booking.stato}'),
                        const SizedBox(height: 8),
                        Text('Note: ${booking.note}'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Chiudi'),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}