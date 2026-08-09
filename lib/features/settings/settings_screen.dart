import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 20),

          const Icon(
            Icons.settings,
            size: 80,
            color: Color(0xFFC9A86A),
          ),

          const SizedBox(height: 20),

          const Center(
            child: Text(
              'Le Capase Booking',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 8),

          const Center(
            child: Text(
              'Versione 1.0',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ),

          const SizedBox(height: 30),

          Card(
            child: ListTile(
              leading: const Icon(Icons.restaurant),
              title: const Text('Le Capase'),
              subtitle: const Text(
                'Ristorante • Pizzeria',
              ),
            ),
          ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Contatti'),
              subtitle: const Text(
                'Gestione prenotazioni',
              ),
            ),
          ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Informazioni App'),
              subtitle: const Text(
                'Sistema prenotazioni Le Capase',
              ),
            ),
          ),

          const SizedBox(height: 30),

          const Center(
            child: Text(
              '© Le Capase',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}