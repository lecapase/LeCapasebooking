import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({
    super.key,
  });

  @override
  State<AdminLoginScreen> createState() =>
      _AdminLoginScreenState();
}

class _AdminLoginScreenState
    extends State<AdminLoginScreen> {
  final _formKey =
      GlobalKey<FormState>();

  final _emailController =
      TextEditingController();

  final _passwordController =
      TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;

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
    if (_isLoading) {
      return;
    }

    final form =
        _formKey.currentState;

    if (form == null ||
        !form.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final auth =
          FirebaseAuth.instance;

      // Sul Web scegliamo quanto deve durare
      // la sessione.
      if (kIsWeb) {
        await auth.setPersistence(
          _rememberMe
              ? Persistence.LOCAL
              : Persistence.SESSION,
        );
      }

      await auth.signInWithEmailAndPassword(
        email:
            _emailController.text.trim(),
        password:
            _passwordController.text,
      );

      // NON facciamo Navigator.push.
      //
      // AdminAuthGate ascolta authStateChanges()
      // e aprirà automaticamente la Home.
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      String message =
          'Accesso non riuscito.';

      switch (error.code) {
        case 'invalid-credential':
          message =
              'Email o password non corretti.';
          break;

        case 'user-not-found':
          message =
              'Utente non trovato.';
          break;

        case 'wrong-password':
          message =
              'Password non corretta.';
          break;

        case 'invalid-email':
          message =
              'Indirizzo email non valido.';
          break;

        case 'too-many-requests':
          message =
              'Troppi tentativi di accesso. '
              'Riprova tra qualche minuto.';
          break;

        case 'network-request-failed':
          message =
              'Problema di connessione. '
              'Controlla Internet e riprova.';
          break;
      }

      _showMessage(
        message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Si è verificato un errore. Riprova.',
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
  // MESSAGGIO
  // =========================================================

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading:
            false,
        leading: IconButton(
          tooltip: 'Indietro',
          onPressed:
              _isLoading
                  ? null
                  : () {
                      Navigator.of(context)
                          .maybePop();
                    },
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
          ),
        ),
        title: const Text(
          'Accesso gestionale',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.all(
              24,
            ),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 420,
              ),
              child: Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    24,
                  ),
                  child: Form(
                    key:
                        _formKey,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .stretch,
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 48,
                        ),

                        const SizedBox(
                          height: 20,
                        ),

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

                        const SizedBox(
                          height: 8,
                        ),

                        const Text(
                          'Accesso amministratore',
                          textAlign:
                              TextAlign.center,
                          style: TextStyle(
                            color:
                                Colors.grey,
                          ),
                        ),

                        const SizedBox(
                          height: 28,
                        ),

                        TextFormField(
                          controller:
                              _emailController,
                          enabled:
                              !_isLoading,
                          keyboardType:
                              TextInputType
                                  .emailAddress,
                          textInputAction:
                              TextInputAction
                                  .next,
                          autofillHints:
                              const [
                            AutofillHints.email,
                          ],
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Email',
                            prefixIcon:
                                Icon(
                              Icons
                                  .email_outlined,
                            ),
                            border:
                                OutlineInputBorder(),
                          ),
                          validator:
                              (value) {
                            final email =
                                value?.trim() ??
                                    '';

                            if (email.isEmpty) {
                              return 'Inserisci la tua email';
                            }

                            if (!email.contains(
                              '@',
                            )) {
                              return 'Inserisci una email valida';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        TextFormField(
                          controller:
                              _passwordController,
                          enabled:
                              !_isLoading,
                          obscureText:
                              _obscurePassword,
                          textInputAction:
                              TextInputAction.done,
                          autofillHints:
                              const [
                            AutofillHints.password,
                          ],
                          onFieldSubmitted:
                              (_) {
                            if (!_isLoading) {
                              _login();
                            }
                          },
                          decoration:
                              InputDecoration(
                            labelText:
                                'Password',
                            prefixIcon:
                                const Icon(
                              Icons
                                  .lock_outline,
                            ),
                            border:
                                const OutlineInputBorder(),
                            suffixIcon:
                                IconButton(
                              onPressed:
                                  _isLoading
                                      ? null
                                      : () {
                                          setState(
                                            () {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            },
                                          );
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
                          validator:
                              (value) {
                            if (value ==
                                    null ||
                                value.isEmpty) {
                              return 'Inserisci la password';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        CheckboxListTile(
                          value:
                              _rememberMe,
                          contentPadding:
                              EdgeInsets.zero,
                          controlAffinity:
                              ListTileControlAffinity
                                  .leading,
                          title:
                              const Text(
                            'Ricordami',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                          subtitle:
                              const Text(
                            'Mantieni l’accesso su questo dispositivo',
                          ),
                          onChanged:
                              _isLoading
                                  ? null
                                  : (value) {
                                      setState(
                                        () {
                                          _rememberMe =
                                              value ??
                                                  true;
                                        },
                                      );
                                    },
                        ),

                        const SizedBox(
                          height: 20,
                        ),

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
                            child:
                                _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth:
                                              2,
                                        ),
                                      )
                                    : const Text(
                                        'ACCEDI',
                                        style:
                                            TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),
                          ),
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        const Text(
                          'Face ID / accesso biometrico '
                          'verrà aggiunto nelle Impostazioni.',
                          textAlign:
                              TextAlign.center,
                          style: TextStyle(
                            color:
                                Colors.grey,
                            fontSize: 12,
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