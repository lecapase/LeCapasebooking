import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import 'customer_booking_screen.dart';
import 'booking_language.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  void _openBooking(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CustomerBookingScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/booking_home.jpeg',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),

          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x8A000000),
                  Color(0x12000000),
                  Color(0x33000000),
                  Color(0xE8000000),
                ],
                stops: [0, 0.35, 0.60, 1],
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
                  child: Column(
                    children: [
                      // Logo ingrandito
                      SizedBox(
                        height: 190,
                        child: Transform.scale(
                          scale: 1.55,
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            isAntiAlias: true,
                          ),
                        ),
                      ),

                      const Spacer(),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                        decoration: BoxDecoration(
                          color: AppColors.black.withValues(alpha: 0.76),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.52),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 28,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              bookingText(
                                context,
                                'Benvenuti a\nLe Capase',
                                'Welcome to\nLe Capase',
                              ),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.libreBaskerville(
                                color: AppColors.white,
                                fontSize: 29,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),

                            const SizedBox(height: 12),

                            Text(
                              bookingText(
                                context,
                                'Prenota il tuo tavolo e vivi una serata nel cuore di Cisternino.',
                                'Book your table and enjoy an evening in the heart of Cisternino.',
                              ),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.libreBaskerville(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 15,
                                height: 1.55,
                              ),
                            ),

                            const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              height: 58,
                              child: FilledButton.icon(
                                onPressed: () {
                                  _openBooking(context);
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.gold,
                                  foregroundColor: AppColors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.calendar_month_outlined,
                                  size: 22,
                                ),
                                label: Text(
                                  bookingText(
                                    context,
                                    'PRENOTA UN TAVOLO',
                                    'BOOK A TABLE',
                                  ),
                                  style: GoogleFonts.libreBaskerville(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 15),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  color: AppColors.gold,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Cisternino · Puglia',
                                  style: GoogleFonts.libreBaskerville(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            top: 14,
            right: 16,
            child: SafeArea(child: BookingLanguageToggle()),
          ),
        ],
      ),
    );
  }
}
