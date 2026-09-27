import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'customer_history.dart';
import 'booking_history_repository.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key, this.initialCustomerKey});
  final String? initialCustomerKey;
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late Future<List<CustomerHistory>> _customers;
  String _search = '';
  @override
  void initState() {
    super.initState();
    _customers = _load();
  }

  Future<List<CustomerHistory>> _load() async {
    final records = await loadBookingHistory();
    return CustomerHistory.group(records);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Clienti'),
      actions: [
        IconButton(
          tooltip: 'Aggiorna',
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(() => _customers = _load()),
        ),
      ],
    ),
    body: FutureBuilder<List<CustomerHistory>>(
      future: _customers,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Impossibile caricare i clienti.'),
                TextButton(
                  onPressed: () => setState(() => _customers = _load()),
                  child: const Text('Riprova'),
                ),
              ],
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final customers = snapshot.data!;
        if (widget.initialCustomerKey != null) {
          final customer = customers
              .where((c) => c.key == widget.initialCustomerKey)
              .firstOrNull;
          return customer == null
              ? const Center(child: Text('Cliente non trovato.'))
              : _CustomerDetails(key: ValueKey(customer), customer: customer);
        }
        final visible = customers
            .where(
              (c) => '${c.name} ${c.phone} ${c.email}'.toLowerCase().contains(
                _search.toLowerCase(),
              ),
            )
            .toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Cerca nome, telefono o email',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _search = value),
              ),
            ),
            Text('${visible.length} clienti'),
            Expanded(
              child: visible.isEmpty
                  ? const Center(child: Text('Nessun cliente trovato.'))
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final customer = visible[index];
                        return ListTile(
                          title: Text(customer.name),
                          subtitle: Text(
                            '${customer.phone.isEmpty ? customer.email : customer.phone}\n'
                            '${customer.visits} visite · ${customer.noShows} no-show',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => Scaffold(
                                appBar: AppBar(title: Text(customer.name)),
                                body: _CustomerDetails(customer: customer),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    ),
  );
}

class _CustomerDetails extends StatefulWidget {
  const _CustomerDetails({super.key, required this.customer});
  final CustomerHistory customer;
  @override
  State<_CustomerDetails> createState() => _CustomerDetailsState();
}

class _CustomerDetailsState extends State<_CustomerDetails> {
  final _preferences = TextEditingController();
  bool _loading = true, _saving = false, _loadFailed = false;
  late final _reference = FirebaseFirestore.instance
      .collection('customers')
      .doc('crm_${base64Url.encode(utf8.encode(widget.customer.key))}');
  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final doc = await _reference.get();
      if (!mounted) return;
      _preferences.text = doc.data()?['preferences'] as String? ?? '';
    } catch (_) {
      if (mounted) _loadFailed = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _preferences.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _reference.set({
        'preferences': _preferences.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Preferenze salvate.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Salvataggio non riuscito. Riprova.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _date(String? date) {
    final parsed = DateTime.tryParse(date ?? '');
    return parsed == null
        ? '—'
        : '${parsed.day}/${parsed.month}/${parsed.year}';
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;
    const statuses = {
      'pending': 'Da confermare',
      'booked': 'Prenotata',
      'confirmed': 'Confermata',
      'arrived': 'Arrivata',
      'released': 'Liberata',
      'completed': 'Completata',
      'cancelled': 'Cancellata',
      'rejected': 'Rifiutata',
      'no_show': 'No show',
    };
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(customer.name, style: Theme.of(context).textTheme.headlineSmall),
        if (customer.phone.isNotEmpty) SelectableText(customer.phone),
        if (customer.email.isNotEmpty) SelectableText(customer.email),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            Chip(label: Text('${customer.visits} visite')),
            Chip(label: Text('${customer.cancellations} cancellazioni')),
            Chip(label: Text('${customer.noShows} no-show')),
          ],
        ),
        Text('Ultima visita: ${_date(customer.lastVisit)}'),
        const Text(
          'Visite conteggiate dagli stati Arrivata, Liberata e Completata.',
        ),
        const SizedBox(height: 20),
        if (_loading)
          const LinearProgressIndicator()
        else if (_loadFailed)
          TextButton(
            onPressed: _loadPreferences,
            child: const Text('Preferenze non disponibili. Riprova'),
          )
        else ...[
          TextField(
            controller: _preferences,
            maxLines: 3,
            maxLength: 2000,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Preferenze del cliente',
              hintText: 'Ad esempio: tavolo in terrazza',
              border: OutlineInputBorder(),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Salvataggio…' : 'Salva preferenze'),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'Storico prenotazioni (${customer.bookings.length})',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'Prenotazioni associate allo stesso telefono, oppure email se il telefono manca.',
        ),
        ...customer.bookings.map(
          (b) => Card(
            child: ListTile(
              title: Text(
                '${_date(b['dateKey'] as String?)} · ${b['time'] ?? ''} · ${b['guests'] ?? 0} coperti',
              ),
              subtitle: Text(
                '${b['service'] == 'lunch'
                    ? 'Pranzo'
                    : b['service'] == 'dinner'
                    ? 'Cena'
                    : b['service'] ?? ''}'
                ' · ${statuses[b['status']] ?? b['status'] ?? 'Stato non disponibile'}',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
