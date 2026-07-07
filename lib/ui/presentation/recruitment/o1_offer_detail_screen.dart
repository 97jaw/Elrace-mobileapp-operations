import 'dart:typed_data';

import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/recruitment/models/recruitment_entities.dart';
import 'package:el_race/core/recruitment/providers/requisition_providers.dart';
import 'package:el_race/core/recruitment/recruitment_salary_visibility.dart';
import 'package:el_race/core/theme/hr_badge_kind.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/utils/pdf_watermark.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/core/widgets/hr_management/hr_detail_row.dart';
import 'package:el_race/core/widgets/hr_management/hr_status_badge.dart';
import 'package:el_race/core/widgets/recruitment/recruitment_gradient_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

/// O1 — Offer letter detail (SRD §5.1).
class O1OfferDetailScreen extends ConsumerWidget {
  const O1OfferDetailScreen({super.key, required this.offerId});

  final String offerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(hrEffectiveViewProvider);
    final async = ref.watch(recruitmentOfferDetailProvider(offerId));

    return async.when(
      loading: () => RecruitmentGradientScaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Offer'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => RecruitmentGradientScaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Offer'),
        ),
        body: Center(child: Text('$e')),
      ),
      data: (o) {
        final showComp = recruitmentShowsOfferCompensation(view: view);
        return RecruitmentGradientScaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            foregroundColor: HrModuleColors.text,
            title: Text(
              'Offer letter',
              style: HrModuleTypography.sectionHeading().copyWith(fontSize: 18.sp),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'Download PDF',
                onPressed: () async {
                  final bytes = await _buildPdfBytes(
                    o,
                    includeCompensation: showComp,
                  );
                  if (context.mounted) {
                    await Printing.layoutPdf(onLayout: (_) async => bytes);
                  }
                },
              ),
              PopupMenuButton<String>(
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    enabled: false,
                    value: 'r',
                    child: Text('Resend (Phase 2)'),
                  ),
                  PopupMenuItem(
                    enabled: false,
                    value: 'e',
                    child: Text('Mark expired (Phase 2)'),
                  ),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: EdgeInsets.all(HrModuleLayout.screenPaddingH.w),
            children: [
              Container(
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(
                  color: HrModuleColors.surface,
                  borderRadius:
                      BorderRadius.circular(HrModuleLayout.cardRadius.r),
                  border: Border.all(color: HrModuleColors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.mail_outline, color: HrModuleColors.primary, size: 32.sp),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.candidateName,
                            style: HrModuleTypography.cardTitle().copyWith(fontSize: 17.sp),
                          ),
                          Text(o.positionTitle, style: HrModuleTypography.body()),
                          Text(o.referenceNumber, style: HrModuleTypography.caption()),
                          SizedBox(height: 6.h),
                          HrStatusBadge(uiStatus: o.uiStatus, kind: HrBadgeKind.offer),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Offer details',
                style: HrModuleTypography.sectionHeading().copyWith(fontSize: 14.sp),
              ),
              HrDetailRow(label: 'Position', value: o.positionTitle),
              HrDetailRow(label: 'Department', value: o.department),
              HrDetailRow(label: 'Reporting manager', value: o.reportingManager),
              HrDetailRow(label: 'Location', value: o.location),
              if (o.joiningDate != null)
                HrDetailRow(
                  label: 'Joining date',
                  value: DateFormat('dd MMM yyyy').format(o.joiningDate!),
                ),
              HrDetailRow(label: 'Employment type', value: o.employmentType),
              if (o.sentAt != null)
                HrDetailRow(
                  label: 'Sent',
                  value: DateFormat('dd MMM yyyy').format(o.sentAt!),
                ),
              if (o.expiryAt != null)
                HrDetailRow(
                  label: 'Expiry',
                  value: DateFormat('dd MMM yyyy').format(o.expiryAt!),
                ),
              SizedBox(height: 12.h),
              Text(
                'Status',
                style: HrModuleTypography.sectionHeading().copyWith(fontSize: 14.sp),
              ),
              _timelineTile('Draft', o.uiStatus == 'DRAFT'),
              _timelineTile('Sent', o.uiStatus == 'SENT' || o.uiStatus == 'ACCEPTED' || o.uiStatus == 'DECLINED' || o.uiStatus == 'EXPIRED'),
              _timelineTile('Outcome', o.uiStatus == 'ACCEPTED' || o.uiStatus == 'DECLINED' || o.uiStatus == 'EXPIRED'),
              SizedBox(height: 12.h),
              if (showComp && o.salaryBreakdownLines != null) ...[
                Text(
                  'Compensation',
                  style: HrModuleTypography.sectionHeading().copyWith(fontSize: 14.sp),
                ),
                ...o.salaryBreakdownLines!.map(
                  (line) => Padding(
                    padding: EdgeInsets.only(bottom: 4.h),
                    child: Text(line, style: HrModuleTypography.body()),
                  ),
                ),
              ] else if (!showComp) ...[
                Text(
                  'Compensation details are restricted for your role (SRD §5.1.2).',
                  style: HrModuleTypography.caption(),
                ),
              ],
              SizedBox(height: 20.h),
              FilledButton.icon(
                onPressed: () async {
                  final bytes = await _buildPdfBytes(
                    o,
                    includeCompensation: showComp,
                  );
                  if (context.mounted) {
                    await Printing.layoutPdf(onLayout: (_) async => bytes);
                  }
                },
                icon: const Icon(Icons.download),
                label: const Text('Download PDF (watermarked)'),
              ),
              SizedBox(height: 12.h),
              Tooltip(
                message: 'Available in Phase 2',
                child: OutlinedButton(
                  onPressed: () {
                    Fluttertoast.showToast(msg: 'HR actions — Phase 2');
                  },
                  child: const Text('Resend / Mark expired'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Uint8List> _buildPdfBytes(
    RecruitmentOfferDetail o, {
    required bool includeCompensation,
  }) async {
    final empId = SharedPref.getLoginData().result?.data?.emp_id ?? 'EMP-DEV';
    final rows = <(String, String)>[
      ('Department', o.department),
      ('Location', o.location),
      ('Reporting manager', o.reportingManager),
      ('Employment type', o.employmentType),
      if (o.joiningDate != null)
        ('Joining', DateFormat('dd MMM yyyy').format(o.joiningDate!)),
    ];
    final timeline = <String>[
      if (o.sentAt != null) 'Sent: ${DateFormat('dd MMM yyyy').format(o.sentAt!)}',
      if (o.expiryAt != null) 'Expires: ${DateFormat('dd MMM yyyy').format(o.expiryAt!)}',
    ];
    if (includeCompensation && o.salaryBreakdownLines != null) {
      timeline.addAll(
        o.salaryBreakdownLines!.map((l) => 'Comp: $l'),
      );
    }
    return PdfWatermark.buildRequestDetailPdf(
      watermarkEmpId: empId,
      heading: 'Offer — ${o.candidateName}',
      referenceLine: o.referenceNumber,
      statusLine: 'Status: ${o.uiStatus}',
      rows: rows,
      timelineLines: timeline,
    );
  }

  Widget _timelineTile(String label, bool done) {
    return ListTile(
      dense: true,
      leading: Icon(
        done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: done ? HrModuleColors.success : HrModuleColors.mutedText,
        size: 20.sp,
      ),
      title: Text(label, style: TextStyle(fontSize: 13.sp)),
    );
  }
}
