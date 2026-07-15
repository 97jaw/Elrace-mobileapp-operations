import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:flutter/material.dart';

/// App-wide glass logo bar (same chrome as My Reports / Purchase / Projects)
/// used across every Site Report entry (My Reports + Site Management).
class TmSiteReportGlassHeader extends StatelessWidget {
  const TmSiteReportGlassHeader({
    super.key,
    required this.title,
    this.trailing = const [],
    this.onBack,
  });

  final String title;
  final List<Widget> trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return ContextualGlassChromeHeader(
      title: title,
      showBack: true,
      onBack: onBack,
      trailing: trailing,
      onLightSurface: true,
      scrimColor: TimesheetModuleColors.bgGradientEnd,
      scrimTopOpacity: 0.28,
      transparentGlassBar: false,
      logoOpacity: 1,
    );
  }
}

/// Scaffold shell: glass logo header + body (not Material AppBar).
class TmSiteReportGlassShell extends StatelessWidget {
  const TmSiteReportGlassShell({
    super.key,
    required this.title,
    required this.body,
    this.trailing = const [],
    this.floatingActionButton,
    this.onBack,
  });

  final String title;
  final Widget body;
  final List<Widget> trailing;
  final Widget? floatingActionButton;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TimesheetModuleColors.bgGradientEnd,
      floatingActionButton: floatingActionButton,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TmSiteReportGlassHeader(
            title: title,
            trailing: trailing,
            onBack: onBack,
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
