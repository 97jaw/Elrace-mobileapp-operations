import 'package:el_race/core/hr_management/routing/hr_route_names.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/hr_management/hr_management_entry_screen.dart';
import 'package:el_race/ui/presentation/home_screen/bloc/home_bloc.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_attendance_widget_provider.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_hrms_widget_provider.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_timesheet_widget_provider.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/category_widget_gradient_border.dart';
import 'package:el_race/utils/Util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// v7 Human Resource category widgets (Attendance, HRMS, Timesheet).
class HrCategoryAttendanceCard extends ConsumerWidget {
  const HrCategoryAttendanceCard({
    super.key,
    this.compact = false,
    this.tabletCompact = false,
  });

  final bool compact;

  /// When true, prefer denser layout for narrow tablet columns.
  /// Phone layout is unchanged when this is false.
  final bool tabletCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthLabel = BlocProvider.of<HomeBloc>(context).monthName.isNotEmpty
        ? BlocProvider.of<HomeBloc>(context).monthName
        : DateFormat('MMMM').format(DateTime.now());

    final stats = ref.watch(homeAttendanceWidgetProvider);
    final present = stats.presentDays;
    final workingDays = stats.workingDays;
    final pct = stats.attendancePercent;
    final workingLabel = workingDays > 0 ? '$workingDays' : '—';

    return _HrHalfCardShell(
      height: tabletCompact ? double.infinity : 140.uh,
      onTap: () =>
          Navigator.of(context).pushNamed(HrRouteNames.attendanceReports),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFC5DFF8),
          Color(0xFFDCE9F7),
          Color(0xFFE8F2FC),
          Color(0xFFF7FAFE),
        ],
      ),
      iconBadge: _HrIconBadge(
        icon: Icons.fingerprint_rounded,
        gradient: const [Color(0xFF5B9FE8), Color(0xFF3E7BFA)],
      ),
      pattern: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          IgnorePointer(
            child: SvgPicture.asset(
              'assets/svg/attendance-effect.svg',
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              colorFilter: ColorFilter.mode(
                const Color(0xFF3E7BFA).withValues(alpha: 0.28),
                BlendMode.srcIn,
              ),
            ),
          ),
          Positioned(
            right: 2.w,
            bottom: 4.uh,
            child: IgnorePointer(
              child: Image.asset(
                'assets/newapp/finger-print_svgrepo.com.png',
                width: (compact || tabletCompact) ? 70.w : 84.w,
                fit: BoxFit.contain,
                color: const Color(0xFF2F6FD4).withValues(alpha: 0.38),
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: tabletCompact ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ATTENDANCE',
                style: GoogleFonts.poppins(
                  fontSize: 8.usp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF3E7BFA),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 2.uh),
              Text(
                monthLabel,
                style: GoogleFonts.poppins(
                  fontSize: (compact || tabletCompact) ? 11.usp : 12.usp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A2A4F),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: (compact || tabletCompact) ? 6.uh : 8.uh),
              _HrAttendanceStatRow(
                present: present,
                workingLabel: workingLabel,
                compact: compact || tabletCompact,
              ),
              SizedBox(height: 4.uh),
              Text(
                '$pct% present',
                style: GoogleFonts.poppins(
                  fontSize: 9.5.usp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F9D63),
                ),
              ),
            ],
          ),
          if (!tabletCompact) const Spacer(),
          if (!compact) ...[
            if (tabletCompact) SizedBox(height: 6.uh),
            _HrWeekDotsRow(weekDayStates: stats.weekDayStates),
          ],
        ],
      ),
    );
  }
}

class HrCategoryHrmsCard extends ConsumerWidget {
  const HrCategoryHrmsCard({
    super.key,
    this.compact = false,
    this.tabletCompact = false,
  });

  final bool compact;

  /// When true, prefer denser layout for narrow tablet columns.
  final bool tabletCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(homeHrmsWidgetProvider);

    final countLabel =
        stats.headlineCount > 0 ? '${stats.headlineCount}' : '—';

    final pills = <String>[
      if (stats.departmentName != null && stats.departmentName!.isNotEmpty)
        stats.departmentName!,
      if (stats.sectionName != null && stats.sectionName!.isNotEmpty)
        stats.sectionName!,
    ];

    return _HrHalfCardShell(
      height: tabletCompact ? double.infinity : 140.uh,
      onTap: () => Util.pushPage(const HrManagementEntryScreen(), context),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFE8E5),
          Color(0xFFFFCFC9),
          Color(0xFFF5B7B1),
          Color(0xFFE8A8A2),
        ],
      ),
      iconBadge: _HrIconBadge(
        icon: Icons.groups_rounded,
        gradient: const [Color(0xFFE63946), Color(0xFFC62828)],
      ),
      pattern: Positioned(
        right: 0.w,
        bottom: 4.uh,
        child: IgnorePointer(
          child: Opacity(
            opacity: 0.38,
            child: CustomPaint(
              size: Size(
                (compact || tabletCompact) ? 92.w : 108.w,
                (compact || tabletCompact) ? 72.uh : 86.uh,
              ),
              painter: _PeopleNetworkPatternPainter(),
            ),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: tabletCompact ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stats.headlineLabel,
                style: GoogleFonts.poppins(
                  fontSize: 8.usp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFE63946),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 2.uh),
              Text(
                'HRMS',
                style: GoogleFonts.poppins(
                  fontSize: (compact || tabletCompact) ? 11.usp : 12.usp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF7A1E28),
                ),
              ),
              SizedBox(height: (compact || tabletCompact) ? 6.uh : 8.uh),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  countLabel,
                  style: GoogleFonts.poppins(
                    fontSize: (compact || tabletCompact) ? 26.usp : 28.usp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF7A1E28),
                    height: 1,
                  ),
                ),
              ),
              SizedBox(height: 4.uh),
              Text(
                stats.trendLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 9.usp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFE63946),
                  height: 1.25,
                ),
              ),
            ],
          ),
          if (!tabletCompact) const Spacer(),
          if (!compact && pills.isNotEmpty) ...[
            if (tabletCompact) SizedBox(height: 6.uh),
            Row(
              children: [
                for (var i = 0; i < pills.length; i++) ...[
                  if (i > 0) SizedBox(width: 6.w),
                  Flexible(
                    child: _HrSoftPill(label: pills[i]),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class HrCategoryTimesheetCard extends ConsumerWidget {
  const HrCategoryTimesheetCard({
    super.key,
    this.tabletCompact = false,
  });

  /// When true, prefer denser layout for narrow tablet columns.
  final bool tabletCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(homeTimesheetWidgetProvider);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(TimesheetRouteNames.home),
        borderRadius: BorderRadius.circular(22.ur),
        child: Container(
          decoration: CategoryWidgetGradientBorder.outer(borderRadius: 22.ur),
          padding: CategoryWidgetGradientBorder.padding,
          child: Container(
            decoration: CategoryWidgetGradientBorder.inner(
              borderRadius: 22.ur,
              fillGradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFAF6EC),
                  Color(0xFFF5F0E0),
                  Color(0xFFE8E0CC),
                  Color(0xFFDBD2B5),
                ],
              ),
            ),
            child: Stack(
            children: [
              Positioned(
                right: -8.w,
                bottom: -10.uh,
                child: Opacity(
                  opacity: 0.2,
                  child: Icon(
                    Icons.construction_rounded,
                    size: 96.usp,
                    color: const Color(0xFFD4A82A),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(14.w, 12.uh, 14.w, 12.uh),
                child: _tabletScaleDownContent(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TIMESHEET',
                                  style: GoogleFonts.poppins(
                                    fontSize: 8.usp,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF8A8F9C),
                                    letterSpacing: 0.55,
                                  ),
                                ),
                                SizedBox(height: 2.uh),
                                Text(
                                  data.titleLine,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.usp,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1A2A4F),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _HrIconBadge(
                            icon: Icons.schedule_rounded,
                            gradient: const [
                              Color(0xFFE8C547),
                              Color(0xFFD4A82A),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 12.uh),
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            _HrStatColumn(
                              label: 'Total Hours',
                              value: _formatHours(data.totalHours),
                              valueColor: const Color(0xFF1A2A4F),
                            ),
                            _HrStatDivider(),
                            _HrStatColumn(
                              label: 'Overtime',
                              value: _formatHours(data.overtimeHours),
                              valueColor: const Color(0xFFD4A82A),
                            ),
                            _HrStatDivider(),
                            _HrStatColumn(
                              label: data.isProjectScope
                                  ? 'Avg / Worker'
                                  : 'Avg / Day',
                              value: _formatHours(data.avgPerWorker),
                              valueColor: const Color(0xFF1A2A4F),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 10.uh),
                      Text(
                        data.deltaTrendLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 10.usp,
                          fontWeight: FontWeight.w600,
                          color: data.deltaVsLastWeek >= 0
                              ? const Color(0xFF1F9D63)
                              : const Color(0xFFE05A4F),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

/// Collapsed panel peek — Attendance + HRMS only (no duplicate full category).
class HrCategoryCollapsedPreview extends StatelessWidget {
  const HrCategoryCollapsedPreview({super.key, required this.onExpandTap});

  final VoidCallback onExpandTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.uh),
      child: SizedBox(
        height: 140.uh,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onExpandTap,
                child: const HrCategoryAttendanceCard(),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: GestureDetector(
                onTap: onExpandTap,
                child: const HrCategoryHrmsCard(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatHours(num value) {
  if (value % 1 == 0) return '${value.toStringAsFixed(0)}h';
  return '${value.toStringAsFixed(1)}h';
}

/// Overflow guard for tablet scale boxes only — never wrap phone content
/// (breaks Spacer / bottom metadata on Attendance & HRMS).
Widget _tabletScaleDownContent({required Widget child}) {
  if (!ResponsiveBreakpoints.isTabletScreen) return child;
  return LayoutBuilder(
    builder: (context, constraints) {
      return Align(
        alignment: Alignment.topLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: child,
          ),
        ),
      );
    },
  );
}

class _HrHalfCardShell extends StatelessWidget {
  const _HrHalfCardShell({
    required this.child,
    required this.gradient,
    required this.iconBadge,
    this.pattern,
    this.onTap,
    this.height,
  });

  final Widget child;
  final Gradient gradient;
  final Widget iconBadge;
  final Widget? pattern;
  final VoidCallback? onTap;
  final double? height;

  /// Landscape tablets: inflate shell height so ScreenUtil `.w`/`.usp` content fits.
  static double defaultHeight() =>
      ResponsiveBreakpoints.landscapeAwareCardHeight();

  @override
  Widget build(BuildContext context) {
    final innerRadius =
        (22.ur - CategoryWidgetGradientBorder.width).clamp(0.0, double.infinity);

    return LayoutBuilder(
      builder: (context, constraints) {
        final shellH = height ??
            (constraints.hasBoundedHeight && constraints.maxHeight < 10000
                ? constraints.maxHeight
                : defaultHeight());

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22.ur),
            child: Container(
              height: shellH,
              width: constraints.hasBoundedWidth ? constraints.maxWidth : null,
              decoration:
                  CategoryWidgetGradientBorder.outer(borderRadius: 22.ur),
              padding: CategoryWidgetGradientBorder.padding,
              child: Container(
                decoration: CategoryWidgetGradientBorder.inner(
                  borderRadius: 22.ur,
                  fillGradient: gradient,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(innerRadius),
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.hardEdge,
                    children: [
                      if (pattern != null) pattern!,
                      // Phone: direct child so Spacer + week-dots/pills layout
                      // works. Tablet: FittedBox only inside the scale box.
                      Padding(
                        padding: EdgeInsets.fromLTRB(12.w, 10.uh, 46.w, 12.uh),
                        child: ResponsiveBreakpoints.isTabletScreen
                            ? LayoutBuilder(
                                builder: (context, inner) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.topLeft,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: inner.maxWidth,
                                        ),
                                        child: child,
                                      ),
                                    ),
                                  );
                                },
                              )
                            : child,
                      ),
                      Positioned(
                        top: 8.uh,
                        right: 8.w,
                        child: iconBadge,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HrAttendanceStatRow extends StatelessWidget {
  const _HrAttendanceStatRow({
    required this.present,
    required this.workingLabel,
    required this.compact,
  });

  final int present;
  final String workingLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '$present',
            style: GoogleFonts.poppins(
              fontSize: compact ? 26.usp : 28.usp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A2A4F),
              height: 1,
            ),
          ),
          Text(
            ' /$workingLabel',
            style: GoogleFonts.poppins(
              fontSize: compact ? 16.usp : 18.usp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A2A4F).withValues(alpha: 0.72),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HrIconBadge extends StatelessWidget {
  const _HrIconBadge({
    required this.icon,
    required this.gradient,
  });

  final IconData icon;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34.w,
      height: 34.w,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.ur),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 18.usp),
    );
  }
}

class _HrSoftPill extends StatelessWidget {
  const _HrSoftPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.uh),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          fontSize: 8.usp,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF7A1E28),
        ),
      ),
    );
  }
}

class _HrWeekDotsRow extends StatelessWidget {
  const _HrWeekDotsRow({this.weekDayStates});

  final List<HomeAttendanceWeekDayState>? weekDayStates;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = today.subtract(Duration(days: today.weekday % 7));
    const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Row(
      children: [
        for (var index = 0; index < 7; index++) ...[
          if (index > 0) SizedBox(width: 4.w),
          Expanded(
            child: _weekDayChip(
              label: labels[index],
              state: weekDayStates != null && weekDayStates!.length > index
                  ? weekDayStates![index]
                  : _fallbackStateForDay(start.add(Duration(days: index)), today),
            ),
          ),
        ],
      ],
    );
  }

  HomeAttendanceWeekDayState _fallbackStateForDay(DateTime day, DateTime today) {
    final dayOnly = DateTime(day.year, day.month, day.day);
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (dayOnly.isAfter(todayOnly)) return HomeAttendanceWeekDayState.future;
    if (dayOnly == todayOnly) return HomeAttendanceWeekDayState.today;
    return HomeAttendanceWeekDayState.present;
  }

  Widget _weekDayChip({
    required String label,
    required HomeAttendanceWeekDayState state,
  }) {
    late final Color fill;
    late final Color textColor;

    switch (state) {
      case HomeAttendanceWeekDayState.today:
        fill = const Color(0xFF1A2A4F);
        textColor = Colors.white;
      case HomeAttendanceWeekDayState.todayPresent:
        fill = const Color(0xFF1F9D63);
        textColor = Colors.white;
      case HomeAttendanceWeekDayState.future:
        fill = Colors.white.withValues(alpha: 0.35);
        textColor = const Color(0xFF8A9BB5);
      case HomeAttendanceWeekDayState.absent:
        fill = const Color(0xFFE05A4F).withValues(alpha: 0.22);
        textColor = const Color(0xFFE05A4F);
      case HomeAttendanceWeekDayState.empty:
        fill = Colors.white.withValues(alpha: 0.45);
        textColor = const Color(0xFF8A9BB5);
      case HomeAttendanceWeekDayState.present:
        fill = const Color(0xFF3E7BFA).withValues(alpha: 0.22);
        textColor = const Color(0xFF3E7BFA);
    }

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(6.ur),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 7.usp,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

class _HrStatColumn extends StatelessWidget {
  const _HrStatColumn({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 7.5.usp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF7A849C),
              letterSpacing: 0.35,
            ),
          ),
          SizedBox(height: 4.uh),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 17.usp,
              fontWeight: FontWeight.w800,
              color: valueColor,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HrStatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: EdgeInsets.symmetric(horizontal: 8.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF1A2A4F).withValues(alpha: 0.16),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _PeopleNetworkPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35;

    final fill = Paint()..color = Colors.white.withValues(alpha: 0.9);

    const nodes = [
      Offset(0.72, 0.22),
      Offset(0.42, 0.55),
      Offset(0.82, 0.72),
    ];

    final points = nodes
        .map((n) => Offset(n.dx * size.width, n.dy * size.height))
        .toList();

    for (var i = 0; i < points.length; i++) {
      for (var j = i + 1; j < points.length; j++) {
        canvas.drawLine(points[i], points[j], paint);
      }
    }
    for (final p in points) {
      canvas.drawCircle(p, 6.5, fill);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
