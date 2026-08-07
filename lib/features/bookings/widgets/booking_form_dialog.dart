import 'package:flutter/material.dart';

class BookingFormDialog extends StatefulWidget {
  const BookingFormDialog({super.key});

  @override
  State<BookingFormDialog> createState() => _BookingFormDialogState();
}

class _BookingFormDialogState extends State<BookingFormDialog> {
  final nomeController = TextEditingController();
  final telefonoController = TextEditingController();
  final personeController = TextEditingController();
  final dataController = TextEditingController();
  final orarioController = TextEditingController();
  final noteController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuova Prenotazione'),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
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
                controller: telefonoController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefono',
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
                controller: dataController,
                decoration: const InputDecoration(
                  labelText: 'Data',
                  hintText: '07/08/2026',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: orarioController,
                decoration: const InputDecoration(
                  labelText: 'Orario',
                  hintText: '20:30',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Note',
                ),
              ),
            ],
          ),
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
                'nome': nomeController.text.trim(),
                'telefono': telefonoController.text.trim(),
                'persone':
                    int.tryParse(personeController.text) ?? 0,
                'data': dataController.text.trim(),
                'orario': orarioController.text.trim(),
                'note': noteController.text.trim(),
              },
            );
          },
          child: const Text('Salva'),
        ),
      ],
    );
  }
}