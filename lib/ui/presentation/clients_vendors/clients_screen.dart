import 'package:flutter/material.dart';

/// Clients tab under Client & Vendors. Intentionally empty for now — this
/// is the shell (background + app bar) the real client list will be built
/// into next.
class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  static const _gradientStart = Color(0xFF0E2A63);
  static const _gradientEnd = Color(0xFF060B1D);

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
      body: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_gradientStart, _gradientEnd],
          ),
        ),
        child: SizedBox.expand(),
      ),
    );
  }
}
