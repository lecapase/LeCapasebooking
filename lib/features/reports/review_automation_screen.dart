import 'package:flutter/material.dart';
import '../../services/callable_http_service.dart';

class ReviewAutomationScreen extends StatefulWidget {
  const ReviewAutomationScreen({super.key});
  @override
  State<ReviewAutomationScreen> createState() => _ReviewAutomationScreenState();
}

class _ReviewAutomationScreenState extends State<ReviewAutomationScreen> {
  final _link = TextEditingController();
  bool _loading = true,
      _failed = false,
      _saving = false,
      _enabled = false,
      _savedEnabled = false;
  List<dynamic> _events = [];
  List<dynamic> _batches = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final data = await CallableHttpService.call('getReviewAutomation');
      if (!mounted) return;
      _link.text = data['reviewUrl'] as String? ?? '';
      _enabled = _savedEnabled = data['enabled'] == true;
      _events = data['events'] as List? ?? [];
      _batches = data['batches'] as List? ?? [];
    } catch (_) {
      if (mounted) _failed = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_enabled && !_savedEnabled) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Attiva le richieste recensione'),
          content: const Text(
            'Alle 11:00 il sistema preparerà le richieste e avviserà gli amministratori. Le email partiranno solo dopo la vostra autorizzazione. Confermi?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Attiva'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }
    setState(() => _saving = true);
    try {
      await CallableHttpService.call('updateReviewAutomation', {
        'enabled': _enabled,
        'reviewUrl': _link.text.trim(),
      });
      if (mounted) {
        _savedEnabled = _enabled;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Impostazioni salvate.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is CallableHttpException
                  ? error.message
                  : 'Salvataggio non riuscito. Riprova.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _state(dynamic value) => switch (value) {
    'sent' => 'Accettata dal servizio email',
    'skipped' => 'Non inviata',
    'failed' => 'Errore di preparazione',
    'uncertain' => 'Esito da verificare',
    _ => 'Invio avviato: esito da verificare',
  };
  Future<void> _approve(Map<String, dynamic> batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Autorizza invio recensioni'),
        content: Text(
          'Autorizzi l’invio di ${batch['count']} richieste per le visite del ${batch['dateKey']}? '
          'Consensi e contatti verranno ricontrollati prima di ogni invio.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Autorizza invio'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await CallableHttpService.call('approveReviewBatch', {
        'batchId': batch['id'],
      });
      if (mounted) await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is CallableHttpException
                  ? error.message
                  : 'Autorizzazione non riuscita. Riprova.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _batchState(dynamic value) => switch (value) {
    'pending' => 'In attesa di autorizzazione',
    'approved' => 'Autorizzato',
    'sending' => 'Invio in corso',
    'completed' => 'Elaborazione conclusa',
    'empty' => 'Nessun destinatario idoneo',
    _ => 'Da verificare nel registro',
  };
  String _reason(dynamic value) => switch (value) {
    'missing_email' => 'Email mancante o non valida',
    'no_consent' => 'Consenso assente o revocato',
    'cooldown' => 'Invito già richiesto negli ultimi 90 giorni',
    'changed_before_send' => 'Invio sospeso o dati modificati prima dell’invio',
    'provider_result_unknown' =>
      'Nessun reinvio automatico per evitare duplicati',
    'preparation_failed' => 'Impossibile preparare il messaggio',
    _ => '',
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Richieste recensione'),
      actions: [
        IconButton(
          tooltip: 'Aggiorna',
          onPressed: _loading || _saving ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _failed
        ? Center(
            child: TextButton(
              onPressed: _load,
              child: const Text('Impossibile caricare. Riprova'),
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                _savedEnabled
                    ? 'Automazione attiva'
                    : 'Automazione disattivata',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Prepara richieste recensione ogni giorno'),
                subtitle: const Text(
                  'Ogni giorno alle 11:00, ora italiana. Salva per applicare la modifica.',
                ),
                value: _enabled,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _enabled = value),
              ),
              TextField(
                controller: _link,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Link Google “Chiedi recensioni”',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Salvataggio…' : 'Salva impostazioni'),
              ),
              const SizedBox(height: 20),
              Text(
                'Invii da autorizzare e recenti',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'Solo un amministratore può autorizzare. Basta l’approvazione di uno: il sistema impedisce invii duplicati.',
              ),
              if (_batches.isEmpty) const Text('Nessuna richiesta preparata.'),
              ..._batches.map((raw) {
                final batch = Map<String, dynamic>.from(raw as Map);
                return Card(
                  child: ExpansionTile(
                    title: Text(
                      '${batch['dateKey']} · ${batch['count']} email',
                    ),
                    subtitle: Text(_batchState(batch['state'])),
                    children: [
                      for (final recipient
                          in batch['recipients'] as List? ?? [])
                        ListTile(
                          title: Text((recipient as Map)['email'].toString()),
                        ),
                      if (batch['approvedBy'] != null)
                        ListTile(
                          title: const Text('Autorizzazione registrata'),
                          subtitle: Text(
                            '${batch['approvedBy']} · ${batch['approvedAt']}',
                          ),
                        ),
                      if (batch['state'] == 'pending')
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: FilledButton(
                            onPressed: _saving || !_savedEnabled
                                ? null
                                : () => _approve(batch),
                            child: const Text('Autorizza invio'),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
              const Text(
                'Destinatari: prenotazioni Liberata o Completata del giorno precedente. '
                'Solo email con consenso documentato e non revocato. Un invito per prenotazione, '
                'massimo uno per contatto ogni 90 giorni. Nessun recupero automatico delle date passate.',
              ),
              const SizedBox(height: 16),
              Text(
                'Anteprima email',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Grazie per aver scelto Le Capase! Se ti va, racconta la tua esperienza su Google. '
                    'La tua opinione ci aiuta a migliorare.\n\nLascia una recensione\n\nLe Capase\n\nDisiscriviti dalle email promozionali',
                  ),
                ),
              ),
              const Text(
                'Il messaggio è disponibile anche in inglese. La sospensione ferma i prossimi invii; '
                'non può ritirare email già affidate al servizio di invio.',
              ),
              const SizedBox(height: 20),
              Text(
                'Ultime 100 richieste',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (_events.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Nessuna richiesta registrata.'),
                ),
              ..._events.map((raw) {
                final event = Map<String, dynamic>.from(raw as Map);
                return Card(
                  child: ListTile(
                    title: Text(
                      '${event['email'] ?? ''} · ${_state(event['state'])}',
                    ),
                    subtitle: Text(
                      'Visita: ${event['dateKey'] ?? ''}\n${_reason(event['reason'])}',
                    ),
                  ),
                );
              }),
              const Text(
                'L’accettazione dell’email non prova la consegna, la lettura o la pubblicazione di una recensione.',
              ),
            ],
          ),
  );
}
