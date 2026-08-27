import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'features/customer_booking/customer_home_screen.dart';
import 'features/customer_booking/booking_language.dart';
import 'theme/app_colors.dart';

class LeCapaseCustomerApp extends StatelessWidget {
  const LeCapaseCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
    );

    return ValueListenableBuilder<String>(
      valueListenable: bookingLanguage,
      builder: (context, language, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: language == 'it' ? 'Prenota da Le Capase' : 'Book at Le Capase',

        locale: bookingLocale,

        supportedLocales: bookingSupportedLocales,

        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],

        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: AppColors.ivory,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.gold,
            brightness: Brightness.light,
          ),
          textTheme: GoogleFonts.libreBaskervilleTextTheme(baseTheme.textTheme),
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.ivory,
            foregroundColor: AppColors.textDark,
            centerTitle: true,
            elevation: 0,
            titleTextStyle: GoogleFonts.libreBaskerville(
              color: AppColors.textDark,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.black,
              textStyle: GoogleFonts.libreBaskerville(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textDark,
              side: const BorderSide(color: AppColors.gold),
              textStyle: GoogleFonts.libreBaskerville(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            labelStyle: GoogleFonts.libreBaskerville(
              color: AppColors.textMuted,
            ),
            hintStyle: GoogleFonts.libreBaskerville(color: AppColors.textMuted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.ivoryDark),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.ivoryDark),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.gold, width: 2),
            ),
          ),
        ),

        home: const CustomerHomeScreen(),
      ),
    );
  }
}
