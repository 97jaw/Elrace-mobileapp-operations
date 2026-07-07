import 'package:el_race/ui/presentation/productivity/widgets/productivity_background.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_glass_header.dart';
import 'package:flutter/material.dart';

/// Gradient background + glass header shell for Productivity inner screens.
class ProductivityScreenShell extends StatelessWidget {
  const ProductivityScreenShell({
    super.key,
    this.title,
    required this.body,
    this.showBack = true,
    this.onBack,
    this.titleTrailing,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  final String? title;
  final Widget body;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? titleTrailing;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return ProductivityBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomNavigationBar,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProductivityGlassHeader(
              title: title,
              showBack: showBack,
              onBack: onBack,
              titleTrailing: titleTrailing,
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
