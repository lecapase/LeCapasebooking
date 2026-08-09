import '../models/service_availability.dart';

class AvailabilityRepository {
  // =========================================================
  // CONFIGURAZIONE BASE PRANZO
  // =========================================================

  static ServiceAvailability _createLunch() {
    return ServiceAvailability(
      id: 'lunch',
      name: 'Pranzo',
      isOpen: true,
      startTime: '12:30',
      endTime: '14:15',
      maxOnlineGuests: 80,
    );
  }

  // =========================================================
  // CONFIGURAZIONE BASE CENA
  // =========================================================

  static ServiceAvailability _createDinner() {
    return ServiceAvailability(
      id: 'dinner',
      name: 'Cena',
      isOpen: true,
      startTime: '19:00',
      endTime: '23:30',
      maxOnlineGuests: 80,
    );
  }

  // =========================================================
  // REGOLE SETTIMANALI
  // =========================================================

  static List<DayAvailability> days = [
    DayAvailability(
      weekday: DateTime.monday,
      name: 'Lunedì',
      lunch: _createLunch(),
      dinner: _createDinner(),
    ),
    DayAvailability(
      weekday: DateTime.tuesday,
      name: 'Martedì',
      lunch: _createLunch(),
      dinner: _createDinner(),
    ),
    DayAvailability(
      weekday: DateTime.wednesday,
      name: 'Mercoledì',
      lunch: _createLunch(),
      dinner: _createDinner(),
    ),
    DayAvailability(
      weekday: DateTime.thursday,
      name: 'Giovedì',
      lunch: _createLunch(),
      dinner: _createDinner(),
    ),
    DayAvailability(
      weekday: DateTime.friday,
      name: 'Venerdì',
      lunch: _createLunch(),
      dinner: _createDinner(),
    ),
    DayAvailability(
      weekday: DateTime.saturday,
      name: 'Sabato',
      lunch: _createLunch(),
      dinner: ServiceAvailability(
        id: 'dinner',
        name: 'Cena',
        isOpen: true,
        startTime: '19:00',
        endTime: '23:30',
        maxOnlineGuests: 80,
        blockedRanges: const [
          BlockedTimeRange(
            startTime: '20:15',
            endTime: '22:15',
          ),
        ],
      ),
    ),
    DayAvailability(
      weekday: DateTime.sunday,
      name: 'Domenica',
      lunch: _createLunch(),
      dinner: _createDinner(),
    ),
  ];

  // =========================================================
  // ECCEZIONI PER DATA
  // =========================================================

  static List<DateAvailabilityException> exceptions = [];

  // =========================================================
  // SOSTITUISCE LE REGOLE SETTIMANALI CON QUELLE DI FIREBASE
  // =========================================================

  static void replaceWeeklyDays(
    List<DayAvailability> newDays,
  ) {
    if (newDays.isEmpty) {
      return;
    }

    days = newDays;
  }

  // =========================================================
  // SOSTITUISCE LE ECCEZIONI CON QUELLE DI FIREBASE
  // =========================================================

  static void replaceExceptions(
    List<DateAvailabilityException> newExceptions,
  ) {
    exceptions = newExceptions;
  }

  // =========================================================
  // TROVA LE REGOLE SETTIMANALI PER UNA DATA
  // =========================================================

  static DayAvailability getDayForDate(DateTime date) {
    return days.firstWhere(
      (day) => day.weekday == date.weekday,
    );
  }

  // =========================================================
  // CERCA ECCEZIONE PER UNA DATA
  // =========================================================

  static DateAvailabilityException? getException(DateTime date) {
    for (final exception in exceptions) {
      if (_isSameDate(exception.date, date)) {
        return exception;
      }
    }

    return null;
  }

  // =========================================================
  // CREA ECCEZIONE
  // =========================================================

  static DateAvailabilityException createException(DateTime date) {
    final existing = getException(date);

    if (existing != null) {
      return existing;
    }

    final weeklyDay = getDayForDate(date);

    final exception = DateAvailabilityException(
      date: DateTime(
        date.year,
        date.month,
        date.day,
      ),
      lunch: weeklyDay.lunch.copy(),
      dinner: weeklyDay.dinner.copy(),
    );

    exceptions.add(exception);

    return exception;
  }

  // =========================================================
  // ELIMINA ECCEZIONE
  // =========================================================

  static void removeException(DateTime date) {
    exceptions.removeWhere(
      (exception) => _isSameDate(
        exception.date,
        date,
      ),
    );
  }

  // =========================================================
  // CONFRONTA DATE
  // =========================================================

  static bool _isSameDate(
    DateTime a,
    DateTime b,
  ) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }
}