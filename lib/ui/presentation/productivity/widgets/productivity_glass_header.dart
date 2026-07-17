import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/productivity/theme/productivity_theme.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:flutter/material.dart';

/// Light glass header on sky-blue Productivity surfaces.
class ProductivityGlassHeader extends StatelessWidget {
  const ProductivityGlassHeader({
    super.key,
    this.title,
    this.showBack = false,
    this.onBack,
    this.titleTrailing,
    this.bottom,
    this.tabsHeight,
    this.trailing = const [],
  });

  final String? title;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? titleTrailing;
  final Widget? bottom;
  final double? tabsHeight;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return ContextualGlassChromeHeader(
      title: title,
      showBack: showBack,
      onBack: onBack,
      titleTrailing: titleTrailing,
      bottom: bottom,
      tabsHeight: tabsHeight,
      trailing: trailing,
      onLightSurface: true,
      scrimColor: ProductivityTheme.hubBackground,
      scrimTopOpacity: 0.35,
    );
  }
}
