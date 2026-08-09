import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../availability/availability_screen.dart';
import '../bookings/bookings_screen.dart';
import '../home/admin_home_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() =>
      _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  // =========================================================
  // LOGIN
  // =========================================================

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (homeContext) {
            return AdminHomeScreen(
              // =================================================
              // GESTISCI PRENOTAZIONI
              // =================================================

              onBookings: () {
                Navigator.of(homeContext).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const BookingsScreen(),
                  ),
                );
              },

              // =================================================
              // DISPONIBILITÀ ONLINE
              // =================================================

              onAvailability: () {
                Navigator.of(homeContext).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const AvailabilityScreen(),
                  ),
                );
              },

              // =================================================
              // ECCEZIONI E CHIUSURE
              //
              // Per ora porta alla schermata disponibilità,
              // dove abbiamo già la gestione eccezioni.
              // Più avanti la separiamo in una schermata dedicata.
              // =================================================

              onExceptions: () {
                Navigator.of(homeContext).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const AvailabilityScreen(),
                  ),
                );
              },

              // =================================================
              // IMPOSTAZIONI
              // =================================================

              onSettings: () {
                Navigator.of(homeContext).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const _SettingsPlaceholderScreen(),
                  ),
                );
              },
            );
          },
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      String message = 'Accesso non riuscito.';

      if (error.code == 'invalid-credential') {
        message =
            'Email o password non corretti.';
      } else if (error.code == 'user-not-found') {
        message =
            'Utente non trovato.';
      } else if (error.code == 'wrong-password') {
        message =
            'Password non corretta.';
      } else if (error.code == 'invalid-email') {
        message =
            'Indirizzo email non valido.';
      } else if (error.code == 'too-many-requests') {
        message =
            'Troppi tentativi di accesso. '
            'Riprova tra qualche minuto.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Si è verificato un errore. Riprova.',
          ),
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
  // INTERFACCIA LOGIN
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 420,
              ),
              child: Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 48,
                        ),

                        const SizedBox(height: 20),

                        const Text(
                          'Le Capase Booking',
                          textAlign:
                              TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          'Accesso amministratore',
                          textAlign:
                              TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),

                        const SizedBox(height: 28),

                        TextFormField(
                          controller:
                              _emailController,
                          keyboardType:
                              TextInputType
                                  .emailAddress,
                          textInputAction:
                              TextInputAction.next,
                          decoration:
                              const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(
                              Icons.email_outlined,
                            ),
                            border:
                                OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final email =
                                value?.trim() ?? '';

                            if (email.isEmpty) {
                              return 'Inserisci la tua email';
                            }

                            if (!email.contains('@')) {
                              return 'Inserisci una email valida';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller:
                              _passwordController,
                          obscureText:
                              _obscurePassword,
                          textInputAction:
                              TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (!_isLoading) {
                              _login();
                            }
                          },
                          decoration:
                              InputDecoration(
                            labelText: 'Password',
                            prefixIcon:
                                const Icon(
                              Icons.lock_outline,
                            ),
                            border:
                                const OutlineInputBorder(),
                            suffixIcon:
                                IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscurePassword =
                                      !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons
                                        .visibility_outlined
                                    : Icons
                                        .visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.isEmpty) {
                              return 'Inserisci la password';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        FilledButton(
                          onPressed:
                              _isLoading
                                  ? null
                                  : _login,
                          child: Padding(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              vertical: 14,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'ACCEDI',
                                    style: TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
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
        ),
      ),
    );
  }
}

// ===========================================================
// IMPOSTAZIONI - SCHERMATA TEMPORANEA
// ===========================================================

class _SettingsPlaceholderScreen
    extends StatelessWidget {
  const _SettingsPlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Impostazioni',
        ),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Le impostazioni verranno aggiunte qui.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }
}