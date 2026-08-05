import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/services/approval_viewed_service.dart';
import 'package:el_race/core/services/approval_count_service.dart';
import 'package:el_race/ui/presentation/Email%20Approval/Approval_confirmation.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/invoice_details_screen.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/rfq_details_screen.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/approval_display_helpers.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/approval_photo_cache.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/invoice_approval_display.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/rfq_approval_display.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/approval_list_avatar.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class InvoiceAndRfqCard extends StatelessWidget {
  final List<dynamic> approvalItems;
  final VoidCallback? onRefresh;
  final String categoryType;
  const InvoiceAndRfqCard(
      {super.key,
      required this.approvalItems,
      this.onRefresh,
      this.categoryType = ''});

  String _formatAmountForCard(String raw) {
    return ApprovalDisplayHelpers.formatAmountWithAed(raw);
  }

  String _canonicalApprovalType(
    dynamic raw, {
    String fallback = '',
  }) {
    final source = (raw ?? fallback).toString().trim();
    if (source.isEmpty) return '';
    final norm = source.toLowerCase().replaceAll('_', ' ');
    if (norm.contains('rfq') ||
        norm.contains('request for quotation') ||
        norm.contains('purchase.order') ||
        norm == 'purchase order') {
      return 'RFQ';
    }
    if (norm.contains('invoice') ||
        norm.contains('account.move') ||
        norm.contains('customer invoice')) {
      return 'INVOICE';
    }
    return source.toUpperCase();
  }

  Widget _buildCardAvatar({
    required Map<dynamic, dynamic> itemMap,
    required ApprovalAvatarKind kind,
    required double size,
    String? initials,
    ApprovalListCategory? lazyLoadCategory,
  }) {
    return ApprovalListAvatar(
      item: itemMap,
      kind: kind,
      size: size,
      initials: initials,
      lazyLoadCategory: lazyLoadCategory,
    );
  }

  Widget _buildRfqCard({
    required dynamic item,
    required String refNo,
    required String title,
    required String subtitle,
    required String date,
    required String amount,
  }) {
    final amountText = _formatAmountForCard(amount);
    final itemMap = item as Map<dynamic, dynamic>;

    return Container(
      constraints: BoxConstraints(minHeight: 150.tw),
      width: 350.tw,
      margin: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 5.tw),
      padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 10.tw),
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
                    child: _buildCardAvatar(
                      itemMap: itemMap,
                      kind: ApprovalAvatarKind.vendor,
                      size: 38.tw,
                      initials: subtitle.isNotEmpty ? subtitle : refNo,
                      lazyLoadCategory: ApprovalListCategory.rfq,
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
            title.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 14.tsp,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F1114),
              height: 1.1,
            ),
          ),
          SizedBox(height: 4.tw),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 12.tsp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF737A83),
              letterSpacing: 0.2,
              height: 1.0,
            ),
          ),
          SizedBox(height: 10.tw),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  date,
                  style: GoogleFonts.poppins(
                    fontSize: 10.tsp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8C939C),
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              SizedBox(width: 10.tw),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    amountText,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(
                      fontSize: 26.tsp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0B387A),
                      letterSpacing: 0.2,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard({
    required dynamic item,
    required String refNo,
    required String title,
    required String client,
    required String date,
    required String amount,
  }) {
    final amountText = _formatAmountForCard(amount);
    final itemMap = item as Map<dynamic, dynamic>;

    return Container(
      constraints: BoxConstraints(minHeight: 150.tw),
      width: 350.tw,
      margin: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 5.tw),
      padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 10.tw),
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
                    child: _buildCardAvatar(
                      itemMap: itemMap,
                      kind: ApprovalAvatarKind.vendor,
                      size: 38.tw,
                      initials: client.isNotEmpty ? client : refNo,
                      lazyLoadCategory: ApprovalListCategory.invoice,
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
            title.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 16.tsp,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F1114),
              height: 1.1,
            ),
          ),
          SizedBox(height: 4.tw),
          Text(
            client,
            style: GoogleFonts.poppins(
              fontSize: 13.tsp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF737A83),
              letterSpacing: 0.2,
              height: 1.0,
            ),
          ),
          SizedBox(height: 10.tw),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  date,
                  style: GoogleFonts.poppins(
                    fontSize: 10.tsp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8C939C),
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              SizedBox(width: 10.tw),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    amountText,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(
                      fontSize: 26.tsp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0B387A),
                      letterSpacing: 0.2,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (approvalItems.isEmpty) {
      return const Center(
        child: Text('No items found'),
      );
    }

    // Calculate safe bottom padding for devices with navigation bars
    final totalBottomPadding =
        kBottomNavigationBarHeight + context.systemBottomInset + 100.th;

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 5) +
          EdgeInsets.only(bottom: totalBottomPadding, top: 8.th),
      itemCount: approvalItems.length,
      separatorBuilder: (context, index) => const SizedBox(height: 1),
      itemBuilder: (context, index) {
        final item = approvalItems[index];
        final type = _canonicalApprovalType(
          item["type"],
          fallback: _canonicalApprovalType(categoryType),
        );
        String id = item["id"]?.toString() ?? "";
        final isRfq = type == 'RFQ';

        // Helper function to safely get string value
        String getSafeString(dynamic value, {String fallback = "N/A"}) {
          if (value == null || value == false || value == true) return fallback;
          String str = value.toString();
          if (str.isEmpty ||
              str.toLowerCase() == 'false' ||
              str.toLowerCase() == 'true' ||
              str.toLowerCase() == 'null') {
            return fallback;
          }
          return str;
        }

        // RFQ sequence stays on RFQ cards; Invoice reference from ERP field.
        String refNo = isRfq
            ? getSafeString(item["request_no"] ??
                item["rfq_no_code"] ??
                item["rfq_no"] ??
                item["name"] ??
                item["ref_no"] ??
                item["title"])
            : getSafeString(
                InvoiceApprovalDisplay.referenceNumber(item),
                fallback: 'N/A',
              );

        // Check multiple amount fields
        String amount = getSafeString(
            item["total_amount"] ??
                item["amount_total"] ??
                item["amount"] ??
                item["total"],
            fallback: "0");

        final rfqTitle = getSafeString(
          item["project_title"] ??
              item["project"] ??
              item["name"] ??
              item["title"],
          fallback: 'N/A',
        );

        final rfqSubtitle = getSafeString(
          item["client_name"] ??
              item["client"] ??
              item["vendor"] ??
              item["partner_name"],
          fallback: 'N/A',
        );

        final rfqDate = RfqApprovalDisplay.formattedDate(item).isNotEmpty
            ? RfqApprovalDisplay.formattedDate(item)
            : 'N/A';

        final invoiceTitle = getSafeString(
          item["project_title"] ?? item["project"] ?? item["name"],
          fallback: 'N/A',
        );

        final invoiceClient = getSafeString(
          item["client_name"] ?? item["client"] ?? item["partner_name"],
          fallback: 'N/A',
        );

        final invoiceDate = InvoiceApprovalDisplay.formattedDate(item).isNotEmpty
            ? InvoiceApprovalDisplay.formattedDate(item)
            : 'N/A';

        return GestureDetector(
          onTap: () async {
            debugPrint(
                '👆 [MyApproval][Invoice/RFQ] Tap -> type=$type, id=$id');
            // Mark item as viewed
            print('🔵 Marking as viewed - Type: $type, ID: $id');
            await ApprovalViewedService.markAsViewed(
              type,
              id,
            );

            if (context.mounted) {
              final upperType = type.toUpperCase();
              final result = upperType == 'INVOICE'
                  ? await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InvoiceDetailsScreen(
                          requestId: id,
                          type: type,
                          initialData: Map<String, dynamic>.from(item as Map),
                        ),
                      ),
                    )
                  : upperType == 'RFQ'
                      ? await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RfqDetailsScreen(
                              requestId: id,
                              type: type,
                              initialData:
                                  Map<String, dynamic>.from(item as Map),
                            ),
                          ),
                        )
                      : await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return ApprovalConfirmationScreen(
                              requestId: id,
                              type: type,
                            );
                          },
                        );
              // Trigger a rebuild to update the list after dialog closes
              debugPrint(
                '↩️ [MyApproval][Invoice/RFQ] Back from details -> type=$type, id=$id, result=$result',
              );
              if (result == true) {
                // Invalidate cache so header re-fetches fresh count from API
                ApprovalCountService.invalidateCache();
                ApprovalCountService.notifyListeners();
                // Refresh the list
                debugPrint(
                    '🔁 [MyApproval][Invoice/RFQ] Triggering onRefresh callback');
                onRefresh?.call();
              }
            }
          },
          child: isRfq
              ? _buildRfqCard(
                  item: item,
                  refNo: refNo,
                  title: rfqTitle,
                  subtitle: rfqSubtitle,
                  date: rfqDate,
                  amount: amount,
                )
              : _buildInvoiceCard(
                  item: item,
                  refNo: refNo,
                  title: invoiceTitle,
                  client: invoiceClient,
                  date: invoiceDate,
                  amount: amount,
                ),
        );
      },
    );
  }
}

// final item = approvalItems[index];
// List<String> statuses = ['approved', 'pending', 'rejected'];
// String sampleStatus = statuses[index % statuses.length];
// final itemData = {
//   "id": "${item["id"] ?? ""}",
//   "name": "${item["name"] ?? ""}",
//   "type": "${item["type"] ?? ""}",
//   "requester": "${item["requester_name"] ?? ""}",
//   "approver": "${item["emp_name"] ?? ""}",
//   "location": "${item["location"] ?? ""}",
//   "date": "${item["date"] ?? ""}",
//   "image_emp": "${item["image_emp"] ?? ""}",
//   "req_no":
//   "REQ-${(item["id"] ?? "").toString().padLeft(6, '0')}",
//   "title": "${item["name"] ?? ""}",
//   "status": item["status"] ?? sampleStatus,
// };

// return ApprovalCardTypeTwo(
//   item: itemData,
//   isExpanded: false,
//   onTap: () {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return ApprovalConfirmationScreen(
//           requestId: itemData["id"],
//           type: itemData["type"],
//         );
//       },
//     );
//   },
// );
