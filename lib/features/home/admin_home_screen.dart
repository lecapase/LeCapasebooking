import 'package:flutter/material.dart';

import '../../core/app_version.dart';
import '../../theme/app_colors.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({
    super.key,
    required this.onBookings,
    required this.onAvailability,
    required this.onExceptions,
    required this.onSettings,
    required this.onLock,
    required this.onLogout,
  });

  final VoidCallback onBookings;
  final VoidCallback onAvailability;
  final VoidCallback onExceptions;
  final VoidCallback onSettings;

  final Future<void> Function() onLock;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.ivory,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.gold,
          brightness: Brightness.light,
        ),
      ),
      child: Scaffold(
        backgroundColor: AppColors.ivory,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 1050,
                  ),
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _buildHeader(
                          context,
                        ),
                      ),
                      SliverPadding(
                        padding:
                            const EdgeInsets.fromLTRB(
                          24,
                          30,
                          24,
                          70,
                        ),
                        sliver:
                            SliverToBoxAdapter(
                          child:
                              _buildContent(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Positioned(
                right: 18,
                bottom: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color:
                        AppColors.black.withValues(
                      alpha: 0.88,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: Text(
                    AppVersion.fullLabel,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _buildHeader(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          24,
          14,
          24,
          28,
        ),
        child: Column(
          children: [
            // =================================================
            // AZIONI SUPERIORI
            // =================================================

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await onLock();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor:
                        AppColors.gold,
                  ),
                  icon: const Icon(
                    Icons.lock_outline_rounded,
                    size: 19,
                  ),
                  label: const Text(
                    'Blocca',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 6,
                ),

                TextButton.icon(
                  onPressed: () async {
                    await _confirmLogout(
                      context,
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor:
                        AppColors.gold,
                  ),
                  icon: const Icon(
                    Icons.logout_rounded,
                    size: 19,
                  ),
                  label: const Text(
                    'Logout',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            Image.asset(
              'assets/images/logo.png',
              height: 210,
              fit: BoxFit.contain,
            ),

            const SizedBox(
              height: 8,
            ),

            const Text(
              'GESTIONALE',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
                fontFamily: 'Georgia',
              ),
            ),

            const SizedBox(
              height: 6,
            ),

            const Text(
              'Le Capase Booking',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
                fontFamily: 'Georgia',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // CONFERMA LOGOUT
  // =========================================================

  Future<void> _confirmLogout(
    BuildContext context,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Uscire dal gestionale?',
          ),
          content: const Text(
            'Il logout richiederà nuovamente '
            'email e password al prossimo accesso.\n\n'
            'Se vuoi solo proteggere il gestionale, '
            'usa “Blocca”.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                'ANNULLA',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child: const Text(
                'LOGOUT',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await onLogout();
  }

  // =========================================================
  // CONTENUTO
  // =========================================================

  Widget _buildContent() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Cosa vuoi fare?',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            fontFamily: 'Georgia',
          ),
        ),

        const SizedBox(
          height: 5,
        ),

        const Text(
          'Gestisci il ristorante da un unico posto.',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 15,
          ),
        ),

        const SizedBox(
          height: 26,
        ),

        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final desktop =
                constraints.maxWidth >= 720;

            final cardWidth =
                desktop
                    ? (constraints.maxWidth -
                            18) /
                        2
                    : constraints.maxWidth;

            return Wrap(
              spacing: 18,
              runSpacing: 18,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _AdminMenuCard(
                    icon:
                        Icons.event_note_outlined,
                    title:
                        'Prenotazioni',
                    subtitle:
                        'Visualizza, conferma e gestisci '
                        'le prenotazioni.',
                    accent: true,
                    onTap:
                        onBookings,
                  ),
                ),

                SizedBox(
                  width: cardWidth,
                  child: _AdminMenuCard(
                    icon:
                        Icons.schedule_outlined,
                    title:
                        'Disponibilità online',
                    subtitle:
                        'Gestisci servizi, orari, coperti '
                        'e fasce prenotabili.',
                    onTap:
                        onAvailability,
                  ),
                ),

                SizedBox(
                  width: cardWidth,
                  child: _AdminMenuCard(
                    icon:
                        Icons.event_busy_outlined,
                    title:
                        'Eccezioni e chiusure',
                    subtitle:
                        'Modifica disponibilità e chiusure '
                        'per singole date.',
                    onTap:
                        onExceptions,
                  ),
                ),

                SizedBox(
                  width: cardWidth,
                  child: _AdminMenuCard(
                    icon:
                        Icons.settings_outlined,
                    title:
                        'Impostazioni',
                    subtitle:
                        'Configura il gestionale e le '
                        'preferenze operative.',
                    onTap:
                        onSettings,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ===========================================================
// CARD MENU
// ===========================================================

class _AdminMenuCard
    extends StatelessWidget {
  const _AdminMenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color: accent
          ? AppColors.black
          : Colors.white,
      borderRadius:
          BorderRadius.circular(
        22,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        child: Container(
          constraints:
              const BoxConstraints(
            minHeight: 165,
          ),
          padding:
              const EdgeInsets.all(
            22,
          ),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              22,
            ),
            border: Border.all(
              color: accent
                  ? AppColors.gold
                      .withValues(
                      alpha: 0.45,
                    )
                  : AppColors.ivoryDark,
            ),
            boxShadow: const [
              BoxShadow(
                color:
                    Color(0x12000000),
                blurRadius: 20,
                offset:
                    Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration:
                    BoxDecoration(
                  color: accent
                      ? AppColors.gold
                      : AppColors.goldSoft,
                  shape:
                      BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: accent
                      ? AppColors.black
                      : AppColors.goldDark,
                  size: 29,
                ),
              ),

              const SizedBox(
                width: 18,
              ),

              Expanded(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: accent
                            ? AppColors.white
                            : AppColors.textDark,
                        fontSize: 20,
                        fontWeight:
                            FontWeight.w700,
                        fontFamily:
                            'Georgia',
                      ),
                    ),

                    const SizedBox(
                      height: 7,
                    ),

                    Text(
                      subtitle,
                      style: TextStyle(
                        color: accent
                            ? Colors.white60
                            : AppColors.textMuted,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              const Icon(
                Icons.arrow_forward_ios_rounded,
                color:
                    AppColors.gold,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}