import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'features/customer_booking/customer_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const LeCapaseBookingPublicApp());
}

class LeCapaseBookingPublicApp extends StatelessWidget {
  const LeCapaseBookingPublicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Le Capase - Prenota',
      locale: Locale('it', 'IT'),
      supportedLocales: [Locale('it', 'IT')],
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
    );
  }
}
