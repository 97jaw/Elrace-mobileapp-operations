import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:async';

import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/ui/presentation/Attendace_list/model/attendance_model.dart';
import 'package:el_race/ui/presentation/attendance_reports/attendance_employee_deep_dive_screen.dart';
import 'package:el_race/ui/presentation/attendance_reports/attendance_reports_period.dart';
import 'package:el_race/ui/presentation/attendance_reports/attendance_reports_session.dart';
import 'package:el_race/ui/presentation/attendance_reports/attendance_report_helpers.dart';
import 'package:el_race/ui/presentation/attendance_reports/theme/attendance_dashboard_theme.dart';
import 'package:el_race/ui/presentation/attendance_reports/widgets/attendance_glass_chrome_header.dart';
import 'package:el_race/ui/presentation/attendance_reports/widgets/attendance_month_switcher_card.dart';
import 'package:el_race/ui/presentation/attendance_reports/widgets/attendance_network_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const _kPrimary = Color(0xFF1E4DB7);
const _kSkyLight = Color(0xFFEEF4FF);
const _kSkyMid = Color(0xFFDEEAFF);

/// Team directory: alphabetical list + search + alpha chips + month calendar filter.
class TeamDirectoryScreen extends ConsumerStatefulWidget {
  const TeamDirectoryScreen({
    super.key,
    required this.session,
    this.sessionRefreshing = false,
  });

  final AttendanceSession session;
  final bool sessionRefreshing;

  @override
  ConsumerState<TeamDirectoryScreen> createState() =>
      _TeamDirectoryScreenState();
}

class _TeamDirectoryScreenState extends ConsumerState<TeamDirectoryScreen> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _letterKeys = {};
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearch);
  }

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (mounted) setState(() => _query = _search.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _ensureKeys(Iterable<String> letters) {
    for (final l in letters) {
      _letterKeys.putIfAbsent(l, GlobalKey.new);
    }
  }

  void _scrollToLetter(String letter) {
    final ctx = _letterKeys[letter]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        alignment: 0.02,
      );
    }
  }

  void _shiftMonth(int delta) {
    final notifier = ref.read(attendanceReportsPeriodProvider.notifier);
    if (delta < 0) {
      notifier.previousMonth();
    } else {
      notifier.nextMonth();
    }
  }

  List<EmployeeMonthlyAttendance> _filtered(
      List<EmployeeMonthlyAttendance> all) {
    if (_query.isEmpty) return all;
    return all
        .where((e) => e.employeeName.toLowerCase().contains(_query))
        .toList();
  }

  Future<void> _refresh() async {
    await ref.read(attendanceSessionProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(attendanceSessionProvider);
    final isLoadingSession = sessionAsync.isLoading && !sessionAsync.hasValue;
    final liveSession = sessionAsync.asData?.value ?? widget.session;
    final period = ref.watch(attendanceReportsPeriodProvider);

    final team = managerTeamRowsFromResult(
      liveSession.result,
      month: period.month,
      year: period.year,
    );
    final filtered = _filtered(team);

    final sorted = List<EmployeeMonthlyAttendance>.from(filtered)
      ..sort((a, b) => a.employeeName
          .toLowerCase()
          .compareTo(b.employeeName.toLowerCase()));

    final groups = <String, List<EmployeeMonthlyAttendance>>{};
    for (final e in sorted) {
      final letter =
          e.employeeName.isNotEmpty ? e.employeeName[0].toUpperCase() : '#';
      groups.putIfAbsent(letter, () => []).add(e);
    }
    final keys = groups.keys.toList()..sort();
    _ensureKeys(keys);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _kSkyLight,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_kSkyLight, Color(0xFFF5F9FF), Colors.white],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AttendanceGlassChromeHeader(
                title: 'Team Directory',
                trailing: [
                  AttendanceGlassChromeHeader.refreshButton(
                    onPressed: _refresh,
                  ),
                ],
              ),
              AttendanceMonthSwitcherCard(
                period: period,
                onPreviousMonth: () => _shiftMonth(-1),
                onNextMonth: () => _shiftMonth(1),
              ),

              // ── Search bar ────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                  HrModuleLayout.screenPaddingH.tw,
                  10.th,
                  HrModuleLayout.screenPaddingH.tw,
                  0,
                ),
                child: _SearchBar(controller: _search),
              ),

              SizedBox(height: 8.th),

              // ── Alpha chips ───────────────────────────────────────────
              if (!isLoadingSession && keys.isNotEmpty)
                SizedBox(
                  height: 34.th,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(
                        horizontal: HrModuleLayout.screenPaddingH.tw),
                    itemCount: keys.length,
                    separatorBuilder: (_, __) => SizedBox(width: 6.tw),
                    itemBuilder: (_, i) => _AlphaChip(
                      letter: keys[i],
                      onTap: () => _scrollToLetter(keys[i]),
                    ),
                  ),
                ),

              SizedBox(height: 8.th),

              // ── Employee list / skeleton / empty ──────────────────────
              Expanded(
                child: RefreshIndicator(
                  color: _kPrimary,
                  onRefresh: _refresh,
                  child: isLoadingSession && sorted.isEmpty
                      ? _SkeletonList()
                      : sorted.isEmpty
                          ? _EmptyState(query: _query)
                          : _EmployeeList(
                              scroll: _scroll,
                              groups: groups,
                              keys: keys,
                              letterKeys: _letterKeys,
                              onOpen: (e) {
                                if (e.employeeId <= 0) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        AttendanceEmployeeDeepDiveScreen(
                                      employeeId: e.employeeId,
                                      employeeName: e.employeeName,
                                      imageUrl: e.employeeImageUrl,
                                      displayFileId: e.empId,
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ),

              if (widget.sessionRefreshing)
                LinearProgressIndicator(
                  minHeight: 2,
                  color: _kPrimary,
                  backgroundColor: Colors.transparent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search bar
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14.tr),
        border: Border.all(color: _kPrimary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'Search by name…',
          hintStyle: TextStyle(
              color: AttendanceDashboardTheme.textMuted, fontSize: 13.tsp),
          prefixIcon: Icon(Icons.search_rounded,
              color: _kPrimary.withValues(alpha: 0.55), size: 20.tsp),
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 16.tw, vertical: 14.th),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Alpha chip
// ─────────────────────────────────────────────────────────────────────────────

class _AlphaChip extends StatelessWidget {
  const _AlphaChip({required this.letter, required this.onTap});
  final String letter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32.tw,
        height: 32.tw,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(8.tr),
          border: Border.all(color: _kPrimary.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: _kPrimary.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          letter,
          style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 12.tsp, color: _kPrimary),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Employee list grouped alphabetically
// ─────────────────────────────────────────────────────────────────────────────

class _EmployeeList extends StatelessWidget {
  const _EmployeeList({
    required this.scroll,
    required this.groups,
    required this.keys,
    required this.letterKeys,
    required this.onOpen,
  });

  final ScrollController scroll;
  final Map<String, List<EmployeeMonthlyAttendance>> groups;
  final List<String> keys;
  final Map<String, GlobalKey> letterKeys;
  final void Function(EmployeeMonthlyAttendance) onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
          HrModuleLayout.screenPaddingH.tw, 0,
          HrModuleLayout.screenPaddingH.tw, 40.th),
      children: [
        for (final k in keys) ...[
          Padding(
            key: letterKeys[k],
            padding: EdgeInsets.only(top: 16.th, bottom: 6.th),
            child: Text(
              k,
              style: TextStyle(
                fontSize: 12.tsp,
                fontWeight: FontWeight.w800,
                color: _kPrimary.withValues(alpha: 0.55),
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...groups[k]!.map((e) => Padding(
                padding: EdgeInsets.only(bottom: 10.th),
                child: _EmployeeCard(employee: e, onTap: () => onOpen(e)),
              )),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Employee card — screenshot-1 inspired layout:
// [photo] | [name + dept] | [chat icon] [arrow icon]
// [attendance progress bar + rate label]
// ─────────────────────────────────────────────────────────────────────────────

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.employee, required this.onTap});
  final EmployeeMonthlyAttendance employee;
  final VoidCallback onTap;

  double get _attendanceRate {
    final wd = employee.totalWorkingDays;
    if (wd <= 0) return 0;
    return (employee.totalPresentDays / wd).clamp(0.0, 1.0);
  }

  Color get _rateColor {
    final r = _attendanceRate;
    if (r >= 0.85) return const Color(0xFF16A34A);
    if (r >= 0.6) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    final rate = _attendanceRate;
    final pct = (rate * 100).toStringAsFixed(0);

    return Container(
      padding: EdgeInsets.fromLTRB(14.tw, 14.th, 10.tw, 14.th),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.tr),
        border: Border.all(color: _kPrimary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: photo | name+dept | action buttons ───────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile photo
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: _kPrimary.withValues(alpha: 0.2), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _kPrimary.withValues(alpha: 0.1),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: AttendanceNetworkAvatar(
                  radius: 26.tr,
                  imageUrl: employee.employeeImageUrl,
                  fallback: Text(
                    employee.employeeName.isNotEmpty
                        ? employee.employeeName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.tsp,
                        color: _kPrimary),
                  ),
                ),
              ),

              SizedBox(width: 12.tw),

              // Name + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.employeeName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.tsp,
                        color: AttendanceDashboardTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 3.th),
                    Text(
                      (employee.empId != null && employee.empId!.trim().isNotEmpty)
                          ? employee.empId!.trim()
                          : 'Employee',
                      style: TextStyle(
                        fontSize: 11.tsp,
                        color: AttendanceDashboardTheme.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow button (navigate to deep dive) — glassy
              GestureDetector(
                onTap: onTap,
                child: Container(
                  width: 36.tw,
                  height: 36.tw,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.95),
                        _kSkyMid.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10.tr),
                    border:
                        Border.all(color: _kPrimary.withValues(alpha: 0.18)),
                    boxShadow: [
                      BoxShadow(
                        color: _kPrimary.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.north_east_rounded,
                      size: 16.tsp, color: _kPrimary),
                ),
              ),
            ],
          ),

          SizedBox(height: 12.th),

          // ── Bottom row: attendance rate + progress bar ─────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$pct% Attendance Rate',
                      style: TextStyle(
                        fontSize: 11.tsp,
                        fontWeight: FontWeight.w700,
                        color: _rateColor,
                      ),
                    ),
                    SizedBox(height: 6.th),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: Stack(
                        children: [
                          Container(
                            height: 5.th,
                            decoration: BoxDecoration(
                              color: _kSkyMid,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: rate,
                            child: Container(
                              height: 5.th,
                              decoration: BoxDecoration(
                                color: _rateColor,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 12.tw),

              // P / A chips
              _MiniPill('P ${employee.totalPresentDays}',
                  const Color(0xFF16A34A)),
              SizedBox(width: 5.tw),
              _MiniPill('A ${employee.totalAbsentDays}',
                  const Color(0xFFDC2626)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.tw, vertical: 3.th),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6.tr),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10.tsp, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated skeleton loader
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonList extends StatefulWidget {
  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim =
        Tween<double>(begin: 0.3, end: 0.85).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            HrModuleLayout.screenPaddingH.tw, 0,
            HrModuleLayout.screenPaddingH.tw, 32.th),
        itemCount: 6,
        separatorBuilder: (_, __) => SizedBox(height: 10.th),
        itemBuilder: (_, __) => Container(
          height: 86.th,
          padding: EdgeInsets.all(14.tw),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _anim.value),
            borderRadius: BorderRadius.circular(18.tr),
            border: Border.all(color: _kPrimary.withValues(alpha: 0.07)),
          ),
          child: Row(
            children: [
              Container(
                  width: 50.tw,
                  height: 50.tw,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kSkyMid.withValues(alpha: _anim.value))),
              SizedBox(width: 12.tw),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 12.th,
                        width: 140.tw,
                        decoration: BoxDecoration(
                            color: _kSkyMid.withValues(alpha: _anim.value),
                            borderRadius: BorderRadius.circular(6.tr))),
                    SizedBox(height: 8.th),
                    Container(
                        height: 8.th,
                        width: 90.tw,
                        decoration: BoxDecoration(
                            color: _kSkyMid.withValues(alpha: _anim.value * 0.6),
                            borderRadius: BorderRadius.circular(4.tr))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: 60.th),
        Center(
          child: Column(
            children: [
              Icon(Icons.search_off_rounded,
                  size: 48.tsp, color: _kPrimary.withValues(alpha: 0.25)),
              SizedBox(height: 12.th),
              Text(
                query.isNotEmpty
                    ? 'No results for "$query"'
                    : 'No employees found',
                style: TextStyle(
                  fontSize: 14.tsp,
                  color: AttendanceDashboardTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
