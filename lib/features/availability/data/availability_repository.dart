import '../models/service_availability.dart';

class AvailabilityRepository {
  AvailabilityRepository._();

  // =========================================================
  // CONFIGURAZIONE BASE PRANZO
  // =========================================================

  static ServiceAvailability _createLunch({bool isOpen = true}) {
    return ServiceAvailability(
      id: 'lunch',
      name: 'Pranzo',
      isOpen: isOpen,
      startTime: '12:30',
      endTime: '14:15',
      maxOnlineGuests: 80,
      slotIntervalMinutes: 15,
    );
  }

  // =========================================================
  // CONFIGURAZIONE BASE CENA
  // =========================================================

  static ServiceAvailability _createDinner({bool isOpen = true}) {
    return ServiceAvailability(
      id: 'dinner',
      name: 'Cena',
      isOpen: isOpen,
      startTime: '19:00',
      endTime: '23:30',
      maxOnlineGuests: 80,
      slotIntervalMinutes: 15,
    );
  }

  // =========================================================
  // REGOLE SETTIMANALI PRECEDENTI
  // Conservate per mantenere compatibile il modulo clienti.
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
        slotIntervalMinutes: 15,
        blockedRanges: const [
          BlockedTimeRange(startTime: '20:15', endTime: '22:15'),
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
  // ECCEZIONI PRECEDENTI
  // =========================================================

  static List<DateAvailabilityException> exceptions = [];

  // =========================================================
  // NUOVI SERVIZI GESTITI
  // =========================================================

  static List<ManagedService> managedServices = [];

  // =========================================================
  // REGOLE SETTIMANALI
  // =========================================================

  static void replaceWeeklyDays(List<DayAvailability> newDays) {
    if (newDays.isEmpty) {
      return;
    }

    days = newDays;
  }

  static DayAvailability getDayForDate(DateTime date) {
    return days.firstWhere((day) => day.weekday == date.weekday);
  }

  // =========================================================
  // ECCEZIONI PRECEDENTI
  // =========================================================

  static void replaceExceptions(List<DateAvailabilityException> newExceptions) {
    exceptions = newExceptions;
  }

  static DateAvailabilityException? getException(DateTime date) {
    for (final exception in exceptions) {
      if (isSameDate(exception.date, date)) {
        return exception;
      }
    }

    return null;
  }

  static DateAvailabilityException createException(DateTime date) {
    final existing = getException(date);

    if (existing != null) {
      return existing;
    }

    final weeklyDay = getDayForDate(date);

    final exception = DateAvailabilityException(
      date: normalizeDate(date),
      lunch: weeklyDay.lunch.copy(),
      dinner: weeklyDay.dinner.copy(),
    );

    exceptions.add(exception);

    return exception;
  }

  static void removeException(DateTime date) {
    exceptions.removeWhere((exception) => isSameDate(exception.date, date));
  }

  // =========================================================
  // SOSTITUZIONE DEI NUOVI SERVIZI
  // =========================================================

  static void replaceManagedServices(List<ManagedService> services) {
    managedServices = services;
    sortManagedServices();
  }

  // =========================================================
  // AGGIUNTA O AGGIORNAMENTO DI UN SERVIZIO
  // =========================================================

  static void upsertManagedService(ManagedService service) {
    final index = managedServices.indexWhere((item) => item.id == service.id);

    if (index < 0) {
      managedServices.add(service);
    } else {
      managedServices[index] = service;
    }

    sortManagedServices();
  }

  // =========================================================
  // ELIMINAZIONE DI UN SERVIZIO
  // =========================================================

  static void removeManagedService(String serviceId) {
    managedServices.removeWhere((service) => service.id == serviceId);
  }

  // =========================================================
  // RICERCA DI UN SERVIZIO
  // =========================================================

  static ManagedService? getManagedServiceById(String serviceId) {
    for (final service in managedServices) {
      if (service.id == serviceId) {
        return service;
      }
    }

    return null;
  }

  // =========================================================
  // SERVIZI ANNUALI
  // =========================================================

  static List<ManagedService> get annualServices {
    final result = managedServices
        .where((service) => service.isAnnual)
        .toList();

    result.sort(_compareManagedServices);

    return result;
  }

  // =========================================================
  // SERVIZI PER DATE SPECIFICHE
  // =========================================================

  static List<ManagedService> get specificDateServices {
    final result = managedServices
        .where((service) => service.isSpecificDate)
        .toList();

    result.sort(_compareManagedServices);

    return result;
  }

  // =========================================================
  // SERVIZI SPECIFICI DI UNA DATA
  // =========================================================

  static List<ManagedService> getSpecificServicesForDate(DateTime date) {
    final result = managedServices
        .where(
          (service) =>
              service.isSpecificDate &&
              service.specificDate != null &&
              isSameDate(service.specificDate!, date),
        )
        .toList();

    result.sort(_compareManagedServices);

    return result;
  }

  // =========================================================
  // SERVIZI EFFETTIVI DI UNA DATA
  //
  // La data specifica sostituisce il servizio annuale
  // dello stesso tipo.
  // =========================================================

  static List<ManagedService> getEffectiveServicesForDate(DateTime date) {
    final annual = annualServices
        .where((service) => service.appliesToDate(date))
        .map((service) => service.copy())
        .toList();

    final specific = getSpecificServicesForDate(date)
        .where((service) => service.isActive)
        .map((service) => service.copy())
        .toList();

    for (final specificService in specific) {
      annual.removeWhere(
        (annualService) =>
            annualService.restaurantServiceType ==
            specificService.restaurantServiceType,
      );
    }

    return [...annual, ...specific]..sort(_compareManagedServices);
  }

  // =========================================================
  // CONTROLLO PRESENZA MODIFICA SPECIFICA
  // =========================================================

  static bool hasSpecificServiceForDate(DateTime date) {
    return managedServices.any(
      (service) =>
          service.isSpecificDate &&
          service.specificDate != null &&
          isSameDate(service.specificDate!, date),
    );
  }

  // =========================================================
  // CREA SERVIZIO ANNUALE VUOTO
  // =========================================================

  static ManagedService createEmptyAnnualService({
    RestaurantServiceType restaurantServiceType = RestaurantServiceType.dinner,
  }) {
    final now = DateTime.now();

    return ManagedService(
      id: createServiceId(),
      name: restaurantServiceType == RestaurantServiceType.lunch
          ? 'Pranzo'
          : restaurantServiceType == RestaurantServiceType.dinner
          ? 'Cena'
          : 'Nuovo servizio',
      scheduleType: ServiceScheduleType.annual,
      restaurantServiceType: restaurantServiceType,
      isActive: true,
      isOpen: true,
      startDate: DateTime(now.year, 1, 1),
      endDate: DateTime(now.year, 12, 31),
      weekdays: const [
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
        DateTime.saturday,
        DateTime.sunday,
      ],
      startTime: restaurantServiceType == RestaurantServiceType.lunch
          ? '12:30'
          : '19:00',
      endTime: restaurantServiceType == RestaurantServiceType.lunch
          ? '14:15'
          : '23:30',
      slotIntervalMinutes: 15,
      maxOnlineGuests: 80,
    );
  }

  // =========================================================
  // CREA SERVIZIO PER UNA DATA SPECIFICA
  // =========================================================

  static ManagedService createEmptySpecificDateService({
    required DateTime date,
    RestaurantServiceType restaurantServiceType = RestaurantServiceType.dinner,
  }) {
    return ManagedService(
      id: createServiceId(),
      name: restaurantServiceType == RestaurantServiceType.lunch
          ? 'Pranzo'
          : restaurantServiceType == RestaurantServiceType.dinner
          ? 'Cena'
          : 'Servizio speciale',
      scheduleType: ServiceScheduleType.specificDate,
      restaurantServiceType: restaurantServiceType,
      isActive: true,
      isOpen: true,
      specificDate: normalizeDate(date),
      weekdays: const [],
      startTime: restaurantServiceType == RestaurantServiceType.lunch
          ? '12:30'
          : '19:00',
      endTime: restaurantServiceType == RestaurantServiceType.lunch
          ? '14:15'
          : '23:30',
      slotIntervalMinutes: 15,
      maxOnlineGuests: 80,
    );
  }

  // =========================================================
  // CREA I SERVIZI INIZIALI
  // Utilizzato soltanto quando Firebase non contiene ancora
  // alcun servizio gestito.
  // =========================================================

  static List<ManagedService> createInitialManagedServices() {
    return [
      createEmptyAnnualService(
        restaurantServiceType: RestaurantServiceType.lunch,
      ),
      createEmptyAnnualService(
        restaurantServiceType: RestaurantServiceType.dinner,
      ),
    ];
  }

  // =========================================================
  // GENERAZIONE ID SERVIZIO
  // =========================================================

  static String createServiceId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  // =========================================================
  // ORDINAMENTO
  // =========================================================

  static void sortManagedServices() {
    managedServices.sort(_compareManagedServices);
  }

  static int _compareManagedServices(
    ManagedService first,
    ManagedService second,
  ) {
    if (first.isAnnual && second.isSpecificDate) {
      return -1;
    }

    if (first.isSpecificDate && second.isAnnual) {
      return 1;
    }

    if (first.isSpecificDate && second.isSpecificDate) {
      final firstDate = first.specificDate ?? DateTime(2100);

      final secondDate = second.specificDate ?? DateTime(2100);

      final dateComparison = firstDate.compareTo(secondDate);

      if (dateComparison != 0) {
        return dateComparison;
      }
    }

    return first.startTime.compareTo(second.startTime);
  }

  // =========================================================
  // UTILITÀ DATE
  // =========================================================

  static DateTime normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static bool isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
