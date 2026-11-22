class CalendarServiceTotals {
  int covers = 0;
  int reservations = 0;
  int pendingCovers = 0;
  int pendingReservations = 0;

  void add(Map<String, dynamic> booking) {
    final guests = booking['guests'];
    final count = guests is num && guests > 0 ? guests.toInt() : 0;
    if (booking['status'] == 'pending') {
      pendingCovers += count;
      pendingReservations++;
    } else if (const [
      'booked',
      'confirmed',
      'arrived',
      'released',
      'completed',
    ].contains(booking['status'])) {
      covers += count;
      reservations++;
    }
  }
}

class CalendarDayTotals {
  final lunch = CalendarServiceTotals();
  final dinner = CalendarServiceTotals();
}

Map<String, CalendarDayTotals> calendarTotals(
  Iterable<Map<String, dynamic>> bookings,
) {
  final result = <String, CalendarDayTotals>{};
  for (final booking in bookings) {
    final key = booking['dateKey'];
    final service = booking['service'];
    if (key is! String || (service != 'lunch' && service != 'dinner')) continue;
    final day = result.putIfAbsent(key, CalendarDayTotals.new);
    (service == 'lunch' ? day.lunch : day.dinner).add(booking);
  }
  return result;
}
