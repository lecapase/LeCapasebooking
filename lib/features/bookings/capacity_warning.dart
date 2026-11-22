class CapacityWarning implements Exception {
  const CapacityWarning(this.projectedGuests, this.limit);
  final int projectedGuests;
  final int limit;
}

void checkCapacityIncrease({
  required int currentGuests,
  required int increase,
  required int limit,
  int? approvedTotal,
}) {
  final projected = currentGuests + increase;
  if (increase > 0 &&
      projected > limit &&
      (approvedTotal == null || projected > approvedTotal)) {
    throw CapacityWarning(projected, limit);
  }
}
