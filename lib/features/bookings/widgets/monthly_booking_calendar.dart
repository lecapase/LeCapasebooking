import 'package:flutter/material.dart';
import '../calendar_totals.dart';

class MonthlyBookingCalendar extends StatelessWidget {
  const MonthlyBookingCalendar({
    super.key,
    required this.selectedDate,
    required this.bookings,
    required this.onMonth,
    required this.onDay,
  });
  final DateTime selectedDate;
  final Iterable<Map<String, dynamic>> bookings;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<DateTime> onDay;
  static const gold = Color(0xFFC8A45D);
  static const months = [
    'gennaio',
    'febbraio',
    'marzo',
    'aprile',
    'maggio',
    'giugno',
    'luglio',
    'agosto',
    'settembre',
    'ottobre',
    'novembre',
    'dicembre',
  ];
  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final first = DateTime(selectedDate.year, selectedDate.month);
    final next = DateTime(selectedDate.year, selectedDate.month + 1);
    final days = next.subtract(const Duration(days: 1)).day;
    final offset = first.weekday - 1;
    final prefix = _dateKey(first).substring(0, 7);
    final monthBookings = bookings
        .where((b) => (b['dateKey'] as String? ?? '').startsWith('$prefix-'))
        .toList();
    final totals = calendarTotals(monthBookings);
    final lunch = CalendarServiceTotals();
    final dinner = CalendarServiceTotals();
    for (final b in monthBookings) {
      if (b['service'] == 'lunch') lunch.add(b);
      if (b['service'] == 'dinner') dinner.add(b);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 740;
        final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Mese precedente',
                  onPressed: () =>
                      onMonth(DateTime(first.year, first.month - 1)),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${months[first.month - 1]} ${first.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Mese successivo',
                  onPressed: () => onMonth(next),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _summary('Pranzo', lunch),
                _summary('Cena', dinner),
                Chip(
                  label: Text(
                    'Totale mese: ${lunch.covers + dinner.covers} coperti',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final label in [
                  'Lun',
                  'Mar',
                  'Mer',
                  'Gio',
                  'Ven',
                  'Sab',
                  'Dom',
                ])
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: (compact ? 156.0 : 178.0) * scale,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: offset + days,
              itemBuilder: (context, index) {
                if (index < offset) return const SizedBox.shrink();
                final date = DateTime(
                  first.year,
                  first.month,
                  index - offset + 1,
                );
                final day = totals[_dateKey(date)] ?? CalendarDayTotals();
                final now = DateTime.now();
                final today = _dateKey(date) == _dateKey(now);
                final selected = _dateKey(date) == _dateKey(selectedDate);
                return Material(
                  color: selected
                      ? gold.withValues(alpha: 0.18)
                      : const Color(0xFF201F1C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: today || selected ? gold : const Color(0xFF3A342B),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onDay(date),
                    child: Padding(
                      padding: EdgeInsets.all(compact ? 3 : 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${date.day}${today && !compact ? ' · Oggi' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: today ? gold : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _service('Pranzo', day.lunch, compact),
                          const Divider(height: 12),
                          _service('Cena', day.dinner, compact),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              compact
                  ? 'P = pranzo · C = cena · cop. = coperti · pren. = prenotazioni'
                  : 'Coperti e prenotazioni separati per servizio.',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 6),
            const Text(
              'Arancione: richieste in attesa, escluse dai totali. I totali includono le visite concluse; escludono cancellazioni, rifiuti e no-show. Tocca un giorno per aprire le prenotazioni.',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        );
      },
    );
  }

  Widget _summary(String name, CalendarServiceTotals t) => Chip(
    label: Text(
      '$name: ${t.covers} coperti · ${t.reservations} prenotazioni'
      '${t.pendingReservations > 0 ? ' · ${t.pendingReservations} in attesa (${t.pendingCovers} cop.)' : ''}',
    ),
  );

  Widget _service(String name, CalendarServiceTotals t, bool compact) {
    final description =
        '$name: ${t.covers} coperti, ${t.reservations} prenotazioni. '
        'Da confermare: ${t.pendingReservations} richieste, ${t.pendingCovers} coperti.';
    return Tooltip(
      message: description,
      child: Semantics(
        label: description,
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              compact ? name[0] : name,
              style: const TextStyle(
                fontSize: 10,
                color: gold,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              compact ? '${t.covers}p' : '${t.covers} cop.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 11 : 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              compact ? '${t.reservations}pr' : '${t.reservations} pren.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Colors.white70),
            ),
            if (t.pendingReservations > 0)
              Text(
                compact
                    ? '! ${t.pendingReservations}'
                    : '${t.pendingReservations} da confermare',
                style: const TextStyle(fontSize: 9, color: Colors.orange),
              ),
          ],
        ),
      ),
    );
  }
}
