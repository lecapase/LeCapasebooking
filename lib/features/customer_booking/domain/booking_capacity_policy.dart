class BookingCapacityPolicy {
  BookingCapacityPolicy._();

  static int remainingGuests({
    required int maxGuests,
    required int bookedGuests,
  }) {
    final remaining = maxGuests - bookedGuests;
    return remaining > 0 ? remaining : 0;
  }

  static bool hasAvailability({
    required int maxGuests,
    required int bookedGuests,
  }) {
    return bookedGuests < maxGuests;
  }

  static bool hasCapacityForGuests({
    required int maxGuests,
    required int bookedGuests,
    required int requestedGuests,
  }) {
    return bookedGuests + requestedGuests <= maxGuests;
  }
}
