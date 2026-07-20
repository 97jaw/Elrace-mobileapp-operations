import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/hr_management/hr_effective_view.dart';
import 'package:el_race/core/hr_management/models/hr_request_summary.dart';
import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/hr_management/hr_kpi_counter_card.dart';
import 'package:el_race/core/widgets/hr_management/hr_request_card.dart';
import 'package:el_race/core/widgets/hr_management/hr_search_bar.dart';
import 'package:el_race/ui/presentation/hr_management/hr_new_request_picker_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skeletonizer/skeletonizer.dart';

enum _HrSort { newest, oldest, byStatus, byType }

/// E1 list body — used on employee landing and manager "My own" tab (SRD §3.1 / §4.1).
class HrPersonalRequestListContent extends ConsumerStatefulWidget {
  const HrPersonalRequestListContent({
    super.key,
    required this.onOpenDetail,
    this.bottomInset = 100,
    this.searchHint = 'Search by reference no. or request type',
  });

  final void Function(HrRequestSummary summary) onOpenDetail;
  final double bottomInset;
  final String searchHint;

  @override
  ConsumerState<HrPersonalRequestListContent> createState() =>
      _HrPersonalRequestListContentState();
}

class _HrPersonalRequestListContentState
    extends ConsumerState<HrPersonalRequestListContent> {
  String? _filterId; // null = show all
  String _searchQuery = '';
  _HrSort _sort = _HrSort.newest;

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

  List<HrRequestSummary> _applyFilterSearchSort(List<HrRequestSummary> raw) {
    var list = List<HrRequestSummary>.from(raw);
    final active = _filterId;
    if (active != null && active != 'all') {
      list = list
          .where((e) => e.uiStatus.toUpperCase() == active.toUpperCase())
          .toList();
    }
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((e) {
        return e.referenceNumber.toLowerCase().contains(q) ||
            e.type.toLowerCase().contains(q);
      }).toList();
    }
    switch (_sort) {
      case _HrSort.newest:
        list.sort((a, b) => b.sequence.compareTo(a.sequence));
        break;
      case _HrSort.oldest:
        list.sort((a, b) => a.sequence.compareTo(b.sequence));
        break;
      case _HrSort.byStatus:
        list.sort((a, b) {
          final c = _statusRank(a.uiStatus).compareTo(_statusRank(b.uiStatus));
          if (c != 0) return c;
          return b.sequence.compareTo(a.sequence);
        });
        break;
      case _HrSort.byType:
        list.sort((a, b) {
          final c = a.type.toLowerCase().compareTo(b.type.toLowerCase());
          if (c != 0) return c;
          return b.sequence.compareTo(a.sequence);
        });
        break;
    }
    return list;
  }

  Map<String, int> _counts(List<HrRequestSummary> all) {
    int c(String status) =>
        all.where((e) => e.uiStatus.toUpperCase() == status).length;
    return {
      'PENDING': c('PENDING'),
      'APPROVED': c('APPROVED'),
      'REJECTED': c('REJECTED'),
      'DRAFT': c('DRAFT'),
    };
  }

  void _onKpiTap(String status) {
    setState(() {
      // Tap again to clear filter (show all).
      _filterId = _filterId == status ? null : status;
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncList = ref.watch(hrRequestListProvider);
    final effective = ref.watch(hrEffectiveViewProvider);

    return asyncList.when(
      loading: () => Padding(
        padding: EdgeInsets.all(HrModuleLayout.screenPaddingH.tw),
        child: Skeletonizer(
          enabled: true,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8.th),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: List.generate(
                      4,
                      (i) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i < 3 ? 8.tw : 0),
                          child: HrKpiCounterCard(
                            value: '…',
                            label: [
                              'Pending',
                              'Approved',
                              'Rejected',
                              'Draft',
                            ][i],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16.th),
                Container(
                  height: 48.th,
                  decoration: BoxDecoration(
                    color: HrModuleColors.surface,
                    borderRadius:
                        BorderRadius.circular(HrModuleLayout.cardRadius.tr),
                  ),
                ),
                SizedBox(height: 16.th),
                ...List.generate(
                  2,
                  (_) => Padding(
                    padding: EdgeInsets.only(bottom: 12.th),
                    child: HrRequestCard(
                      requestTypeTitle: 'Loading request type',
                      referenceNumber: 'HR/…/2026/0000',
                      uiStatus: 'PENDING',
                      secondaryLine: 'Placeholder line',
                      onTap: () {},
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: EdgeInsets.all(24.tw),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Something went wrong',
                style: HrModuleTypography.sectionHeading().copyWith(fontSize: 16.tsp),
              ),
              SizedBox(height: 8.th),
              Text(
                err.toString(),
                textAlign: TextAlign.center,
                style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp),
              ),
              SizedBox(height: 16.th),
              FilledButton(
                onPressed: () => ref.read(hrRequestListProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (all) {
        final counts = _counts(all);
        final display = _applyFilterSearchSort(all);
        final emptyFilter = display.isEmpty;

        return RefreshIndicator(
          onRefresh: () => ref.read(hrRequestListProvider.notifier).refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              HrModuleLayout.screenPaddingH.tw,
              8.th,
              HrModuleLayout.screenPaddingH.tw,
              widget.bottomInset.th + 4,
            ),
            children: [
              if (kDebugMode)
                Padding(
                  padding: EdgeInsets.only(bottom: 8.th),
                  child: Text(
                    'Dev role: ${effective.label} (mock data same for all)',
                    style: HrModuleTypography.caption().copyWith(fontSize: 11.tsp),
                  ),
                ),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: HrKpiCounterCard(
                        value: '${counts['PENDING']}',
                        label: 'Pending',
                        onTap: () => _onKpiTap('PENDING'),
                        valueColor: const Color(0xFFE89B4C),
                        selected: _filterId == 'PENDING',
                      ),
                    ),
                    SizedBox(width: 8.tw),
                    Expanded(
                      child: HrKpiCounterCard(
                        value: '${counts['APPROVED']}',
                        label: 'Approved',
                        onTap: () => _onKpiTap('APPROVED'),
                        valueColor: const Color(0xFF3D9B6E),
                        selected: _filterId == 'APPROVED',
                      ),
                    ),
                    SizedBox(width: 8.tw),
                    Expanded(
                      child: HrKpiCounterCard(
                        value: '${counts['REJECTED']}',
                        label: 'Rejected',
                        onTap: () => _onKpiTap('REJECTED'),
                        valueColor: const Color(0xFFC45C6A),
                        selected: _filterId == 'REJECTED',
                      ),
                    ),
                    SizedBox(width: 8.tw),
                    Expanded(
                      child: HrKpiCounterCard(
                        value: '${counts['DRAFT']}',
                        label: 'Draft',
                        onTap: () => _onKpiTap('DRAFT'),
                        valueColor: const Color(0xFF6B7280),
                        selected: _filterId == 'DRAFT',
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: HrModuleLayout.cardSpacingV.th),
              HrSearchBar(
                hintText: widget.searchHint,
                onDebouncedChanged: (q) => setState(() => _searchQuery = q),
              ),
              SizedBox(height: 16.th),
              Row(
                children: [
                  Text(
                    'Recent requests',
                    style: HrModuleTypography.sectionHeading().copyWith(
                          fontSize: 16.tsp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: HrModuleColors.text,
                        ),
                  ),
                  const Spacer(),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<_HrSort>(
                      value: _sort,
                      style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp),
                      items: const [
                        DropdownMenuItem(value: _HrSort.newest, child: Text('Newest')),
                        DropdownMenuItem(value: _HrSort.oldest, child: Text('Oldest')),
                        DropdownMenuItem(
                          value: _HrSort.byStatus,
                          child: Text('By status'),
                        ),
                        DropdownMenuItem(value: _HrSort.byType, child: Text('By type')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _sort = v);
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.th),
              if (emptyFilter)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.th),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 56.tsp, color: HrModuleColors.mutedText),
                      SizedBox(height: 12.th),
                      Text(
                        all.isEmpty
                            ? 'No requests yet'
                            : 'No requests match this filter',
                        style: HrModuleTypography.body().copyWith(fontSize: 15.tsp),
                      ),
                      SizedBox(height: 16.th),
                      FilledButton(
                        onPressed: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const HrNewRequestPickerScreen(),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: HrModuleColors.primary,
                        ),
                        child: const Text('Create your first request'),
                      ),
                    ],
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
                    padding: EdgeInsets.only(bottom: HrModuleLayout.cardSpacingV.th),
                    child: HrRequestCard(
                      requestTypeTitle: e.type,
                      referenceNumber: e.referenceNumber,
                      uiStatus: e.uiStatus,
                      secondaryLine: line.isEmpty ? null : line,
                      onTap: () => widget.onOpenDetail(e),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
