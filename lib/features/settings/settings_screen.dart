import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_version.dart';
import '../../services/biometric_service.dart';
import '../../theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
  });

  @override
  State<SettingsScreen> createState() =>
      _SettingsScreenState();
}

class _SettingsScreenState
    extends State<SettingsScreen> {
  static const String _biometricPreferenceKey =
      'biometric_enabled';

  static const String _notificationsPreferenceKey =
      'notifications_enabled';

  bool _biometricEnabled = false;
  bool _notificationsEnabled = true;

  bool _isLoading = true;
  bool _isBiometricChanging = false;

  String _biometricLabel =
      'Accesso biometrico / Face ID';

  String _biometricSubtitle =
      'Richiedi Face ID o biometria per entrare nel gestionale.';

  @override
  void initState() {
    super.initState();

    _loadSettings();
  }

  // =========================================================
  // CARICA IMPOSTAZIONI
  // =========================================================

  Future<void> _loadSettings() async {
    try {
      final preferences =
          await SharedPreferences.getInstance();

      final biometricEnabled =
          preferences.getBool(
                _biometricPreferenceKey,
              ) ??
              false;

      final notificationsEnabled =
          preferences.getBool(
                _notificationsPreferenceKey,
              ) ??
              true;

      String biometricLabel =
          'Accesso biometrico / Face ID';

      String biometricSubtitle =
          'Richiedi Face ID o biometria per entrare nel gestionale.';

      if (kIsWeb) {
        biometricLabel =
            'Accesso biometrico';

        biometricSubtitle =
            'Face ID e biometria saranno disponibili nell’app mobile.';
      } else {
        final biometricName =
            await BiometricService.biometricName();

        biometricLabel =
            'Accesso con $biometricName';

        final available =
            await BiometricService.isAvailable();

        if (!available) {
          biometricSubtitle =
              'Nessuna biometria configurata su questo dispositivo.';
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _biometricEnabled =
            biometricEnabled;

        _notificationsEnabled =
            notificationsEnabled;

        _biometricLabel =
            biometricLabel;

        _biometricSubtitle =
            biometricSubtitle;

        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  // =========================================================
  // ATTIVA / DISATTIVA BIOMETRIA
  // =========================================================

  Future<void> _changeBiometric(
    bool value,
  ) async {
    if (_isBiometricChanging) {
      return;
    }

    // =====================================================
    // WEB
    // =====================================================

    if (kIsWeb) {
      _showMessage(
        'Face ID e biometria saranno disponibili '
        'nell’app mobile.',
      );

      return;
    }

    setState(() {
      _isBiometricChanging = true;
    });

    try {
      final preferences =
          await SharedPreferences.getInstance();

      // =====================================================
      // DISATTIVA
      // =====================================================

      if (!value) {
        await preferences.setBool(
          _biometricPreferenceKey,
          false,
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _biometricEnabled = false;
        });

        _showMessage(
          'Accesso biometrico disattivato.',
        );

        return;
      }

      // =====================================================
      // VERIFICA DISPONIBILITA
      // =====================================================

      final available =
          await BiometricService.isAvailable();

      if (!available) {
        if (!mounted) {
          return;
        }

        _showMessage(
          'La biometria non è disponibile '
          'o non è configurata su questo dispositivo.',
        );

        return;
      }

      // =====================================================
      // AUTENTICAZIONE
      // =====================================================

      final authenticated =
          await BiometricService.authenticate();

      if (!mounted) {
        return;
      }

      if (!authenticated) {
        _showMessage(
          'Autenticazione biometrica non riuscita.',
        );

        return;
      }

      await preferences.setBool(
        _biometricPreferenceKey,
        true,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _biometricEnabled = true;
      });

      final name =
          await BiometricService.biometricName();

      if (!mounted) {
        return;
      }

      _showMessage(
        '$name attivato correttamente.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Impossibile modificare '
        'l’impostazione biometrica.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBiometricChanging = false;
        });
      }
    }
  }

  // =========================================================
  // NOTIFICHE
  // =========================================================

  Future<void> _changeNotifications(
    bool value,
  ) async {
    try {
      final preferences =
          await SharedPreferences.getInstance();

      await preferences.setBool(
        _notificationsPreferenceKey,
        value,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _notificationsEnabled = value;
      });

      if (value) {
        _showMessage(
          'Preferenza notifiche attivata. '
          'Le notifiche push verranno collegate successivamente.',
        );
      } else {
        _showMessage(
          'Preferenza notifiche disattivata.',
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Impossibile salvare '
        'l’impostazione notifiche.',
      );
    }
  }

  // =========================================================
  // MESSAGGI
  // =========================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

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
      backgroundColor:
          AppColors.ivory,

      appBar: AppBar(
        automaticallyImplyLeading:
            false,

        leading: IconButton(
          tooltip:
              'Indietro',

          onPressed: () {
            Navigator.of(context)
                .maybePop();
          },

          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
          ),
        ),

        title: const Text(
          'Impostazioni',
        ),
      ),

      body: SafeArea(
        child: _isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(),
              )
            : ListView(
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  30,
                ),
                children: [
                  // =========================================
                  // HEADER
                  // =========================================

                  Center(
                    child: Container(
                      width: 82,
                      height: 82,
                      decoration:
                          const BoxDecoration(
                        color:
                            AppColors.black,
                        shape:
                            BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.settings_outlined,
                        size: 40,
                        color:
                            AppColors.gold,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  const Center(
                    child: Text(
                      'Le Capase Booking',
                      style: TextStyle(
                        color:
                            AppColors.textDark,
                        fontSize: 24,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  Center(
                    child: Text(
                      AppVersion.fullLabel,
                      style:
                          const TextStyle(
                        color:
                            AppColors.textMuted,
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 30,
                  ),

                  // =========================================
                  // SICUREZZA
                  // =========================================

                  const _SectionTitle(
                    title:
                        'Sicurezza',
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  Card(
                    color:
                        Colors.white,

                    child:
                        SwitchListTile(
                      value:
                          _biometricEnabled,

                      activeThumbColor:
                          AppColors.gold,

                      secondary: Icon(
                        kIsWeb
                            ? Icons
                                .security_outlined
                            : Icons
                                .fingerprint_rounded,
                        color:
                            AppColors.goldDark,
                      ),

                      title: Text(
                        _biometricLabel,
                        style:
                            const TextStyle(
                          color:
                              AppColors.textDark,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),

                      subtitle: Text(
                        _biometricSubtitle,
                        style:
                            const TextStyle(
                          color:
                              AppColors.textMuted,
                        ),
                      ),

                      onChanged:
                          _isBiometricChanging
                              ? null
                              : _changeBiometric,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  if (_biometricEnabled)
                    Container(
                      padding:
                          const EdgeInsets.all(
                        14,
                      ),
                      decoration:
                          BoxDecoration(
                        color: Colors.green
                            .withValues(
                          alpha: 0.08,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                        border: Border.all(
                          color: Colors.green
                              .withValues(
                            alpha: 0.25,
                          ),
                        ),
                      ),
                      child:
                          const Row(
                        children: [
                          Icon(
                            Icons
                                .verified_user_outlined,
                            color:
                                Colors.green,
                          ),

                          SizedBox(
                            width: 10,
                          ),

                          Expanded(
                            child: Text(
                              'Protezione biometrica attiva',
                              style:
                                  TextStyle(
                                color:
                                    Colors.green,
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(
                    height: 24,
                  ),

                  // =========================================
                  // NOTIFICHE
                  // =========================================

                  const _SectionTitle(
                    title:
                        'Notifiche',
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  Card(
                    color:
                        Colors.white,

                    child:
                        SwitchListTile(
                      value:
                          _notificationsEnabled,

                      activeThumbColor:
                          AppColors.gold,

                      secondary:
                          const Icon(
                        Icons
                            .notifications_active_outlined,
                        color:
                            AppColors.goldDark,
                      ),

                      title:
                          const Text(
                        'Nuove prenotazioni',
                        style:
                            TextStyle(
                          color:
                              AppColors.textDark,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),

                      subtitle:
                          const Text(
                        'Ricevi una notifica quando arriva '
                        'una nuova prenotazione.',
                        style:
                            TextStyle(
                          color:
                              AppColors.textMuted,
                        ),
                      ),

                      onChanged:
                          _changeNotifications,
                    ),
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  // =========================================
                  // RISTORANTE
                  // =========================================

                  const _SectionTitle(
                    title:
                        'Ristorante',
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  const Card(
                    color:
                        Colors.white,

                    child:
                        ListTile(
                      leading: Icon(
                        Icons.restaurant_outlined,
                        color:
                            AppColors.goldDark,
                      ),

                      title: Text(
                        'Le Capase',
                        style:
                            TextStyle(
                          color:
                              AppColors.textDark,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),

                      subtitle:
                          Text(
                        'Ristorante • Pizzeria',
                        style:
                            TextStyle(
                          color:
                              AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  const Card(
                    color:
                        Colors.white,

                    child:
                        ListTile(
                      leading: Icon(
                        Icons.info_outline,
                        color:
                            AppColors.goldDark,
                      ),

                      title: Text(
                        'Informazioni App',
                        style:
                            TextStyle(
                          color:
                              AppColors.textDark,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),

                      subtitle:
                          Text(
                        'Sistema prenotazioni Le Capase',
                        style:
                            TextStyle(
                          color:
                              AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 30,
                  ),

                  const Center(
                    child: Text(
                      '© Le Capase',
                      style:
                          TextStyle(
                        color:
                            AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ===========================================================
// TITOLO SEZIONE
// ===========================================================

class _SectionTitle
    extends StatelessWidget {
  const _SectionTitle({
    required this.title,
  });

  final String title;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Text(
      title,
      style:
          const TextStyle(
        color:
            AppColors.textDark,
        fontSize: 18,
        fontWeight:
            FontWeight.w700,
      ),
    );
  }
}