import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../agenda/kitchen_agenda_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  List<Map<String, String>> _profiles = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _functions
          .httpsCallable('listActiveStaffProfiles')
          .call();

      final data = Map<String, dynamic>.from(result.data as Map);

      final rawProfiles = data['profiles'] as List? ?? const [];

      final profiles = rawProfiles
          .map((item) => Map<String, dynamic>.from(item as Map))
          .map(
            (item) => {
              'uid': (item['uid'] ?? '').toString(),
              'displayName': (item['displayName'] ?? '').toString(),
              'loginEmail': (item['loginEmail'] ?? '').toString(),
            },
          )
          .where(
            (item) =>
                item['displayName']!.isNotEmpty &&
                item['loginEmail']!.isNotEmpty,
          )
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _profiles = profiles;
        _loading = false;
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.message ?? 'Impossibile caricare gli utenti.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'Impossibile caricare gli utenti.';
      });
    }
  }

  Future<void> _openPasswordDialog(Map<String, String> profile) async {
    final passwordController = TextEditingController();

    bool obscurePassword = true;
    bool signingIn = false;
    String? dialogError;

    await showDialog<void>(
      context: context,
      barrierDismissible: !signingIn,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> login() async {
              if (signingIn) {
                return;
              }

              final password = passwordController.text;

              if (password.isEmpty) {
                setDialogState(() {
                  dialogError = 'Inserisci la password.';
                });
                return;
              }

              setDialogState(() {
                signingIn = true;
                dialogError = null;
              });

              try {
                if (kIsWeb) {
                  await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
                }

                await FirebaseAuth.instance.signInWithEmailAndPassword(
                  email: profile['loginEmail']!,
                  password: password,
                );

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop();
              } on FirebaseAuthException catch (error) {
                String message = 'Password non corretta.';

                if (error.code == 'too-many-requests') {
                  message = 'Troppi tentativi. Riprova tra qualche minuto.';
                } else if (error.code == 'network-request-failed') {
                  message = 'Problema di connessione.';
                } else if (error.code == 'user-disabled' ||
                    error.code == 'user-not-found') {
                  message = 'Questo account non \u00e8 disponibile.';
                }

                setDialogState(() {
                  signingIn = false;
                  dialogError = message;
                });
              } catch (_) {
                setDialogState(() {
                  signingIn = false;
                  dialogError = 'Accesso non riuscito.';
                });
              }
            }

            return AlertDialog(
              title: Text(profile['displayName']!, textAlign: TextAlign.center),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Inserisci la tua password',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: passwordController,
                      autofocus: true,
                      enabled: !signingIn,
                      obscureText: obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => login(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: signingIn
                              ? null
                              : () {
                                  setDialogState(() {
                                    obscurePassword = !obscurePassword;
                                  });
                                },
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                        errorText: dialogError,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: signingIn
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: signingIn ? null : login,
                  child: signingIn
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('ACCEDI'),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();
  }

  Future<void> _openAdministratorLogin() async {
    final emailController = TextEditingController();

    final passwordController = TextEditingController();

    bool signingIn = false;
    bool obscurePassword = true;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> login() async {
              if (signingIn) {
                return;
              }

              final email = emailController.text.trim().toLowerCase();

              final password = passwordController.text;

              if (!email.contains('@')) {
                setDialogState(() {
                  errorText = 'Inserisci una email valida.';
                });
                return;
              }

              if (password.isEmpty) {
                setDialogState(() {
                  errorText = 'Inserisci la password.';
                });
                return;
              }

              setDialogState(() {
                signingIn = true;
                errorText = null;
              });

              try {
                if (kIsWeb) {
                  await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
                }

                await FirebaseAuth.instance.signInWithEmailAndPassword(
                  email: email,
                  password: password,
                );

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop();
              } on FirebaseAuthException catch (error) {
                String message = 'Email o password non corretti.';

                if (error.code == 'too-many-requests') {
                  message = 'Troppi tentativi. Riprova tra qualche minuto.';
                } else if (error.code == 'network-request-failed') {
                  message = 'Problema di connessione.';
                } else if (error.code == 'user-disabled') {
                  message = 'Questo account \u00e8 disattivato.';
                }

                setDialogState(() {
                  signingIn = false;
                  errorText = message;
                });
              } catch (_) {
                setDialogState(() {
                  signingIn = false;
                  errorText = 'Accesso non riuscito.';
                });
              }
            }

            return AlertDialog(
              title: const Text(
                'Accesso amministratore',
                textAlign: TextAlign.center,
              ),
              content: SizedBox(
                width: 370,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: emailController,
                      autofocus: true,
                      enabled: !signingIn,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: passwordController,
                      enabled: !signingIn,
                      obscureText: obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => login(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        errorText: errorText,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: signingIn
                              ? null
                              : () {
                                  setDialogState(() {
                                    obscurePassword = !obscurePassword;
                                  });
                                },
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: signingIn
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: signingIn ? null : login,
                  child: signingIn
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('ACCEDI'),
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();
    passwordController.dispose();
  }

  Widget _profileButton(Map<String, String> profile) {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: () => _openPasswordDialog(profile),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: const Color(0xFF171717),
          side: const BorderSide(color: Color(0xFFC8A45D), width: 0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          profile['displayName']!,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 46, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _loadProfiles,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Riprova'),
            ),
          ],
        ),
      );
    }

    if (_profiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Nessun utente disponibile.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _loadProfiles,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Aggiorna'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProfiles,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _profiles.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _profileButton(_profiles[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 42, 24, 24),
              child: Column(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 38,
                    color: Color(0xFFC8A45D),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Le Capase Booking 2.0',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Seleziona il tuo profilo',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                  const SizedBox(height: 34),
                  Expanded(child: _content()),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const KitchenAgendaScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: const Text('Agenda'),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: _openAdministratorLogin,
                    icon: const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 18,
                    ),
                    label: const Text('Accesso amministratore'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Seleziona il tuo nome e inserisci la password',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
