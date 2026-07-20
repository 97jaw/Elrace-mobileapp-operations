import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:ui';

import 'package:el_race/ui/presentation/my_reports/models/my_report_view_mode.dart';
import 'package:el_race/ui/presentation/my_reports/theme/my_reports_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MyReportsViewBar extends StatelessWidget {
  const MyReportsViewBar({
    super.key,
    required this.mode,
    required this.onModeChanged,
  });

  final MyReportViewMode mode;
  final ValueChanged<MyReportViewMode> onModeChanged;

  static double scrollBottomPadding(BuildContext context) {
    return 78.th + MediaQuery.paddingOf(context).bottom + 10.th;
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16.tw, 0, 16.tw, safe + 10.th),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.tr),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 8.th),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [MyReportsTheme.royalBlue, MyReportsTheme.deepNavy],
              ),
              borderRadius: BorderRadius.circular(24.tr),
              border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
            ),
            child: Row(
              children: [
                _ModeChip(
                  icon: Icons.table_chart_outlined,
                  label: 'Standard',
                  active: mode == MyReportViewMode.standard,
                  onTap: () => onModeChanged(MyReportViewMode.standard),
                ),
                _ModeChip(
                  icon: Icons.analytics_outlined,
                  label: 'Analytics',
                  active: mode == MyReportViewMode.analytics,
                  onTap: () => onModeChanged(MyReportViewMode.analytics),
                ),
                _ModeChip(
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI',
                  active: mode == MyReportViewMode.ai,
                  onTap: () => onModeChanged(MyReportViewMode.ai),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: EdgeInsets.symmetric(horizontal: 4.tw),
          padding: EdgeInsets.symmetric(vertical: 7.th, horizontal: 6.tw),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.tr),
            color: active ? MyReportsTheme.accent : Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14.tsp,
                color: active ? Colors.white : Colors.white.withValues(alpha: 0.75),
              ),
              SizedBox(width: 4.tw),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11.tsp,
                  color: active ? Colors.white : Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
