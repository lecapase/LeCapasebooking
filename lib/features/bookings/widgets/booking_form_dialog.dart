import 'package:flutter/material.dart';

class BookingFormDialog extends StatefulWidget {
  const BookingFormDialog({super.key});

  @override
  State<BookingFormDialog> createState() => _BookingFormDialogState();
}

class _BookingFormDialogState extends State<BookingFormDialog> {
  final nomeController = TextEditingController();
  final personeController = TextEditingController();
  final tavoloController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuova Prenotazione'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(
                labelText: 'Nome cliente',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: personeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Numero persone',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tavoloController,
              decoration: const InputDecoration(
                labelText: 'Tavolo',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              {
                'nome': nomeController.text,
                'persone':
                    int.tryParse(personeController.text) ?? 0,
                'tavolo': tavoloController.text,
                'orario': '20:00',
              },
            );
          },
          child: const Text('Salva'),
        ),
      ],
    );
  }
}