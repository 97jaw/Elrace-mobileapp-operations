import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:flutter/material.dart';

/// Full-screen white → sky blue gradient shell for Purchase Management.
class PurchaseBackground extends StatelessWidget {
  const PurchaseBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: PurchaseTheme.hubBackgroundGradient,
      ),
      child: child,
    );
  }
}
