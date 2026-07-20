import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/hr_management/hr_effective_view.dart';
import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/recruitment/providers/requisition_providers.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/utils/pdf_watermark.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/core/widgets/hr_management/hr_kpi_counter_card.dart';
import 'package:el_race/core/widgets/recruitment/recruitment_funnel_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:printing/printing.dart';

/// D1 — Recruitment dashboard content (SRD §6); embedded in R1 or full-screen.
class D1RecruitmentDashboardPanel extends ConsumerStatefulWidget {
  const D1RecruitmentDashboardPanel({super.key});

  @override
  ConsumerState<D1RecruitmentDashboardPanel> createState() =>
      _D1RecruitmentDashboardPanelState();
}

class _D1RecruitmentDashboardPanelState
    extends ConsumerState<D1RecruitmentDashboardPanel> {
  int _period = 2; // quarter default
  static const _periodLabels = [
    'This week',
    'This month',
    'This quarter',
    'This year',
  ];

  late final PageController _pageController;
  int _vizPage = 0;

  static const _funnelAccent = Color(0xFF00897B);
  static const _deptAccent = Color(0xFF4A6B8A);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goVizPage(int index) {
    if (index < 0 || index > 1) return;
    setState(() => _vizPage = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _vizTabChip(int index, String label, IconData icon, Color accent) {
    final selected = _vizPage == index;
    return Padding(
      padding: EdgeInsets.only(right: 10.tw),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _goVizPage(index),
          borderRadius: BorderRadius.circular(22.tr),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: 14.tw, vertical: 10.th),
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: 0.16)
                  : HrModuleColors.surface,
              borderRadius: BorderRadius.circular(22.tr),
              border: Border.all(
                color: selected ? accent : HrModuleColors.border,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected ? HrModuleColors.cardShadow : const [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20.tsp,
                  color: selected ? accent : HrModuleColors.mutedText,
                ),
                SizedBox(width: 8.tw),
                Text(
                  label,
                  style: HrModuleTypography.caption().copyWith(
                    fontSize: 13.tsp,
                    fontWeight: FontWeight.w600,
                    color: selected ? accent : HrModuleColors.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _vizTabStrip() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 2.tw),
      child: Row(
        children: [
          _vizTabChip(
            0,
            'Pipeline funnel',
            Icons.account_tree_outlined,
            _funnelAccent,
          ),
          _vizTabChip(
            1,
            'By department',
            Icons.apartment_outlined,
            _deptAccent,
          ),
        ],
      ),
    );
  }

  Widget _departmentBars(List<Map<String, dynamic>> depts) {
    if (depts.isEmpty) {
      return Text(
        'No department breakdown for this period.',
        style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Open requisitions by department',
          style: HrModuleTypography.sectionHeading().copyWith(fontSize: 14.tsp),
        ),
        SizedBox(height: 10.th),
        ...depts.map(
          (d) {
            final share = (d['share'] as num?)?.toDouble() ?? 0;
            return Padding(
              padding: EdgeInsets.only(bottom: 10.th),
              child: Row(
                children: [
                  SizedBox(
                    width: 100.tw,
                    child: Text(
                      d['label']?.toString() ?? '',
                      style: TextStyle(fontSize: 12.tsp),
                    ),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: share.clamp(0.0, 1.0),
                      backgroundColor: HrModuleColors.border,
                      color: _deptAccent,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(hrEffectiveViewProvider);
    final dashAsync = ref.watch(recruitmentDashboardProvider);
    final reqs = ref.watch(requisitionsListProvider).asData?.value ?? [];

    final dash = dashAsync.asData?.value;
    final kpis = dash?['kpis'] as Map<String, dynamic>?;
    final openReqs = (kpis?['open'] as num?)?.toInt() ??
        reqs
            .where(
              (r) => r.uiStatus == 'OPEN',
            )
            .length;
    final pipeline = (kpis?['pipeline'] as num?)?.toInt() ?? 0;
    final offers = (kpis?['offers'] as num?)?.toInt() ?? 0;

    final funnelRaw = dash?['funnel'] as List? ?? [];
    final stages = funnelRaw.isNotEmpty
        ? funnelRaw.map((e) => (e as Map)['stage']?.toString() ?? '').toList()
        : ['APPLIED', 'SCREENING', 'INTERVIEW', 'OFFER', 'HIRED'];
    final funnelCounts = funnelRaw.isNotEmpty
        ? funnelRaw.map((e) => ((e as Map)['count'] as num?)?.toInt() ?? 0).toList()
        : [pipeline, 0, 0, offers, 0];

    final deptRaw = dash?['by_department'] as List? ?? [];
    final depts = deptRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

    final showManagerViz = view == HrEffectiveView.manager ||
        view == HrEffectiveView.hrManager;

    final hiredPeriod = funnelCounts.isNotEmpty
        ? funnelCounts.last
        : reqs.where((r) => r.uiStatus == 'CLOSED').length;
    final avgTthLabel =
        (dash?['avg_time_to_hire_days'] as num?)?.toStringAsFixed(1) ?? '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard',
          style: HrModuleTypography.cardTitle().copyWith(fontSize: 16.tsp),
        ),
        SizedBox(height: 8.th),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(
              _periodLabels.length,
              (i) => Padding(
                padding: EdgeInsets.only(right: 8.tw),
                child: ChoiceChip(
                  label: Text(_periodLabels[i]),
                  selected: _period == i,
                  onSelected: (_) => setState(() => _period = i),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 12.th),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: HrKpiCounterCard(
                  value: '$openReqs',
                  label: 'Open reqs',
                ),
              ),
              SizedBox(width: 8.tw),
              Expanded(
                child: HrKpiCounterCard(
                  value: '$pipeline',
                  label: 'In pipeline',
                ),
              ),
              SizedBox(width: 8.tw),
              Expanded(
                child: HrKpiCounterCard(
                  value: '$offers',
                  label: 'Offers pending',
                  valueColor: HrModuleColors.secondary,
                ),
              ),
            ],
          ),
        ),
        if (showManagerViz) ...[
          SizedBox(height: 16.th),
          _vizTabStrip(),
          SizedBox(height: 10.th),
          SizedBox(
            height: 300.th,
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _vizPage = i),
              children: [
                SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: RecruitmentFunnelChart(
                    stages: stages,
                    counts: funnelCounts,
                    showTitle: false,
                  ),
                ),
                SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: _departmentBars(depts),
                ),
              ],
            ),
          ),
        ] else ...[
          SizedBox(height: 20.th),
          RecruitmentFunnelChart(
            stages: stages,
            counts: funnelCounts,
          ),
        ],
        SizedBox(height: 16.th),
        Text(
          'Avg time per stage (days)',
          style: HrModuleTypography.sectionHeading().copyWith(fontSize: 14.tsp),
        ),
        Text('Applied → Screening: 2.1', style: TextStyle(fontSize: 12.tsp)),
        Text('Screening → Interview: 4.5', style: TextStyle(fontSize: 12.tsp)),
        Text('Interview → Offer: 6.0', style: TextStyle(fontSize: 12.tsp)),
        Text('Offer → Hired: 8.2', style: TextStyle(fontSize: 12.tsp)),
        SizedBox(height: 12.th),
        Text(
          'Top sources',
          style: HrModuleTypography.sectionHeading().copyWith(fontSize: 14.tsp),
        ),
        Text('LinkedIn — 42%', style: TextStyle(fontSize: 12.tsp)),
        Text('Referrals — 28%', style: TextStyle(fontSize: 12.tsp)),
        Text('Careers site — 20%', style: TextStyle(fontSize: 12.tsp)),
        SizedBox(height: 20.th),
        FilledButton.icon(
          onPressed: () async {
            final empId =
                SharedPref.getLoginData().result?.data?.emp_id ?? 'EMP-DEV';
            final bytes = await PdfWatermark.buildDashboardPdf(
              watermarkEmpId: empId,
              periodLabel: _periodLabels[_period],
              lines: [
                'Open requisitions: $openReqs',
                'Hired (period): $hiredPeriod',
                'Avg time-to-hire: $avgTthLabel days',
                'Funnel: ${funnelCounts.join(' → ')}',
              ],
            );
            if (context.mounted) {
              await Printing.layoutPdf(onLayout: (_) async => bytes);
            }
          },
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Export dashboard PDF'),
        ),
      ],
    );
  }
}
