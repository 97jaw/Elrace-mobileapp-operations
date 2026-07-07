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
    return 78.h + MediaQuery.paddingOf(context).bottom + 10.h;
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, safe + 10.h),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [MyReportsTheme.royalBlue, MyReportsTheme.deepNavy],
              ),
              borderRadius: BorderRadius.circular(24.r),
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
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          padding: EdgeInsets.symmetric(vertical: 7.h, horizontal: 6.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            color: active ? MyReportsTheme.accent : Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14.sp,
                color: active ? Colors.white : Colors.white.withValues(alpha: 0.75),
              ),
              SizedBox(width: 4.w),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11.sp,
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
