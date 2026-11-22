import '../../../services/restaurant_clock.dart';

class BookingDatePolicy {
  BookingDatePolicy._();

  static const minimumNotice = Duration(minutes: 45);

  static bool isBookable(DateTime date, String time, {DateTime? now}) {
    final appointment = RestaurantClock.appointment(date, time);
    return appointment != null &&
        !appointment.isBefore(
          (now ?? DateTime.now()).toUtc().add(minimumNotice),
        );
  }

  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999, 999);
  }
}
