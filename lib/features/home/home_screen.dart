import 'package:flutter/material.dart';

import '../dashboard/dashboard_screen.dart';
import '../bookings/bookings_screen.dart';
import '../customer_booking/customer_booking_screen.dart';
import '../tables/tables_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState
    extends State<HomeScreen> {
  int selectedIndex = 0;

  final List<Widget> pages = [
    const DashboardScreen(),
    const BookingsScreen(),
    const CustomerBookingScreen(),
    const TablesScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[selectedIndex],

      bottomNavigationBar: Container(
        height: 80,

        decoration: const BoxDecoration(
          color: Color(0xFF0B0B0B),
          border: Border(
            top: BorderSide(
              color: Color(0xFFC8A45D),
              width: 0.5,
            ),
          ),
        ),

        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceAround,

          children: [
            _navItem(
              index: 0,
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'Home',
            ),

            _navItem(
              index: 1,
              icon:
                  Icons.calendar_month_outlined,
              activeIcon:
                  Icons.calendar_month,
              label: 'Prenotazioni',
            ),

            GestureDetector(
              onTap: () {
                setState(() {
                  selectedIndex = 2;
                });
              },
              child: Container(
                width: 65,
                height: 65,

                decoration:
                    const BoxDecoration(
                  color: Color(0xFFC8A45D),
                  shape: BoxShape.circle,
                ),

                child: const Icon(
                  Icons.add,
                  color: Colors.black,
                  size: 36,
                ),
              ),
            ),

            _navItem(
              index: 3,
              icon:
                  Icons.table_restaurant_outlined,
              activeIcon:
                  Icons.table_restaurant,
              label: 'Tavoli',
            ),

            _navItem(
              index: 4,
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings,
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final selected =
        selectedIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          selectedIndex = index;
        });
      },
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            selected
                ? activeIcon
                : icon,
            color: selected
                ? const Color(
                    0xFFC8A45D,
                  )
                : Colors.white70,
          ),

          const SizedBox(height: 4),

          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: selected
                  ? const Color(
                      0xFFC8A45D,
                    )
                  : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}