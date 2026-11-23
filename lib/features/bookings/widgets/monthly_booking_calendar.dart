import 'package:flutter/material.dart';
import '../calendar_totals.dart';

class MonthlyBookingCalendar extends StatefulWidget {
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
  @override
  State<MonthlyBookingCalendar> createState() => _MonthlyBookingCalendarState();
}

class _MonthlyBookingCalendarState extends State<MonthlyBookingCalendar> {
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
  late DateTime selected = widget.selectedDate;
  @override
  void didUpdateWidget(covariant MonthlyBookingCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      selected = widget.selectedDate;
    }
  }

  String keyFor(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  String quantity(int n, String singular, String plural) =>
      '$n ${n == 1 ? singular : plural}';

  @override
  Widget build(BuildContext context) {
    final first = DateTime(widget.selectedDate.year, widget.selectedDate.month);
    final next = DateTime(first.year, first.month + 1);
    final offset = first.weekday - 1;
    final days = next.subtract(const Duration(days: 1)).day;
    final prefix = keyFor(first).substring(0, 7);
    final totals = calendarTotals(
      widget.bookings.where(
        (b) => (b['dateKey'] as String? ?? '').startsWith('$prefix-'),
      ),
    );
    final monthCovers = totals.values.fold<int>(
      0,
      (sum, d) => sum + d.lunch.covers + d.dinner.covers,
    );
    final day = totals[keyFor(selected)] ?? CalendarDayTotals();
    final pending = totals.values.any(
      (d) => d.lunch.pendingReservations + d.dinner.pendingReservations > 0,
    );
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Mese precedente',
              onPressed: () =>
                  widget.onMonth(DateTime(first.year, first.month - 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${months[first.month - 1]} ${first.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Mese successivo',
              onPressed: () => widget.onMonth(next),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Text(
          'Totale mese: $monthCovers coperti',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.white60),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            for (final label in ['L', 'M', 'M', 'G', 'V', 'S', 'D'])
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
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
            mainAxisExtent: 58 * scale,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: offset + days,
          itemBuilder: (context, index) {
            if (index < offset) return const SizedBox.shrink();
            final date = DateTime(first.year, first.month, index - offset + 1);
            final data = totals[keyFor(date)];
            final covers =
                (data?.lunch.covers ?? 0) + (data?.dinner.covers ?? 0);
            final waiting =
                (data?.lunch.pendingReservations ?? 0) +
                (data?.dinner.pendingReservations ?? 0);
            final active = keyFor(date) == keyFor(selected);
            final today = keyFor(date) == keyFor(DateTime.now());
            return Semantics(
              label:
                  '${date.day} ${months[first.month - 1]}, $covers coperti, $waiting richieste da confermare',
              selected: active,
              child: Material(
                color: active ? gold : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                  side: BorderSide(
                    color: today && !active ? gold : Colors.transparent,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => setState(() => selected = date),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: active
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: active ? Colors.black : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (covers > 0)
                        Text(
                          '$covers',
                          style: TextStyle(
                            fontSize: 11,
                            color: active ? Colors.black87 : gold,
                          ),
                        )
                      else
                        const SizedBox(height: 13),
                      if (waiting > 0)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          pending
              ? 'Numeri in oro: coperti · Pallino arancione: da confermare'
              : 'Numeri in oro: coperti',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Colors.white54),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF201F1C),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${selected.day} ${months[selected.month - 1]}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              service('Pranzo', Icons.wb_sunny_outlined, day.lunch),
              const Divider(height: 24, color: Color(0xFF3A342B)),
              service('Cena', Icons.nightlight_outlined, day.dinner),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => widget.onDay(selected),
                child: const Text('Apri prenotazioni'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget service(String title, IconData icon, CalendarServiceTotals t) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: gold),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              t.reservations == 0
                  ? 'Nessuna prenotazione'
                  : '${quantity(t.covers, 'coperto', 'coperti')} · ${quantity(t.reservations, 'prenotazione', 'prenotazioni')}',
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
            if (t.pendingReservations > 0)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  'Da confermare: ${quantity(t.pendingReservations, 'richiesta', 'richieste')} (${quantity(t.pendingCovers, 'coperto', 'coperti')})',
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
