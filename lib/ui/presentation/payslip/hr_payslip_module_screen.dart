import 'package:el_race/core/payslip/providers/payslip_providers.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/hr_management/hr_module_glass_header.dart';
import 'package:el_race/core/widgets/hr_management/hr_search_bar.dart';
import 'package:el_race/core/widgets/payslip/payslip_gradient_scaffold.dart';
import 'package:el_race/ui/presentation/payslip/widgets/payslip_record_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// H1 — HR supervisor: all employees' payslips (paginated).
class HrPayslipModuleScreen extends ConsumerStatefulWidget {
  const HrPayslipModuleScreen({super.key});

  @override
  ConsumerState<HrPayslipModuleScreen> createState() =>
      _HrPayslipModuleScreenState();
}

class _HrPayslipModuleScreenState extends ConsumerState<HrPayslipModuleScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final keyword = query.trim();
    ref.read(payslipListProvider.notifier).setFilters(
          keyword: keyword.isEmpty ? null : keyword,
        );
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(payslipListProvider);

    return PayslipGradientScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HrModuleGlassHeader(
            title: 'Payslips',
            accentTint: HrModuleHeaderTints.payslip,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              HrModuleLayout.screenPaddingH.w,
              12.h,
              HrModuleLayout.screenPaddingH.w,
              8.h,
            ),
            child: HrSearchBar(
              controller: _searchCtrl,
              hintText: 'Search employee or reference',
              onDebouncedChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: HrModuleColors.payslipAccent,
              onRefresh: () => ref.read(payslipListProvider.notifier).refresh(),
              child: listAsync.when(
                data: (list) {
                  if (list.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        HrModuleLayout.screenPaddingH.w,
                        48.h,
                        HrModuleLayout.screenPaddingH.w,
                        32.h,
                      ),
                      children: [
                        Center(
                          child: Text(
                            'No payslips found.',
                            style: HrModuleTypography.body(),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      HrModuleLayout.screenPaddingH.w,
                      4.h,
                      HrModuleLayout.screenPaddingH.w,
                      32.h,
                    ),
                    itemCount: list.length + 1,
                    separatorBuilder: (_, __) => SizedBox(height: 10.h),
                    itemBuilder: (context, index) {
                      if (index == list.length) {
                        return TextButton(
                          onPressed: () =>
                              ref.read(payslipListProvider.notifier).loadMore(),
                          child: const Text('Load more'),
                        );
                      }
                      final s = list[index];
                      return PayslipRecordCard(
                        summary: s,
                      );
                    },
                  );
                },
                loading: () => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 48.h),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ],
                ),
                error: (e, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    HrModuleLayout.screenPaddingH.w,
                    48.h,
                    HrModuleLayout.screenPaddingH.w,
                    32.h,
                  ),
                  children: [
                    Text(
                      'Could not load payslips: $e',
                      style: HrModuleTypography.body(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
