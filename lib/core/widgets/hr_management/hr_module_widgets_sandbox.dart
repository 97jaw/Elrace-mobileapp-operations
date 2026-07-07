import 'package:el_race/core/theme/hr_badge_kind.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/hr_management/hr_detail_row.dart';
import 'package:el_race/core/widgets/hr_management/hr_employee_info_card.dart';
import 'package:el_race/core/widgets/hr_management/hr_filter_chip_row.dart';
import 'package:el_race/core/widgets/hr_management/hr_kpi_counter_card.dart';
import 'package:el_race/core/widgets/hr_management/hr_request_card.dart';
import 'package:el_race/core/widgets/hr_management/hr_search_bar.dart';
import 'package:el_race/core/widgets/hr_management/hr_status_badge.dart';
import 'package:el_race/core/utils/pdf_watermark.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:printing/printing.dart';

/// Dev-only gallery for F.2 widgets. Navigate via:
/// `Navigator.push(context, MaterialPageRoute(builder: (_) => const HrModuleWidgetsSandbox()))`
/// (app must be wrapped with `ScreenUtilInit`.)
class HrModuleWidgetsSandbox extends StatefulWidget {
  const HrModuleWidgetsSandbox({super.key});

  @override
  State<HrModuleWidgetsSandbox> createState() => _HrModuleWidgetsSandboxState();
}

class _HrModuleWidgetsSandboxState extends State<HrModuleWidgetsSandbox> {
  String _chipId = 'all';
  String _lastSearch = '';

  static const _chips = [
    HrFilterOption(id: 'all', label: 'All'),
    HrFilterOption(id: 'PENDING', label: 'Pending'),
    HrFilterOption(id: 'APPROVED', label: 'Approved'),
    HrFilterOption(id: 'REJECTED', label: 'Rejected'),
    HrFilterOption(id: 'DRAFT', label: 'Draft'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HrModuleColors.lightBg,
      appBar: AppBar(
        title: Text(
          'HR widgets (F.2)',
          style: HrModuleTypography.pageTitle().copyWith(fontSize: 18.sp),
        ),
        backgroundColor: HrModuleColors.surface,
        foregroundColor: HrModuleColors.text,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: HrModuleLayout.screenPaddingH.w,
          vertical: 12.h,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final empId =
                    SharedPref.getLoginData().result?.data?.emp_id ?? 'EMP-DEV';
                final bytes = await PdfWatermark.buildSamplePdf(empId: empId);
                await Printing.layoutPdf(onLayout: (_) async => bytes);
              },
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Preview PDF with watermark (F.7)'),
            ),
            SizedBox(height: 16.h),
            _section('Status badges (HR requests)'),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                HrStatusBadge(uiStatus: 'DRAFT'),
                HrStatusBadge(uiStatus: 'PENDING'),
                HrStatusBadge(uiStatus: 'APPROVED'),
                HrStatusBadge(uiStatus: 'REJECTED'),
              ],
            ),
            SizedBox(height: 12.h),
            _section('Recruitment badges (Module 2)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...[
                  'DRAFT',
                  'IN_RECRUITMENT',
                  'HOLD',
                  'FILLED',
                  'CANCELLED',
                ].map(
                  (s) => HrStatusBadge(
                    uiStatus: s,
                    kind: HrBadgeKind.requisition,
                  ),
                ),
                ...[
                  'APPLIED',
                  'SCREENING',
                  'INTERVIEW',
                  'OFFER',
                  'HIRED',
                  'REJECTED',
                  'WITHDRAWN',
                ].map(
                  (s) => HrStatusBadge(
                    uiStatus: s,
                    kind: HrBadgeKind.candidate,
                  ),
                ),
                ...[
                  'DRAFT',
                  'SENT',
                  'ACCEPTED',
                  'DECLINED',
                  'EXPIRED',
                ].map(
                  (s) => HrStatusBadge(
                    uiStatus: s,
                    kind: HrBadgeKind.offer,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            _section('KPI cards'),
            Row(
              children: [
                Expanded(
                  child: HrKpiCounterCard(
                    value: '4',
                    label: 'Pending',
                    onTap: () {},
                  ),
                ),
                SizedBox(width: 10.w),
                const Expanded(
                  child: HrKpiCounterCard(
                    value: '18',
                    label: 'Approved',
                    valueColor: HrModuleColors.success,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            _section('Filter chips (selected: $_chipId)'),
            HrFilterChipRow(
              options: _chips,
              selectedId: _chipId,
              onChanged: (id) => setState(() => _chipId = id),
            ),
            SizedBox(height: 20.h),
            _section('Search (debounced)'),
            HrSearchBar(
              hintText: 'Type to debounce…',
              onDebouncedChanged: (q) => setState(() => _lastSearch = q),
            ),
            Text(
              'Last query: "${_lastSearch.isEmpty ? '—' : _lastSearch}"',
              style: HrModuleTypography.caption().copyWith(fontSize: 11.sp),
            ),
            SizedBox(height: 20.h),
            _section('Detail rows'),
            const HrDetailRow(label: 'From', value: '2026-05-01'),
            const HrDetailRow(label: 'To', value: '2026-05-03'),
            const HrDetailRow(label: 'Empty', value: ''),
            SizedBox(height: 8.h),
            _section('Employee info card'),
            const HrEmployeeInfoCard(
              name: 'Ayesha Khan',
              positionDepartmentLine: 'Senior Analyst · Finance',
              employeeId: 'EMP-4471',
              email: 'ayesha.khan@example.com',
              phone: '+971 50 123 4567',
            ),
            SizedBox(height: 20.h),
            _section('Request card — employee'),
            HrRequestCard(
              requestTypeTitle: 'Annual Leave',
              referenceNumber: 'HR/LV/2026/0001',
              uiStatus: 'PENDING',
              secondaryLine: 'Submitted 10 May 2026',
              onTap: () {},
            ),
            SizedBox(height: 12.h),
            _section('Request card — team'),
            HrRequestCard(
              requestTypeTitle: 'Sick Leave',
              referenceNumber: 'HR/LV/2026/0002',
              uiStatus: 'APPROVED',
              secondaryLine: '1 day · 9 May 2026',
              showEmployeeHeader: true,
              employeeName: 'Omar Hassan',
              employeeRoleLine: 'Developer · IT',
              employeeId: 'EMP-2201',
              onTap: () {},
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(
        title,
        style: HrModuleTypography.sectionHeading().copyWith(fontSize: 16.sp),
      ),
    );
  }
}
