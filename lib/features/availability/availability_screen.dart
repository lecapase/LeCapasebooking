import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'data/availability_repository.dart';
import 'data/firestore_availability_repository.dart';
import 'models/service_availability.dart';

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  DateTime _selectedDate = AvailabilityRepository.normalizeDate(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  // =========================================================
  // CARICAMENTO
  // =========================================================

  Future<void> _loadServices() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final services =
          await FirestoreAvailabilityRepository.loadManagedServices();

      if (services.isEmpty) {
        final initialServices =
            AvailabilityRepository.createInitialManagedServices();

        AvailabilityRepository.replaceManagedServices(initialServices);

        await FirestoreAvailabilityRepository.saveAllManagedServices(
          initialServices,
        );
      } else {
        AvailabilityRepository.replaceManagedServices(services);
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossibile caricare i servizi.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // =========================================================
  // NUOVO SERVIZIO
  // =========================================================

  Future<void> _createNewService() async {
    final scheduleType = await showModalBottomSheet<ServiceScheduleType>(
      context: context,
      showDragHandle: true,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(8, 4, 8, 16),
                    child: Text(
                      'Nuovo servizio',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.autorenew_rounded),
                  ),
                  title: const Text(
                    'Servizio annuale',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Programmazione ricorrente per '
                    'determinati giorni della settimana.',
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 17,
                  ),
                  onTap: () {
                    Navigator.pop(
                      bottomSheetContext,
                      ServiceScheduleType.annual,
                    );
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.event_available_outlined),
                  ),
                  title: const Text(
                    'Servizio per una data specifica',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Apertura, chiusura o modifica '
                    'valida soltanto per una data.',
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 17,
                  ),
                  onTap: () {
                    Navigator.pop(
                      bottomSheetContext,
                      ServiceScheduleType.specificDate,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || scheduleType == null) {
      return;
    }

    final service = scheduleType == ServiceScheduleType.annual
        ? AvailabilityRepository.createEmptyAnnualService()
        : AvailabilityRepository.createEmptySpecificDateService(
            date: _selectedDate,
          );

    await _openServiceEditor(service);
  }

  // =========================================================
  // MODIFICA SERVIZIO
  // =========================================================

  Future<void> _openServiceEditor(ManagedService service) async {
    final editedService = await Navigator.of(context).push<ManagedService>(
      MaterialPageRoute(
        builder: (_) => ManagedServiceEditorScreen(service: service.copy()),
      ),
    );

    if (!mounted || editedService == null) {
      return;
    }

    await _saveService(editedService);
  }

  // =========================================================
  // SALVATAGGIO
  // =========================================================

  Future<void> _saveService(ManagedService service) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await FirestoreAvailabilityRepository.saveManagedService(service);

      AvailabilityRepository.upsertManagedService(service);

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Servizio salvato'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Salvataggio non riuscito.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // =========================================================
  // ATTIVA / DISATTIVA
  // =========================================================

  Future<void> _changeServiceActive(ManagedService service, bool value) async {
    final updatedService = service.copy()..isActive = value;

    await _saveService(updatedService);
  }

  // =========================================================
  // ELIMINAZIONE
  // =========================================================

  Future<void> _deleteService(ManagedService service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminare il servizio?'),
          content: Text(
            'Il servizio “${service.name}” '
            'verrà eliminato definitivamente.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Elimina'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await FirestoreAvailabilityRepository.deleteManagedService(service.id);

      AvailabilityRepository.removeManagedService(service.id);

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Servizio eliminato')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Eliminazione non riuscita.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final annualServices = AvailabilityRepository.annualServices;

    final specificServices = AvailabilityRepository.specificDateServices;

    final selectedDateServices =
        AvailabilityRepository.getEffectiveServicesForDate(_selectedDate);

    final hasSpecificService = AvailabilityRepository.hasSpecificServiceForDate(
      _selectedDate,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Indietro',
          onPressed: () {
            Navigator.of(context).maybePop();
          },
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('Gestione servizi'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: _isSaving ? null : _loadServices,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _createNewService,
        icon: const Icon(Icons.add),
        label: const Text('Nuovo servizio'),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadServices,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              children: [
                const Text(
                  'Calendario',
                  style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Seleziona una data per vedere '
                  'i servizi disponibili.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 18),

                // Calendario principale
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: CalendarDatePicker(
                      initialDate: _selectedDate,
                      firstDate: DateTime(DateTime.now().year - 1, 1, 1),
                      lastDate: DateTime(DateTime.now().year + 3, 12, 31),
                      onDateChanged: (date) {
                        setState(() {
                          _selectedDate = AvailabilityRepository.normalizeDate(
                            date,
                          );
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Riepilogo data selezionata
                _SelectedDateCard(
                  date: _selectedDate,
                  services: selectedDateServices,
                  hasSpecificService: hasSpecificService,
                  onCreateSpecificService:
                      _createSpecificServiceForSelectedDate,
                  onEditService: _openServiceEditor,
                ),

                const SizedBox(height: 34),

                // Servizi annuali salvati
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Servizi annuali',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${annualServices.length}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Programmazione ordinaria '
                  'del ristorante.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),

                if (annualServices.isEmpty)
                  const _EmptyServicesCard(
                    text: 'Nessun servizio annuale creato.',
                  ),

                ...annualServices.map(
                  (service) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ManagedServiceCard(
                      service: service,
                      onEdit: () {
                        _openServiceEditor(service);
                      },
                      onDelete: () {
                        _deleteService(service);
                      },
                      onActiveChanged: (value) {
                        _changeServiceActive(service, value);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Servizi per date specifiche
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Date specifiche',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${specificServices.length}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Aperture, chiusure e modifiche '
                  'straordinarie.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),

                if (specificServices.isEmpty)
                  const _EmptyServicesCard(
                    text: 'Nessuna data specifica creata.',
                  ),

                ...specificServices.map(
                  (service) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ManagedServiceCard(
                      service: service,
                      onEdit: () {
                        _openServiceEditor(service);
                      },
                      onDelete: () {
                        _deleteService(service);
                      },
                      onActiveChanged: (value) {
                        _changeServiceActive(service, value);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_isSaving)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.18),
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _createSpecificServiceForSelectedDate() async {
    final service = AvailabilityRepository.createEmptySpecificDateService(
      date: _selectedDate,
    );

    await _openServiceEditor(service);
  }
}

// ===========================================================
// RIEPILOGO DATA SELEZIONATA
// ===========================================================

class _SelectedDateCard extends StatelessWidget {
  const _SelectedDateCard({
    required this.date,
    required this.services,
    required this.hasSpecificService,
    required this.onCreateSpecificService,
    required this.onEditService,
  });

  final DateTime date;
  final List<ManagedService> services;
  final bool hasSpecificService;
  final VoidCallback onCreateSpecificService;
  final ValueChanged<ManagedService> onEditService;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: hasSpecificService
          ? Colors.orange.withValues(alpha: 0.10)
          : Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: hasSpecificService
              ? Colors.orange.withValues(alpha: 0.45)
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatDate(date),
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (hasSpecificService)
                  const Chip(
                    avatar: Icon(Icons.star_rounded, size: 17),
                    label: Text('Data modificata'),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (services.isEmpty)
              const Text(
                'Nessun servizio disponibile.',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),

            ...services.map(
              (service) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: service.isOpen
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.red.withValues(alpha: 0.15),
                  child: Icon(
                    service.isOpen
                        ? Icons.restaurant_rounded
                        : Icons.event_busy_rounded,
                    color: service.isOpen ? Colors.green : Colors.red,
                  ),
                ),
                title: Text(
                  service.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  service.isOpen
                      ? '${service.startTime} – '
                            '${service.endTime} · '
                            '${service.maxOnlineGuests} coperti'
                      : 'Servizio chiuso',
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  onEditService(service);
                },
              ),
            ),

            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCreateSpecificService,
                icon: const Icon(Icons.add),
                label: const Text('Crea servizio per questa data'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    const weekdayNames = [
      'Lunedì',
      'Martedì',
      'Mercoledì',
      'Giovedì',
      'Venerdì',
      'Sabato',
      'Domenica',
    ];

    const monthNames = [
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

    return '${weekdayNames[date.weekday - 1]} '
        '${date.day} ${monthNames[date.month - 1]} '
        '${date.year}';
  }
}

// ===========================================================
// CARD SERVIZIO SALVATO
// ===========================================================

class _ManagedServiceCard extends StatelessWidget {
  const _ManagedServiceCard({
    required this.service,
    required this.onEdit,
    required this.onDelete,
    required this.onActiveChanged,
  });

  final ManagedService service;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    service.name,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(value: service.isActive, onChanged: onActiveChanged),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    }

                    if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Modifica')),
                    PopupMenuItem(value: 'delete', child: Text('Elimina')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              service.isAnnual
                  ? _annualDescription(service)
                  : _specificDescription(service),
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: service.isOpen
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                  text: service.isOpen ? 'Aperto' : 'Chiuso',
                ),
                _InfoChip(
                  icon: Icons.schedule,
                  text: service.isOpen
                      ? '${service.startTime} – '
                            '${service.endTime}'
                      : 'Nessun orario',
                ),
                _InfoChip(
                  icon: Icons.groups_outlined,
                  text: '${service.maxOnlineGuests} coperti',
                ),
                _InfoChip(
                  icon: Icons.timer_outlined,
                  text: 'Ogni ${service.slotIntervalMinutes} min',
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Modifica servizio'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _annualDescription(ManagedService service) {
    if (service.weekdays.isEmpty) {
      return 'Nessun giorno selezionato';
    }

    const shortNames = {
      DateTime.monday: 'Lun',
      DateTime.tuesday: 'Mar',
      DateTime.wednesday: 'Mer',
      DateTime.thursday: 'Gio',
      DateTime.friday: 'Ven',
      DateTime.saturday: 'Sab',
      DateTime.sunday: 'Dom',
    };

    final days = List<int>.from(service.weekdays)..sort();

    final text = days.map((day) => shortNames[day] ?? '').join(', ');

    return 'Servizio annuale · $text';
  }

  static String _specificDescription(ManagedService service) {
    final date = service.specificDate;

    if (date == null) {
      return 'Data non impostata';
    }

    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    return 'Data specifica · '
        '$day/$month/${date.year}';
  }
}

// ===========================================================
// CHIP INFORMAZIONE
// ===========================================================

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 17), label: Text(text));
  }
}

// ===========================================================
// STATO VUOTO
// ===========================================================

class _EmptyServicesCard extends StatelessWidget {
  const _EmptyServicesCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(text, style: const TextStyle(color: Colors.grey)),
    );
  }
}

// ===========================================================
// SCHERMATA CREAZIONE / MODIFICA SERVIZIO
// ===========================================================

class ManagedServiceEditorScreen extends StatefulWidget {
  const ManagedServiceEditorScreen({super.key, required this.service});

  final ManagedService service;

  @override
  State<ManagedServiceEditorScreen> createState() =>
      _ManagedServiceEditorScreenState();
}

class _ManagedServiceEditorScreenState
    extends State<ManagedServiceEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;

  late final TextEditingController _guestsController;

  late ManagedService _service;

  @override
  void initState() {
    super.initState();

    _service = widget.service.copy();

    _nameController = TextEditingController(text: _service.name);

    _guestsController = TextEditingController(
      text: '${_service.maxOnlineGuests}',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _guestsController.dispose();
    super.dispose();
  }

  // =========================================================
  // SALVA
  // =========================================================

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_service.isAnnual && _service.weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleziona almeno un giorno.'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    _service.name = _nameController.text.trim();

    _service.maxOnlineGuests = int.parse(_guestsController.text.trim());

    Navigator.pop(context, _service);
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Indietro',
          onPressed: () {
            Navigator.of(context).maybePop();
          },
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: Text(
          _service.isAnnual ? 'Servizio annuale' : 'Servizio per data',
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'SALVA',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 50),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome del servizio',
                hintText: 'Es. Cena, Pranzo, Pasquetta',
                prefixIcon: Icon(Icons.restaurant_menu_rounded),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Inserisci il nome del servizio';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<RestaurantServiceType>(
              initialValue: _service.restaurantServiceType,
              decoration: const InputDecoration(
                labelText: 'Tipo di servizio',
                prefixIcon: Icon(Icons.room_service_outlined),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: RestaurantServiceType.lunch,
                  child: Text('Pranzo'),
                ),
                DropdownMenuItem(
                  value: RestaurantServiceType.dinner,
                  child: Text('Cena'),
                ),
                DropdownMenuItem(
                  value: RestaurantServiceType.custom,
                  child: Text('Altro'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _service.restaurantServiceType = value;
                });
              },
            ),
            const SizedBox(height: 20),

            if (_service.isAnnual)
              _buildAnnualDates()
            else
              _buildSpecificDate(),

            const SizedBox(height: 22),
            const Text(
              'Disponibilità',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Servizio attivo',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Il servizio viene considerato '
                'nel calendario.',
              ),
              value: _service.isActive,
              onChanged: (value) {
                setState(() {
                  _service.isActive = value;
                });
              },
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Prenotazioni aperte',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                _service.isOpen
                    ? 'I clienti possono prenotare.'
                    : 'Il servizio risulta chiuso.',
              ),
              value: _service.isOpen,
              onChanged: (value) {
                setState(() {
                  _service.isOpen = value;
                });
              },
            ),

            const SizedBox(height: 16),

            if (_service.isOpen) ...[
              Row(
                children: [
                  Expanded(
                    child: _EditorButton(
                      label: 'Inizio',
                      value: _service.startTime,
                      icon: Icons.schedule,
                      onTap: () {
                        _selectTime(start: true);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _EditorButton(
                      label: 'Fine',
                      value: _service.endTime,
                      icon: Icons.schedule,
                      onTap: () {
                        _selectTime(start: false);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _guestsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Coperti massimi online',
                  prefixIcon: Icon(Icons.groups_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final guests = int.tryParse(value?.trim() ?? '');

                  if (guests == null || guests < 1) {
                    return 'Inserisci un numero valido';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<int>(
                initialValue: _service.slotIntervalMinutes,
                decoration: const InputDecoration(
                  labelText: 'Intervallo prenotazioni',
                  prefixIcon: Icon(Icons.timer_outlined),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 15, child: Text('Ogni 15 minuti')),
                  DropdownMenuItem(value: 30, child: Text('Ogni 30 minuti')),
                  DropdownMenuItem(value: 45, child: Text('Ogni 45 minuti')),
                  DropdownMenuItem(value: 60, child: Text('Ogni 60 minuti')),
                ],
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _service.slotIntervalMinutes = value;
                  });
                },
              ),
            ],

            const SizedBox(height: 28),

            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'Salva servizio',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // PROGRAMMAZIONE ANNUALE
  // =========================================================

  Widget _buildAnnualDates() {
    const weekdays = [
      (DateTime.monday, 'Lunedì'),
      (DateTime.tuesday, 'Martedì'),
      (DateTime.wednesday, 'Mercoledì'),
      (DateTime.thursday, 'Giovedì'),
      (DateTime.friday, 'Venerdì'),
      (DateTime.saturday, 'Sabato'),
      (DateTime.sunday, 'Domenica'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Periodo di validità',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _EditorButton(
                label: 'Dal',
                value: _formatDate(_service.startDate),
                icon: Icons.calendar_today_outlined,
                onTap: () {
                  _selectAnnualDate(start: true);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _EditorButton(
                label: 'Al',
                value: _formatDate(_service.endDate),
                icon: Icons.event_outlined,
                onTap: () {
                  _selectAnnualDate(start: false);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Giorni del servizio',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: weekdays.map((item) {
            final selected = _service.weekdays.contains(item.$1);

            return FilterChip(
              label: Text(item.$2),
              selected: selected,
              onSelected: (value) {
                setState(() {
                  if (value) {
                    _service.weekdays.add(item.$1);
                  } else {
                    _service.weekdays.remove(item.$1);
                  }

                  _service.weekdays.sort();
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // =========================================================
  // DATA SPECIFICA
  // =========================================================

  Widget _buildSpecificDate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Data del servizio',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _EditorButton(
          label: 'Data specifica',
          value: _formatDate(_service.specificDate),
          icon: Icons.event_available_outlined,
          onTap: _selectSpecificDate,
        ),
      ],
    );
  }

  // =========================================================
  // SELEZIONE DATE
  // =========================================================

  Future<void> _selectAnnualDate({required bool start}) async {
    final now = DateTime.now();

    final initialDate = start
        ? _service.startDate ?? now
        : _service.endDate ?? now;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 2, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
    );

    if (selectedDate == null) return;

    setState(() {
      if (start) {
        _service.startDate = AvailabilityRepository.normalizeDate(selectedDate);
      } else {
        _service.endDate = AvailabilityRepository.normalizeDate(selectedDate);
      }
    });
  }

  Future<void> _selectSpecificDate() async {
    final now = DateTime.now();

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _service.specificDate ?? now,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
    );

    if (selectedDate == null) return;

    setState(() {
      _service.specificDate = AvailabilityRepository.normalizeDate(
        selectedDate,
      );
    });
  }

  // =========================================================
  // SELEZIONE ORARIO
  // =========================================================

  Future<void> _selectTime({required bool start}) async {
    final now = DateTime.now();
    final roundedMinutes = ((now.minute + 14) ~/ 15) * 15;
    final initialHour = (now.hour + (roundedMinutes ~/ 60)) % 24;
    final initialMinute = roundedMinutes % 60;
    var pendingTime = TimeOfDay(hour: initialHour, minute: initialMinute);

    final selectedTime = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: const Color(0xFF201D18),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: 330,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('ANNULLA'),
                      ),
                      Expanded(
                        child: Text(
                          start ? 'Orario di apertura' : 'Orario di chiusura',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop(pendingTime);
                        },
                        child: const Text('FATTO'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: CupertinoTheme(
                    data: const CupertinoThemeData(
                      brightness: Brightness.dark,
                      primaryColor: Color(0xFFC8A45D),
                      textTheme: CupertinoTextThemeData(
                        dateTimePickerTextStyle: TextStyle(
                          color: Color(0xFFE9E1D2),
                          fontSize: 22,
                        ),
                      ),
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      use24hFormat: true,
                      minuteInterval: 15,
                      initialDateTime: DateTime(
                        2026,
                        1,
                        1,
                        initialHour,
                        initialMinute,
                      ),
                      onDateTimeChanged: (value) {
                        pendingTime = TimeOfDay(
                          hour: value.hour,
                          minute: value.minute,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedTime == null) return;

    final formatted =
        '${selectedTime.hour.toString().padLeft(2, '0')}:'
        '${selectedTime.minute.toString().padLeft(2, '0')}';

    setState(() {
      if (start) {
        _service.startTime = formatted;
      } else {
        _service.endTime = formatted;
      }
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Seleziona';
    }

    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }
}

// ===========================================================
// PULSANTE MODIFICA CAMPO
// ===========================================================

class _EditorButton extends StatelessWidget {
  const _EditorButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined, size: 18),
          ],
        ),
      ),
    );
  }
}
