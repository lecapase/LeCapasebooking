import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/callable_http_service.dart';
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

  void _message(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  String _functionError(Object error, String fallback) {
    if (error is CallableHttpException) {
      return error.message ?? fallback;
    }

    return fallback;
  }

  Future<void> _openNewUserDialog() async {
    final nameController = TextEditingController();

    final emailController = TextEditingController();

    final passwordController = TextEditingController();

    final confirmController = TextEditingController();

    String selectedRole = 'staff';
    bool saving = false;
    bool obscure = true;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              if (saving) {
                return;
              }

              final displayName = nameController.text.trim();

              final email = emailController.text.trim().toLowerCase();

              final password = passwordController.text;

              if (displayName.length < 2) {
                setDialogState(() {
                  errorText = 'Inserisci il nome utente.';
                });
                return;
              }

              if (!email.contains('@')) {
                setDialogState(() {
                  errorText = 'Inserisci una email valida.';
                });
                return;
              }

              if (password.length < 8) {
                setDialogState(() {
                  errorText = 'La password deve avere almeno 8 caratteri.';
                });
                return;
              }

              if (password != confirmController.text) {
                setDialogState(() {
                  errorText = 'Le password non coincidono.';
                });
                return;
              }

              setDialogState(() {
                saving = true;
                errorText = null;
              });

              try {
                await CallableHttpService.call('createStaffUser', {
                  'displayName': displayName,
                  'email': email,
                  'role': selectedRole,
                  'password': password,
                });

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop();

                _message('Utente creato correttamente.');
              } catch (error) {
                setDialogState(() {
                  saving = false;
                  errorText = _functionError(
                    error,
                    'Impossibile creare l\'utente.',
                  );
                });
              }
            }

            return AlertDialog(
              title: const Text('Nuovo utente'),
              content: SizedBox(
                width: 430,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        enabled: !saving,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nome e cognome',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: emailController,
                        enabled: !saving,
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
                                if (value == null) {
                                  return;
                                }

                                setDialogState(() {
                                  selectedRole = value;
                                });
                              },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: passwordController,
                        enabled: !saving,
                        obscureText: obscure,
                        decoration: InputDecoration(
                          labelText: 'Password iniziale',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: saving
                                ? null
                                : () {
                                    setDialogState(() {
                                      obscure = !obscure;
                                    });
                                  },
                            icon: Icon(
                              obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: confirmController,
                        enabled: !saving,
                        obscureText: obscure,
                        onSubmitted: (_) => save(),
                        decoration: InputDecoration(
                          labelText: 'Conferma password',
                          prefixIcon: const Icon(Icons.lock_reset_outlined),
                          errorText: errorText,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Al primo accesso l\'utente potra mantenerla oppure cambiarla.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
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

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
  }

  Future<void> _resetPassword(String uid, String displayName) async {
    final passwordController = TextEditingController();

    final confirmController = TextEditingController();

    bool saving = false;
    bool obscure = true;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              final password = passwordController.text;

              if (password.length < 8) {
                setDialogState(() {
                  errorText = 'Usa almeno 8 caratteri.';
                });
                return;
              }

              if (password != confirmController.text) {
                setDialogState(() {
                  errorText = 'Le password non coincidono.';
                });
                return;
              }

              setDialogState(() {
                saving = true;
                errorText = null;
              });

              try {
                await CallableHttpService.call('resetStaffPassword', {
                  'uid': uid,
                  'password': password,
                });

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop();

                _message(
                  'Password temporanea assegnata a ' + displayName + '.',
                );
              } catch (error) {
                setDialogState(() {
                  saving = false;
                  errorText = _functionError(
                    error,
                    'Reimpostazione non riuscita.',
                  );
                });
              }
            }

            return AlertDialog(
              title: Text('Password di ' + displayName),
              content: SizedBox(
                width: 390,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: passwordController,
                      autofocus: true,
                      enabled: !saving,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Nuova password temporanea',
                        prefixIcon: const Icon(Icons.lock_reset),
                        suffixIcon: IconButton(
                          onPressed: saving
                              ? null
                              : () {
                                  setDialogState(() {
                                    obscure = !obscure;
                                  });
                                },
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: confirmController,
                      enabled: !saving,
                      obscureText: obscure,
                      onSubmitted: (_) => save(),
                      decoration: InputDecoration(
                        labelText: 'Conferma password',
                        errorText: errorText,
                      ),
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
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Reimposta'),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();
    confirmController.dispose();
  }

  Future<void> _deleteUser(String uid, String displayName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Elimina utente'),
          content: Text('Vuoi eliminare definitivamente ' + displayName + '?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Elimina'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await CallableHttpService.call('deleteStaffUser', <String, dynamic>{
        'uid': uid,
      });

      _message(displayName + ' eliminato correttamente.');
    } catch (error) {
      _message(_functionError(error, 'Impossibile eliminare l\'utente.'));
    }
  }

  Future<void> _editOwnProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    final nameController = TextEditingController(text: 'Antonio');

    final selectedName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Profilo amministratore'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nome da mostrare nella homepage',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(nameController.text.trim()),
              child: const Text('Salva'),
            ),
          ],
        );
      },
    );

    nameController.dispose();

    if (selectedName == null || selectedName.length < 2) {
      return;
    }

    await _firestore.collection('admins').doc(user.uid).set({
      'uid': user.uid,
      'displayName': selectedName,
      'email': user.email ?? '',
      'role': 'admin',
      'active': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _message('Profilo amministratore aggiornato.');
  }

  Future<void> _editUser(String uid, Map<String, dynamic> data) async {
    if (uid == _auth.currentUser?.uid) {
      _message('Non puoi modificare il tuo account da questa schermata.');
      return;
    }

    String selectedRole = (data['role'] ?? 'staff').toString();

    bool active = data['active'] == true;
    bool saving = false;

    final displayName = (data['displayName'] ?? 'Utente').toString();

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
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop();
                _message('Utente aggiornato.');
              } catch (error) {
                setDialogState(() {
                  saving = false;
                });

                _message('Aggiornamento non riuscito.');
              }
            }

            return AlertDialog(
              title: Text(displayName),
              content: SizedBox(
                width: 410,
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
                              if (value == null) {
                                return;
                              }

                              setDialogState(() {
                                selectedRole = value;
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Utente attivo'),
                      subtitle: Text(
                        active
                            ? 'Puo accedere al gestionale'
                            : 'Accesso disabilitato',
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
                    const Divider(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                Navigator.of(dialogContext).pop();

                                await _resetPassword(uid, displayName);
                              },
                        icon: const Icon(Icons.lock_reset),
                        label: const Text('Reimposta password'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                        ),
                        onPressed: saving
                            ? null
                            : () async {
                                Navigator.of(dialogContext).pop();

                                await _deleteUser(uid, displayName);
                              },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Elimina utente'),
                      ),
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
      appBar: AppBar(
        title: const Text('Utenti e permessi'),
        actions: [
          IconButton(
            tooltip: 'Profilo amministratore',
            onPressed: _editOwnProfile,
            icon: const Icon(Icons.manage_accounts_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewUserDialog,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nuovo utente'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('staff_users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Impossibile caricare gli utenti.'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final first = (a.data()['displayName'] ?? '')
                  .toString()
                  .toLowerCase();

              final second = (b.data()['displayName'] ?? '')
                  .toString()
                  .toLowerCase();

              return first.compareTo(second);
            });

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
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _editUser(document.id, data),
              );
            },
          );
        },
      ),
    );
  }
}
