import 'package:el_race/ui/presentation/PettyCash/theme/petty_cash_theme.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:flutter/material.dart';

/// Petty Cash glass header on the black→mint gradient.
class PettyCashGlassHeader extends StatelessWidget {
  const PettyCashGlassHeader({
    super.key,
    this.title,
    this.showBack = false,
    this.onBack,
    this.titleTrailing,
  });

  final String? title;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? titleTrailing;

  @override
  Widget build(BuildContext context) {
    return ContextualGlassChromeHeader(
      title: title,
      showBack: showBack,
      onBack: onBack,
      titleTrailing: titleTrailing,
      onLightSurface: false,
      transparentGlassBar: true,
      scrimTopOpacity: 0,
    );
  }
}
