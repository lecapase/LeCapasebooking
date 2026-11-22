/// Europe/Rome civil time, independent of the device timezone.
class RestaurantClock {
  RestaurantClock._();

  static DateTime _transition(int year, int month) {
    final lastDay = DateTime.utc(year, month + 1, 0, 1);
    return lastDay.subtract(Duration(days: lastDay.weekday % 7));
  }

  static bool _summer(DateTime utc) =>
      !utc.isBefore(_transition(utc.year, 3)) &&
      utc.isBefore(_transition(utc.year, 10));

  /// UTC container for civil fields: never interpreted as an actual instant.
  static DateTime civil(DateTime instant) {
    final utc = instant.toUtc();
    return utc.add(Duration(hours: _summer(utc) ? 2 : 1));
  }

  static DateTime? appointment(DateTime date, String time) {
    if (!RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(time)) return null;
    final parts = time.split(':').map(int.parse).toList();
    final wall = DateTime.utc(
      date.year,
      date.month,
      date.day,
      parts[0],
      parts[1],
    );
    final winter = wall.subtract(const Duration(hours: 1));
    final instant = winter.subtract(Duration(hours: _summer(winter) ? 1 : 0));
    // Reject the nonexistent hour at the spring clock change.
    return civil(instant) == wall ? instant : null;
  }

  static String formatCreatedAt(DateTime instant) {
    final date = civil(instant);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        'alle ${two(date.hour)}:${two(date.minute)}';
  }
}
