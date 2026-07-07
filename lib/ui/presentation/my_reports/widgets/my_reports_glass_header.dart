import 'package:el_race/ui/presentation/my_reports/theme/my_reports_theme.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:flutter/material.dart';

class MyReportsGlassHeader extends StatelessWidget {
  const MyReportsGlassHeader({
    super.key,
    required this.title,
    this.trailing = const [],
    this.onDarkBackground = false,
  });

  final String title;
  final List<Widget> trailing;
  final bool onDarkBackground;

  @override
  Widget build(BuildContext context) {
    return ContextualGlassChromeHeader(
      title: title,
      showBack: true,
      trailing: trailing,
      onLightSurface: !onDarkBackground,
      scrimColor: onDarkBackground ? MyReportsTheme.deepNavy : Colors.white,
      scrimTopOpacity: onDarkBackground ? 0.28 : 0.18,
    );
  }
}
