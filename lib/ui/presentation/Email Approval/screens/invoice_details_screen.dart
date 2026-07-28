import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/Email%20Approval/theme/approvals_overview_theme.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/approval_display_helpers.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/approval_action_buttons.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:el_race/utils/Util.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:math' as math;

class InvoiceDetailsScreen extends StatefulWidget {
  final String requestId;
  final String type;
  final Map<String, dynamic>? initialData;

  const InvoiceDetailsScreen({
    super.key,
    required this.requestId,
    required this.type,
    this.initialData,
  });

  @override
  State<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends State<InvoiceDetailsScreen> {
  static const String _localFakeInvoiceRequestId = 'LOCAL_FAKE_INVOICE_001';
  bool _isLoading = true;
  String _error = '';

  Map<String, dynamic> _formData = const {};

  bool get _isLocalFakeRequest =>
      widget.requestId == _localFakeInvoiceRequestId;

  Map<String, dynamic> _buildLocalFakeInvoiceData() {
    return {
      'request_no': 'INV/1254/89585',
      'project_name': 'Project Name',
      'department': 'Department',
      'vendor_name': 'Al Ameen Interiors',
      'vendor_tags': ['Ceiling', 'Civil', 'Fitout', 'Label'],
      'work_order_no': '123345654874954652',
      'request_date': '2025-01-10',
      'material_type': 'Ceramic',
      'contract_lpo': 'RCC/LPO/1231215',
      'advance': '15000',
      'progress': '60000',
      'last_update': '2025-01-28',
      'retention': '-',
      'invoice_amount': '1000000',
      'completion': '85',
      'advance_percentage': '20%',
      'last_update_percentage': '30%',
      'retention_percentage': '10%',
      'comment': '',
      'client_photo_url': '',
      'attachment_ids': ['1'],
    };
  }

  @override
  void initState() {
    super.initState();
    if (_isLocalFakeRequest) {
      final fake = _buildLocalFakeInvoiceData();
      _formData = fake;
      _isLoading = false;
      return;
    }
    if (widget.initialData != null) {
      _formData = Map<String, dynamic>.from(widget.initialData!);
    }
    _fetchInvoiceDetails();
  }

  String _safe(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    if (v == false || v == true) return fallback;
    final s = v.toString();
    if (s.isEmpty) return fallback;
    final lower = s.toLowerCase();
    if (lower == 'false' || lower == 'true' || lower == 'null') return fallback;
    return s;
  }

  String _pick(List<dynamic> values, {String fallback = ''}) {
    for (final v in values) {
      final s = _safe(v);
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }

  String _displayOrDash(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? '-' : normalized;
  }

  String _formatDate(dynamic value) {
    final raw = _safe(value);
    if (raw.isEmpty) return '-';
    final normalized = raw.contains(' ') ? raw.replaceFirst(' ', 'T') : raw;
    final parsed = DateTime.tryParse(normalized) ?? DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  String _formatAmount(dynamic value) {
    final raw = _safe(value);
    if (raw.isEmpty || raw == '-') return '-';
    return ApprovalDisplayHelpers.formatAmountWithAed(raw, fallback: '-');
  }

  double _parsePercent(dynamic value) {
    final raw = _safe(value);
    if (raw.isEmpty) return 0;
    final cleaned =
        raw.replaceAll('%', '').replaceAll(RegExp(r'[^0-9.\-]'), '');
    final parsed = double.tryParse(cleaned);
    if (parsed == null || parsed <= 0) return 0;
    if (parsed > 100) return 100;
    return parsed;
  }

  List<String> _extractTags(List<dynamic> candidates) {
    for (final raw in candidates) {
      if (raw == null || raw == false || raw == true) continue;

      if (raw is List) {
        final listTags = raw
            .map((e) => e.toString().trim())
            .map((e) => e
                .replaceAll('[', '')
                .replaceAll(']', '')
                .replaceAll('"', '')
                .replaceAll("'", '')
                .trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (listTags.isNotEmpty) return listTags;
        continue;
      }

      final str = raw.toString().trim();
      if (str.isEmpty) continue;
      final lower = str.toLowerCase();
      if (lower == 'null' || lower == 'false' || lower == 'true') continue;

      final parsed = str
          .split(RegExp(r'[,|]'))
          .map((e) => e.trim())
          .map((e) => e
              .replaceAll('[', '')
              .replaceAll(']', '')
              .replaceAll('"', '')
              .replaceAll("'", '')
              .trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (parsed.isNotEmpty) return parsed;
    }

    return const <String>[];
  }

  Future<void> _fetchInvoiceDetails() async {
    final token = SharedPref.getLoginData().result?.token;
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final url = Uri.parse('https://erp.elrace.com/api/get_invoice_details');
    final commentParam = _pick([
      _formData['comment'],
      widget.initialData?['comment'],
      _formData['note'],
      widget.initialData?['note'],
      _formData['description'],
      widget.initialData?['description'],
    ]);
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'params': {
        'invoice_id': int.tryParse(widget.requestId),
        'comment': commentParam,
      },
    });

    // cURL debug
    debugPrint('\n==== INVOICE DETAILS REQUEST ====');
    debugPrint('curl -X GET "$url" \\');
    headers.forEach((k, v) {
      final safe = k == 'Authorization' ? 'Bearer [TOKEN]' : v;
      debugPrint('  -H "$k: $safe" \\');
    });
    debugPrint('  -d \'$body\'');
    debugPrint('=========================\n');

    try {
      final request = http.Request('GET', url)
        ..headers.addAll(headers)
        ..body = body;

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      // raw response logging
      debugPrint(
          '\n==== INVOICE DETAILS RESPONSE (status: ${response.statusCode}) ====');
      final rawBody = response.body;
      const chunk = 800;
      for (var i = 0; i < rawBody.length; i += chunk) {
        debugPrint(rawBody.substring(
            i, i + chunk > rawBody.length ? rawBody.length : i + chunk));
      }
      debugPrint('=========================\n');

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to load invoice details: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final result = (decoded['result'] as Map?)?['data'] as Map?;
      final formView =
          (result?['form_view'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        final merged = Map<String, dynamic>.from(_formData);
        merged.addAll(formView);
        _formData = merged;
        _isLoading = false;
        _error = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  int? _parsePositiveInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value > 0 ? value : null;
    if (value is num) {
      final asInt = value.toInt();
      return asInt > 0 ? asInt : null;
    }
    return int.tryParse(value.toString().trim());
  }

  Future<void> _viewLpoReport({String? lpoName}) async {
    final poId = _parsePositiveInt(
          _formData['lpo_id'],
        ) ??
        _parsePositiveInt(_formData['purchase_order_id']) ??
        _parsePositiveInt(_formData['po_id']);

    if (poId == null) {
      Fluttertoast.showToast(
        msg: 'No LPO linked to this invoice.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.black,
        textColor: Colors.white,
      );
      return;
    }

    await Util.openLpoPdfReport(
      context,
      poId,
      lpoName: (lpoName != null && lpoName.trim().isNotEmpty && lpoName != '-')
          ? lpoName.trim()
          : null,
    );
  }

  Widget _sectionTitle({
    required String title,
    required IconData icon,
    Color iconColor = const Color(0xFF2F80ED),
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 22.tw,
          height: 22.tw,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6.tr),
          ),
          child: Icon(icon, size: 13.tsp, color: iconColor),
        ),
        SizedBox(width: 8.tw),
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 11.tsp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: const Color(0xFF2F80ED),
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _glassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return OverviewGlassPanel(
      fillAlpha: 0.94,
      blurSigma: 8,
      radius: 18,
      padding: padding ?? EdgeInsets.fromLTRB(14.tw, 12.th, 14.tw, 12.th),
      child: child,
    );
  }

  Widget _infoField({
    required String label,
    required String value,
    Color? valueColor,
    IconData? leadingIcon,
    Color? iconColor,
    int maxLines = 2,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10.tsp,
            fontWeight: FontWeight.w500,
            color: ApprovalsOverviewTheme.textSoft,
          ),
        ),
        SizedBox(height: 4.th),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leadingIcon != null) ...[
              Icon(
                leadingIcon,
                size: 14.tsp,
                color: iconColor ?? ApprovalsOverviewTheme.textMuted,
              ),
              SizedBox(width: 5.tw),
            ],
            Expanded(
              child: Text(
                _displayOrDash(value),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12.tsp,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: valueColor ?? ApprovalsOverviewTheme.textDark,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _categoryPill(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 5.th),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE7FF),
        borderRadius: BorderRadius.circular(20.tr),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.brush_rounded, size: 12.tsp, color: const Color(0xFF6B4EFF)),
          SizedBox(width: 5.tw),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 10.tsp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6B4EFF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _docIconButton({
    required VoidCallback? onTap,
    Color color = const Color(0xFF2F80ED),
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.tr),
        child: Container(
          width: 34.tw,
          height: 34.tw,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10.tr),
          ),
          child: Icon(Icons.description_outlined, size: 18.tsp, color: color),
        ),
      ),
    );
  }

  Widget _financeMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(10.tw, 10.th, 10.tw, 10.th),
      decoration: BoxDecoration(
        color: ApprovalsOverviewTheme.screenTintLight.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14.tr),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 10.tsp,
                    fontWeight: FontWeight.w500,
                    color: ApprovalsOverviewTheme.textSoft,
                  ),
                ),
              ),
              Container(
                width: 24.tw,
                height: 24.tw,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8.tr),
                ),
                child: Icon(icon, size: 13.tsp, color: accent),
              ),
            ],
          ),
          SizedBox(height: 8.th),
          Text(
            _displayOrDash(value),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 13.tsp,
              fontWeight: FontWeight.w700,
              color: ApprovalsOverviewTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _invoiceAmountBar({
    required String amount,
    VoidCallback? onTapDoc,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 12.th),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8E6),
        borderRadius: BorderRadius.circular(14.tr),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoice Amount',
                  style: GoogleFonts.poppins(
                    fontSize: 10.tsp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFB4534A),
                  ),
                ),
                SizedBox(height: 2.th),
                Text(
                  _displayOrDash(amount),
                  style: GoogleFonts.poppins(
                    fontSize: 18.tsp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFD32F2F),
                  ),
                ),
              ],
            ),
          ),
          _docIconButton(
            onTap: onTapDoc,
            color: const Color(0xFFD32F2F),
          ),
        ],
      ),
    );
  }

  Widget _invoiceRequestHeader({
    required String imageUrl,
    required String projectName,
    required double completionPercent,
  }) {
    return _glassCard(
      padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 12.th),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 58.tw,
            height: 58.tw,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.95),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: ApprovalsOverviewTheme.invoice.withValues(alpha: 0.14),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(
              child: _buildAvatar(imageUrl: imageUrl, name: projectName),
            ),
          ),
          SizedBox(width: 12.tw),
          Expanded(
            child: Text(
              _displayOrDash(projectName),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 15.tsp,
                fontWeight: FontWeight.w700,
                color: ApprovalsOverviewTheme.textDark,
                height: 1.2,
              ),
            ),
          ),
          SizedBox(width: 8.tw),
          _buildCompletionDonut(completionPercent, compact: true),
        ],
      ),
    );
  }

  Widget _invoiceInfoCard({
    required String workOrderNo,
    required String requestDate,
    required String vendorName,
    required List<String> tags,
  }) {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            title: 'Invoice Info',
            icon: Icons.description_outlined,
          ),
          SizedBox(height: 14.th),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _infoField(label: 'W.O No#', value: workOrderNo),
              ),
              SizedBox(width: 16.tw),
              Expanded(
                child: _infoField(
                  label: 'Request Date',
                  value: requestDate,
                  leadingIcon: Icons.calendar_today_rounded,
                  iconColor: const Color(0xFF2F80ED),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.th),
          _infoField(
            label: 'Vendor',
            value: vendorName,
            valueColor: ApprovalsOverviewTheme.invoice,
            maxLines: 3,
          ),
          if (tags.isNotEmpty) ...[
            SizedBox(height: 12.th),
            SizedBox(
              height: 32.th,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: tags.length,
                separatorBuilder: (_, __) => SizedBox(width: 8.tw),
                itemBuilder: (_, index) => _categoryPill(tags[index]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _financialDetailsCard({
    required String contractLpo,
    required String advance,
    required String progress,
    required String lastUpdate,
    required String retention,
    required String invoiceAmount,
    VoidCallback? onOpenDoc,
  }) {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            title: 'Financial Details',
            icon: Icons.description_outlined,
          ),
          SizedBox(height: 12.th),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(12.tw, 10.th, 8.tw, 10.th),
            decoration: BoxDecoration(
              color: ApprovalsOverviewTheme.screenTintLight.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14.tr),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _infoField(
                    label: 'Contract / LPO',
                    value: contractLpo,
                    maxLines: 2,
                  ),
                ),
                SizedBox(width: 8.tw),
                _docIconButton(onTap: onOpenDoc),
              ],
            ),
          ),
          SizedBox(height: 10.th),
          Row(
            children: [
              Expanded(
                child: _financeMetricTile(
                  label: 'Advance',
                  value: advance,
                  icon: Icons.account_balance_wallet_outlined,
                  accent: const Color(0xFF2F80ED),
                ),
              ),
              SizedBox(width: 8.tw),
              Expanded(
                child: _financeMetricTile(
                  label: 'Progress',
                  value: progress,
                  icon: Icons.pie_chart_outline_rounded,
                  accent: const Color(0xFF2E9B6C),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.th),
          Row(
            children: [
              Expanded(
                child: _financeMetricTile(
                  label: 'Last Update',
                  value: lastUpdate,
                  icon: Icons.calendar_month_rounded,
                  accent: const Color(0xFFE08A00),
                ),
              ),
              SizedBox(width: 8.tw),
              Expanded(
                child: _financeMetricTile(
                  label: 'Retention',
                  value: retention,
                  icon: Icons.verified_user_outlined,
                  accent: const Color(0xFF6B4EFF),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.th),
          _invoiceAmountBar(amount: invoiceAmount, onTapDoc: onOpenDoc),
        ],
      ),
    );
  }

  Widget _floatingApprovalBar(String userId) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.tr),
        boxShadow: [
          BoxShadow(
            color: ApprovalsOverviewTheme.screenDeep.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: OverviewGlassPanel(
        fillAlpha: 0.78,
        blurSigma: 14,
        radius: 20,
        padding: EdgeInsets.symmetric(horizontal: 8.tw, vertical: 6.th),
        child: ApprovalActionButtons(
          requestId: widget.requestId,
          type: widget.type,
          userIds: [userId],
          variant: ApprovalActionButtonsVariant.glass,
          showHrApproveConfirmation: true,
          enableFakeApproveDemo: _isLocalFakeRequest,
        ),
      ),
    );
  }

  Widget _buildAvatar({required String imageUrl, required String name}) {
    return ApprovalDisplayHelpers.buildCircleAvatar(
      imageData: imageUrl,
      size: 58.tw,
      initials: name,
    );
  }

  Widget _buildCompletionDonut(double percent, {bool compact = false}) {
    final p = percent.clamp(0, 100).toDouble();
    final outer = compact ? 58.tw : 74.tw;
    final inner = compact ? 48.tw : 64.tw;
    return SizedBox(
      width: outer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: outer,
            height: outer,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: inner,
                  height: inner,
                  child: CustomPaint(
                    painter: _PiePercentPainter(
                      percent: p,
                      fillColor: ApprovalsOverviewTheme.invoice,
                      baseColor: ApprovalsOverviewTheme.screenTintMid,
                    ),
                  ),
                ),
                Text(
                  '${p.round()}%',
                  style: GoogleFonts.poppins(
                    fontSize: compact ? 12.tsp : 15.tsp,
                    fontWeight: FontWeight.w800,
                    color: ApprovalsOverviewTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 2.th),
          Text(
            'Progress',
            style: GoogleFonts.poppins(
              fontSize: 9.tsp,
              fontWeight: FontWeight.w600,
              color: ApprovalsOverviewTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requestNo = _pick([
      _formData['inv_no'],
      _formData['invoice_no'],
      _formData['invoice_no_code'],
      _formData['request_no'],
      _formData['title'],
      _formData['name'],
      _formData['ref_no'],
    ], fallback: widget.requestId);

    final projectName = _pick([
      _formData['project_name'],
      _formData['project_title'],
      _formData['project'] is Map
          ? (_formData['project'] as Map)['name']
          : _formData['project'],
      _formData['project_name_id'],
      _formData['name'],
    ]);

    final requestDate = _formatDate(_pick([
      _formData['request_date'],
      _formData['create_date'],
      _formData['req_date'],
      _formData['invoice_date'],
      _formData['date_of_invoice'],
      _formData['date'],
    ]));

    final projectMap = _formData['project'] is Map
        ? Map<String, dynamic>.from(_formData['project'] as Map)
        : null;
    final workOrderNo = _pick([
      projectMap?['wo_ref_no'],
      _formData['wo_ref_no'],
      _formData['wo_ref_number'],
      _formData['work_order_no'],
      _formData['work_order_number'],
      _formData['work_order'],
      _formData['wo_order_no'],
      _formData['wo_order_number'],
      _formData['wo_name'],
      _formData['wo'],
      _formData['wo_no'],
      _formData['wono'],
      _formData['wo_no#'],
    ]);

    final vendorName = _pick([
      _formData['vendor_name'],
      _formData['vendor'],
      _formData['partner_name'],
      _formData['client_name'],
      _formData['supplier'],
    ]);

    final invoiceAmount = _formatAmount(_pick([
      _formData['invoice_amount'],
      _formData['total_amount'],
      _formData['amount_total'],
      _formData['amount'],
      _formData['total'],
    ]));

    final completionRaw = _pick([
      _formData['completion'],
      _formData['completion_percentage'],
      _formData['completion_percent'],
    ], fallback: '0');
    final completionPercent = _parsePercent(completionRaw);

    final advance = _formatAmount(_pick([_formData['advance']], fallback: '-'));
    final progress = _formatAmount(_pick([_formData['progress']], fallback: '-'));
    final lastUpdate = _formatDate(_pick([_formData['last_update']], fallback: '-'));
    final retention = _displayOrDash(_pick([_formData['retention']], fallback: '-'));

    final contractLpo = _pick([
      _formData['lpo_name'],
      _formData['contract_lpo'],
      _formData['lpo_no'],
      _formData['lpo'],
      _formData['lpo_number'],
      _formData['contract'],
      _formData['contract_no'],
    ], fallback: '-');

    final vendorPhotoUrl = ApprovalDisplayHelpers.normalizeImageUrl(
      ApprovalDisplayHelpers.pickImageUrl(_formData, ApprovalAvatarKind.vendor),
    );

    final tags = _extractTags([
      _formData['vendor_tag'],
      _formData['vendor_tags'],
      _formData['tags'],
      _formData['tag_names'],
      _formData['material_type'],
      _formData['category'],
    ]).take(8).toList();

    final canViewLpo = _parsePositiveInt(_formData['lpo_id']) != null ||
        _parsePositiveInt(_formData['purchase_order_id']) != null ||
        _parsePositiveInt(_formData['po_id']) != null;
    final openDoc =
        canViewLpo ? () => _viewLpoReport(lpoName: contractLpo) : null;

    final userId =
        SharedPref.getLoginData().result?.data?.uid?.toString() ?? '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ApprovalsOverviewTheme.overlay,
      child: Scaffold(
        backgroundColor: ApprovalsOverviewTheme.screenBase,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: ApprovalsOverviewTheme.screenGradient,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ContextualGlassChromeHeader(
                  title: requestNo.isNotEmpty ? requestNo : 'Invoice',
                  showBack: true,
                  onLightSurface: true,
                  transparentGlassBar: false,
                  scrimTopOpacity: 0,
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _error.isNotEmpty
                          ? Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.tw),
                                child: Text(
                                  _error,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.tsp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : Stack(
                              children: [
                                SingleChildScrollView(
                                  physics: const ClampingScrollPhysics(),
                                  padding: EdgeInsets.fromLTRB(
                                    16.tw,
                                    4.th,
                                    16.tw,
                                    78.th + context.systemBottomInset,
                                  ),
                                  child: Column(
                                    children: [
                                      _invoiceRequestHeader(
                                        imageUrl: vendorPhotoUrl,
                                        projectName: projectName,
                                        completionPercent: completionPercent,
                                      ),
                                      SizedBox(height: 10.th),
                                      _invoiceInfoCard(
                                        workOrderNo: workOrderNo,
                                        requestDate: requestDate,
                                        vendorName: vendorName,
                                        tags: tags,
                                      ),
                                      SizedBox(height: 10.th),
                                      _financialDetailsCard(
                                        contractLpo: contractLpo,
                                        advance: advance,
                                        progress: progress,
                                        lastUpdate: lastUpdate,
                                        retention: retention,
                                        invoiceAmount: invoiceAmount,
                                        onOpenDoc: openDoc,
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  left: 16.tw,
                                  right: 16.tw,
                                  bottom: context.systemBottomInset + 8.th,
                                  child: _floatingApprovalBar(userId),
                                ),
                              ],
                            ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PiePercentPainter extends CustomPainter {
  final double percent;
  final Color fillColor;
  final Color baseColor;

  const _PiePercentPainter({
    required this.percent,
    required this.fillColor,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(size.width, size.height) / 2;

    final basePaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, basePaint);

    if (percent <= 0) return;

    final sweep = 2 * math.pi * (percent.clamp(0, 100) / 100);
    final arcPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawArc(rect, -math.pi / 2, sweep, true, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _PiePercentPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.baseColor != baseColor;
  }
}
