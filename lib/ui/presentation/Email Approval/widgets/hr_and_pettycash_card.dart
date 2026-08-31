import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/services/approval_count_service.dart';
import 'package:el_race/core/services/approval_viewed_service.dart';
import 'package:el_race/ui/presentation/Email%20Approval/Approval_confirmation.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/hr_details_screen.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/pettycash_details_screen.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/approval_display_helpers.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/approval_photo_cache.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/hr_approval_display.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/petty_cash_approval_display.dart';
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

  Widget _buildHrCard({
    required dynamic item,
    required String reqNo,
    required String requestType,
    required String leaveSubtype,
    required String employeeName,
    required String empCode,
    required String date,
  }) {
    return Container(
      height: 158.tw,
      width: 350.tw,
      margin: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 5.tw),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFDDE1E6),
            Color(0xFFBDC4CD),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.tr),
        border: Border.all(color: const Color(0xFF8F969F), width: 0.8),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 9.tw),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 34.tw,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 34.tw,
                      height: 34.tw,
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
                          size: 34.tw,
                          initials: employeeName,
                          lazyLoadCategory: ApprovalListCategory.hr,
                        ),
                      ),
                    ),
                  ),
                  if (date.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        date,
                        style: GoogleFonts.poppins(
                          fontSize: 9.5.tsp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF8C939C),
                        ),
                      ),
                    ),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 38.tw),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          reqNo.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 13.2.tsp,
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
                  Text(
                    requestType,
                    style: GoogleFonts.poppins(
                      fontSize: 12.4.tsp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0E0E10),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (leaveSubtype.trim().isNotEmpty) ...[
                    SizedBox(height: 4.tw),
                    Text(
                      leaveSubtype,
                      style: GoogleFonts.poppins(
                        fontSize: 11.tsp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0B387A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  SizedBox(height: 6.tw),
                  Text(
                    employeeName,
                    style: GoogleFonts.poppins(
                      fontSize: 12.tsp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4A5564),
                      letterSpacing: 0.1,
                    ),
                    maxLines: null,
                    overflow: TextOverflow.visible,
                  ),
                  SizedBox(height: 1.8.tw),
                  Text(
                    empCode,
                    style: GoogleFonts.poppins(
                      fontSize: 12.tsp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6B717B),
                    ),
                    maxLines: null,
                    overflow: TextOverflow.visible,
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
    required String holderName,
    required String date,
    required String amount,
  }) {
    final amountText = _formatAmountForCard(amount);
    final displayHolderName = holderName.isNotEmpty ? holderName : 'N/A';
    final displayDate = date.isNotEmpty
        ? date
        : PettyCashApprovalDisplay.formattedDate(item);

    return Container(
      height: 150.tw,
      width: 350.tw,
      margin: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 5.tw),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE1E4E8),
            Color(0xFFB9C0CB),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.tr),
        border: Border.all(color: const Color(0xFF8F969F), width: 0.8),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 10.tw),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 34.tw,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 38.tw,
                      height: 38.tw,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: ClipOval(
                        child: ApprovalListAvatar(
                          item: item,
                          kind: ApprovalAvatarKind.pettyCashHolder,
                          size: 38.tw,
                          initials: displayHolderName,
                          lazyLoadCategory: ApprovalListCategory.pettyCash,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 38.tw),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          refNo.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 16.tsp,
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
            SizedBox(height: 10.tw),
            Text(
              displayHolderName.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 16.tsp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F1114),
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    displayDate,
                    style: GoogleFonts.poppins(
                      fontSize: 12.tsp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF4A4F57),
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  amountText,
                  style: GoogleFonts.poppins(
                    fontSize: 26.tsp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0B387A),
                    letterSpacing: 0.2,
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
        kBottomNavigationBarHeight + context.systemBottomInset + 100.th;

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 5) +
          EdgeInsets.only(bottom: totalBottomPadding, top: 8.th),
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

        final holderName = isHr
            ? ''
            : PettyCashApprovalDisplay.holderName(item);

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

        final reqNo = isHr
            ? _getSafeString(
                item['name'] ??
                    item['request_no'] ??
                    item['ref_no'] ??
                    item['reference_no'] ??
                    item['req_no'],
                'N/A',
              )
            : PettyCashApprovalDisplay.sequence(item);

        final amount = isHr
            ? _getSafeString(
                item['amount_total'] ??
                    item['amount'] ??
                    item['total_amount'] ??
                    item['total'],
                '0',
              )
            : PettyCashApprovalDisplay.amountText(item);

        final requestType = HrApprovalDisplay.requestTypeName(item).isNotEmpty
            ? HrApprovalDisplay.requestTypeName(item)
            : _getSafeString(
                item['request_type'] ??
                    item['request_type_name'] ??
                    item['type'] ??
                    item['title'] ??
                    item['subject'],
                'HR Management',
              );

        final leaveSubtype = isHr
            ? HrApprovalDisplay.leaveSubtypeLabel(item)
            : '';

        final date = isHr
            ? HrApprovalDisplay.formattedDate(item)
            : PettyCashApprovalDisplay.formattedDate(item);

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
              ApprovalCountService.notifyListeners();
              onRefresh?.call();
            }
          },
          child: isHr
              ? _buildHrCard(
                  item: item,
                  reqNo: reqNo,
                  requestType: requestType,
                  leaveSubtype: leaveSubtype,
                  employeeName: requesterName,
                  empCode: empCode,
                  date: date,
                )
              : _buildPettyCashCard(
                  item: item,
                  refNo: reqNo,
                  holderName: holderName,
                  date: date,
                  amount: amount,
                ),
        );
      },
    );
  }
}
