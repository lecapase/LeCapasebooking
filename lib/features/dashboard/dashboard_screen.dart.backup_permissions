import 'package:flutter/material.dart';

import '../../data/booking_repository.dart';
import '../bookings/bookings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() =>
      _DashboardScreenState();
}

class _DashboardScreenState
    extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final bookings = BookingRepository.bookings;

    int totalePersone = 0;
    int confermate = 0;
    int daConfermare = 0;

    for (final booking in bookings) {
      totalePersone += booking.persone;

      if (booking.stato == 'Confermata') {
        confermate++;
      }

      if (booking.stato == 'Da confermare') {
        daConfermare++;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              const SizedBox(height: 10),

              Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 90,
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                'Benvenuto Antonio',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w300,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Le Capase Booking Manager',
                style: TextStyle(
                  color: Color(0xFFC8A45D),
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 30),

              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      icon: Icons.calendar_month,
                      title: 'PRENOTAZIONI',
                      value:
                          bookings.length.toString(),
                    ),
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                    child: _statCard(
                      icon: Icons.people,
                      title: 'COPERTI',
                      value:
                          totalePersone.toString(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      icon: Icons.check_circle,
                      title: 'CONFERMATE',
                      value:
                          confermate.toString(),
                    ),
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                    child: _statCard(
                      icon: Icons.schedule,
                      title: 'IN ATTESA',
                      value:
                          daConfermare.toString(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const BookingsScreen(),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFC8A45D),
                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.warning_amber,
                        color: Colors.white,
                        size: 34,
                      ),
                      SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          'PRENOTAZIONI\nDA GESTIRE',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.black,
                        size: 34,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                'PRENOTAZIONI DI OGGI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),

              if (bookings.isEmpty)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFF161616),
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                    border: Border.all(
                      color:
                          const Color(0xFFC8A45D),
                    ),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.restaurant,
                        color:
                            Color(0xFFC8A45D),
                        size: 60,
                      ),
                      SizedBox(height: 15),
                      Text(
                        'Nessuna prenotazione',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),

              ...bookings.reversed.take(5).map(
                (booking) => Container(
                  margin:
                      const EdgeInsets.only(
                    bottom: 12,
                  ),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFF161616),
                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),
                    border: Border.all(
                      color:
                          const Color(0xFFC8A45D),
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          const Color(
                        0xFFC8A45D,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.black,
                      ),
                    ),
                    title: Text(
                      booking.nome,
                      style:
                          const TextStyle(
                        color: Colors.white,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${booking.persone} persone • ${booking.orario}',
                      style:
                          const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                    trailing: Text(
                      booking.stato,
                      style:
                          const TextStyle(
                        color:
                            Color(0xFFC8A45D),
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: const Color(0xFF161616),

        borderRadius:
            BorderRadius.circular(20),

        border: Border.all(
          color: const Color(0xFFC8A45D),
        ),
      ),

      child: Column(
        children: [
          Icon(
            icon,
            color: const Color(0xFFC8A45D),
            size: 34,
          ),

          const SizedBox(height: 10),

          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFC8A45D),
              fontSize: 34,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}