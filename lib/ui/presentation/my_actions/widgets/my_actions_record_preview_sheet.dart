import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_actions/data/my_actions_models.dart';
import 'package:el_race/ui/presentation/my_actions/data/my_actions_repository.dart';
import 'package:el_race/ui/presentation/my_actions/theme/my_actions_module_theme.dart';
import 'package:el_race/ui/presentation/my_actions/widgets/my_action_employee_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Draggable preview: basic record header + approvals/review trail table.
class MyActionsRecordPreviewSheet extends StatefulWidget {
  const MyActionsRecordPreviewSheet({
    super.key,
    required this.module,
    required this.item,
    required this.actionsType,
  });

  final MyActionsModule module;
  final MyActionItem item;
  final MyActionsType actionsType;

  static Future<void> show(
    BuildContext context, {
    required MyActionsModule module,
    required MyActionItem item,
    required MyActionsType actionsType,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => MyActionsRecordPreviewSheet(
        module: module,
        item: item,
        actionsType: actionsType,
      ),
    );
  }

  @override
  State<MyActionsRecordPreviewSheet> createState() =>
      _MyActionsRecordPreviewSheetState();
}

class _MyActionsRecordPreviewSheetState
    extends State<MyActionsRecordPreviewSheet> {
  final _repo = MyActionsRepository();
  bool _loading = true;
  Object? _error;
  MyActionRecordPreview? _preview;

  MyActionsModuleTheme get _theme => MyActionsModuleTheme.of(widget.module);

  String get _title {
    final item = widget.item;
    if (item.reference?.trim().isNotEmpty == true) return item.reference!.trim();
    if (item.name.trim().isNotEmpty) return item.name.trim();
    return 'Request #${item.id}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final preview = await _repo.fetchRecordPreview(
        type: widget.actionsType,
        recordId: widget.item.id,
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final parsed = DateTime.tryParse(raw.trim().replaceFirst(' ', 'T'));
    if (parsed == null) return raw.trim();
    return DateFormat('dd MMM yyyy').format(parsed);
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('approve') || s == 'done' || s == 'true') {
      return MyActionsModuleTheme.approved;
    }
    if (s.contains('reject') || s.contains('refuse')) {
      return MyActionsModuleTheme.rejected;
    }
    if (s.contains('skip')) return MyActionsModuleTheme.textMuted;
    return MyActionsModuleTheme.pending;
  }

  String _statusLabel(String status) {
    final s = status.toLowerCase().trim();
    if (s.isEmpty) return 'Pending';
    if (s == 'true' || s == 'approved' || s == 'approve' || s == 'done') {
      return 'Approved';
    }
    if (s.contains('reject') || s.contains('refuse')) return 'Rejected';
    if (s.contains('skip')) return 'Skipped';
    if (s.contains('pending') || s.contains('todo') || s.contains('wait')) {
      return 'Pending';
    }
    return status[0].toUpperCase() + status.substring(1);
  }

  List<MapEntry<String, String>> get _detailRows {
    final item = widget.item;
    final extras = _preview?.headerExtras ?? const <String, String>{};
    final dateLabel = _formatDate(item.date);
    final isInvoice = widget.module == MyActionsModule.invoice;
    final isRfq = widget.module == MyActionsModule.rfq;

    final rows = <MapEntry<String, String>>[
      // Invoice/RFQ are vendor documents — don't show injected login employee.
      if (!isInvoice &&
          !isRfq &&
          item.employeeName.trim().isNotEmpty)
        MapEntry('Employee', item.employeeName.trim()),
      if (!isInvoice && item.requestType?.trim().isNotEmpty == true)
        MapEntry('Type', item.requestType!.trim()),
      if (item.vendor?.trim().isNotEmpty == true)
        MapEntry('Vendor', item.vendor!.trim()),
      if (item.project?.trim().isNotEmpty == true)
        MapEntry('Project', item.project!.trim()),
      if (item.amountTotal != null)
        MapEntry('Amount', '${item.amountTotal!.toStringAsFixed(2)} AED'),
      if (dateLabel.isNotEmpty) MapEntry('Date', dateLabel),
      ...extras.entries,
    ];
    final seen = <String>{};
    final unique = <MapEntry<String, String>>[];
    for (final row in rows) {
      if (seen.add(row.key.toLowerCase())) unique.add(row);
    }
    return unique;
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final item = widget.item;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: height * 0.82,
        decoration: BoxDecoration(
          color: MyActionsModuleTheme.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(height: 10.th),
            Container(
              width: 42.tw,
              height: 4.th,
              decoration: BoxDecoration(
                color: MyActionsModuleTheme.textMuted.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.tw, 14.th, 12.tw, 8.th),
              child: Row(
                children: [
                  Container(
                    width: 36.tw,
                    height: 36.tw,
                    decoration: BoxDecoration(
                      color: _theme.tint,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    padding: EdgeInsets.all(7.tw),
                    child: Image.asset(_theme.iconAsset, fit: BoxFit.contain),
                  ),
                  SizedBox(width: 12.tw),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _theme.title,
                          style: GoogleFonts.poppins(
                            fontSize: 12.tsp,
                            fontWeight: FontWeight.w500,
                            color: MyActionsModuleTheme.textMuted,
                          ),
                        ),
                        Text(
                          _title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 16.tsp,
                            fontWeight: FontWeight.w600,
                            color: MyActionsModuleTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: MyActionsModuleTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20.tw, 4.th, 20.tw, 28.th),
                children: [
                  _HeaderCard(
                    theme: _theme,
                    item: item,
                    title: _title,
                    rows: _detailRows,
                    statusColor: _statusColor(item.status),
                    statusLabel: _statusLabel(item.status),
                  ),
                  SizedBox(height: 18.th),
                  Text(
                    widget.module == MyActionsModule.hr
                        ? 'Request approvals'
                        : widget.module == MyActionsModule.invoice
                            ? 'Invoice review trail'
                            : 'Review trail',
                    style: GoogleFonts.poppins(
                      fontSize: 14.tsp,
                      fontWeight: FontWeight.w600,
                      color: MyActionsModuleTheme.textDark,
                    ),
                  ),
                  SizedBox(height: 10.th),
                  if (_loading)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 28.th),
                      child: Center(
                        child: CircularProgressIndicator(color: _theme.primary),
                      ),
                    )
                  else if (_error != null)
                    _ErrorBox(message: '$_error', onRetry: _load)
                  else if ((_preview?.approvals.isEmpty ?? true))
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.th),
                      child: Text(
                        'No approval steps found for this record.',
                        style: GoogleFonts.poppins(
                          fontSize: 13.tsp,
                          color: MyActionsModuleTheme.textMuted,
                        ),
                      ),
                    )
                  else
                    _ApprovalsTable(
                      theme: _theme,
                      steps: _preview!.approvals,
                      statusColor: _statusColor,
                      statusLabel: _statusLabel,
                      formatDate: _formatDate,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.theme,
    required this.item,
    required this.title,
    required this.rows,
    required this.statusColor,
    required this.statusLabel,
  });

  final MyActionsModuleTheme theme;
  final MyActionItem item;
  final String title;
  final List<MapEntry<String, String>> rows;
  final Color statusColor;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.tw),
      decoration: BoxDecoration(
        color: theme.wash,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: theme.soft.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MyActionEmployeeAvatar.circle(
                imageUrl: item.employeeImage,
                statusColor: statusColor,
                fallbackTint: theme.tint,
                fallbackIcon: theme.primary,
                size: 44,
              ),
              SizedBox(width: 12.tw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14.tsp,
                        fontWeight: FontWeight.w600,
                        color: MyActionsModuleTheme.textDark,
                      ),
                    ),
                    SizedBox(height: 6.th),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.tw,
                        vertical: 3.th,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 11.tsp,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (rows.isNotEmpty) ...[
            SizedBox(height: 12.th),
            ...rows.map(
              (e) => Padding(
                padding: EdgeInsets.only(bottom: 6.th),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 88.tw,
                      child: Text(
                        e.key,
                        style: GoogleFonts.poppins(
                          fontSize: 12.tsp,
                          color: MyActionsModuleTheme.textMuted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.value,
                        style: GoogleFonts.poppins(
                          fontSize: 12.tsp,
                          fontWeight: FontWeight.w500,
                          color: MyActionsModuleTheme.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ApprovalsTable extends StatelessWidget {
  const _ApprovalsTable({
    required this.theme,
    required this.steps,
    required this.statusColor,
    required this.statusLabel,
    required this.formatDate,
  });

  final MyActionsModuleTheme theme;
  final List<MyActionApprovalStep> steps;
  final Color Function(String status) statusColor;
  final String Function(String status) statusLabel;
  final String Function(String? raw) formatDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: MyActionsModuleTheme.textMuted.withValues(alpha: 0.18),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: theme.tint,
            padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 10.th),
            child: Row(
              children: [
                _cell('#', flex: 1, bold: true),
                _cell('Approver', flex: 5, bold: true),
                _cell('Status', flex: 3, bold: true, alignEnd: true),
              ],
            ),
          ),
          ...List.generate(steps.length, (index) {
            final step = steps[index];
            final color = statusColor(step.status);
            final seq = step.sequence ?? (index + 1);
            final subtitle = [
              if (step.description?.trim().isNotEmpty == true)
                step.description!.trim(),
              if (step.approveTime != null) formatDate(step.approveTime),
            ].where((s) => s.isNotEmpty).join(' · ');
            return Container(
              color: index.isOdd
                  ? MyActionsModuleTheme.textMuted.withValues(alpha: 0.04)
                  : MyActionsModuleTheme.white,
              padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 11.th),
              child: Row(
                children: [
                  _cell('$seq', flex: 1),
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.name.trim().isEmpty ? '—' : step.name.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 12.tsp,
                            fontWeight: FontWeight.w500,
                            color: MyActionsModuleTheme.textDark,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          SizedBox(height: 2.th),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 10.tsp,
                              color: MyActionsModuleTheme.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.tw,
                          vertical: 3.th,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          statusLabel(step.status),
                          style: GoogleFonts.poppins(
                            fontSize: 10.tsp,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _cell(
    String text, {
    required int flex,
    bool bold = false,
    bool alignEnd = false,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        style: GoogleFonts.poppins(
          fontSize: 11.tsp,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
          color: bold
              ? MyActionsModuleTheme.textDark
              : MyActionsModuleTheme.textMuted,
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.tw),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load approvals.',
            style: GoogleFonts.poppins(
              fontSize: 13.tsp,
              fontWeight: FontWeight.w600,
              color: MyActionsModuleTheme.rejected,
            ),
          ),
          SizedBox(height: 4.th),
          Text(
            message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11.tsp,
              color: MyActionsModuleTheme.textMuted,
            ),
          ),
          SizedBox(height: 10.th),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
