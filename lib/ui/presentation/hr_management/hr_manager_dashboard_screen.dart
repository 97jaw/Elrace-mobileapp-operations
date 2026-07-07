import 'package:el_race/core/hr_management/hr_effective_view.dart';
import 'package:el_race/core/hr_management/models/hr_dashboard_data.dart';
import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/utils/pdf_watermark.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/core/widgets/hr_management/hr_themed_pickers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:printing/printing.dart';

/// M2 — Manager analytics from `POST /api/hr/dashboard`.
class HrManagerDashboardScreen extends ConsumerStatefulWidget {
  const HrManagerDashboardScreen({
    super.key,
    required this.effectiveView,
  });

  final HrEffectiveView effectiveView;

  @override
  ConsumerState<HrManagerDashboardScreen> createState() =>
      _HrManagerDashboardScreenState();
}

class _HrManagerDashboardScreenState
    extends ConsumerState<HrManagerDashboardScreen> {
  int _periodIndex = 1;
  late final PageController _pageController;
  int _dashPage = 0;

  static const _periods = [
    'This week',
    'This month',
    'Last month',
    'Quarter',
    'Year',
    'Custom',
  ];

  String get _periodKey => hrDashboardPeriodFromIndex(_periodIndex);

  String get _periodLabel => _periods[_periodIndex];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _pageCount(HrDashboardData data) =>
      data.includeDepartments ? 4 : 3;

  @override
  void didUpdateWidget(HrManagerDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final async = ref.read(hrDashboardProvider(_periodKey));
    final count = async.maybeWhen(
      data: _pageCount,
      orElse: () => widget.effectiveView == HrEffectiveView.hrManager ? 4 : 3,
    );
    if (_dashPage >= count) {
      _dashPage = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      });
    }
  }

  void _goToPage(int index, int pageCount) {
    if (index < 0 || index >= pageCount) return;
    setState(() => _dashPage = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  String _watermarkEmpId() {
    final data = SharedPref.getLoginData().result?.data;
    return (data?.emp_id?.isNotEmpty == true)
        ? data!.emp_id!
        : (data?.employee_id?.toString() ?? 'EMP');
  }

  Future<void> _exportPdf(HrDashboardData data) async {
    final lines = <String>[
      'Total: ${data.total}',
      'Pending: ${data.pending}',
      'Approved: ${data.approved}',
      if (data.avgApprovalDays != null)
        'Avg approval time: ${data.avgApprovalDays!.toStringAsFixed(1)} days',
      '',
      'By type:',
      ...data.byType.map((s) => '  · ${s.label}: ${s.count}'),
      '',
      'Top requesters:',
      ...data.topRequesters.map((r) => '  · ${r.name}: ${r.count}'),
    ];
    final bytes = await PdfWatermark.buildDashboardPdf(
      watermarkEmpId: _watermarkEmpId(),
      periodLabel: _periodLabel,
      lines: lines,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Widget _chartCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: HrModuleColors.surface,
        borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.r),
        boxShadow: HrModuleColors.cardShadow,
      ),
      child: child,
    );
  }

  Widget _tabChip(
    int index,
    String label,
    IconData icon,
    Color accent,
    int pageCount,
  ) {
    final selected = _dashPage == index;
    return Padding(
      padding: EdgeInsets.only(right: 8.w),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _goToPage(index, pageCount),
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
            decoration: BoxDecoration(
              color: selected ? HrModuleColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: selected ? HrModuleColors.cardShadow : const [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18.sp,
                  color: selected ? accent : HrModuleColors.mutedText,
                ),
                SizedBox(width: 6.w),
                Text(
                  label,
                  style: HrModuleTypography.caption().copyWith(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: selected ? accent : HrModuleColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabStrip(HrDashboardData data) {
    final pageCount = _pageCount(data);
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: HrModuleColors.requestsTabTrack.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 2.w),
        child: Row(
          children: [
            _tabChip(
              0,
              'Request type',
              Icons.bar_chart_rounded,
              const Color(0xFF1F3A5F),
              pageCount,
            ),
            _tabChip(
              1,
              'By month',
              Icons.bar_chart_rounded,
              const Color(0xFF4A6B8A),
              pageCount,
            ),
            _tabChip(
              2,
              'Top requesters',
              Icons.groups_outlined,
              const Color(0xFF00897B),
              pageCount,
            ),
            if (data.includeDepartments)
              _tabChip(
                3,
                'By department',
                Icons.apartment_outlined,
                HrModuleColors.accent,
                pageCount,
              ),
          ],
        ),
      ),
    );
  }

  Widget _coloredBarChart({
    required String title,
    required List<String> labels,
    required List<double> values,
    List<Color>? barColors,
  }) {
    if (labels.isEmpty || values.isEmpty) {
      return _emptyChart('No data in this period.');
    }
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final colors = barColors ??
        List.generate(
          values.length,
          (i) => hrDashboardChartColors[i % hrDashboardChartColors.length],
        );

    return SingleChildScrollView(
      padding: EdgeInsets.only(top: 4.h, bottom: 24.h),
      child: _chartCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: HrModuleTypography.sectionHeading().copyWith(fontSize: 15.sp),
            ),
            SizedBox(height: 12.h),
            SizedBox(
              height: 220.h,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY > 0 ? maxY * 1.2 : 1,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, m) {
                          final i = v.toInt();
                          if (i < 0 || i >= labels.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: EdgeInsets.only(top: 6.h),
                            child: Text(
                              labels[i],
                              style: HrModuleTypography.caption()
                                  .copyWith(fontSize: 9.sp),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, m) => Text(
                          v.toInt().toString(),
                          style: HrModuleTypography.caption().copyWith(fontSize: 9.sp),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(
                    values.length,
                    (i) => BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: values[i],
                          width: 14,
                          color: colors[i % colors.length],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageByType(HrDashboardData data) {
    final slices = data.byType;
    if (slices.isEmpty) {
      return _emptyChart('No requests in this period.');
    }
    return _coloredBarChart(
      title: 'Distribution by request type',
      labels: slices.map((s) => s.label).toList(),
      values: slices.map((s) => s.count.toDouble()).toList(),
    );
  }

  Widget _pageByMonth(HrDashboardData data) {
    final months = data.byMonth;
    if (months.isEmpty) {
      return _emptyChart('No monthly data for this period.');
    }
    return _coloredBarChart(
      title: 'Requests by month',
      labels: months.map((m) => m.label).toList(),
      values: months.map((m) => m.value.toDouble()).toList(),
    );
  }

  Widget _pageTopRequesters(HrDashboardData data) {
    final rows = data.topRequesters;
    if (rows.isEmpty) {
      return _emptyChart('No requesters in this period.');
    }
    return SingleChildScrollView(
      padding: EdgeInsets.only(top: 4.h, bottom: 24.h),
      child: _chartCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Top requesters',
              style: HrModuleTypography.sectionHeading().copyWith(fontSize: 15.sp),
            ),
            SizedBox(height: 12.h),
            ...rows.map(
              (r) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 4.h),
                leading: CircleAvatar(
                  radius: 20.r,
                  backgroundColor:
                      HrModuleColors.primary.withValues(alpha: 0.12),
                  child: Icon(Icons.person_outline, color: HrModuleColors.primary),
                ),
                title: Text(
                  r.name,
                  style: HrModuleTypography.body().copyWith(fontSize: 14.sp),
                ),
                trailing: Text(
                  '${r.count} req',
                  style: HrModuleTypography.caption().copyWith(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: HrModuleColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageDepartments(HrDashboardData data) {
    final depts = data.byDepartment;
    if (depts.isEmpty) {
      return _emptyChart('No department breakdown available.');
    }
    return SingleChildScrollView(
      padding: EdgeInsets.only(top: 4.h, bottom: 24.h),
      child: _chartCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'By department',
              style: HrModuleTypography.sectionHeading().copyWith(fontSize: 15.sp),
            ),
            SizedBox(height: 12.h),
            ...depts.map((d) {
              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: Row(
                  children: [
                    SizedBox(
                      width: 88.w,
                      child: Text(
                        d.label,
                        style: HrModuleTypography.caption()
                            .copyWith(fontSize: 12.sp),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: d.share.clamp(0.0, 1.0),
                          minHeight: 10.h,
                          backgroundColor:
                              HrModuleColors.border.withValues(alpha: 0.35),
                          color: HrModuleColors.secondary,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      '${(d.share * 100).round()}%',
                      style: HrModuleTypography.caption().copyWith(fontSize: 11.sp),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _emptyChart(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: HrModuleTypography.caption().copyWith(fontSize: 13.sp),
        ),
      ),
    );
  }

  Widget _kpiTile(String label, String value, Color accent) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: HrModuleColors.surface,
        borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.r),
        boxShadow: HrModuleColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: HrModuleTypography.counterNumber().copyWith(
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: HrModuleTypography.caption().copyWith(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: accent.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardBody(HrDashboardData data) {
    final pageCount = _pageCount(data);
    final avgLabel = data.avgApprovalDays != null
        ? '${data.avgApprovalDays!.toStringAsFixed(1)}d'
        : '—';
    final isLocalFallback = data.byMonth.isEmpty && data.total > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isLocalFallback)
          Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Text(
              'Charts built from your team request list (dashboard API unavailable).',
              style: HrModuleTypography.caption().copyWith(fontSize: 11.sp),
            ),
          ),
        HrThemedPickerField<int>(
          label: 'Period',
          value: _periodIndex,
          hint: 'This month',
          displayText: (v) => _periods[v ?? _periodIndex],
          options: List.generate(
            _periods.length,
            (i) => HrPickerOption<int>(
              value: i,
              label: _periods[i],
              icon: Icons.date_range_outlined,
              iconColor: HrModuleColors.primary,
            ),
          ),
          onChanged: (v) {
            if (v == null) return;
            setState(() => _periodIndex = v);
          },
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _kpiTile('Total', '${data.total}', HrModuleColors.primary),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _kpiTile(
                'Pending',
                '${data.pending}',
                const Color(0xFFE89B4C),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _kpiTile('Avg time', avgLabel, HrModuleColors.secondary),
            ),
          ],
        ),
        SizedBox(height: 14.h),
        _tabStrip(data),
        SizedBox(height: 10.h),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (i) {
              if (i >= 0 && i < pageCount) {
                setState(() => _dashPage = i);
              }
            },
            children: [
              _pageByType(data),
              _pageByMonth(data),
              _pageTopRequesters(data),
              if (data.includeDepartments) _pageDepartments(data),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashAsync = ref.watch(hrDashboardProvider(_periodKey));

    return Padding(
      padding: EdgeInsets.fromLTRB(
        HrModuleLayout.screenPaddingH.w,
        8.h,
        HrModuleLayout.screenPaddingH.w,
        8.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Dashboard',
                  style: HrModuleTypography.pageTitle().copyWith(fontSize: 20.sp),
                ),
              ),
              dashAsync.maybeWhen(
                data: (d) => IconButton(
                  tooltip: 'Export PDF',
                  onPressed: () => _exportPdf(d),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Expanded(
            child: dashAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Could not load dashboard',
                      style: HrModuleTypography.body().copyWith(fontSize: 14.sp),
                    ),
                    SizedBox(height: 8.h),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(hrDashboardProvider(_periodKey)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: _dashboardBody,
            ),
          ),
        ],
      ),
    );
  }
}
