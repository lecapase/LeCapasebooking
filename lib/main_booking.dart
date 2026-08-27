import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'services/firebase_app_check_service.dart';
import 'features/customer_booking/customer_home_screen.dart';
import 'features/customer_booking/booking_language.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await initializeFirebaseAppCheck();

  runApp(const LeCapaseBookingPublicApp());
}

class LeCapaseBookingPublicApp extends StatelessWidget {
  const LeCapaseBookingPublicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: bookingLanguage,
      builder: (context, language, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: language == 'it' ? 'Le Capase - Prenota' : 'Le Capase - Book',
        locale: bookingLocale,
        supportedLocales: bookingSupportedLocales,
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFC8A45D),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF7F3EB),
        ),
        home: const CustomerHomeScreen(),
      ),
    );
  }
}
