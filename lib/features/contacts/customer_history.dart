String customerIdentity(Map<String, dynamic> data, String bookingId) {
  var phone = (data['normalizedPhone'] ?? data['telefono'] ?? '')
      .toString()
      .replaceAll(RegExp(r'[^0-9]'), '');
  if (phone.startsWith('00')) phone = phone.substring(2);
  if (phone.length == 10 && phone.startsWith('3')) phone = '39$phone';
  if (phone.isNotEmpty) return 'phone_$phone';
  final email = (data['normalizedEmail'] ?? data['email'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  if (email.isNotEmpty) return 'email_$email';
  return 'booking_$bookingId';
}

class CustomerHistory {
  CustomerHistory(this.key, this.bookings) {
    bookings.sort(
      (a, b) => '${b['dateKey'] ?? ''} ${b['time'] ?? ''}'.compareTo(
        '${a['dateKey'] ?? ''} ${a['time'] ?? ''}',
      ),
    );
  }
  final String key;
  final List<Map<String, dynamic>> bookings;
  Map<String, dynamic> get latest => bookings.first;
  String get name {
    final value = '${latest['nome'] ?? ''} ${latest['cognome'] ?? ''}'.trim();
    return value.isEmpty ? 'Cliente senza nome' : value;
  }

  String get phone => (latest['telefono'] ?? '').toString();
  String get email => (latest['email'] ?? '').toString();
  static bool isVisit(Map<String, dynamic> booking) =>
      const ['arrived', 'released', 'completed'].contains(booking['status']);
  int get visits => bookings.where(isVisit).length;
  int get cancellations =>
      bookings.where((b) => b['status'] == 'cancelled').length;
  int get noShows => bookings.where((b) => b['status'] == 'no_show').length;
  String? get lastVisit =>
      bookings.where(isVisit).firstOrNull?['dateKey'] as String?;

  static List<CustomerHistory> group(
    Map<String, Map<String, dynamic>> records,
  ) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final entry in records.entries) {
      groups
          .putIfAbsent(customerIdentity(entry.value, entry.key), () => [])
          .add(entry.value);
    }
    return groups.entries.map((e) => CustomerHistory(e.key, e.value)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
}
