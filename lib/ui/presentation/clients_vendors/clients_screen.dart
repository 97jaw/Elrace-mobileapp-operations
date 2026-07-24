import 'dart:ui';

import 'package:el_race/core/clients_vendors/clients_vendors_route_names.dart';
import 'package:el_race/ui/presentation/clients_vendors/theme/clients_vendors_theme.dart';
import 'package:el_race/ui/presentation/clients_vendors/widgets/clients_invoicing_section.dart';
import 'package:el_race/ui/presentation/clients_vendors/widgets/clients_list_chrome.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Clients tab under Client & Vendors — feature cards + invoicing dashboard
/// (filters / chart / AR & collections tiles).
class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  ClientsVendorsTheme.deepLight,
                  ClientsVendorsTheme.deepMid,
                  ClientsVendorsTheme.deepDark,
                ],
              ),
            ),
          ),
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.35, -0.55),
                  radius: 0.9,
                  colors: [
                    ClientsVendorsTheme.glowBright,
                    ClientsVendorsTheme.glowMid,
                    ClientsVendorsTheme.glowSoft,
                    ClientsVendorsTheme.glowEdge,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.25, 0.45, 0.65, 1.0],
                ),
              ),
            ),
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.2, -0.3),
                  radius: 1.3,
                  colors: [Colors.transparent, Color(0x66001233)],
                  stops: [0.55, 1.0],
                ),
              ),
            ),
          ),
          const IgnorePointer(
            child: Opacity(
              opacity: 0.05,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.transparent,
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.35, 0.6, 0.9],
                  ),
                ),
              ),
            ),
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ContextualGlassChromeHeader(
                showBack: false,
                onLightSurface: false,
                transparentGlassBar: true,
                logoOpacity: 0.7,
              ),
              Expanded(child: _ClientsDashboardBody()),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClientsDashboardBody extends StatelessWidget {
  const _ClientsDashboardBody();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 228,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: PressableScale(
                    onTap: () => Navigator.of(context).pushNamed(
                      ClientsVendorsRouteNames.accountsReceivable,
                    ),
                    child: const _ClientsFeatureCard(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Accounts Receivable',
                      slogan: 'Track amounts owed by clients in real time.',
                      gradientTop: ClientsVendorsTheme.cardGradientTop,
                      gradientBottom: ClientsVendorsTheme.cardGradientBottom,
                      tiltY: -0.06,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: PressableScale(
                    onTap: () => Navigator.of(context).pushNamed(
                      ClientsVendorsRouteNames.outstandingInvoices,
                    ),
                    child: const _ClientsFeatureCard(
                      icon: Icons.receipt_long_rounded,
                      title: 'Outstanding Invoices',
                      slogan: 'Stay ahead of unpaid invoices before overdue.',
                      gradientTop: ClientsVendorsTheme.cardGradientTopAlt,
                      gradientBottom: ClientsVendorsTheme.cardGradientBottomAlt,
                      tiltY: 0.06,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const ClientsInvoicingSection(),
        ],
      ),
    );
  }
}

/// Feature card: dark-blue gradient, centered icon/title/slogan, thin footer
/// border strip, slight 3D tilt + elevation shadow.
class _ClientsFeatureCard extends StatelessWidget {
  const _ClientsFeatureCard({
    required this.icon,
    required this.title,
    required this.slogan,
    required this.gradientTop,
    required this.gradientBottom,
    this.tiltY = 0,
  });

  final IconData icon;
  final String title;
  final String slogan;
  final Color gradientTop;
  final Color gradientBottom;
  final double tiltY;

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0016)
        ..rotateX(0.05)
        ..rotateY(tiltY),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: gradientBottom.withValues(alpha: 0.55),
              blurRadius: 26,
              offset: const Offset(0, 18),
              spreadRadius: -8,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [gradientTop, gradientBottom],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
              ),
            ),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0x33FFFFFF),
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.55],
                        ),
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _IconGlow(
                              icon: icon,
                              color: ClientsVendorsTheme.iconAccent,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              slogan,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.72),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      height: 28,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconGlow extends StatelessWidget {
  const _IconGlow({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.55),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          Icon(
            icon,
            size: 32,
            color: color,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
