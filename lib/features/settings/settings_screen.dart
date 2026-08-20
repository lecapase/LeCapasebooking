import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_version.dart';
import '../../services/biometric_service.dart';
import '../../services/push_notification_service.dart';
import '../../theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _biometricPreferenceKey = 'biometric_enabled';
  static const String _notificationsPreferenceKey = 'notifications_enabled';

  bool _biometricEnabled = false;
  bool _notificationsEnabled = false;
  bool _isLoading = true;
  bool _isBiometricChanging = false;
  bool _isNotificationsChanging = false;

  String _biometricLabel = 'Accesso biometrico / Face ID';
  String _biometricSubtitle =
      'Richiedi Face ID o biometria per entrare nel gestionale.';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final preferences = await SharedPreferences.getInstance();

      final biometricEnabled =
          preferences.getBool(_biometricPreferenceKey) ?? false;

      var notificationsEnabled =
          preferences.getBool(_notificationsPreferenceKey) ?? false;

      var biometricLabel = 'Accesso biometrico / Face ID';
      var biometricSubtitle =
          'Richiedi Face ID o biometria per entrare nel gestionale.';

      if (kIsWeb) {
        biometricLabel = 'Accesso con Face ID / impronta';
        biometricSubtitle = 'Sarà disponibile tramite passkey del dispositivo.';
      } else {
        final biometricName = await BiometricService.biometricName();
        final available = await BiometricService.isAvailable();

        biometricLabel = 'Accesso con $biometricName';

        if (!available) {
          biometricSubtitle =
              'Nessuna biometria configurata su questo dispositivo.';
        }
      }

      final notificationStatus =
          await PushNotificationService.getPermissionStatus();

      final permissionGranted =
          notificationStatus == AuthorizationStatus.authorized ||
          notificationStatus == AuthorizationStatus.provisional;

      if (!permissionGranted) {
        notificationsEnabled = false;
        await preferences.setBool(_notificationsPreferenceKey, false);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _biometricEnabled = biometricEnabled;
        _notificationsEnabled = notificationsEnabled;
        _biometricLabel = biometricLabel;
        _biometricSubtitle = biometricSubtitle;
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

  Future<void> _changeBiometric(bool value) async {
    if (_isBiometricChanging) {
      return;
    }

    if (kIsWeb) {
      _showMessage(
        'L’accesso con Face ID o impronta tramite passkey '
        'sarà la prossima integrazione del Gestionale.',
      );
      return;
    }

    setState(() {
      _isBiometricChanging = true;
    });

    try {
      final preferences = await SharedPreferences.getInstance();

      if (!value) {
        await preferences.setBool(_biometricPreferenceKey, false);

        if (!mounted) {
          return;
        }

        setState(() {
          _biometricEnabled = false;
        });

        _showMessage('Accesso biometrico disattivato.');
        return;
      }

      final available = await BiometricService.isAvailable();

      if (!available) {
        _showMessage(
          'La biometria non è disponibile '
          'o non è configurata su questo dispositivo.',
        );
        return;
      }

      final authenticated = await BiometricService.authenticate();

      if (!authenticated) {
        _showMessage('Autenticazione biometrica non riuscita.');
        return;
      }

      await preferences.setBool(_biometricPreferenceKey, true);

      final name = await BiometricService.biometricName();

      if (!mounted) {
        return;
      }

      setState(() {
        _biometricEnabled = true;
      });

      _showMessage('$name attivato correttamente.');
    } catch (_) {
      _showMessage('Impossibile modificare l’impostazione biometrica.');
    } finally {
      if (mounted) {
        setState(() {
          _isBiometricChanging = false;
        });
      }
    }
  }

  Future<void> _changeNotifications(bool value) async {
    if (_isNotificationsChanging) {
      return;
    }

    setState(() {
      _isNotificationsChanging = true;
    });

    try {
      final preferences = await SharedPreferences.getInstance();

      if (!value) {
        await preferences.setBool(_notificationsPreferenceKey, false);

        if (!mounted) {
          return;
        }

        setState(() {
          _notificationsEnabled = false;
        });

        _showMessage('Notifiche disattivate su questo dispositivo.');
        return;
      }

      var enabled = false;

      if (kIsWeb) {
        enabled = await PushNotificationService.enableWebNotifications();
      } else {
        await PushNotificationService.initialize();

        final status = await PushNotificationService.getPermissionStatus();

        enabled =
            status == AuthorizationStatus.authorized ||
            status == AuthorizationStatus.provisional;
      }

      await preferences.setBool(_notificationsPreferenceKey, enabled);

      if (!mounted) {
        return;
      }

      setState(() {
        _notificationsEnabled = enabled;
      });

      if (enabled) {
        _showMessage(
          'Notifiche attivate correttamente per questo dispositivo.',
        );
      } else {
        _showMessage(
          'Permesso non concesso. '
          'Consenti le notifiche dal browser e riprova.',
        );
      }
    } catch (_) {
      _showMessage('Non è stato possibile attivare le notifiche.');
    } finally {
      if (mounted) {
        setState(() {
          _isNotificationsChanging = false;
        });
      }
    }
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
    return Scaffold(
      backgroundColor: AppColors.ivory,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Indietro',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('Impostazioni'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                children: [
                  Center(
                    child: Container(
                      width: 82,
                      height: 82,
                      decoration: const BoxDecoration(
                        color: AppColors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.settings_outlined,
                        size: 40,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Center(
                    child: Text(
                      'Le Capase Booking',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      AppVersion.fullLabel,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const _SectionTitle(title: 'Sicurezza'),
                  const SizedBox(height: 10),
                  Card(
                    color: Colors.white,
                    child: SwitchListTile(
                      value: _biometricEnabled,
                      activeThumbColor: AppColors.gold,
                      secondary: Icon(
                        kIsWeb
                            ? Icons.security_outlined
                            : Icons.fingerprint_rounded,
                        color: AppColors.goldDark,
                      ),
                      title: Text(
                        _biometricLabel,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        _biometricSubtitle,
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                      onChanged: _isBiometricChanging ? null : _changeBiometric,
                    ),
                  ),
                  if (_biometricEnabled) ...[
                    const SizedBox(height: 8),
                    _successBox(
                      icon: Icons.verified_user_outlined,
                      text: 'Protezione biometrica attiva',
                    ),
                  ],
                  const SizedBox(height: 24),
                  const _SectionTitle(title: 'Notifiche'),
                  const SizedBox(height: 10),
                  Card(
                    color: Colors.white,
                    child: SwitchListTile(
                      value: _notificationsEnabled,
                      activeThumbColor: AppColors.gold,
                      secondary: const Icon(
                        Icons.notifications_active_outlined,
                        color: AppColors.goldDark,
                      ),
                      title: const Text(
                        'Nuove prenotazioni',
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        _notificationsEnabled
                            ? 'Notifiche attive su questo dispositivo.'
                            : 'Ricevi un avviso per ogni nuova prenotazione.',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                      onChanged: _isNotificationsChanging
                          ? null
                          : _changeNotifications,
                    ),
                  ),
                  if (_isNotificationsChanging)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      ),
                    ),
                  if (_notificationsEnabled) ...[
                    const SizedBox(height: 8),
                    _successBox(
                      icon: Icons.notifications_active_outlined,
                      text: 'Questo dispositivo riceverà le nuove prenotazioni',
                    ),
                  ],
                  const SizedBox(height: 24),
                  const _SectionTitle(title: 'Ristorante'),
                  const SizedBox(height: 10),
                  const Card(
                    color: Colors.white,
                    child: ListTile(
                      leading: Icon(
                        Icons.restaurant_outlined,
                        color: AppColors.goldDark,
                      ),
                      title: Text(
                        'Le Capase',
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        'Ristorante • Pizzeria',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Card(
                    color: Colors.white,
                    child: ListTile(
                      leading: Icon(
                        Icons.info_outline,
                        color: AppColors.goldDark,
                      ),
                      title: Text(
                        'Informazioni App',
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        'Sistema prenotazioni Le Capase',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Center(
                    child: Text(
                      '© Le Capase',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _successBox({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textDark,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
