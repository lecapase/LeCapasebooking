import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/auth/admin_login_screen.dart';
import 'features/auth/first_login_prompt.dart';
import 'features/bookings/bookings_screen.dart';
import 'services/biometric_service.dart';
import 'services/push_notification_service.dart';
import 'theme/app_colors.dart';

class LeCapaseApp extends StatelessWidget {
  const LeCapaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Le Capase Booking Gestionale',
      locale: const Locale('it', 'IT'),
      supportedLocales: const [Locale('it', 'IT')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.gold,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.libreBaskervilleTextTheme(
          baseTheme.textTheme,
        ).apply(bodyColor: Colors.white, displayColor: Colors.white),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.dark,
          foregroundColor: AppColors.white,
          centerTitle: true,
          elevation: 0,
          titleTextStyle: GoogleFonts.libreBaskerville(
            color: AppColors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.dark,
          indicatorColor: AppColors.gold.withValues(alpha: 0.2),
          labelTextStyle: WidgetStateProperty.all(
            GoogleFonts.libreBaskerville(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.dark,
            minimumSize: const Size(double.infinity, 55),
            textStyle: GoogleFonts.libreBaskerville(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            textStyle: GoogleFonts.libreBaskerville(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: GoogleFonts.libreBaskerville(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        cardTheme: const CardThemeData(color: AppColors.card, elevation: 4),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: GoogleFonts.libreBaskerville(),
          hintStyle: GoogleFonts.libreBaskerville(color: Colors.grey),
        ),
        dialogTheme: DialogThemeData(
          titleTextStyle: GoogleFonts.libreBaskerville(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
          contentTextStyle: GoogleFonts.libreBaskerville(
            color: Colors.white70,
            fontSize: 15,
          ),
        ),
      ),
      home: const AdminAuthGate(),
    );
  }
}

class AdminAuthGate extends StatelessWidget {
  const AdminAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == null) {
          return const AdminLoginScreen();
        }

        return StaffAccessGate(user: snapshot.data!);
      },
    );
  }
}

class StaffAccessGate extends StatelessWidget {
  const StaffAccessGate({super.key, required this.user});

  final User user;

  Widget _loading() {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  Widget _accessDenied(String message) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Le Capase Booking'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_person_outlined,
                  size: 58,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Accesso non autorizzato',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Esci'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staffReference = FirebaseFirestore.instance
        .collection('staff_users')
        .doc(user.uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: staffReference.snapshots(),
      builder: (context, staffSnapshot) {
        if (staffSnapshot.connectionState == ConnectionState.waiting) {
          return _loading();
        }

        if (staffSnapshot.hasData && staffSnapshot.data!.exists) {
          final data = staffSnapshot.data!.data() ?? {};

          final active = data['active'] == true;
          final role = (data['role'] ?? '').toString();

          const allowedRoles = {'staff', 'supervisor', 'manager', 'admin'};

          if (!active) {
            return _accessDenied('Questo account è stato disattivato.');
          }

          if (!allowedRoles.contains(role)) {
            return _accessDenied(
              'Il ruolo assegnato a questo account non è valido.',
            );
          }

          final displayName =
              (data['displayName'] ??
                      user.displayName ??
                      user.email ??
                      'Utente')
                  .toString();

          final email = (data['email'] ?? user.email ?? '').toString();

          return BiometricGate(
            displayName: displayName,
            email: email,
            role: role,
          );
        }

        // Compatibilità con l'amministratore storico.
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('admins')
              .doc(user.uid)
              .get(),
          builder: (context, adminSnapshot) {
            if (adminSnapshot.connectionState == ConnectionState.waiting) {
              return _loading();
            }

            if (adminSnapshot.hasData && adminSnapshot.data!.exists) {
              final data = adminSnapshot.data!.data() ?? {};

              return BiometricGate(
                displayName:
                    (data['displayName'] ??
                            user.displayName ??
                            user.email ??
                            'Amministratore')
                        .toString(),
                email: (data['email'] ?? user.email ?? '').toString(),
                role: 'admin',
              );
            }

            return _accessDenied(
              'Questo account non dispone dei permessi per accedere al gestionale.',
            );
          },
        );
      },
    );
  }
}

class BiometricGate extends StatefulWidget {
  const BiometricGate({
    super.key,
    required this.displayName,
    required this.email,
    required this.role,
  });

  final String displayName;
  final String email;
  final String role;

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate> {
  bool _isLoading = true;
  bool _isUnlocked = false;
  bool _biometricRequired = false;
  bool _pushInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

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
      final preferences = await SharedPreferences.getInstance();

      final biometricEnabled =
          preferences.getBool('biometric_enabled') ?? false;

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

      final authenticated = await BiometricService.authenticate();

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

  Future<void> _initializePushIfNeeded() async {
    if (_pushInitialized) {
      return;
    }

    _pushInitialized = true;

    try {
      await PushNotificationService.initialize();
    } catch (_) {
      _pushInitialized = false;
    }
  }

  Future<void> _lockApp() async {
    if (kIsWeb) {
      if (!mounted) {
        return;
      }

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

    final preferences = await SharedPreferences.getInstance();

    final biometricEnabled = preferences.getBool('biometric_enabled') ?? false;

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

  Future<void> _retryBiometric() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authenticated = await BiometricService.authenticate();

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _isUnlocked = authenticated;
    });
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isUnlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializePushIfNeeded();
      });

      return FirstLoginPrompt(
        child: BookingsScreen(
          onLock: _lockApp,
          onLogout: _signOut,
          displayName: widget.displayName,
          email: widget.email,
          userRole: widget.role,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Accesso protetto',
          style: GoogleFonts.libreBaskerville(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.fingerprint_rounded,
                    size: 78,
                    color: AppColors.gold,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Gestionale bloccato',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.libreBaskerville(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
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
                    style: GoogleFonts.libreBaskerville(
                      color: Colors.grey,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _retryBiometric,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: Text(
                      'SBLOCCA',
                      style: GoogleFonts.libreBaskerville(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(
                      'ACCEDI CON UN ALTRO ACCOUNT',
                      style: GoogleFonts.libreBaskerville(
                        fontWeight: FontWeight.w700,
                      ),
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
