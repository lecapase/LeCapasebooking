import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ContactsMarketingScreen extends StatefulWidget {
  const ContactsMarketingScreen({super.key});

  @override
  State<ContactsMarketingScreen> createState() =>
      _ContactsMarketingScreenState();
}

class _ContactsMarketingScreenState extends State<ContactsMarketingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

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
      return '—';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contatti e Marketing')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
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
            Expanded(
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

                  if (contacts.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Nessun contatto con consenso marketing.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                    itemCount: contacts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final document = contacts[index];
                      final data = document.data();

                      final name = _fullName(data);
                      final email = (data['email'] as String? ?? '').trim();
                      final phone = (data['telefono'] as String? ?? '').trim();

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
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                    const Icon(Icons.phone_outlined, size: 17),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(phone)),
                                  ],
                                ),
                              if (phone.isNotEmpty && email.isNotEmpty)
                                const SizedBox(height: 7),
                              if (email.isNotEmpty)
                                Row(
                                  children: [
                                    const Icon(Icons.email_outlined, size: 17),
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
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
