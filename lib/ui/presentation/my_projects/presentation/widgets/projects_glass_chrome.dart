import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:flutter/material.dart';

/// Accent tint for My Projects — aligned with dashboard maroon.
abstract final class ProjectsHeaderTints {
  static const Color projects = ProjectsDashboardTheme.maroon;
}

/// Project Management glass header — sits on the PM gradient with a light scrim.
class ProjectsGlassChromeHeader extends StatelessWidget {
  const ProjectsGlassChromeHeader({
    super.key,
    this.title,
    this.showBack = false,
    this.onBack,
    this.trailing = const [],
    this.bottom,
    this.tabsHeight,
    this.titleTrailing,
    this.onLightSurface = false,
    this.scrimTopOpacity,
    this.transparentGlassBar = false,
  });

  final String? title;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget> trailing;
  final Widget? bottom;
  final double? tabsHeight;
  final Widget? titleTrailing;
  final bool onLightSurface;
  final double? scrimTopOpacity;
  final bool transparentGlassBar;

  static double get titleRowHeight => ContextualGlassChromeHeader.titleRowHeight;

  static double extent(
    BuildContext context, {
    String? title,
    double bottomHeight = 0,
    bool showBack = false,
  }) =>
      ContextualGlassChromeHeader.extent(
        context,
        title: title,
        bottomHeight: bottomHeight,
        showBack: showBack,
      );

  static Widget homeTrailing({
    required VoidCallback onPressed,
    String tooltip = 'Projects home',
    bool onLightSurface = false,
  }) =>
      ContextualGlassChromeHeader.homeTrailing(
        onPressed: onPressed,
        tooltip: tooltip,
        iconColor: onLightSurface
            ? ProjectsDashboardTheme.navy
            : ProjectsDashboardTheme.white,
      );

  @override
  Widget build(BuildContext context) {
    return ContextualGlassChromeHeader(
      title: title,
      showBack: showBack,
      onBack: onBack,
      trailing: trailing,
      bottom: bottom,
      tabsHeight: tabsHeight,
      titleTrailing: titleTrailing,
      onLightSurface: onLightSurface,
      scrimColor: onLightSurface ? Colors.black : ProjectsDashboardTheme.maroon,
      scrimTopOpacity: scrimTopOpacity ?? (onLightSurface ? 0.08 : 0.14),
      transparentGlassBar: transparentGlassBar,
    );
  }
}

/// PM shell: shared background with translucent header chrome on top.
class ProjectsGlassShell extends StatelessWidget {
  const ProjectsGlassShell({
    super.key,
    required this.body,
    this.title,
    this.showBack = true,
    this.onBack,
    this.trailing = const [],
    this.titleTrailing,
    this.headerBottom,
    this.background,
    this.backgroundColor = Colors.white,
    this.onLightSurface = true,
    this.useDashboardGradient = false,
  });

  final String? title;
  final Widget body;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget> trailing;
  final Widget? titleTrailing;
  final Widget? headerBottom;
  final Decoration? background;
  final Color? backgroundColor;
  final bool onLightSurface;
  final bool useDashboardGradient;

  @override
  Widget build(BuildContext context) {
    final decoration = background ??
        BoxDecoration(
          gradient: useDashboardGradient
              ? ProjectsDashboardTheme.screenGradient
              : null,
          color: useDashboardGradient ? null : backgroundColor,
        );

    return ContextualGlassShell(
      title: title,
      showBack: showBack,
      onBack: onBack,
      trailing: trailing,
      titleTrailing: titleTrailing,
      headerBottom: headerBottom,
      onLightSurface: onLightSurface,
      scrimColor: onLightSurface
          ? Colors.black
          : ProjectsDashboardTheme.maroon,
      scrimTopOpacity: onLightSurface ? 0.08 : 0.14,
      background: decoration,
      body: body,
    );
  }
}
