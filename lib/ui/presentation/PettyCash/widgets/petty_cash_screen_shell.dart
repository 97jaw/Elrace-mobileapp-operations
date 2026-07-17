import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/PettyCash/theme/petty_cash_theme.dart';
import 'package:flutter/material.dart';

/// Full-height black→mint gradient shell for all Petty Cash holder screens.
class PettyCashScreenShell extends StatelessWidget {
  const PettyCashScreenShell({
    super.key,
    required this.body,
    this.header,
  });

  final Widget? header;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettyCashTheme.greenBlack,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: PettyCashTheme.screenGradient,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) header!,
            Expanded(child: TabletContentFrame(child: body)),
          ],
        ),
      ),
    );
  }
}
