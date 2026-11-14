class BookingDatePolicy {
  BookingDatePolicy._();

  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999, 999);
  }
}
