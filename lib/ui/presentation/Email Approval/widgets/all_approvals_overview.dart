import 'package:el_race/ui/presentation/Email%20Approval/theme/approvals_overview_theme.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/approval_overview_records_sheet.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/stat_counter_card.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Compact ROR tab panel height.
const double _kRorTabHeight = 290;

/// Full-screen Waiting Approval dashboard (All tab).
class AllApprovalsOverview extends StatefulWidget {
  const AllApprovalsOverview({
    super.key,
    required this.invoiceCount,
    required this.pettyCashCount,
    required this.rfqCount,
    required this.hrCount,
    required this.hrItems,
    required this.rfqItems,
    required this.invoiceItems,
    required this.pettyCashItems,
    this.categoryLoading = const {},
    this.categoryLoaded = const {},
    this.categoryErrors = const {},
    this.onCategoryRetry,
    required this.delayedCount,
    this.delayedHrCount = 0,
    this.delayedRfqCount = 0,
    this.delayedInvoiceCount = 0,
    this.delayedPettyCashCount = 0,
    this.rorPercentage,
    this.rorHrRor,
    this.rorRfqRor,
    this.rorInvoiceRor,
    this.rorPettyCashRor,
    this.onDelayedRecordTap,
    this.onCategoryRecordTap,
    this.onHrManagementTestCasesTap,
  });

  final int invoiceCount;
  final int pettyCashCount;
  final int rfqCount;
  final int hrCount;
  final List<Map<String, dynamic>> hrItems;
  final List<Map<String, dynamic>> rfqItems;
  final List<Map<String, dynamic>> invoiceItems;
  final List<Map<String, dynamic>> pettyCashItems;
  final Map<String, bool> categoryLoading;
  final Map<String, bool> categoryLoaded;
  final Map<String, String> categoryErrors;
  final ValueChanged<String>? onCategoryRetry;
  final int delayedCount;
  final int delayedHrCount;
  final int delayedRfqCount;
  final int delayedInvoiceCount;
  final int delayedPettyCashCount;
  final int? rorPercentage;
  final int? rorHrRor;
  final int? rorRfqRor;
  final int? rorInvoiceRor;
  final int? rorPettyCashRor;
  final Future<void> Function(
    BuildContext sheetContext,
    Map<String, dynamic> item,
  )? onDelayedRecordTap;
  final Future<void> Function(
    BuildContext sheetContext,
    Map<String, dynamic> item,
    String categoryKey,
  )? onCategoryRecordTap;
  final VoidCallback? onHrManagementTestCasesTap;

  @override
  State<AllApprovalsOverview> createState() => _AllApprovalsOverviewState();
}

class _AllApprovalsOverviewState extends State<AllApprovalsOverview> {
  int _tabIndex = 0;

  bool _isLoading(String apiKey) =>
      widget.categoryLoading[apiKey] == true &&
      widget.categoryLoaded[apiKey] != true;

  bool _hasError(String apiKey) => widget.categoryErrors.containsKey(apiKey);

  List<Map<String, dynamic>> _itemsFor(String route) {
    switch (route) {
      case 'hr':
        return widget.hrItems;
      case 'rfq':
        return widget.rfqItems;
      case 'invoice':
        return widget.invoiceItems;
      case 'petty_cash':
        return widget.pettyCashItems;
      default:
        return const [];
    }
  }

  int _countFor(String route) {
    switch (route) {
      case 'hr':
        return widget.hrCount;
      case 'rfq':
        return widget.rfqCount;
      case 'invoice':
        return widget.invoiceCount;
      case 'petty_cash':
        return widget.pettyCashCount;
      default:
        return 0;
    }
  }

  void _openCategorySheet(String route, String title) {
    final expectedCount = _countFor(route);
    final loading = _isLoading(route);
    final items = List<Map<String, dynamic>>.from(_itemsFor(route));

    if (items.isEmpty && expectedCount > 0 && !loading) {
      widget.onCategoryRetry?.call(route);
    }

    ApprovalOverviewRecordsSheet.showCategory(
      context: context,
      title: title,
      categoryKey: route,
      getItems: () => List<Map<String, dynamic>>.from(_itemsFor(route)),
      expectedCount: expectedCount,
      isCategoryLoading: () => _isLoading(route),
      onRequestReload: () => widget.onCategoryRetry?.call(route),
      onItemTap: (sheetContext, item, key) =>
          widget.onCategoryRecordTap?.call(sheetContext, item, key) ??
          Future.value(),
    );
  }

  void _openDelayedSheet() {
    ApprovalOverviewRecordsSheet.showDelayed(
      context: context,
      onItemTap: (sheetContext, item) async {
        await widget.onDelayedRecordTap?.call(sheetContext, item);
      },
    );
  }

  List<StatCounterCardData> _waitingCards() {
    void retry(String apiKey) => widget.onCategoryRetry?.call(apiKey);

    return [
      StatCounterCardData(
        id: 'rfq',
        title: 'Request for Quotation',
        subtitle: ApprovalsOverviewTheme.statCardShortLabel('rfq'),
        value: widget.rfqCount,
        backgroundColor: ApprovalsOverviewTheme.statCardRfq,
        route: 'rfq',
        isLoading: _isLoading('rfq'),
        hasError: _hasError('rfq'),
        onTap: () => _openCategorySheet('rfq', 'Request for Quotation'),
        onRetry: () => retry('rfq'),
      ),
      StatCounterCardData(
        id: 'invoice',
        title: 'Invoice',
        subtitle: ApprovalsOverviewTheme.statCardShortLabel('invoice'),
        value: widget.invoiceCount,
        backgroundColor: ApprovalsOverviewTheme.statCardInvoice,
        route: 'invoice',
        isLoading: _isLoading('invoice'),
        hasError: _hasError('invoice'),
        onTap: () => _openCategorySheet('invoice', 'Invoice'),
        onRetry: () => retry('invoice'),
      ),
      StatCounterCardData(
        id: 'petty_cash',
        title: 'Petty Cash',
        subtitle: ApprovalsOverviewTheme.statCardShortLabel('petty_cash'),
        value: widget.pettyCashCount,
        backgroundColor: ApprovalsOverviewTheme.statCardPettyCash,
        route: 'petty_cash',
        isLoading: _isLoading('petty_cash'),
        hasError: _hasError('petty_cash'),
        onTap: () => _openCategorySheet('petty_cash', 'Petty Cash'),
        onRetry: () => retry('petty_cash'),
      ),
      StatCounterCardData(
        id: 'hr_request',
        title: 'Employee Request',
        subtitle: ApprovalsOverviewTheme.statCardShortLabel('hr_request'),
        value: widget.hrCount,
        backgroundColor: ApprovalsOverviewTheme.statCardHr,
        route: 'hr',
        isLoading: _isLoading('hr'),
        hasError: _hasError('hr'),
        onTap: () => _openCategorySheet('hr', 'Employee Request'),
        onRetry: () => retry('hr'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 2.h, 16.w, 0),
          child: const _WaitingApprovalsHeadingCard(),
        ),
        SizedBox(height: 10.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: OverviewSegmentedTabs(
            selectedIndex: _tabIndex,
            onChanged: (i) => setState(() => _tabIndex = i),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _tabIndex == 0
                ? StatCounterGrid(
                    key: const ValueKey('waiting'),
                    cards: _waitingCards(),
                  )
                : SizedBox(
                    key: const ValueKey('ror'),
                    height: _kRorTabHeight.h,
                    child: _RorCard(
                      compact: true,
                      height: _kRorTabHeight.h,
                      rorPercentage: widget.rorPercentage ?? 0,
                      hrRor: widget.rorHrRor,
                      rfqRor: widget.rorRfqRor,
                      invoiceRor: widget.rorInvoiceRor,
                      pettyCashRor: widget.rorPettyCashRor,
                    ),
                  ),
          ),
        ),
        SizedBox(height: 12.h),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16.w,
              0,
              16.w,
              kBottomNavigationBarHeight + context.systemBottomInset + 16.h,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DelayedGlassCard(
                  total: widget.delayedCount,
                  hrCount: widget.delayedHrCount,
                  rfqCount: widget.delayedRfqCount,
                  invoiceCount: widget.delayedInvoiceCount,
                  onTap: _openDelayedSheet,
                ),
                if (widget.onHrManagementTestCasesTap != null) ...[
                  SizedBox(height: 10.h),
                  _HrManagementTestCasesCard(
                    onTap: widget.onHrManagementTestCasesTap!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Section 1: Heading ─────────────────────────────────────────────────────

class _WaitingApprovalsHeadingCard extends StatelessWidget {
  const _WaitingApprovalsHeadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 12.w, 13.h),
      decoration: ApprovalsOverviewTheme.waitingHeadingDecoration(),
      child: Row(
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
            child: Icon(
              Icons.pending_actions_rounded,
              size: 20.sp,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Waiting for approvals',
                  style: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Review pending requests across modules',
                  style: GoogleFonts.poppins(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section 2: ROR — line chart (Tickets Resolved style) ─────────────────

class _RorCard extends StatelessWidget {
  const _RorCard({
    required this.rorPercentage,
    this.hrRor,
    this.rfqRor,
    this.invoiceRor,
    this.pettyCashRor,
    this.compact = false,
    this.height,
  });

  final int rorPercentage;
  final int? hrRor;
  final int? rfqRor;
  final int? invoiceRor;
  final int? pettyCashRor;
  final bool compact;
  final double? height;

  List<_RorSeriesPoint> get _points => [
        _RorSeriesPoint('Employee', hrRor ?? 0, ApprovalsOverviewTheme.hr),
        _RorSeriesPoint('RFQ', rfqRor ?? 0, ApprovalsOverviewTheme.rfq),
        _RorSeriesPoint(
          'Petty Cash',
          pettyCashRor ?? 0,
          ApprovalsOverviewTheme.petty,
        ),
        _RorSeriesPoint('Invoice', invoiceRor ?? 0, ApprovalsOverviewTheme.invoice),
      ];

  int get _displayOverall {
    final active = _points.where((p) => p.percent > 0).toList();
    if (active.isEmpty) return rorPercentage.clamp(0, 100);
    final categoryAvg = (active.fold<int>(0, (sum, p) => sum + p.percent) /
            active.length)
        .round();
    final cappedApi = rorPercentage.clamp(0, 100);
    if (cappedApi <= 0) return categoryAvg;
    if ((cappedApi - categoryAvg).abs() > 35) return categoryAvg;
    return cappedApi;
  }

  /// Chart scale follows category values only — not the headline overall %.
  double get _chartMaxY {
    final peak = _points.fold<int>(
      0,
      (max, p) => p.percent > max ? p.percent : max,
    );
    if (peak <= 0) return 100;
    final padded = ((peak * 1.35) / 5).ceil() * 5.0;
    return padded.clamp(15, 100);
  }

  static bool _isWholeStep(double value) =>
      (value - value.roundToDouble()).abs() < 0.001;

  @override
  Widget build(BuildContext context) {
    final points = _points;
    final displayOverall = _displayOverall;
    final hasData = points.any((p) => p.percent > 0) || displayOverall > 0;

    return Container(
      height: compact ? height : null,
      padding: EdgeInsets.fromLTRB(
        compact ? 12.w : 16.w,
        compact ? 12.h : 16.h,
        compact ? 12.w : 16.w,
        compact ? 10.h : 14.h,
      ),
      decoration: BoxDecoration(
        color: ApprovalsOverviewTheme.white,
        borderRadius: BorderRadius.circular(compact ? 16.r : 18.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Text(
            'Response Rate',
            style: GoogleFonts.poppins(
              fontSize: compact ? 14.sp : 16.sp,
              fontWeight: FontWeight.w700,
              color: ApprovalsOverviewTheme.textDark,
            ),
          ),
          SizedBox(height: compact ? 2.h : 4.h),
          Text(
            '$displayOverall%',
            style: GoogleFonts.poppins(
              fontSize: compact ? 26.sp : 30.sp,
              fontWeight: FontWeight.w700,
              color: ApprovalsOverviewTheme.textDark,
              height: 1.05,
            ),
          ),
          SizedBox(height: compact ? 8.h : 12.h),
          if (hasData) ...[
            if (!compact) ...[
              _RorValueLabelsRow(points: points),
              SizedBox(height: 6.h),
            ],
            Expanded(
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (points.length - 1).toDouble(),
                  minY: 0,
                  maxY: _chartMaxY,
                  clipData: const FlClipData.all(),
                  lineTouchData: const LineTouchData(enabled: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _chartMaxY / 4,
                    getDrawingHorizontalLine: (_) => const FlLine(
                      color: Color(0xFFECEEF2),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: compact
                        ? AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 18.h,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                if (!_isWholeStep(value)) {
                                  return const SizedBox.shrink();
                                }
                                final i = value.round();
                                if (i < 0 || i >= points.length) {
                                  return const SizedBox.shrink();
                                }
                                return Text(
                                  '${points[i].percent}%',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w700,
                                    color: ApprovalsOverviewTheme.textDark,
                                  ),
                                );
                              },
                            ),
                          )
                        : const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: compact ? 24.w : 28.w,
                        interval: _chartMaxY / 4,
                        getTitlesWidget: (value, meta) {
                          if (value < 0 || value > _chartMaxY) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            value.toInt().toString(),
                            style: GoogleFonts.poppins(
                              fontSize: 8.sp,
                              fontWeight: FontWeight.w500,
                              color: ApprovalsOverviewTheme.textSoft,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: compact ? 18.h : 22.h,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          if (!_isWholeStep(value)) {
                            return const SizedBox.shrink();
                          }
                          final i = value.round();
                          if (i < 0 || i >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: EdgeInsets.only(top: 3.h),
                            child: Text(
                              _shortLabel(points[i].label),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 7.sp,
                                fontWeight: FontWeight.w600,
                                color: ApprovalsOverviewTheme.textSoft,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < points.length; i++)
                          FlSpot(i.toDouble(), points[i].percent.toDouble()),
                      ],
                      isCurved: true,
                      curveSmoothness: 0.32,
                      color: ApprovalsOverviewTheme.rorChartLine,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) {
                          return FlDotCirclePainter(
                            radius: compact ? 3.5 : 4.5,
                            color: ApprovalsOverviewTheme.white,
                            strokeWidth: 2.5,
                            strokeColor: points[index].color,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            ApprovalsOverviewTheme.rorChartFill
                                .withValues(alpha: 0.28),
                            ApprovalsOverviewTheme.rorChartFill
                                .withValues(alpha: 0.02),
                          ],
                        ),
                      ),
                    ),
                  ],
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: displayOverall.toDouble().clamp(0, _chartMaxY),
                        color: ApprovalsOverviewTheme.screenDeep
                            .withValues(alpha: 0.35),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!compact) ...[
              SizedBox(height: 12.h),
              Row(
                children: [
                  for (var i = 0; i < points.length; i++)
                    Expanded(
                      child: _RorLegendItem(point: points[i]),
                    ),
                ],
              ),
            ] else ...[
              SizedBox(height: 6.h),
              Row(
                children: [
                  for (var i = 0; i < points.length; i++)
                    Expanded(
                      child: _RorLegendItem(point: points[i], compact: true),
                    ),
                ],
              ),
            ],
          ] else
            Expanded(
              child: Center(
                child: Text(
                  'No response rate data yet',
                  style: GoogleFonts.poppins(
                    fontSize: 11.sp,
                    color: ApprovalsOverviewTheme.textSoft,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _shortLabel(String label) {
    switch (label) {
      case 'Employee':
        return 'Emp';
      case 'Petty Cash':
        return 'Cash';
      default:
        return label;
    }
  }
}

class _RorSeriesPoint {
  const _RorSeriesPoint(this.label, this.percent, this.color);
  final String label;
  final int percent;
  final Color color;
}

class _RorValueLabelsRow extends StatelessWidget {
  const _RorValueLabelsRow({required this.points});

  final List<_RorSeriesPoint> points;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 28.w),
        Expanded(
          child: Row(
            children: [
              for (var i = 0; i < points.length; i++)
                Expanded(
                  child: Text(
                    '${points[i].percent}%',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: ApprovalsOverviewTheme.textDark,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RorLegendItem extends StatelessWidget {
  const _RorLegendItem({required this.point, this.compact = false});

  final _RorSeriesPoint point;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          point.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: compact ? 9.sp : 10.sp,
            fontWeight: FontWeight.w600,
            color: point.color,
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          '${point.percent}%',
          style: GoogleFonts.poppins(
            fontSize: compact ? 11.sp : 13.sp,
            fontWeight: FontWeight.w700,
            color: ApprovalsOverviewTheme.textDark,
            height: 1,
          ),
        ),
      ],
    );
  }
}

// ─── Section 3: Delayed ─────────────────────────────────────────────────────

class _DelayedGlassCard extends StatelessWidget {
  const _DelayedGlassCard({
    required this.total,
    required this.hrCount,
    required this.rfqCount,
    required this.invoiceCount,
    this.onTap,
  });

  final int total;
  final int hrCount;
  final int rfqCount;
  final int invoiceCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OverviewGlassPanel(
      fillAlpha: 0.84,
      blurSigma: 6,
      onTap: onTap,
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 12.w, 13.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Delayed Requests',
                  style: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: ApprovalsOverviewTheme.textDark,
                  ),
                ),
              ),
              OverviewArrowButton(onTap: onTap, size: 26),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            total > 0
                ? 'Beyond SLA · Action required'
                : 'All requests on time',
            style: GoogleFonts.poppins(
              fontSize: 10.sp,
              fontWeight: FontWeight.w500,
              color: ApprovalsOverviewTheme.textSoft,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$total',
                style: GoogleFonts.poppins(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w700,
                  color: total > 0
                      ? ApprovalsOverviewTheme.hr
                      : ApprovalsOverviewTheme.textDark,
                  height: 1,
                ),
              ),
              SizedBox(width: 5.w),
              Text(
                'Total',
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: ApprovalsOverviewTheme.textSoft,
                ),
              ),
              const Spacer(),
              _DelayedInline(value: hrCount, label: 'HR'),
              SizedBox(width: 12.w),
              _DelayedInline(value: rfqCount, label: 'RFQ'),
              SizedBox(width: 12.w),
              _DelayedInline(value: invoiceCount, label: 'Inv'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DelayedInline extends StatelessWidget {
  const _DelayedInline({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = ApprovalsOverviewTheme.accentFor(
      label == 'HR'
          ? 'hr'
          : label == 'RFQ'
              ? 'rfq'
              : 'invoice',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$value',
          style: GoogleFonts.poppins(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 9.sp,
            fontWeight: FontWeight.w500,
            color: ApprovalsOverviewTheme.textSoft,
          ),
        ),
      ],
    );
  }
}

class _HrManagementTestCasesCard extends StatelessWidget {
  const _HrManagementTestCasesCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OverviewGlassPanel(
      fillAlpha: 0.8,
      blurSigma: 4,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'HR Management Test Cases',
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: ApprovalsOverviewTheme.textDark,
              ),
            ),
          ),
          const OverviewArrowButton(size: 24),
        ],
      ),
    );
  }
}
