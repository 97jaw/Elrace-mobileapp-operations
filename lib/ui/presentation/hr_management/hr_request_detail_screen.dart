import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/hr_management/models/hr_request_detail.dart';
import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/utils/pdf_watermark.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/core/widgets/hr_management/hr_detail_row.dart';
import 'package:el_race/core/widgets/hr_management/hr_employee_info_card.dart';
import 'package:el_race/core/widgets/hr_management/hr_status_badge.dart';
import 'package:el_race/core/widgets/hr_management/hr_status_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:printing/printing.dart';

/// E3 (employee) and M3 (manager) — SRD §3.3 / §4.3.
class HrRequestDetailScreen extends ConsumerWidget {
  const HrRequestDetailScreen({
    super.key,
    required this.requestId,
    required this.managerContext,
  });

  final String requestId;
  final bool managerContext;

  String _watermarkEmpId() {
    final data = SharedPref.getLoginData().result?.data;
    return (data?.emp_id?.isNotEmpty == true)
        ? data!.emp_id!
        : (data?.employee_id?.toString() ?? 'EMP');
  }

  Future<void> _exportPdf(BuildContext context, HrRequestDetail d) async {
    final empId = _watermarkEmpId();
    final timelineLines = d.timeline
        .map((t) => [
              t.title,
              if (t.subtitle != null && t.subtitle!.isNotEmpty) t.subtitle!,
            ].join(' — '))
        .toList();
    final bytes = await PdfWatermark.buildRequestDetailPdf(
      watermarkEmpId: empId,
      heading: d.summary.type,
      referenceLine: 'Ref: ${d.summary.referenceNumber}',
      statusLine: 'Status: ${d.summary.uiStatus} · ${d.submittedAtDisplay}',
      rows: d.detailRows,
      timelineLines: timelineLines,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  bool _showCancel(HrRequestDetail d) {
    final s = d.summary.uiStatus.toUpperCase();
    return s == 'PENDING' || s == 'DRAFT';
  }

  bool _showEdit(HrRequestDetail d) {
    return d.summary.uiStatus.toUpperCase() == 'DRAFT';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = HrDetailQuery(id: requestId, managerContext: managerContext);
    final async = ref.watch(hrRequestDetailProvider(q));

    return Scaffold(
      backgroundColor: HrModuleColors.surface,
      appBar: AppBar(
        backgroundColor: HrModuleColors.surface,
        foregroundColor: HrModuleColors.text,
        elevation: 0,
        title: Text(
          'Request detail',
          style: HrModuleTypography.sectionHeading().copyWith(fontSize: 18.tsp),
        ),
        actions: [
          async.maybeWhen(
            data: (d) => IconButton(
              tooltip: 'Export PDF',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () => _exportPdf(context, d),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: EdgeInsets.all(24.tw),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Could not load detail',
                  style: HrModuleTypography.sectionHeading().copyWith(fontSize: 16.tsp),
                ),
                SizedBox(height: 8.th),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: HrModuleTypography.caption(),
                ),
              ],
            ),
          ),
        ),
        data: (d) {
          final sub = d.subjectEmployee;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    HrModuleLayout.screenPaddingH.tw,
                    12.th,
                    HrModuleLayout.screenPaddingH.tw,
                    16.th,
                  ),
                  children: [
                    if (managerContext && sub != null) ...[
                      HrEmployeeInfoCard(
                        name: sub.name,
                        positionDepartmentLine: sub.positionDepartmentLine,
                        employeeId: sub.employeeId,
                        email: sub.email,
                        phone: sub.phone,
                      ),
                      SizedBox(height: 12.th),
                    ],
                    Container(
                      padding: EdgeInsets.all(16.tr),
                      decoration: BoxDecoration(
                        color: HrModuleColors.surface,
                        borderRadius:
                            BorderRadius.circular(HrModuleLayout.cardRadius.tr),
                        border: Border.all(color: HrModuleColors.border),
                        boxShadow: HrModuleColors.cardShadow,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            color: HrModuleColors.primary,
                            size: 28.tsp,
                          ),
                          SizedBox(width: 12.tw),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.summary.type,
                                  style: HrModuleTypography.cardTitle()
                                      .copyWith(fontSize: 17.tsp),
                                ),
                                SizedBox(height: 4.th),
                                Text(
                                  d.summary.referenceNumber,
                                  style: HrModuleTypography.caption()
                                      .copyWith(fontSize: 13.tsp),
                                ),
                                SizedBox(height: 6.th),
                                Text(
                                  d.submittedAtDisplay,
                                  style: HrModuleTypography.body()
                                      .copyWith(fontSize: 13.tsp),
                                ),
                              ],
                            ),
                          ),
                          HrStatusBadge(uiStatus: d.summary.uiStatus),
                        ],
                      ),
                    ),
                    if (d.availableLeaveBalance != null) ...[
                      SizedBox(height: 12.th),
                      HrDetailRow(
                        label: 'Available balance',
                        value: d.availableLeaveBalance!,
                      ),
                    ],
                    SizedBox(height: 20.th),
                    Text(
                      'REQUEST DETAILS',
                      style: HrModuleTypography.sectionHeading()
                          .copyWith(fontSize: 14.tsp),
                    ),
                    SizedBox(height: 8.th),
                    ...d.detailRows.map(
                      (r) => HrDetailRow(label: r.$1, value: r.$2),
                    ),
                    if (d.attachments.isNotEmpty) ...[
                      SizedBox(height: 20.th),
                      Text(
                        'ATTACHMENTS',
                        style: HrModuleTypography.sectionHeading()
                            .copyWith(fontSize: 14.tsp),
                      ),
                      SizedBox(height: 8.th),
                      ...d.attachments.map((a) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.attach_file, color: HrModuleColors.secondary),
                          title: Text(
                            a.name,
                            style: HrModuleTypography.body().copyWith(fontSize: 14.tsp),
                          ),
                          trailing: TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    a.url == null
                                        ? 'Preview not available (mock)'
                                        : 'Open ${a.name}',
                                  ),
                                ),
                              );
                            },
                            child: const Text('View'),
                          ),
                        );
                      }),
                    ],
                    SizedBox(height: 20.th),
                    Text(
                      'STATUS TIMELINE',
                      style: HrModuleTypography.sectionHeading()
                          .copyWith(fontSize: 14.tsp),
                    ),
                    SizedBox(height: 12.th),
                    HrStatusTimeline(steps: d.timeline),
                    SizedBox(height: 20.th),
                    Text(
                      'COMMENTS',
                      style: HrModuleTypography.sectionHeading()
                          .copyWith(fontSize: 14.tsp),
                    ),
                    SizedBox(height: 8.th),
                    if (d.comments.isEmpty)
                      Text(
                        '(No comments yet)',
                        style: HrModuleTypography.caption().copyWith(fontSize: 13.tsp),
                      )
                    else
                      ...d.comments.map((c) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12.th),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(12.tr),
                            decoration: BoxDecoration(
                              color: HrModuleColors.surface,
                              borderRadius: BorderRadius.circular(
                                HrModuleLayout.cardRadius.tr,
                              ),
                              border: Border.all(color: HrModuleColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.author,
                                  style: HrModuleTypography.body().copyWith(
                                    fontSize: 13.tsp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (c.timestamp != null) ...[
                                  SizedBox(height: 2.th),
                                  Text(
                                    c.timestamp!,
                                    style: HrModuleTypography.caption(),
                                  ),
                                ],
                                SizedBox(height: 6.th),
                                Text(
                                  c.text,
                                  style: HrModuleTypography.body().copyWith(fontSize: 13.tsp),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    SizedBox(height: managerContext ? 24.th : 100.th),
                  ],
                ),
              ),
              if (managerContext)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(16.tw, 12.th, 16.tw, 24.th),
                  decoration: BoxDecoration(
                    color: HrModuleColors.surface,
                    border: Border(top: BorderSide(color: HrModuleColors.border)),
                  ),
                  child: Text(
                    'Approval actions will be connected when backend workflows are ready.',
                    textAlign: TextAlign.center,
                    style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp),
                  ),
                )
              else
                _EmployeeActionsBar(
                  showCancel: _showCancel(d),
                  showEdit: _showEdit(d),
                  onCancel: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Cancel request'),
                        content: const Text(
                          'Cancel this request? (Mock — no server call yet.)',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('No'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Yes'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true && context.mounted) {
                      ref.invalidate(hrRequestListProvider);
                      ref.invalidate(hrTeamRequestListProvider);
                      Navigator.pop(context, true);
                    }
                  },
                  onDuplicate: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Duplicate: open New request picker from home (mock).'),
                      ),
                    );
                  },
                  onEdit: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Edit draft: use the original form flow (mock).'),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EmployeeActionsBar extends StatelessWidget {
  const _EmployeeActionsBar({
    required this.showCancel,
    required this.showEdit,
    required this.onCancel,
    required this.onDuplicate,
    required this.onEdit,
  });

  final bool showCancel;
  final bool showEdit;
  final VoidCallback onCancel;
  final VoidCallback onDuplicate;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.tw, 10.th, 16.tw, 24.th),
      decoration: BoxDecoration(
        color: HrModuleColors.surface,
        border: Border(top: BorderSide(color: HrModuleColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (showCancel)
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
              ),
            if (showCancel) SizedBox(width: 10.tw),
            Expanded(
              child: FilledButton(
                onPressed: onDuplicate,
                style: FilledButton.styleFrom(
                  backgroundColor: HrModuleColors.secondary,
                ),
                child: const Text('Duplicate'),
              ),
            ),
            if (showEdit) ...[
              SizedBox(width: 10.tw),
              Expanded(
                child: FilledButton(
                  onPressed: onEdit,
                  child: const Text('Edit'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
