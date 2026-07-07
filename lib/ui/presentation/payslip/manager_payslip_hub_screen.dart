import 'package:el_race/core/payslip/providers/payslip_providers.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_metallic_decorations.dart';
import 'package:el_race/core/theme/hr_service_screen_backdrop.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/ui/presentation/payslip/manager_payslip_pending_full_screen.dart';
import 'package:el_race/ui/presentation/payslip/payslip_detail_screen.dart';
import 'package:el_race/ui/presentation/payslip/widgets/payslip_record_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Stakeholder: pending queue for managers. Module 4 TASKS reserve team payslips for HR —
// product may restrict this screen to [HrEffectiveView.hrManager] only on release.

/// Manager landing — pending counter tile + last five pending (card list).
class ManagerPayslipHubScreen extends ConsumerWidget {
  const ManagerPayslipHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(payslipPendingCountProvider);
    final peekAsync = ref.watch(payslipPendingPeekProvider);

    return Scaffold(
      backgroundColor:
          HrServiceScreenBackdrop.scaffoldBackground(HrServiceScreenKind.payslip),
      appBar: AppBar(
        backgroundColor: HrModuleColors.surface,
        foregroundColor: HrModuleColors.text,
        elevation: 0,
        title: Text(
          'Payslips (team)',
          style: HrModuleTypography.pageTitle().copyWith(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
      body: HrServiceScreenBackdrop.wrap(
        kind: HrServiceScreenKind.payslip,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            HrModuleLayout.screenPaddingH.w,
            16.h,
            HrModuleLayout.screenPaddingH.w,
            32.h,
          ),
          children: [
          if (kDebugMode)
            Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Text(
                'Dev: use HR hub role toggle. Pending list is mock data.',
                style: HrModuleTypography.caption().copyWith(fontSize: 11.sp),
              ),
            ),
          countAsync.when(
            data: (count) => _PendingCounterTile(
              count: count,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ManagerPayslipPendingFullScreen(),
                  ),
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
          SizedBox(height: 24.h),
          Text(
            'Latest pending',
            style: HrModuleTypography.sectionHeading().copyWith(fontSize: 15.sp),
          ),
          SizedBox(height: 6.h),
          Text(
            'Last five in queue',
            style: HrModuleTypography.caption().copyWith(fontSize: 12.sp),
          ),
          SizedBox(height: 12.h),
          peekAsync.when(
            data: (list) {
              if (list.isEmpty) {
                return Text(
                  'No pending payslips.',
                  style: HrModuleTypography.body(),
                );
              }
              return Column(
                children: [
                  for (final s in list) ...[
                    PayslipRecordCard(
                      summary: s,
                      compact: true,
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
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
        ),
      ),
    );
  }
}

class _PendingCounterTile extends StatelessWidget {
  const _PendingCounterTile({
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HrModuleColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(18.w),
          decoration: HrMetallicDecorations.kpiTile(
            statusTint: const Color(0xFF64B5F6),
            borderRadius: 16,
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EEF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.pending_actions_rounded,
                  size: 32.sp,
                  color: HrModuleColors.primary,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pending payslips',
                      style: HrModuleTypography.sectionHeading()
                          .copyWith(fontSize: 16.sp, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Tap to open full list with pagination',
                      style: HrModuleTypography.caption().copyWith(fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
              Text(
                '$count',
                style: HrModuleTypography.sectionHeading().copyWith(
                      fontSize: 32.sp,
                      fontWeight: FontWeight.w800,
                      color: HrModuleColors.primary,
                    ),
              ),
              SizedBox(width: 4.w),
              Icon(Icons.chevron_right, color: HrModuleColors.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}
