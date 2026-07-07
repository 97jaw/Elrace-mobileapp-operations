import 'package:el_race/core/hr_management/models/hr_request_summary.dart';
import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/hr_management/hr_request_card.dart';
import 'package:el_race/core/hr_management/hr_request_navigation.dart';
import 'package:el_race/core/widgets/hr_management/hr_requests_gradient_scaffold.dart';
import 'package:el_race/core/widgets/hr_management/hr_search_bar.dart';
import 'package:el_race/core/widgets/hr_management/hr_themed_pickers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// M4 — Search older team requests (SRD §4.4) via `/api/hr/team_requests/search`.
class HrManagerSearchOlderScreen extends ConsumerStatefulWidget {
  const HrManagerSearchOlderScreen({super.key});

  @override
  ConsumerState<HrManagerSearchOlderScreen> createState() =>
      _HrManagerSearchOlderScreenState();
}

class _HrManagerSearchOlderScreenState extends ConsumerState<HrManagerSearchOlderScreen> {
  final _queryCtrl = TextEditingController();
  final _scroll = ScrollController();
  String? _department;
  String? _type;
  String _status = 'all';
  final List<HrRequestSummary> _items = [];
  int _offset = 0;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  static const _departments = [
    'R&D',
    'Delivery',
    'Finance',
    'Operations',
    'HR',
    'Marketing',
    'IT',
  ];

  static const _types = [
    'Annual Leave',
    'Sick Leave',
    'Short Leave',
    'Car Rent Request',
    'SIM Card Request',
    'Car Allowance',
    'Job Mission',
    'Temporary Permission',
  ];

  static const _statuses = ['all', 'PENDING', 'APPROVED', 'REJECTED', 'DRAFT'];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _queryCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loading) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _search({bool reset = true}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _offset = 0;
        _items.clear();
        _hasMore = true;
      }
    });
    try {
      final client = ref.read(hrApiClientProvider);
      final env = await client.searchTeamRequests(
        query: _queryCtrl.text,
        department: _department,
        requestType: _type,
        status: _status == 'all' ? null : _status,
        offset: _offset,
        limit: 20,
      );
      if (!mounted) return;
      if (env.success && env.data != null) {
        final next = env.data!.map(HrRequestSummary.fromJson).toList();
        setState(() {
          _items.addAll(next);
          _offset = _items.length;
          _hasMore = next.length >= 20;
          _loading = false;
        });
      } else {
        setState(() {
          _error = env.error ?? 'Search failed';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final client = ref.read(hrApiClientProvider);
      final env = await client.searchTeamRequests(
        query: _queryCtrl.text,
        department: _department,
        requestType: _type,
        status: _status == 'all' ? null : _status,
        offset: _offset,
        limit: 20,
      );
      if (!mounted) return;
      if (env.success && env.data != null) {
        final next = env.data!.map(HrRequestSummary.fromJson).toList();
        setState(() {
          _items.addAll(next);
          _offset = _items.length;
          _hasMore = next.length >= 20;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusIconColor(String status) {
    return switch (status) {
      'PENDING' => HrModuleColors.warning,
      'APPROVED' => HrModuleColors.success,
      'REJECTED' => HrModuleColors.danger,
      'DRAFT' => HrModuleColors.secondary,
      _ => HrModuleColors.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    return HrRequestsGradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: HrModuleColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Search team requests',
          style: HrModuleTypography.sectionHeading().copyWith(fontSize: 18.sp),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                HrModuleLayout.screenPaddingH.w,
                8.h,
                HrModuleLayout.screenPaddingH.w,
                8.h,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HrSearchBar(
                    controller: _queryCtrl,
                    hintText: 'Reference, type, or employee',
                    onDebouncedChanged: (_) {},
                  ),
                  SizedBox(height: 10.h),
                  HrThemedPickerField<String?>(
                    label: 'Department',
                    value: _department,
                    hint: 'Any',
                    displayText: (v) => v ?? 'Any',
                    options: [
                      const HrPickerOption<String?>(
                        value: null,
                        label: 'Any department',
                        icon: Icons.apartment_outlined,
                        iconColor: HrModuleColors.primary,
                      ),
                      ..._departments.map(
                        (d) => HrPickerOption<String?>(
                          value: d,
                          label: d,
                          icon: Icons.business_outlined,
                          iconColor: HrModuleColors.secondary,
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _department = v),
                  ),
                  SizedBox(height: 10.h),
                  HrThemedPickerField<String?>(
                    label: 'Request type',
                    value: _type,
                    hint: 'Any',
                    displayText: (v) => v ?? 'Any',
                    options: [
                      const HrPickerOption<String?>(
                        value: null,
                        label: 'Any type',
                        icon: Icons.category_outlined,
                        iconColor: HrModuleColors.primary,
                      ),
                      ..._types.map(
                        (t) => HrPickerOption<String?>(
                          value: t,
                          label: t,
                          icon: Icons.description_outlined,
                          iconColor: HrModuleColors.secondary,
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _type = v),
                  ),
                  SizedBox(height: 10.h),
                  HrThemedPickerField<String>(
                    label: 'Status',
                    value: _status,
                    hint: 'All',
                    displayText: (v) => v == null || v == 'all' ? 'All' : v,
                    options: _statuses
                        .map(
                          (s) => HrPickerOption<String>(
                            value: s,
                            label: s == 'all' ? 'All statuses' : s,
                            icon: Icons.flag_outlined,
                            iconColor: _statusIconColor(s),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _status = v ?? 'all'),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _loading ? null : () => _search(reset: true),
                          style: FilledButton.styleFrom(
                            backgroundColor: HrModuleColors.primary,
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                          ),
                          child: const Text('Apply filters'),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      OutlinedButton(
                        onPressed: _loading
                            ? null
                            : () {
                                setState(() {
                                  _queryCtrl.clear();
                                  _department = null;
                                  _type = null;
                                  _status = 'all';
                                });
                                _search(reset: true);
                              },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Text(
                  _error!,
                  style: TextStyle(color: HrModuleColors.danger, fontSize: 12.sp),
                ),
              ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_items.length} result(s)',
                  style: HrModuleTypography.caption().copyWith(
                    fontSize: 11.sp,
                    color: HrModuleColors.mutedText,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _items.isEmpty && !_loading
                  ? Center(
                      child: Text(
                        'Submit a search to see results',
                        style: HrModuleTypography.body().copyWith(
                          fontSize: 14.sp,
                          color: HrModuleColors.mutedText,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
                      itemCount: _items.length + (_loading ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= _items.length) {
                          return Padding(
                            padding: EdgeInsets.all(16.r),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        final e = _items[i];
                        final line = [
                          if (e.secondaryLine != null &&
                              e.secondaryLine!.isNotEmpty)
                            e.secondaryLine,
                          if (e.relativeSubmittedLabel != null &&
                              e.relativeSubmittedLabel!.isNotEmpty)
                            e.relativeSubmittedLabel,
                        ].join(' · ');
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
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
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
