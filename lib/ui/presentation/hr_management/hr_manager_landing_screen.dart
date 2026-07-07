import 'dart:math';

import 'package:el_race/core/hr_management/hr_effective_view.dart';
import 'package:el_race/core/hr_management/models/hr_request_summary.dart';
import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/hr_management/hr_filter_chip_row.dart';
import 'package:el_race/core/widgets/hr_management/hr_kpi_counter_card.dart';
import 'package:el_race/core/widgets/hr_management/hr_request_card.dart';
import 'package:el_race/core/widgets/hr_management/hr_pill_tab_controls.dart';
import 'package:el_race/core/widgets/hr_management/hr_module_glass_header.dart';
import 'package:el_race/core/widgets/hr_management/hr_requests_gradient_scaffold.dart';
import 'package:el_race/core/widgets/hr_management/hr_search_filter_header.dart';
import 'package:el_race/core/widgets/hr_management/hr_themed_pickers.dart';
import 'package:el_race/ui/presentation/hr_management/hr_manager_dashboard_screen.dart';
import 'package:el_race/ui/presentation/hr_management/hr_manager_search_older_screen.dart';
import 'package:el_race/ui/presentation/hr_management/hr_new_request_picker_screen.dart';
import 'package:el_race/ui/presentation/hr_management/hr_personal_request_list_content.dart';
import 'package:el_race/core/hr_management/hr_request_navigation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skeletonizer/skeletonizer.dart';

enum _TeamSort { newest, oldest, byStatus, byType }

/// M1 — Manager / HR manager landing (SRD §4.1).
class HrManagerLandingScreen extends ConsumerStatefulWidget {
  const HrManagerLandingScreen({super.key});

  @override
  ConsumerState<HrManagerLandingScreen> createState() => _HrManagerLandingScreenState();
}

class _HrManagerLandingScreenState extends ConsumerState<HrManagerLandingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _viewSegment = 0;

  String _teamFilterId = 'all';
  String _teamSearchQuery = '';
  _TeamSort _teamSort = _TeamSort.newest;
  String? _teamDeptFilter;
  String? _teamTypeFilter;
  bool _teamFiltersExpanded = false;
  List<HrRequestSummary> _queueRaw = [];
  List<HrRequestSummary> _queueItems = [];
  bool _queueLoading = false;
  String? _queueError;

  static const _chips = [
    HrFilterOption(id: 'all', label: 'All'),
    HrFilterOption(id: 'PENDING', label: 'Pending'),
    HrFilterOption(id: 'APPROVED', label: 'Approved'),
    HrFilterOption(id: 'REJECTED', label: 'Rejected'),
    HrFilterOption(id: 'DRAFT', label: 'Draft'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQueue());
  }

  Future<void> _loadQueue() async {
    if (!mounted) return;
    setState(() {
      _queueLoading = true;
      _queueError = null;
    });
    try {
      final client = ref.read(hrApiClientProvider);
      final env = await client.fetchTeamRequests(
        keyword: _teamSearchQuery,
        department: _teamDeptFilter,
        type: _teamTypeFilter,
        status: _teamFilterId,
        offset: 0,
        limit: 20,
      );
      if (!mounted) return;
      if (env.success && env.data != null) {
        _queueRaw = env.data!.map(HrRequestSummary.fromJson).toList();
        setState(() {
          _queueItems = _sortQueueList(_queueRaw);
          _queueLoading = false;
        });
      } else {
        setState(() {
          _queueRaw = [];
          _queueItems = [];
          _queueError = env.error ?? 'Could not load queue';
          _queueLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _queueRaw = [];
        _queueItems = [];
        _queueError = 'Could not load requests. Pull down to refresh.';
        _queueLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _statusRank(String s) {
    switch (s.toUpperCase()) {
      case 'PENDING':
        return 0;
      case 'APPROVED':
        return 1;
      case 'REJECTED':
        return 2;
      case 'DRAFT':
        return 3;
      default:
        return 4;
    }
  }

  List<HrRequestSummary> _sortQueueList(List<HrRequestSummary> raw) {
    final list = List<HrRequestSummary>.from(raw);
    if (_teamFilterId == 'all' && _teamSort == _TeamSort.newest) {
      list.shuffle(Random());
      return list;
    }
    switch (_teamSort) {
      case _TeamSort.newest:
        list.sort((a, b) => b.sequence.compareTo(a.sequence));
        break;
      case _TeamSort.oldest:
        list.sort((a, b) => a.sequence.compareTo(b.sequence));
        break;
      case _TeamSort.byStatus:
        list.sort((a, b) {
          final c = _statusRank(a.uiStatus).compareTo(_statusRank(b.uiStatus));
          if (c != 0) return c;
          return b.sequence.compareTo(a.sequence);
        });
        break;
      case _TeamSort.byType:
        list.sort((a, b) {
          final c = a.type.toLowerCase().compareTo(b.type.toLowerCase());
          if (c != 0) return c;
          return b.sequence.compareTo(a.sequence);
        });
        break;
    }
    return list;
  }

  String _teamSortLabel(_TeamSort sort) {
    return switch (sort) {
      _TeamSort.newest => 'Newest',
      _TeamSort.oldest => 'Oldest',
      _TeamSort.byStatus => 'By status',
      _TeamSort.byType => 'By type',
    };
  }

  Map<String, int> _teamKpis(List<HrRequestSummary> team) {
    int c(String status) =>
        team.where((e) => e.uiStatus.toUpperCase() == status).length;
    return {
      'pending': c('PENDING'),
      'approved': c('APPROVED'),
      'total': team.length,
    };
  }

  Widget _teamKpiRow({
    required String pending,
    required String approved,
    required String total,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: HrKpiCounterCard(
                value: pending,
                label: 'Pending',
                valueColor: const Color(0xFFE89B4C),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: HrKpiCounterCard(
                value: approved,
                label: 'Approved',
                valueColor: const Color(0xFF3D9B6E),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: HrKpiCounterCard(
                value: total,
                label: 'Total',
                valueColor: HrModuleColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Set<String> _departments(List<HrRequestSummary> team) {
    final s = team
        .map((e) => e.department)
        .whereType<String>()
        .where((d) => d.isNotEmpty)
        .toSet();
    for (final e in _queueRaw) {
      final d = e.department;
      if (d != null && d.isNotEmpty) s.add(d);
    }
    return s;
  }

  Set<String> _types(List<HrRequestSummary> team) {
    final s = team.map((e) => e.type).where((t) => t.isNotEmpty).toSet();
    for (final e in _queueRaw) {
      if (e.type.isNotEmpty) s.add(e.type);
    }
    return s;
  }

  Widget _departmentPicker(List<String> depts) {
    return HrThemedPickerField<String?>(
      label: 'Department',
      value: _teamDeptFilter,
      hint: 'All departments',
      displayText: (v) => v ?? 'All departments',
      options: [
        const HrPickerOption<String?>(
          value: null,
          label: 'All departments',
          icon: Icons.apartment_outlined,
          iconColor: HrModuleColors.primary,
        ),
        ...depts.map(
          (d) => HrPickerOption<String?>(
            value: d,
            label: d,
            icon: Icons.business_outlined,
            iconColor: HrModuleColors.secondary,
          ),
        ),
      ],
      onChanged: (v) {
        setState(() => _teamDeptFilter = v);
        _loadQueue();
      },
    );
  }

  Widget _typeFilterPicker(List<String> types) {
    return HrThemedPickerField<String?>(
      label: 'Request type',
      value: _teamTypeFilter != null && types.contains(_teamTypeFilter)
          ? _teamTypeFilter
          : null,
      hint: 'All types',
      displayText: (v) => v ?? 'All types',
      options: [
        const HrPickerOption<String?>(
          value: null,
          label: 'All types',
          icon: Icons.category_outlined,
          iconColor: HrModuleColors.primary,
        ),
        ...types.map(
          (t) => HrPickerOption<String?>(
            value: t,
            label: t,
            icon: Icons.description_outlined,
            iconColor: HrModuleColors.secondary,
          ),
        ),
      ],
      onChanged: (v) {
        setState(() => _teamTypeFilter = v);
        _loadQueue();
      },
    );
  }

  Widget _sortPicker() {
    return HrThemedPickerField<_TeamSort>(
      label: 'Sort',
      value: _teamSort,
      hint: 'Newest',
      displayText: (v) => _teamSortLabel(v ?? _TeamSort.newest),
      options: const [
        HrPickerOption(
          value: _TeamSort.newest,
          label: 'Newest',
          icon: Icons.schedule,
          iconColor: HrModuleColors.primary,
        ),
        HrPickerOption(
          value: _TeamSort.oldest,
          label: 'Oldest',
          icon: Icons.history,
          iconColor: HrModuleColors.secondary,
        ),
        HrPickerOption(
          value: _TeamSort.byStatus,
          label: 'By status',
          icon: Icons.flag_outlined,
          iconColor: HrModuleColors.warning,
        ),
        HrPickerOption(
          value: _TeamSort.byType,
          label: 'By type',
          icon: Icons.label_outline,
          iconColor: HrModuleColors.success,
        ),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _teamSort = v;
          _queueItems = _sortQueueList(_queueRaw);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final effective = ref.watch(hrEffectiveViewProvider);
    final teamAsync = ref.watch(hrTeamRequestListProvider);

    return HrRequestsGradientScaffold(
      floatingActionButton: _viewSegment == 0 && _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const HrNewRequestPickerScreen(),
                  ),
                );
              },
              backgroundColor: HrModuleColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'New request',
                style: HrModuleTypography.button().copyWith(
                      fontSize: 14.sp,
                      color: Colors.white,
                    ),
              ),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HrModuleGlassHeader(
            title: 'HR Requests',
            accentTint: HrModuleHeaderTints.requests,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
              child: HrPillSegmentControl(
                segments: const ['Requests', 'Dashboard'],
                selectedIndex: _viewSegment,
                onChanged: (i) => setState(() => _viewSegment = i),
              ),
            ),
            Expanded(
              child: _viewSegment == 1
                  ? HrManagerDashboardScreen(effectiveView: effective)
                : Column(
                    children: [
                      ref.watch(hrTeamKpisProvider).when(
                        loading: () => _teamKpiRow(
                          pending: '…',
                          approved: '…',
                          total: '…',
                        ),
                        error: (_, __) => teamAsync.when(
                          loading: () => _teamKpiRow(
                            pending: '…',
                            approved: '…',
                            total: '…',
                          ),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (team) {
                            final k = _teamKpis(team);
                            return _teamKpiRow(
                              pending: '${k['pending']}',
                              approved: '${k['approved']}',
                              total: '${k['total']}',
                            );
                          },
                        ),
                        data: (k) => _teamKpiRow(
                          pending: '${k['pending']}',
                          approved: '${k['approved']}',
                          total: '${k['total']}',
                        ),
                      ),
                      HrPillTabBar(
                        controller: _tabController,
                        tabs: const ['All requests', 'My requests'],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            teamAsync.when(
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (e, _) => Center(child: Text('$e')),
                              data: (team) => _buildTeamTab(context, team, effective),
                            ),
                            HrPersonalRequestListContent(
                              searchHint:
                                  'Search my requests — reference or type',
                              onOpenDetail: (e) {
                                openHrRequestDetail(
                                  context,
                                  e,
                                  managerContext: false,
                                );
                              },
                              bottomInset: 100,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
            ),
          ],
        ),
      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamTab(
    BuildContext context,
    List<HrRequestSummary> team,
    HrEffectiveView effective,
  ) {
    final typeKeys = team.map((e) => e.type).toSet();
    if (_teamTypeFilter != null && !typeKeys.contains(_teamTypeFilter)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _teamTypeFilter = null);
        }
      });
    }

    final display = _queueItems;
    final depts = _departments(team).toList()..sort();
    final types = _types(team).toList()..sort();

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(hrTeamRequestListProvider.notifier).refresh();
        await _loadQueue();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
        children: [
          if (kDebugMode)
            Text(
              'Dev role: ${effective.label}',
              style: HrModuleTypography.caption().copyWith(fontSize: 11.sp),
            ),
          HrSearchFilterHeader(
            hintText: 'Search team — reference, type, or employee',
            onDebouncedChanged: (q) {
              setState(() => _teamSearchQuery = q);
              _loadQueue();
            },
            filtersExpanded: _teamFiltersExpanded,
            onFilterToggle: () =>
                setState(() => _teamFiltersExpanded = !_teamFiltersExpanded),
            filterPanel: Padding(
              padding: EdgeInsets.only(top: 10.h),
              child: Column(
                children: [
                  if (effective == HrEffectiveView.hrManager) ...[
                    _departmentPicker(depts),
                    SizedBox(height: 10.h),
                  ],
                  _typeFilterPicker(types),
                  SizedBox(height: 10.h),
                ],
              ),
            ),
          ),
          SizedBox(height: 10.h),
          HrFilterChipRow(
            options: _chips,
            selectedId: _teamFilterId,
            onChanged: (id) {
              setState(() => _teamFilterId = id);
              _loadQueue();
            },
          ),
          SizedBox(height: 12.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Queue',
                  style: HrModuleTypography.sectionHeading().copyWith(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: HrModuleColors.text,
                      ),
                ),
              ),
              SizedBox(width: 130.w, child: _sortPicker()),
            ],
          ),
          SizedBox(height: 8.h),
          if (_queueLoading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24.h),
              child: const Center(child: CircularProgressIndicator()),
            )
          else if (_queueError != null)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Text(
                _queueError!,
                style: HrModuleTypography.caption().copyWith(
                  fontSize: 12.sp,
                  color: HrModuleColors.danger,
                ),
              ),
            )
          else if (display.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 32.h),
              child: Center(
                child: Text(
                  'No team requests match',
                  style: HrModuleTypography.body().copyWith(fontSize: 14.sp),
                ),
              ),
            )
          else
            ...display.map((e) {
              final line = [
                if (e.secondaryLine != null && e.secondaryLine!.isNotEmpty)
                  e.secondaryLine,
                if (e.relativeSubmittedLabel != null &&
                    e.relativeSubmittedLabel!.isNotEmpty)
                  e.relativeSubmittedLabel,
              ].join(' · ');
              return Padding(
                padding: EdgeInsets.only(bottom: HrModuleLayout.cardSpacingV.h),
                child: HrRequestCard(
                  showEmployeeHeader: true,
                  employeeName: e.employeeName,
                  employeeRoleLine: e.employeeRoleLine,
                  employeeId: e.employeeNumber,
                  requestTypeTitle: e.type,
                  referenceNumber: e.referenceNumber,
                  uiStatus: e.uiStatus,
                  secondaryLine: line.isEmpty ? null : line,
                  onTap: () {
                    openHrRequestDetail(
                      context,
                      e,
                      managerContext: true,
                    );
                  },
                ),
              );
            }),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.history, color: HrModuleColors.primary),
            title: Text(
              'Show more — search older requests',
              style: HrModuleTypography.body().copyWith(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: HrModuleColors.primary,
              ),
            ),
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const HrManagerSearchOlderScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
