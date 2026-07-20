import 'dart:ui';

import 'package:flutter/material.dart';

/// Clients tab under Client & Vendors. Intentionally empty for now — this
/// is the shell (background + app bar) the real client list will be built
/// into next.
///
/// Background is layered rather than one flat diagonal sweep, to match the
/// reference screenshot: a deep-navy base with a soft, blurred glow
/// concentrated toward the upper-left, plus a faint diagonal sheen for a
/// bit of metallic/glass depth. All colors are the exact hex values from
/// the screenshot.
class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  // Deep tier — the base, covers most of the screen.
  static const _deepLight = Color(0xFF014894);
  static const _deepMid = Color(0xFF024790);
  static const _deepDark = Color(0xFF03468C);

  // Bright tier — glow only, not spread across the whole screen.
  static const _glowBright = Color(0xFF12A5F5);
  static const _glowMid = Color(0xFF0A95E3);
  static const _glowSoft = Color(0xFF2A99F0);
  static const _glowEdge = Color(0xFF085CA8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Clients',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Base — mostly dark, subtle top-to-bottom variation.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_deepLight, _deepMid, _deepDark],
              ),
            ),
          ),
          // Glow — concentrated, soft-edged (blurred) radial highlight
          // toward the upper-left, fading into the base rather than
          // spanning the whole screen.
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.35, -0.55),
                  radius: 0.9,
                  colors: [
                    _glowBright,
                    _glowMid,
                    _glowSoft,
                    _glowEdge,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.25, 0.45, 0.65, 1.0],
                ),
              ),
            ),
          ),
          // Faint diagonal sheen for a metallic/glass touch.
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
        ],
      ),
    );
  }
}
