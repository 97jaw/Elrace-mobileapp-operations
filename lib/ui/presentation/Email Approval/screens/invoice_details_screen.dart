import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/Email%20Approval/theme/approvals_overview_theme.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/approval_display_helpers.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/approval_action_buttons.dart';
import 'package:el_race/ui/presentation/lpo/screens/lpo_pdf_viewer_screen.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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

  Future<void> _viewAttachment() async {
    final invoiceId = int.tryParse(widget.requestId);
    if (invoiceId == null || invoiceId <= 0) {
      Fluttertoast.showToast(
        msg: 'Invalid invoice id.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.black,
        textColor: Colors.white,
      );
      return;
    }

    final token = SharedPref.getLoginData().result?.token;
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final data = {
      'jsonrpc': '2.0',
      'params': {
        'invoice_id': invoiceId,
      },
    };

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await http.post(
        Uri.parse('https://erp.elrace.com/api/invoice/report_url'),
        headers: headers,
        body: jsonEncode(data),
      );

      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (response.statusCode != 200) {
        Fluttertoast.showToast(
          msg: 'Failed to load PDF: HTTP ${response.statusCode}',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.black,
          textColor: Colors.white,
        );
        return;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final result = decoded['result'] as Map?;
      final pdfUrl = result?['report_url']?.toString() ?? '';

      if (pdfUrl.isEmpty) {
        final error = decoded['error'] as Map?;
        final errorData = error?['data'] as Map?;
        Fluttertoast.showToast(
          msg: result?['message']?.toString() ??
              result?['error']?.toString() ??
              errorData?['message']?.toString() ??
              error?['message']?.toString() ??
              'Failed to retrieve PDF URL.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.black,
          textColor: Colors.white,
        );
        return;
      }

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LpoPdfViewerScreen(
            pdfUrl: pdfUrl,
            title: 'Invoice ${_pick([
                  _formData['request_no'],
                  _formData['invoice_no_code'],
                  _formData['invoice_no'],
                  _formData['name'],
                ], fallback: widget.requestId)}',
          ),
        ),
      );
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      Fluttertoast.showToast(
        msg: 'Error: $e',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.black,
        textColor: Colors.white,
      );
    }
  }

  Widget _tagChip(String text, Color bg, Color fg) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.w),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 9.sp,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _glassSectionCard({required String title, required Widget child}) {
    return OverviewGlassPanel(
      fillAlpha: 0.9,
      blurSigma: 8,
      radius: 16,
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: ApprovalsOverviewTheme.screenDeep,
            ),
          ),
          SizedBox(height: 6.h),
          child,
        ],
      ),
    );
  }

  Widget _themeDetailCell(String label, String value,
      {bool highlight = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: ApprovalsOverviewTheme.screenTintLight.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 9.sp,
              fontWeight: FontWeight.w500,
              color: ApprovalsOverviewTheme.textSoft,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            _displayOrDash(value),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: highlight
                  ? ApprovalsOverviewTheme.invoice
                  : ApprovalsOverviewTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _invoiceRequestHeader({
    required String imageUrl,
    required String projectName,
    required String department,
    required String requestNo,
    required double completionPercent,
  }) {
    return OverviewGlassPanel(
      fillAlpha: 0.88,
      blurSigma: 10,
      radius: 16,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 62.w,
            height: 62.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: ApprovalsOverviewTheme.invoice.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(
              child: _buildAvatar(imageUrl: imageUrl, name: projectName),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _displayOrDash(projectName),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: ApprovalsOverviewTheme.textDark,
                    height: 1.2,
                  ),
                ),
                if (department.trim().isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    department,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      color: ApprovalsOverviewTheme.textMuted,
                    ),
                  ),
                ],
                SizedBox(height: 6.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: ApprovalsOverviewTheme.screenTintMid
                        .withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Text(
                    _displayOrDash(requestNo),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: ApprovalsOverviewTheme.textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 6.w),
          _buildCompletionDonut(completionPercent, compact: true),
        ],
      ),
    );
  }

  Widget _buildSimCommentCard(String comment) {
    return OverviewGlassPanel(
      fillAlpha: 0.9,
      blurSigma: 8,
      radius: 16,
      padding: EdgeInsets.fromLTRB(10.w, 8.h, 10.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'COMMENT',
                style: GoogleFonts.poppins(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: ApprovalsOverviewTheme.screenDeep,
                ),
              ),
              const Spacer(),
              Text(
                '${comment.characters.length}/50',
                style: GoogleFonts.poppins(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w500,
                  color: ApprovalsOverviewTheme.textSoft,
                ),
              ),
            ],
          ),
          SizedBox(height: 5.h),
          Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: 36.h),
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
            decoration: BoxDecoration(
              color:
                  ApprovalsOverviewTheme.screenTintLight.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
            ),
            child: Text(
              comment.trim().isEmpty ? 'No comment' : comment,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight:
                    comment.trim().isEmpty ? FontWeight.w400 : FontWeight.w500,
                color: comment.trim().isEmpty
                    ? ApprovalsOverviewTheme.textSoft
                    : ApprovalsOverviewTheme.textDark,
                fontStyle: comment.trim().isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _floatingApprovalBar(String userId) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
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
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
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
      size: 62.w,
      initials: name,
    );
  }

  Widget _buildMetricRow({
    required String label,
    required String value,
    String? percentBadge,
    bool valueHighlighted = false,
  }) {
    final badgeText = _safe(percentBadge, fallback: '');

    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _themeDetailCell(
              label,
              value,
              highlight: valueHighlighted ||
                  label == 'Invoice Amount' ||
                  label == 'Vendor',
            ),
          ),
          if (badgeText.isNotEmpty && badgeText != '-') ...[
            SizedBox(width: 6.w),
            _buildMiniPercentBadge(badgeText),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniPercentBadge(String badgeText) {
    final parsed = _parsePercent(badgeText);
    final text = parsed > 0 ? '${parsed.round()}%' : _displayOrDash(badgeText);

    return Container(
      width: 26.w,
      height: 26.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF4F4F4), Color(0xFFD1D1D1)],
        ),
        border: Border.all(color: const Color(0xFFCBCBCB), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 2.5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 8.5.sp,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF151515),
          height: 1,
        ),
      ),
    );
  }

  Widget _buildCompletionDonut(double percent, {bool compact = false}) {
    final p = percent.clamp(0, 100).toDouble();
    final outer = compact ? 54.w : 74.w;
    final inner = compact ? 46.w : 64.w;
    return SizedBox(
      width: outer,
      height: outer,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: inner,
            height: inner,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: ApprovalsOverviewTheme.invoice.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
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
              fontSize: compact ? 11.sp : 15.sp,
              fontWeight: FontWeight.w800,
              color: ApprovalsOverviewTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requestNo = _pick([
      _formData['request_no'],
      _formData['invoice_no_code'],
      _formData['invoice_no'],
      _formData['name'],
      _formData['ref_no'],
    ], fallback: widget.requestId);

    final projectName = _pick([
      _formData['project_name'],
      _formData['project_title'],
      _formData['project'],
      _formData['project_name_id'],
      _formData['name'],
    ]);

    final department = _pick([
      _pick([
        (_formData['department_id'] is Map)
            ? (_formData['department_id'] as Map)['name']
            : null
      ]),
      _formData['department'],
      _formData['section'],
      _formData['dept_name'],
    ]);

    final requestDate = _formatDate(_pick([
      _formData['request_date'],
      _formData['create_date'],
      _formData['req_date'],
      _formData['invoice_date'],
      _formData['date_of_invoice'],
      _formData['date'],
    ]));

    final workOrderNo = _pick([
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

    final advance = _pick([_formData['advance']], fallback: '-');
    final progress = _pick([_formData['progress']], fallback: '-');
    final lastUpdate = _pick([_formData['last_update']], fallback: '-');
    final retention = _pick([_formData['retention']], fallback: '-');

    final advancePct = _pick([
      _formData['advance_percentage'],
      _formData['advance_percent'],
    ], fallback: '-');
    final progressPct = _pick([
      _formData['progress_percentage'],
      _formData['progress_percent'],
    ], fallback: '-');
    final lastUpdatePct = _pick([
      _formData['last_update_percentage'],
      _formData['last_update_percent'],
    ], fallback: '-');
    final retentionPct = _pick([
      _formData['retention_percentage'],
      _formData['retention_percent'],
    ], fallback: '-');

    final contractLpo = _pick([
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
    ]).take(4).toList();

    final comment = _pick([
      _formData['comment'],
      _formData['note'],
      _formData['description'],
    ]);

    final canViewReport = int.tryParse(widget.requestId) != null;

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
                const ContextualGlassChromeHeader(
                  title: 'Invoice',
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
                                padding: EdgeInsets.all(16.w),
                                child: Text(
                                  _error,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : Stack(
                              children: [
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(
                                          16.w, 4.h, 16.w, 0),
                                      child: _invoiceRequestHeader(
                                        imageUrl: vendorPhotoUrl,
                                        projectName: projectName,
                                        department: department,
                                        requestNo: requestNo,
                                        completionPercent: completionPercent,
                                      ),
                                    ),
                                    SizedBox(height: 6.h),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        physics: const ClampingScrollPhysics(),
                                        padding: EdgeInsets.fromLTRB(
                                          16.w,
                                          0,
                                          16.w,
                                          68.h + context.systemBottomInset,
                                        ),
                                        child: Column(
                                          children: [
                                            _glassSectionCard(
                                              title: 'Invoice Info',
                                              child: LayoutBuilder(
                                                builder:
                                                    (context, constraints) {
                                                  final cellW =
                                                      (constraints.maxWidth -
                                                              6.w) /
                                                          2;
                                                  return Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Wrap(
                                                        spacing: 6.w,
                                                        runSpacing: 6.h,
                                                        children: [
                                                          SizedBox(
                                                            width: cellW,
                                                            child:
                                                                _themeDetailCell(
                                                              'W.O No#',
                                                              workOrderNo,
                                                            ),
                                                          ),
                                                          SizedBox(
                                                            width: cellW,
                                                            child:
                                                                _themeDetailCell(
                                                              'Request Date',
                                                              requestDate,
                                                            ),
                                                          ),
                                                          SizedBox(
                                                            width: constraints
                                                                .maxWidth,
                                                            child:
                                                                _themeDetailCell(
                                                              'Vendor',
                                                              vendorName,
                                                              highlight: true,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (tags.isNotEmpty) ...[
                                                        SizedBox(height: 6.h),
                                                        Wrap(
                                                          spacing: 6.w,
                                                          runSpacing: 4.h,
                                                          children: [
                                                            for (int i = 0;
                                                                i < tags.length;
                                                                i++)
                                                              _tagChip(
                                                                tags[i],
                                                                [
                                                                  const Color(
                                                                      0xFFE1E4FF),
                                                                  const Color(
                                                                      0xFFFCE6E6),
                                                                  const Color(
                                                                      0xFFFFF1D8),
                                                                  const Color(
                                                                      0xFFE1F5EC),
                                                                ][i % 4],
                                                                [
                                                                  const Color(
                                                                      0xFF3F51E8),
                                                                  const Color(
                                                                      0xFFD32F2F),
                                                                  const Color(
                                                                      0xFFE08A00),
                                                                  const Color(
                                                                      0xFF00A05A),
                                                                ][i % 4],
                                                              ),
                                                          ],
                                                        ),
                                                      ],
                                                    ],
                                                  );
                                                },
                                              ),
                                            ),
                                            SizedBox(height: 6.h),
                                            _glassSectionCard(
                                              title: 'Financial Details',
                                              child: Column(
                                                children: [
                                                  _buildMetricRow(
                                                    label: 'Contract/Lpo',
                                                    value: contractLpo,
                                                    percentBadge: '-',
                                                  ),
                                                  _buildMetricRow(
                                                    label: 'Advance',
                                                    value:
                                                        _formatAmount(advance),
                                                    percentBadge: advancePct,
                                                  ),
                                                  _buildMetricRow(
                                                    label: 'Progress',
                                                    value:
                                                        _formatAmount(progress),
                                                    percentBadge: progressPct,
                                                  ),
                                                  _buildMetricRow(
                                                    label: 'Last update',
                                                    value:
                                                        _formatDate(lastUpdate),
                                                    percentBadge: lastUpdatePct,
                                                  ),
                                                  _buildMetricRow(
                                                    label: 'Retention',
                                                    value: _displayOrDash(
                                                        retention),
                                                    percentBadge: retentionPct,
                                                  ),
                                                  _buildMetricRow(
                                                    label: 'Invoice Amount',
                                                    value: _displayOrDash(
                                                        invoiceAmount),
                                                    percentBadge: '-',
                                                    valueHighlighted: true,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(height: 6.h),
                                            _buildSimCommentCard(comment),
                                            if (canViewReport) ...[
                                              SizedBox(height: 8.h),
                                              Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: _viewAttachment,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          14.r),
                                                  child: Ink(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            vertical: 11.h),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              14.r),
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          ApprovalsOverviewTheme
                                                              .screenMid,
                                                          ApprovalsOverviewTheme
                                                              .screenDeep,
                                                        ],
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .attach_file_rounded,
                                                          color: Colors.white,
                                                          size: 18.sp,
                                                        ),
                                                        SizedBox(width: 6.w),
                                                        Text(
                                                          'View Attachments',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            fontSize: 13.sp,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                            SizedBox(height: 8.h),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Positioned(
                                  left: 16.w,
                                  right: 16.w,
                                  bottom: context.systemBottomInset + 8.h,
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
