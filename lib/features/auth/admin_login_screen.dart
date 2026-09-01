import '../../services/callable_http_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_version.dart';
import '../../theme/app_colors.dart';

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 1100;
          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.black,
                        AppColors.dark,
                        AppColors.goldDark.withValues(alpha: 0.24),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -100,
                top: -120,
                child: Container(
                  width: 420,
                  height: 420,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold.withValues(alpha: 0.07),
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(desktop ? 48 : 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xF2141311),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0xFF302D27)),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 48,
                              offset: Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Flex(
                          direction: desktop ? Axis.horizontal : Axis.vertical,
                          children: [
                            SizedBox(
                              width: desktop ? 580 : double.infinity,
                              child: Padding(
                                padding: EdgeInsets.all(desktop ? 54 : 30),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.gold.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(99),
                                        border: Border.all(
                                          color: AppColors.gold.withValues(
                                            alpha: 0.28,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'GESTIONALE RISTORANTE',
                                        style: GoogleFonts.inter(
                                          color: AppColors.gold,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    Image.asset(
                                      'assets/images/logo.png',
                                      height: desktop ? 112 : 84,
                                      alignment: Alignment.centerLeft,
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'Tutto il servizio,\nin un solo posto.',
                                      style: GoogleFonts.libreBaskerville(
                                        color: AppColors.white,
                                        fontSize: desktop ? 38 : 29,
                                        height: 1.16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Prenotazioni, disponibilità e sala sempre sotto controllo.',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFB9B3A8),
                                        fontSize: 15,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(
                              width: desktop ? 400 : double.infinity,
                              child: Container(
                                padding: EdgeInsets.all(desktop ? 46 : 30),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B1916),
                                  borderRadius: BorderRadius.circular(27),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Bentornato',
                                      style: GoogleFonts.libreBaskerville(
                                        color: AppColors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 9),
                                    Text(
                                      'Accedi con il tuo account personale per iniziare.',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFA9A39A),
                                        height: 1.45,
                                      ),
                                    ),
                                    const SizedBox(height: 30),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: FilledButton.icon(
                                        onPressed: _openLogin,
                                        icon: const Icon(Icons.login_rounded),
                                        label: const Text(
                                          'Accedi al gestionale',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.shield_outlined,
                                          size: 17,
                                          color: AppColors.gold,
                                        ),
                                        const SizedBox(width: 9),
                                        Expanded(
                                          child: Text(
                                            'Accesso riservato al personale autorizzato',
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFF888279),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 18,
                bottom: 12,
                child: Text(
                  AppVersion.fullLabel,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF777168),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
