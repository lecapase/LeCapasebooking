import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../contacts/booking_history_repository.dart';
import 'monthly_report.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});
  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  late final DateTime _currentMonth;
  late DateTime _month;
  late Future<Map<String, Map<String, dynamic>>> _history;
  static const _months = [
    'Gennaio',
    'Febbraio',
    'Marzo',
    'Aprile',
    'Maggio',
    'Giugno',
    'Luglio',
    'Agosto',
    'Settembre',
    'Ottobre',
    'Novembre',
    'Dicembre',
  ];
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
    _month = DateTime(now.year, now.month - 1);
    _history = loadBookingHistory();
  }

  String get _label => '${_months[_month.month - 1]} ${_month.year}';
  void _refresh() => setState(() => _history = loadBookingHistory());
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Report mensile'),
      actions: [
        IconButton(
          onPressed: _refresh,
          tooltip: 'Aggiorna dati',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Mese precedente',
              onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month - 1),
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                _label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Mese successivo',
              onPressed: _month.isBefore(_currentMonth)
                  ? () => setState(
                      () => _month = DateTime(_month.year, _month.month + 1),
                    )
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Expanded(
          child: FutureBuilder<Map<String, Map<String, dynamic>>>(
            future: _history,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Impossibile caricare il report.'),
                      TextButton(
                        onPressed: _refresh,
                        child: const Text('Riprova'),
                      ),
                    ],
                  ),
                );
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final report = MonthlyReport.fromBookings(snapshot.data!, _month);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_month == _currentMonth)
                    const Text('Mese in corso: dati provvisori.'),
                  if (report.bookings == 0)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Nessuna prenotazione nel mese selezionato.'),
                    ),
                  ...report.metrics.entries.map(
                    (entry) => Card(
                      child: ListTile(
                        title: Text(entry.key),
                        trailing: Text(
                          '${entry.value}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Le visite e i coperti serviti includono solo Arrivata, Liberata e Completata. '
                    'Le prenotazioni ancora aperte non sono visite effettive.\n\n'
                    'I clienti sono i titolari delle prenotazioni identificati da telefono o email, non tutti i commensali. '
                    'Nuovi: prima visita registrata nel mese. Già venuti: almeno una visita prima del mese. '
                    'Ogni cliente viene contato una sola volta. Le visite senza contatto sono separate.\n\n'
                    'Il report viene calcolato automaticamente all’apertura sui dati disponibili. '
                    'Aggiorna per includere nuove prenotazioni e correzioni agli stati.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Copia riepilogo'),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text:
                              'Le Capase — $_label\n${report.metrics.entries.map((e) => '${e.key}: ${e.value}').join('\n')}',
                        ),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Riepilogo copiato.')),
                        );
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
