import 'package:el_race/core/payslip/models/payslip_models.dart';
import 'package:el_race/core/payslip/providers/payslip_providers.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/ui/presentation/payslip/widgets/payslip_document_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Bottom-to-top payslip detail sheet (same pattern as attendance stat sheets).
Future<void> showPayslipDetailSheet(
  BuildContext context, {
  required String payslipId,
  String? title,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _PayslipDetailSheet(
      payslipId: payslipId,
      title: title ?? 'Payslip details',
    ),
  );
}

class _PayslipDetailSheet extends ConsumerWidget {
  const _PayslipDetailSheet({
    required this.payslipId,
    required this.title,
  });

  final String payslipId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(payslipRecordProvider(payslipId));

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F8FC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
          ),
          child: Column(
            children: [
              SizedBox(height: 10.h),
              Container(
                width: 42.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 8.w, 8.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: HrModuleTypography.sectionHeading().copyWith(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: HrModuleColors.border),
              Expanded(
                child: async.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Text(
                        'Could not load payslip\n$e',
                        textAlign: TextAlign.center,
                        style: HrModuleTypography.body(),
                      ),
                    ),
                  ),
                  data: (PayslipRecord? record) {
                    if (record == null) {
                      return Center(
                        child: Text(
                          'Payslip not found',
                          style: HrModuleTypography.body(),
                        ),
                      );
                    }
                    return ListView(
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 28.h),
                      children: [
                        PayslipDocumentView(record: record),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
