import '../../services/callable_http_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  Future<void> _notifySuccessfulLogin() async {
    try {
      await CallableHttpService.call('notifyStaffLogin');
    } catch (_) {
      // L'avviso non deve impedire l'accesso al gestionale.
    }
  }

  Future<void> _openLogin() async {
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

                await _notifySuccessfulLogin();

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
                'Accesso al gestionale',
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
                    'Le Capase Booking 2.1',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Accedi con le tue credenziali',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _openLogin,
                      icon: const Icon(Icons.login_rounded),
                      label: const Text(
                        'ACCEDI',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Inserisci l’email e la password del tuo account personale.',
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
