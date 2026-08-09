import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/booking.dart';

class BookingRepository {
  static List<Booking> bookings = [];

  static Future<void> loadBookings() async {
    final prefs = await SharedPreferences.getInstance();

    final String? data = prefs.getString('bookings');

    if (data == null) {
      bookings = [];
      print('CARICATE: 0');
      return;
    }

    final List decoded = jsonDecode(data);

    bookings = decoded
        .map((item) => Booking.fromJson(item))
        .toList();

    print('CARICATE: ${bookings.length}');
  }

  static Future<void> saveBookings() async {
    final prefs = await SharedPreferences.getInstance();

    final String data = jsonEncode(
      bookings.map((booking) => booking.toJson()).toList(),
    );

    await prefs.setString('bookings', data);

    print('SALVATE: ${bookings.length}');
  }

  static Future<void> clearBookings() async {
    final prefs = await SharedPreferences.getInstance();

    bookings.clear();

    await prefs.remove('bookings');

    print('PRENOTAZIONI AZZERATE');
  }
}