import 'package:el_race/core/recruitment/models/recruitment_entities.dart';
import 'package:el_race/core/recruitment/providers/requisition_providers.dart';
import 'package:el_race/core/theme/hr_badge_kind.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/hr_management/hr_detail_row.dart';
import 'package:el_race/core/widgets/hr_management/hr_employee_info_card.dart';
import 'package:el_race/core/widgets/hr_management/hr_status_badge.dart';
import 'package:el_race/core/widgets/recruitment/recruitment_gradient_scaffold.dart';
import 'package:el_race/core/widgets/recruitment/recruitment_star_rating.dart';
import 'package:el_race/ui/presentation/recruitment/a1_assessment_detail_screen.dart';
import 'package:el_race/ui/presentation/recruitment/a2_assessment_form_screen.dart';
import 'package:el_race/ui/presentation/recruitment/o1_offer_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(recruitmentCandidateProvider(widget.candidateId));

    return async.when(
      loading: () => RecruitmentGradientScaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Candidate'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => RecruitmentGradientScaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Candidate'),
        ),
        body: Center(child: Text('$e')),
      ),
      data: (RecruitmentCandidate c) {
        final initials = HrEmployeeInfoCard.initialsFromName(c.fullName);
        return RecruitmentGradientScaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            foregroundColor: HrModuleColors.text,
            title: Text(
              c.fullName,
              style: HrModuleTypography.sectionHeading().copyWith(fontSize: 18.sp),
            ),
            actions: [
              PopupMenuButton<String>(
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    enabled: false,
                    value: 'x',
                    child: Text('Move to next stage (Phase 2)'),
                  ),
                ],
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: HrModuleColors.primary,
              unselectedLabelColor: HrModuleColors.mutedText,
              tabs: const [
                Tab(text: 'Assessments'),
                Tab(text: 'Activity'),
                Tab(text: 'Notes'),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(HrModuleLayout.screenPaddingH.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _headerCard(c, initials),
                      SizedBox(height: 16.h),
                      Text(
                        'Profile',
                        style: HrModuleTypography.sectionHeading()
                            .copyWith(fontSize: 14.sp),
                      ),
                      HrDetailRow(label: 'Source', value: c.source ?? '—'),
                      HrDetailRow(
                        label: 'Applied',
                        value:
                            '${c.appliedAt.day}/${c.appliedAt.month}/${c.appliedAt.year}',
                      ),
                      HrDetailRow(
                        label: 'Experience (yrs)',
                        value: c.yearsExperience?.toString() ?? '—',
                      ),
                      HrDetailRow(
                        label: 'Current company',
                        value: c.currentCompany ?? '—',
                      ),
                      HrDetailRow(
                        label: 'Expected salary',
                        value: c.expectedSalary ?? '—',
                      ),
                      HrDetailRow(label: 'Notice', value: c.noticePeriod ?? '—'),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('CV / Resume', style: HrModuleTypography.body()),
                        trailing: TextButton(
                          onPressed: () {
                            Fluttertoast.showToast(msg: 'Mock — document viewer');
                          },
                          child: const Text('View'),
                        ),
                      ),
                      if (c.offerId != null) ...[
                        SizedBox(height: 12.h),
                        Text(
                          'Associated offer',
                          style: HrModuleTypography.sectionHeading()
                              .copyWith(fontSize: 14.sp),
                        ),
                        ListTile(
                          tileColor: HrModuleColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              HrModuleLayout.cardRadius.r,
                            ),
                            side: BorderSide(color: HrModuleColors.border),
                          ),
                          title: const Text('Open offer letter'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    O1OfferDetailScreen(offerId: c.offerId!),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _assessmentsTab(c),
                    _activityTab(c),
                    _notesTab(c),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _headerCard(RecruitmentCandidate c, String initials) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: HrModuleColors.surface,
        borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.r),
        border: Border.all(color: HrModuleColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28.r,
            backgroundColor: HrModuleColors.primary.withValues(alpha: 0.12),
            child: Text(
              initials,
              style: HrModuleTypography.cardTitle().copyWith(
                    fontSize: 16.sp,
                    color: HrModuleColors.primary,
                  ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.jobTitle,
                  style: HrModuleTypography.body().copyWith(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(c.requisitionRef, style: HrModuleTypography.caption()),
                SizedBox(height: 6.h),
                HrStatusBadge(uiStatus: c.stage, kind: HrBadgeKind.candidate),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 8.w,
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

  Widget _assessmentsTab(RecruitmentCandidate c) {
    final avg = c.avgScore;
    return ListView(
      padding: EdgeInsets.all(HrModuleLayout.screenPaddingH.w),
      children: [
        if (avg != null) ...[
          Text(
            'Average: ${avg.toStringAsFixed(1)} / 5',
            style: HrModuleTypography.cardTitle().copyWith(fontSize: 15.sp),
          ),
          RecruitmentStarDisplay(value: avg),
          SizedBox(height: 12.h),
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

  Widget _activityTab(RecruitmentCandidate c) {
    return ListView(
      padding: EdgeInsets.all(HrModuleLayout.screenPaddingH.w),
      children: [
        ListTile(
          leading: const Icon(Icons.inbox),
          title: const Text('Application received'),
          subtitle: Text('${c.appliedAt}'),
        ),
      ],
    );
  }

  Widget _notesTab(RecruitmentCandidate c) {
    return ListView(
      padding: EdgeInsets.all(HrModuleLayout.screenPaddingH.w),
      children: c.notesLines
          .map(
            (line) => ListTile(
              leading: const Icon(Icons.notes_outlined),
              title: Text(line, style: TextStyle(fontSize: 13.sp)),
            ),
          )
          .toList(),
    );
  }
}
