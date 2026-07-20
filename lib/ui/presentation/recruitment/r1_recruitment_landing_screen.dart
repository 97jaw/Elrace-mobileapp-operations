import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/hr_management/hr_effective_view.dart';
import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/recruitment/models/requisition.dart';
import 'package:el_race/core/recruitment/providers/requisition_providers.dart';
import 'package:el_race/core/recruitment/recruitment_job_share.dart';
import 'package:el_race/core/theme/hr_badge_kind.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/hr_management/hr_kpi_counter_card.dart';
import 'package:el_race/core/widgets/hr_management/hr_pill_tab_controls.dart';
import 'package:el_race/core/widgets/hr_management/hr_request_card.dart';
import 'package:el_race/core/widgets/hr_management/hr_search_bar.dart';
import 'package:el_race/core/widgets/hr_management/hr_status_badge.dart';
import 'package:el_race/core/widgets/hr_management/hr_module_glass_header.dart';
import 'package:el_race/core/widgets/recruitment/recruitment_gradient_scaffold.dart';
import 'package:el_race/ui/presentation/recruitment/d1_recruitment_dashboard_panel.dart';
import 'package:el_race/ui/presentation/recruitment/r2_requisition_detail_screen.dart';
import 'package:el_race/ui/presentation/recruitment/recruitment_under_planning_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// TODO(release): Remove dev role toggle. Replace with dynamic role
// detection from login API booleans (is_hr_manager, is_management, is_pm).
// Reference: doc/Module_2_Recruitment_TASKS.md §3.

/// R1 — Recruitment landing (SRD §3.1, TASKS R1).
class R1RecruitmentLandingScreen extends ConsumerStatefulWidget {
  const R1RecruitmentLandingScreen({super.key});

  @override
  ConsumerState<R1RecruitmentLandingScreen> createState() =>
      _R1RecruitmentLandingScreenState();
}

enum _ListTab { active, closed, drafts }

enum _ActiveChip { all, open }

const _approvalStatuses = {
  'REQUESTER_APPROVAL',
  'HR_OFFICER_APPROVAL',
  'HR_MANAGER_APPROVAL',
};

class _R1RecruitmentLandingScreenState
    extends ConsumerState<R1RecruitmentLandingScreen> {
  bool _dashboardMode = false;
  _ListTab _listTab = _ListTab.active;
  _ActiveChip _activeChip = _ActiveChip.all;
  String _searchQuery = '';
  bool _managerSearchOpen = false;
  final _managerSearchController = TextEditingController();

  @override
  void dispose() {
    _managerSearchController.dispose();
    super.dispose();
  }

  ({int open, int pipeline, int offers}) _kpis(List<Requisition> all) {
    var open = 0;
    var pipeline = 0;
    var offers = 0;
    for (final r in all) {
      if (r.uiStatus == 'OPEN' || r.uiStatus == 'IN_RECRUITMENT') {
        open++;
        pipeline += r.candidatesInPipeline;
        offers += r.pendingOfferCount;
      }
    }
    return (open: open, pipeline: pipeline, offers: offers);
  }

  List<Requisition> _filtered(List<Requisition> all) {
    var list = List<Requisition>.from(all);
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where(
            (r) =>
                r.jobTitle.toLowerCase().contains(q) ||
                r.referenceNumber.toLowerCase().contains(q) ||
                r.department.toLowerCase().contains(q) ||
                r.location.toLowerCase().contains(q) ||
                r.raisedBy.toLowerCase().contains(q),
          )
          .toList();
    }
    switch (_listTab) {
      case _ListTab.active:
        // Show all non-closed requisitions (OPEN, IN_RECRUITMENT, HOLD, draft/approval…).
        if (_activeChip == _ActiveChip.open) {
          list = list
              .where(
                (r) =>
                    r.uiStatus == 'OPEN' ||
                    r.uiStatus == 'IN_RECRUITMENT' ||
                    r.uiStatus == 'HOLD',
              )
              .toList();
        } else {
          list = list
              .where(
                (r) =>
                    r.uiStatus != 'CLOSED' &&
                    r.uiStatus != 'CANCELLED' &&
                    r.uiStatus != 'FILLED',
              )
              .toList();
        }
      case _ListTab.closed:
        list = list
            .where(
              (r) =>
                  r.uiStatus == 'CLOSED' ||
                  r.uiStatus == 'CANCELLED' ||
                  r.uiStatus == 'FILLED',
            )
            .toList();
      case _ListTab.drafts:
        list = list
            .where(
              (r) =>
                  r.uiStatus == 'DRAFT' ||
                  _approvalStatuses.contains(r.uiStatus),
            )
            .toList();
    }
    list.sort((a, b) => b.openedAt.compareTo(a.openedAt));
    return list;
  }

  List<Requisition> _employeeOpenings(List<Requisition> all) {
    // Show all openings returned by the API (search filter only).
    var list = List<Requisition>.from(all);
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where(
            (r) =>
                r.jobTitle.toLowerCase().contains(q) ||
                r.referenceNumber.toLowerCase().contains(q) ||
                r.department.toLowerCase().contains(q) ||
                r.location.toLowerCase().contains(q),
          )
          .toList();
    }
    list.sort((a, b) => b.openedAt.compareTo(a.openedAt));
    return list;
  }

  Future<void> _refreshRecruitment() async {
    // Roles refresh on re-login only (product decision 2026-07-20).
    await ref.read(requisitionsListProvider.notifier).refresh();
  }

  void _sharePosition(Requisition r) {
    shareRecruitmentPosition(context, requisition: r);
  }

  List<Widget> _debugRoleActions() {
    if (!kDebugMode) return const [];
    return [
      IconButton(
        tooltip: 'Employee view',
        icon: Icon(Icons.person_outline, color: HrModuleColors.mutedText),
        onPressed: () => ref
            .read(hrDevViewOverrideProvider.notifier)
            .setOverride(HrEffectiveView.employee),
      ),
      IconButton(
        tooltip: 'Manager view',
        icon: Icon(Icons.groups_outlined, color: HrModuleColors.mutedText),
        onPressed: () => ref
            .read(hrDevViewOverrideProvider.notifier)
            .setOverride(HrEffectiveView.manager),
      ),
      IconButton(
        tooltip: 'HR Manager view',
        icon:
            Icon(Icons.business_center_outlined, color: HrModuleColors.mutedText),
        onPressed: () => ref
            .read(hrDevViewOverrideProvider.notifier)
            .setOverride(HrEffectiveView.hrManager),
      ),
      IconButton(
        tooltip: 'Clear role override',
        icon: Icon(Icons.restart_alt, color: HrModuleColors.mutedText),
        onPressed: () =>
            ref.read(hrDevViewOverrideProvider.notifier).setOverride(null),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(hrEffectiveViewProvider);
    if (view == HrEffectiveView.employee) {
      final async = ref.watch(requisitionsListProvider);
      return RecruitmentGradientScaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HrModuleGlassHeader(
              title: 'Recruitment',
              accentTint: HrModuleHeaderTints.recruitment,
            ),
            Expanded(
              child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: EdgeInsets.all(24.tw),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Could not load openings',
                    style: HrModuleTypography.sectionHeading()
                        .copyWith(fontSize: 16.tsp),
                  ),
                  SizedBox(height: 8.th),
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: HrModuleTypography.caption(),
                  ),
                  SizedBox(height: 16.th),
                  FilledButton(
                    onPressed: _refreshRecruitment,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (all) {
            final rows = _employeeOpenings(all);
            return RefreshIndicator(
              onRefresh: _refreshRecruitment,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  HrModuleLayout.screenPaddingH.tw,
                  12.th,
                  HrModuleLayout.screenPaddingH.tw,
                  32.th,
                ),
                children: [
                  HrSearchBar(
                    hintText: 'Search by job title, team, or location',
                    onDebouncedChanged: (q) => setState(() => _searchQuery = q),
                  ),
                  SizedBox(height: 16.th),
                  if (rows.isEmpty) ...[
                    SizedBox(height: 40.th),
                    Center(
                      child: Text(
                        _searchQuery.trim().isNotEmpty
                            ? 'No positions match your search.'
                            : 'No open positions right now.',
                        style: HrModuleTypography.body().copyWith(fontSize: 14.tsp),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ] else
                    ...rows.map(
                      (r) => Padding(
                        padding: EdgeInsets.only(bottom: 12.th),
                        child: _EmployeeOpeningCard(
                          requisition: r,
                          onShare: () => _sharePosition(r),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
              ),
            ),
          ],
        ),
      );
    }

    final async = ref.watch(requisitionsListProvider);

    return RecruitmentGradientScaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const RecruitmentUnderPlanningScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New'),
        backgroundColor: HrModuleColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HrModuleGlassHeader(
            title: 'Recruitment',
            accentTint: HrModuleHeaderTints.recruitment,
          ),
          Expanded(child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: EdgeInsets.all(24.tw),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Could not load requisitions',
                    style: HrModuleTypography.sectionHeading()
                        .copyWith(fontSize: 16.tsp),
                  ),
                  SizedBox(height: 8.th),
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: HrModuleTypography.caption(),
                  ),
                  SizedBox(height: 16.th),
                  FilledButton(
                    onPressed: _refreshRecruitment,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (all) {
            final k = _kpis(all);
            return RefreshIndicator(
              onRefresh: _refreshRecruitment,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  HrModuleLayout.screenPaddingH.tw,
                  12.th,
                  HrModuleLayout.screenPaddingH.tw,
                  100.th,
                ),
                children: [
                  HrPillSegmentControl(
                    segments: const ['Requisitions', 'Dashboard'],
                    selectedIndex: _dashboardMode ? 1 : 0,
                    trackColor: HrModuleColors.recruitmentTabTrack,
                    onChanged: (i) =>
                        setState(() => _dashboardMode = i == 1),
                  ),
                  SizedBox(height: 16.th),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: HrKpiCounterCard(
                            value: '${k.open}',
                            label: 'Open positions',
                          ),
                        ),
                        SizedBox(width: 8.tw),
                        Expanded(
                          child: HrKpiCounterCard(
                            value: '${k.pipeline}',
                            label: 'Candidates in pipeline',
                          ),
                        ),
                        SizedBox(width: 8.tw),
                        Expanded(
                          child: HrKpiCounterCard(
                            value: '${k.offers}',
                            label: 'Offers pending',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_dashboardMode) ...[
                    SizedBox(height: 16.th),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(14.tr),
                      decoration: BoxDecoration(
                        color: HrModuleColors.surface,
                        borderRadius:
                            BorderRadius.circular(HrModuleLayout.cardRadius.tr),
                        boxShadow: HrModuleColors.cardShadow,
                      ),
                      child: const D1RecruitmentDashboardPanel(),
                    ),
                  ] else ...[
                    SizedBox(height: 12.th),
                    _managerFiltersToolbar(),
                    if (_managerSearchOpen) ...[
                      SizedBox(height: 10.th),
                      HrSearchBar(
                        controller: _managerSearchController,
                        hintText: 'Title, ref, department, location…',
                        onDebouncedChanged: (q) =>
                            setState(() => _searchQuery = q),
                      ),
                    ],
                    SizedBox(height: 12.th),
                    ..._buildList(_filtered(all)),
                  ],
                ],
              ),
            );
          },
        )),
        ],
      ),
    );
  }

  /// One row: Active / Closed / Drafts + (when Active) status dropdown + search icon.
  Widget _managerFiltersToolbar() {
    Widget mainTabChip(String label, _ListTab tab) {
      final selected = _listTab == tab;
      return Padding(
        padding: EdgeInsets.only(right: 6.tw),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(() {
            _listTab = tab;
            if (tab != _ListTab.active) {
              _activeChip = _ActiveChip.all;
            }
          }),
          selectedColor: HrModuleColors.primary.withValues(alpha: 0.15),
          labelPadding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 0),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          labelStyle: HrModuleTypography.body().copyWith(
                fontSize: 12.tsp,
                color: selected ? HrModuleColors.primary : HrModuleColors.text,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                mainTabChip('Active', _ListTab.active),
                mainTabChip('Closed', _ListTab.closed),
                mainTabChip('Planning', _ListTab.drafts),
                if (_listTab == _ListTab.active) ...[
                  SizedBox(width: 6.tw),
                  _activeStatusDropdown(),
                ],
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: _managerSearchOpen ? 'Close search' : 'Search',
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: 40.tw, minHeight: 40.th),
          icon: Icon(
            _managerSearchOpen ? Icons.close : Icons.search,
            color: HrModuleColors.mutedText,
            size: 24.tsp,
          ),
          onPressed: () {
            setState(() {
              _managerSearchOpen = !_managerSearchOpen;
              if (!_managerSearchOpen) {
                _managerSearchController.clear();
                _searchQuery = '';
              }
            });
          },
        ),
      ],
    );
  }

  Widget _activeStatusDropdown() {
    return Container(
      constraints: BoxConstraints(minWidth: 132.tw, maxWidth: 168.tw),
      padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 2.th),
      decoration: BoxDecoration(
        color: HrModuleColors.surface,
        borderRadius: BorderRadius.circular(22.tr),
        border: Border.all(
          color: HrModuleColors.secondary.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: HrModuleColors.cardShadow,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_ActiveChip>(
          isDense: true,
          isExpanded: true,
          // ignore: deprecated_member_use
          value: _activeChip,
          dropdownColor: HrModuleColors.surface,
          borderRadius: BorderRadius.circular(12.tr),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: HrModuleColors.secondary,
            size: 22.tsp,
          ),
          style: HrModuleTypography.body().copyWith(
                fontSize: 12.tsp,
                fontWeight: FontWeight.w600,
                color: HrModuleColors.primary,
              ),
          items: [
            DropdownMenuItem(
              value: _ActiveChip.all,
              child: Text(
                'All open',
                style: HrModuleTypography.body().copyWith(fontSize: 12.tsp),
              ),
            ),
            DropdownMenuItem(
              value: _ActiveChip.open,
              child: Text(
                'Open',
                style: HrModuleTypography.body().copyWith(fontSize: 12.tsp),
              ),
            ),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _activeChip = v);
          },
        ),
      ),
    );
  }

  List<Widget> _buildList(List<Requisition> rows) {
    if (rows.isEmpty) {
      return [
        SizedBox(height: 32.th),
        Center(
          child: Text(
            'No requisitions match your filters.',
            style: HrModuleTypography.body().copyWith(fontSize: 14.tsp),
            textAlign: TextAlign.center,
          ),
        ),
      ];
    }
    return rows.map((r) {
      final opened =
          '${r.openedAt.day}/${r.openedAt.month}/${r.openedAt.year}';
      return Padding(
        padding: EdgeInsets.only(bottom: 12.th),
        child: HrRequestCard(
          requestTypeTitle: r.jobTitle,
          referenceNumber: r.referenceNumber,
          uiStatus: r.uiStatus,
          statusLabelOverride: r.uiStatusLabel,
          statusBadgeKind: HrBadgeKind.requisition,
          secondaryLine:
              '${r.department} · ${r.location} · ${r.vacancies} vac · '
              '${r.candidateCount} candidates · Raised by ${r.raisedBy} · $opened',
          onTap: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) =>
                    R2RequisitionDetailScreen(requisitionId: r.id),
              ),
            );
          },
        ),
      );
    }).toList();
  }
}

class _EmployeeOpeningCard extends StatelessWidget {
  const _EmployeeOpeningCard({
    required this.requisition,
    required this.onShare,
  });

  final Requisition requisition;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final r = requisition;
    final vacLabel = r.vacancies == 1 ? '1 opening' : '${r.vacancies} openings';
    return Container(
      decoration: BoxDecoration(
        color: HrModuleColors.surface,
        borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.tr),
        boxShadow: HrModuleColors.cardShadow,
      ),
      child: Padding(
          padding: EdgeInsets.fromLTRB(14.tw, 12.th, 14.tw, 12.th),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      r.jobTitle,
                      style: HrModuleTypography.cardTitle().copyWith(fontSize: 15.tsp),
                    ),
                  ),
                  SizedBox(width: 8.tw),
                  HrStatusBadge(
                    uiStatus: r.uiStatus,
                    kind: HrBadgeKind.requisition,
                    labelOverride: r.uiStatusLabel,
                  ),
                ],
              ),
              SizedBox(height: 4.th),
              Text(
                r.referenceNumber,
                style: HrModuleTypography.caption().copyWith(fontSize: 11.tsp),
              ),
              SizedBox(height: 2.th),
              Text(
                '${r.department} · ${r.location} · $vacLabel',
                style: HrModuleTypography.body().copyWith(fontSize: 12.tsp),
              ),
              SizedBox(height: 10.th),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share, size: 18),
                  style: FilledButton.styleFrom(
                    backgroundColor: HrModuleColors.success,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16.tw, vertical: 8.th),
                  ),
                  label: const Text('Share position'),
                ),
              ),
            ],
          ),
      ),
    );
  }
}
