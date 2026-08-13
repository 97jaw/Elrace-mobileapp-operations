import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:convert';
import 'dart:ui' as ui show TextDirection;

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/Email%20Approval/bloc/approval_bloc.dart';
import 'package:el_race/ui/presentation/Email%20Approval/theme/approvals_overview_theme.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/approval_display_helpers.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/invoice_approval_display.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/approval_action_buttons.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/approval_rejected_banner.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/invoice_print_menu_button.dart';
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
  /// Debug-only waiting-invoice form when no live approval is available.
  static const String localFakeInvoiceRequestId = 'LOCAL_FAKE_INVOICE_001';

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
  bool _isLoading = true;
  String _error = '';
  bool _rejectedLocked = false;

  Map<String, dynamic> _formData = const {};
  /// Filled when form only has project id/[id,name] without embedded wo_ref_no.
  String _resolvedWoRefNo = '';

  bool get _isLocalFakeRequest =>
      widget.requestId == InvoiceDetailsScreen.localFakeInvoiceRequestId;

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
      'write_date': '2025-01-28 14:30:00',
      'retention': '-',
      'invoice_amount': '1000000',
      'completion': '85',
      'work_done_percent': '85',
      'work_done_amount': '60000',
      'x_report_work_done_amount': '60000',
      'advance_percentage': '20%',
      'last_update_percentage': '30%',
      'retention_percentage': '10%',
      'x_report_retention_amount': '0',
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
      if (widget.initialData != null) {
        final id = widget.initialData!['invoice_id'] ?? widget.initialData!['id'];
        if (id != null && int.tryParse(id.toString()) != null) {
          fake['invoice_id'] = int.parse(id.toString());
          fake['id'] = int.parse(id.toString());
        }
      }
      _formData = fake;
      _isLoading = false;
      return;
    }
    if (widget.initialData != null) {
      _formData = Map<String, dynamic>.from(widget.initialData!);
      // List payload may already include the project link — try early resolve.
      _resolveWoRefFromLinkedProject();
    }
    _fetchInvoiceDetails();
  }

  String _safe(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    if (v == false || v == true) return fallback;
    final s = v.toString().trim();
    if (s.isEmpty) return fallback;
    final lower = s.toLowerCase();
    // API used to send literal "-" placeholders for missing finance fields.
    if (lower == 'false' ||
        lower == 'true' ||
        lower == 'null' ||
        lower == '-' ||
        lower == 'n/a' ||
        lower == 'none') {
      return fallback;
    }
    return s;
  }

  /// Unwrap Odoo many2one / linked values: Map{name}, [id, name], or plain.
  String _odooDisplay(dynamic value, {String fallback = ''}) {
    if (value == null || value == false || value == true) return fallback;
    if (value is Map) {
      return _pick([
        value['wo_ref_no'],
        value['wo_ref'],
        value['date'],
        value['datetime'],
        value['value'],
        value['name'],
        value['display_name'],
        value['ref'],
        value['label'],
      ], fallback: fallback);
    }
    if (value is List && value.isNotEmpty) {
      if (value.length >= 2) {
        final name = _safe(value[1]);
        if (name.isNotEmpty) return name;
      }
      return _odooDisplay(value.first, fallback: fallback);
    }
    return _safe(value, fallback: fallback);
  }

  String _pick(List<dynamic> values, {String fallback = ''}) {
    for (final v in values) {
      final s = _odooDisplay(v);
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }

  /// Prefer incoming form_view values, but keep list-item values when Odoo
  /// sends `false` / null / "-" for empty fields.
  Map<String, dynamic> _mergeFormView(
    Map<String, dynamic> existing,
    Map<String, dynamic> formView,
  ) {
    final merged = Map<String, dynamic>.from(existing);
    formView.forEach((key, value) {
      if (value == null || value == false) {
        if (_odooDisplay(merged[key]).isNotEmpty) return;
      }
      final incoming = _odooDisplay(value);
      if (incoming.isEmpty && _odooDisplay(merged[key]).isNotEmpty) {
        return;
      }
      merged[key] = value;
    });
    return merged;
  }

  /// `x_folder_count_project_id` → `project.project.wo_ref_no` (not project name).
  String _woRefFromFolderProject(dynamic value) {
    return InvoiceApprovalDisplay.woRefFromProjectLink(value);
  }

  String _pickNestedWoRef(Map<String, dynamic> data) {
    final fromFolderProject = _woRefFromFolderProject(
      data['x_folder_count_project_id'],
    );
    if (fromFolderProject.isNotEmpty) return fromFolderProject;

    final direct = _pick([
      data['wo_ref_no'],
      data['wo_ref'],
      data['wo_ref_number'],
      data['work_order_no'],
      data['work_order_number'],
      data['work_order'],
      data['workorder'],
      data['wo_order_no'],
      data['wo_order_number'],
      data['wo_name'],
      data['wo'],
      data['w_o'],
      data['wo_no'],
      data['wono'],
      data['wo_no#'],
      data['wo_id'],
      data['x_wo_ref_no'],
      data['x_studio_wo_ref_no'],
    ]);
    if (direct.isNotEmpty) return direct;

    for (final value in data.values) {
      if (value is Map) {
        final nested = _pickNestedWoRef(Map<String, dynamic>.from(value));
        if (nested.isNotEmpty) return nested;
      }
    }
    return '';
  }

  String _displayOrDash(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? '-' : normalized;
  }

  String _formatDate(dynamic value) {
    final raw = _odooDisplay(value);
    if (raw.isEmpty || raw == '-') return '-';
    final normalized = raw.contains(' ') ? raw.replaceFirst(' ', 'T') : raw;
    final parsed = DateTime.tryParse(normalized) ?? DateTime.tryParse(raw);
    if (parsed == null) {
      // Keep already-formatted dd/MM/yyyy (or similar) as-is.
      if (RegExp(r'^\d{1,2}[/-]\d{1,2}[/-]\d{2,4}$').hasMatch(raw)) {
        return raw;
      }
      return raw;
    }
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
        _formData = _mergeFormView(_formData, formView);
        _isLoading = false;
        _error = '';
      });
      // form_view often sends x_folder_count_project_id as id or [id, name]
      // without wo_ref_no — resolve from get_projects.
      await _resolveWoRefFromLinkedProject();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _deepFindWoRef(dynamic node, {int depth = 0}) {
    if (depth > 6 || node == null) return '';
    if (node is Map) {
      final map = Map<dynamic, dynamic>.from(node);
      for (final key in const [
        'wo_ref_no',
        'wo_ref',
        'wo_ref_number',
        'w_o',
        'work_order_no',
      ]) {
        final direct = _safe(map[key]);
        if (direct.isNotEmpty) return direct;
      }
      // Prefer linked project map before scanning everything.
      for (final key in const [
        'x_folder_count_project_id',
        'project',
        'project_id',
      ]) {
        if (!map.containsKey(key)) continue;
        final nested = _woRefFromFolderProject(map[key]);
        if (nested.isNotEmpty) return nested;
        final deep = _deepFindWoRef(map[key], depth: depth + 1);
        if (deep.isNotEmpty) return deep;
      }
      for (final value in map.values) {
        final deep = _deepFindWoRef(value, depth: depth + 1);
        if (deep.isNotEmpty) return deep;
      }
    } else if (node is List) {
      for (final entry in node) {
        final deep = _deepFindWoRef(entry, depth: depth + 1);
        if (deep.isNotEmpty) return deep;
      }
    }
    return '';
  }

  List<Map<String, dynamic>> _projectsFromGetProjectsResponse(dynamic decoded) {
    if (decoded is! Map) return const [];
    final result = decoded['result'];
    dynamic data;
    if (result is Map) {
      data = result['data'] ?? result['projects'] ?? result['records'];
      if (data == null && result['result'] is Map) {
        final inner = result['result'] as Map;
        data = inner['data'] ?? inner['projects'];
      }
    } else if (result is List) {
      data = result;
    }
    if (data is Map) {
      data = data['data'] ?? data['projects'] ?? data['records'];
    }
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  String _woFromProjectRow(Map<String, dynamic> map) {
    return _safe(
      map['wo_ref_no'] ??
          map['wo_ref'] ??
          map['wo_ref_number'] ??
          map['w_o'] ??
          map['wo_no'] ??
          map['work_order_no'] ??
          map['work_order'],
    );
  }

  Future<String> _queryProjectsForWoRef({
    required String token,
    required Map<String, dynamic> params,
    int? preferProjectId,
    String preferProjectName = '',
  }) async {
    final body = jsonEncode({'jsonrpc': '2.0', 'params': params});
    final request = http.Request(
      'GET',
      Uri.parse('https://erp.elrace.com/api/get_projects'),
    )
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      })
      ..body = body;
    final response = await http.Response.fromStream(await request.send());
    debugPrint(
      'INVOICE W.O get_projects status=${response.statusCode} params=$params',
    );
    if (response.statusCode != 200) return '';

    final rows = _projectsFromGetProjectsResponse(jsonDecode(response.body));
    debugPrint('INVOICE W.O get_projects rows=${rows.length}');
    if (rows.isEmpty) return '';

    String? byId;
    String? byName;
    String? firstWo;
    final preferName = preferProjectName.trim().toLowerCase();

    for (final map in rows) {
      final wo = _woFromProjectRow(map);
      if (wo.isEmpty) continue;
      firstWo ??= wo;

      final rowIds = <int?>[
        _parsePositiveInt(map['id']),
        _parsePositiveInt(map['project_id']),
        InvoiceApprovalDisplay.projectIdFromLink(map['project_id']),
      ].whereType<int>();
      if (preferProjectId != null && rowIds.contains(preferProjectId)) {
        byId = wo;
        break;
      }

      final rowName =
          _safe(map['name'] ?? map['project_name'] ?? map['display_name'])
              .toLowerCase();
      if (preferName.isNotEmpty &&
          rowName.isNotEmpty &&
          (rowName == preferName ||
              rowName.contains(preferName) ||
              preferName.contains(rowName))) {
        byName ??= wo;
      }
    }

    return byId ?? byName ?? ((rows.length == 1) ? (firstWo ?? '') : '');
  }

  Future<void> _resolveWoRefFromLinkedProject() async {
    if (_resolvedWoRefNo.isNotEmpty) return;

    final link = _formData['x_folder_count_project_id'] ??
        widget.initialData?['x_folder_count_project_id'];

    // 1) Embedded wo_ref_no on the project link / anywhere in form payload.
    final embedded = _woRefFromFolderProject(link);
    final deep = embedded.isNotEmpty
        ? embedded
        : _deepFindWoRef({
            ..._formData,
            if (widget.initialData != null) ...widget.initialData!,
          });
    if (deep.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _resolvedWoRefNo = deep;
        _formData = {
          ..._formData,
          'wo_ref_no': deep,
        };
      });
      return;
    }

    final projectId = InvoiceApprovalDisplay.projectIdFromLink(link) ??
        InvoiceApprovalDisplay.projectIdFromLink(_formData['project_id']) ??
        InvoiceApprovalDisplay.projectIdFromLink(_formData['project']) ??
        InvoiceApprovalDisplay.projectIdFromLink(
            widget.initialData?['project_id']);

    final projectName = _pick([
      InvoiceApprovalDisplay.projectNameFromLink(link),
      _formData['project_name'],
      _formData['project_title'],
      _formData['project'] is Map
          ? (_formData['project'] as Map)['name']
          : _formData['project'],
      widget.initialData?['project_name'],
      widget.initialData?['project_title'],
    ]);

    debugPrint(
      '==== INVOICE W.O resolve ====\n'
      'x_folder_count_project_id raw=$link\n'
      'projectId=$projectId name="$projectName"\n'
      'form keys=${_formData.keys.toList()}',
    );
    if (projectId == null && projectName.isEmpty) return;

    final token = SharedPref.getLoginData().result?.token;
    if (token == null || token.isEmpty) return;

    try {
      final attempts = <Map<String, dynamic>>[
        if (projectId != null)
          {'limit': 20, 'offset': 0, 'project_id': projectId, 'id': projectId},
        if (projectName.isNotEmpty)
          {
            'limit': 20,
            'offset': 0,
            'keyword': projectName,
            'name': projectName,
            'search_name': projectName,
          },
        if (projectId != null)
          {'limit': 50, 'offset': 0, 'keyword': '$projectId'},
      ];

      String found = '';
      for (final params in attempts) {
        found = await _queryProjectsForWoRef(
          token: token,
          params: params,
          preferProjectId: projectId,
          preferProjectName: projectName,
        );
        if (found.isNotEmpty) break;
      }

      debugPrint('INVOICE W.O resolved wo_ref_no="$found"');
      if (found.isEmpty || !mounted) return;
      setState(() {
        _resolvedWoRefNo = found;
        _formData = {
          ..._formData,
          'wo_ref_no': found,
        };
      });
    } catch (e) {
      debugPrint('INVOICE W.O resolve error: $e');
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
            child: _TwoLineSlowSlideText(
              text: _displayOrDash(projectName),
              style: GoogleFonts.poppins(
                fontSize: 15.tsp,
                fontWeight: FontWeight.w700,
                color: ApprovalsOverviewTheme.textDark,
                height: 1.25,
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
    int? invoiceId,
    String? invoiceTitle,
  }) {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            title: 'Invoice Info',
            icon: Icons.description_outlined,
            trailing: (invoiceId != null && invoiceId > 0)
                ? InvoicePrintMenuButton(
                    invoiceId: invoiceId,
                    title: invoiceTitle,
                    color: const Color(0xFF2F80ED),
                  )
                : null,
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
          onRejectedLocked: () {
            if (!mounted) return;
            setState(() => _rejectedLocked = true);
          },
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
      _formData['project_id'],
      _formData['project_name_id'],
      _formData['name'],
    ]);

    final requestDate = _formatDate(_pick([
      _formData['request_date'],
      _formData['req_date'],
      _formData['date_request'],
      _formData['date_order'],
      _formData['create_date'],
      _formData['created_date'],
      _formData['invoice_date'],
      _formData['date_of_invoice'],
      _formData['date_invoice'],
      _formData['date'],
      _formData['submitted_date'],
      _formData['approval_date'],
      widget.initialData?['request_date'],
      widget.initialData?['invoice_date'],
      widget.initialData?['date'],
      widget.initialData?['create_date'],
      _formData['write_date'],
    ]));

    final projectMap = _formData['project'] is Map
        ? Map<String, dynamic>.from(_formData['project'] as Map)
        : null;
    final projectIdMap = _formData['project_id'] is Map
        ? Map<String, dynamic>.from(_formData['project_id'] as Map)
        : null;
    final workOrderNo = _pick([
      // Related project.project on x_folder_count_project_id → wo_ref_no.
      _resolvedWoRefNo,
      _woRefFromFolderProject(_formData['x_folder_count_project_id']),
      _woRefFromFolderProject(widget.initialData?['x_folder_count_project_id']),
      _woRefFromFolderProject(projectMap?['x_folder_count_project_id']),
      _woRefFromFolderProject(projectIdMap?['x_folder_count_project_id']),
      projectMap?['wo_ref_no'],
      projectMap?['wo_ref'],
      projectMap?['work_order'],
      projectIdMap?['wo_ref_no'],
      projectIdMap?['wo_ref'],
      _formData['wo_ref_no'],
      _formData['wo_ref'],
      _formData['wo_ref_number'],
      _formData['work_order_no'],
      _formData['work_order_number'],
      _formData['work_order'],
      _formData['workorder'],
      _formData['wo_order_no'],
      _formData['wo_order_number'],
      _formData['wo_name'],
      _formData['wo'],
      _formData['w_o'],
      _formData['wo_no'],
      _formData['wono'],
      _formData['wo_no#'],
      _formData['wo_id'],
      _formData['x_wo_ref_no'],
      _formData['x_studio_wo_ref_no'],
      widget.initialData?['wo_ref_no'],
      widget.initialData?['wo_ref'],
      widget.initialData?['work_order_no'],
      widget.initialData?['wo_name'],
      widget.initialData?['wo'],
      _pickNestedWoRef(_formData),
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
      _formData['work_done_percent'],
      _formData['work_done_percentage'],
      _formData['progress_percent'],
      _formData['progress_percentage'],
      _formData['completion'],
      _formData['completion_percentage'],
      _formData['completion_percent'],
      widget.initialData?['work_done_percent'],
      widget.initialData?['completion'],
    ], fallback: '');
    final completionPercent = _parsePercent(completionRaw);

    // Advance: amount preferred; percentage fallback (x_elrace_customer_invoices).
    final advanceRaw = _pick([
      _formData['advance'],
      _formData['advance_amount'],
      _formData['advance_deduction'],
      _formData['advance_payment_amount'],
      _formData['x_report_advance_amount'],
      widget.initialData?['advance'],
      widget.initialData?['advance_amount'],
    ]);
    final advance = advanceRaw.isNotEmpty
        ? _formatAmount(advanceRaw)
        : _displayOrDash(_pick([
            _formData['advance_percentage'],
            _formData['advance_percent'],
            _formData['x_payment_percent'],
            widget.initialData?['advance_percentage'],
          ], fallback: '-'));

    // Progress amount (cumulative work done value on certificate).
    final progress = _formatAmount(_pick([
      _formData['progress'],
      _formData['progress_amount'],
      _formData['x_report_work_done_amount'],
      _formData['work_done_amount'],
      _formData['x_work_done_amount'],
      _formData['total_work_value'],
      widget.initialData?['progress'],
      widget.initialData?['work_done_amount'],
    ], fallback: '-'));

    // Last update = write_date from form_view.
    final lastUpdate = _formatDate(_pick([
      _formData['write_date'],
      widget.initialData?['write_date'],
      _formData['__last_update'],
      _formData['last_update'],
      _formData['last_update_date'],
      _formData['last_updated'],
      _formData['last_updated_at'],
      _formData['date_last_update'],
      _formData['updated_at'],
      widget.initialData?['last_update'],
      widget.initialData?['updated_at'],
    ], fallback: '-'));

    // Retention: report/certificate amount preferred.
    final retentionRaw = _pick([
      _formData['retention'],
      _formData['retention_amount'],
      _formData['retention_deduction'],
      _formData['x_report_retention_amount'],
      _formData['retention_fee'],
      widget.initialData?['retention'],
      widget.initialData?['retention_amount'],
    ]);
    final retention = retentionRaw.isNotEmpty
        ? _formatAmount(retentionRaw)
        : _displayOrDash(_pick([
            _formData['retention_percentage'],
            _formData['retention_percent'],
            _formData['x_retention_deduction_percent'],
            widget.initialData?['retention_percentage'],
          ], fallback: '-'));

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
                                    (isRejected ? 24.th : 78.th) +
                                        context.systemBottomInset,
                                  ),
                                  child: Column(
                                    children: [
                                      if (isRejected) ...[
                                        ApprovalRejectedBanner(
                                          message: rejectedMessage,
                                        ),
                                        SizedBox(height: 10.th),
                                      ],
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
                                        invoiceId: _parsePositiveInt(
                                              _formData['invoice_id'],
                                            ) ??
                                            _parsePositiveInt(
                                              _formData['id'],
                                            ) ??
                                            _parsePositiveInt(widget.requestId),
                                        invoiceTitle: requestNo,
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
                                if (!isRejected)
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

/// Max 2 lines. Line 1 stays fixed; if overflow, only line 2 slides horizontally.
class _TwoLineSlowSlideText extends StatefulWidget {
  const _TwoLineSlowSlideText({
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  @override
  State<_TwoLineSlowSlideText> createState() => _TwoLineSlowSlideTextState();
}

class _TwoLineSlowSlideTextState extends State<_TwoLineSlowSlideText>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  String _line1 = '';
  String _line2 = '';
  double _overflowX = 0;
  double _lastWidth = 0;
  String _lastText = '';
  bool _useStaticTwoLines = true;

  double get _lineHeight {
    final size = widget.style.fontSize ?? 15;
    final height = widget.style.height ?? 1.25;
    return size * height;
  }

  double get _boxHeight => _lineHeight * 2;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  int _endOfFirstLine(TextPainter painter, double maxWidth) {
    final metrics = painter.computeLineMetrics();
    if (metrics.isEmpty) return widget.text.length;
    final line = metrics.first;
    final pos = painter.getPositionForOffset(
      Offset(line.left + line.width - 0.001, line.baseline),
    );
    var end = pos.offset.clamp(0, widget.text.length);
    // Prefer breaking after whitespace when possible.
    if (end > 0 && end < widget.text.length) {
      final ch = widget.text[end - 1];
      if (ch != ' ' && ch != '\n') {
        final space = widget.text.lastIndexOf(' ', end - 1);
        if (space > 0) end = space + 1;
      }
    }
    return end;
  }

  void _evaluate(double maxWidth) {
    if (maxWidth <= 0) return;
    if (maxWidth == _lastWidth && widget.text == _lastText) return;
    _lastWidth = maxWidth;
    _lastText = widget.text;

    _controller?.dispose();
    _controller = null;
    _overflowX = 0;

    final text = widget.text.trim();
    if (text.isEmpty) {
      _line1 = '';
      _line2 = '';
      _useStaticTwoLines = true;
      if (mounted) setState(() {});
      return;
    }

    final wrapped = TextPainter(
      text: TextSpan(text: text, style: widget.style),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    final metrics = wrapped.computeLineMetrics();
    if (metrics.length <= 2) {
      // Fits in two lines — no animation.
      _useStaticTwoLines = true;
      _line1 = text;
      _line2 = '';
      if (mounted) setState(() {});
      return;
    }

    // More than 2 lines: freeze line 1, marquee the remainder on line 2.
    _useStaticTwoLines = false;
    final end = _endOfFirstLine(wrapped, maxWidth);
    _line1 = text.substring(0, end).trimRight();
    _line2 = text.substring(end).trimLeft();

    final line2Painter = TextPainter(
      text: TextSpan(text: _line2, style: widget.style),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout();
    _overflowX =
        (line2Painter.width - maxWidth).clamp(0.0, double.infinity);

    if (_overflowX > 1) {
      // ~22px/sec — slow horizontal ping-pong.
      final seconds = (_overflowX / 22).clamp(4.0, 18.0);
      _controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: (seconds * 1000).round()),
      )..repeat(reverse: true);
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _evaluate(constraints.maxWidth);
        });

        if (_useStaticTwoLines || _line2.isEmpty) {
          return SizedBox(
            height: _boxHeight,
            width: constraints.maxWidth,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.text,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                style: widget.style,
              ),
            ),
          );
        }

        return SizedBox(
          height: _boxHeight,
          width: constraints.maxWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: _lineHeight,
                width: constraints.maxWidth,
                child: Text(
                  _line1,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: widget.style,
                ),
              ),
              SizedBox(
                height: _lineHeight,
                width: constraints.maxWidth,
                child: ClipRect(
                  child: _overflowX <= 1 || _controller == null
                      ? Text(
                          _line2,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: widget.style,
                        )
                      : AnimatedBuilder(
                          animation: _controller!,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(
                                -_overflowX * _controller!.value,
                                0,
                              ),
                              child: child,
                            );
                          },
                          child: Text(
                            _line2,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.visible,
                            style: widget.style,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
