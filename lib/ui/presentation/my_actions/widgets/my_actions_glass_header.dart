import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:flutter/material.dart';

/// Standard app chrome for My Actions — company logo (left) + home glass bar (right).
class MyActionsGlassHeader extends StatelessWidget {
  const MyActionsGlassHeader({
    super.key,
    this.title,
    this.showBack = false,
    this.onBack,
  });

  final String? title;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return ContextualGlassChromeHeader(
      title: title,
      showBack: showBack,
      onBack: onBack,
      transparentGlassBar: true,
      scrimTopOpacity: 0,
    );
  }
}
