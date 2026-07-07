import 'package:el_race/core/payslip/providers/payslip_providers.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/hr_management/hr_module_glass_header.dart';
import 'package:el_race/core/widgets/payslip/payslip_gradient_scaffold.dart';
import 'package:el_race/ui/presentation/payslip/payslip_detail_screen.dart';
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
          Expanded(
            child: RefreshIndicator(
        color: HrModuleColors.payslipAccent,
        onRefresh: () => ref.read(payslipListProvider.notifier).refresh(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            HrModuleLayout.screenPaddingH.w,
            16.h,
            HrModuleLayout.screenPaddingH.w,
            32.h,
          ),
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search employee or reference',
                filled: true,
                fillColor: HrModuleColors.surface,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    ref.read(payslipListProvider.notifier).setFilters();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: HrModuleColors.border),
                ),
              ),
              onSubmitted: (v) {
                ref
                    .read(payslipListProvider.notifier)
                    .setFilters(keyword: v.trim());
              },
            ),
            SizedBox(height: 8.h),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  ref
                      .read(payslipListProvider.notifier)
                      .setFilters(keyword: _searchCtrl.text.trim());
                },
                child: const Text('Search'),
              ),
            ),
            SizedBox(height: 12.h),
            listAsync.when(
              data: (list) {
                if (list.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.only(top: 48.h),
                    child: Center(
                      child: Text(
                        'No payslips found.',
                        style: HrModuleTypography.body(),
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final s in list) ...[
                      PayslipRecordCard(
                        summary: s,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  PayslipDetailScreen(payslipId: s.id),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 10.h),
                    ],
                    TextButton(
                      onPressed: () =>
                          ref.read(payslipListProvider.notifier).loadMore(),
                      child: const Text('Load more'),
                    ),
                  ],
                );
              },
              loading: () => Padding(
                padding: EdgeInsets.only(top: 48.h),
                child: const Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                'Could not load payslips: $e',
                style: HrModuleTypography.body(),
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
}
