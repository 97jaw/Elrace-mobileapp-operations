import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:flutter/material.dart';

/// Light glass header on sky-blue Purchase Management surfaces.
class PurchaseManagementGlassHeader extends StatelessWidget {
  const PurchaseManagementGlassHeader({
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
      scrimColor: PurchaseTheme.hubBackground,
      scrimTopOpacity: 0.35,
      transparentGlassBar: false,
    );
  }

  static double extent(
    BuildContext context, {
    String? title,
    double bottomHeight = 0,
    bool showBack = false,
  }) {
    return ContextualGlassChromeHeader.extent(
      context,
      title: title,
      bottomHeight: bottomHeight,
      showBack: showBack,
    );
  }
}

/// Convenience shell: gradient background + glass header + body.
class PurchaseManagementGlassShell extends StatelessWidget {
  const PurchaseManagementGlassShell({
    super.key,
    required this.body,
    this.title,
    this.showBack = false,
    this.onBack,
    this.titleTrailing,
    this.bottom,
    this.tabsHeight,
    this.trailing = const [],
  });

  final Widget body;
  final String? title;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? titleTrailing;
  final Widget? bottom;
  final double? tabsHeight;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: PurchaseTheme.hubBackgroundGradient,
      ),
      child: Column(
        children: [
          PurchaseManagementGlassHeader(
            title: title,
            showBack: showBack,
            onBack: onBack,
            titleTrailing: titleTrailing,
            bottom: bottom,
            tabsHeight: tabsHeight,
            trailing: trailing,
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
