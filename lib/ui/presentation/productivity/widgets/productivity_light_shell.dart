import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/productivity/theme/productivity_light_theme.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_light_moving_background.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:flutter/material.dart';

/// Light moving-gradient shell for Task Management / Tickets.
///
/// List entry screens: [showBack] false, no [title] (company chrome only).
/// Nested screens: [showBack] true with optional [title].
class ProductivityLightShell extends StatelessWidget {
  const ProductivityLightShell({
    super.key,
    required this.body,
    this.title,
    this.showBack = false,
    this.onBack,
    this.titleTrailing,
    this.centerTitle = false,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  final Widget body;
  final String? title;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? titleTrailing;
  final bool centerTitle;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return ProductivityLightMovingBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: bottomNavigationBar,
        extendBody: bottomNavigationBar != null,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ContextualGlassChromeHeader(
              title: title,
              showBack: showBack,
              onBack: onBack,
              titleTrailing: titleTrailing,
              centerTitle: centerTitle,
              onLightSurface: true,
              transparentGlassBar: true,
              scrimColor: ProductivityLightTheme.washBlue,
              scrimTopOpacity: 0.12,
              titleColor: ProductivityLightTheme.ink,
            ),
            Expanded(child: TabletContentFrame(child: body)),
          ],
        ),
      ),
    );
  }
}
