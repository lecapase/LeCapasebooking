import 'package:flutter/material.dart';
import '../../services/callable_http_service.dart';

class CustomerConsentsPanel extends StatefulWidget {
  const CustomerConsentsPanel({super.key, required this.customerKey});
  final String customerKey;
  @override
  State<CustomerConsentsPanel> createState() => _CustomerConsentsPanelState();
}

class _CustomerConsentsPanelState extends State<CustomerConsentsPanel> {
  late Future<Map<String, dynamic>> _consents;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _consents = _load();
  }

  Future<Map<String, dynamic>> _load() => CallableHttpService.call(
    'getCustomerConsents',
    {'customerKey': widget.customerKey},
  );
  void _refresh() => setState(() => _consents = _load());
  String _date(dynamic value) {
    final d = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    return d == null
        ? 'Data non disponibile'
        : '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _source(dynamic value) => switch (value) {
    'customer_booking' => 'Modulo prenotazione',
    'staff_customer_request' => 'Richiesta registrata dal personale',
    'admin_removed' => 'Rimozione dalla lista marketing',
    'whatsapp_stop' => 'STOP WhatsApp',
    'email_unsubscribe' => 'Link disiscrizione email',
    _ => 'Provenienza non documentata',
  };
  Future<void> _revoke(String channel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registra disiscrizione'),
        content: Text(
          'Confermi la richiesta del cliente di non ricevere più promozioni via ${channel == 'email' ? 'email' : 'WhatsApp'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await CallableHttpService.call('revokeCustomerConsent', {
        'customerKey': widget.customerKey,
        'channel': channel,
      });
      if (mounted) _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disiscrizione non riuscita. Riprova.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.customerKey.startsWith('booking_')) {
      return const Text(
        'Consensi: nessun telefono o email associato al cliente.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Consensi e comunicazioni',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'Le autorizzazioni riguardano le promozioni. Le comunicazioni sulle prenotazioni restano separate.',
        ),
        FutureBuilder<Map<String, dynamic>>(
          future: _consents,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return TextButton(
                onPressed: _refresh,
                child: const Text('Consensi non disponibili. Riprova'),
              );
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            final data = snapshot.data!;
            final events = data['events'] as List? ?? [];
            return Column(
              children: [
                for (final channel in ['email', 'whatsapp'])
                  Builder(
                    builder: (context) {
                      final consent = Map<String, dynamic>.from(
                        data[channel] as Map,
                      );
                      final state = consent['state'];
                      final label = state == 'granted'
                          ? 'Autorizzato'
                          : state == 'revoked'
                          ? 'Revocato'
                          : 'Mai espresso / non documentato';
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${channel == 'email' ? 'Email' : 'WhatsApp'} · $label',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (consent['at'] != null)
                                Text(_date(consent['at'])),
                              if (consent['source'] != null)
                                Text(_source(consent['source'])),
                              if (consent['version'] != null)
                                Text('Versione testo: ${consent['version']}'),
                              if (state != 'revoked')
                                TextButton(
                                  onPressed: _saving
                                      ? null
                                      : () => _revoke(channel),
                                  child: const Text('Registra disiscrizione'),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ExpansionTile(
                  title: const Text('Storico consensi (ultimi 50 eventi)'),
                  children: events.isEmpty
                      ? [
                          const ListTile(
                            title: Text(
                              'Nessun evento registrato. Gli eventuali consensi precedenti sono indicati sopra.',
                            ),
                          ),
                        ]
                      : events.map((raw) {
                          final event = Map<String, dynamic>.from(raw as Map);
                          return ListTile(
                            title: Text(
                              '${event['channel'] == 'email' ? 'Email' : 'WhatsApp'} · ${event['state'] == 'granted' ? 'Autorizzato' : 'Revocato'}',
                            ),
                            subtitle: Text(
                              '${_date(event['at'])}\n${_source(event['source'])}${event['version'] == null ? '' : ' · testo ${event['version']}'}',
                            ),
                          );
                        }).toList(),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
