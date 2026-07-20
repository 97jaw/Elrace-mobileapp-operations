import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/recruitment/models/recruitment_entities.dart';
import 'package:el_race/core/recruitment/models/requisition.dart';
import 'package:el_race/core/recruitment/providers/requisition_providers.dart';
import 'package:el_race/core/recruitment/recruitment_salary_visibility.dart';
import 'package:el_race/core/theme/hr_badge_kind.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/utils/pdf_watermark.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/core/widgets/hr_management/hr_detail_row.dart';
import 'package:el_race/core/widgets/hr_management/hr_module_glass_header.dart';
import 'package:el_race/core/widgets/hr_management/hr_status_badge.dart';
import 'package:el_race/core/widgets/recruitment/recruitment_candidate_tile.dart';
import 'package:el_race/core/widgets/recruitment/recruitment_gradient_scaffold.dart';
import 'package:el_race/core/widgets/recruitment/recruitment_pipeline_summary.dart';
import 'package:el_race/ui/presentation/recruitment/c2_candidate_detail_screen.dart';
import 'package:el_race/ui/presentation/recruitment/o1_offer_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

/// R2 — Requisition detail (SRD §3.2).
class R2RequisitionDetailScreen extends ConsumerStatefulWidget {
  const R2RequisitionDetailScreen({super.key, required this.requisitionId});

  final String requisitionId;

  @override
  ConsumerState<R2RequisitionDetailScreen> createState() =>
      _R2RequisitionDetailScreenState();
}

class _R2RequisitionDetailScreenState extends ConsumerState<R2RequisitionDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _stageChip;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String? _loginDisplayName() {
    final d = SharedPref.getLoginData().result?.data;
    return d?.name ?? d?.emp_name;
  }

  Future<void> _exportPdf(RequisitionDetailModel d) async {
    final empId = SharedPref.getLoginData().result?.data?.emp_id ?? 'EMP-DEV';
    final r = d.requisition;
    final rows = <(String, String)>[
      ('Department', r.department),
      ('Location', r.location),
      ('Vacancies', '${r.vacancies}'),
      ('Raised by', r.raisedBy),
    ];
    final view = ref.read(hrEffectiveViewProvider);
    if (recruitmentShowsRequisitionSalary(
      view: view,
      raisedBy: r.raisedBy,
      currentUserDisplayName: _loginDisplayName(),
    )) {
      if (d.salaryMinAed != null && d.salaryMaxAed != null) {
        rows.add(('Salary (AED)', '${d.salaryMinAed} – ${d.salaryMaxAed}'));
      }
    }
    final bytes = await PdfWatermark.buildRequestDetailPdf(
      watermarkEmpId: empId,
      heading: r.jobTitle,
      referenceLine: r.referenceNumber,
      statusLine: 'Status: ${r.uiStatus}',
      rows: rows,
      timelineLines: d.activities.map((e) => e.message).toList(),
    );
    if (!mounted) return;
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  List<RecruitmentCandidate> _filterCandidates(List<RecruitmentCandidate> all) {
    if (_stageChip == null) return all;
    return all.where((c) => c.stage == _stageChip).toList();
  }

  Future<void> _refreshDetail() async {
    // Roles refresh on re-login only (product decision 2026-07-20).
    ref.invalidate(requisitionDetailProvider(widget.requisitionId));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(requisitionDetailProvider(widget.requisitionId));

    return async.when(
      loading: () => RecruitmentGradientScaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HrModuleGlassHeader(
              title: 'Requisition',
              accentTint: HrModuleHeaderTints.recruitment,
            ),
            const Expanded(child: Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
      error: (e, _) => RecruitmentGradientScaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HrModuleGlassHeader(
              title: 'Requisition',
              accentTint: HrModuleHeaderTints.recruitment,
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24.tw),
                  child: Text('$e', textAlign: TextAlign.center),
                ),
              ),
            ),
          ],
        ),
      ),
      data: (d) {
        final r = d.requisition;
        final daysOpen = DateTime.now().difference(r.openedAt).inDays;
        final candidates = _filterCandidates(d.candidates);

        return RecruitmentGradientScaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HrModuleGlassHeader(
                title: 'Requisition',
                accentTint: HrModuleHeaderTints.recruitment,
                trailing: [
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined,
                        color: Colors.white),
                    tooltip: 'Export PDF',
                    onPressed: () => _exportPdf(d),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (v) {
                      Fluttertoast.showToast(
                        msg: '$v — available when workflow API is live',
                      );
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'hold', child: Text('Hold')),
                      PopupMenuItem(value: 'cancel', child: Text('Cancel')),
                    ],
                  ),
                ],
                bottom: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(text: 'Candidates'),
                    Tab(text: 'Offers'),
                    Tab(text: 'Activity'),
                  ],
                ),
                tabsHeight: 46,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    RefreshIndicator(
                      onRefresh: _refreshDetail,
                      child: _candidatesTab(d, candidates, r, daysOpen),
                    ),
                    RefreshIndicator(
                      onRefresh: _refreshDetail,
                      child: _offersTab(d, r, daysOpen),
                    ),
                    RefreshIndicator(
                      onRefresh: _refreshDetail,
                      child: _activityTab(d, r, daysOpen),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _headerCard(RequisitionDetailModel d, Requisition r, int daysOpen) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.tr),
      decoration: BoxDecoration(
        color: HrModuleColors.surface,
        borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.tr),
        border: Border.all(color: HrModuleColors.border),
        boxShadow: HrModuleColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.work_outline, color: HrModuleColors.primary, size: 28.tsp),
              SizedBox(width: 10.tw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.jobTitle,
                      style: HrModuleTypography.cardTitle().copyWith(fontSize: 17.tsp),
                    ),
                    SizedBox(height: 4.th),
                    Text(
                      '${r.department} · ${r.location}',
                      style: HrModuleTypography.body().copyWith(fontSize: 13.tsp),
                    ),
                  ],
                ),
              ),
              HrStatusBadge(
                uiStatus: r.uiStatus,
                kind: HrBadgeKind.requisition,
                labelOverride: r.uiStatusLabel,
              ),
            ],
          ),
          SizedBox(height: 8.th),
          Text(
            'Ref: ${r.referenceNumber}',
            style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp),
          ),
          SizedBox(height: 4.th),
          Text(
            'Raised by: ${r.raisedBy} · $daysOpen days ago',
            style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp),
          ),
        ],
      ),
    );
  }

  Widget _positionDetailsBlock(RequisitionDetailModel d, Requisition r) {
    final view = ref.watch(hrEffectiveViewProvider);
    final showSalary = recruitmentShowsRequisitionSalary(
      view: view,
      raisedBy: r.raisedBy,
      currentUserDisplayName: _loginDisplayName(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Position details',
          style: HrModuleTypography.sectionHeading().copyWith(fontSize: 14.tsp),
        ),
        SizedBox(height: 8.th),
        HrDetailRow(label: 'Department', value: r.department),
        HrDetailRow(label: 'Job title', value: r.jobTitle),
        HrDetailRow(label: 'Location', value: r.location),
        HrDetailRow(label: 'Vacancies', value: '${r.vacancies}'),
        if (showSalary &&
            d.salaryMinAed != null &&
            d.salaryMaxAed != null) ...[
          HrDetailRow(
            label: 'Salary (AED)',
            value: '${d.salaryMinAed} – ${d.salaryMaxAed}',
          ),
        ],
        if (d.requiredBy != null)
          HrDetailRow(
            label: 'Required by',
            value: DateFormat('dd MMM yyyy').format(d.requiredBy!),
          ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text(
              'Description',
              style: HrModuleTypography.body().copyWith(
                    fontSize: 14.tsp,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 12.th),
                  child: Text(
                    d.jobDescription,
                    style: HrModuleTypography.body().copyWith(fontSize: 13.tsp),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _candidatesTab(
    RequisitionDetailModel d,
    List<RecruitmentCandidate> candidates,
    Requisition r,
    int daysOpen,
  ) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        HrModuleLayout.screenPaddingH.tw,
        12.th,
        HrModuleLayout.screenPaddingH.tw,
        24.th,
      ),
      children: [
        _headerCard(d, r, daysOpen),
        SizedBox(height: 16.th),
        RecruitmentPipelineSummary(
          counts: d.pipeline,
          selectedStage: _stageChip,
          onStageTap: (s) {
            setState(() {
              _stageChip = _stageChip == s ? null : s;
            });
          },
        ),
        SizedBox(height: 16.th),
        _positionDetailsBlock(d, r),
        SizedBox(height: 20.th),
        Text(
          'Candidates',
          style: HrModuleTypography.sectionHeading().copyWith(fontSize: 14.tsp),
        ),
        SizedBox(height: 8.th),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: const Text('All'),
                selected: _stageChip == null,
                onSelected: (_) => setState(() => _stageChip = null),
              ),
              SizedBox(width: 8.tw),
              ...[
                'APPLIED',
                'SCREENING',
                'INTERVIEW',
                'OFFER',
                'HIRED',
                'REJECTED',
                'WITHDRAWN',
              ].map(
                (s) => Padding(
                  padding: EdgeInsets.only(right: 8.tw),
                  child: FilterChip(
                    label: Text(s),
                    selected: _stageChip == s,
                    onSelected: (_) => setState(() => _stageChip = s),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.th),
        ...candidates.map(
          (c) => Padding(
            padding: EdgeInsets.only(bottom: 10.th),
            child: RecruitmentCandidateTile(
              candidate: c,
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => C2CandidateDetailScreen(candidateId: c.id),
                  ),
                );
              },
            ),
          ),
        ),
        if (candidates.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24.th),
            child: Center(
              child: Text(
                'No candidates for this filter.',
                style: HrModuleTypography.body(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _offersTab(RequisitionDetailModel d, Requisition r, int daysOpen) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        HrModuleLayout.screenPaddingH.tw,
        12.th,
        HrModuleLayout.screenPaddingH.tw,
        24.th,
      ),
      children: [
        _headerCard(d, r, daysOpen),
        SizedBox(height: 20.th),
        if (d.offers.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: 40.th),
            child: Center(
              child: Text('No offers yet.', style: HrModuleTypography.body()),
            ),
          )
        else
          ...d.offers.map(
            (o) => Card(
              child: ListTile(
                title: Text(o.candidateName),
                subtitle: Text('${o.uiStatus} · ${o.sentAt != null ? DateFormat('dd MMM yyyy').format(o.sentAt!) : '—'}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => O1OfferDetailScreen(offerId: o.id),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _activityTab(RequisitionDetailModel d, Requisition r, int daysOpen) {
    final sorted = [...d.activities]..sort((a, b) => b.at.compareTo(a.at));
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        HrModuleLayout.screenPaddingH.tw,
        12.th,
        HrModuleLayout.screenPaddingH.tw,
        24.th,
      ),
      children: [
        _headerCard(d, r, daysOpen),
        SizedBox(height: 20.th),
        ...sorted.map(
          (e) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history),
            title: Text(e.message, style: TextStyle(fontSize: 13.tsp)),
            subtitle: Text(DateFormat('dd MMM yyyy, HH:mm').format(e.at)),
          ),
        ),
      ],
    );
  }
}
