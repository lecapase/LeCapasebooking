import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();

  final _newPasswordController = TextEditingController();

  final _confirmPasswordController = TextEditingController();

  bool _saving = false;
  bool _hideCurrentPassword = true;
  bool _hideNewPassword = true;
  bool _hideConfirmation = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  String _firebaseError(FirebaseAuthException error) {
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'La password attuale non ? corretta.';

      case 'weak-password':
        return 'La nuova password ? troppo debole.';

      case 'requires-recent-login':
        return 'Per sicurezza, esci e accedi nuovamente '
            'prima di cambiare la password.';

      case 'too-many-requests':
        return 'Troppi tentativi. Riprova tra qualche minuto.';

      case 'network-request-failed':
        return 'Connessione assente. Controlla Internet e riprova.';

      case 'user-disabled':
        return 'Questo account ? stato disattivato.';

      default:
        return error.message ?? 'Impossibile cambiare la password.';
    }
  }

  Future<void> _changePassword() async {
    if (_saving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    final email = user?.email?.trim() ?? '';

    if (user == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sessione non valida. Esci e accedi nuovamente.'),
        ),
      );

      return;
    }

    final currentPassword = _currentPasswordController.text;

    final newPassword = _newPasswordController.text;

    setState(() {
      _saving = true;
    });

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      await user.updatePassword(newPassword);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password aggiornata correttamente.')),
      );

      Navigator.of(context).pop();
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_firebaseError(error))));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile cambiare la password.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cambia password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.password_rounded,
                      size: 48,
                      color: Color(0xFFC8A45D),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Proteggi il tuo account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Inserisci la password attuale '
                      'e scegli una nuova password.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _currentPasswordController,
                      enabled: !_saving,
                      obscureText: _hideCurrentPassword,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password attuale',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _hideCurrentPassword = !_hideCurrentPassword;
                            });
                          },
                          icon: Icon(
                            _hideCurrentPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Inserisci la password attuale.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _newPasswordController,
                      enabled: !_saving,
                      obscureText: _hideNewPassword,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'Nuova password',
                        prefixIcon: const Icon(Icons.password_rounded),
                        helperText: 'Almeno 8 caratteri',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _hideNewPassword = !_hideNewPassword;
                            });
                          },
                          icon: Icon(
                            _hideNewPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 8) {
                          return 'Inserisci almeno 8 caratteri.';
                        }

                        if (value == _currentPasswordController.text) {
                          return 'La nuova password deve essere diversa.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      enabled: !_saving,
                      obscureText: _hideConfirmation,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        _changePassword();
                      },
                      decoration: InputDecoration(
                        labelText: 'Conferma nuova password',
                        prefixIcon: const Icon(Icons.verified_user_outlined),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _hideConfirmation = !_hideConfirmation;
                            });
                          },
                          icon: Icon(
                            _hideConfirmation
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value != _newPasswordController.text) {
                          return 'Le password non coincidono.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _saving ? null : _changePassword,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(
                        _saving ? 'AGGIORNAMENTO...' : 'CAMBIA PASSWORD',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
