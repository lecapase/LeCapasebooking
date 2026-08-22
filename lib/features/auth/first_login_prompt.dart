import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/callable_http_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FirstLoginPrompt extends StatefulWidget {
  const FirstLoginPrompt({super.key, required this.child});

  final Widget child;

  @override
  State<FirstLoginPrompt> createState() => _FirstLoginPromptState();
}

class _FirstLoginPromptState extends State<FirstLoginPrompt> {
  bool _checked = false;
  bool _dialogOpened = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFirstLogin());
  }

  Future<void> _checkFirstLogin() async {
    if (_checked) {
      return;
    }

    _checked = true;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('staff_users')
          .doc(user.uid)
          .get();

      final data = snapshot.data();

      if (!mounted ||
          data == null ||
          data['offerPasswordChange'] != true ||
          _dialogOpened) {
        return;
      }

      _dialogOpened = true;
      await _showInitialChoice(
        (data['displayName'] ?? user.displayName ?? 'Utente').toString(),
      );
    } catch (_) {
      // Il gestionale resta utilizzabile.
    }
  }

  Future<void> _complete({String? password}) async {
    final data = <String, dynamic>{};

    if (password != null) {
      data['password'] = password;
    }

    await CallableHttpService.call('completeFirstStaffLogin', data);
  }

  Future<void> _showInitialChoice(String displayName) async {
    final changePassword = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Benvenuto, $displayName'),
          content: const Text(
            'Stai utilizzando la password iniziale. '
            'Vuoi personalizzarla?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Continua'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cambia password'),
            ),
          ],
        );
      },
    );

    if (!mounted || changePassword == null) {
      return;
    }

    if (!changePassword) {
      try {
        await _complete();
      } catch (_) {
        _showMessage('Non \u00e8 stato possibile completare il primo accesso.');
      }
      return;
    }

    await _showChangePassword();
  }

  Future<void> _showChangePassword() async {
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

              final confirmation = confirmController.text;

              if (password.length < 8) {
                setDialogState(() {
                  errorText = 'Usa almeno 8 caratteri.';
                });
                return;
              }

              if (password != confirmation) {
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
                await _complete(password: password);

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop();

                _showMessage('Password aggiornata.');
              } on CallableHttpException catch (error) {
                setDialogState(() {
                  saving = false;
                  errorText = error.message ?? 'Aggiornamento non riuscito.';
                });
              } catch (_) {
                setDialogState(() {
                  saving = false;
                  errorText = 'Aggiornamento non riuscito.';
                });
              }
            }

            return AlertDialog(
              title: const Text('Nuova password'),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: passwordController,
                      autofocus: true,
                      enabled: !saving,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Nuova password',
                        errorText: errorText,
                        border: const OutlineInputBorder(),
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
                        border: const OutlineInputBorder(),
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
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Non ora'),
                ),
                FilledButton(
                  onPressed: saving ? null : save,
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salva'),
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

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
