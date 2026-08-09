import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() =>
      _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // =========================================================
  // ETICHETTA STATO
  // =========================================================

  String _statusLabel(String status) {
    switch (status) {
      case 'confirmed':
        return 'Confermata';

      case 'arrived':
        return 'Arrivata';

      case 'cancelled':
        return 'Annullata';

      case 'rejected':
        return 'Rifiutata';

      case 'pending':
      default:
        return 'Da confermare';
    }
  }

  // =========================================================
  // COLORE STATO
  // =========================================================

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;

      case 'arrived':
        return Colors.blue;

      case 'cancelled':
        return Colors.red;

      case 'rejected':
        return Colors.redAccent;

      case 'pending':
      default:
        return Colors.orange;
    }
  }

  // =========================================================
  // PRENOTAZIONE CONTA NEI COPERTI?
  // =========================================================

  bool _countsForCapacity(String status) {
    return status != 'cancelled' &&
        status != 'rejected';
  }

  // =========================================================
  // CAMBIO STATO
  // =========================================================

  Future<void> _changeStatus(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data();

    final nome =
        data['nome'] as String? ?? '';

    final cognome =
        data['cognome'] as String? ?? '';

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            '$nome $cognome',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                ),
                title: const Text(
                  'Confermata',
                ),
                onTap: () async {
                  Navigator.pop(
                    dialogContext,
                  );

                  await _setStatus(
                    document.reference,
                    'confirmed',
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.login,
                  color: Colors.blue,
                ),
                title: const Text(
                  'Arrivata',
                ),
                onTap: () async {
                  Navigator.pop(
                    dialogContext,
                  );

                  await _setStatus(
                    document.reference,
                    'arrived',
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.cancel_outlined,
                  color: Colors.red,
                ),
                title: const Text(
                  'Annullata',
                ),
                onTap: () async {
                  Navigator.pop(
                    dialogContext,
                  );

                  await _setStatus(
                    document.reference,
                    'cancelled',
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.block,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Rifiutata',
                ),
                onTap: () async {
                  Navigator.pop(
                    dialogContext,
                  );

                  await _setStatus(
                    document.reference,
                    'rejected',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  // AGGIORNA STATO
  // =========================================================

  Future<void> _setStatus(
    DocumentReference<Map<String, dynamic>>
        bookingReference,
    String newStatus,
  ) async {
    try {
      await _firestore.runTransaction(
        (transaction) async {
          final bookingSnapshot =
              await transaction.get(
            bookingReference,
          );

          if (!bookingSnapshot.exists) {
            return;
          }

          final booking =
              bookingSnapshot.data();

          if (booking == null) {
            return;
          }

          final oldStatus =
              booking['status'] as String? ??
                  'pending';

          if (oldStatus == newStatus) {
            return;
          }

          final guests =
              booking['guests'] as int? ??
                  0;

          final dateKey =
              booking['dateKey'] as String? ??
                  '';

          final service =
              booking['service'] as String? ??
                  '';

          final oldCounts =
              _countsForCapacity(
            oldStatus,
          );

          final newCounts =
              _countsForCapacity(
            newStatus,
          );

          // =================================================
          // DA ATTIVA A ANNULLATA / RIFIUTATA
          // LIBERA I COPERTI
          // =================================================

          if (oldCounts &&
              !newCounts &&
              dateKey.isNotEmpty &&
              service.isNotEmpty) {
            final counterReference =
                _firestore
                    .collection(
                      'availability_counters',
                    )
                    .doc(
                      '${dateKey}_$service',
                    );

            final counterSnapshot =
                await transaction.get(
              counterReference,
            );

            if (counterSnapshot.exists) {
              final counter =
                  counterSnapshot.data();

              final current =
                  counter?['bookedGuests']
                          as int? ??
                      0;

              var updated =
                  current - guests;

              if (updated < 0) {
                updated = 0;
              }

              transaction.update(
                counterReference,
                {
                  'bookedGuests':
                      updated,
                  'updatedAt':
                      FieldValue
                          .serverTimestamp(),
                },
              );
            }
          }

          // =================================================
          // DA ANNULLATA / RIFIUTATA A ATTIVA
          // RIMETTE I COPERTI
          // =================================================

          if (!oldCounts &&
              newCounts &&
              dateKey.isNotEmpty &&
              service.isNotEmpty) {
            final counterReference =
                _firestore
                    .collection(
                      'availability_counters',
                    )
                    .doc(
                      '${dateKey}_$service',
                    );

            final counterSnapshot =
                await transaction.get(
              counterReference,
            );

            int current = 0;

            if (counterSnapshot.exists) {
              final counter =
                  counterSnapshot.data();

              current =
                  counter?['bookedGuests']
                          as int? ??
                      0;
            }

            transaction.set(
              counterReference,
              {
                'dateKey':
                    dateKey,
                'service':
                    service,
                'bookedGuests':
                    current + guests,
                'updatedAt':
                    FieldValue
                        .serverTimestamp(),
              },
              SetOptions(
                merge: true,
              ),
            );
          }

          // =================================================
          // AGGIORNA STATO PRENOTAZIONE
          // =================================================

          transaction.update(
            bookingReference,
            {
              'status':
                  newStatus,
              'updatedAt':
                  FieldValue.serverTimestamp(),
            },
          );
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Errore durante l’aggiornamento: $error',
          ),
        ),
      );
    }
  }

  // =========================================================
  // ELIMINA PRENOTAZIONE
  // =========================================================

  Future<void> _deleteBooking(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data();

    final nome =
        data['nome'] as String? ?? '';

    final cognome =
        data['cognome'] as String? ?? '';

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Elimina prenotazione',
          ),
          content: Text(
            'Vuoi eliminare $nome $cognome?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Annulla',
              ),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    Colors.red,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'Elimina',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _firestore.runTransaction(
        (transaction) async {
          final bookingSnapshot =
              await transaction.get(
            document.reference,
          );

          if (!bookingSnapshot.exists) {
            return;
          }

          final booking =
              bookingSnapshot.data();

          if (booking == null) {
            return;
          }

          final status =
              booking['status'] as String? ??
                  'pending';

          final guests =
              booking['guests'] as int? ??
                  0;

          final dateKey =
              booking['dateKey'] as String? ??
                  '';

          final service =
              booking['service'] as String? ??
                  '';

          // Se era una prenotazione attiva,
          // libera i coperti.
          if (_countsForCapacity(status) &&
              dateKey.isNotEmpty &&
              service.isNotEmpty) {
            final counterReference =
                _firestore
                    .collection(
                      'availability_counters',
                    )
                    .doc(
                      '${dateKey}_$service',
                    );

            final counterSnapshot =
                await transaction.get(
              counterReference,
            );

            if (counterSnapshot.exists) {
              final counter =
                  counterSnapshot.data();

              final current =
                  counter?['bookedGuests']
                          as int? ??
                      0;

              var updated =
                  current - guests;

              if (updated < 0) {
                updated = 0;
              }

              transaction.update(
                counterReference,
                {
                  'bookedGuests':
                      updated,
                  'updatedAt':
                      FieldValue
                          .serverTimestamp(),
                },
              );
            }
          }

          transaction.delete(
            document.reference,
          );
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Errore durante l’eliminazione: $error',
          ),
        ),
      );
    }
  }

  // =========================================================
  // FORMATO DATA
  // =========================================================

  String _formatDate(
    dynamic value,
  ) {
    if (value is Timestamp) {
      final date =
          value.toDate();

      final day =
          date.day.toString().padLeft(
                2,
                '0',
              );

      final month =
          date.month.toString().padLeft(
                2,
                '0',
              );

      return '$day/$month/${date.year}';
    }

    // Se per qualche vecchia prenotazione
    // la data non è Timestamp.
    if (value is String &&
        value.isNotEmpty) {
      return value;
    }

    return '-';
  }

  // =========================================================
  // SERVIZIO
  // =========================================================

  String _serviceLabel(
    String service,
  ) {
    switch (service) {
      case 'lunch':
        return 'Pranzo';

      case 'dinner':
        return 'Cena';

      default:
        return service;
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Prenotazioni',
        ),
      ),

      // =====================================================
      // FIRESTORE IN TEMPO REALE
      //
      // IMPORTANTE:
      // PER ORA NON USIAMO orderBy(createdAt).
      // LEGGIAMO TUTTI I DOCUMENTI DELLA COLLEZIONE.
      // =====================================================

      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('bookings')
            .snapshots(),

        builder: (
          context,
          snapshot,
        ) {
          // =================================================
          // ERRORE FIRESTORE
          // =================================================

          if (snapshot.hasError) {
            return Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.all(
                  24,
                ),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    const Text(
                      'Errore nel caricamento delle prenotazioni',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    Text(
                      '${snapshot.error}',
                      textAlign:
                          TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          // =================================================
          // CARICAMENTO
          // =================================================

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final bookings =
              snapshot.data?.docs ?? [];

          // =================================================
          // NESSUNA PRENOTAZIONE
          // =================================================

          if (bookings.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy_outlined,
                    size: 52,
                    color: Colors.grey,
                  ),

                  SizedBox(
                    height: 14,
                  ),

                  Text(
                    'Nessuna prenotazione',
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            );
          }

          // =================================================
          // LISTA PRENOTAZIONI
          // =================================================

          return ListView.builder(
            padding:
                const EdgeInsets.all(
              16,
            ),
            itemCount:
                bookings.length,
            itemBuilder: (
              context,
              index,
            ) {
              final document =
                  bookings[index];

              final booking =
                  document.data();

              final nome =
                  booking['nome']
                          as String? ??
                      '';

              final cognome =
                  booking['cognome']
                          as String? ??
                      '';

              final email =
                  booking['email']
                          as String? ??
                      '';

              final telefono =
                  booking['telefono']
                          as String? ??
                      '';

              final time =
                  booking['time']
                          as String? ??
                      '';

              final service =
                  booking['service']
                          as String? ??
                      '';

              final guests =
                  booking['guests']
                          as int? ??
                      0;

              final occasion =
                  booking['occasion']
                          as String? ??
                      '';

              final notes =
                  booking['notes']
                          as String? ??
                      '';

              final status =
                  booking['status']
                          as String? ??
                      'pending';

              final source =
                  booking['source']
                          as String? ??
                      '';

              // =============================================
              // CARD PRENOTAZIONE
              // =============================================

              return Card(
                margin:
                    const EdgeInsets.only(
                  bottom: 14,
                ),
                child: InkWell(
                  onTap: () {
                    _changeStatus(
                      document,
                    );
                  },
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      16,
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              _statusColor(
                            status,
                          ),
                          child:
                              const Icon(
                            Icons.person,
                            color:
                                Colors.white,
                          ),
                        ),

                        const SizedBox(
                          width: 14,
                        ),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                '$nome $cognome',
                                style:
                                    const TextStyle(
                                  fontSize: 18,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),

                              const SizedBox(
                                height: 8,
                              ),

                              Row(
                                children: [
                                  const Icon(
                                    Icons
                                        .calendar_today_outlined,
                                    size: 16,
                                  ),

                                  const SizedBox(
                                    width: 6,
                                  ),

                                  Expanded(
                                    child: Text(
                                      '${_formatDate(booking['date'])} • $time',
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(
                                height: 5,
                              ),

                              Row(
                                children: [
                                  const Icon(
                                    Icons
                                        .restaurant_outlined,
                                    size: 16,
                                  ),

                                  const SizedBox(
                                    width: 6,
                                  ),

                                  Text(
                                    '${_serviceLabel(service)} • '
                                    '$guests '
                                    '${guests == 1 ? 'persona' : 'persone'}',
                                  ),
                                ],
                              ),

                              if (email.isNotEmpty) ...[
                                const SizedBox(
                                  height: 5,
                                ),

                                Row(
                                  children: [
                                    const Icon(
                                      Icons
                                          .email_outlined,
                                      size: 16,
                                    ),

                                    const SizedBox(
                                      width: 6,
                                    ),

                                    Expanded(
                                      child: Text(
                                        email,
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              if (telefono.isNotEmpty) ...[
                                const SizedBox(
                                  height: 5,
                                ),

                                Row(
                                  children: [
                                    const Icon(
                                      Icons
                                          .phone_outlined,
                                      size: 16,
                                    ),

                                    const SizedBox(
                                      width: 6,
                                    ),

                                    Text(
                                      telefono,
                                    ),
                                  ],
                                ),
                              ],

                              if (occasion.isNotEmpty &&
                                  occasion !=
                                      'Nessuna') ...[
                                const SizedBox(
                                  height: 7,
                                ),

                                Text(
                                  'Occasione: $occasion',
                                ),
                              ],

                              if (notes.isNotEmpty) ...[
                                const SizedBox(
                                  height: 7,
                                ),

                                Text(
                                  'Note: $notes',
                                ),
                              ],

                              const SizedBox(
                                height: 12,
                              ),

                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  // =================================
                                  // STATO
                                  // =================================

                                  Container(
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal:
                                          10,
                                      vertical:
                                          5,
                                    ),
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          _statusColor(
                                        status,
                                      ).withValues(
                                        alpha:
                                            0.15,
                                      ),
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        20,
                                      ),
                                    ),
                                    child: Text(
                                      _statusLabel(
                                        status,
                                      ),
                                      style:
                                          TextStyle(
                                        color:
                                            _statusColor(
                                          status,
                                        ),
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                      ),
                                    ),
                                  ),

                                  // =================================
                                  // PRENOTAZIONE ONLINE
                                  // =================================

                                  if (source ==
                                      'customer')
                                    Container(
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                        horizontal:
                                            10,
                                        vertical:
                                            5,
                                      ),
                                      decoration:
                                          BoxDecoration(
                                        color: Colors
                                            .amber
                                            .withValues(
                                          alpha:
                                              0.15,
                                        ),
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          20,
                                        ),
                                      ),
                                      child:
                                          const Row(
                                        mainAxisSize:
                                            MainAxisSize
                                                .min,
                                        children: [
                                          Icon(
                                            Icons
                                                .language_outlined,
                                            size:
                                                15,
                                            color:
                                                Colors.amber,
                                          ),

                                          SizedBox(
                                            width:
                                                5,
                                          ),

                                          Text(
                                            'Online',
                                            style:
                                                TextStyle(
                                              color:
                                                  Colors.amber,
                                              fontWeight:
                                                  FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        IconButton(
                          tooltip:
                              'Elimina',
                          onPressed: () {
                            _deleteBooking(
                              document,
                            );
                          },
                          icon:
                              const Icon(
                            Icons
                                .delete_outline,
                            color:
                                Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}