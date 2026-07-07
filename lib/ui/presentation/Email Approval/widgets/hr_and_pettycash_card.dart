import 'package:el_race/core/services/approval_count_service.dart';
import 'package:el_race/core/services/approval_viewed_service.dart';
import 'package:el_race/ui/presentation/Email%20Approval/Approval_confirmation.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/hr_details_screen.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/pettycash_details_screen.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/approval_display_helpers.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/approval_photo_cache.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/approval_list_avatar.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class HrAndPettycashCard extends StatelessWidget {
  final List<dynamic> approvalItems;
  final VoidCallback? onRefresh;

  const HrAndPettycashCard({
    super.key,
    required this.approvalItems,
    this.onRefresh,
  });

  String _formatAmountForCard(String raw) {
    return ApprovalDisplayHelpers.formatAmountWithAed(raw);
  }

  String _titleCase(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
  }

  Widget _buildHrCard({
    required dynamic item,
    required String reqNo,
    required String requestType,
    required String employeeName,
    required String empCode,
    required String date,
  }) {
    return Container(
      height: 150.w,
      width: 350.w,
      margin: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFDDE1E6),
            Color(0xFFBDC4CD),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFF8F969F), width: 0.8),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 34.w,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 34.w,
                      height: 34.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.95),
                          width: 1.5,
                        ),
                      ),
                      child: ClipOval(
                        child: ApprovalListAvatar(
                          item: item as Map<dynamic, dynamic>,
                          kind: ApprovalAvatarKind.employee,
                          size: 34.w,
                          initials: employeeName,
                          lazyLoadCategory: ApprovalListCategory.hr,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 38.w),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          reqNo.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 13.2.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0B2D5E),
                            letterSpacing: 0.25,
                            height: 1.0,
                          ),
                          maxLines: null,
                          overflow: TextOverflow.visible,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'EMPLOYEE REQUEST',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12.4.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0E0E10),
                      ),
                      maxLines: null,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  SizedBox(height: 6.w),
                  Text(
                    employeeName,
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4A5564),
                      letterSpacing: 0.1,
                    ),
                    maxLines: null,
                    overflow: TextOverflow.visible,
                  ),
                  SizedBox(height: 1.8.w),
                  Text(
                    empCode,
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6B717B),
                    ),
                    maxLines: null,
                    overflow: TextOverflow.visible,
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          date,
                          style: GoogleFonts.poppins(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF8C939C),
                            letterSpacing: 0.1,
                          ),
                          maxLines: null,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                      if (requestType.trim().isNotEmpty)
                        Text(
                          _titleCase(requestType),
                          style: GoogleFonts.poppins(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0B387A),
                            letterSpacing: 0.15,
                            height: 1.0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPettyCashCard({
    required Map<dynamic, dynamic> item,
    required String refNo,
    required String requesterName,
    required String holderName,
    required String projectName,
    required String date,
    required String amount,
  }) {
    final amountText = _formatAmountForCard(amount);
    final displayHolderName =
        holderName.isNotEmpty ? holderName : requesterName;

    return Container(
      height: 150.w,
      width: 350.w,
      margin: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE1E4E8),
            Color(0xFFB9C0CB),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFF8F969F), width: 0.8),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 34.w,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 38.w,
                      height: 38.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: ClipOval(
                        child: ApprovalListAvatar(
                          item: item,
                          kind: ApprovalAvatarKind.pettyCashHolder,
                          size: 38.w,
                          initials: displayHolderName,
                          lazyLoadCategory: ApprovalListCategory.pettyCash,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 38.w),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          refNo.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0B2D5E),
                            letterSpacing: 0.25,
                            height: 1.0,
                          ),
                          maxLines: null,
                          overflow: TextOverflow.visible,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10.w),
            Text(
              displayHolderName.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F1114),
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4.w),
            Text(
              projectName,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF737A83),
                letterSpacing: 0.2,
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (requesterName.isNotEmpty) ...[
              SizedBox(height: 2.w),
              Text(
                'Requested by: $requesterName',
                style: GoogleFonts.poppins(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8C939C),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    date,
                    style: GoogleFonts.poppins(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8C939C),
                      letterSpacing: 0.1,
                    ),
                    maxLines: null,
                    overflow: TextOverflow.visible,
                  ),
                ),
                Text(
                  amountText,
                  style: GoogleFonts.poppins(
                    fontSize: 26.sp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0B387A),
                    letterSpacing: 0.2,
                    height: 1.0,
                  ),
                  maxLines: null,
                  overflow: TextOverflow.visible,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getSafeString(dynamic value, String fallback) {
    if (value == null || value == false || value == true) return fallback;
    final strValue = value.toString().trim();
    if (strValue.isEmpty ||
        strValue.toLowerCase() == 'false' ||
        strValue.toLowerCase() == 'true' ||
        strValue.toLowerCase() == 'null') {
      return fallback;
    }
    return strValue;
  }

  @override
  Widget build(BuildContext context) {
    final displayItems = List<dynamic>.from(approvalItems);

    if (displayItems.isEmpty) {
      return const Center(
        child: Text('No items found'),
      );
    }

    final totalBottomPadding =
        kBottomNavigationBarHeight + context.systemBottomInset + 100.h;

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 5) +
          EdgeInsets.only(bottom: totalBottomPadding, top: 8.h),
      itemCount: displayItems.length,
      separatorBuilder: (context, index) => const SizedBox(height: 1),
      itemBuilder: (context, index) {
        final item = displayItems[index];
        final category = item['category'] ?? item['type'] ?? '';
        final id = item['id']?.toString() ?? '';
        final isHr = category.toString().toUpperCase() == 'HR';

        if (kDebugMode && isHr && index == 0) {
          debugPrint('🔍 HR Item Fields: ${item.keys.toList()}');
          debugPrint('📋 HR Item Data: $item');
        }

        final requesterName = ApprovalDisplayHelpers.pickString(
          item,
          const [
            'requester_name',
            'requester',
            'emp_name',
            'employee_name',
            'employee',
          ],
          fallback: 'N/A',
        );

        final holderName = ApprovalDisplayHelpers.pickString(
          item,
          const [
            'pettycash_holder',
            'holder_name',
            'holder',
            'petty_cash_holder',
            'cash_holder',
          ],
        );

        final projectName = ApprovalDisplayHelpers.pickString(
          item,
          const [
            'project_name',
            'project_title',
            'project',
          ],
          fallback: 'N/A',
        );

        final empCode = _getSafeString(
          item['emp_code'] ??
              item['employee_code'] ??
              item['requester_code'] ??
              item['emp_id']?.toString() ??
              item['employee_id']?.toString() ??
              item['requester_id']?.toString() ??
              item['requester_emp_id']?.toString() ??
              item['code'],
          '',
        );

        final reqNo = _getSafeString(
          item['name'] ??
              item['request_no'] ??
              item['ref_no'] ??
              item['reference_no'] ??
              item['req_no'],
          'N/A',
        );

        final amount = _getSafeString(
          item['amount_total'] ??
              item['amount'] ??
              item['total_amount'] ??
              item['total'],
          '0',
        );

        final requestType = _getSafeString(
          item['leave_request_subtype'] ??
              item['leave_request_type'] ??
              item['request_type'] ??
              item['holiday_status_name'] ??
              item['request_type_name'] ??
              item['holiday_status_id'] ??
              item['leave_type'] ??
              item['subject'] ??
              item['type'] ??
              item['title'],
          'HR Management',
        );

        final date = _getSafeString(
          item['date'] ??
              item['request_date'] ??
              item['created_date'] ??
              item['submission_date'],
          '',
        );

        return GestureDetector(
          onTap: () async {
            debugPrint(
              '👆 [MyApproval][HR/PettyCash] Tap -> category=$category, id=$id',
            );

            await ApprovalViewedService.markAsViewed(category, id);
            if (!context.mounted) return;

            final upperCategory = category.toString().toUpperCase();
            final result = upperCategory == 'HR'
                ? await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HrDetailsScreen(
                        requestId: id,
                        type: category,
                      ),
                    ),
                  )
                : upperCategory == 'PETTY CASH'
                    ? await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PettyCashDetailsScreen(
                            requestId: id,
                            type: category,
                          ),
                        ),
                      )
                    : await showDialog(
                        context: context,
                        builder: (dialogContext) {
                          return ApprovalConfirmationScreen(
                            requestId: id,
                            type: category,
                          );
                        },
                      );

            debugPrint(
              '↩️ [MyApproval][HR/PettyCash] Back -> category=$category, id=$id, result=$result',
            );

            if (result == true) {
              ApprovalCountService.invalidateCache();
              ApprovalCountService.onCountChanged?.call();
              onRefresh?.call();
            }
          },
          child: isHr
              ? _buildHrCard(
                  item: item,
                  reqNo: reqNo,
                  requestType: requestType,
                  employeeName: requesterName,
                  empCode: empCode,
                  date: date,
                )
              : _buildPettyCashCard(
                  item: item,
                  refNo: reqNo,
                  requesterName: requesterName,
                  holderName: holderName,
                  projectName: projectName,
                  date: date.isNotEmpty ? date : 'N/A',
                  amount: amount,
                ),
        );
      },
    );
  }
}
