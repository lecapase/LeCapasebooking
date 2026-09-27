import '../contacts/customer_history.dart';

class MonthlyReport {
  MonthlyReport.fromBookings(
    Map<String, Map<String, dynamic>> records,
    DateTime month,
  ) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final previousVisitors = <String>{};
    final visitors = <String>{};
    for (final entry in records.entries) {
      final b = entry.value;
      final dateKey = b['dateKey']?.toString() ?? '';
      final date = DateTime.tryParse(dateKey);
      if (date == null || dateKey != _dateKey(date)) {
        invalidDates++;
        continue;
      }
      if (!date.isBefore(end)) continue;
      final identity = customerIdentity(b, entry.key);
      final identified = !identity.startsWith('booking_');
      final visited = CustomerHistory.isVisit(b);
      if (date.isBefore(start)) {
        if (visited && identified) previousVisitors.add(identity);
        continue;
      }
      bookings++;
      final guests = b['guests'];
      final parsed = guests is num ? guests.toInt() : int.tryParse('$guests');
      final covers = parsed != null && parsed > 0 ? parsed : 0;
      if (visited) {
        visits++;
        servedCovers += covers;
        if (covers == 0) visitsWithoutCovers++;
        if (identified) {
          visitors.add(identity);
        } else {
          unidentifiedVisits++;
        }
      } else if (b['status'] == 'cancelled') {
        cancellations++;
        cancelledCovers += covers;
      } else if (b['status'] == 'no_show') {
        noShows++;
        noShowCovers += covers;
      } else if (b['status'] == 'rejected') {
        rejected++;
      } else {
        unresolved++;
      }
    }
    returningCustomers = visitors.intersection(previousVisitors).length;
    newCustomers = visitors.length - returningCustomers;
  }
  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  int bookings = 0, visits = 0, servedCovers = 0;
  int cancellations = 0, cancelledCovers = 0, noShows = 0, noShowCovers = 0;
  int newCustomers = 0, returningCustomers = 0, unidentifiedVisits = 0;
  int unresolved = 0, rejected = 0, invalidDates = 0, visitsWithoutCovers = 0;
  Map<String, int> get metrics => {
    'Prenotazioni totali': bookings,
    'Visite effettuate': visits,
    'Coperti serviti': servedCovers,
    'Clienti nuovi': newCustomers,
    'Clienti già venuti': returningCustomers,
    'Cancellazioni': cancellations,
    'Coperti cancellati': cancelledCovers,
    'No-show': noShows,
    'Coperti no-show': noShowCovers,
    'Prenotazioni rifiutate': rejected,
    'Prenotazioni non consuntivate': unresolved,
    'Visite senza contatto': unidentifiedVisits,
    'Visite senza coperti validi': visitsWithoutCovers,
    'Date non valide nell’archivio': invalidDates,
  };
}
