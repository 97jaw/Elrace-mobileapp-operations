import 'package:el_race/ui/presentation/attendance_reports/theme/attendance_dashboard_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// AI Attendance Insights — "Coming Soon" placeholder.
/// [fullPage] shows an expanded centered layout for the AI tab.
class AttendanceAiComingSoonSection extends StatelessWidget {
  const AttendanceAiComingSoonSection({super.key, this.fullPage = false});

  final bool fullPage;

  @override
  Widget build(BuildContext context) {
    return fullPage ? _FullPageAi() : _CompactAi();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact card (used inside Dashboard tab)
// ─────────────────────────────────────────────────────────────────────────────

class _CompactAi extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E4DB7).withValues(alpha: 0.08),
            const Color(0xFF0284C7).withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: const Color(0xFF1E4DB7).withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E4DB7).withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 3D-style icon
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2563EB), Color(0xFF0284C7)],
              ),
              borderRadius: BorderRadius.circular(14.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E4DB7).withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.6),
                  blurRadius: 2,
                  offset: const Offset(-1, -1),
                ),
              ],
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 24.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Attendance Insights',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.sp,
                    color: AttendanceDashboardTheme.filterActive,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Smart summaries & anomaly alerts for your team.',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AttendanceDashboardTheme.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E4DB7), Color(0xFF2563EB)],
              ),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E4DB7).withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              'Soon',
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-page AI tab view
// ─────────────────────────────────────────────────────────────────────────────

class _FullPageAi extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 36.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFDEEAFF),
            const Color(0xFFEEF4FF),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: const Color(0xFF1E4DB7).withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E4DB7).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Animated sparkle icon
          Container(
            width: 80.w,
            height: 80.w,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2563EB), Color(0xFF0284C7)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E4DB7).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 38.sp,
            ),
          ),

          SizedBox(height: 24.h),

          Text(
            'AI Attendance Insights',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: AttendanceDashboardTheme.filterActive,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 10.h),

          Text(
            'Intelligent summaries, anomaly detection,\nand smart attendance predictions for your team.',
            style: TextStyle(
              fontSize: 13.sp,
              color: AttendanceDashboardTheme.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 28.h),

          // Feature preview cards
          for (final item in [
            (Icons.insights_rounded, 'Smart Summaries', 'Daily & weekly attendance summaries'),
            (Icons.warning_amber_rounded, 'Anomaly Alerts', 'Unusual patterns & irregular behavior'),
            (Icons.trending_up_rounded, 'Trend Analysis', 'Attendance trends over time'),
          ]) ...[
            _FeatureRow(icon: item.$1, title: item.$2, subtitle: item.$3),
            SizedBox(height: 12.h),
          ],

          SizedBox(height: 8.h),

          Container(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E4DB7), Color(0xFF2563EB)],
              ),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E4DB7).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              'Coming Soon',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: const Color(0xFF1E4DB7).withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: const Color(0xFF1E4DB7).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon,
                size: 18.sp,
                color: AttendanceDashboardTheme.filterActive),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: AttendanceDashboardTheme.filterActive,
                    )),
                Text(subtitle,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AttendanceDashboardTheme.textMuted,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
