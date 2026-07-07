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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(requisitionDetailProvider(widget.requisitionId));

    return async.when(
      loading: () => RecruitmentGradientScaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Requisition'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => RecruitmentGradientScaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Requisition'),
        ),
        body: Center(child: Text('$e')),
      ),
      data: (d) {
        final r = d.requisition;
        final daysOpen = DateTime.now().difference(r.openedAt).inDays;
        final candidates = _filterCandidates(d.candidates);

        return RecruitmentGradientScaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            foregroundColor: HrModuleColors.text,
            title: Text(
              'Requisition',
              style: HrModuleTypography.sectionHeading().copyWith(fontSize: 18.sp),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'Export PDF',
                onPressed: () => _exportPdf(d),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  Fluttertoast.showToast(msg: '$v — available when workflow API is live');
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'hold', child: Text('Hold')),
                  const PopupMenuItem(value: 'cancel', child: Text('Cancel')),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    HrModuleLayout.screenPaddingH.w,
                    12.h,
                    HrModuleLayout.screenPaddingH.w,
                    8.h,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _headerCard(d, r, daysOpen),
                      SizedBox(height: 16.h),
                      RecruitmentPipelineSummary(
                        counts: d.pipeline,
                        selectedStage: _stageChip,
                        onStageTap: (s) {
                          setState(() {
                            _stageChip = _stageChip == s ? null : s;
                          });
                        },
                      ),
                      SizedBox(height: 16.h),
                      _positionDetailsBlock(d, r),
                    ],
                  ),
                ),
              ),
              Material(
                color: HrModuleColors.surface,
                child: TabBar(
                  controller: _tabController,
                  labelColor: HrModuleColors.primary,
                  unselectedLabelColor: HrModuleColors.mutedText,
                  tabs: const [
                    Tab(text: 'Candidates'),
                    Tab(text: 'Offers'),
                    Tab(text: 'Activity'),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _candidatesTab(d, candidates),
                    _offersTab(d),
                    _activityTab(d),
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
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: HrModuleColors.surface,
        borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.r),
        border: Border.all(color: HrModuleColors.border),
        boxShadow: HrModuleColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.work_outline, color: HrModuleColors.primary, size: 28.sp),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.jobTitle,
                      style: HrModuleTypography.cardTitle().copyWith(fontSize: 17.sp),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${r.department} · ${r.location}',
                      style: HrModuleTypography.body().copyWith(fontSize: 13.sp),
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
          SizedBox(height: 8.h),
          Text(
            'Ref: ${r.referenceNumber}',
            style: HrModuleTypography.caption().copyWith(fontSize: 12.sp),
          ),
          SizedBox(height: 4.h),
          Text(
            'Raised by: ${r.raisedBy} · $daysOpen days ago',
            style: HrModuleTypography.caption().copyWith(fontSize: 12.sp),
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
          style: HrModuleTypography.sectionHeading().copyWith(fontSize: 14.sp),
        ),
        SizedBox(height: 8.h),
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
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: Text(
                    d.jobDescription,
                    style: HrModuleTypography.body().copyWith(fontSize: 13.sp),
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
  ) {
    return ListView(
      padding: EdgeInsets.all(HrModuleLayout.screenPaddingH.w),
      children: [
        Text(
          'Candidates',
          style: HrModuleTypography.sectionHeading().copyWith(fontSize: 14.sp),
        ),
        SizedBox(height: 8.h),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: const Text('All'),
                selected: _stageChip == null,
                onSelected: (_) => setState(() => _stageChip = null),
              ),
              SizedBox(width: 8.w),
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
                  padding: EdgeInsets.only(right: 8.w),
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
        SizedBox(height: 12.h),
        ...candidates.map(
          (c) => Padding(
            padding: EdgeInsets.only(bottom: 10.h),
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
            padding: EdgeInsets.symmetric(vertical: 24.h),
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

  Widget _offersTab(RequisitionDetailModel d) {
    return ListView(
      padding: EdgeInsets.all(HrModuleLayout.screenPaddingH.w),
      children: [
        if (d.offers.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: 40.h),
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

  Widget _activityTab(RequisitionDetailModel d) {
    final sorted = [...d.activities]..sort((a, b) => b.at.compareTo(a.at));
    return ListView.builder(
      padding: EdgeInsets.all(HrModuleLayout.screenPaddingH.w),
      itemCount: sorted.length,
      itemBuilder: (context, i) {
        final e = sorted[i];
        return ListTile(
          leading: const Icon(Icons.history),
          title: Text(e.message, style: TextStyle(fontSize: 13.sp)),
          subtitle: Text(DateFormat('dd MMM yyyy, HH:mm').format(e.at)),
        );
      },
    );
  }
}
