import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/Email%20Approval/bloc/approval_bloc.dart';
import 'package:el_race/ui/presentation/Email%20Approval/theme/approvals_overview_theme.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/approval_action_buttons.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/approval_rejected_banner.dart';
import 'package:el_race/ui/presentation/lpo/screens/lpo_pdf_viewer_screen.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class RfqDetailsScreen extends StatefulWidget {
  final String requestId;
  final String type;
  final Map<String, dynamic>? initialData;

  const RfqDetailsScreen({
    super.key,
    required this.requestId,
    required this.type,
    this.initialData,
  });

  @override
  State<RfqDetailsScreen> createState() => _RfqDetailsScreenState();
}

class _RfqDetailsScreenState extends State<RfqDetailsScreen> {
  static const String _localFakeRfqRequestId = 'LOCAL_FAKE_RFQ_001';
  bool _isLoading = true;
  String _error = '';
  bool _rejectedLocked = false;
  Map<String, dynamic> _formData = {};

  bool get _isLocalFakeRequest => widget.requestId == _localFakeRfqRequestId;

  Map<String, dynamic> _buildLocalFakeRfqData() {
    return {
      'request_no': 'RFQ/1254/89585',
      'project_name': 'Project Name',
      'city_id': 'City',
      'department': 'Department',
      'vendor_name': 'Vendor Name',
      'vendor_tags': ['Ceiling', 'Civil', 'Fitout', 'Label'],
      'work_order_no': '123345654874954652',
      'request_date': '2025-01-10',
      'material_type': 'Ceramic',
      'total_amount': '1000000',
      'comment': '',
      'client_photo_url': '',
      'attachment_ids': ['1'],
    };
  }

  @override
  void initState() {
    super.initState();
    if (_isLocalFakeRequest) {
      final fake = _buildLocalFakeRfqData();
      _formData = fake;
      _isLoading = false;
      return;
    }
    if (widget.initialData != null) {
      _formData = Map<String, dynamic>.from(widget.initialData!);
    }
    _fetchRfqDetails();
  }

  String _pick(List<dynamic> values, {String fallback = ''}) {
    for (final val in values) {
      if (val == null || val == false || val == true) continue;
      if (val is Map || val is List) {
        final nested = _pickName(val);
        if (nested.isNotEmpty) return nested;
        continue;
      }
      final str = val.toString().trim();
      if (str.isEmpty) continue;
      final lower = str.toLowerCase();
      if (lower == 'null' || lower == 'false' || lower == 'true') continue;
      return str;
    }
    return fallback;
  }

  String _displayOrDash(String? value) {
    final normalized = (value ?? '').trim();
    return normalized.isEmpty ? '-' : normalized;
  }

  String _pickName(dynamic source, {String fallback = ''}) {
    if (source is Map) {
      final map = Map<String, dynamic>.from(source);
      return _pick([
        map['name'],
        map['display_name'],
        map['label'],
      ], fallback: fallback);
    }
    if (source is List && source.isNotEmpty) {
      if (source.length >= 2) {
        final name = source[1]?.toString().trim() ?? '';
        if (name.isNotEmpty &&
            name.toLowerCase() != 'false' &&
            name.toLowerCase() != 'null') {
          return name;
        }
      }
      return _pickName(source.first, fallback: fallback);
    }
    return _pick([source], fallback: fallback);
  }

  String _normalizeImageUrl(String? rawUrl) {
    final value = (rawUrl ?? '').trim();
    if (value.isEmpty) return '';
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;
    if (value.startsWith('/')) return 'https://erp.elrace.com$value';
    return 'https://erp.elrace.com/$value';
  }

  String _dateForDisplay(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '-';
    final normalized =
        value.contains(' ') ? value.replaceFirst(' ', 'T') : value;
    final parsed = DateTime.tryParse(normalized) ?? DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  String _formatAmount(String raw) {
    if (raw.trim().isEmpty) return '-';
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.\-]'), '');
    final value = double.tryParse(cleaned);
    if (value == null) return _displayOrDash(raw);
    if (value % 1 == 0) {
      return NumberFormat('#,##0', 'en_US').format(value);
    }
    return NumberFormat('#,##0.##', 'en_US').format(value);
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

  Map<String, dynamic> _extractRfqFormData(Map result) {
    final rawData = result['data'];
    if (rawData is! Map) return const <String, dynamic>{};

    final data = Map<String, dynamic>.from(rawData);
    final formView = data['form_view'];

    final flattened = Map<String, dynamic>.from(data);
    if (formView is Map) {
      flattened.addAll(Map<String, dynamic>.from(formView));
    }

    return flattened;
  }

  Future<void> _fetchRfqDetails() async {
    final token = SharedPref.getLoginData().result?.token;
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final url = Uri.parse('https://erp.elrace.com/api/get_rfq_details');
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
        'rfq_id': int.tryParse(widget.requestId),
        'comment': commentParam,
      },
    });

    // cURL debug
    debugPrint('\n==== RFQ DETAILS REQUEST ====');
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
          '\n==== RFQ DETAILS RESPONSE (status: ${response.statusCode}) ====');
      final raw = response.body;
      const chunk = 800;
      for (var i = 0; i < raw.length; i += chunk) {
        debugPrint(
            raw.substring(i, i + chunk > raw.length ? raw.length : i + chunk));
      }
      debugPrint('=========================\n');

      final data = jsonDecode(response.body);

      if (data['result'] != null) {
        final result = data['result'] as Map;
        final formData = _extractRfqFormData(result);

        setState(() {
          final merged = Map<String, dynamic>.from(_formData);
          merged.addAll(formData);
          _formData = merged;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          if (_formData.isEmpty) {
            _error = 'Failed to load RFQ details';
          }
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        if (_formData.isEmpty) {
          _error = 'Error loading RFQ details: $e';
        }
      });
    }
  }

  Future<void> _viewAttachment() async {
    final poId = int.tryParse(widget.requestId);
    if (poId == null || poId <= 0) {
      Fluttertoast.showToast(
        msg: 'Invalid RFQ id.',
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
        'rfq_id': poId,
      },
    };

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await http.post(
        Uri.parse('https://erp.elrace.com/api/rfq/report_url'),
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
      final status = result?['status']?.toString();

      final pdfUrls = <String>[];
      final rawAttachments = result?['attachments'];
      if (rawAttachments is List) {
        for (final item in rawAttachments) {
          if (item is! Map) continue;
          final url = item['url']?.toString().trim() ?? '';
          if (url.isNotEmpty) pdfUrls.add(url);
        }
      }
      final reportUrl = result?['report_url']?.toString().trim() ?? '';
      if (pdfUrls.isEmpty && reportUrl.isNotEmpty) {
        pdfUrls.add(reportUrl);
      }

      if (status == 'error' ||
          result?['code']?.toString() == 'NO_ATTACHMENT' ||
          pdfUrls.isEmpty) {
        final error = decoded['error'] as Map?;
        final errorData = error?['data'] as Map?;
        Fluttertoast.showToast(
          msg: result?['message']?.toString() ??
              result?['error']?.toString() ??
              errorData?['message']?.toString() ??
              error?['message']?.toString() ??
              'No attachment to show',
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
            pdfUrls: pdfUrls,
            title: _pick([
              _formData['request_no'],
              _formData['rfq_no_code'],
              _formData['rfq_no'],
              _formData['name'],
              _formData['title'],
            ], fallback: widget.requestId),
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
      padding: EdgeInsets.symmetric(horizontal: 8.tw, vertical: 3.tw),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8.tr),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 9.tsp,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _glassSectionCard({required String title, required Widget child}) {
    return OverviewGlassPanel(
      fillAlpha: 0.94,
      blurSigma: 8,
      radius: 18,
      padding: EdgeInsets.fromLTRB(14.tw, 12.th, 14.tw, 12.th),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 11.tsp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: ApprovalsOverviewTheme.screenDeep,
            ),
          ),
          SizedBox(height: 14.th),
          child,
        ],
      ),
    );
  }

  Widget _themeDetailCell(String label, String value, {bool highlight = false}) {
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
        Text(
          _displayOrDash(value),
          softWrap: true,
          style: GoogleFonts.poppins(
            fontSize: 12.tsp,
            fontWeight: FontWeight.w700,
            height: 1.25,
            color: highlight
                ? ApprovalsOverviewTheme.rfq
                : ApprovalsOverviewTheme.textDark,
          ),
        ),
      ],
    );
  }

  Widget _metaPill(String text, {required Color background, Color? textColor}) {
    return Flexible(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 6.th),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16.tr),
        ),
        child: Text(
          _displayOrDash(text),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 10.tsp,
            fontWeight: FontWeight.w700,
            color: textColor ?? ApprovalsOverviewTheme.textDark,
          ),
        ),
      ),
    );
  }

  Widget _rfqRequestHeader({
    required String imageUrl,
    required String projectName,
    required String requestNo,
    required String department,
    required String vendorName,
  }) {
    return OverviewGlassPanel(
      fillAlpha: 0.88,
      blurSigma: 10,
      radius: 16,
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
                  color: ApprovalsOverviewTheme.rfq.withValues(alpha: 0.14),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(
              child: _buildClientAvatar(
                imageUrl: imageUrl,
                name: vendorName,
              ),
            ),
          ),
          SizedBox(width: 12.tw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _displayOrDash(projectName),
                  softWrap: true,
                  style: GoogleFonts.poppins(
                    fontSize: 15.tsp,
                    fontWeight: FontWeight.w700,
                    color: ApprovalsOverviewTheme.textDark,
                    height: 1.25,
                  ),
                ),
                SizedBox(height: 8.th),
                Row(
                  children: [
                    _metaPill(
                      requestNo,
                      background: ApprovalsOverviewTheme.screenTintMid
                          .withValues(alpha: 0.75),
                    ),
                    if (department.trim().isNotEmpty &&
                        department.trim() != '-') ...[
                      SizedBox(width: 8.tw),
                      _metaPill(
                        department,
                        background: ApprovalsOverviewTheme.screenMid
                            .withValues(alpha: 0.18),
                      ),
                    ],
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
      padding: EdgeInsets.fromLTRB(14.tw, 14.th, 14.tw, 14.th),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'COMMENT',
                style: GoogleFonts.poppins(
                  fontSize: 11.tsp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: ApprovalsOverviewTheme.screenDeep,
                ),
              ),
              const Spacer(),
              Text(
                '${comment.characters.length}/50',
                style: GoogleFonts.poppins(
                  fontSize: 10.tsp,
                  fontWeight: FontWeight.w500,
                  color: ApprovalsOverviewTheme.textSoft,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.th),
          Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: 48.th),
            padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 10.th),
            decoration: BoxDecoration(
              color: ApprovalsOverviewTheme.screenTintLight.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14.tr),
              border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
            ),
            child: Text(
              comment.trim().isEmpty ? 'No comment' : comment,
              style: GoogleFonts.poppins(
                fontSize: 12.tsp,
                fontWeight: comment.trim().isEmpty
                    ? FontWeight.w400
                    : FontWeight.w500,
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
          onRejectedLocked: () {
            if (!mounted) return;
            setState(() => _rejectedLocked = true);
          },
        ),
      ),
    );
  }

  Widget _buildClientAvatar({required String imageUrl, required String name}) {
    final initials = name.trim().isEmpty ? 'CL' : name.trim()[0].toUpperCase();

    Widget placeholder() {
      return Container(
        color: const Color(0xFFE8EDF5),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: GoogleFonts.poppins(
            fontSize: 16.tsp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF4A607A),
          ),
        ),
      );
    }

    if (imageUrl.isEmpty) {
      return ClipOval(child: placeholder());
    }

    return ClipOval(
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return placeholder();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requestNo = _pick([
      _formData['request_no'],
      _formData['rfq_no_code'],
      _formData['rfq_no'],
      _formData['title'],
      _formData['name'],
      _formData['ref_no'],
    ], fallback: widget.requestId);

    final reqDateRaw = _pick([
      _formData['request_date'],
      _formData['create_date'],
      _formData['req_date'],
      _formData['rfq_date'],
      _formData['date'],
    ]);
    final reqDate = _dateForDisplay(reqDateRaw);

    final projectName = _pick([
      _formData['project_name'],
      _formData['project_title'],
      _pickName(_formData['project']),
      _pickName(_formData['project_id']),
      _formData['project_name_id'],
      _formData['name'],
    ]);

    final department = _pick([
      _pickName(_formData['department_id']),
      _formData['department'],
      _formData['section'],
      _formData['dept_name'],
    ]);

    final vendorName = _pick([
      _formData['vendor_name'],
      _formData['vendor'],
      _formData['partner_name'],
      _formData['client_name'],
      _formData['client'],
      _formData['supplier'],
    ]);

    final projectMap = _formData['project'] is Map
        ? Map<String, dynamic>.from(_formData['project'] as Map)
        : null;
    final workOrderNo = _pick([
      // Waiting / form field used by ERP for RFQ work order number.
      _formData['w_o'],
      widget.initialData?['w_o'],
      projectMap?['w_o'],
      projectMap?['wo_ref_no'],
      projectMap?['wo_ref'],
      projectMap?['work_order'],
      _formData['wo_ref_no'],
      _formData['wo_ref'],
      _formData['wo_ref_number'],
      _formData['work_order_no'],
      _formData['work_order_number'],
      _formData['wo_no'],
      _formData['wono'],
      _formData['wo_no#'],
      _formData['wo'],
      _formData['wo_name'],
      _formData['work_order'],
    ]);

    final totalAmount = _pick([
      _formData['total_amount'],
      _formData['amount_total'],
      _formData['amount'],
      _formData['total'],
    ]);
    final formattedAmount = _formatAmount(totalAmount);

    final materialType = _pick([
      _formData['material_type'],
      _formData['material_type_name'],
      _formData['material'],
      _formData['item_type'],
      _formData['product_type'],
    ]);

    final comment = _pick([
      _formData['comment'],
      _formData['note'],
      _formData['description'],
    ]);

    final clientPhotoUrl = _normalizeImageUrl(_pick([
      _formData['client_photo_url'],
      _formData['vendor_photo_url'],
      _formData['partner_image_url'],
      _formData['image_url'],
      _formData['photo_url'],
    ]));

    final tags = _extractTags([
      _formData['vendor_tag'],
      _formData['vendor_tags'],
      _formData['tags'],
      _formData['tag_names'],
      _formData['tag'],
      _formData['rfq_tag'],
    ]).take(4).toList();

    final canViewReport = int.tryParse(widget.requestId) != null;
    final isRejected =
        _rejectedLocked || ApprovalRejectedBanner.isRejected(_formData);
    final rejectedMessage = ApprovalRejectedBanner.messageFromForm(_formData);

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
                  title: requestNo.isNotEmpty ? requestNo : 'RFQ',
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
                                      child: _rfqRequestHeader(
                                        imageUrl: clientPhotoUrl,
                                        projectName: projectName,
                                        requestNo: requestNo,
                                        department: department,
                                        vendorName: vendorName,
                                      ),
                                    ),
                                    SizedBox(height: 12.th),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        physics:
                                            const ClampingScrollPhysics(),
                                        padding: EdgeInsets.fromLTRB(
                                          16.tw,
                                          0,
                                          16.tw,
                                          (isRejected ? 24.th : 68.th) +
                                              context.systemBottomInset,
                                        ),
                                        child: Column(
                                          children: [
                                            if (isRejected) ...[
                                              ApprovalRejectedBanner(
                                                message: rejectedMessage,
                                              ),
                                              SizedBox(height: 12.th),
                                            ],
                                            _glassSectionCard(
                                              title: 'Vendor Details',
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  _themeDetailCell(
                                                    'Vendor',
                                                    vendorName,
                                                    highlight: true,
                                                  ),
                                                  SizedBox(height: 12.th),
                                                  SizedBox(
                                                    height: 32.th,
                                                    width: double.infinity,
                                                    child: tags.isEmpty
                                                        ? const SizedBox
                                                            .expand()
                                                        : ListView.separated(
                                                            scrollDirection:
                                                                Axis.horizontal,
                                                            itemCount:
                                                                tags.length,
                                                            separatorBuilder:
                                                                (_, __) =>
                                                                    SizedBox(
                                                              width: 8.tw,
                                                            ),
                                                            itemBuilder:
                                                                (_, index) {
                                                              final i =
                                                                  index % 4;
                                                              return Align(
                                                                alignment: Alignment
                                                                    .centerLeft,
                                                                child:
                                                                    _tagChip(
                                                                  tags[index],
                                                                  const [
                                                                    Color(
                                                                        0xFFE1E4FF),
                                                                    Color(
                                                                        0xFFFCE6E6),
                                                                    Color(
                                                                        0xFFFFF1D8),
                                                                    Color(
                                                                        0xFFE1F5EC),
                                                                  ][i],
                                                                  const [
                                                                    Color(
                                                                        0xFF3F51E8),
                                                                    Color(
                                                                        0xFFD32F2F),
                                                                    Color(
                                                                        0xFFE08A00),
                                                                    Color(
                                                                        0xFF00A05A),
                                                                  ][i],
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(height: 12.th),
                                            _glassSectionCard(
                                              title: 'RFQ Info',
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Expanded(
                                                        child: _themeDetailCell(
                                                          'W.O No#',
                                                          workOrderNo,
                                                        ),
                                                      ),
                                                      SizedBox(width: 16.tw),
                                                      Expanded(
                                                        child: _themeDetailCell(
                                                          'Request Date',
                                                          reqDate,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 14.th),
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Expanded(
                                                        child: _themeDetailCell(
                                                          'RFQ Amount',
                                                          formattedAmount,
                                                          highlight: true,
                                                        ),
                                                      ),
                                                      SizedBox(width: 16.tw),
                                                      Expanded(
                                                        child: _themeDetailCell(
                                                          'Material Type',
                                                          materialType,
                                                          highlight: true,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(height: 12.th),
                                            _buildSimCommentCard(comment),
                                            if (canViewReport) ...[
                                              SizedBox(height: 12.th),
                                              Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: _viewAttachment,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          14.tr),
                                                  child: Ink(
                                                    padding: EdgeInsets
                                                        .symmetric(
                                                            vertical: 11.th),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              14.tr),
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
                                                          size: 18.tsp,
                                                        ),
                                                        SizedBox(width: 6.tw),
                                                        Text(
                                                          'View Attachments',
                                                          style: GoogleFonts
                                                              .poppins(
                                                            fontSize: 13.tsp,
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
                                            SizedBox(height: 8.th),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (!isRejected)
                                  Positioned(
                                    left: 16.tw,
                                    right: 16.tw,
                                    bottom:
                                        context.systemBottomInset + 8.th,
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
