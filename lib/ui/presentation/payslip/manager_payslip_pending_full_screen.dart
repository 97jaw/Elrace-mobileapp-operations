import 'package:el_race/core/payslip/models/payslip_models.dart';
import 'package:el_race/core/payslip/payslip_mock_data.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/theme/hr_service_screen_backdrop.dart';
import 'package:el_race/ui/presentation/payslip/widgets/payslip_record_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Full pending queue with simple page-style pagination (mock — replace with API paging).
class ManagerPayslipPendingFullScreen extends StatefulWidget {
  const ManagerPayslipPendingFullScreen({super.key});

  @override
  State<ManagerPayslipPendingFullScreen> createState() =>
      _ManagerPayslipPendingFullScreenState();
}

class _ManagerPayslipPendingFullScreenState
    extends State<ManagerPayslipPendingFullScreen> {
  static const _pageSize = 10;
  int _page = 0;
  final _items = <PayslipSummary>[];
  bool _loading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _appendNextPage();
  }

  void _appendNextPage() {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    final chunk = payslipPendingPage(page: _page, pageSize: _pageSize);
    setState(() {
      _items.addAll(chunk);
      _page++;
      _hasMore = payslipPendingHasMore(page: _page - 1, pageSize: _pageSize);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = payslipPendingCount();

    return Scaffold(
      backgroundColor:
          HrServiceScreenBackdrop.scaffoldBackground(HrServiceScreenKind.payslip),
      appBar: AppBar(
        backgroundColor: HrModuleColors.surface,
        foregroundColor: HrModuleColors.text,
        elevation: 0,
        title: Text(
          'Pending payslips',
          style: HrModuleTypography.pageTitle().copyWith(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
      body: HrServiceScreenBackdrop.wrap(
        kind: HrServiceScreenKind.payslip,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                HrModuleLayout.screenPaddingH.w,
                12.h,
                HrModuleLayout.screenPaddingH.w,
                8.h,
              ),
              child: Text(
                '$total total · showing ${_items.length}',
                style: HrModuleTypography.caption().copyWith(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  HrModuleLayout.screenPaddingH.w,
                  0,
                  HrModuleLayout.screenPaddingH.w,
                  24.h,
                ),
                itemCount: _items.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == _items.length) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      child: Center(
                        child: _loading
                            ? const CircularProgressIndicator()
                            : TextButton(
                                onPressed: _appendNextPage,
                                child: const Text('Load more'),
                              ),
                      ),
                    );
                  }
                  final s = _items[i];
                  return Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: PayslipRecordCard(
                      summary: s,
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
