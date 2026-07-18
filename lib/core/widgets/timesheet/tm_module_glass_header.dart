import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:flutter/material.dart';

/// Company glass logo bar for the whole timesheet module (same chrome as
/// My Reports / Purchase / Projects and the Site Reports sub-module).
class TmModuleGlassHeader extends StatelessWidget {
  const TmModuleGlassHeader({
    super.key,
    required this.title,
    this.trailing = const [],
    this.showBack = true,
    this.onBack,
  });

  final String title;
  final List<Widget> trailing;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return ContextualGlassChromeHeader(
      title: title,
      showBack: showBack,
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
