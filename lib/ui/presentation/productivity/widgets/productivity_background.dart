import 'package:el_race/ui/presentation/productivity/theme/productivity_theme.dart';
import 'package:flutter/material.dart';

/// Full-screen white → sky blue gradient shell for Productivity modules.
class ProductivityBackground extends StatelessWidget {
  const ProductivityBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: ProductivityTheme.hubBackgroundGradient,
      ),
      child: child,
    );
  }
}
