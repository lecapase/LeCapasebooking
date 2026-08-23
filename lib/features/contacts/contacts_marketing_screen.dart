import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/callable_http_service.dart';

class ContactsMarketingScreen extends StatefulWidget {
  const ContactsMarketingScreen({super.key});

  @override
  State<ContactsMarketingScreen> createState() =>
      _ContactsMarketingScreenState();
}

class _ContactsMarketingScreenState extends State<ContactsMarketingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  final Set<String> _selectedIds = <String>{};

  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _fullName(Map<String, dynamic> data) {
    final nome = (data['nome'] as String? ?? '').trim();
    final cognome = (data['cognome'] as String? ?? '').trim();

    return '$nome $cognome'.trim();
  }

  bool _hasMarketingConsent(Map<String, dynamic> data) {
    return data['marketingEmailConsent'] == true ||
        data['marketingWhatsappConsent'] == true;
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (_search.isEmpty) {
      return true;
    }

    final query = _search.toLowerCase();

    final name = _fullName(data).toLowerCase();
    final email = (data['email'] as String? ?? '').toLowerCase();
    final phone = (data['telefono'] as String? ?? '').toLowerCase();

    return name.contains(query) ||
        email.contains(query) ||
        phone.contains(query);
  }

  String _formatTimestamp(dynamic value) {
    if (value is! Timestamp) {
      return '-';
    }

    final date = value.toDate();

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  Widget _consentBadge({required String label, required bool active}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? const Color(0x1AC8A45D)
            : Colors.grey.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? const Color(0xFFC8A45D) : Colors.grey.shade300,
        ),
      ),
      child: Text(
        active ? '$label ✓' : label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: active ? const Color(0xFF8A6B24) : Colors.grey.shade600,
        ),
      ),
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> contacts,
  ) {
    final visibleIds = contacts.map((document) => document.id).toSet();

    final allSelected =
        visibleIds.isNotEmpty && visibleIds.every(_selectedIds.contains);

    setState(() {
      if (allSelected) {
        _selectedIds.removeAll(visibleIds);
      } else {
        _selectedIds.addAll(visibleIds);
      }
    });
  }

  Future<void> _openCampaignPreview(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> contacts,
  ) async {
    final selectedContacts = contacts
        .where((document) => _selectedIds.contains(document.id))
        .toList();

    if (selectedContacts.isEmpty) {
      return;
    }

    final campaignNameController = TextEditingController();
    final messageController = TextEditingController();

    String channel = 'both';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            int whatsappRecipients = 0;
            int emailRecipients = 0;

            for (final document in selectedContacts) {
              final data = document.data();

              if (data['marketingWhatsappConsent'] == true) {
                whatsappRecipients++;
              }

              if (data['marketingEmailConsent'] == true) {
                emailRecipients++;
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Crea campagna',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${selectedContacts.length} clienti selezionati',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: campaignNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome campagna',
                        hintText: 'Es. Apertura Capà',
                        prefixIcon: Icon(Icons.campaign_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Canale',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: 'whatsapp',
                          icon: Icon(Icons.chat_outlined),
                          label: Text('WhatsApp'),
                        ),
                        ButtonSegment<String>(
                          value: 'email',
                          icon: Icon(Icons.email_outlined),
                          label: Text('Email'),
                        ),
                        ButtonSegment<String>(
                          value: 'both',
                          icon: Icon(Icons.all_inclusive),
                          label: Text('Entrambi'),
                        ),
                      ],
                      selected: <String>{channel},
                      onSelectionChanged: (selection) {
                        setSheetState(() {
                          channel = selection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F2E8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x66C8A45D)),
                      ),
                      child: DefaultTextStyle(
                        style: const TextStyle(
                          color: Color(0xFF2E2922),
                          fontSize: 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Destinatari disponibili',
                              style: TextStyle(
                                color: Color(0xFF2E2922),
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'WhatsApp: $whatsappRecipients',
                              style: const TextStyle(
                                color: Color(0xFF2E2922),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Email: $emailRecipients',
                              style: const TextStyle(
                                color: Color(0xFF2E2922),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Ogni cliente sarà utilizzato soltanto '
                              'sui canali per i quali ha dato consenso.',
                              style: TextStyle(
                                color: Color(0xFF514A3E),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: messageController,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Messaggio campagna',
                        hintText: 'Scrivi qui il testo della comunicazione...',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          if (selectedContacts.length != 1) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Per il test seleziona un solo cliente.',
                                ),
                              ),
                            );
                            return;
                          }

                          if (channel != 'email') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'WhatsApp marketing sarà attivato dopo '
                                  'l’approvazione del template dedicato.',
                                ),
                              ),
                            );
                            return;
                          }

                          final campaignName = campaignNameController.text
                              .trim();

                          final message = messageController.text.trim();

                          if (campaignName.length < 2) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Inserisci il nome della campagna.',
                                ),
                              ),
                            );
                            return;
                          }

                          if (message.length < 2) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Inserisci il messaggio della campagna.',
                                ),
                              ),
                            );
                            return;
                          }

                          final customerId = selectedContacts.first.id;

                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) {
                              return AlertDialog(
                                title: const Text('Conferma invio di test'),
                                content: const Text(
                                  'Stai per inviare realmente questa '
                                  'email al cliente selezionato.\n\n'
                                  'Vuoi procedere?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(false),
                                    child: const Text('ANNULLA'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(true),
                                    child: const Text('INVIA EMAIL'),
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirmed != true) {
                            return;
                          }

                          try {
                            final result = await CallableHttpService.call(
                              'sendMarketingCampaign',
                              <String, dynamic>{
                                'campaignName': campaignName,
                                'message': message,
                                'channel': 'email',
                                'customerIds': <String>[customerId],
                              },
                            );

                            if (!context.mounted) {
                              return;
                            }

                            Navigator.of(sheetContext).pop();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result['success'] == true
                                      ? 'Email marketing inviata '
                                            'correttamente.'
                                      : 'Invio non completato.',
                                ),
                              ),
                            );

                            setState(() {
                              _selectedIds.clear();
                            });
                          } catch (error) {
                            if (!context.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Errore invio: $error')),
                            );
                          }
                        },
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('INVIA EMAIL DI TEST'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Per ora è consentito un solo destinatario e solo tramite Email.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    campaignNameController.dispose();
    messageController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contatti e Marketing')),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore
              .collection('customer_profiles')
              .orderBy('updatedAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Errore nel caricamento dei contatti:\n'
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final documents = snapshot.data?.docs ?? [];

            final contacts = documents.where((document) {
              final data = document.data();

              return _hasMarketingConsent(data) && _matchesSearch(data);
            }).toList();

            final visibleIds = contacts.map((document) => document.id).toSet();

            final allSelected =
                visibleIds.isNotEmpty &&
                visibleIds.every(_selectedIds.contains);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _search = value.trim();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Cerca nome, email o telefono',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();

                                setState(() {
                                  _search = '';
                                });
                              },
                              icon: const Icon(Icons.close),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                if (contacts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 12, 6),
                    child: Row(
                      children: [
                        Checkbox(
                          value: allSelected,
                          onChanged: (_) => _toggleSelectAll(contacts),
                        ),
                        Expanded(
                          child: Text(
                            allSelected
                                ? 'Deseleziona tutti'
                                : 'Seleziona tutti',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${_selectedIds.length} selezionati',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: contacts.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Nessun contatto con consenso marketing.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            6,
                            16,
                            _selectedIds.isEmpty ? 24 : 100,
                          ),
                          itemCount: contacts.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final document = contacts[index];
                            final data = document.data();

                            final selected = _selectedIds.contains(document.id);

                            final name = _fullName(data);
                            final email = (data['email'] as String? ?? '')
                                .trim();
                            final phone = (data['telefono'] as String? ?? '')
                                .trim();

                            final emailConsent =
                                data['marketingEmailConsent'] == true;

                            final whatsappConsent =
                                data['marketingWhatsappConsent'] == true;

                            final lastConsent =
                                data['marketingLastConsentAt'] ??
                                data['marketingWhatsappConsentAt'] ??
                                data['marketingEmailConsentAt'];

                            return Card(
                              margin: EdgeInsets.zero,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _toggleSelection(document.id),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Checkbox(
                                        value: selected,
                                        onChanged: (_) =>
                                            _toggleSelection(document.id),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name.isEmpty ? 'Cliente' : name,
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            if (phone.isNotEmpty)
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.phone_outlined,
                                                    size: 17,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(child: Text(phone)),
                                                ],
                                              ),
                                            if (phone.isNotEmpty &&
                                                email.isNotEmpty)
                                              const SizedBox(height: 7),
                                            if (email.isNotEmpty)
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.email_outlined,
                                                    size: 17,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(child: Text(email)),
                                                ],
                                              ),
                                            const SizedBox(height: 12),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                _consentBadge(
                                                  label: 'WhatsApp',
                                                  active: whatsappConsent,
                                                ),
                                                _consentBadge(
                                                  label: 'Email',
                                                  active: emailConsent,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              'Ultimo consenso: '
                                              '${_formatTimestamp(lastConsent)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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
      ),
      bottomNavigationBar: _selectedIds.isEmpty
          ? null
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('customer_profiles')
                  .orderBy('updatedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                final documents = snapshot.data?.docs ?? [];

                final contacts = documents.where((document) {
                  final data = document.data();

                  return _hasMarketingConsent(data);
                }).toList();

                return SafeArea(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 12,
                          offset: const Offset(0, -2),
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
                      ],
                    ),
                    child: FilledButton.icon(
                      onPressed: () => _openCampaignPreview(contacts),
                      icon: const Icon(Icons.campaign_outlined),
                      label: Text(
                        'CREA CAMPAGNA '
                        '(${_selectedIds.length})',
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
