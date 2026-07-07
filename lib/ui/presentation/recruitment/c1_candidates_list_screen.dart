import 'package:el_race/core/recruitment/models/recruitment_entities.dart';
import 'package:el_race/core/recruitment/providers/requisition_providers.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/hr_management/hr_search_bar.dart';
import 'package:el_race/core/widgets/recruitment/recruitment_candidate_tile.dart';
import 'package:el_race/core/widgets/recruitment/recruitment_gradient_scaffold.dart';
import 'package:el_race/ui/presentation/recruitment/c2_candidate_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// C1 — Candidates list (SRD §4.1).
class C1CandidatesListScreen extends ConsumerStatefulWidget {
  const C1CandidatesListScreen({
    super.key,
    this.requisitionIdFilter,
    this.initialStage,
  });

  final String? requisitionIdFilter;
  final String? initialStage;

  @override
  ConsumerState<C1CandidatesListScreen> createState() =>
      _C1CandidatesListScreenState();
}

class _C1CandidatesListScreenState extends ConsumerState<C1CandidatesListScreen> {
  String _search = '';
  String? _stage;
  _Sort _sort = _Sort.newest;

  @override
  void initState() {
    super.initState();
    _stage = widget.initialStage;
  }

  List<RecruitmentCandidate> _apply(
    List<RecruitmentCandidate> all,
  ) {
    var list = all;
    if (widget.requisitionIdFilter != null) {
      list = list
          .where((c) => c.requisitionId == widget.requisitionIdFilter)
          .toList();
    }
    if (_stage != null) {
      list = list.where((c) => c.stage == _stage).toList();
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where(
            (c) =>
                c.fullName.toLowerCase().contains(q) ||
                c.email.toLowerCase().contains(q),
          )
          .toList();
    }
    switch (_sort) {
      case _Sort.newest:
        list = [...list]..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
      case _Sort.oldest:
        list = [...list]..sort((a, b) => a.appliedAt.compareTo(b.appliedAt));
      case _Sort.scoreHigh:
        list = [...list]..sort((a, b) {
            final av = a.avgScore ?? -1;
            final bv = b.avgScore ?? -1;
            return bv.compareTo(av);
          });
      case _Sort.scoreLow:
        list = [...list]..sort((a, b) {
            final av = a.avgScore ?? 999;
            final bv = b.avgScore ?? 999;
            return av.compareTo(bv);
          });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(allRecruitmentCandidatesProvider);
    final global = widget.requisitionIdFilter == null;

    return RecruitmentGradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: HrModuleColors.text,
        title: Text(
          'Candidates',
          style: HrModuleTypography.sectionHeading().copyWith(fontSize: 18.sp),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (all) {
          final rows = _apply(all);
          const stages = [
            'APPLIED',
            'SCREENING',
            'INTERVIEW',
            'OFFER',
            'HIRED',
            'REJECTED',
            'WITHDRAWN',
          ];
          return ListView(
            padding: EdgeInsets.all(HrModuleLayout.screenPaddingH.w),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('All stages'),
                      selected: _stage == null,
                      onSelected: (_) => setState(() => _stage = null),
                    ),
                    ...stages.map(
                      (s) => Padding(
                        padding: EdgeInsets.only(left: 8.w),
                        child: ChoiceChip(
                          label: Text(s),
                          selected: _stage == s,
                          onSelected: (_) => setState(() => _stage = s),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              HrSearchBar(
                hintText: 'Name or email',
                onDebouncedChanged: (q) => setState(() => _search = q),
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Text('Sort: ', style: HrModuleTypography.caption()),
                  DropdownButton<_Sort>(
                    value: _sort,
                    items: const [
                      DropdownMenuItem(value: _Sort.newest, child: Text('Newest')),
                      DropdownMenuItem(value: _Sort.oldest, child: Text('Oldest')),
                      DropdownMenuItem(
                        value: _Sort.scoreHigh,
                        child: Text('Highest score'),
                      ),
                      DropdownMenuItem(
                        value: _Sort.scoreLow,
                        child: Text('Lowest score'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _sort = v);
                    },
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              if (rows.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 32.h),
                  child: Center(
                    child: Text(
                      'No candidates match.',
                      style: HrModuleTypography.body(),
                    ),
                  ),
                )
              else
                ...rows.map(
                  (c) => Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: RecruitmentCandidateTile(
                      candidate: c,
                      showRequisitionLink: global,
                      onTap: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                C2CandidateDetailScreen(candidateId: c.id),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

enum _Sort { newest, oldest, scoreHigh, scoreLow }
