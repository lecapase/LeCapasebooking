import 'package:flutter/material.dart';
import 'features/bookings/bookings_screen.dart';

class LeCapaseApp extends StatelessWidget {
  const LeCapaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Le Capase Booking',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC8A45D),
          brightness: Brightness.dark,
        ),
      ),
      home: const BookingsScreen(),
    );
  }
}