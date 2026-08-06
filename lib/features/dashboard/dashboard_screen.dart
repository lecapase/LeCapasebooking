import 'package:flutter/material.dart';
import '../bookings/bookings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Le Capase Booking'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Buonasera Antonio 👋',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            Row(
              children: [
                Expanded(
                  child: _card(
                    Icons.people,
                    '182',
                    'Coperti',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BookingsScreen(),
                        ),
                      );
                    },
                    child: _card(
                      Icons.calendar_month,
                      '73',
                      'Prenotazioni',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _card(
                    Icons.euro,
                    '€ 5.280',
                    'Incasso',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _card(
                    Icons.table_restaurant,
                    '18 / 24',
                    'Tavoli',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(IconData icon, String value, String title) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(title),
          ],
        ),
      ),
    );
  }
}