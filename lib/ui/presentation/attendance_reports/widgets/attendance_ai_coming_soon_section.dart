import 'package:el_race/core/utils/responsive_breakpoints.dart';
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
      padding: EdgeInsets.symmetric(horizontal: 16.tw, vertical: 16.th),
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
        borderRadius: BorderRadius.circular(18.tr),
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
            width: 48.tw,
            height: 48.tw,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2563EB), Color(0xFF0284C7)],
              ),
              borderRadius: BorderRadius.circular(14.tr),
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
              size: 24.tsp,
            ),
          ),
          SizedBox(width: 14.tw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Attendance Insights',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.tsp,
                    color: AttendanceDashboardTheme.filterActive,
                  ),
                ),
                SizedBox(height: 4.th),
                Text(
                  'Smart summaries & anomaly alerts for your team.',
                  style: TextStyle(
                    fontSize: 11.tsp,
                    color: AttendanceDashboardTheme.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.tw),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 5.th),
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
                fontSize: 10.tsp,
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
      padding: EdgeInsets.symmetric(horizontal: 24.tw, vertical: 36.th),
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
        borderRadius: BorderRadius.circular(24.tr),
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
            width: 80.tw,
            height: 80.tw,
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
              size: 38.tsp,
            ),
          ),

          SizedBox(height: 24.th),

          Text(
            'AI Attendance Insights',
            style: TextStyle(
              fontSize: 20.tsp,
              fontWeight: FontWeight.w800,
              color: AttendanceDashboardTheme.filterActive,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 10.th),

          Text(
            'Intelligent summaries, anomaly detection,\nand smart attendance predictions for your team.',
            style: TextStyle(
              fontSize: 13.tsp,
              color: AttendanceDashboardTheme.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 28.th),

          // Feature preview cards
          for (final item in [
            (Icons.insights_rounded, 'Smart Summaries', 'Daily & weekly attendance summaries'),
            (Icons.warning_amber_rounded, 'Anomaly Alerts', 'Unusual patterns & irregular behavior'),
            (Icons.trending_up_rounded, 'Trend Analysis', 'Attendance trends over time'),
          ]) ...[
            _FeatureRow(icon: item.$1, title: item.$2, subtitle: item.$3),
            SizedBox(height: 12.th),
          ],

          SizedBox(height: 8.th),

          Container(
            padding: EdgeInsets.symmetric(horizontal: 24.tw, vertical: 10.th),
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
                fontSize: 14.tsp,
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
      padding: EdgeInsets.symmetric(horizontal: 14.tw, vertical: 12.th),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14.tr),
        border: Border.all(
          color: const Color(0xFF1E4DB7).withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36.tw,
            height: 36.tw,
            decoration: BoxDecoration(
              color: const Color(0xFF1E4DB7).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10.tr),
            ),
            child: Icon(icon,
                size: 18.tsp,
                color: AttendanceDashboardTheme.filterActive),
          ),
          SizedBox(width: 12.tw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontSize: 13.tsp,
                      fontWeight: FontWeight.w700,
                      color: AttendanceDashboardTheme.filterActive,
                    )),
                Text(subtitle,
                    style: TextStyle(
                      fontSize: 11.tsp,
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
