import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/Email%20Approval/bloc/approval_bloc.dart';
import 'package:el_race/ui/presentation/Email%20Approval/theme/approvals_overview_theme.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/approval_display_helpers.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/petty_cash_expense_line_groups.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/approval_action_buttons.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/approval_rejected_banner.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/petty_cash_expense_lines_popup.dart';
import 'package:el_race/ui/presentation/my_documents/utils/document_attachment_opener.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class PettyCashDetailsScreen extends StatefulWidget {
  final String requestId;
  final String type;
  final Map<String, dynamic>? initialData;

  const PettyCashDetailsScreen({
    super.key,
    required this.requestId,
    required this.type,
    this.initialData,
  });

  @override
  State<PettyCashDetailsScreen> createState() => _PettyCashDetailsScreenState();
}

class _PettyCashDetailsScreenState extends State<PettyCashDetailsScreen> {
  bool _isLoading = true;
  String _error = '';
  bool _rejectedLocked = false;

  Map<String, dynamic> _formData = const {};
  List<dynamic> _attachmentIds = const [];

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

  String _displayOrNA(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? 'N/A' : normalized;
  }

  String _normalizeApiComment(String value) {
    final v = value.trim();
    if (v.isEmpty) return '';
    final lower = v.toLowerCase();
    if (lower == 'no comments' ||
        lower == 'no comment' ||
        lower == 'n/a' ||
        lower == 'na' ||
        lower == '-' ||
        lower == '--') {
      return '';
    }
    return v;
  }

  String _formatAmount(dynamic value) {
    final raw = _safe(value);
    if (raw.trim().isEmpty) return '0 AED';
    return ApprovalDisplayHelpers.formatAmountWithAed(raw, fallback: '0');
  }

  String _formatDate(dynamic value) {
    final raw = _safe(value);
    if (raw.trim().isEmpty) return 'N/A';
    final normalized = raw.contains(' ') ? raw.replaceFirst(' ', 'T') : raw;
    final parsed = DateTime.tryParse(normalized) ?? DateTime.tryParse(raw);
    if (parsed == null) return _displayOrNA(raw);
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  bool _isInvalidImageValue(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'false' || normalized == 'null') {
      return true;
    }

    if (normalized.endsWith('/false') ||
        normalized.contains('/image/false') ||
        normalized.contains('employee/image/false')) {
      return true;
    }

    return false;
  }

  String _pickImage(List<dynamic> values) {
    for (final value in values) {
      final candidate = _safe(value);
      if (candidate.isEmpty) continue;
      if (_isInvalidImageValue(candidate)) continue;
      return candidate;
    }
    return '';
  }

  String _normalizeImageUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || _isInvalidImageValue(trimmed)) return '';

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    if (trimmed.startsWith('/')) {
      return 'https://erp.elrace.com$trimmed';
    }

    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return 'https://erp.elrace.com/public/employee/image/$trimmed';
    }

    if (trimmed.startsWith('public/') || trimmed.startsWith('employee/')) {
      return 'https://erp.elrace.com/$trimmed';
    }

    return trimmed;
  }

  Widget _buildAvatar(String imageData, {required double iconSize}) {
    final trimmed = imageData.trim();
    if (trimmed.isEmpty) {
      return Icon(
        Icons.person,
        color: const Color(0xFF6B6B6B),
        size: iconSize,
      );
    }

    final normalizedUrl = _normalizeImageUrl(trimmed);
    final isUrl = normalizedUrl.startsWith('http://') ||
        normalizedUrl.startsWith('https://');
    if (isUrl) {
      final token = SharedPref.getLoginData().result?.token;
      final headers = <String, String>{
        'Accept': 'image/*,*/*;q=0.8',
      };
      if (_safe(token).isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      return Image.network(
        normalizedUrl,
        fit: BoxFit.cover,
        headers: headers,
        errorBuilder: (_, __, ___) => Icon(
          Icons.person,
          color: const Color(0xFF6B6B6B),
          size: iconSize,
        ),
      );
    }

    try {
      String base64String = trimmed;
      if (trimmed.contains('base64,')) {
        base64String = trimmed.split('base64,')[1];
      }
      final bytes = base64Decode(base64String);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          Icons.person,
          color: const Color(0xFF6B6B6B),
          size: iconSize,
        ),
      );
    } catch (_) {
      return Icon(
        Icons.person,
        color: const Color(0xFF6B6B6B),
        size: iconSize,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _formData = Map<String, dynamic>.from(widget.initialData!);
      final maybeAttachments = _formData['attachment_ids'];
      if (maybeAttachments is List) {
        _attachmentIds = maybeAttachments;
      }
    }
    _fetchPettyCashDetails();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchPettyCashDetails() async {
    final token = SharedPref.getLoginData().result?.token;
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final url = Uri.parse('https://erp.elrace.com/api/get_petty_cash_details');
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'params': {
        'petty_cash_id': int.tryParse(widget.requestId),
      },
    });

    print('══════════ [PETTYCASH] API REQUEST ══════════');
    print('[PETTYCASH] URL: $url');
    print('[PETTYCASH] METHOD: GET');
    print(
        '[PETTYCASH] HEADERS: ${headers.map((k, v) => MapEntry(k, k == "Authorization" ? "Bearer ***" : v))}');
    print('[PETTYCASH] BODY: $body');
    print('═════════════════════════════════════════════');

    try {
      final request = http.Request('GET', url)
        ..headers.addAll(headers)
        ..body = body;

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      print('══════════ [PETTYCASH] API RESPONSE ══════════');
      print('[PETTYCASH] STATUS: ${response.statusCode}');
      print('[PETTYCASH] BODY: ${response.body}');
      print('══════════════════════════════════════════════');

      final data = jsonDecode(response.body);

      if (data['result'] != null) {
        final result = data['result'] as Map;
        final rawFormData = result['data'] as Map? ?? {};
        final formData = _normalizePettyCashFormData(
          Map<String, dynamic>.from(rawFormData),
        );
        final attachmentList = result['attachment_ids'] as List? ??
            (formData['attachment_ids'] as List? ?? []);

        _logApiCompatibilityIssues(formData);

        print('[PETTYCASH] PARSED formData keys: ${formData.keys.toList()}');
        print('[PETTYCASH] PARSED formData: $formData');
        print('[PETTYCASH] PARSED attachmentIds: $attachmentList');
        print('[PETTYCASH] COMMENT CANDIDATES: ${jsonEncode({
              'api_comment': formData['api_comment'],
              'comment': formData['comment'],
              'comments': formData['comments'],
              'note': formData['note'],
              'notes': formData['notes'],
              'remark': formData['remark'],
              'remarks': formData['remarks'],
              'description': formData['description'],
              'manager_comment': formData['manager_comment'],
              'approver_comment': formData['approver_comment'],
              'reviewer_comment': formData['reviewer_comment'],
              'request_comment': formData['request_comment'],
              'employee_comment': formData['employee_comment'],
            })}');

        setState(() {
          final merged = Map<String, dynamic>.from(_formData);
          merged.addAll(Map<String, dynamic>.from(formData));
          _formData = merged;
          _attachmentIds = attachmentList;
          _isLoading = false;
        });
      } else {
        print(
            '[PETTYCASH] ERROR: result is null. Full response: ${response.body}');
        setState(() {
          _isLoading = false;
          if (_formData.isEmpty) {
            _error = 'Failed to load Petty Cash details';
          }
        });
      }
    } catch (e) {
      print('══════════ [PETTYCASH] API ERROR ══════════');
      print('[PETTYCASH] EXCEPTION: $e');
      print('═══════════════════════════════════════════');
      setState(() {
        _isLoading = false;
        if (_formData.isEmpty) {
          _error = e.toString();
        }
      });
    }
  }

  Map<String, dynamic> _normalizePettyCashFormData(
    Map<String, dynamic> raw,
  ) {
    final normalized = Map<String, dynamic>.from(raw);

    final formViewRaw = raw['form_view'];
    if (formViewRaw is Map) {
      normalized.addAll(Map<String, dynamic>.from(formViewRaw));
    }

    final tableViewRaw = raw['table_view'];
    if (tableViewRaw is List) {
      normalized['lines'] = tableViewRaw
          .whereType<Map>()
          .map((line) =>
              _normalizePettyCashLine(Map<String, dynamic>.from(line)))
          .toList();
    } else if (normalized['lines'] is List) {
      final lines = normalized['lines'] as List;
      normalized['lines'] = lines
          .whereType<Map>()
          .map((line) =>
              _normalizePettyCashLine(Map<String, dynamic>.from(line)))
          .toList();
    }

    normalized['request_no'] = _pick([
      normalized['request_no'],
      normalized['pettycash_no'],
      normalized['petty_cash_no'],
      normalized['name'],
      normalized['ref_no'],
    ]);

    normalized['pettycash_holder'] = _pick([
      normalized['pettycash_holder'],
      normalized['holder_name'],
      normalized['holder'],
    ]);

    final holderRaw =
        raw['pettycash_holder'] ?? raw['holder'] ?? raw['holder_name'];
    if (holderRaw is Map) {
      final holderMap = Map<String, dynamic>.from(holderRaw);
      normalized['holder_name'] = _pick([
        holderMap['name'],
        holderMap['holder_name'],
        holderMap['employee_name'],
        holderMap['emp_name'],
        normalized['holder_name'],
        normalized['pettycash_holder'],
      ]);
      normalized['holder_image'] = _pick([
        holderMap['holder_image_url'],
        holderMap['emp_image_url'],
        holderMap['image_emp'],
        holderMap['employee_image'],
        holderMap['image'],
        holderMap['avatar'],
        holderMap['photo'],
        holderMap['id'],
        normalized['holder_image'],
      ]);
      normalized['pettycash_holder'] = _pick([
        normalized['holder_name'],
        normalized['pettycash_holder'],
      ]);
    }

    normalized['requester_name'] = _pick([
      normalized['requester_name'],
      normalized['requester'],
      normalized['emp_name'],
      normalized['employee_name'],
      normalized['employee'],
    ]);

    normalized['pettycash_limit'] = _pick([
      normalized['pettycash_limit'],
      normalized['limit'],
      normalized['limit_amount'],
      normalized['amount'],
      normalized['total_amount'],
    ]);

    normalized['total'] = _pick([
      normalized['total'],
      normalized['total_amount'],
      normalized['amount_total'],
      normalized['amount'],
    ]);

    // Keep a unified, API-driven comment field for UI + approve/reject payload.
    normalized['api_comment'] = _normalizeApiComment(_pick([
      normalized['api_comment'],
      normalized['comment'],
      normalized['comments'],
      normalized['note'],
      normalized['notes'],
      normalized['remark'],
      normalized['remarks'],
      normalized['description'],
      normalized['manager_comment'],
      normalized['approver_comment'],
      normalized['reviewer_comment'],
      normalized['request_comment'],
      normalized['employee_comment'],
    ]));

    return normalized;
  }

  Map<String, dynamic> _normalizePettyCashLine(Map<String, dynamic> line) {
    final normalizedLine = Map<String, dynamic>.from(line);

    normalizedLine['description'] = _pick([
      normalizedLine['description'],
      normalizedLine['name'],
      normalizedLine['remarks'],
      normalizedLine['project_name'],
      normalizedLine['project'],
    ]);

    normalizedLine['project_name'] = _pick([
      normalizedLine['project_name'],
      normalizedLine['project'],
    ]);

    normalizedLine['expense_type_label'] = _pick([
      normalizedLine['expense_type_label'],
      normalizedLine['expense_type'],
      normalizedLine['x_expense_type'],
    ]);

    normalizedLine['amount'] = _pick([
      normalizedLine['amount'],
      normalizedLine['price'],
      normalizedLine['subtotal'],
      normalizedLine['unit_price'],
    ]);

    normalizedLine['date'] = _pick([
      normalizedLine['invoice_date'],
      normalizedLine['submitted_date'],
      normalizedLine['date'],
      normalizedLine['expense_date'],
      normalizedLine['line_date'],
      normalizedLine['create_date'],
    ]);

    return normalizedLine;
  }

  void _logApiCompatibilityIssues(Map<String, dynamic> formData) {
    final requiredAny = <String, List<String>>{
      'requestNo': [
        'request_no',
        'pettycash_no',
        'petty_cash_no',
        'name',
        'ref_no'
      ],
      'pettycashLimit': ['pettycash_limit', 'limit', 'limit_amount', 'amount'],
      'pettycashHolder': ['pettycash_holder', 'holder_name', 'holder'],
      'requester': [
        'requester_name',
        'requester',
        'emp_name',
        'employee_name',
        'employee'
      ],
      'total': ['total', 'total_amount', 'amount_total', 'amount'],
    };

    for (final entry in requiredAny.entries) {
      final hasValue = entry.value.any((k) {
        final v = formData[k];
        final s = _safe(v);
        return s.isNotEmpty;
      });
      if (!hasValue) {
        debugPrint(
          '⚠️ [PETTYCASH][API_COMPAT] Missing ${entry.key}. Expected one of: ${entry.value.join(', ')}',
        );
      }
    }

    final lines = formData['lines'];
    if (lines != null && lines is List && lines.isNotEmpty) {
      final firstLine = lines.first;
      if (firstLine is Map) {
        final lineMap = Map<String, dynamic>.from(firstLine);
        final hasDescription = _safe(lineMap['description']).isNotEmpty ||
            _safe(lineMap['name']).isNotEmpty;
        final hasAmount = _safe(lineMap['amount']).isNotEmpty ||
            _safe(lineMap['price']).isNotEmpty ||
            _safe(lineMap['subtotal']).isNotEmpty;
        if (!hasDescription) {
          debugPrint(
            '⚠️ [PETTYCASH][API_COMPAT] Line item description missing. Expected: description or name',
          );
        }
        if (!hasAmount) {
          debugPrint(
            '⚠️ [PETTYCASH][API_COMPAT] Line item amount missing. Expected: amount or price or subtotal',
          );
        }
      }
    }
  }

  /// Extracts a plain integer attachment ID from whatever shape the item is.
  int? _extractAttachmentId(dynamic item) {
    if (item is int) return item;
    if (item is Map) {
      final raw = item['attachment_id'] ?? item['id'] ?? item['attachmentId'];
      if (raw is int) return raw;
      return int.tryParse(raw?.toString() ?? '');
    }
    return int.tryParse(item?.toString() ?? '');
  }

  /// Tries to extract a human-readable filename from an attachment item.
  String _extractAttachmentHintName(dynamic item, {int fallbackIndex = 0}) {
    if (item is Map) {
      for (final key in ['name', 'attachment_name', 'filename', 'file_name']) {
        final v = item[key]?.toString().trim() ?? '';
        if (v.isNotEmpty &&
            v.toLowerCase() != 'false' &&
            v.toLowerCase() != 'null' &&
            v.toLowerCase() != 'attachment_id') {
          return v;
        }
      }
    }
    // Fall back to petty cash request name + index
    final reqName = _safe(_formData['name']);
    if (reqName.isNotEmpty) {
      return '$reqName${fallbackIndex > 0 ? ' (${fallbackIndex + 1})' : ''}';
    }
    return 'Attachment${fallbackIndex > 0 ? ' ${fallbackIndex + 1}' : ''}';
  }

  Future<void> _openSingleAttachment(int attachmentId,
      {String hintName = ''}) async {
    if (!mounted) return;
    // API often returns has_binary:false + public_url only — open via
    // /web/content byte loader (SfPdfViewer.network on public_url is blank).
    final fallbackName = hintName.isNotEmpty
        ? hintName
        : _safe(_formData['name'], fallback: 'Petty Cash Attachment');
    try {
      await DocumentAttachmentOpener.openById(
        context,
        attachmentId: attachmentId,
        hintName: fallbackName,
      );
    } catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(
        msg: e.toString(),
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.black,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _viewAttachment() async {
    if (_attachmentIds.isEmpty) return;

    // Collect valid integer IDs
    // Build (id, hintName) pairs
    final items = _attachmentIds
        .asMap()
        .entries
        .map((e) {
          final id = _extractAttachmentId(e.value);
          if (id == null) return null;
          final name =
              _extractAttachmentHintName(e.value, fallbackIndex: e.key);
          return (id: id, name: name);
        })
        .whereType<({int id, String name})>()
        .toList();

    if (items.isEmpty) {
      Fluttertoast.showToast(
        msg: 'No valid attachment IDs found.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.black,
        textColor: Colors.white,
      );
      return;
    }

    // If only one attachment, open directly
    if (items.length == 1) {
      await _openSingleAttachment(items.first.id, hintName: items.first.name);
      return;
    }

    // Multiple attachments — let user pick
    if (!mounted) return;
    final picked = await showModalBottomSheet<({int id, String name})>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.tr)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.tw, 14.tw, 16.tw, 4.tw),
              child: Text(
                'Select Attachment',
                style: GoogleFonts.poppins(
                  fontSize: 14.tsp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Divider(),
            ...items.map((item) => ListTile(
                  leading: const Icon(Icons.picture_as_pdf_rounded),
                  title: Text(
                    item.name,
                    style: GoogleFonts.poppins(fontSize: 13.tsp),
                  ),
                  onTap: () => Navigator.of(ctx).pop(item),
                )),
            SizedBox(height: 8.tw),
          ],
        ),
      ),
    );

    if (picked != null) {
      await _openSingleAttachment(picked.id, hintName: picked.name);
    }
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return OverviewGlassPanel(
      fillAlpha: 0.9,
      blurSigma: 8,
      radius: 16,
      padding:
          padding ?? EdgeInsets.symmetric(horizontal: 12.tw, vertical: 10.th),
      child: child,
    );
  }

  Widget _glassSectionCard({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return OverviewGlassPanel(
      fillAlpha: 0.9,
      blurSigma: 8,
      radius: 16,
      padding: EdgeInsets.fromLTRB(12.tw, 10.th, 12.tw, 10.th),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 10.tsp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: ApprovalsOverviewTheme.screenDeep,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          SizedBox(height: 6.th),
          child,
        ],
      ),
    );
  }

  Widget _themeDetailCell(String label, String value,
      {bool highlight = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 8.tw, vertical: 6.th),
      decoration: BoxDecoration(
        color: ApprovalsOverviewTheme.screenTintLight.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12.tr),
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
              fontSize: 9.tsp,
              fontWeight: FontWeight.w500,
              color: ApprovalsOverviewTheme.textSoft,
            ),
          ),
          SizedBox(height: 2.th),
          Text(
            _displayOrNA(value),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11.tsp,
              fontWeight: FontWeight.w700,
              color: highlight
                  ? ApprovalsOverviewTheme.petty
                  : ApprovalsOverviewTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaPill(String text, {required Color background}) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6.tw, vertical: 4.th),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16.tr),
        ),
        child: Text(
          _displayOrNA(text),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 9.tsp,
            fontWeight: FontWeight.w700,
            color: ApprovalsOverviewTheme.textDark,
          ),
        ),
      ),
    );
  }

  Widget _totalAmountCell({required String amount}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 12.th),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5EE),
        borderRadius: BorderRadius.circular(12.tr),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              'Total Amount',
              style: GoogleFonts.poppins(
                fontSize: 10.tsp,
                fontWeight: FontWeight.w500,
                color: ApprovalsOverviewTheme.textSoft,
              ),
            ),
          ),
          Text(
            _formatAmount(amount),
            style: GoogleFonts.poppins(
              fontSize: 13.tsp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1B8A4B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pettyCashRequestHeader({
    required String holderImage,
    required String holderName,
    required String requesterName,
    required String submitDate,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFCEE3E0),
        borderRadius: BorderRadius.circular(16.tr),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
      ),
      child: OverviewGlassPanel(
        fillAlpha: 0.72,
        blurSigma: 10,
        radius: 16,
        padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 12.th),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 62.tw,
            height: 62.tw,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: _buildAvatar(holderImage, iconSize: 30.tw),
            ),
          ),
          SizedBox(width: 12.tw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _displayOrNA(holderName),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 16.tsp,
                    fontWeight: FontWeight.w700,
                    color: ApprovalsOverviewTheme.textDark,
                    height: 1.2,
                  ),
                ),
                if (requesterName.trim().isNotEmpty) ...[
                  SizedBox(height: 4.th),
                  Text(
                    'Requested by $requesterName',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12.tsp,
                      fontWeight: FontWeight.w500,
                      color: ApprovalsOverviewTheme.textMuted,
                    ),
                  ),
                ],
                if (submitDate.trim().isNotEmpty) ...[
                  SizedBox(height: 10.th),
                  Text(
                    submitDate,
                    style: GoogleFonts.poppins(
                      fontSize: 13.tsp,
                      fontWeight: FontWeight.w500,
                      color: ApprovalsOverviewTheme.textSoft,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _viewAttachmentsButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _viewAttachment,
        borderRadius: BorderRadius.circular(14.tr),
        child: Ink(
          padding: EdgeInsets.symmetric(vertical: 11.th),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.tr),
            gradient: const LinearGradient(
              colors: [
                ApprovalsOverviewTheme.screenMid,
                ApprovalsOverviewTheme.screenDeep,
              ],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.attach_file_rounded,
                color: Colors.white,
                size: 18.tsp,
              ),
              SizedBox(width: 6.tw),
              Text(
                'View Attachments',
                style: GoogleFonts.poppins(
                  fontSize: 13.tsp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimCommentCard(String comment) {
    return OverviewGlassPanel(
      fillAlpha: 0.9,
      blurSigma: 8,
      radius: 16,
      padding: EdgeInsets.fromLTRB(10.tw, 8.th, 10.tw, 8.th),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'COMMENT',
                style: GoogleFonts.poppins(
                  fontSize: 10.tsp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: ApprovalsOverviewTheme.screenDeep,
                ),
              ),
              const Spacer(),
              Text(
                '${comment.characters.length}/50',
                style: GoogleFonts.poppins(
                  fontSize: 9.tsp,
                  fontWeight: FontWeight.w500,
                  color: ApprovalsOverviewTheme.textSoft,
                ),
              ),
            ],
          ),
          SizedBox(height: 5.th),
          Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: 36.th),
            padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 7.th),
            decoration: BoxDecoration(
              color:
                  ApprovalsOverviewTheme.screenTintLight.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12.tr),
              border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
            ),
            child: Text(
              comment.trim().isEmpty ? 'No comment' : comment,
              style: GoogleFonts.poppins(
                fontSize: 12.tsp,
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

  Widget _floatingApprovalBar(String userId, {required String apiComment}) {
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
          useProvidedComment: true,
          commentProvider: () => apiComment,
          onRejectedLocked: () {
            if (!mounted) return;
            setState(() => _rejectedLocked = true);
          },
        ),
      ),
    );
  }

  Widget _label(String text, {TextAlign? align, double? size}) {
    return Text(
      text,
      textAlign: align,
      style: GoogleFonts.poppins(
        fontSize: size ?? 11.tsp,
        fontWeight: FontWeight.w700,
        color: const Color(0xFFB4B4B4),
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _value(String text,
      {double? size, FontWeight? weight, Color? color, TextAlign? align}) {
    return Text(
      _displayOrNA(text),
      textAlign: align,
      style: GoogleFonts.poppins(
        fontSize: size ?? 14.tsp,
        fontWeight: weight ?? FontWeight.w700,
        color: color ?? const Color(0xFF0E0E0E),
        letterSpacing: 0.1,
      ),
      maxLines: 2,
      overflow: TextOverflow.visible,
    );
  }

  Widget _lineItemTile({
    required String description,
    required String lineDate,
    required String amount,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _value(description, size: 11.tsp, weight: FontWeight.w700),
                  SizedBox(height: 6.tw),
                  _label(_formatDate(lineDate), size: 8.tsp),
                ],
              ),
            ),
            SizedBox(width: 12.tw),
            _value(
              _formatAmount(amount),
              size: 11.tsp,
              weight: FontWeight.w700,
              color: ApprovalsOverviewTheme.petty,
            ),
          ],
        ),
        if (showDivider) ...[
          SizedBox(height: 10.tw),
          const Divider(
            color: Color(0xFFD2D2D2),
            height: 1,
          ),
          SizedBox(height: 10.tw),
        ],
      ],
    );
  }

  List<List<dynamic>> _chunkLines(List<dynamic> source, int chunkSize) {
    if (source.isEmpty) return const [];
    final chunks = <List<dynamic>>[];
    for (int i = 0; i < source.length; i += chunkSize) {
      final end =
          (i + chunkSize < source.length) ? i + chunkSize : source.length;
      chunks.add(source.sublist(i, end));
    }
    return chunks;
  }

  Widget _buildGroupedExpenseLines(List<dynamic> lines) {
    final groups = groupPettyCashLinesByType(lines);
    if (groups.isEmpty) {
      return Text(
        'No expense lines',
        style: GoogleFonts.poppins(
          fontSize: 11.tsp,
          fontWeight: FontWeight.w500,
          color: ApprovalsOverviewTheme.textMuted,
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < groups.length; i++) ...[
          if (i > 0) ...[
            SizedBox(height: 10.th),
            Divider(
              height: 1,
              color: ApprovalsOverviewTheme.textSoft.withValues(alpha: 0.28),
            ),
            SizedBox(height: 10.th),
          ],
          InkWell(
            onTap: () {
              PettyCashExpenseLinesPopup.show(
                context: context,
                title: groups[i].typeLabel,
                lines: groups[i].lines,
              );
            },
            borderRadius: BorderRadius.circular(8.tr),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 2.th),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      groups[i].typeLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 13.tsp,
                        fontWeight: FontWeight.w600,
                        color: ApprovalsOverviewTheme.textDark,
                      ),
                    ),
                  ),
                  Text(
                    ApprovalDisplayHelpers.formatAmountWithAed(
                      groups[i].totalAmount,
                      fallback: '0',
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 13.tsp,
                      fontWeight: FontWeight.w700,
                      color: ApprovalsOverviewTheme.petty,
                    ),
                  ),
                  SizedBox(width: 4.tw),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20.tsp,
                    color: ApprovalsOverviewTheme.screenDeep,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final requestNo = _pick([
      _formData['request_no'],
      _formData['pettycash_no'],
      _formData['petty_cash_no'],
      _formData['name'],
      _formData['ref_no'],
    ], fallback: widget.requestId);

    final requester = _pick([
      _formData['requester_name'],
      _formData['requester'],
      _formData['emp_name'],
      _formData['employee_name'],
      _formData['employee'],
    ]);

    final pettycashHolder = _pick([
      _formData['pettycash_holder'],
      _formData['holder_name'],
      _formData['holder'],
    ]);
    final displayHolderName =
        pettycashHolder.isNotEmpty ? pettycashHolder : requester;

    final pettycashLimit = _pick([
      _formData['pettycash_limit'],
      _formData['limit'],
      _formData['limit_amount'],
      _formData['amount'],
    ]);

    final totalAmount = _pick([
      _formData['total_amount'],
      _formData['amount_total'],
      _formData['amount'],
      pettycashLimit,
    ]);

    final date = _pick([
      _formData['date'],
      _formData['request_date'],
      _formData['req_date'],
    ]);

    final submitDate = _formatDate(_pick([
      _formData['create_date'],
      _formData['created_date'],
      date,
    ]));

    final holderImage = _pickImage([
      _formData['holder_image_url'],
      _formData['pettycash_holder_image_url'],
      _formData['pettycash_holder_image'],
      _formData['holder_image'],
      _formData['holder_img'],
      _formData['pettycash_holder_avatar'],
      (_formData['pettycash_holder'] is Map)
          ? (_formData['pettycash_holder'] as Map)['image_emp']
          : null,
      (_formData['holder'] is Map)
          ? (_formData['holder'] as Map)['image_emp']
          : null,
      (_formData['holder_name'] is Map)
          ? (_formData['holder_name'] as Map)['image_emp']
          : null,
      _formData['image_emp'],
    ]);

    final lines = _formData['lines'] as List? ?? [];
    final hasAttachments = _attachmentIds.isNotEmpty;
    final isRejected =
        _rejectedLocked || ApprovalRejectedBanner.isRejected(_formData);
    final rejectedMessage = ApprovalRejectedBanner.messageFromForm(_formData);
    final apiComment = _normalizeApiComment(_pick([
      _formData['api_comment'],
      _formData['comment'],
      _formData['comments'],
      _formData['note'],
      _formData['notes'],
      _formData['remark'],
      _formData['remarks'],
      _formData['description'],
      _formData['manager_comment'],
      _formData['approver_comment'],
      _formData['reviewer_comment'],
      _formData['request_comment'],
      _formData['employee_comment'],
    ]));

    void showAllExpenseLines() {
      final allLines = lines.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      PettyCashExpenseLinesPopup.show(
        context: context,
        title: 'Expense Lines',
        lines: allLines,
        showTypeBadges: true,
      );
    }

    final userId = ApprovalBloc.resolveActingUserId();

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
                  title: requestNo.isNotEmpty ? requestNo : 'Petty Cash',
                  showBack: true,
                  onLightSurface: true,
                  transparentGlassBar: false,
                  scrimTopOpacity: 0,
                ),
                Expanded(
                  child: (_isLoading && _formData.isEmpty)
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
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (_isLoading && _formData.isNotEmpty)
                                      const LinearProgressIndicator(
                                        backgroundColor: Color(0xFFE0E0E0),
                                        color: Color(0xFF0A3887),
                                        minHeight: 3,
                                      ),
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(
                                          16.tw, 4.th, 16.tw, 0),
                                      child: _pettyCashRequestHeader(
                                        holderImage: holderImage,
                                        holderName: displayHolderName,
                                        requesterName: requester,
                                        submitDate: submitDate,
                                      ),
                                    ),
                                    SizedBox(height: 6.th),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        physics: const ClampingScrollPhysics(),
                                        padding: EdgeInsets.fromLTRB(
                                          16.tw,
                                          0,
                                          16.tw,
                                          (isRejected
                                                  ? (hasAttachments
                                                      ? 72.th
                                                      : 24.th)
                                                  : (hasAttachments
                                                      ? 120.th
                                                      : 68.th)) +
                                              context.systemBottomInset,
                                        ),
                                        child: Column(
                                          children: [
                                            SizedBox(height: 4.th),
                                            if (isRejected) ...[
                                              ApprovalRejectedBanner(
                                                message: rejectedMessage,
                                              ),
                                              SizedBox(height: 8.th),
                                            ],
                                            _glassSectionCard(
                                              title: 'Expense Lines',
                                              trailing: InkWell(
                                                onTap: showAllExpenseLines,
                                                borderRadius:
                                                    BorderRadius.circular(6.tr),
                                                child: Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 4.tw,
                                                    vertical: 2.th,
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        'Show all',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 10.tsp,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              ApprovalsOverviewTheme
                                                                  .screenDeep,
                                                        ),
                                                      ),
                                                      Icon(
                                                        Icons
                                                            .chevron_right_rounded,
                                                        size: 16.tsp,
                                                        color:
                                                            ApprovalsOverviewTheme
                                                                .screenDeep,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              child: _buildGroupedExpenseLines(
                                                lines,
                                              ),
                                            ),
                                            SizedBox(height: 6.th),
                                            _totalAmountCell(amount: totalAmount),
                                            SizedBox(height: 6.th),
                                            _buildSimCommentCard(apiComment),
                                            SizedBox(height: 8.th),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (hasAttachments)
                                  Positioned(
                                    left: 16.tw,
                                    right: 16.tw,
                                    bottom: context.systemBottomInset +
                                        (isRejected ? 8.th : 72.th),
                                    child: _viewAttachmentsButton(),
                                  ),
                                if (!isRejected)
                                  Positioned(
                                    left: 16.tw,
                                    right: 16.tw,
                                    bottom: context.systemBottomInset + 8.th,
                                    child: _floatingApprovalBar(
                                      userId,
                                      apiComment: apiComment,
                                    ),
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

class PettyCashSeeMoreScreen extends StatelessWidget {
  final String requestId;
  final String type;
  final String userId;
  final List<dynamic> lines;
  final String projectName;
  final String date;

  const PettyCashSeeMoreScreen({
    super.key,
    required this.requestId,
    required this.type,
    required this.userId,
    required this.lines,
    required this.projectName,
    required this.date,
  });

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

  String _displayOrNA(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? 'N/A' : normalized;
  }

  String _formatAmount(dynamic value) {
    final raw = _safe(value);
    if (raw.trim().isEmpty) return '0 AED';
    return ApprovalDisplayHelpers.formatAmountWithAed(raw, fallback: '0');
  }

  String _formatDate(dynamic value) {
    final raw = _safe(value);
    if (raw.trim().isEmpty) return 'N/A';
    final normalized = raw.contains(' ') ? raw.replaceFirst(' ', 'T') : raw;
    final parsed = DateTime.tryParse(normalized) ?? DateTime.tryParse(raw);
    if (parsed == null) return _displayOrNA(raw);
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  Widget _value(String text,
      {double? size, FontWeight? weight, Color? color, TextAlign? align}) {
    return Text(
      _displayOrNA(text),
      textAlign: align,
      style: GoogleFonts.poppins(
        fontSize: size ?? 14.tsp,
        fontWeight: weight ?? FontWeight.w700,
        color: color ?? const Color(0xFF0E0E0E),
        letterSpacing: 0.1,
      ),
      maxLines: 2,
      overflow: TextOverflow.visible,
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 11.tsp,
        fontWeight: FontWeight.w700,
        color: const Color(0xFFB4B4B4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  title: 'Petty Cash Details',
                  showBack: true,
                  onLightSurface: true,
                  transparentGlassBar: false,
                  scrimTopOpacity: 0,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      16.tw,
                      6.th,
                      16.tw,
                      68.th + context.systemBottomInset,
                    ),
                    child: OverviewGlassPanel(
                      fillAlpha: 0.9,
                      blurSigma: 8,
                      radius: 16,
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.tw, vertical: 10.th),
                      child: Column(
                        children: [
                          if (lines.isNotEmpty)
                            ...lines.asMap().entries.map((entry) {
                              final i = entry.key;
                              final lineMap = (entry.value as Map?) ?? {};
                              final description = _pick([
                                lineMap['description'],
                                lineMap['name'],
                                projectName,
                              ], fallback: 'Item');
                              final lineDate = _pick([
                                lineMap['invoice_date'],
                                lineMap['submitted_date'],
                                lineMap['expense_date'],
                                lineMap['date'],
                                lineMap['line_date'],
                                date,
                              ]);
                              final amount = _pick([
                                lineMap['amount'],
                                lineMap['price'],
                                lineMap['subtotal'],
                              ]);

                              return Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _value(description, size: 14.tsp),
                                            SizedBox(height: 6.tw),
                                            _label(_formatDate(lineDate)),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 12.tw),
                                      _value(
                                        _formatAmount(amount),
                                        size: 14.tsp,
                                        color: ApprovalsOverviewTheme.petty,
                                      ),
                                    ],
                                  ),
                                  if (i < lines.length - 1) ...[
                                    SizedBox(height: 10.tw),
                                    Divider(
                                      color: ApprovalsOverviewTheme.textSoft
                                          .withValues(alpha: 0.35),
                                      height: 1,
                                    ),
                                    SizedBox(height: 10.tw),
                                  ],
                                ],
                              );
                            })
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _value(projectName, size: 14.tsp),
                                      SizedBox(height: 6.tw),
                                      _label(_formatDate(date)),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 12.tw),
                                _value(
                                  _formatAmount(''),
                                  size: 14.tsp,
                                  color: ApprovalsOverviewTheme.petty,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 16.tw,
              right: 16.tw,
              bottom: context.systemBottomInset + 8.th,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20.tr),
                  boxShadow: [
                    BoxShadow(
                      color: ApprovalsOverviewTheme.screenDeep
                          .withValues(alpha: 0.12),
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
                    requestId: requestId,
                    type: type,
                    userIds: [userId],
                    variant: ApprovalActionButtonsVariant.glass,
                    showHrApproveConfirmation: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
