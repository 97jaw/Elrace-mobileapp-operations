import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/widgets/timesheet/tm_module_glass_header.dart';
import 'package:flutter/material.dart';

class TmScaffold extends StatelessWidget {
  const TmScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.glassTitle,
    this.glassTrailing = const [],
    this.glassShowBack = true,
    this.onGlassBack,
    this.bottomNavigationBar,
    this.padding = const EdgeInsets.symmetric(
      horizontal: TimesheetModuleLayout.screenPaddingH,
      vertical: 16,
    ),
  });

  final PreferredSizeWidget? appBar;

  /// When set, the company glass logo header is rendered instead of [appBar].
  final String? glassTitle;
  final List<Widget> glassTrailing;
  final bool glassShowBack;
  final VoidCallback? onGlassBack;

  final Widget body;
  final Widget? bottomNavigationBar;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (glassTitle != null) {
      return Scaffold(
        backgroundColor: TimesheetModuleColors.bgGradientEnd,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TmModuleGlassHeader(
              title: glassTitle!,
              trailing: glassTrailing,
              showBack: glassShowBack,
              onBack: onGlassBack,
            ),
            Expanded(
              child: SafeArea(
                top: false,
                bottom: bottomNavigationBar == null,
                child: Padding(
                  padding: padding,
                  child: body,
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: bottomNavigationBar,
      );
    }

    return Scaffold(
      backgroundColor: TimesheetModuleColors.bgGradientEnd,
      appBar: appBar,
      body: SafeArea(
        top: appBar == null,
        bottom: bottomNavigationBar == null,
        child: Padding(
          padding: padding,
          child: body,
        ),
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
