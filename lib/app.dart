import 'package:flutter/material.dart';

import 'features/auth/admin_login_screen.dart';
import 'features/customer_booking/customer_booking_screen.dart';
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
          ),
        ),
      ),

      home: const AppEntryScreen(),
    );
  }
}

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
                      fontWeight: FontWeight.bold,
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
                              const AdminLoginScreen(),
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