import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import 'customer_booking_screen.dart';
import 'booking_language.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.black,
    body: LayoutBuilder(
      builder: (context, viewport) {
        final desktop = viewport.maxWidth >= 900;
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/booking_home_fireplace_v2.jpeg',
              fit: BoxFit.cover,
              alignment: desktop ? Alignment.center : const Alignment(-0.55, 0),
              filterQuality: FilterQuality.high,
              excludeFromSemantics: true,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xB3000000),
                    Color(0x80000000),
                    Color(0x08000000),
                    Color(0x80000000),
                  ],
                  stops: [0, 0.20, 0.50, 1],
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, safeViewport) {
                  final short = safeViewport.maxHeight < 700;
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: safeViewport.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            desktop ? 56 : 20,
                            12,
                            desktop ? 56 : 20,
                            24,
                          ),
                          child: Column(
                            children: [
                              Center(
                                child: SizedBox(
                                  height: short ? 140 : 175,
                                  child: Transform.scale(
                                    scale: 1.55,
                                    child: Image.asset(
                                      'assets/images/logo.png',
                                      fit: BoxFit.contain,
                                      filterQuality: FilterQuality.high,
                                      isAntiAlias: true,
                                      semanticLabel:
                                          'Le Capase · Ristorante Pizzeria d’autore',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 110),
                              const Spacer(),
                              Align(
                                alignment: desktop
                                    ? Alignment.centerRight
                                    : Alignment.center,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 540,
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.fromLTRB(
                                      22,
                                      short ? 20 : 24,
                                      22,
                                      22,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.black.withValues(
                                        alpha: 0.57,
                                      ),
                                      borderRadius: BorderRadius.circular(26),
                                      border: Border.all(
                                        color: AppColors.gold.withValues(
                                          alpha: 0.72,
                                        ),
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x30000000),
                                          blurRadius: 24,
                                          offset: Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
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
                                            fontSize: short ? 26 : 29,
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
                                            color: Colors.white.withValues(
                                              alpha: 0.92,
                                            ),
                                            fontSize: 15,
                                            height: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 22),
                                        SizedBox(
                                          width: double.infinity,
                                          child: FilledButton.icon(
                                            onPressed: () =>
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const CustomerBookingScreen(),
                                                  ),
                                                ),
                                            style: FilledButton.styleFrom(
                                              minimumSize: const Size(0, 58),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 17,
                                                  ),
                                              backgroundColor: AppColors.gold,
                                              foregroundColor: AppColors.black,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
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
                                              textAlign: TextAlign.center,
                                              style:
                                                  GoogleFonts.libreBaskerville(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.4,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 15),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.location_on_outlined,
                                              color: AppColors.gold,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Cisternino · Puglia',
                                              style:
                                                  GoogleFonts.libreBaskerville(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.88,
                                                        ),
                                                    fontSize: 12,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Positioned(
              top: 14,
              right: 16,
              child: SafeArea(child: BookingLanguageToggle()),
            ),
          ],
        );
      },
    ),
  );
}
