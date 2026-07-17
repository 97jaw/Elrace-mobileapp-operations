import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/recruitment/models/recruitment_entities.dart';
import 'package:el_race/core/recruitment/providers/requisition_providers.dart';
import 'package:el_race/core/session/login_session_refresh_service.dart';
import 'package:el_race/core/theme/hr_badge_kind.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/hr_management/hr_detail_row.dart';
import 'package:el_race/core/widgets/hr_management/hr_employee_info_card.dart';
import 'package:el_race/core/widgets/hr_management/hr_module_glass_header.dart';
import 'package:el_race/core/widgets/hr_management/hr_status_badge.dart';
import 'package:el_race/core/widgets/recruitment/recruitment_gradient_scaffold.dart';
import 'package:el_race/core/widgets/recruitment/recruitment_star_rating.dart';
import 'package:el_race/ui/presentation/recruitment/a1_assessment_detail_screen.dart';
import 'package:el_race/ui/presentation/recruitment/a2_assessment_form_screen.dart';
import 'package:el_race/ui/presentation/recruitment/o1_offer_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

/// C2 — Candidate detail (SRD §4.2).
class C2CandidateDetailScreen extends ConsumerStatefulWidget {
  const C2CandidateDetailScreen({super.key, required this.candidateId});

  final String candidateId;

  @override
  ConsumerState<C2CandidateDetailScreen> createState() =>
      _C2CandidateDetailScreenState();
}

class _C2CandidateDetailScreenState extends ConsumerState<C2CandidateDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  Future<void> _launch(Uri u) async {
    if (await canLaunchUrl(u)) {
      await launchUrl(u);
    }
  }

  Future<void> _refresh() async {
    await LoginSessionRefreshService.refreshRoles(
      container: ProviderScope.containerOf(context),
    );
    ref.invalidate(recruitmentCandidateProvider(widget.candidateId));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(recruitmentCandidateProvider(widget.candidateId));

    return async.when(
      loading: () => RecruitmentGradientScaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HrModuleGlassHeader(
              title: 'Candidate',
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
              title: 'Candidate',
              accentTint: HrModuleHeaderTints.recruitment,
            ),
            Expanded(child: Center(child: Text('$e'))),
          ],
        ),
      ),
      data: (RecruitmentCandidate c) {
        final initials = HrEmployeeInfoCard.initialsFromName(c.fullName);
        return RecruitmentGradientScaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HrModuleGlassHeader(
                title: c.fullName,
                accentTint: HrModuleHeaderTints.recruitment,
                bottom: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(text: 'Assessments'),
                    Tab(text: 'Activity'),
                    Tab(text: 'Notes'),
                  ],
                ),
                tabsHeight: 46,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    RefreshIndicator(
                      onRefresh: _refresh,
                      child: _assessmentsTab(c, initials),
                    ),
                    RefreshIndicator(
                      onRefresh: _refresh,
                      child: _profileScroll(
                        c,
                        initials,
                        children: _activityTab(c),
                      ),
                    ),
                    RefreshIndicator(
                      onRefresh: _refresh,
                      child: _profileScroll(
                        c,
                        initials,
                        children: _notesTab(c),
                      ),
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

  Widget _profileScroll(
    RecruitmentCandidate c,
    String initials, {
    required List<Widget> children,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        HrModuleLayout.screenPaddingH.tw,
        12.th,
        HrModuleLayout.screenPaddingH.tw,
        24.th,
      ),
      children: [
        _headerCard(c, initials),
        SizedBox(height: 16.th),
        ..._profileRows(c),
        SizedBox(height: 16.th),
        ...children,
      ],
    );
  }

  List<Widget> _profileRows(RecruitmentCandidate c) {
    return [
      Text(
        'Profile',
        style: HrModuleTypography.sectionHeading().copyWith(fontSize: 14.tsp),
      ),
      HrDetailRow(label: 'Source', value: c.source ?? '—'),
      HrDetailRow(
        label: 'Applied',
        value: '${c.appliedAt.day}/${c.appliedAt.month}/${c.appliedAt.year}',
      ),
      HrDetailRow(
        label: 'Experience (yrs)',
        value: c.yearsExperience?.toString() ?? '—',
      ),
      HrDetailRow(label: 'Current company', value: c.currentCompany ?? '—'),
      HrDetailRow(label: 'Expected salary', value: c.expectedSalary ?? '—'),
      HrDetailRow(label: 'Notice', value: c.noticePeriod ?? '—'),
      if (c.offerId != null) ...[
        SizedBox(height: 12.th),
        Text(
          'Associated offer',
          style: HrModuleTypography.sectionHeading().copyWith(fontSize: 14.tsp),
        ),
        ListTile(
          tileColor: HrModuleColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.tr),
            side: BorderSide(color: HrModuleColors.border),
          ),
          title: const Text('Open offer letter'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => O1OfferDetailScreen(offerId: c.offerId!),
              ),
            );
          },
        ),
      ],
    ];
  }

  Widget _headerCard(RecruitmentCandidate c, String initials) {
    return Container(
      padding: EdgeInsets.all(14.tr),
      decoration: BoxDecoration(
        color: HrModuleColors.surface,
        borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.tr),
        border: Border.all(color: HrModuleColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28.tr,
            backgroundColor: HrModuleColors.primary.withValues(alpha: 0.12),
            child: Text(
              initials,
              style: HrModuleTypography.cardTitle().copyWith(
                    fontSize: 16.tsp,
                    color: HrModuleColors.primary,
                  ),
            ),
          ),
          SizedBox(width: 12.tw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.jobTitle,
                  style: HrModuleTypography.body().copyWith(
                        fontSize: 14.tsp,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(c.requisitionRef, style: HrModuleTypography.caption()),
                SizedBox(height: 6.th),
                HrStatusBadge(uiStatus: c.stage, kind: HrBadgeKind.candidate),
                SizedBox(height: 8.th),
                Wrap(
                  spacing: 8.tw,
                  children: [
                    TextButton.icon(
                      onPressed: () => _launch(Uri.parse('mailto:${c.email}')),
                      icon: const Icon(Icons.email_outlined, size: 18),
                      label: const Text('Email'),
                    ),
                    if (c.phone != null)
                      TextButton.icon(
                        onPressed: () =>
                            _launch(Uri.parse('tel:${c.phone!.replaceAll(' ', '')}')),
                        icon: const Icon(Icons.phone_outlined, size: 18),
                        label: const Text('Call'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _assessmentsTab(RecruitmentCandidate c, String initials) {
    final avg = c.avgScore;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        HrModuleLayout.screenPaddingH.tw,
        12.th,
        HrModuleLayout.screenPaddingH.tw,
        24.th,
      ),
      children: [
        _headerCard(c, initials),
        SizedBox(height: 16.th),
        ..._profileRows(c),
        SizedBox(height: 16.th),
        if (avg != null) ...[
          Text(
            'Average: ${avg.toStringAsFixed(1)} / 5',
            style: HrModuleTypography.cardTitle().copyWith(fontSize: 15.tsp),
          ),
          RecruitmentStarDisplay(value: avg),
          SizedBox(height: 12.th),
        ],
        ...c.assessments.map(
          (a) => Card(
            child: ListTile(
              title: Text(a.roundName),
              subtitle: Text(
                '${a.interviewer} · ${a.overallScore.toStringAsFixed(1)} · ${a.recommendation}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        A1AssessmentDetailScreen(assessmentId: a.id),
                  ),
                );
              },
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            await Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => A2AssessmentFormScreen(candidateId: c.id),
              ),
            );
            if (mounted) ref.invalidate(recruitmentCandidateProvider(c.id));
          },
          icon: const Icon(Icons.add),
          label: const Text('Add assessment'),
        ),
      ],
    );
  }

  List<Widget> _activityTab(RecruitmentCandidate c) {
    return [
      Text(
        'Activity',
        style: HrModuleTypography.sectionHeading().copyWith(fontSize: 14.tsp),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.inbox),
        title: const Text('Application received'),
        subtitle: Text('${c.appliedAt}'),
      ),
    ];
  }

  List<Widget> _notesTab(RecruitmentCandidate c) {
    return [
      Text(
        'Notes',
        style: HrModuleTypography.sectionHeading().copyWith(fontSize: 14.tsp),
      ),
      ...c.notesLines.map(
        (line) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notes_outlined),
          title: Text(line, style: TextStyle(fontSize: 13.tsp)),
        ),
      ),
    ];
  }
}
