import '../models/booking.dart';

class BookingRepository {
  static final List<Booking> bookings = [
    Booking(
      nome: 'Mario Rossi',
      telefono: '3331234567',
      persone: 4,
      data: '07/08/2026',
      orario: '20:00',
      note: '',
      stato: 'Confermata',
    ),
    Booking(
      nome: 'John Smith',
      telefono: '3409876543',
      persone: 2,
      data: '07/08/2026',
      orario: '20:30',
      note: 'Tavolo tranquillo',
      stato: 'Nuova',
    ),
  ];
}