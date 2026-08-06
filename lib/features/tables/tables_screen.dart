import 'package:flutter/material.dart';

class TablesScreen extends StatelessWidget {
  const TablesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tables = [
      {
        'name': 'T1',
        'status': 'free',
      },
      {
        'name': 'T2',
        'status': 'reserved',
        'cliente': 'Mario Rossi',
        'persone': '4',
        'orario': '20:00',
      },
      {
        'name': 'T3',
        'status': 'occupied',
      },
      {
        'name': 'T4',
        'status': 'free',
      },
      {
        'name': 'T5',
        'status': 'reserved',
        'cliente': 'John Smith',
        'persone': '2',
        'orario': '20:30',
      },
      {
        'name': 'T6',
        'status': 'free',
      },
      {
        'name': 'T7',
        'status': 'occupied',
      },
      {
        'name': 'T8',
        'status': 'free',
      },
      {
        'name': 'T9',
        'status': 'free',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Tavoli'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          itemCount: tables.length,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final table = tables[index];

            Color color;

            switch (table['status']) {
              case 'occupied':
                color = Colors.red;
                break;
              case 'reserved':
                color = Colors.orange;
                break;
              default:
                color = Colors.green;
            }

            return InkWell(
              onTap: () {
                if (table['status'] == 'reserved') {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text('Tavolo ${table['name']}'),
                      content: Text(
                        'Cliente: ${table['cliente']}\n'
                        'Persone: ${table['persone']}\n'
                        'Orario: ${table['orario']}',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Chiudi'),
                        ),
                      ],
                    ),
                  );
                }
              },
              child: Card(
                color: color.withOpacity(0.25),
                child: Center(
                  child: Text(
                    table['name'] as String,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}