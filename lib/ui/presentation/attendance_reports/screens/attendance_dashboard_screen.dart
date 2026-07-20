import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/attendance_reports/utils/attendance_format_utils.dart';
import 'package:el_race/ui/presentation/Attendace_list/model/attendance_model.dart';
import 'package:el_race/ui/presentation/attendance_reports/attendance_employee_deep_dive_screen.dart';
import 'package:el_race/ui/presentation/attendance_reports/attendance_reports_session.dart';
import 'package:el_race/ui/presentation/attendance_reports/providers/attendance_dashboard_provider.dart';
import 'package:el_race/ui/presentation/attendance_reports/screens/team_directory_screen.dart';
import 'package:el_race/ui/presentation/attendance_reports/theme/attendance_dashboard_theme.dart';
import 'package:el_race/ui/presentation/attendance_reports/widgets/attendance_stat_records_sheet.dart';
import 'package:el_race/ui/presentation/attendance_reports/widgets/dashboard_date_filter.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

/// Attendance Dashboard — manager first screen.
class AttendanceDashboardScreen extends ConsumerStatefulWidget {
  const AttendanceDashboardScreen({
    super.key,
    required this.session,
    this.sessionRefreshing = false,
  });

  final AttendanceSession session;
  final bool sessionRefreshing;

  @override
  ConsumerState<AttendanceDashboardScreen> createState() =>
      _AttendanceDashboardScreenState();
}

class _AttendanceDashboardScreenState
    extends ConsumerState<AttendanceDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(attendanceDashboardProvider.notifier).ensureTodayLoaded();
    });
  }

  void _openStatRecordsSheet(String type, AttendanceDashboardState? dashState) {
    final from = dashState?.dateFrom ?? DateTime.now();
    final to = dashState?.dateTo ?? DateTime.now();
    showAttendanceStatRecordsSheet(
      context,
      attendanceType: type,
      dateFrom: from,
      dateTo: to,
    );
  }

  String? _profileImageUrl() {
    final url = SharedPref.getLoginDataOrNull()?.result?.data?.image_url;
    if (url == null || url.isEmpty) return null;
    return url;
  }

  String _welcomeName(Result result) {
    final login = SharedPref.getLoginDataOrNull()?.result?.data;
    final n = login?.name?.trim();
    if (n != null && n.isNotEmpty) return n;
    final e = result.employeeName?.trim();
    if (e != null && e.isNotEmpty) return e;
    return 'there';
  }

  @override
  Widget build(BuildContext context) {
    final dashAsync = ref.watch(attendanceDashboardProvider);
    final dashState = dashAsync.asData?.value;
    final isLoading = dashState == null
        ? dashAsync.isLoading
        : dashState.loading;
    final stats = dashState?.stats;
    final hasError =
        dashAsync.hasError || (dashState?.error?.isNotEmpty == true);
    final errorMessage =
        dashState?.error ?? dashAsync.error?.toString() ?? 'Failed to load';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: AttendanceDashboardTheme.scaffoldGradient,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Glass chrome header
              ContextualGlassChromeHeader(
                onLightSurface: false,
                transparentGlassBar: false,
                trailing: [
                  if (widget.sessionRefreshing)
                    SizedBox(
                      width: 18.tw,
                      height: 18.tw,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),

              Expanded(
                child: _buildDashboardTab(
                  dashState,
                  stats,
                  isLoading,
                  hasError,
                  errorMessage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardTab(
    AttendanceDashboardState? dashState,
    AttendanceDashboardStats? stats,
    bool isLoading,
    bool hasError,
    String errorMessage,
  ) {
    return RefreshIndicator(
      color: AttendanceDashboardTheme.filterActive,
      onRefresh: () async {
        ref.read(attendanceDashboardProvider.notifier).refresh();
        ref.read(attendanceSessionProvider.notifier).refresh();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: 24.th),
        children: [
          // Hero stats card
          _GlassyHeroHeader(
            name: _welcomeName(widget.session.result),
            dashState: dashState,
            stats: stats,
            isLoading: isLoading,
            hasError: hasError,
            errorMessage: errorMessage,
            onRetry: () =>
                ref.read(attendanceDashboardProvider.notifier).refresh(),
            onStatCardTap: (type) => _openStatRecordsSheet(type, dashState),
            onFilterSelect: (f, {customFrom, customTo, monthLabel}) {
              ref.read(attendanceDashboardProvider.notifier).applyFilter(
                    f,
                    customFrom: customFrom,
                    customTo: customTo,
                    monthLabel: monthLabel,
                  );
            },
          ),

          SizedBox(height: 16.th),

          // Quick Access card
          _QuickAccessCard(
            session: widget.session,
            sessionRefreshing: widget.sessionRefreshing,
            welcomeName: _welcomeName(widget.session.result),
            profileImageUrl: _profileImageUrl(),
          ),

          SizedBox(height: 16.th),
        ],
      ),
    );
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// Glassy hero header — welcome + filter + 6 stat boxes (no avatar)
// ─────────────────────────────────────────────────────────────────────────────

class _GlassyHeroHeader extends StatelessWidget {
  const _GlassyHeroHeader({
    required this.name,
    required this.dashState,
    required this.stats,
    required this.isLoading,
    required this.hasError,
    required this.errorMessage,
    required this.onRetry,
    required this.onStatCardTap,
    required this.onFilterSelect,
  });

  final String name;
  final AttendanceDashboardState? dashState;
  final AttendanceDashboardStats? stats;
  final bool isLoading;
  final bool hasError;
  final String errorMessage;
  final VoidCallback onRetry;
  final void Function(String type) onStatCardTap;
  final void Function(
    DashboardDateFilter filter, {
    DateTime? customFrom,
    DateTime? customTo,
    String? monthLabel,
  }) onFilterSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(12.tw, 8.th, 12.tw, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE4EEFF), Color(0xFFF0F5FF), Color(0xFFFFFFFF)],
        ),
        borderRadius: BorderRadius.circular(22.tr),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.92),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E4DB7).withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.tw, 16.th, 16.tw, 16.th),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title only, no avatar
            Text(
              'Attendance Dashboard',
              style: TextStyle(
                fontSize: 17.tsp,
                fontWeight: FontWeight.w800,
                color: AttendanceDashboardTheme.filterActive,
                letterSpacing: -0.2,
              ),
            ),
            SizedBox(height: 2.th),
            Text(
              'Hello, $name',
              style: TextStyle(
                fontSize: 12.tsp,
                color: AttendanceDashboardTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),

            SizedBox(height: 14.th),

            // Filter chips
            DashboardDateFilterBar(
              selected: dashState?.filter ?? DashboardDateFilter.today,
              selectedMonthLabel: dashState?.selectedMonthLabel,
              onSelect: onFilterSelect,
            ),

            SizedBox(height: 6.th),

            // Date label
            if (dashState != null)
              Padding(
                padding: EdgeInsets.only(bottom: 4.th),
                child: Text(
                  _dateLabel(dashState!),
                  style: TextStyle(
                    fontSize: 10.tsp,
                    color: AttendanceDashboardTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            SizedBox(height: 10.th),

            if (hasError)
              _ErrorBanner(message: errorMessage, onRetry: onRetry),

            // Stat grid 3×2 — tap to jump to Records tab with that filter
            Row(
              children: [
                Expanded(
                  child: _GlassStatCard(
                    label: 'TOTAL',
                    value: stats?.total ?? 0,
                    accent: AttendanceDashboardTheme.accentTotal,
                    isLoading: isLoading,
                    onTap: () => onStatCardTap('all'),
                  ),
                ),
                SizedBox(width: 8.tw),
                Expanded(
                  child: _GlassStatCard(
                    label: 'ON TIME',
                    value: stats?.onTime ?? 0,
                    accent: AttendanceDashboardTheme.accentOnTime,
                    isLoading: isLoading,
                    onTap: () => onStatCardTap('ontime'),
                  ),
                ),
                SizedBox(width: 8.tw),
                Expanded(
                  child: _GlassStatCard(
                    label: 'LATE',
                    value: stats?.late ?? 0,
                    accent: AttendanceDashboardTheme.accentLate,
                    isLoading: isLoading,
                    onTap: () => onStatCardTap('late'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.th),
            Row(
              children: [
                Expanded(
                  child: _GlassStatCard(
                    label: 'ABSENT',
                    value: stats?.absent ?? 0,
                    accent: AttendanceDashboardTheme.accentAbsent,
                    isLoading: isLoading,
                    onTap: () => onStatCardTap('absent'),
                  ),
                ),
                SizedBox(width: 8.tw),
                Expanded(
                  child: _GlassStatCard(
                    label: 'JM / TP',
                    value: stats?.jmTp ?? 0,
                    accent: AttendanceDashboardTheme.accentJmTp,
                    isLoading: isLoading,
                    onTap: () => onStatCardTap('jm_tp'),
                  ),
                ),
                SizedBox(width: 8.tw),
                Expanded(
                  child: _GlassStatCard(
                    label: 'LEAVES',
                    value: stats?.leaves ?? 0,
                    accent: AttendanceDashboardTheme.accentLeaves,
                    isLoading: isLoading,
                    onTap: () => onStatCardTap('leaves'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _dateLabel(AttendanceDashboardState s) {
    final fmt = DateFormat('d MMM');
    if (s.filter == DashboardDateFilter.today) {
      return DateFormat('EEEE, d MMMM yyyy').format(s.dateFrom);
    }
    if (s.dateFrom.year == s.dateTo.year &&
        s.dateFrom.month == s.dateTo.month &&
        s.dateFrom.day == s.dateTo.day) {
      return fmt.format(s.dateFrom);
    }
    return '${fmt.format(s.dateFrom)} – ${fmt.format(s.dateTo)}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Access card — same container as hero, transparent tiles, 3D icons
// ─────────────────────────────────────────────────────────────────────────────

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({
    required this.session,
    required this.sessionRefreshing,
    required this.welcomeName,
    required this.profileImageUrl,
  });

  final AttendanceSession session;
  final bool sessionRefreshing;
  final String welcomeName;
  final String? profileImageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.tw),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE4EEFF), Color(0xFFF0F5FF), Color(0xFFFFFFFF)],
        ),
        borderRadius: BorderRadius.circular(22.tr),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.92),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E4DB7).withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21.tr),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section header
            Padding(
              padding: EdgeInsets.fromLTRB(16.tw, 14.th, 16.tw, 0),
              child: Text(
                'Quick Access',
                style: TextStyle(
                  fontSize: 14.tsp,
                  fontWeight: FontWeight.w800,
                  color: AttendanceDashboardTheme.filterActive,
                  letterSpacing: -0.1,
                ),
              ),
            ),

            SizedBox(height: 10.th),

            // My Attendance
            _QuickTile(
              icon: Icons.badge_rounded,
              iconColor: const Color(0xFF0284C7),
              title: 'My Attendance',
              subtitle: 'Personal records & calendar',
              onTap: () {
                final login =
                    SharedPref.getLoginDataOrNull()?.result?.data;
                final id = login?.employee_id;
                if (login == null || id == null || id <= 0) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AttendanceEmployeeDeepDiveScreen(
                      employeeId: id,
                      employeeName:
                          login.name?.trim().isNotEmpty == true
                              ? login.name!.trim()
                              : welcomeName,
                      imageUrl: (login.image_url != null &&
                              login.image_url!.isNotEmpty)
                          ? login.image_url
                          : profileImageUrl,
                      displayFileId:
                          login.emp_profile_id?.trim().isNotEmpty == true
                              ? login.emp_profile_id!.trim()
                              : null,
                      useCompactKpis: false,
                    ),
                  ),
                );
              },
            ),

            // Divider
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.tw),
              child: Divider(
                height: 1,
                color:
                    AttendanceDashboardTheme.filterActive.withValues(alpha: 0.08),
              ),
            ),

            // Team Details
            _QuickTile(
              icon: Icons.groups_rounded,
              iconColor: const Color(0xFF0D9488),
              title: 'Team Details',
              subtitle: 'Directory · search · filters',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TeamDirectoryScreen(
                      session: session,
                      sessionRefreshing: sessionRefreshing,
                    ),
                  ),
                );
              },
            ),

            SizedBox(height: 4.th),
          ],
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            // Right accent strip
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      iconColor.withValues(alpha: 0.6),
                      iconColor.withValues(alpha: 0.15),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(16.tw, 12.th, 22.tw, 12.th),
              child: Row(
                children: [
                  // 3D-style icon container
                  Container(
                    width: 46.tw,
                    height: 46.tw,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          iconColor.withValues(alpha: 0.9),
                          iconColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(13.tr),
                      boxShadow: [
                        BoxShadow(
                          color: iconColor.withValues(alpha: 0.38),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.7),
                          blurRadius: 2,
                          offset: const Offset(-1, -1),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 22.tsp),
                  ),

                  SizedBox(width: 14.tw),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: HrModuleTypography.body().copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.tsp,
                            color: AttendanceDashboardTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 3.th),
                        Text(
                          subtitle,
                          style: HrModuleTypography.caption().copyWith(
                            fontSize: 11.tsp,
                            color: AttendanceDashboardTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Icon(
                    Icons.chevron_right_rounded,
                    color: iconColor.withValues(alpha: 0.5),
                    size: 20.tsp,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glassy stat card — ClipRRect + inner accent strip (no border-radius crash)
// ─────────────────────────────────────────────────────────────────────────────

class _GlassStatCard extends StatelessWidget {
  const _GlassStatCard({
    required this.label,
    required this.value,
    required this.accent,
    required this.isLoading,
    this.onTap,
  });

  final String label;
  final int value;
  final Color accent;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.tr),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13.tr),
        child: isLoading
            ? Container(
                height: 90.th,
                color: Colors.white.withValues(alpha: 0.70),
                child: Center(
                  child: SizedBox(
                    width: 18.tw,
                    height: 18.tw,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, accent.withValues(alpha: 0.06)],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(height: 10.th, color: accent),
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 6.tw, vertical: 14.th),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatK(value),
                            style: TextStyle(
                              fontSize: 22.tsp,
                              fontWeight: FontWeight.w900,
                              color: accent,
                              height: 1.0,
                            ),
                          ),
                          SizedBox(height: 4.th),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 9.tsp,
                              fontWeight: FontWeight.w700,
                              color: AttendanceDashboardTheme.textSecondary,
                              letterSpacing: 0.4,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
      ), // GestureDetector
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error banner
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.th),
      padding: EdgeInsets.symmetric(horizontal: 14.tw, vertical: 10.th),
      decoration: BoxDecoration(
        color: AttendanceDashboardTheme.accentAbsent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10.tr),
        border: Border.all(
          color: AttendanceDashboardTheme.accentAbsent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: AttendanceDashboardTheme.accentAbsent, size: 18.tsp),
          SizedBox(width: 8.tw),
          Expanded(
            child: Text(
              message,
              style: AttendanceDashboardTheme.statLabel()
                  .copyWith(color: AttendanceDashboardTheme.accentAbsent),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: TextStyle(
                fontSize: 12.tsp,
                fontWeight: FontWeight.w700,
                color: AttendanceDashboardTheme.accentAbsent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
