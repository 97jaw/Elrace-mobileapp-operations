import 'package:el_race/ui/presentation/my_reports/theme/my_reports_theme.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:flutter/material.dart';

class MyReportsGlassHeader extends StatelessWidget {
  const MyReportsGlassHeader({
    super.key,
    required this.title,
    this.trailing = const [],
    this.onDarkBackground = false,
    this.transparentTopBar = true,
  });

  final String title;
  final List<Widget> trailing;
  final bool onDarkBackground;

  /// Right glass pill more see-through (logo bar still visible).
  final bool transparentTopBar;

  @override
  Widget build(BuildContext context) {
    final light = !onDarkBackground;
    return ContextualGlassChromeHeader(
      title: title,
      showBack: true,
      trailing: trailing,
      onLightSurface: light,
      scrimColor: light ? MyReportsTheme.mistWhite : MyReportsTheme.deepNavy,
      scrimTopOpacity: light ? 0.12 : 0.22,
      transparentGlassBar: transparentTopBar,
      logoOpacity: light ? 1.0 : 0.7,
    );
  }
}
