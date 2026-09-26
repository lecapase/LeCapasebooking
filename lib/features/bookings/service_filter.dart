/// Initial filter when opening a service date. Manual choices are kept by the UI.
String initialServiceFilter(DateTime selectedDate, DateTime now) {
  final isToday =
      selectedDate.year == now.year &&
      selectedDate.month == now.month &&
      selectedDate.day == now.day;
  if (!isToday) return 'all';
  return now.hour < 16 ? 'lunch' : 'dinner';
}
