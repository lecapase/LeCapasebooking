import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StaffUsersScreen extends StatefulWidget {
  const StaffUsersScreen({super.key});

  @override
  State<StaffUsersScreen> createState() => _StaffUsersScreenState();
}

class _StaffUsersScreenState extends State<StaffUsersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const Map<String, String> _roleLabels = {
    'staff': 'Staff',
    'supervisor': 'Supervisor',
    'manager': 'Manager',
    'admin': 'Amministratore',
  };

  Future<void> _openNewUserDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    String selectedRole = 'staff';
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              final displayName = nameController.text.trim();
              final email = emailController.text.trim().toLowerCase();
              final currentUser = _auth.currentUser;

              if (displayName.length < 2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Inserisci il nome utente.')),
                );
                return;
              }

              if (!email.contains('@') || email.length < 5) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Inserisci una email valida.')),
                );
                return;
              }

              if (currentUser == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Sessione non valida. Effettua nuovamente il login.',
                    ),
                  ),
                );
                return;
              }

              setDialogState(() {
                saving = true;
              });

              try {
                await _firestore.collection('staff_user_invites').add({
                  'displayName': displayName,
                  'email': email,
                  'role': selectedRole,
                  'createdBy': currentUser.uid,
                  'status': 'pending',
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();

                if (!mounted) return;

                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Invito creato. Il sistema sta preparando lâ€™account e inviando lâ€™email.',
                    ),
                  ),
                );
              } catch (error) {
                setDialogState(() {
                  saving = false;
                });

                if (!mounted) return;

                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('Errore durante la creazione: $error'),
                  ),
                );
              }
            }

            return AlertDialog(
              title: const Text('Nuovo utente'),
              content: SizedBox(
                width: 430,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nome e cognome',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Ruolo',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: _roleLabels.entries
                          .map(
                            (entry) => DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value == null) return;
                              setDialogState(() {
                                selectedRole = value;
                              });
                            },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annulla'),
                ),
                FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add_alt_1),
                  label: Text(saving ? 'Creazione...' : 'Crea utente'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editUser(String uid, Map<String, dynamic> data) async {
    if (uid == _auth.currentUser?.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Per sicurezza non puoi modificare il tuo account da questa schermata.',
          ),
        ),
      );
      return;
    }

    String selectedRole = (data['role'] ?? 'staff').toString();
    bool active = data['active'] == true;
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              setDialogState(() {
                saving = true;
              });

              try {
                await _firestore.collection('staff_users').doc(uid).update({
                  'role': selectedRole,
                  'active': active,
                });

                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();

                if (!mounted) return;

                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Utente aggiornato.')),
                );
              } catch (error) {
                setDialogState(() {
                  saving = false;
                });

                if (!mounted) return;

                ScaffoldMessenger.of(
                  this.context,
                ).showSnackBar(SnackBar(content: Text('Errore: $error')));
              }
            }

            return AlertDialog(
              title: Text((data['displayName'] ?? 'Utente').toString()),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _roleLabels.containsKey(selectedRole)
                          ? selectedRole
                          : 'staff',
                      decoration: const InputDecoration(
                        labelText: 'Ruolo',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: _roleLabels.entries
                          .map(
                            (entry) => DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value == null) return;
                              setDialogState(() {
                                selectedRole = value;
                              });
                            },
                    ),
                    const SizedBox(height: 18),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Utente attivo'),
                      subtitle: Text(
                        active
                            ? 'PuÃ² accedere al gestionale'
                            : 'Accesso al gestionale disabilitato',
                      ),
                      value: active,
                      onChanged: saving
                          ? null
                          : (value) {
                              setDialogState(() {
                                active = value;
                              });
                            },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: saving ? null : save,
                  child: Text(saving ? 'Salvataggio...' : 'Salva'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _roleChip(String role) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(
        _roleLabels[role] ?? role,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Utenti e permessi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewUserDialog,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nuovo utente'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('staff_users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Impossibile caricare gli utenti.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final nameA = (a.data()['displayName'] ?? '')
                  .toString()
                  .toLowerCase();
              final nameB = (b.data()['displayName'] ?? '')
                  .toString()
                  .toLowerCase();
              return nameA.compareTo(nameB);
            });

          if (users.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.groups_outlined,
                      size: 54,
                      color: Color(0xFFC8A45D),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Nessun utente staff',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Crea il primo account per iniziare a gestire gli accessi.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _openNewUserDialog,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Nuovo utente'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            itemCount: users.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final document = users[index];
              final data = document.data();

              final displayName = (data['displayName'] ?? 'Utente').toString();
              final email = (data['email'] ?? '').toString();
              final role = (data['role'] ?? 'staff').toString();
              final active = data['active'] == true;
              final isMe = document.id == currentUid;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFC8A45D),
                  foregroundColor: Colors.black,
                  child: Text(
                    displayName.isNotEmpty
                        ? displayName.substring(0, 1).toUpperCase()
                        : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 8),
                      const Text(
                        'TU',
                        style: TextStyle(
                          color: Color(0xFFC8A45D),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(email),
                      _roleChip(role),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            active
                                ? Icons.check_circle_outline
                                : Icons.block_outlined,
                            size: 15,
                            color: active ? Colors.green : Colors.redAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            active ? 'Attivo' : 'Disattivato',
                            style: TextStyle(
                              fontSize: 11,
                              color: active ? Colors.green : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                trailing: isMe
                    ? const Icon(Icons.verified_user_outlined)
                    : const Icon(Icons.chevron_right),
                onTap: () => _editUser(document.id, data),
              );
            },
          );
        },
      ),
    );
  }
}
