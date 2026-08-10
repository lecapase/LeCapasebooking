import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/auth/admin_login_screen.dart';
import 'features/availability/availability_screen.dart';
import 'features/bookings/bookings_screen.dart';
import 'features/customer_booking/customer_booking_screen.dart';
import 'features/home/admin_home_screen.dart';
import 'features/settings/settings_screen.dart';
import 'services/biometric_service.dart';
import 'theme/app_colors.dart';

class LeCapaseApp extends StatelessWidget {
  const LeCapaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Le Capase Booking',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.gold,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.dark,
          foregroundColor: AppColors.white,
          centerTitle: true,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: AppColors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            fontFamily: 'Georgia',
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.dark,
          indicatorColor: AppColors.gold.withValues(
            alpha: 0.2,
          ),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(
              color: Colors.white,
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.dark,
            minimumSize: const Size(
              double.infinity,
              55,
            ),
          ),
        ),
        cardTheme: const CardThemeData(
          color: AppColors.card,
          elevation: 4,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            color: Colors.white,
          ),
          bodyMedium: TextStyle(
            color: Colors.white,
          ),
          titleLarge: TextStyle(
            color: Colors.white,
            fontFamily: 'Georgia',
            fontWeight: FontWeight.w700,
          ),
          titleMedium: TextStyle(
            color: Colors.white,
            fontFamily: 'Georgia',
            fontWeight: FontWeight.w700,
          ),
          headlineLarge: TextStyle(
            color: Colors.white,
            fontFamily: 'Georgia',
            fontWeight: FontWeight.w700,
          ),
          headlineMedium: TextStyle(
            color: Colors.white,
            fontFamily: 'Georgia',
            fontWeight: FontWeight.w700,
          ),
          headlineSmall: TextStyle(
            color: Colors.white,
            fontFamily: 'Georgia',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      home: const AppEntryScreen(),
    );
  }
}

// ===========================================================
// SCHERMATA INIZIALE
// ===========================================================

class AppEntryScreen extends StatelessWidget {
  const AppEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 500,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 150,
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    'Le Capase Booking',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Georgia',
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Scegli dove entrare',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 40),

                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const AdminAuthGate(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.admin_panel_settings_outlined,
                    ),
                    label: const Text(
                      'GESTIONALE',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.gold,
                      side: const BorderSide(
                        color: AppColors.gold,
                      ),
                      minimumSize: const Size(
                        double.infinity,
                        55,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const CustomerBookingScreen(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.restaurant_outlined,
                    ),
                    label: const Text(
                      'PRENOTAZIONE CLIENTE',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    'Schermata temporanea di sviluppo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
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

// ===========================================================
// AUTH GATE
// ===========================================================

class AdminAuthGate extends StatelessWidget {
  const AdminAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.data == null) {
          return const AdminLoginScreen();
        }

        return const BiometricGate();
      },
    );
  }
}

// ===========================================================
// BIOMETRIC GATE
// ===========================================================

class BiometricGate extends StatefulWidget {
  const BiometricGate({
    super.key,
  });

  @override
  State<BiometricGate> createState() =>
      _BiometricGateState();
}

class _BiometricGateState
    extends State<BiometricGate> {
  bool _isLoading = true;
  bool _isUnlocked = false;
  bool _biometricRequired = false;

  @override
  void initState() {
    super.initState();

    _checkAccess();
  }

  // =========================================================
  // CONTROLLO ACCESSO INIZIALE
  // =========================================================

  Future<void> _checkAccess() async {
    if (kIsWeb) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _isUnlocked = true;
      });

      return;
    }

    try {
      final preferences =
          await SharedPreferences.getInstance();

      final biometricEnabled =
          preferences.getBool(
                'biometric_enabled',
              ) ??
              false;

      if (!biometricEnabled) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoading = false;
          _isUnlocked = true;
          _biometricRequired = false;
        });

        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _biometricRequired = true;
      });

      final authenticated =
          await BiometricService.authenticate();

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _isUnlocked = authenticated;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _isUnlocked = false;
      });
    }
  }

  // =========================================================
  // BLOCCA APP
  // =========================================================

  Future<void> _lockApp() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Il blocco biometrico è disponibile '
              'nell’app mobile.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );

      return;
    }

    final preferences =
        await SharedPreferences.getInstance();

    final biometricEnabled =
        preferences.getBool(
              'biometric_enabled',
            ) ??
            false;

    if (!biometricEnabled) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Attiva prima la biometria '
              'nelle Impostazioni.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );

      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _biometricRequired = true;
      _isUnlocked = false;
      _isLoading = false;
    });
  }

  // =========================================================
  // RIPROVA BIOMETRIA
  // =========================================================

  Future<void> _retryBiometric() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authenticated =
        await BiometricService.authenticate();

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _isUnlocked = authenticated;
    });
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isUnlocked) {
      return _buildHome(
        context,
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Accesso protetto',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(
              24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 420,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.fingerprint_rounded,
                    size: 78,
                    color: AppColors.gold,
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Gestionale bloccato',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Georgia',
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    _biometricRequired
                        ? 'Usa la biometria del dispositivo '
                            'per accedere a Le Capase Booking.'
                        : 'Autenticazione biometrica '
                            'non disponibile.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 28),

                  FilledButton.icon(
                    onPressed: _retryBiometric,
                    icon: const Icon(
                      Icons.fingerprint_rounded,
                    ),
                    label: const Text(
                      'SBLOCCA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextButton.icon(
                    onPressed: () async {
                      await FirebaseAuth.instance
                          .signOut();
                    },
                    icon: const Icon(
                      Icons.logout_rounded,
                    ),
                    label: const Text(
                      'ACCEDI CON UN ALTRO ACCOUNT',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // HOME
  // =========================================================

  Widget _buildHome(
    BuildContext context,
  ) {
    return AdminHomeScreen(
      onBookings: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                const BookingsScreen(),
          ),
        );
      },

      onAvailability: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                const AvailabilityScreen(),
          ),
        );
      },

      onExceptions: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                const AvailabilityScreen(),
          ),
        );
      },

      onSettings: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                const SettingsScreen(),
          ),
        );
      },

      onLock: _lockApp,

      onLogout: () async {
        await FirebaseAuth.instance.signOut();
      },
    );
  }
}