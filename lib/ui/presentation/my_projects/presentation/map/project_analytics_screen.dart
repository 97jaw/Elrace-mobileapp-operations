import 'dart:typed_data';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:el_race/chat/chat_module_helper.dart';
import 'package:el_race/chat/models/models.dart';
import 'package:el_race/chat/repositories/chat_repository.dart';
import 'package:el_race/data/repositories/company_repository.dart';
import 'package:el_race/ui/presentation/my_projects/data/datasources/project_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_expense_breakdown_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_expense_summary_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_scurve_model.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/map/project_expense_breakdown_panel.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/map/project_expense_summary_panel.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_dashboard_access.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_analytics_site_report_tab.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_glass_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class ProjectAnalyticsScreen extends StatefulWidget {
  const ProjectAnalyticsScreen({super.key, required this.project});

  final ProjectEntity project;

  @override
  State<ProjectAnalyticsScreen> createState() => _ProjectAnalyticsScreenState();
}

class _ProjectAnalyticsScreenState extends State<ProjectAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ProjectRemoteDataSource _remoteDataSource;
  late final Future<ProjectScurveData> _future;
  late Future<_ProjectFinancialsData> _financialsFuture;
  late final bool _showFinancials;
  int? _snapshotWeeks = 10; // null => All

  @override
  void initState() {
    super.initState();
    _showFinancials = ProjectsDashboardAccess.isManagementUser();
    final tabCount = _showFinancials ? 3 : 2;
    _tabController = TabController(length: tabCount, vsync: this);
    _remoteDataSource = ProjectRemoteDataSource();
    _future = _remoteDataSource.fetchProjectScurve(widget.project.projectId);
    _financialsFuture = _loadFinancials();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Widget> get _tabViews {
    final progress = FutureBuilder<ProjectScurveData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: ProjectsDashboardTheme.white,
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Text(
                '${snapshot.error}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ProjectsDashboardTheme.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }
        final data = snapshot.data;
        if (data == null || data.series.isEmpty) {
          return Center(
            child: Text(
              'No analytics data available for this project.',
              style: TextStyle(
                color: ProjectsDashboardTheme.greyPanel,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }
        return _ProgressAnalyticsBody(
          data: data,
          project: widget.project,
          snapshotWeeks: _snapshotWeeks,
          onSnapshotWeeksChanged: (v) {
            setState(() => _snapshotWeeks = v);
          },
        );
      },
    );

    final financials = FutureBuilder<_ProjectFinancialsData>(
      future: _financialsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _FinancialLoadingView();
        }
        if (snapshot.hasError) {
          return _FinancialFatalErrorView(onRetry: _reloadFinancials);
        }
        final data = snapshot.data;
        if (data == null) {
          return _FinancialFatalErrorView(onRetry: _reloadFinancials);
        }
        return _ProjectFinancialsBody(
          data: data,
          onRetry: _reloadFinancials,
        );
      },
    );

    final siteReport = ProjectAnalyticsSiteReportTab(
      projectId: '${widget.project.projectId}',
      projectName: widget.project.name,
    );

    if (_showFinancials) {
      return [progress, financials, siteReport];
    }
    return [progress, siteReport];
  }

  List<Widget> get _tabs {
    if (_showFinancials) {
      return const [
        Tab(text: 'Project progress'),
        Tab(text: 'Project Financials'),
        Tab(text: 'Site Report'),
      ];
    }
    return const [
      Tab(text: 'Project progress'),
      Tab(text: 'Site Report'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xF01E2365),
              Color(0xE6353A44),
              Color(0xF07A1F32),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: Column(
          children: [
            ProjectsGlassChromeHeader(
              title: 'Project Analytics',
              showBack: true,
              bottom: _AutoMarqueeTitle(
                text: widget.project.name,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: ProjectsDashboardTheme.greyPanel,
                ),
              ),
              tabsHeight: 18,
            ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                child: Container(
                  padding: EdgeInsets.all(4.w),
                  decoration: ProjectsDashboardTheme.frostedPanel(radius: 14),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      gradient: ProjectsDashboardTheme.maroonAccentGradient,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    labelColor: ProjectsDashboardTheme.white,
                    unselectedLabelColor:
                        ProjectsDashboardTheme.greyPanel.withValues(alpha: 0.95),
                    labelStyle:
                        TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700),
                    unselectedLabelStyle:
                        TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500),
                    tabs: _tabs,
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _tabViews,
                ),
              ),
            ],
          ),
        ),
    );
  }

  Future<_ProjectFinancialsData> _loadFinancials() async {
    final projectId = widget.project.projectId;
    final results = await Future.wait([
      _remoteDataSource.fetchProjectExpenseSummary(projectId),
      _remoteDataSource.fetchProjectExpenseBreakdown(projectId),
    ]);
    return _ProjectFinancialsData(
      summary: results[0] as ProjectExpenseSummaryModel,
      breakdown: results[1] as ProjectExpenseBreakdownResult,
    );
  }

  void _reloadFinancials() {
    setState(() {
      _financialsFuture = _loadFinancials();
    });
  }
}

class _ProjectFinancialsData {
  const _ProjectFinancialsData({
    required this.summary,
    required this.breakdown,
  });

  final ProjectExpenseSummaryModel summary;
  final ProjectExpenseBreakdownResult breakdown;
}

class _FinancialLoadingView extends StatelessWidget {
  const _FinancialLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: ProjectsDashboardTheme.white,
      ),
    );
  }
}

class _FinancialFatalErrorView extends StatelessWidget {
  const _FinancialFatalErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
            SizedBox(height: 8.h),
            Text(
              'Unable to load financial data.',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: ProjectsDashboardTheme.white,
              ),
            ),
            SizedBox(height: 8.h),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectFinancialsBody extends StatefulWidget {
  const _ProjectFinancialsBody({
    required this.data,
    required this.onRetry,
  });

  final _ProjectFinancialsData data;
  final VoidCallback onRetry;

  @override
  State<_ProjectFinancialsBody> createState() => _ProjectFinancialsBodyState();
}

class _ProjectFinancialsBodyState extends State<_ProjectFinancialsBody> {
  /// 0 = Analytics (ERP summary), 1 = Cost distribution (GL breakdown)
  int _financialSection = 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _financialSectionToggle(),
          SizedBox(height: 12.h),
          Expanded(
            child: _financialSection == 0
                ? ProjectExpenseSummaryPanel(
                    summary: widget.data.summary,
                  )
                : ProjectExpenseBreakdownPanel(
                    result: widget.data.breakdown,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _financialSectionToggle() {
    Widget seg({
      required IconData icon,
      required String label,
      required int index,
    }) {
      final on = _financialSection == index;
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _financialSection = index),
            borderRadius: BorderRadius.circular(14.r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
              decoration: on
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(14.r),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          ProjectsDashboardTheme.navy.withValues(alpha: 0.88),
                          ProjectsDashboardTheme.maroon.withValues(alpha: 0.78),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.38),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ProjectsDashboardTheme.navy
                              .withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    )
                  : analyticsGlassPanel(radius: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18.sp,
                    color: on
                        ? ProjectsDashboardTheme.white
                        : ProjectsDashboardTheme.greyPanel
                            .withValues(alpha: 0.85),
                  ),
                  SizedBox(width: 8.w),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w800,
                        color: on
                            ? ProjectsDashboardTheme.white
                            : ProjectsDashboardTheme.greyPanel
                                .withValues(alpha: 0.9),
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

    return Row(
      children: [
        seg(
          icon: Icons.insights_rounded,
          label: 'Analytics',
          index: 0,
        ),
        SizedBox(width: 10.w),
        seg(
          icon: Icons.pie_chart_outline_rounded,
          label: 'Cost distribution',
          index: 1,
        ),
      ],
    );
  }
}

class _SectionContainer extends StatelessWidget {
  const _SectionContainer({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12.sp,
              color: const Color(0xFF111827),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          child,
        ],
      ),
    );
  }
}

class _SectionErrorCard extends StatelessWidget {
  const _SectionErrorCard({required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFB91C1C)),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10.sp,
                color: const Color(0xFF7F1D1D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _ProgressAnalyticsBody extends StatefulWidget {
  const _ProgressAnalyticsBody({
    required this.data,
    required this.project,
    required this.snapshotWeeks,
    required this.onSnapshotWeeksChanged,
  });

  final ProjectScurveData data;
  final ProjectEntity project;
  final int? snapshotWeeks;
  final ValueChanged<int?> onSnapshotWeeksChanged;

  @override
  State<_ProgressAnalyticsBody> createState() => _ProgressAnalyticsBodyState();
}

class _ProgressAnalyticsBodyState extends State<_ProgressAnalyticsBody> {
  bool _isSending = false;
  bool _sentDone = false;

  @override
  Widget build(BuildContext context) {
    final kpi = widget.data.kpis;
    final status = kpi.status.toLowerCase();
    final statusColor = status == 'green'
        ? const Color(0xFF16A34A)
        : status == 'amber' || status == 'yellow'
            ? const Color(0xFFF59E0B)
            : const Color(0xFFDC2626);
    final isBehind = kpi.variance < 0;
    final varianceText =
        '${isBehind ? 'Behind' : 'Ahead'} by ${kpi.variance.abs().toStringAsFixed(1)}%';
    final window = widget.snapshotWeeks ?? widget.data.series.length;
    final visibleRows = widget.data.series.length <= window
        ? widget.data.series
        : widget.data.series.sublist(widget.data.series.length - window);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF111827), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: statusColor.withValues(alpha: 0.7)),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 10.sp,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'SPI ${kpi.spi.toStringAsFixed(3)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Text(
                  varianceText,
                  style: TextStyle(
                    color: isBehind ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Range: week ${widget.data.rangeStart} - ${widget.data.rangeEnd}',
                  style: TextStyle(color: const Color(0xFFCBD5E1), fontSize: 10.sp),
                ),
                SizedBox(height: 10.h),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14.r,
                      backgroundColor: Colors.white24,
                      backgroundImage:
                          (widget.project.managerPhoto != null &&
                                  widget.project.managerPhoto!.isNotEmpty)
                              ? NetworkImage(widget.project.managerPhoto!)
                              : null,
                      child: (widget.project.managerPhoto == null ||
                              widget.project.managerPhoto!.isEmpty)
                          ? Icon(Icons.person_rounded, color: Colors.white, size: 14.sp)
                          : null,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        widget.project.projectManagerName ?? 'Manager not assigned',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              _miniKpiCard('Planned', '${kpi.planned.toStringAsFixed(1)}%',
                  const Color(0xFF2563EB)),
              SizedBox(width: 8.w),
              _miniKpiCard('Actual', '${kpi.actual.toStringAsFixed(1)}%',
                  const Color(0xFF16A34A)),
              SizedBox(width: 8.w),
              _miniKpiCard(
                'Variance',
                '${kpi.variance.toStringAsFixed(1)}%',
                isBehind ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0B3A87), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFF1E3A8A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Forecast',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.sp,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 6.h),
                _forecastLine('EAC week', widget.data.forecast.eacWeek.toStringAsFixed(1)),
                SizedBox(height: 6.h),
                _forecastLine('Expected completion', widget.data.forecast.expectedCompletion),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Text(
                'Snapshot',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: ProjectsDashboardTheme.white,
                ),
              ),
              const Spacer(),
              _weeksChip('Last 10', widget.snapshotWeeks == 10, () {
                widget.onSnapshotWeeksChanged(10);
              }),
              SizedBox(width: 8.w),
              _weeksChip('All', widget.snapshotWeeks == null, () {
                widget.onSnapshotWeeksChanged(null);
              }),
              SizedBox(width: 6.w),
              _actionCompactButton(
                title: 'View Report',
                icon: Icons.picture_as_pdf_rounded,
                colors: const [Color(0xFF0F766E), Color(0xFF14B8A6)],
                onTap: () => _openReport(context, visibleRows),
              ),
              SizedBox(width: 6.w),
              _actionCompactButton(
                title: 'View and Send',
                icon: _sentDone ? Icons.check_circle_rounded : Icons.send_rounded,
                colors: const [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                onTap: _isSending ? null : () => _openSendDialog(visibleRows),
                isLoading: _isSending,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Container(
            height: 250.h,
            decoration: BoxDecoration(
              color: kAnalyticsFadedPanel,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: kAnalyticsFadedPanelBorder),
            ),
            child: Column(
              children: [
                _snapshotHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final point in visibleRows)
                          _snapshotRow(
                            week: point.week,
                            planned: point.planned,
                            actual: point.actual,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
        ],
      ),
    );
  }

  Widget _miniKpiCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: kAnalyticsFadedPanel,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: kAnalyticsFadedPanelBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 10.sp,
                color: const Color(0xFF6B7280).withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              value,
              style: TextStyle(
                fontSize: 12.sp,
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _forecastLine(String title, String value) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Text(
        '$title: $value',
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _snapshotHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6).withValues(alpha: 0.72),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
      ),
      child: Row(
        children: [
          _h('Week'),
          _h('Planned'),
          _h('Actual'),
          _h('Gap'),
        ],
      ),
    );
  }

  Widget _h(String t) {
    return Expanded(
      child: Text(
        t,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF4B5563).withValues(alpha: 0.88),
        ),
      ),
    );
  }

  Widget _weeksChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1E2365)
              : kAnalyticsFadedPanel,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: selected
                ? const Color(0xFF1E2365)
                : kAnalyticsFadedPanelBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF374151),
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _snapshotRow({
    required int week,
    required double planned,
    required double actual,
  }) {
    final gap = actual - planned;
    final gapColor = gap < 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: const Color(0xFFE5E7EB).withValues(alpha: 0.65),
          ),
        ),
      ),
      child: Row(
        children: [
          _v('W$week'),
          _v('${planned.toStringAsFixed(1)}%'),
          _v('${actual.toStringAsFixed(1)}%'),
          Expanded(
            child: Text(
              '${gap.toStringAsFixed(1)}%',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.sp,
                color: gapColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _v(String t) {
    return Expanded(
      child: Text(
        t,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10.sp,
          color: const Color(0xFF111827).withValues(alpha: 0.88),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _actionCompactButton({
    required String title,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 6.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 13.sp),
                SizedBox(width: 4.w),
                if (isLoading)
                  SizedBox(
                    width: 9.w,
                    height: 9.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: Colors.white,
                    ),
                  )
                else
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openReport(
      BuildContext context, List<ProjectScurvePoint> snapshot) async {
    final bytes = await _buildReportPdf(snapshot);
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AnalyticsPdfViewerScreen(
          bytes: bytes,
          title: '${widget.data.projectName} Progress Report',
        ),
      ),
    );
  }

  Future<Uint8List> _buildReportPdf(List<ProjectScurvePoint> snapshot) async {
    final company = await CompanyRepository().getCompany();
    final logoBytes = await _loadAssetBytes(company.logo);
    final clientBytes = await _loadNetworkBytes(widget.project.clientImageUrl);
    final managerBytes = await _loadNetworkBytes(widget.project.managerPhoto);

    final document = PdfDocument();
    final page = document.pages.add();
    final graphics = page.graphics;
    final bounds = page.getClientSize();

    final titleFont =
        PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold);
    final headerFont = PdfStandardFont(PdfFontFamily.helvetica, 11);
    final boldSmall =
        PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
    final small = PdfStandardFont(PdfFontFamily.helvetica, 10);

    graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(13, 36, 87)),
      bounds: Rect.fromLTWH(0, 0, bounds.width, 74),
    );
    if (logoBytes != null) {
      graphics.drawImage(
        PdfBitmap(logoBytes),
        Rect.fromLTWH(14, 10, 108, 54),
      );
    }
    graphics.drawString(
      'Project Progress Report',
      titleFont,
      brush: PdfBrushes.white,
      bounds: Rect.fromLTWH(130, 16, bounds.width - 140, 24),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
    );
    graphics.drawString(
      company.companyName,
      PdfStandardFont(PdfFontFamily.helvetica, 9),
      brush: PdfSolidBrush(PdfColor(226, 232, 240)),
      bounds: Rect.fromLTWH(130, 40, bounds.width - 140, 18),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
    );

    double y = 84;
    if (clientBytes != null) {
      graphics.drawImage(PdfBitmap(clientBytes), Rect.fromLTWH(16, y, 42, 42));
    } else {
      graphics.drawRectangle(
        pen: PdfPens.lightGray,
        brush: PdfSolidBrush(PdfColor(241, 245, 249)),
        bounds: Rect.fromLTWH(16, y, 42, 42),
      );
    }
    if (managerBytes != null) {
      graphics.drawImage(
        PdfBitmap(managerBytes),
        Rect.fromLTWH(bounds.width - 58, y, 42, 42),
      );
    } else {
      graphics.drawRectangle(
        pen: PdfPens.lightGray,
        brush: PdfSolidBrush(PdfColor(241, 245, 249)),
        bounds: Rect.fromLTWH(bounds.width - 58, y, 42, 42),
      );
    }

    graphics.drawString(
      widget.project.name,
      PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold),
      bounds: Rect.fromLTWH(66, y + 2, bounds.width - 132, 16),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    graphics.drawString(
      'Manager: ${widget.project.projectManagerName ?? '—'}',
      headerFont,
      bounds: Rect.fromLTWH(66, y + 18, bounds.width - 132, 14),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    graphics.drawString(
      'Start: ${widget.project.dateStart}    End: ${widget.project.date}',
      PdfStandardFont(PdfFontFamily.helvetica, 9),
      bounds: Rect.fromLTWH(66, y + 32, bounds.width - 132, 12),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    y += 56;
    graphics.drawString(
      'Report date: ${DateTime.now().toString().split(' ').first}',
      PdfStandardFont(PdfFontFamily.helvetica, 10),
      bounds: Rect.fromLTWH(16, y, bounds.width - 32, 18),
    );
    y += 26;

    graphics.drawRectangle(
      pen: PdfPens.lightGray,
      brush: PdfSolidBrush(PdfColor(246, 248, 252)),
      bounds: Rect.fromLTWH(16, y, bounds.width - 32, 66),
    );
    graphics.drawString('Planned: ${widget.data.kpis.planned.toStringAsFixed(1)}%',
        boldSmall, bounds: Rect.fromLTWH(24, y + 10, 180, 16));
    graphics.drawString('Actual: ${widget.data.kpis.actual.toStringAsFixed(1)}%',
        boldSmall, bounds: Rect.fromLTWH(24, y + 28, 180, 16));
    graphics.drawString('Variance: ${widget.data.kpis.variance.toStringAsFixed(1)}%',
        boldSmall, bounds: Rect.fromLTWH(24, y + 46, 180, 16));
    graphics.drawString('SPI: ${widget.data.kpis.spi.toStringAsFixed(3)}', boldSmall,
        bounds: Rect.fromLTWH(250, y + 10, 160, 16));
    graphics.drawString('Status: ${widget.data.kpis.status.toUpperCase()}', boldSmall,
        bounds: Rect.fromLTWH(250, y + 28, 160, 16));
    graphics.drawString(
      'Expected completion: ${widget.data.forecast.expectedCompletion}',
      boldSmall,
      bounds: Rect.fromLTWH(250, y + 46, 260, 16),
    );
    y += 80;

    final grid = PdfGrid();
    grid.columns.add(count: 4);
    grid.headers.add(1);
    final header = grid.headers[0];
    header.cells[0].value = 'Week';
    header.cells[1].value = 'Planned';
    header.cells[2].value = 'Actual';
    header.cells[3].value = 'Gap';
    for (final p in snapshot) {
      final row = grid.rows.add();
      row.cells[0].value = 'W${p.week}';
      row.cells[1].value = '${p.planned.toStringAsFixed(1)}%';
      row.cells[2].value = '${p.actual.toStringAsFixed(1)}%';
      row.cells[3].value = '${(p.actual - p.planned).toStringAsFixed(1)}%';
      final idx = grid.rows.count - 1;
      if (idx.isEven) {
        row.style.backgroundBrush = PdfSolidBrush(PdfColor(249, 250, 251));
      }
      if (p.actual - p.planned < 0) {
        row.cells[3].style.textBrush = PdfSolidBrush(PdfColor(185, 28, 28));
      } else {
        row.cells[3].style.textBrush = PdfSolidBrush(PdfColor(21, 128, 61));
      }
    }
    grid.style = PdfGridStyle(
      font: small,
      cellPadding: PdfPaddings(left: 4, right: 4, top: 3, bottom: 3),
    );
    header.style = PdfGridRowStyle(
      backgroundBrush: PdfSolidBrush(PdfColor(30, 58, 138)),
      textBrush: PdfBrushes.white,
      font: boldSmall,
    );
    grid.draw(
      page: page,
      bounds: Rect.fromLTWH(16, y, bounds.width - 32, bounds.height - y - 20),
    );

    final bytes = Uint8List.fromList(document.saveSync());
    document.dispose();
    return bytes;
  }

  Future<void> _openSendDialog(List<ProjectScurvePoint> snapshot) async {
    final selected = <ChatUser>{};
    final users = await _loadChatUsers();
    if (!mounted) return;
    if (users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No chat users available to send.')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final queryController = TextEditingController();
        final filtered = ValueNotifier<List<ChatUser>>(users);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Send report to users'),
              content: SizedBox(
                width: 370.w,
                height: 420.h,
                child: Column(
                  children: [
                    TextField(
                      controller: queryController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search user',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        final q = value.trim().toLowerCase();
                        filtered.value = q.isEmpty
                            ? users
                            : users
                                .where((u) => u.name.toLowerCase().contains(q))
                                .toList();
                      },
                    ),
                    SizedBox(height: 10.h),
                    Expanded(
                      child: ValueListenableBuilder<List<ChatUser>>(
                        valueListenable: filtered,
                        builder: (_, list, __) {
                          return ListView.builder(
                            itemCount: list.length,
                            itemBuilder: (_, i) {
                              final user = list[i];
                              final isChecked = selected.contains(user);
                              return Container(
                                margin: EdgeInsets.only(bottom: 8.h),
                                decoration: BoxDecoration(
                                  gradient: isChecked
                                      ? const LinearGradient(
                                          colors: [
                                            Color(0xFFE0E7FF),
                                            Color(0xFFDBEAFE),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : const LinearGradient(
                                          colors: [
                                            Color(0xFFFFFFFF),
                                            Color(0xFFF8FAFC),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                  borderRadius: BorderRadius.circular(14.r),
                                  border: Border.all(
                                    color: isChecked
                                        ? const Color(0xFF3B82F6)
                                        : const Color(0xFFE5E7EB),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x14000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14.r),
                                    onTap: () {
                                      setDialogState(() {
                                        if (isChecked) {
                                          selected.remove(user);
                                        } else {
                                          selected.add(user);
                                        }
                                      });
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10.w,
                                        vertical: 8.h,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(2.w),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isChecked
                                                    ? const Color(0xFF1D4ED8)
                                                    : const Color(0xFF9CA3AF),
                                                width: 1.6,
                                              ),
                                              color: isChecked
                                                  ? const Color(0xFF1D4ED8)
                                                  : Colors.white,
                                            ),
                                            child: Icon(
                                              isChecked
                                                  ? Icons.check_rounded
                                                  : Icons.circle_outlined,
                                              size: 14.sp,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(width: 10.w),
                                          CircleAvatar(
                                            radius: 18.r,
                                            backgroundColor: const Color(0xFFE5E7EB),
                                            backgroundImage: (user.avatarUrl != null &&
                                                    user.avatarUrl!.isNotEmpty)
                                                ? NetworkImage(user.avatarUrl!)
                                                : null,
                                            child: (user.avatarUrl == null ||
                                                    user.avatarUrl!.isEmpty)
                                                ? Icon(
                                                    Icons.person_rounded,
                                                    size: 16.sp,
                                                    color: const Color(0xFF4B5563),
                                                  )
                                                : null,
                                          ),
                                          SizedBox(width: 10.w),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _OneLineMarqueeText(
                                                  text: user.name,
                                                  style: TextStyle(
                                                    fontSize: 12.sp,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(0xFF111827),
                                                  ),
                                                ),
                                                SizedBox(height: 2.h),
                                                Text(
                                                  user.roleName ?? 'User',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 10.sp,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(0xFF6B7280),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(dialogContext);
                          await _sendReportToUsers(selected.toList(), snapshot);
                        },
                  child: Text('Send (${selected.length})'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<ChatUser>> _loadChatUsers() async {
    final session = ChatModuleHelper.instance.currentSession;
    final currentUid = ChatModuleHelper.instance.currentUid;
    try {
      Query<Map<String, dynamic>> query =
          FirebaseFirestore.instance.collection('users');
      if (session?.companyId != null) {
        query = query.where('company_id', isEqualTo: session!.companyId);
      }
      final snapshot = await query.limit(300).get();
      return snapshot.docs
          .map((d) => ChatUser.fromFirestore(d))
          .where((u) => u.uid != currentUid && u.name.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    } catch (_) {
      return <ChatUser>[];
    }
  }

  Future<void> _sendReportToUsers(
    List<ChatUser> users,
    List<ProjectScurvePoint> snapshot,
  ) async {
    if (!ChatModuleHelper.instance.isChatEnabled ||
        ChatModuleHelper.instance.currentUid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat module is not ready yet.')),
      );
      return;
    }
    setState(() {
      _isSending = true;
      _sentDone = false;
    });
    try {
      final bytes = await _buildReportPdf(snapshot);
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/project_${widget.project.projectId}_analytics_report.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);

      final session = ChatModuleHelper.instance.currentSession;
      final currentName = session?.name ?? 'Project Team';
      for (final user in users) {
        final chatId = await ChatRepository.instance.createOrGetDmChat(
          otherUid: user.uid,
          otherName: user.name,
          currentUserName: currentName,
          otherRoleId: user.roleId,
          otherBranchId: user.branchId,
          otherCompanyId: user.companyId,
          currentUserRoleId: session?.roleId,
          currentUserBranchId: session?.branchId,
          currentUserCompanyId: session?.companyId,
        );
        await ChatRepository.instance.sendFile(
          chatId,
          file,
          caption: 'Project analytics report - ${widget.project.name}',
          mimeType: 'application/pdf',
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report sent to ${users.length} user(s).')),
      );
      setState(() => _sentDone = true);
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _sentDone = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send report: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<Uint8List?> _loadAssetBytes(String path) async {
    try {
      final data = await rootBundle.load(path);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _loadNetworkBytes(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

class _AnalyticsPdfViewerScreen extends StatelessWidget {
  const _AnalyticsPdfViewerScreen({required this.bytes, required this.title});

  final Uint8List bytes;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: SfPdfViewer.memory(bytes),
    );
  }
}

class _AutoMarqueeTitle extends StatefulWidget {
  const _AutoMarqueeTitle({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_AutoMarqueeTitle> createState() => _AutoMarqueeTitleState();
}

class _AutoMarqueeTitleState extends State<_AutoMarqueeTitle> {
  final ScrollController _controller = ScrollController();
  bool _running = false;

  @override
  void dispose() {
    _running = false;
    _controller.dispose();
    super.dispose();
  }

  void _startIfNeeded() {
    if (_running || !_controller.hasClients) return;
    if (_controller.position.maxScrollExtent <= 2) return;
    _running = true;
    Future<void>(() async {
      while (mounted && _running) {
        await _controller.animateTo(
          _controller.position.maxScrollExtent,
          duration: const Duration(seconds: 5),
          curve: Curves.linear,
        );
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) break;
        _controller.jumpTo(0);
        await Future.delayed(const Duration(milliseconds: 600));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _startIfNeeded());
    return SizedBox(
      height: 16,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Text(
          widget.text,
          maxLines: 1,
          style: widget.style,
        ),
      ),
    );
  }
}

class _OneLineMarqueeText extends StatefulWidget {
  const _OneLineMarqueeText({
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  @override
  State<_OneLineMarqueeText> createState() => _OneLineMarqueeTextState();
}

class _OneLineMarqueeTextState extends State<_OneLineMarqueeText> {
  final ScrollController _controller = ScrollController();
  bool _running = false;

  @override
  void dispose() {
    _running = false;
    _controller.dispose();
    super.dispose();
  }

  void _startIfNeeded() {
    if (_running || !_controller.hasClients) return;
    if (_controller.position.maxScrollExtent <= 4) return;
    _running = true;
    Future<void>(() async {
      while (mounted && _running) {
        await _controller.animateTo(
          _controller.position.maxScrollExtent,
          duration: const Duration(seconds: 4),
          curve: Curves.linear,
        );
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) break;
        _controller.jumpTo(0);
        await Future.delayed(const Duration(milliseconds: 500));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _startIfNeeded());
    return SizedBox(
      height: 16.h,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Text(
          widget.text,
          maxLines: 1,
          style: widget.style,
        ),
      ),
    );
  }
}
