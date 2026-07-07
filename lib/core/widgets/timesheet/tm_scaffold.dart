import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:flutter/material.dart';

class TmScaffold extends StatelessWidget {
  const TmScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.padding = const EdgeInsets.symmetric(
      horizontal: TimesheetModuleLayout.screenPaddingH,
      vertical: 16,
    ),
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
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
