import '../../availability/data/firestore_availability_repository.dart';
import '../../availability/models/service_availability.dart';

class CustomerAvailabilityService {
  static Future<DayAvailability?> getAvailabilityForDate(
    DateTime date,
  ) async {
    final exception =
        await FirestoreAvailabilityRepository.loadException(date);

    if (exception != null) {
      return DayAvailability(
        weekday: date.weekday,
        name: _dayName(date.weekday),
        lunch: exception.lunch,
        dinner: exception.dinner,
      );
    }

    final weeklyDays =
        await FirestoreAvailabilityRepository.loadWeeklyDays();

    if (weeklyDays.isEmpty) {
      return null;
    }

    return weeklyDays.firstWhere(
      (day) => day.weekday == date.weekday,
    );
  }

  static bool isTimeBlocked({
    required ServiceAvailability service,
    required String time,
  }) {
    final timeMinutes = _toMinutes(time);

    for (final range in service.blockedRanges) {
      final start = _toMinutes(range.startTime);
      final end = _toMinutes(range.endTime);

      if (timeMinutes >= start && timeMinutes < end) {
        return true;
      }
    }

    return false;
  }

  static int _toMinutes(String value) {
    final parts = value.split(':');

    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    return hour * 60 + minute;
  }

  static String _dayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Lunedì';
      case DateTime.tuesday:
        return 'Martedì';
      case DateTime.wednesday:
        return 'Mercoledì';
      case DateTime.thursday:
        return 'Giovedì';
      case DateTime.friday:
        return 'Venerdì';
      case DateTime.saturday:
        return 'Sabato';
      case DateTime.sunday:
        return 'Domenica';
      default:
        return '';
    }
  }
}