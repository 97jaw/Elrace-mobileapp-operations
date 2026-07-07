import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/Email%20Approval/theme/approvals_overview_theme.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/approval_display_helpers.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/approval_action_buttons.dart';
import 'package:el_race/ui/presentation/my_documents/screens/attachment_viewer_screen.dart';
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
  final PageController _linesPageController = PageController();
  int _currentLinesPage = 0;

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
    _linesPageController.dispose();
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
      normalizedLine['project'],
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

  Future<Map<String, dynamic>> _fetchAttachmentDetails(int attachmentId) async {
    final token = SharedPref.getLoginData().result?.token ?? '';
    const endpoint = 'https://erp.elrace.com/api/get_attachment_details';
    final url = Uri.parse(endpoint);
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final bodyMap = {
      'jsonrpc': '2.0',
      'params': {'attachment_id': attachmentId},
    };
    final bodyJson = jsonEncode(bodyMap);

    // ── curl log ──────────────────────────────────────────────────────
    debugPrint(
      "curl -X GET '$endpoint' "
      "-H 'Content-Type: application/json' "
      "-H 'Accept: application/json' "
      "-H 'Authorization: Bearer $token' "
      "--data '${bodyJson.replaceAll("'", "'\\''")}'",
    );

    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..body = bodyJson;
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    debugPrint(
        '══════ [PETTYCASH] get_attachment_details ($attachmentId) ══════');
    debugPrint('STATUS: ${response.statusCode}');
    debugPrint('BODY: ${response.body}');
    debugPrint(
        '═══════════════════════════════════════════════════════════════');

    final decoded = jsonDecode(response.body) as Map;
    final result = decoded['result'] as Map?;

    if (result == null || result['status'] != 'success') {
      throw Exception(
        result?['message']?.toString() ??
            decoded['error']?.toString() ??
            'Failed to load attachment (HTTP ${response.statusCode})',
      );
    }

    final data = result['data'];
    if (data is! Map) throw Exception('Invalid attachment details response');
    return Map<String, dynamic>.from(data);
  }

  Future<void> _openSingleAttachment(int attachmentId,
      {String hintName = ''}) async {
    bool loaderVisible = true;
    void dismissLoader() {
      if (!loaderVisible) return;
      loaderVisible = false;
      if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final details = await _fetchAttachmentDetails(attachmentId);
      dismissLoader();

      final publicUrl = (details['public_url'] ?? '').toString().trim();

      // Prefer attachment_name from API, but fall back to petty cash request
      // name if the API returns a raw field key like "attachment_id".
      final rawName = (details['attachment_name'] ?? '').toString().trim();
      final looksLikeKey = rawName.isEmpty ||
          rawName.toLowerCase() == 'attachment_id' ||
          rawName.toLowerCase() == 'false' ||
          rawName.toLowerCase() == 'null';
      final fallbackName = hintName.isNotEmpty
          ? hintName
          : _safe(_formData['name'], fallback: 'Petty Cash Attachment');
      final fileName = looksLikeKey ? fallbackName : rawName;

      if (publicUrl.isEmpty) {
        throw Exception('Attachment URL is empty');
      }

      final attachmentType =
          (details['attachment_type'] ?? '').toString().trim();

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AttachmentViewerScreen(
            publicUrl: publicUrl,
            title: fileName,
            attachmentType: attachmentType.isNotEmpty ? attachmentType : null,
          ),
        ),
      );
    } catch (e) {
      dismissLoader();
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 14.w, 16.w, 4.w),
              child: Text(
                'Select Attachment',
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Divider(),
            ...items.map((item) => ListTile(
                  leading: const Icon(Icons.picture_as_pdf_rounded),
                  title: Text(
                    item.name,
                    style: GoogleFonts.poppins(fontSize: 13.sp),
                  ),
                  onTap: () => Navigator.of(ctx).pop(item),
                )),
            SizedBox(height: 8.w),
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
          padding ?? EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      child: child,
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
            _displayOrNA(value),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
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
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Text(
          _displayOrNA(text),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 9.sp,
            fontWeight: FontWeight.w700,
            color: ApprovalsOverviewTheme.textDark,
          ),
        ),
      ),
    );
  }

  Widget _pettyCashRequestHeader({
    required String holderImage,
    required String holderName,
    required String pettycashLimit,
    required String requester,
    required String requestNo,
    required String requestDate,
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
            ),
            child: ClipOval(
              child: _buildAvatar(holderImage, iconSize: 30.w),
            ),
          ),
          SizedBox(width: 10.w),
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
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: ApprovalsOverviewTheme.textDark,
                    height: 1.2,
                  ),
                ),
                if (requester.trim().isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    'Requested by: $requester',
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
                Row(
                  children: [
                    _metaPill(
                      _formatAmount(pettycashLimit),
                      background: ApprovalsOverviewTheme.screenTintMid
                          .withValues(alpha: 0.75),
                    ),
                    SizedBox(width: 4.w),
                    _metaPill(
                      requestNo,
                      background:
                          ApprovalsOverviewTheme.petty.withValues(alpha: 0.16),
                    ),
                    SizedBox(width: 4.w),
                    _metaPill(
                      requestDate,
                      background: ApprovalsOverviewTheme.screenTintLight
                          .withValues(alpha: 0.75),
                    ),
                  ],
                ),
              ],
            ),
          ),
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

  Widget _floatingApprovalBar(String userId, {required String apiComment}) {
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
          useProvidedComment: true,
          commentProvider: () => apiComment,
        ),
      ),
    );
  }

  Widget _label(String text, {TextAlign? align, double? size}) {
    return Text(
      text,
      textAlign: align,
      style: GoogleFonts.poppins(
        fontSize: size ?? 11.sp,
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
        fontSize: size ?? 14.sp,
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
                  _value(description, size: 11.sp, weight: FontWeight.w700),
                  SizedBox(height: 6.w),
                  _label(_formatDate(lineDate), size: 8.sp),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            _value(
              _formatAmount(amount),
              size: 11.sp,
              weight: FontWeight.w700,
              color: ApprovalsOverviewTheme.petty,
            ),
          ],
        ),
        if (showDivider) ...[
          SizedBox(height: 10.w),
          const Divider(
            color: Color(0xFFD2D2D2),
            height: 1,
          ),
          SizedBox(height: 10.w),
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

    final projectName = _pick([
      _formData['project_name'],
      _formData['project_title'],
      _formData['project'],
    ]);

    final date = _pick([
      _formData['date'],
      _formData['request_date'],
      _formData['req_date'],
    ]);

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
    final linePages = _chunkLines(lines, 6);
    final safePageIndex = linePages.isEmpty
        ? 0
        : _currentLinesPage.clamp(0, linePages.length - 1) as int;
    final currentPageLineCount =
        linePages.isEmpty ? 1 : linePages[safePageIndex].length;
    final dividerCount =
        currentPageLineCount > 0 ? currentPageLineCount - 1 : 0;
    final lineSliderHeight = linePages.isNotEmpty
        ? (24.w + (currentPageLineCount * 38.w) + (dividerCount * 19.w))
            .clamp(84.w, 460.w)
        : 84.w;
    final hasAttachments = _attachmentIds.isNotEmpty;
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
    final requestDateLabel = _formatDate(date);

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
                  title: 'Petty Cash',
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
                                    if (_isLoading && _formData.isNotEmpty)
                                      const LinearProgressIndicator(
                                        backgroundColor: Color(0xFFE0E0E0),
                                        color: Color(0xFF0A3887),
                                        minHeight: 3,
                                      ),
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(
                                          16.w, 4.h, 16.w, 0),
                                      child: _pettyCashRequestHeader(
                                        holderImage: holderImage,
                                        holderName: displayHolderName,
                                        pettycashLimit: pettycashLimit,
                                        requester: requester,
                                        requestNo: requestNo,
                                        requestDate: requestDateLabel,
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
                                              title: 'Request Info',
                                              child: Column(
                                                children: [
                                                  _themeDetailCell(
                                                    'Petty Cash Holder',
                                                    pettycashHolder,
                                                  ),
                                                  SizedBox(height: 6.h),
                                                  _themeDetailCell(
                                                    'Requested By',
                                                    requester,
                                                  ),
                                                  SizedBox(height: 6.h),
                                                  _themeDetailCell(
                                                    'Project',
                                                    projectName,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(height: 6.h),
                                            _glassSectionCard(
                                              title: 'Expense Lines',
                                              child: Column(
                                                children: [
                                                  SizedBox(
                                                    height: lineSliderHeight,
                                                    child: linePages.isNotEmpty
                                                        ? PageView.builder(
                                                            controller:
                                                                _linesPageController,
                                                            itemCount: linePages
                                                                .length,
                                                            onPageChanged:
                                                                (index) {
                                                              if (!mounted) {
                                                                return;
                                                              }
                                                              setState(() {
                                                                _currentLinesPage =
                                                                    index;
                                                              });
                                                            },
                                                            itemBuilder:
                                                                (context,
                                                                    pageIndex) {
                                                              final pageLines =
                                                                  linePages[
                                                                      pageIndex];
                                                              return Column(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  for (int i =
                                                                          0;
                                                                      i <
                                                                          pageLines
                                                                              .length;
                                                                      i++)
                                                                    () {
                                                                      final lineMap =
                                                                          pageLines[i] as Map? ??
                                                                              {};
                                                                      final description =
                                                                          _pick([
                                                                        lineMap[
                                                                            'description'],
                                                                        lineMap[
                                                                            'name'],
                                                                        projectName,
                                                                      ], fallback: 'Project name');
                                                                      final lineDate =
                                                                          _pick([
                                                                        lineMap[
                                                                            'invoice_date'],
                                                                        lineMap[
                                                                            'submitted_date'],
                                                                        lineMap[
                                                                            'expense_date'],
                                                                        lineMap[
                                                                            'date'],
                                                                        lineMap[
                                                                            'line_date'],
                                                                        date,
                                                                      ]);
                                                                      final amount =
                                                                          _pick([
                                                                        lineMap[
                                                                            'amount'],
                                                                        lineMap[
                                                                            'price'],
                                                                        lineMap[
                                                                            'subtotal'],
                                                                        pettycashLimit,
                                                                      ]);

                                                                      return _lineItemTile(
                                                                        description:
                                                                            description,
                                                                        lineDate:
                                                                            lineDate,
                                                                        amount:
                                                                            amount,
                                                                        showDivider: i <
                                                                            pageLines.length -
                                                                                1,
                                                                      );
                                                                    }(),
                                                                ],
                                                              );
                                                            },
                                                          )
                                                        : _lineItemTile(
                                                            description:
                                                                _displayOrNA(
                                                                    projectName),
                                                            lineDate: date,
                                                            amount:
                                                                pettycashLimit,
                                                            showDivider: false,
                                                          ),
                                                  ),
                                                  if (linePages.length > 1) ...[
                                                    SizedBox(height: 8.h),
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        for (int i = 0;
                                                            i <
                                                                linePages
                                                                    .length;
                                                            i++)
                                                          Container(
                                                            width: 8.w,
                                                            height: 8.w,
                                                            margin: EdgeInsets
                                                                .symmetric(
                                                                    horizontal:
                                                                        5.w),
                                                            decoration:
                                                                BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              color: i ==
                                                                      _currentLinesPage
                                                                  ? ApprovalsOverviewTheme
                                                                      .petty
                                                                  : Colors
                                                                      .transparent,
                                                              border:
                                                                  Border.all(
                                                                color:
                                                                    ApprovalsOverviewTheme
                                                                        .textSoft,
                                                                width: 1,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            SizedBox(height: 6.h),
                                            _buildSimCommentCard(apiComment),
                                            if (hasAttachments) ...[
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
                                                      gradient:
                                                          const LinearGradient(
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
        fontSize: size ?? 14.sp,
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
        fontSize: 11.sp,
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
                      16.w,
                      6.h,
                      16.w,
                      68.h + context.systemBottomInset,
                    ),
                    child: OverviewGlassPanel(
                      fillAlpha: 0.9,
                      blurSigma: 8,
                      radius: 16,
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 10.h),
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
                                            _value(description, size: 14.sp),
                                            SizedBox(height: 6.w),
                                            _label(_formatDate(lineDate)),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      _value(
                                        _formatAmount(amount),
                                        size: 14.sp,
                                        color: ApprovalsOverviewTheme.petty,
                                      ),
                                    ],
                                  ),
                                  if (i < lines.length - 1) ...[
                                    SizedBox(height: 10.w),
                                    Divider(
                                      color: ApprovalsOverviewTheme.textSoft
                                          .withValues(alpha: 0.35),
                                      height: 1,
                                    ),
                                    SizedBox(height: 10.w),
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
                                      _value(projectName, size: 14.sp),
                                      SizedBox(height: 6.w),
                                      _label(_formatDate(date)),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                _value(
                                  _formatAmount(''),
                                  size: 14.sp,
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
              left: 16.w,
              right: 16.w,
              bottom: context.systemBottomInset + 8.h,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20.r),
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
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
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
