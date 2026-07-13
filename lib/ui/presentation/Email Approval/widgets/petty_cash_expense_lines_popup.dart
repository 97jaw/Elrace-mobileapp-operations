import 'package:el_race/ui/presentation/Email%20Approval/theme/approvals_overview_theme.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/approval_display_helpers.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/petty_cash_expense_line_groups.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class PettyCashExpenseLinesPopup {
  PettyCashExpenseLinesPopup._();

  static Future<void> show({
    required BuildContext context,
    required String title,
    required List<Map<String, dynamic>> lines,
    bool showTypeBadges = false,
  }) {
    final total = _sumLines(lines);

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final maxHeight = MediaQuery.sizeOf(ctx).height * 0.72;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(maxHeight: maxHeight),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: Colors.white, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 14.h, 8.w, 8.h),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.poppins(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                                color: ApprovalsOverviewTheme.textDark,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close_rounded),
                            color: ApprovalsOverviewTheme.textMuted,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              'PROJECT',
                              style: GoogleFonts.poppins(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: ApprovalsOverviewTheme.textSoft,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'AMOUNT',
                              textAlign: TextAlign.end,
                              style: GoogleFonts.poppins(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: ApprovalsOverviewTheme.textSoft,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Divider(
                      height: 1,
                      color: ApprovalsOverviewTheme.textSoft.withValues(alpha: 0.28),
                    ),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
                        itemCount: lines.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 16.h,
                          color: ApprovalsOverviewTheme.textSoft
                              .withValues(alpha: 0.22),
                        ),
                        itemBuilder: (context, index) {
                          final line = lines[index];
                          final project = _pick(line, const [
                            'project_name',
                            'project',
                            'description',
                            'name',
                          ]);
                          final amount = ApprovalDisplayHelpers.formatAmountWithAed(
                            line['amount'] ??
                                line['unit_price'] ??
                                line['subtotal'],
                            fallback: '0',
                          );
                          final dateRaw = _pick(line, const [
                            'date',
                            'expense_date',
                            'invoice_date',
                          ]);
                          final dateLabel = _formatDate(dateRaw);
                          final typeLabel = pettyCashExpenseTypeBadgeLabel(line);
                          final typeCode = _pick(line, const [
                            'expense_type',
                            'x_expense_type',
                          ]);
                          final badgeColor = pettyCashExpenseTypeBadgeColor(
                            expenseTypeCode: typeCode,
                            expenseTypeLabel: typeLabel,
                          );

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      project.isEmpty ? 'N/A' : project,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w600,
                                        color: ApprovalsOverviewTheme.textDark,
                                      ),
                                    ),
                                    if (dateLabel.isNotEmpty ||
                                        (showTypeBadges &&
                                            typeLabel.isNotEmpty)) ...[
                                      SizedBox(height: 4.h),
                                      Wrap(
                                        spacing: 6.w,
                                        runSpacing: 4.h,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          if (dateLabel.isNotEmpty)
                                            Text(
                                              dateLabel,
                                              style: GoogleFonts.poppins(
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.w500,
                                                color: ApprovalsOverviewTheme
                                                    .textMuted,
                                              ),
                                            ),
                                          if (showTypeBadges &&
                                              typeLabel.isNotEmpty)
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 7.w,
                                                vertical: 2.h,
                                              ),
                                              decoration: BoxDecoration(
                                                color: badgeColor
                                                    .withValues(alpha: 0.14),
                                                borderRadius:
                                                    BorderRadius.circular(6.r),
                                                border: Border.all(
                                                  color: badgeColor
                                                      .withValues(alpha: 0.45),
                                                ),
                                              ),
                                              child: Text(
                                                typeLabel,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 9.sp,
                                                  fontWeight: FontWeight.w700,
                                                  color: badgeColor,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  amount,
                                  textAlign: TextAlign.end,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                    color: ApprovalsOverviewTheme.petty,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: ApprovalsOverviewTheme.textSoft.withValues(alpha: 0.35),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Total',
                              style: GoogleFonts.poppins(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: ApprovalsOverviewTheme.textDark,
                              ),
                            ),
                          ),
                          Text(
                            ApprovalDisplayHelpers.formatAmountWithAed(
                              total,
                              fallback: '0',
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              color: ApprovalsOverviewTheme.petty,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static double _sumLines(List<Map<String, dynamic>> lines) {
    var total = 0.0;
    for (final line in lines) {
      final raw =
          line['amount'] ?? line['unit_price'] ?? line['subtotal'] ?? 0;
      if (raw is num) {
        total += raw.toDouble();
      } else {
        total += double.tryParse(raw.toString()) ?? 0;
      }
    }
    return total;
  }

  static String _pick(Map<String, dynamic> line, List<String> keys) {
    for (final key in keys) {
      final value = line[key];
      if (value == null || value == false) continue;
      final text = value.toString().trim();
      if (text.isEmpty || text.toLowerCase() == 'null') continue;
      return text;
    }
    return '';
  }

  static String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('dd/MM/yyyy').format(dt);
  }
}
