import 'dart:async';

import 'package:el_race/ui/presentation/Email%20Approval/delayed/data/delayed_approvals_repository.dart';
import 'package:el_race/ui/presentation/Email%20Approval/theme/approvals_overview_theme.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/approval_display_helpers.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/approval_photo_cache.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/hr_approval_display.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/invoice_approval_display.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/petty_cash_approval_display.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/rfq_approval_display.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/approval_list_avatar.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Bottom sheet listing approval / delayed records (reference card design).
class ApprovalOverviewRecordsSheet {
  ApprovalOverviewRecordsSheet._();

  static double _sheetHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height * 0.88;

  static Future<void> showCategory({
    required BuildContext context,
    required String title,
    required String categoryKey,
    required List<Map<String, dynamic>> Function() getItems,
    required int expectedCount,
    required bool Function() isCategoryLoading,
    required Future<void> Function(
      BuildContext sheetContext,
      Map<String, dynamic> item,
      String categoryKey,
    ) onItemTap,
    VoidCallback? onRequestReload,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => SizedBox(
        height: _sheetHeight(ctx),
        child: _RecordsSheetBody(
          title: title,
          categoryKey: categoryKey,
          getItems: getItems,
          expectedCount: expectedCount,
          isCategoryLoading: isCategoryLoading,
          onRequestReload: onRequestReload,
          onItemTap: onItemTap,
        ),
      ),
    );
  }

  static Future<void> showDelayed({
    required BuildContext context,
    required Future<void> Function(
      BuildContext sheetContext,
      Map<String, dynamic> item,
    ) onItemTap,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => SizedBox(
        height: _sheetHeight(ctx),
        child: _DelayedRecordsSheetBody(onItemTap: onItemTap),
      ),
    );
  }
}

class _RecordsSheetBody extends StatefulWidget {
  const _RecordsSheetBody({
    required this.title,
    required this.categoryKey,
    required this.getItems,
    required this.expectedCount,
    required this.isCategoryLoading,
    required this.onItemTap,
    this.onRequestReload,
  });

  final String title;
  final String categoryKey;
  final List<Map<String, dynamic>> Function() getItems;
  final int expectedCount;
  final bool Function() isCategoryLoading;
  final VoidCallback? onRequestReload;
  final Future<void> Function(
    BuildContext sheetContext,
    Map<String, dynamic> item,
    String categoryKey,
  ) onItemTap;

  @override
  State<_RecordsSheetBody> createState() => _RecordsSheetBodyState();
}

class _RecordsSheetBodyState extends State<_RecordsSheetBody> {
  Timer? _pollTimer;
  int _pollAttempts = 0;

  @override
  void initState() {
    super.initState();
    final items = widget.getItems();
    if (items.isEmpty &&
        widget.expectedCount > 0 &&
        !widget.isCategoryLoading()) {
      widget.onRequestReload?.call();
    }
    _startPollingIfNeeded();
  }

  void _startPollingIfNeeded() {
    _pollTimer?.cancel();
    if (widget.getItems().isNotEmpty || widget.expectedCount == 0) return;

    _pollTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      _pollAttempts++;
      setState(() {});
      final items = widget.getItems();
      if (items.isNotEmpty ||
          !widget.isCategoryLoading() ||
          _pollAttempts >= 25) {
        _pollTimer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  bool get _showLoading {
    final items = widget.getItems();
    return items.isEmpty &&
        (widget.isCategoryLoading() ||
            (widget.expectedCount > 0 && _pollAttempts < 25));
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.getItems();

    return Material(
      color: const Color(0xFFF4F6F9),
      borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 10.h),
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18.w, 14.h, 8.w, 4.h),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: GoogleFonts.poppins(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: ApprovalsOverviewTheme.textDark,
                        ),
                      ),
                      Text(
                        _showLoading
                            ? 'Loading records…'
                            : '${items.length} record${items.length == 1 ? '' : 's'}',
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color: ApprovalsOverviewTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, size: 22.sp),
                  color: ApprovalsOverviewTheme.textMuted,
                ),
              ],
            ),
          ),
          Expanded(
            child: _showLoading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? Center(
                        child: Text(
                          'No records found',
                          style: GoogleFonts.poppins(
                            fontSize: 13.sp,
                            color: ApprovalsOverviewTheme.textSoft,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          14.w,
                          4.h,
                          14.w,
                          context.systemBottomInset + 16.h,
                        ),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => SizedBox(height: 8.h),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _ApprovalRecordTile(
                            item: item,
                            categoryKey: widget.categoryKey,
                            onTap: () async {
                              await widget.onItemTap(
                                context,
                                item,
                                widget.categoryKey,
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _DelayedRecordsSheetBody extends StatefulWidget {
  const _DelayedRecordsSheetBody({required this.onItemTap});

  final Future<void> Function(
    BuildContext sheetContext,
    Map<String, dynamic> item,
  ) onItemTap;

  @override
  State<_DelayedRecordsSheetBody> createState() =>
      _DelayedRecordsSheetBodyState();
}

class _DelayedRecordsSheetBodyState extends State<_DelayedRecordsSheetBody> {
  final _repo = DelayedApprovalsRepository();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await _repo.fetchAll(limit: 50, offset: 0);
      final items = response.toCardItems();
      items.sort(
        (a, b) => ((b['daysDelayed'] ?? 0) as num)
            .compareTo((a['daysDelayed'] ?? 0) as num),
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF4F6F9),
      borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 10.h),
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18.w, 14.h, 8.w, 4.h),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delayed Requests',
                        style: GoogleFonts.poppins(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: ApprovalsOverviewTheme.textDark,
                        ),
                      ),
                      if (!_loading && _error == null)
                        Text(
                          '${_items.length} record${_items.length == 1 ? '' : 's'}',
                          style: GoogleFonts.poppins(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                            color: ApprovalsOverviewTheme.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, size: 22.sp),
                  color: ApprovalsOverviewTheme.textMuted,
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24.w),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(fontSize: 12.sp),
                          ),
                        ),
                      )
                    : _items.isEmpty
                        ? Center(
                            child: Text(
                              'No delayed records',
                              style: GoogleFonts.poppins(
                                fontSize: 13.sp,
                                color: ApprovalsOverviewTheme.textSoft,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              14.w,
                              4.h,
                              14.w,
                              context.systemBottomInset + 16.h,
                            ),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => SizedBox(height: 8.h),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return _ApprovalRecordTile(
                                item: item,
                                categoryKey: 'delayed',
                                statusLabel: 'DELAYED',
                                onTap: () async {
                                  await widget.onItemTap(context, item);
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalRecordTile extends StatelessWidget {
  const _ApprovalRecordTile({
    required this.item,
    required this.categoryKey,
    required this.onTap,
    this.accentColor,
    this.statusLabel,
  });

  final Map<String, dynamic> item;
  final String categoryKey;
  final VoidCallback onTap;
  final Color? accentColor;
  final String? statusLabel;

  String _str(dynamic v, {String fallback = ''}) {
    if (v == null || v == false || v == true) return fallback;
    final s = v.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return fallback;
    return s;
  }

  String _categoryLabel() {
    switch (categoryKey) {
      case 'hr':
        return HrApprovalDisplay.sequence(item).toUpperCase();
      case 'rfq':
        return RfqApprovalDisplay.sequence(item).toUpperCase();
      case 'invoice':
        return 'INVOICE';
      case 'petty_cash':
        return 'PETTY CASH';
      case 'delayed':
        return _str(item['type'] ?? item['requestType'], fallback: 'DELAYED')
            .toUpperCase();
      default:
        return categoryKey.toUpperCase();
    }
  }

  Color _accent() =>
      accentColor ??
      (categoryKey == 'delayed'
          ? _delayedAccent()
          : ApprovalsOverviewTheme.accentFor(categoryKey));

  Color _delayedAccent() {
    final delayedType = _str(item['type']).toUpperCase();
    switch (delayedType) {
      case 'RFQ':
        return ApprovalsOverviewTheme.rfq;
      case 'INVOICE':
        return ApprovalsOverviewTheme.invoice;
      case 'PETTY CASH':
        return ApprovalsOverviewTheme.petty;
      case 'HR':
      default:
        return ApprovalsOverviewTheme.hr;
    }
  }

  String _rfqReference() {
    return _str(
      item['name'] ?? item['ref_no'] ?? item['request_no'] ?? item['rfq_no'],
      fallback: 'RFQ',
    );
  }

  String _vendorName() {
    return _str(
      item['vendor_name'] ??
          item['partner_name'] ??
          item['client_name'] ??
          item['vendor'] ??
          item['client'] ??
          item['partner_id'],
    );
  }

  String _partnerName() {
    return _str(
      item['partner_name'] ??
          item['client_name'] ??
          item['vendor_name'] ??
          item['vendor'] ??
          item['client'] ??
          item['partner'],
      fallback: 'N/A',
    );
  }

  String _invoiceSequenceName() {
    return _str(
      item['name'] ?? item['invoice_no_code'] ?? item['ref_no'],
    );
  }

  String _invoiceNoSecondary() {
    return _str(item['invoice_no'] ?? item['invoice_no_code']);
  }

  String _projectTitle() {
    return _str(
      item['project_title'] ?? item['project'] ?? item['agreement'],
    );
  }

  String _title() {
    if (categoryKey == 'delayed') {
      return _str(
        item['name'] ??
            item['reqNo'] ??
            item['requestType'] ??
            item['project'] ??
            item['title'],
        fallback: 'Request',
      );
    }
    if (categoryKey == 'hr') {
      final requestType = HrApprovalDisplay.requestTypeName(item);
      if (requestType.isNotEmpty) return requestType;
      return _str(
        item['leave_request_subtype'] ??
            item['request_type'] ??
            item['requestType'] ??
            item['type'] ??
            item['holiday_status_name'] ??
            item['leave_type'] ??
            item['title'] ??
            item['name'],
        fallback: 'Request',
      );
    }
    if (categoryKey == 'rfq') {
      final project = _projectTitle();
      if (project.isNotEmpty) return project;
      return _vendorName().isNotEmpty ? _vendorName() : _rfqReference();
    }
    if (categoryKey == 'invoice') {
      return _str(
        item['project_title'] ?? item['project'] ?? item['title'],
        fallback: _invoiceSequenceName().isNotEmpty
            ? _invoiceSequenceName()
            : 'Invoice',
      );
    }
    if (categoryKey == 'petty_cash') {
      return PettyCashApprovalDisplay.holderName(item);
    }
    return _str(
      item['project_title'] ??
          item['project'] ??
          item['name'] ??
          item['request_type'] ??
          item['requestType'] ??
          item['type'] ??
          item['title'] ??
          item['reqNo'],
      fallback: 'Request',
    );
  }

  String _requester() {
    if (categoryKey == 'delayed') {
      final name = _str(
        item['employee_name'] ??
            item['employeeName'] ??
            item['requester_name'] ??
            item['reviewer_name'] ??
            item['validator_name'] ??
            item['emp_name'] ??
            item['requested_by'] ??
            item['partner_name'],
        fallback: '',
      );
      if (name.isNotEmpty && name.toUpperCase() != 'N/A') return name;
      final code = _str(
        item['emp_code'] ??
            item['empCode'] ??
            item['employee_code'] ??
            item['reviewer_emp_id'] ??
            item['validator_emp_id'],
        fallback: '',
      );
      if (code.isNotEmpty && code.toUpperCase() != 'N/A') return code;
      final ref = _str(
        item['reqNo'] ?? item['name'] ?? item['reference'],
        fallback: '',
      );
      return ref.isNotEmpty ? ref : 'Unknown';
    }
    if (categoryKey == 'invoice') {
      return _partnerName();
    }
    if (categoryKey == 'rfq') {
      return _vendorName().isNotEmpty ? _vendorName() : 'Unknown';
    }
    if (categoryKey == 'petty_cash') {
      return _str(
        item['requester_name'] ??
            item['requester'] ??
            item['emp_name'] ??
            item['employee_name'] ??
            item['holder_name'] ??
            item['holder'],
        fallback: 'Unknown',
      );
    }
    return _str(
      item['employee_name'] ??
          item['requester_name'] ??
          item['emp_name'] ??
          item['employeeName'],
      fallback: 'Unknown',
    );
  }

  bool get _showsAmount =>
      categoryKey == 'rfq' ||
      categoryKey == 'invoice' ||
      categoryKey == 'petty_cash';

  String _amountText() {
    return ApprovalDisplayHelpers.formatAmountWithAed(
      item['amount_total'] ??
          item['total_amount'] ??
          item['amount'] ??
          item['total'],
      fallback: '0',
    );
  }

  ApprovalAvatarKind _avatarKind() {
    return switch (categoryKey) {
      'invoice' || 'rfq' => ApprovalAvatarKind.vendor,
      'petty_cash' => ApprovalAvatarKind.pettyCashHolder,
      'delayed' => switch (_str(item['type']).toUpperCase()) {
          'INVOICE' || 'RFQ' => ApprovalAvatarKind.vendor,
          'PETTY CASH' => ApprovalAvatarKind.pettyCashHolder,
          _ => ApprovalAvatarKind.employee,
        },
      _ => ApprovalAvatarKind.employee,
    };
  }

  String _avatarInitials() {
    if (categoryKey == 'delayed') {
      final delayedType = _str(item['type']).toUpperCase();
      if (delayedType == 'INVOICE' || delayedType == 'RFQ') {
        return _str(
          item['client_name'] ??
              item['vendor_name'] ??
              item['partner_name'] ??
              item['vendor'] ??
              item['employee_name'] ??
              item['requester_name'],
        );
      }
      if (delayedType == 'PETTY CASH') {
        return _str(
          item['pettycash_holder'] ??
              item['holder_name'] ??
              item['holder'] ??
              item['employee_name'] ??
              item['requester_name'],
        );
      }
      return _str(
        item['employee_name'] ??
            item['requester_name'] ??
            item['reviewer_name'] ??
            item['validator_name'] ??
            item['emp_name'],
      );
    }
    if (categoryKey == 'invoice' || categoryKey == 'rfq') {
      return _str(
        item['client_name'] ??
            item['vendor_name'] ??
            item['partner_name'] ??
            item['vendor'],
      );
    }
    if (categoryKey == 'petty_cash') {
      return _str(
        item['pettycash_holder'] ??
            item['holder_name'] ??
            item['holder'] ??
            item['requester_name'] ??
            item['emp_name'],
      );
    }
    return _requester();
  }

  String _hrMidRowLabel() {
    final leaveSubtype = HrApprovalDisplay.leaveSubtypeLabel(item);
    if (leaveSubtype.isNotEmpty) return leaveSubtype;
    return '';
  }

  String _fullDateLabel() {
    if (categoryKey == 'hr') {
      return HrApprovalDisplay.formattedDate(item);
    }
    if (categoryKey == 'rfq') {
      return RfqApprovalDisplay.formattedDate(item);
    }
    if (categoryKey == 'petty_cash') {
      return PettyCashApprovalDisplay.formattedDate(item);
    }
    if (categoryKey == 'invoice') {
      return InvoiceApprovalDisplay.formattedDate(item);
    }
    return '';
  }

  String _status() {
    if (statusLabel != null) return statusLabel!;
    final raw = _str(item['state'] ?? item['status'], fallback: 'open');
    final upper = raw.toUpperCase();
    if (categoryKey == 'invoice' && upper == 'DRAFT') return '';
    if (categoryKey == 'petty_cash' && upper == 'DRAFT') return '';
    if (categoryKey == 'hr' && HrApprovalDisplay.shouldHideDraftStatus(item)) {
      return '';
    }
    if (categoryKey == 'rfq' && RfqApprovalDisplay.shouldHideDraftStatus(item)) {
      return '';
    }
    return upper;
  }

  String _timeLabel() {
    if (categoryKey == 'delayed') {
      final days = item['daysDelayed'];
      if (days is num && days > 0) return '${days.toInt()}d';
    }
    final raw =
        _str(item['date'] ?? item['request_date'] ?? item['requestDate']);
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.tryParse(raw);
      if (dt == null) return raw;
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 48) return '${diff.inHours}h';
      return DateFormat('d MMM').format(dt);
    } catch (_) {
      return raw;
    }
  }

  Widget _buildHeaderLabel(Color color) {
    if (categoryKey == 'invoice') {
      final seq = _invoiceSequenceName();
      final invNo = _invoiceNoSecondary();
      final showSecondary =
          invNo.isNotEmpty && invNo.toUpperCase() != seq.toUpperCase();
      if (seq.isNotEmpty) {
        return RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            children: [
              TextSpan(
                text: seq,
                style: GoogleFonts.poppins(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w700,
                  color: ApprovalsOverviewTheme.textSoft,
                  letterSpacing: 0.4,
                ),
              ),
              if (showSecondary)
                TextSpan(
                  text: '  –  $invNo',
                  style: GoogleFonts.poppins(
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w400,
                    color: ApprovalsOverviewTheme.textSoft,
                  ),
                ),
            ],
          ),
        );
      }
    }

    return Text(
      categoryKey == 'hr'
          ? HrApprovalDisplay.sequence(item).toUpperCase()
          : categoryKey == 'rfq'
              ? RfqApprovalDisplay.sequence(item).toUpperCase()
              : categoryKey == 'petty_cash'
                  ? PettyCashApprovalDisplay.sequence(item).toUpperCase()
                  : _categoryLabel(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.poppins(
        fontSize: 9.sp,
        fontWeight: FontWeight.w600,
        color: ApprovalsOverviewTheme.textSoft,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _buildAmountFooter() {
    if (!_showsAmount) return const SizedBox.shrink();

    if (categoryKey == 'invoice') {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_fullDateLabel().isNotEmpty)
            Text(
              _fullDateLabel(),
              style: GoogleFonts.poppins(
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
                color: ApprovalsOverviewTheme.textMuted,
              ),
            ),
          const Spacer(),
          Text(
            _amountText(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: ApprovalsOverviewTheme.invoice,
            ),
          ),
        ],
      );
    }

    if (categoryKey == 'rfq') {
      final dateLabel = RfqApprovalDisplay.formattedDate(item);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (dateLabel.isNotEmpty)
            Expanded(
              child: Text(
                dateLabel,
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: ApprovalsOverviewTheme.textMuted,
                ),
              ),
            )
          else
            const Spacer(),
          Text(
            _amountText(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: ApprovalsOverviewTheme.rfq,
            ),
          ),
        ],
      );
    }

    if (categoryKey == 'petty_cash') {
      final dateLabel = PettyCashApprovalDisplay.formattedDate(item);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (dateLabel.isNotEmpty)
            Expanded(
              child: Text(
                dateLabel,
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: ApprovalsOverviewTheme.textMuted,
                ),
              ),
            )
          else
            const Spacer(),
          Text(
            _amountText(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: ApprovalsOverviewTheme.petty,
            ),
          ),
        ],
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        _amountText(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          fontSize: 16.sp,
          fontWeight: FontWeight.w800,
          color: ApprovalsOverviewTheme.invoice,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _accent();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: Colors.white, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 4.w,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(14.r),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
                  child: ApprovalListAvatar(
                    item: item,
                    kind: _avatarKind(),
                    size: 44.w,
                    initials: _avatarInitials(),
                    lazyLoadCategory:
                        ApprovalPhotoCache.fromCategoryKey(categoryKey),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(0, 12.h, 12.w, 12.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.layers_rounded,
                                size: 14.sp, color: color),
                            SizedBox(width: 5.w),
                            Expanded(
                              child: _buildHeaderLabel(color),
                            ),
                            if (categoryKey == 'hr' &&
                                _fullDateLabel().isNotEmpty)
                              Text(
                                _fullDateLabel(),
                                style: GoogleFonts.poppins(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w500,
                                  color: ApprovalsOverviewTheme.textMuted,
                                ),
                              )
                            else if (_status().isNotEmpty) ...[
                              Container(
                                width: 6.w,
                                height: 6.w,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                _status(),
                                style: GoogleFonts.poppins(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w600,
                                  color: ApprovalsOverviewTheme.textSoft,
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          _title(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: ApprovalsOverviewTheme.textDark,
                            height: 1.25,
                          ),
                        ),
                        if (categoryKey == 'hr' &&
                            _hrMidRowLabel().isNotEmpty) ...[
                          SizedBox(height: 4.h),
                          Text(
                            _hrMidRowLabel(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: ApprovalsOverviewTheme.hr,
                            ),
                          ),
                        ],
                        if (categoryKey != 'petty_cash') ...[
                          SizedBox(height: 6.h),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'For ${_requester()}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w500,
                                    color: ApprovalsOverviewTheme.textMuted,
                                  ),
                                ),
                              ),
                              if (categoryKey != 'invoice' &&
                                  categoryKey != 'hr' &&
                                  categoryKey != 'rfq' &&
                                  _timeLabel().isNotEmpty) ...[
                                Text(
                                  _timeLabel(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w500,
                                    color: ApprovalsOverviewTheme.textSoft,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                        if (_showsAmount) ...[
                          SizedBox(height: 4.h),
                          _buildAmountFooter(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
