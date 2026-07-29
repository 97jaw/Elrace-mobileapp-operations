import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/Email%20Approval/bloc/approval_bloc.dart';
import 'package:el_race/ui/presentation/Email%20Approval/theme/approvals_overview_theme.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/approval_action_buttons.dart';
import 'package:el_race/ui/presentation/Email%20Approval/widgets/approval_rejected_banner.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class HrDetailsScreen extends StatefulWidget {
  final String requestId;
  final String type;

  /// When false (HR Management module), form is read-only — no approve/reject bar.
  final bool showApprovalActions;

  const HrDetailsScreen({
    super.key,
    required this.requestId,
    required this.type,
    this.showApprovalActions = true,
  });

  @override
  State<HrDetailsScreen> createState() => _HrDetailsScreenState();
}

class _HrDetailsScreenState extends State<HrDetailsScreen> {
  static const String _localFakeHrManagementId = 'LOCAL_FAKE_HR_001';
  static const Map<int, String> _caseByTypeId = {
    35849: 'sick',
    35651: 'short',
    35842: 'annual',
    24602: 'maternity',
    35847: 'job_mission',
    35564: 'temporary_permission',
    35841: 'clearance',
    35837: 'effective_date',
    34068: 'salary_certificate',
    32938: 'loan',
    33800: 'increment',
    32312: 'promotion',
    18915: 'parental',
    31615: 'resignation',
    25165: 'termination',
    31875: 'transfer',
    30388: 'passport',
    35803: 'leave_encashment',
    33244: 'car_rent',
  };

  static const Map<String, String> _caseTitle = {
    'sim': 'Sim Card Request',
    'sick': 'Sick Leave',
    'short': 'Short Leave',
    'annual': 'Annual Leave',
    'maternity': 'Maternity Leave',
    'job_mission': 'Job Mission',
    'temporary_permission': 'Temporary Permission',
    'clearance': 'Clearance',
    'effective_date': 'Effective Date',
    'salary_certificate': 'Salary Certificate',
    'certificate_request': 'Certificate Request',
    'loan': 'Loan Request',
    'increment': 'Salary Increment',
    'salary_increment': 'Salary Increment',
    'promotion': 'Promotion',
    'parental': 'Parental',
    'resignation': 'Resignation',
    'resign': 'Resign',
    'termination': 'Termination',
    'transfer': 'Transfer Request',
    'passport': 'Passport',
    'leave_encashment': 'Leave Encashment',
    'car_rent': 'Car Rent Request',
    'generic': 'HR Management',
  };

  static const Map<String, String> _caseByTypeCode = {
    'sim': 'sim',
    'annual': 'annual',
    'short': 'short',
    'sick': 'sick',
    'maternity': 'maternity',
    'parental': 'parental',
    'annualleave_short': 'short',
    'annualleave_sick': 'sick',
    'annualleave_annual': 'annual',
    'annualleave_parental': 'parental',
    'annualleave_maternity': 'maternity',
    'clearance': 'clearance',
    'temp': 'temporary_permission',
    'effective_date': 'effective_date',
    'jm': 'job_mission',
    'resignation': 'resignation',
    'resign': 'resignation',
    'encashment': 'leave_encashment',
    'salary_certificate': 'salary_certificate',
    'certificate_request': 'salary_certificate',
    'loan': 'loan',
    'promotion': 'promotion',
    'transfer': 'transfer',
    'increment': 'increment',
    'salary_increment': 'increment',
    'termination': 'termination',
    'carrent': 'car_rent',
    'car_rent': 'car_rent',
    'passport': 'passport',
    'passport_request': 'passport',
  };

  bool _isLoading = true;
  String _error = '';
  bool _rejectedLocked = false;

  Map<String, dynamic> _formData = const {};
  Map<String, dynamic> _employeeInfo = const {};
  Map<String, dynamic> _requestInfo = const {};

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

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value as Map);
    }
    return const {};
  }

  String _normalizeToken(String value) {
    return value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  }

  bool _isValidAttachmentUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  String _titleCaseSimple(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final words = trimmed
        .split(RegExp(r'[_\s]+'))
        .where((w) => w.trim().isNotEmpty)
        .map((w) {
      final lower = w.toLowerCase();
      return '${lower[0].toUpperCase()}${lower.substring(1)}';
    }).toList();
    return words.join(' ');
  }

  int? _toInt(dynamic value) {
    if (value == null || value == false || value == true) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  String _pickFromMaps(List<Map<String, dynamic>> maps, List<String> keys,
      {String fallback = ''}) {
    final values = <dynamic>[];
    for (final key in keys) {
      for (final map in maps) {
        values.add(map[key]);
      }
    }
    return _pick(values, fallback: fallback);
  }

  int? _resolveCaseIdFromData(List<Map<String, dynamic>> maps) {
    final idKeys = [
      'leave_request_subtype_id',
      'leave_request_subtype',
      'request_subtype_id',
      'request_subtype',
      'request_type_id',
      'type_id',
      'sub_type_id',
      'hr_request_type_id',
    ];

    for (final key in idKeys) {
      for (final map in maps) {
        final id = _toInt(map[key]);
        if (id != null && _caseByTypeId.containsKey(id)) {
          return id;
        }
      }
    }
    return null;
  }

  String _resolveCaseKey({
    required String requestName,
    required List<Map<String, dynamic>> requestMaps,
  }) {
    final directRequestId = int.tryParse(widget.requestId);
    if (directRequestId != null && _caseByTypeId.containsKey(directRequestId)) {
      return _caseByTypeId[directRequestId] ?? 'generic';
    }

    final caseId = _resolveCaseIdFromData(requestMaps);
    if (caseId != null) {
      return _caseByTypeId[caseId] ?? 'generic';
    }

    final leaveSubtype = _pickFromMaps(requestMaps, [
      'leave_request_subtype',
      'leave_request_type',
      'leave_request_type_labor',
      'leave_type',
      'leave_type_code',
      'holiday_status_name',
    ]);
    if (leaveSubtype.isNotEmpty) {
      final normalizedLeaveSubtype = _normalizeToken(leaveSubtype);
      final mappedLeaveSubtype = _caseByTypeCode[normalizedLeaveSubtype];
      if (mappedLeaveSubtype != null) return mappedLeaveSubtype;
    }

    final rawTypeCode = _pick([
      _pickFromMaps(requestMaps, [
        'request_type_code',
        'request_code',
        'type_code',
        'leave_request_subtype',
        'leave_type_code',
        'request_type',
        'leave_type',
      ]),
      widget.type,
    ]);

    if (rawTypeCode.isNotEmpty) {
      final normalizedTypeCode = _normalizeToken(rawTypeCode);
      final mapped = _caseByTypeCode[normalizedTypeCode];
      if (mapped != null) return mapped;
    }

    final n = requestName.toLowerCase();
    if (n.contains('sim')) return 'sim';
    if (n.contains('sick')) return 'sick';
    if (n.contains('short')) return 'short';
    if (n.contains('annual')) return 'annual';
    if (n.contains('maternity')) return 'maternity';
    if (n.contains('parental')) return 'parental';
    if (n.contains('job mission') || n.contains('مهمة')) return 'job_mission';
    if (n.contains('temporary')) return 'temporary_permission';
    if (n.contains('clearance')) return 'clearance';
    if (n.contains('effective')) return 'effective_date';
    if (n.contains('certificate')) return 'salary_certificate';
    if (n.contains('loan')) return 'loan';
    if (n.contains('promotion')) return 'promotion';
    if (n.contains('salary') && n.contains('increment')) return 'increment';
    if (n.contains('increment')) return 'increment';
    if (n.contains('resign')) return 'resignation';
    if (n.contains('terminat')) return 'termination';
    if (n.contains('transfer')) return 'transfer';
    if (n.contains('passport')) return 'passport';
    if (n.contains('encash')) return 'leave_encashment';
    if (n.contains('car') && n.contains('rent')) return 'car_rent';
    return 'generic';
  }

  List<_DetailItem> _buildRequestDetailItems(
      String caseKey, List<Map<String, dynamic>> dataMaps) {
    List<_DetailItem> makeItems(List<_FieldDef> defs) {
      final items = <_DetailItem>[];
      for (final def in defs) {
        final hasLiteralDash = def.keys.contains('-');
        final value = hasLiteralDash ? '-' : _pickFromMaps(dataMaps, def.keys);
        if (def.label == 'Birth Attachment' && !_isValidAttachmentUrl(value)) {
          continue;
        }
        if (value.isNotEmpty) {
          items.add(_DetailItem(def.label, value, multiline: def.multiline));
        }
      }
      return items;
    }

    final common = [
      const _FieldDef(
          'Requested By', ['requested_by', 'requester_name', 'employee_name']),
      const _FieldDef('Request Date', [
        'request_date',
        'request_datetime',
        'request_date_from',
        'date',
        'create_date',
      ]),
    ];

    switch (caseKey) {
      case 'sim':
        return makeItems([
          ...common,
          const _FieldDef('Company No.', ['company_no']),
          const _FieldDef('Employee ID', ['employee_id', 'emp_id']),
        ]);
      case 'sick':
        return makeItems([
          ...common,
          const _FieldDef('Start Date', ['start_date', 'request_date_from']),
          const _FieldDef('Duration', [
            'requested_duration',
            'duration',
            'number_of_days',
          ]),
          const _FieldDef('Available Days', ['-']),
          const _FieldDef('End Date', ['-']),
          const _FieldDef('Allowed Sick Days', ['allowed_sick_days']),
          const _FieldDef('Sick Leave Reference No', [
            'sick_leave_reference',
            'sick_leave_reference_no',
            'certificate_no',
          ]),
          const _FieldDef('Emirates ID', ['emirates_id']),
          const _FieldDef('Validation', [
            'review_validation',
            'review_validation_url',
            'validation_url',
            'review_url',
          ]),
          const _FieldDef('Reason', ['note', 'description'], multiline: true),
        ]);
      case 'short':
        return makeItems([
          ...common,
          const _FieldDef('Start Date', ['start_date', 'request_date_from']),
          const _FieldDef('Duration', [
            'requested_duration',
            'duration',
            'number_of_days',
          ]),
          const _FieldDef('End Date', ['-']),
          const _FieldDef('Leave Balance', ['-']),
        ]);
      case 'annual':
        final annualItems = makeItems([
          ...common,
          const _FieldDef('Start Date', ['start_date', 'request_date_from']),
          const _FieldDef('Duration', [
            'requested_duration',
            'duration',
            'number_of_days',
          ]),
          const _FieldDef('Available Days', ['available_days']),
          const _FieldDef('End Date', ['end_date', 'request_date_to']),
          const _FieldDef('Annual/Short Usage', [
            'annual_short_leaves_remaining',
          ]),
        ]);
        annualItems.add(const _DetailItem('Leave Balance', '-'));
        return annualItems;
      case 'parental':
        return makeItems([
          ...common,
          const _FieldDef('Start Date', ['start_date', 'request_date_from']),
          const _FieldDef('End Date', ['end_date', 'request_date_to']),
          const _FieldDef('Duration', [
            'requested_duration',
            'duration',
            'number_of_days',
          ]),
          const _FieldDef('Birth Attachment', ['birth_attachment']),
        ]);
      case 'maternity':
        return makeItems([
          ...common,
          const _FieldDef('Start Date', ['start_date', 'request_date_from']),
          const _FieldDef('Duration', [
            'requested_duration',
            'duration',
            'number_of_days',
          ]),
          const _FieldDef('Available Days', ['-']),
          const _FieldDef('End Date', ['end_date', 'request_date_to']),
          const _FieldDef('Annual/Short Usage', ['-']),
          const _FieldDef('Leave Balance', ['-']),
          const _FieldDef(
              'Discharge Report Attachment', ['discharge_report_attachment']),
        ]);
      case 'job_mission':
        return makeItems([
          ...common,
          const _FieldDef('Start Time', ['start_time', 'job_time']),
          const _FieldDef('Duration Type', ['duration_type']),
          const _FieldDef('Job Mission Type', ['job_mission_type', 'job_type']),
          const _FieldDef('Only Afternoon', ['only_afternoon']),
          const _FieldDef('Reason', ['note', 'description'], multiline: true),
        ]);
      case 'temporary_permission':
        return makeItems([
          const _FieldDef('Request Date', [
            'request_date',
            'request_datetime',
            'request_date_from',
            'date',
            'create_date',
          ]),
          const _FieldDef('Start Date', ['start_date', 'request_date_from']),
          const _FieldDef('Available Days', ['available_days']),
          const _FieldDef('End Date', ['end_date', 'request_date_to']),
          const _FieldDef('Leave Balance', [
            'remaining_leave_days',
            'leave_balance',
            'balance_leave',
          ]),
          const _FieldDef(
              'Start Hour', ['start_time', 'hour_from', 'temp_hours']),
          const _FieldDef('Duration Type', ['duration_type', 'temp_selection']),
        ]);
      case 'clearance':
        return makeItems([
          ...common,
          const _FieldDef('Last Work Date', ['last_work_date', 'end_date']),
          const _FieldDef(
              'Reason for Leaving', ['reason_for_leaving', 'reason'],
              multiline: true),
        ]);
      case 'effective_date':
        return makeItems([
          const _FieldDef('Request Date', [
            'request_date',
            'request_datetime',
            'request_date_from',
            'date',
            'create_date',
          ]),
          const _FieldDef('Joined Date', ['joined_date', 'join_date']),
          const _FieldDef(
              'Reason',
              [
                'discipline_reason',
                'e_reason',
                'reason',
              ],
              multiline: true),
        ]);
      case 'salary_certificate':
      case 'certificate_request':
        return makeItems([
          ...common,
          const _FieldDef(
              'Certificate Type', ['certificate_type', 'document_type']),
          const _FieldDef('Language', ['certificate_language', 'language']),
          const _FieldDef('Reason', ['note', 'description'], multiline: true),
        ]);
      case 'loan':
        return makeItems([
          ...common,
          const _FieldDef('Effective Date', ['eos_date']),
          const _FieldDef('Loan Type', ['loan_type']),
          const _FieldDef('Net Worked Days', ['net_worked_days']),
          const _FieldDef('Years', ['years']),
          const _FieldDef('Total Absent Days', ['total_absent_days']),
          const _FieldDef('Total Gratuity', ['total_gratuity']),
          const _FieldDef(
              'Loan Amount', ['loan_amount', 'amount', 'requested_amount']),
        ]);
      case 'promotion':
        final promotionItems = makeItems([
          ...common,
          const _FieldDef('Effective Date', ['effective_date']),
          const _FieldDef('New Job Position', ['new_job']),
        ]);
        final newManagerValue = _pickFromMaps(dataMaps, ['new_manager']);
        promotionItems.add(_DetailItem(
            'New Manager', newManagerValue.isEmpty ? '-' : newManagerValue));
        promotionItems.addAll(makeItems([
          const _FieldDef('Current Manager', ['old_manager']),
          const _FieldDef('Evaluation Score %', ['overall_score']),
        ]));
        return promotionItems;
      case 'increment':
      case 'salary_increment':
        return makeItems([
          ...common,
          const _FieldDef('Effective Date', [
            'increment_effective_date',
            'effective_date',
          ]),
          const _FieldDef(
              'Suggested Increment by Employee', ['employee_suggested_salary']),
          const _FieldDef('Suggested By Manager', ['manager_suggested_salary']),
          const _FieldDef('New Salary', [
            'new_salary',
            'suggested_total',
            'salary_max',
          ]),
          const _FieldDef('Evaluation Score%', [
            'evaluation_score',
            'overall_score',
          ]),
        ]);
      case 'resignation':
      case 'resign':
        return makeItems([
          ...common,
          const _FieldDef(
              'Notice Period Start Date', ['notice_period_start_date']),
          const _FieldDef('Resignation Type', ['resignation_type']),
          const _FieldDef('Last Day of Employee', ['expected_relieving_date']),
          const _FieldDef('Notice Period', ['notice_period']),
          const _FieldDef('Reason', ['reason', 'note'], multiline: true),
        ]);
      case 'termination':
        return makeItems([
          const _FieldDef('Requested By',
              ['requested_by', 'requester_name', 'employee_name']),
          const _FieldDef('Company Number', ['company_no']),
          const _FieldDef('Request Date', [
            'request_date',
            'request_datetime',
            'request_date_from',
            'date',
            'create_date',
          ]),
          const _FieldDef('Termination type', ['termination_type']),
          const _FieldDef('Reason', ['termination_reason', 'reason']),
          const _FieldDef('Expected Last day of Employee', [
            'emp_last_day',
            'expected_relieving_date',
          ]),
        ]);
      case 'transfer':
        final transferItems = makeItems([
          ...common,
          const _FieldDef('Type', ['transfer_type']),
        ]);
        final newManagerValue = _pickFromMaps(dataMaps, ['new_manager']);
        transferItems.add(_DetailItem('New Transfer Manager',
            newManagerValue.isEmpty ? '-' : newManagerValue));
        transferItems.addAll(makeItems([
          const _FieldDef('Transfer From', ['transfer_from']),
          const _FieldDef('Transfer To', ['transfer_to']),
          const _FieldDef('Forman', ['forman']),
          const _FieldDef('Reason', ['reason', 'note'], multiline: true),
        ]));
        return transferItems;
      case 'passport':
        return makeItems([
          ...common,
          const _FieldDef('Passport No', ['passport_no', 'passport_number']),
          const _FieldDef('Issue Date', ['issue_date']),
          const _FieldDef('Expiry Date', ['expiry_date']),
          const _FieldDef('Return Date', ['return_date']),
          const _FieldDef('Reason', ['note', 'description'], multiline: true),
        ]);
      case 'leave_encashment':
        return makeItems([
          ...common,
          const _FieldDef('Start Date', ['-']),
          const _FieldDef(
              'Encashment Days', ['encashment_days', 'encash_days']),
          const _FieldDef('Available Days', ['available_days']),
          const _FieldDef('End Date', ['request_date_to', 'end_date']),
          const _FieldDef('Leave Balance', [
            'remaining_leave_days',
            'available_balance',
            'leave_balance',
          ]),
          const _FieldDef('GM Attachment', ['gm_attachment']),
        ]);
      case 'car_rent':
        return makeItems([
          ...common,
          const _FieldDef('Company Name', ['company_no']),
          const _FieldDef('Car Request Type', ['car_req_type']),
          const _FieldDef('Rent Type', ['rent_type']),
          const _FieldDef('Comment', ['note', 'description'], multiline: true),
        ]);
      default:
        return makeItems([
          ...common,
          const _FieldDef('Start Date', ['start_date', 'request_date_from']),
          const _FieldDef('Duration', [
            'requested_duration',
            'duration',
            'number_of_days',
          ]),
          const _FieldDef('End Date', ['end_date', 'request_date_to']),
          const _FieldDef('Reason', ['note', 'description'], multiline: true),
        ]);
    }
  }

  bool get _isLocalFakeRequest => widget.requestId == _localFakeHrManagementId;

  Map<String, dynamic> _buildLocalFakeFormData() {
    return {
      'employee_info': {
        'employee_name': 'Local Test Employee',
        'emp_id': 'EMP-FAKE-001',
        'type': 'Staff',
        'section': 'Media',
        'job_title': 'Media Manager',
        'city_id': 'Al Ain',
        'joining_date': '2023-10-16',
        'working_days': '2 years 4 months 24 days',
      },
      'request_info': {
        'request_no': 'REQ/FAKE/001',
        'request_name': 'Temporary Permission',
        'request_date_from': '2026-03-04',
        'request_date_to': '2026-03-05',
        'duration_type': '3',
        'start_time': '8 am',
        'leave_balance': '42.50',
      },
    };
  }

  @override
  void initState() {
    super.initState();
    if (_isLocalFakeRequest) {
      _formData = _buildLocalFakeFormData();
      _employeeInfo = _asMap(_formData['employee_info']);
      _requestInfo = _asMap(_formData['request_info']);
      _isLoading = false;
      return;
    }
    _fetchHrDetails();
  }

  Future<void> _fetchHrDetails() async {
    final token = SharedPref.getLoginData().result?.token;
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final url = Uri.parse('https://erp.elrace.com/api/get_hr_request_details');
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'params': {
        'request_id': int.tryParse(widget.requestId),
      },
    });

    print('🔵 HR Details Request - ID: ${widget.requestId}');
    print('🔵 URL: $url');
    print('🔵 Body: $body');

    try {
      final request = http.Request('GET', url)
        ..headers.addAll(headers)
        ..body = body;

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      print('🔵 Response Status: ${response.statusCode}');
      print('🔵 Response Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (data['result'] != null) {
        final result = data['result'] as Map;
        // Backend may return {status: error, message: ...} with no data —
        // previously treated as success → empty/null employee + request cards.
        final status = result['status']?.toString().toLowerCase();
        if (status == 'error' || result['success'] == false) {
          final msg = result['message']?.toString() ??
              'Failed to load HR request details';
          print('🔴 HR details API error: $msg');
          setState(() {
            _error = msg;
            _isLoading = false;
          });
          return;
        }

        final rawData = result['data'] as Map? ?? {};
        // Data is inside form_view
        final formData = rawData['form_view'] as Map? ?? rawData;
        final employeeInfo = _asMap(rawData['employee_info']).isNotEmpty
            ? _asMap(rawData['employee_info'])
            : _asMap(formData['employee_info']);
        final requestInfo = _asMap(rawData['request_info']).isNotEmpty
            ? _asMap(rawData['request_info'])
            : _asMap(formData['request_info']);

        print('🟢 Success - FormData: $formData');
        if (employeeInfo.isNotEmpty) {
          print('🟢 Employee Info: $employeeInfo');
        }
        if (requestInfo.isNotEmpty) {
          print('🟢 Request Info: $requestInfo');
        }

        setState(() {
          _formData = Map<String, dynamic>.from(formData);
          _employeeInfo = Map<String, dynamic>.from(employeeInfo);
          _requestInfo = Map<String, dynamic>.from(requestInfo);
          _isLoading = false;
        });
      } else {
        print('🔴 Error - No result in response: $data');
        setState(() {
          _error = data['error']?['message'] ?? 'Failed to load HR details';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('🔴 Exception: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return OverviewGlassPanel(
      fillAlpha: 0.9,
      blurSigma: 6,
      radius: 16,
      padding:
          padding ?? EdgeInsets.symmetric(horizontal: 16.tw, vertical: 14.tw),
      child: child,
    );
  }

  Widget _label(String text, {TextAlign? align}) {
    return Text(
      text,
      textAlign: align,
      style: GoogleFonts.poppins(
        fontSize: 11.tsp,
        fontWeight: FontWeight.w700,
        color: ApprovalsOverviewTheme.textSoft,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _value(String text,
      {double? size, FontWeight? weight, Color? color, TextAlign? align}) {
    return Text(
      text,
      textAlign: align,
      style: GoogleFonts.poppins(
        fontSize: size ?? 13.tsp,
        fontWeight: weight ?? FontWeight.w600,
        color: color ?? ApprovalsOverviewTheme.textDark,
        letterSpacing: 0.1,
      ),
      maxLines: null,
      overflow: TextOverflow.visible,
    );
  }

  Widget _buildEmployeeImage(String imageData) {
    // Check if it's a base64 encoded image
    if (imageData.startsWith('data:image') ||
        (!imageData.startsWith('http://') &&
            !imageData.startsWith('https://'))) {
      try {
        // Remove the data:image/png;base64, prefix if it exists
        String base64String = imageData;
        if (imageData.contains('base64,')) {
          base64String = imageData.split('base64,')[1];
        }

        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            Icons.person,
            color: const Color(0xFF6B6B6B),
            size: 30.tw,
          ),
        );
      } catch (e) {
        print('🔴 Error decoding base64 image: $e');
        return Icon(
          Icons.person,
          color: const Color(0xFF6B6B6B),
          size: 30.tw,
        );
      }
    }

    // It's a URL, use Image.network
    return Image.network(
      imageData,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
          ),
        );
      },
      errorBuilder: (_, __, ___) => Icon(
        Icons.person,
        color: const Color(0xFF6B6B6B),
        size: 30.tw,
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    final isRequestedBy = label.toLowerCase() == 'requested by';
    final requestedByShouldStartLeft =
        isRequestedBy && value.trim().length > 22;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 13.tw),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: _value(label, size: 13.tsp, weight: FontWeight.w600),
          ),
          SizedBox(width: 12.tw),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign:
                  requestedByShouldStartLeft ? TextAlign.left : TextAlign.right,
              textDirection: TextDirection.ltr,
              softWrap: true,
              maxLines: null,
              overflow: TextOverflow.visible,
              style: GoogleFonts.poppins(
                fontSize: 13.tsp,
                fontWeight: FontWeight.w900,
                color: _isOrangeValueLabel(label)
                    ? const Color(0xFFFF8A00)
                    : const Color(0xFF0E0E0E),
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isOrangeValueLabel(String label) {
    return label == 'Suggested Increment by Employee' ||
        label == 'Suggested By Manager';
  }

  Widget _detailDescriptionBox(String label, String value) {
    final boxHeading = label == 'Comment' ? 'Comment' : 'Description';
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 13.tw),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _value(label, size: 13.tsp, weight: FontWeight.w600),
          SizedBox(height: 6.tw),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(10.tw),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.tr),
              border: Border.all(color: const Color(0xFFC8C8C8)),
              color: const Color(0xFFF5F5F5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  boxHeading,
                  style: GoogleFonts.poppins(
                    fontSize: 12.tsp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF8E8E8E),
                  ),
                ),
                SizedBox(height: 8.tw),
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(minHeight: 60.tw),
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.tw, vertical: 8.tw),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.tr),
                    border: Border.all(color: const Color(0xFFD4D4D4)),
                    color: const Color(0xFFF5F5F5),
                  ),
                  child: Text(
                    value,
                    textDirection: TextDirection.ltr,
                    softWrap: true,
                    maxLines: null,
                    overflow: TextOverflow.visible,
                    style: GoogleFonts.poppins(
                      fontSize: 12.tsp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF333333),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openValidationUrl(String rawUrl) async {
    final url = rawUrl.trim();
    if (url.isEmpty) return;

    final parsed = Uri.tryParse(url);
    if (parsed == null) return;

    final canLaunch = await canLaunchUrl(parsed);
    if (!canLaunch) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open validation link')),
      );
      return;
    }

    final openedInApp =
        await launchUrl(parsed, mode: LaunchMode.inAppBrowserView);
    if (!openedInApp) {
      await launchUrl(parsed, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openAttachmentUrl(String rawValue) async {
    final value = rawValue.trim();
    if (value.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attachment is empty or invalid')),
      );
      return;
    }

    final parsed = Uri.tryParse(value);
    final isValidWebUrl = parsed != null &&
        parsed.hasScheme &&
        (parsed.scheme == 'http' || parsed.scheme == 'https');
    if (!isValidWebUrl) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attachment link is invalid')),
      );
      return;
    }

    final canLaunch = await canLaunchUrl(parsed);
    if (!canLaunch) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open attachment')),
      );
      return;
    }

    final openedInApp =
        await launchUrl(parsed, mode: LaunchMode.inAppBrowserView);
    if (!openedInApp) {
      await launchUrl(parsed, mode: LaunchMode.externalApplication);
    }
  }

  Widget _validationActionBox(String url) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 13.tw),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _value('Validation', size: 13.tsp, weight: FontWeight.w600),
          SizedBox(height: 10.tw),
          SizedBox(
            width: double.infinity,
            child: InkWell(
              onTap: () => _openValidationUrl(url),
              borderRadius: BorderRadius.circular(12.tr),
              child: Container(
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(vertical: 13.tw),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.tr),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF6F737B), Color(0xFF565A62)],
                  ),
                ),
                child: Text(
                  'Review Sick Leave',
                  style: GoogleFonts.poppins(
                    fontSize: 13.tsp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attachmentActionBox(String value, {String label = 'GM Attachment'}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 13.tw),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _value(label, size: 13.tsp, weight: FontWeight.w600),
          SizedBox(height: 10.tw),
          SizedBox(
            width: double.infinity,
            child: InkWell(
              onTap: () => _openAttachmentUrl(value),
              borderRadius: BorderRadius.circular(12.tr),
              child: Container(
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(vertical: 13.tw),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.tr),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF6F737B), Color(0xFF565A62)],
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.attach_file_rounded,
                      color: Colors.white,
                      size: 17.tsp,
                    ),
                    SizedBox(width: 4.tw),
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
          ),
        ],
      ),
    );
  }

  Widget _requestMetaBox({
    required String label,
    required String value,
  }) {
    return Container(
      height: 74.tw,
      padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 9.tw),
      decoration: BoxDecoration(
        color: ApprovalsOverviewTheme.screenTintLight.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12.tr),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11.tsp,
              fontWeight: FontWeight.w500,
              color: ApprovalsOverviewTheme.textSoft,
              letterSpacing: 0.1,
            ),
          ),
          SizedBox(height: 4.tw),
          Expanded(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                value,
                maxLines: null,
                overflow: TextOverflow.visible,
                style: GoogleFonts.poppins(
                  fontSize: 14.tsp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF111111),
                  height: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateForDisplay(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return '';

    final datePart = raw.split(' ').first;
    final parts = datePart.split('-');
    if (parts.length == 3 && parts[0].length == 4) {
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return raw;
  }

  String _formatAmountWithAed(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return '-';
    final lower = raw.toLowerCase();
    if (lower.contains('aed')) return raw;

    final numeric = RegExp(r'^\d+(\.\d+)?$');
    if (numeric.hasMatch(raw)) return '$raw AED';
    return raw;
  }

  Widget _simSectionCard({
    required String title,
    required List<_DetailItem> items,
  }) {
    final visible =
        items.where((e) => e.value.trim().isNotEmpty).toList(growable: false);

    return OverviewGlassPanel(
      fillAlpha: 0.9,
      blurSigma: 8,
      radius: 16,
      padding: EdgeInsets.fromLTRB(12.tw, 10.th, 12.tw, 10.th),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 10.tsp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: ApprovalsOverviewTheme.screenDeep,
            ),
          ),
          SizedBox(height: 6.th),
          if (visible.isEmpty)
            Text(
              'No data',
              style: GoogleFonts.poppins(
                fontSize: 12.tsp,
                color: ApprovalsOverviewTheme.textSoft,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final cellW = (constraints.maxWidth - 8.tw) / 2;
                return Wrap(
                  spacing: 6.tw,
                  runSpacing: 6.th,
                  children: [
                    for (final item in visible)
                      SizedBox(
                        width: item.fullWidth ? constraints.maxWidth : cellW,
                        child: _themeDetailCell(
                          item.label,
                          item.value,
                          highlight: item.highlight ||
                              item.label == 'Suggested Increment' ||
                              item.label == 'Suggested By Manager' ||
                              item.label == 'New Salary',
                        ),
                      ),
                  ],
                );
              },
            ),
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
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
        ),
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
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11.tsp,
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

  Widget _referenceRequestHeader({
    required String employeeName,
    required String secondaryName,
    required String employeeImage,
    required String requestNo,
    required String branchName,
  }) {
    return OverviewGlassPanel(
      fillAlpha: 0.88,
      blurSigma: 10,
      radius: 16,
      padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 8.th),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
              boxShadow: [
                BoxShadow(
                  color:
                      ApprovalsOverviewTheme.screenDeep.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(
              child: employeeImage.isNotEmpty
                  ? _buildEmployeeImage(employeeImage)
                  : Icon(
                      Icons.person_rounded,
                      color: ApprovalsOverviewTheme.textSoft,
                      size: 34.tw,
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
                  employeeName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 15.tsp,
                    fontWeight: FontWeight.w700,
                    color: ApprovalsOverviewTheme.textDark,
                    height: 1.2,
                  ),
                ),
                if (secondaryName.isNotEmpty) ...[
                  SizedBox(height: 2.th),
                  Text(
                    secondaryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 11.tsp,
                      fontWeight: FontWeight.w500,
                      color: ApprovalsOverviewTheme.textMuted,
                    ),
                  ),
                ],
                SizedBox(height: 6.th),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.tw,
                          vertical: 5.th,
                        ),
                        decoration: BoxDecoration(
                          color: ApprovalsOverviewTheme.screenTintMid
                              .withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(16.tr),
                        ),
                        child: Text(
                          requestNo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 10.tsp,
                            fontWeight: FontWeight.w700,
                            color: ApprovalsOverviewTheme.textDark,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 6.tw),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.tw,
                          vertical: 5.th,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              ApprovalsOverviewTheme.screenMid,
                              ApprovalsOverviewTheme.screenDeep,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16.tr),
                        ),
                        child: Text(
                          branchName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 10.tsp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
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

  Widget _simCell(String label, String value,
      {bool highlight = false, bool inlineLabelValue = false}) {
    final isCompanyNumberLabel = label == 'Company No#' ||
        label == 'Company No.' ||
        label == 'Company Number';
    final isManagerLabel = label == 'New Manager' || label == 'Current Manager';
    final highlightAmount = highlight ||
        label == 'Suggested Increment' ||
        label == 'Suggested By Manager' ||
        label == 'New Salary' ||
        label == 'Last work Date' ||
        label == 'Notice Period Start' ||
        label == 'Resignation Type' ||
        label == 'Last Day of Employee' ||
        label == 'Notice Period' ||
        label == 'Start Hour' ||
        label == 'Duration time' ||
        label == 'Duration Time' ||
        label == 'TP Date' ||
        label == 'Job Mission Type';

    if (isCompanyNumberLabel && !inlineLabelValue) {
      final companyText = SizedBox(
        width: double.infinity,
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$label:\n',
                style: GoogleFonts.poppins(
                  fontSize: 12.tsp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFA0A0A0),
                ),
              ),
              TextSpan(
                text: value,
                style: GoogleFonts.poppins(
                  fontSize: 12.tsp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF202020),
                ),
              ),
            ],
          ),
          textAlign: TextAlign.left,
          textDirection: TextDirection.ltr,
          maxLines: null,
          overflow: TextOverflow.visible,
        ),
      );
      return Align(alignment: Alignment.centerLeft, child: companyText);
    }

    final defaultText = SizedBox(
      width: double.infinity,
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.poppins(
                fontSize: 12.tsp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFA0A0A0),
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.poppins(
                fontSize: 12.tsp,
                fontWeight: FontWeight.w700,
                color: highlightAmount
                    ? const Color(0xFFFF8A00)
                    : const Color(0xFF202020),
              ),
            ),
          ],
        ),
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
        maxLines: null,
        overflow: TextOverflow.visible,
      ),
    );

    return Align(alignment: Alignment.centerLeft, child: defaultText);
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
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
              ),
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

  @override
  Widget build(BuildContext context) {
    final employeeMaps = <Map<String, dynamic>>[_employeeInfo, _formData];
    final requestMaps = <Map<String, dynamic>>[_requestInfo, _formData];

    final requestNo = _pick([
      _pickFromMaps(requestMaps, ['request_no', 'name', 'ref_no']),
    ], fallback: widget.requestId);

    final rawRequestType = _pickFromMaps(
      requestMaps,
      [
        'request_name',
        'request_type',
        'holiday_status_name',
        'holiday_status_id',
        'leave_type',
        'type',
      ],
      fallback: 'HR Management',
    );
    final caseKey = _resolveCaseKey(
      requestName: rawRequestType,
      requestMaps: requestMaps,
    );

    final employeeName = _pick([
      _pickFromMaps(employeeMaps, [
        'employee_name',
        'emp_name',
        'requested_by',
        'requester_name',
      ]),
      _pickFromMaps(employeeMaps, ['employee_id', 'emp_id']),
    ], fallback: 'Employee Name');

    // Additional name for manager or secondary person
    final secondaryName = _pick([
      _pickFromMaps(employeeMaps, [
        'manager_name',
        'parent_id',
        'department_manager',
        'approver_name',
      ]),
    ]);

    final employeeImage = _pick([
      _pickFromMaps(employeeMaps, [
        'employee_image',
        'image_emp',
        'emp_image',
        'employee_img',
        'image',
        'avatar',
        'photo',
        'profile_image',
      ]),
    ]);

    // Log the image URL for debugging
    if (employeeImage.isNotEmpty) {
      print('🟢 Employee Image URL: $employeeImage');
    } else {
      print('🔴 No employee image found in data');
      print('🔴 Available keys: ${_formData.keys.toList()}');
    }

    final employeeDetails = <_DetailItem>[
      _DetailItem('Employee Type',
          _pickFromMaps(employeeMaps, ['type', 'employee_type'])),
      _DetailItem(
          'Section', _pickFromMaps(employeeMaps, ['section', 'department'])),
      _DetailItem('Job Position',
          _pickFromMaps(employeeMaps, ['job_title', 'job_position'])),
      _DetailItem('City/Branch',
          _pickFromMaps(employeeMaps, ['city_id', 'city', 'branch'])),
      _DetailItem('Employee ID',
          _pickFromMaps(employeeMaps, ['emp_id', 'employee_id'])),
      _DetailItem('Joining Date',
          _pickFromMaps(employeeMaps, ['joining_date', 'join_date'])),
      _DetailItem(
          'Total Working Days', _pickFromMaps(employeeMaps, ['working_days'])),
    ].where((item) => item.value.isNotEmpty).toList();

    final detailMaps = <Map<String, dynamic>>[
      _requestInfo,
      _formData,
      _employeeInfo,
    ];
    final requestDetailItems = _buildRequestDetailItems(caseKey, detailMaps);
    final isIncrementRequest =
        caseKey == 'increment' || caseKey == 'salary_increment';
    final isAnnualLeaveRequest = caseKey == 'annual';
    final isParentalLeaveRequest = caseKey == 'parental';
    final isMaternityLeaveRequest = caseKey == 'maternity';
    final isPromotionRequest = caseKey == 'promotion';
    final isCarRentRequest = caseKey == 'car_rent';
    final isTransferRequest = caseKey == 'transfer';
    final isSickLeaveRequest = caseKey == 'sick';
    final isClearanceRequest = caseKey == 'clearance';
    final isShortLeaveRequest = caseKey == 'short';
    final isTemporaryPermissionRequest = caseKey == 'temporary_permission';
    final isEffectiveDateRequest = caseKey == 'effective_date';
    final isJobMissionRequest = caseKey == 'job_mission';
    final isResignationRequest =
        caseKey == 'resignation' || caseKey == 'resign';
    final isTerminationRequest = caseKey == 'termination';
    final isLeaveEncashmentRequest = caseKey == 'leave_encashment';
    final isCertificateRequest =
        caseKey == 'salary_certificate' || caseKey == 'certificate_request';
    final isLoanRequest = caseKey == 'loan';
    final isReferenceLayoutRequest = caseKey == 'sim' ||
        isIncrementRequest ||
        isAnnualLeaveRequest ||
        isParentalLeaveRequest ||
        isMaternityLeaveRequest ||
        isPromotionRequest ||
        isCarRentRequest ||
        isTransferRequest ||
        isSickLeaveRequest ||
        isShortLeaveRequest ||
        isClearanceRequest ||
        isTemporaryPermissionRequest ||
        isEffectiveDateRequest ||
        isJobMissionRequest ||
        isResignationRequest ||
        isTerminationRequest ||
        isLeaveEncashmentRequest ||
        isCertificateRequest ||
        isLoanRequest;

    final userId = ApprovalBloc.resolveActingUserId();
    final rejectionForm = <String, dynamic>{
      ..._formData,
      ..._requestInfo,
    };
    final isRejected =
        _rejectedLocked || ApprovalRejectedBanner.isRejected(rejectionForm);
    final rejectedMessage =
        ApprovalRejectedBanner.messageFromForm(rejectionForm);
    final showActions = widget.showApprovalActions && !isRejected;

    final employeeType =
        _pickFromMaps(employeeMaps, ['type', 'employee_type'], fallback: '-');
    final employeeId =
        _pickFromMaps(employeeMaps, ['emp_id', 'employee_id'], fallback: '-');
    final joiningDate = _formatDateForDisplay(
      _pickFromMaps(employeeMaps, ['joining_date', 'join_date'], fallback: '-'),
    );
    final effectiveDate = _formatDateForDisplay(
      _pickFromMaps(
        requestMaps,
        ['increment_effective_date', 'effective_date'],
        fallback: '-',
      ),
    );
    final loanEffectiveDate = _formatDateForDisplay(
      _pickFromMaps(
        requestMaps,
        ['eos_date', 'effective_date'],
        fallback: '-',
      ),
    );
    final suggestedIncrement = _formatAmountWithAed(
      _pickFromMaps(
        requestMaps,
        ['employee_suggested_salary', 'suggested_increment'],
        fallback: '-',
      ),
    );
    final suggestedByManager = _formatAmountWithAed(
      _pickFromMaps(
        requestMaps,
        ['manager_suggested_salary', 'suggested_by_manager'],
        fallback: '-',
      ),
    );
    final newSalary = _formatAmountWithAed(
      _pickFromMaps(
        requestMaps,
        ['new_salary', 'suggested_total', 'salary_max'],
        fallback: '-',
      ),
    );
    final evaluationScore = _pickFromMaps(
      requestMaps,
      ['evaluation_score', 'overall_score'],
      fallback: '-',
    );
    final workDuration =
        _pickFromMaps(employeeMaps, ['working_days'], fallback: '-');
    final requestedBy = _pickFromMaps(
        requestMaps, ['requested_by', 'requester_name', 'employee_name'],
        fallback: employeeName);
    final companyNo = _pickFromMaps(requestMaps, ['company_no'], fallback: '-');
    final leaveBalance = _pickFromMaps(
      requestMaps,
      ['remaining_leave_days', 'leave_balance', 'balance_leave'],
      fallback: '-',
    );
    final availableDays = _pickFromMaps(
      requestMaps,
      ['available_days'],
      fallback: '-',
    );
    final startHour = _pickFromMaps(
      requestMaps,
      ['start_time', 'hour_from', 'temp_hours'],
      fallback: '-',
    );
    final durationTime = _pickFromMaps(
      requestMaps,
      ['duration_type', 'temp_selection', 'requested_duration', 'duration'],
      fallback: '-',
    );
    final tpDate = _formatDateForDisplay(
      _pickFromMaps(
        requestMaps,
        ['request_date_to', 'end_date', 'start_date', 'request_date_from'],
        fallback: '-',
      ),
    );
    final shortLeaveStartDate = _formatDateForDisplay(
      _pickFromMaps(
        requestMaps,
        ['start_date', 'request_date_from'],
        fallback: '-',
      ),
    );
    final shortLeaveEndDate = _formatDateForDisplay(
      _pickFromMaps(
        requestMaps,
        ['end_date', 'request_date_to'],
        fallback: '-',
      ),
    );
    final shortLeaveDuration = _pickFromMaps(
      requestMaps,
      ['requested_duration', 'duration', 'number_of_days'],
      fallback: '-',
    );
    final shortLeaveBalance = _pickFromMaps(
      requestMaps,
      [
        'leave_balance',
        'remaining_leave_days',
        'balance_leave',
        'available_days',
        'annual_short_leaves_remaining',
      ],
      fallback: '-',
    );
    final annualLeaveStartDate = _formatDateForDisplay(
      _pickFromMaps(
        requestMaps,
        ['start_date', 'request_date_from'],
        fallback: '-',
      ),
    );
    final annualLeaveEndDate = _formatDateForDisplay(
      _pickFromMaps(
        requestMaps,
        ['end_date', 'request_date_to'],
        fallback: '-',
      ),
    );
    final annualLeaveDuration = _pickFromMaps(
      requestMaps,
      ['requested_duration', 'duration', 'number_of_days'],
      fallback: '-',
    );
    final annualLeaveBalance = _pickFromMaps(
      requestMaps,
      ['leave_balance', 'remaining_leave_days', 'balance_leave'],
      fallback: '-',
    );
    final annualLeaveAvailableDays = _pickFromMaps(
      requestMaps,
      ['available_days'],
      fallback: '-',
    );
    final annualShortUsage = _pickFromMaps(
      requestMaps,
      ['annual_short_leaves_remaining'],
      fallback: '-',
    );
    final parentalLeaveStartDate = _formatDateForDisplay(
      _pickFromMaps(
        requestMaps,
        ['start_date', 'request_date_from'],
        fallback: '-',
      ),
    );
    final parentalLeaveEndDate = _formatDateForDisplay(
      _pickFromMaps(
        requestMaps,
        ['end_date', 'request_date_to'],
        fallback: '-',
      ),
    );
    final parentalLeaveDuration = _pickFromMaps(
      requestMaps,
      ['requested_duration', 'duration', 'number_of_days'],
      fallback: '-',
    );
    final promotionEffectiveDate = _formatDateForDisplay(
      _pickFromMaps(
        requestMaps,
        ['effective_date'],
        fallback: '-',
      ),
    );
    final promotionNewJobPosition = _pickFromMaps(
      requestMaps,
      ['new_job', 'new_position', 'new_job_position'],
      fallback: '-',
    );
    final promotionEvaluationScoreRaw = _pickFromMaps(
      requestMaps,
      ['overall_score', 'evaluation_score'],
      fallback: '-',
    );
    final promotionEvaluationScore = promotionEvaluationScoreRaw == '-' ||
            promotionEvaluationScoreRaw.trim().isEmpty ||
            promotionEvaluationScoreRaw.contains('%')
        ? promotionEvaluationScoreRaw
        : '${promotionEvaluationScoreRaw.trim()} %';
    final promotionNewManager = _pickFromMaps(
      requestMaps,
      ['new_manager'],
      fallback: '-',
    );
    final promotionCurrentManager = _pickFromMaps(
      requestMaps,
      ['old_manager', 'current_manager'],
      fallback: '-',
    );
    final carRentCompanyNo = _pickFromMaps(
      detailMaps,
      ['company_no', 'company_number', 'companyno', 'compnay_no'],
      fallback: '-',
    );
    final carRequestType = _pickFromMaps(
      requestMaps,
      ['car_req_type', 'car_request_type'],
      fallback: '-',
    );
    final carRentType = _pickFromMaps(
      requestMaps,
      ['rent_type', 'car_rent_type'],
      fallback: '-',
    );
    final transferType = _pickFromMaps(
      requestMaps,
      ['transfer_type', 'transfer_request_type'],
      fallback: '-',
    );
    final transferNewManager = _pickFromMaps(
      requestMaps,
      ['new_manager'],
      fallback: '-',
    );
    final transferFrom = _pickFromMaps(
      requestMaps,
      ['transfer_from'],
      fallback: '-',
    );
    final transferTo = _pickFromMaps(
      requestMaps,
      ['transfer_to'],
      fallback: '-',
    );
    final transferForman = _pickFromMaps(
      requestMaps,
      ['forman'],
      fallback: '-',
    );
    final maternityLeaveStartDate = _formatDateForDisplay(
      _pickFromMaps(
        requestMaps,
        ['start_date', 'request_date_from'],
        fallback: '-',
      ),
    );
    final maternityLeaveEndDate = _formatDateForDisplay(
      _pickFromMaps(
        requestMaps,
        ['end_date', 'request_date_to'],
        fallback: '-',
      ),
    );
    final maternityLeaveDuration = _pickFromMaps(
      requestMaps,
      ['requested_duration', 'duration', 'number_of_days'],
      fallback: '-',
    );
    final maternityLeaveAvailableDays = _pickFromMaps(
      requestMaps,
      ['available_days'],
      fallback: '-',
    );
    final maternityAnnualShortUsage = _pickFromMaps(
      requestMaps,
      ['annual_short_leaves_remaining'],
      fallback: '-',
    );
    final maternityLeaveBalance = _pickFromMaps(
      requestMaps,
      ['leave_balance', 'remaining_leave_days', 'balance_leave'],
      fallback: '-',
    );
    final sickLeaveStartDate = _formatDateForDisplay(
      _pickFromMaps(
        requestMaps,
        ['start_date', 'request_date_from'],
        fallback: '-',
      ),
    );
    final sickAllowedDays = _pickFromMaps(
      requestMaps,
      ['allowed_sick_days'],
      fallback: '-',
    );
    final sickRefNo = _pickFromMaps(
      requestMaps,
      ['sick_leave_reference', 'sick_leave_reference_no', 'certificate_no'],
      fallback: '-',
    );
    final sickEid = _pickFromMaps(
      requestMaps,
      ['emirates_id'],
      fallback: '-',
    );
    final sickValidationUrl = _pickFromMaps(
      detailMaps,
      [
        'review_validation',
        'review_validation_url',
        'validation_url',
        'review_url',
      ],
    );
    final encashmentStartDate = _formatDateForDisplay(
      _pickFromMaps(
        requestMaps,
        ['start_date', 'request_date_from'],
        fallback: '-',
      ),
    );
    final encashmentEndDate = _formatDateForDisplay(
      _pickFromMaps(
        requestMaps,
        ['request_date_to', 'end_date'],
        fallback: '-',
      ),
    );
    final encashmentDays = _pickFromMaps(
      requestMaps,
      ['encashment_days', 'encash_days'],
      fallback: '-',
    );
    final joinedDateRequest = _formatDateForDisplay(
      _pickFromMaps(
        detailMaps,
        ['joined_date', 'join_date'],
        fallback: '-',
      ),
    );
    final noticePeriodStart = _formatDateForDisplay(
      _pickFromMaps(
        requestMaps,
        ['notice_period_start_date'],
        fallback: '-',
      ),
    );
    final resignationType = _pickFromMaps(
      requestMaps,
      ['resignation_type'],
      fallback: '-',
    );
    final lastDayOfEmployee = _formatDateForDisplay(
      _pickFromMaps(
        requestMaps,
        ['expected_relieving_date', 'emp_last_day'],
        fallback: '-',
      ),
    );
    final noticePeriod = _pickFromMaps(
      requestMaps,
      ['notice_period'],
      fallback: '-',
    );
    final terminationType = _pickFromMaps(
      requestMaps,
      ['termination_type'],
      fallback: '-',
    );
    final terminationReason = _pickFromMaps(
      requestMaps,
      ['termination_reason', 'reason'],
      fallback: '-',
    );
    final terminationExpectedLastDay = _formatDateForDisplay(
      _pickFromMaps(
        requestMaps,
        ['emp_last_day', 'expected_relieving_date', 'end_date'],
        fallback: '-',
      ),
    );
    final terminationCompanyNo = _pickFromMaps(
      detailMaps,
      ['company_no', 'company_number', 'companyno', 'compnay_no'],
      fallback: '-',
    );
    final certificateType = _pickFromMaps(
      requestMaps,
      ['certificate_type', 'document_type'],
      fallback: '-',
    );
    final certificateLanguage = _pickFromMaps(
      requestMaps,
      ['certificate_language', 'language'],
      fallback: '-',
    );
    final loanType = _pickFromMaps(
      requestMaps,
      ['loan_type'],
      fallback: '-',
    );
    final netWorkedDays = _pickFromMaps(
      requestMaps,
      ['net_worked_days'],
      fallback: '-',
    );
    final loanYears = _pickFromMaps(
      requestMaps,
      ['years'],
      fallback: '-',
    );
    final totalAbsentDays = _pickFromMaps(
      requestMaps,
      ['total_absent_days'],
      fallback: '-',
    );
    final totalGratuity = _pickFromMaps(
      requestMaps,
      ['total_gratuity'],
      fallback: '-',
    );
    final loanAmount = _pickFromMaps(
      requestMaps,
      ['loan_amount', 'amount', 'requested_amount'],
      fallback: '-',
    );
    final jobMissionDay = _pickFromMaps(
      requestMaps,
      ['day', 'day_name', 'day_type', 'date_type'],
      fallback: 'Today',
    );
    final jobMissionDuration = _pickFromMaps(
      requestMaps,
      ['duration_type', 'only_afternoon', 'duration'],
      fallback: '-',
    );
    final jobMissionType = _pickFromMaps(
      requestMaps,
      ['job_mission_type', 'job_type'],
      fallback: '-',
    );
    final requestDate = _formatDateForDisplay(
      _pickFromMaps(
        requestMaps,
        [
          'request_date',
          'request_datetime',
          'request_date_from',
          'date',
          'create_date',
        ],
        fallback: '-',
      ),
    );
    final lastWorkDate = _formatDateForDisplay(
      _pickFromMaps(
        requestMaps,
        ['last_work_date', 'end_date', 'expected_relieving_date'],
        fallback: '-',
      ),
    );
    final branchName = _pickFromMaps(
      employeeMaps,
      ['city_id', 'city', 'branch'],
      fallback: '-',
    );
    final comment = _pickFromMaps(
      detailMaps,
      [
        'note',
        'description',
        'comment',
        'discipline_reason',
        'e_reason',
        'reason',
      ],
      fallback: '',
    );
    final attachmentUrl = _pickFromMaps(
      detailMaps,
      [
        'attachment',
        'attachments',
        'sim_attachment',
        'attachment_url',
        'document_url',
        'increment_attachment',
        'salary_increment_attachment',
        'birth_attachment',
        'discharge_report_attachment',
        'gm_attachment',
      ],
    );
    final referenceActionUrl =
        isSickLeaveRequest ? sickValidationUrl : attachmentUrl;
    final hasReferenceAction = _isValidAttachmentUrl(referenceActionUrl);

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
                  title: requestNo.isNotEmpty ? requestNo : 'HR Request',
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
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(
                                          16.tw, 4.th, 16.tw, 0),
                                      child: _referenceRequestHeader(
                                        employeeName: employeeName,
                                        secondaryName: secondaryName,
                                        employeeImage: employeeImage,
                                        requestNo: requestNo,
                                        branchName: branchName.isEmpty
                                            ? '-'
                                            : branchName,
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
                                          showActions
                                              ? 68.th + context.systemBottomInset
                                              : 16.th + context.systemBottomInset,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            if (isRejected) ...[
                                              ApprovalRejectedBanner(
                                                message: rejectedMessage,
                                              ),
                                              SizedBox(height: 8.th),
                                            ],
                                            if (isReferenceLayoutRequest)
                                            Column(
                                                children: [
                                                  _simSectionCard(
                                                    title: 'Employee Summary',
                                                    items: [
                                                      _DetailItem(
                                                          'Employee Type',
                                                          employeeType.isEmpty
                                                              ? '-'
                                                              : employeeType),
                                                      _DetailItem(
                                                          'ID',
                                                          employeeId.isEmpty
                                                              ? '-'
                                                              : employeeId),
                                                      _DetailItem(
                                                          'Joining Date',
                                                          joiningDate.isEmpty
                                                              ? '-'
                                                              : joiningDate),
                                                      _DetailItem(
                                                          'Work Duration',
                                                          workDuration.isEmpty
                                                              ? '-'
                                                              : workDuration),
                                                    ],
                                                  ),
                                                  SizedBox(height: 6.tw),
                                                  _simSectionCard(
                                                    title: 'Request Info',
                                                    items: isIncrementRequest
                                                        ? [
                                                            _DetailItem(
                                                              'Requested By',
                                                              requestedBy
                                                                      .isEmpty
                                                                  ? '-'
                                                                  : requestedBy,
                                                            ),
                                                            _DetailItem(
                                                              'Request Date',
                                                              requestDate
                                                                      .isEmpty
                                                                  ? '-'
                                                                  : requestDate,
                                                            ),
                                                            _DetailItem(
                                                              'Effective Date',
                                                              effectiveDate
                                                                      .isEmpty
                                                                  ? '-'
                                                                  : effectiveDate,
                                                            ),
                                                            _DetailItem(
                                                              'Suggested Increment',
                                                              suggestedIncrement,
                                                            ),
                                                            _DetailItem(
                                                              'Suggested By Manager',
                                                              suggestedByManager,
                                                            ),
                                                            _DetailItem(
                                                              'New Salary',
                                                              newSalary,
                                                            ),
                                                            _DetailItem(
                                                              'Evaluation Score %',
                                                              evaluationScore
                                                                      .isEmpty
                                                                  ? '-'
                                                                  : evaluationScore,
                                                            ),
                                                          ]
                                                        : isAnnualLeaveRequest
                                                            ? [
                                                                _DetailItem(
                                                                  'Requested By',
                                                                  requestedBy
                                                                          .isEmpty
                                                                      ? '-'
                                                                      : requestedBy,
                                                                ),
                                                                _DetailItem(
                                                                  'Request Date',
                                                                  requestDate
                                                                          .isEmpty
                                                                      ? '-'
                                                                      : requestDate,
                                                                ),
                                                                _DetailItem(
                                                                  'Start Date',
                                                                  annualLeaveStartDate
                                                                          .isEmpty
                                                                      ? '-'
                                                                      : annualLeaveStartDate,
                                                                  highlight:
                                                                      true,
                                                                ),
                                                                _DetailItem(
                                                                  'End Date',
                                                                  annualLeaveEndDate
                                                                          .isEmpty
                                                                      ? '-'
                                                                      : annualLeaveEndDate,
                                                                  highlight:
                                                                      true,
                                                                ),
                                                                _DetailItem(
                                                                  'Duration',
                                                                  annualLeaveDuration
                                                                          .isEmpty
                                                                      ? '-'
                                                                      : annualLeaveDuration,
                                                                  highlight:
                                                                      true,
                                                                ),
                                                                _DetailItem(
                                                                  'Balance Leave',
                                                                  annualLeaveBalance
                                                                          .isEmpty
                                                                      ? '-'
                                                                      : annualLeaveBalance,
                                                                  highlight:
                                                                      true,
                                                                ),
                                                                _DetailItem(
                                                                  'Available Days',
                                                                  annualLeaveAvailableDays
                                                                          .isEmpty
                                                                      ? '-'
                                                                      : annualLeaveAvailableDays,
                                                                  highlight:
                                                                      true,
                                                                ),
                                                                _DetailItem(
                                                                  'Annual/Short Usage',
                                                                  annualShortUsage
                                                                          .isEmpty
                                                                      ? '-'
                                                                      : annualShortUsage,
                                                                  highlight:
                                                                      true,
                                                                ),
                                                              ]
                                                            : isParentalLeaveRequest
                                                                ? [
                                                                    _DetailItem(
                                                                      'Requested By',
                                                                      requestedBy
                                                                              .isEmpty
                                                                          ? '-'
                                                                          : requestedBy,
                                                                    ),
                                                                    _DetailItem(
                                                                      'Request Date',
                                                                      requestDate
                                                                              .isEmpty
                                                                          ? '-'
                                                                          : requestDate,
                                                                    ),
                                                                    _DetailItem(
                                                                      'Start Date',
                                                                      parentalLeaveStartDate
                                                                              .isEmpty
                                                                          ? '-'
                                                                          : parentalLeaveStartDate,
                                                                    ),
                                                                    _DetailItem(
                                                                      'End Date',
                                                                      parentalLeaveEndDate
                                                                              .isEmpty
                                                                          ? '-'
                                                                          : parentalLeaveEndDate,
                                                                    ),
                                                                    _DetailItem(
                                                                      'Duration',
                                                                      parentalLeaveDuration
                                                                              .isEmpty
                                                                          ? '-'
                                                                          : parentalLeaveDuration,
                                                                      highlight:
                                                                          true,
                                                                    ),
                                                                  ]
                                                                : isMaternityLeaveRequest
                                                                    ? [
                                                                        _DetailItem(
                                                                          'Requested By',
                                                                          requestedBy.isEmpty
                                                                              ? '-'
                                                                              : requestedBy,
                                                                        ),
                                                                        _DetailItem(
                                                                          'Request Date',
                                                                          requestDate.isEmpty
                                                                              ? '-'
                                                                              : requestDate,
                                                                        ),
                                                                        _DetailItem(
                                                                          'Start Date',
                                                                          maternityLeaveStartDate.isEmpty
                                                                              ? '-'
                                                                              : maternityLeaveStartDate,
                                                                        ),
                                                                        _DetailItem(
                                                                          'Duration',
                                                                          maternityLeaveDuration.isEmpty
                                                                              ? '-'
                                                                              : maternityLeaveDuration,
                                                                          highlight:
                                                                              true,
                                                                        ),
                                                                        _DetailItem(
                                                                          'Available Days',
                                                                          maternityLeaveAvailableDays.isEmpty
                                                                              ? '-'
                                                                              : maternityLeaveAvailableDays,
                                                                          highlight:
                                                                              true,
                                                                        ),
                                                                        _DetailItem(
                                                                          'End Date',
                                                                          maternityLeaveEndDate.isEmpty
                                                                              ? '-'
                                                                              : maternityLeaveEndDate,
                                                                        ),
                                                                        _DetailItem(
                                                                          'Annual/Short Usage',
                                                                          maternityAnnualShortUsage.isEmpty
                                                                              ? '-'
                                                                              : maternityAnnualShortUsage,
                                                                          highlight:
                                                                              true,
                                                                        ),
                                                                        _DetailItem(
                                                                          'Leave Balance',
                                                                          maternityLeaveBalance.isEmpty
                                                                              ? '-'
                                                                              : maternityLeaveBalance,
                                                                          highlight:
                                                                              true,
                                                                        ),
                                                                      ]
                                                                    : isPromotionRequest
                                                                        ? [
                                                                            _DetailItem(
                                                                              'Requested By',
                                                                              requestedBy.isEmpty ? '-' : requestedBy,
                                                                            ),
                                                                            _DetailItem(
                                                                              'Effective Date',
                                                                              promotionEffectiveDate.isEmpty ? '-' : promotionEffectiveDate,
                                                                            ),
                                                                            _DetailItem(
                                                                              'Request Date',
                                                                              requestDate.isEmpty ? '-' : requestDate,
                                                                            ),
                                                                            _DetailItem(
                                                                              'New Jon Position',
                                                                              promotionNewJobPosition.isEmpty ? '-' : promotionNewJobPosition,
                                                                              highlight: true,
                                                                            ),
                                                                            _DetailItem(
                                                                              'Evaluation Score',
                                                                              promotionEvaluationScore.isEmpty ? '-' : promotionEvaluationScore,
                                                                              pairWithEmpty: true,
                                                                            ),
                                                                            _DetailItem(
                                                                              'New Manager',
                                                                              promotionNewManager.isEmpty ? '-' : promotionNewManager,
                                                                              highlight: true,
                                                                              fullWidth: true,
                                                                            ),
                                                                            _DetailItem(
                                                                              'Current Manager',
                                                                              promotionCurrentManager.isEmpty ? '-' : promotionCurrentManager,
                                                                              highlight: true,
                                                                              fullWidth: true,
                                                                            ),
                                                                          ]
                                                                        : isCarRentRequest
                                                                            ? [
                                                                                _DetailItem(
                                                                                  'Requested By',
                                                                                  requestedBy.isEmpty ? '-' : requestedBy,
                                                                                ),
                                                                                _DetailItem(
                                                                                  'Company No#',
                                                                                  carRentCompanyNo == '-' ? '__________' : carRentCompanyNo,
                                                                                  inlineLabelValue: true,
                                                                                ),
                                                                                _DetailItem(
                                                                                  'Request Date',
                                                                                  requestDate.isEmpty ? '-' : requestDate,
                                                                                ),
                                                                                _DetailItem(
                                                                                  'Car Request Type',
                                                                                  carRequestType.isEmpty ? '-' : carRequestType,
                                                                                  highlight: true,
                                                                                ),
                                                                                _DetailItem(
                                                                                  'Rent Type',
                                                                                  carRentType.isEmpty ? '-' : carRentType,
                                                                                  highlight: true,
                                                                                  pairWithEmpty: true,
                                                                                ),
                                                                              ]
                                                                            : isSickLeaveRequest
                                                                                ? [
                                                                                    _DetailItem(
                                                                                      'Requested By',
                                                                                      requestedBy.isEmpty ? '-' : requestedBy,
                                                                                    ),
                                                                                    _DetailItem(
                                                                                      'Request Date',
                                                                                      requestDate.isEmpty ? '-' : requestDate,
                                                                                    ),
                                                                                    _DetailItem(
                                                                                      'Start Date',
                                                                                      sickLeaveStartDate.isEmpty ? '-' : sickLeaveStartDate,
                                                                                    ),
                                                                                    _DetailItem(
                                                                                      'Allow Sick Days',
                                                                                      sickAllowedDays.isEmpty ? '-' : sickAllowedDays,
                                                                                    ),
                                                                                    _DetailItem(
                                                                                      'Ref No#',
                                                                                      sickRefNo.isEmpty ? '-' : sickRefNo,
                                                                                    ),
                                                                                    _DetailItem(
                                                                                      'EID',
                                                                                      sickEid.isEmpty ? '-' : sickEid,
                                                                                      highlight: true,
                                                                                    ),
                                                                                  ]
                                                                                : isShortLeaveRequest
                                                                                    ? [
                                                                                        _DetailItem(
                                                                                          'Requested By',
                                                                                          requestedBy.isEmpty ? '-' : requestedBy,
                                                                                        ),
                                                                                        _DetailItem(
                                                                                          'Request Date',
                                                                                          requestDate.isEmpty ? '-' : requestDate,
                                                                                        ),
                                                                                        _DetailItem(
                                                                                          'Start Date',
                                                                                          shortLeaveStartDate.isEmpty ? '-' : shortLeaveStartDate,
                                                                                          highlight: true,
                                                                                        ),
                                                                                        _DetailItem(
                                                                                          'End Date',
                                                                                          shortLeaveEndDate.isEmpty ? '-' : shortLeaveEndDate,
                                                                                          highlight: true,
                                                                                        ),
                                                                                        _DetailItem(
                                                                                          'Duration',
                                                                                          shortLeaveDuration.isEmpty ? '-' : shortLeaveDuration,
                                                                                          highlight: true,
                                                                                        ),
                                                                                        _DetailItem(
                                                                                          'Balance Leave',
                                                                                          shortLeaveBalance.isEmpty ? '-' : shortLeaveBalance,
                                                                                          highlight: true,
                                                                                        ),
                                                                                      ]
                                                                                    : isTemporaryPermissionRequest
                                                                                        ? [
                                                                                            _DetailItem(
                                                                                              'Requested By',
                                                                                              requestedBy.isEmpty ? '-' : requestedBy,
                                                                                            ),
                                                                                            _DetailItem(
                                                                                              'Request Date',
                                                                                              requestDate.isEmpty ? '-' : requestDate,
                                                                                            ),
                                                                                            _DetailItem(
                                                                                              'Leave Balance',
                                                                                              leaveBalance.isEmpty ? '-' : leaveBalance,
                                                                                            ),
                                                                                            _DetailItem(
                                                                                              'Available Days',
                                                                                              availableDays.isEmpty ? '-' : availableDays,
                                                                                            ),
                                                                                            _DetailItem(
                                                                                              'Start Hour',
                                                                                              startHour.isEmpty ? '-' : startHour,
                                                                                            ),
                                                                                            _DetailItem(
                                                                                              'Duration Time',
                                                                                              durationTime.isEmpty ? '-' : durationTime,
                                                                                            ),
                                                                                            _DetailItem(
                                                                                              'TP Date',
                                                                                              tpDate.isEmpty ? '-' : tpDate,
                                                                                            ),
                                                                                          ]
                                                                                        : isLeaveEncashmentRequest
                                                                                            ? [
                                                                                                _DetailItem(
                                                                                                  'Requested By',
                                                                                                  requestedBy.isEmpty ? '-' : requestedBy,
                                                                                                ),
                                                                                                _DetailItem(
                                                                                                  'Request Date',
                                                                                                  requestDate.isEmpty ? '-' : requestDate,
                                                                                                ),
                                                                                                _DetailItem(
                                                                                                  'Start Date',
                                                                                                  encashmentStartDate.isEmpty ? '-' : encashmentStartDate,
                                                                                                ),
                                                                                                _DetailItem(
                                                                                                  'End Date',
                                                                                                  encashmentEndDate.isEmpty ? '-' : encashmentEndDate,
                                                                                                ),
                                                                                                _DetailItem(
                                                                                                  'Available Days',
                                                                                                  availableDays.isEmpty ? '-' : availableDays,
                                                                                                  highlight: true,
                                                                                                ),
                                                                                                _DetailItem(
                                                                                                  'Encashment Days',
                                                                                                  encashmentDays.isEmpty ? '-' : encashmentDays,
                                                                                                  highlight: true,
                                                                                                ),
                                                                                                _DetailItem(
                                                                                                  'Leave Balance',
                                                                                                  leaveBalance.isEmpty ? '-' : leaveBalance,
                                                                                                ),
                                                                                              ]
                                                                                            : isCertificateRequest
                                                                                                ? [
                                                                                                    _DetailItem(
                                                                                                      'Requested By',
                                                                                                      requestedBy.isEmpty ? '-' : requestedBy,
                                                                                                    ),
                                                                                                    _DetailItem(
                                                                                                      'Request Date',
                                                                                                      requestDate.isEmpty ? '-' : requestDate,
                                                                                                    ),
                                                                                                    _DetailItem(
                                                                                                      'Certificate Type',
                                                                                                      certificateType.isEmpty ? '-' : certificateType,
                                                                                                      highlight: true,
                                                                                                    ),
                                                                                                    _DetailItem(
                                                                                                      'Language',
                                                                                                      certificateLanguage.isEmpty ? '-' : certificateLanguage,
                                                                                                      highlight: true,
                                                                                                    ),
                                                                                                  ]
                                                                                                : isLoanRequest
                                                                                                    ? [
                                                                                                        _DetailItem(
                                                                                                          'Requested By',
                                                                                                          requestedBy.isEmpty ? '-' : requestedBy,
                                                                                                        ),
                                                                                                        _DetailItem(
                                                                                                          'Request Date',
                                                                                                          requestDate.isEmpty ? '-' : requestDate,
                                                                                                        ),
                                                                                                        _DetailItem(
                                                                                                          'Effective Date',
                                                                                                          loanEffectiveDate.isEmpty ? '-' : loanEffectiveDate,
                                                                                                        ),
                                                                                                        _DetailItem(
                                                                                                          'Loan Type',
                                                                                                          loanType.isEmpty ? '-' : loanType,
                                                                                                          highlight: true,
                                                                                                        ),
                                                                                                        _DetailItem(
                                                                                                          'Net Worked Days',
                                                                                                          netWorkedDays.isEmpty ? '-' : netWorkedDays,
                                                                                                        ),
                                                                                                        _DetailItem(
                                                                                                          'Years',
                                                                                                          loanYears.isEmpty ? '-' : loanYears,
                                                                                                          highlight: true,
                                                                                                        ),
                                                                                                        _DetailItem(
                                                                                                          'Total Absent Days',
                                                                                                          totalAbsentDays.isEmpty ? '-' : totalAbsentDays,
                                                                                                        ),
                                                                                                        _DetailItem(
                                                                                                          'Total Gratuity',
                                                                                                          totalGratuity.isEmpty ? '-' : totalGratuity,
                                                                                                          highlight: true,
                                                                                                        ),
                                                                                                        _DetailItem(
                                                                                                          'Loan Amount',
                                                                                                          loanAmount.isEmpty ? '-' : loanAmount,
                                                                                                        ),
                                                                                                      ]
                                                                                                    : isJobMissionRequest
                                                                                                        ? [
                                                                                                            _DetailItem(
                                                                                                              'Requested By',
                                                                                                              requestedBy.isEmpty ? '-' : requestedBy,
                                                                                                            ),
                                                                                                            _DetailItem(
                                                                                                              'Request Date',
                                                                                                              requestDate.isEmpty ? '-' : requestDate,
                                                                                                            ),
                                                                                                            _DetailItem(
                                                                                                              'Joined Date',
                                                                                                              joiningDate.isEmpty ? '-' : joiningDate,
                                                                                                            ),
                                                                                                            _DetailItem(
                                                                                                              'Day',
                                                                                                              jobMissionDay.isEmpty ? '-' : jobMissionDay,
                                                                                                            ),
                                                                                                            _DetailItem(
                                                                                                              'Duration time',
                                                                                                              jobMissionDuration.isEmpty ? '-' : jobMissionDuration,
                                                                                                            ),
                                                                                                            _DetailItem(
                                                                                                              'Job Mission Type',
                                                                                                              jobMissionType.isEmpty ? '-' : jobMissionType,
                                                                                                            ),
                                                                                                          ]
                                                                                                        : isTransferRequest
                                                                                                            ? [
                                                                                                                _DetailItem(
                                                                                                                  'Requested By',
                                                                                                                  requestedBy.isEmpty ? '-' : requestedBy,
                                                                                                                ),
                                                                                                                _DetailItem(
                                                                                                                  'Type',
                                                                                                                  transferType.isEmpty ? '-' : transferType,
                                                                                                                ),
                                                                                                                _DetailItem(
                                                                                                                  'Request Date',
                                                                                                                  requestDate.isEmpty ? '-' : requestDate,
                                                                                                                  pairWithEmpty: true,
                                                                                                                ),
                                                                                                                _DetailItem(
                                                                                                                  'New Transfer Manager',
                                                                                                                  transferNewManager.isEmpty ? '-' : transferNewManager,
                                                                                                                  fullWidth: true,
                                                                                                                ),
                                                                                                                _DetailItem(
                                                                                                                  'transfer From',
                                                                                                                  transferFrom.isEmpty ? '-' : transferFrom,
                                                                                                                  fullWidth: true,
                                                                                                                ),
                                                                                                                _DetailItem(
                                                                                                                  'transfer To',
                                                                                                                  transferTo.isEmpty ? '-' : transferTo,
                                                                                                                  highlight: true,
                                                                                                                  fullWidth: true,
                                                                                                                ),
                                                                                                                _DetailItem(
                                                                                                                  'Forman',
                                                                                                                  transferForman.isEmpty ? '-' : transferForman,
                                                                                                                  fullWidth: true,
                                                                                                                ),
                                                                                                              ]
                                                                                                            : isResignationRequest
                                                                                                                ? [
                                                                                                                    _DetailItem(
                                                                                                                      'Requested By',
                                                                                                                      requestedBy.isEmpty ? '-' : requestedBy,
                                                                                                                    ),
                                                                                                                    _DetailItem(
                                                                                                                      'Request Date',
                                                                                                                      requestDate.isEmpty ? '-' : requestDate,
                                                                                                                    ),
                                                                                                                    _DetailItem(
                                                                                                                      'Notice Period Start',
                                                                                                                      noticePeriodStart.isEmpty ? '-' : noticePeriodStart,
                                                                                                                    ),
                                                                                                                    _DetailItem(
                                                                                                                      'Resignation Type',
                                                                                                                      resignationType.isEmpty ? '-' : resignationType,
                                                                                                                    ),
                                                                                                                    _DetailItem(
                                                                                                                      'Last Day of Employee',
                                                                                                                      lastDayOfEmployee.isEmpty ? '-' : lastDayOfEmployee,
                                                                                                                    ),
                                                                                                                    _DetailItem(
                                                                                                                      'Notice Period',
                                                                                                                      noticePeriod.isEmpty ? '-' : noticePeriod,
                                                                                                                    ),
                                                                                                                  ]
                                                                                                                : isTerminationRequest
                                                                                                                    ? [
                                                                                                                        _DetailItem(
                                                                                                                          'Requested By',
                                                                                                                          requestedBy.isEmpty ? '-' : requestedBy,
                                                                                                                        ),
                                                                                                                        _DetailItem(
                                                                                                                          'Company No#',
                                                                                                                          terminationCompanyNo == '-' ? '__________' : terminationCompanyNo.replaceAll(RegExp(r'\s+'), ''),
                                                                                                                        ),
                                                                                                                        _DetailItem(
                                                                                                                          'Request Date',
                                                                                                                          requestDate.isEmpty ? '-' : requestDate,
                                                                                                                        ),
                                                                                                                        _DetailItem(
                                                                                                                          'Termination Type',
                                                                                                                          terminationType.isEmpty ? '-' : terminationType,
                                                                                                                          highlight: true,
                                                                                                                        ),
                                                                                                                        _DetailItem(
                                                                                                                          'Reason',
                                                                                                                          terminationReason.isEmpty ? '-' : terminationReason,
                                                                                                                          highlight: true,
                                                                                                                        ),
                                                                                                                        _DetailItem(
                                                                                                                          'Expected Last Day',
                                                                                                                          terminationExpectedLastDay.isEmpty ? '-' : terminationExpectedLastDay,
                                                                                                                          highlight: true,
                                                                                                                        ),
                                                                                                                      ]
                                                                                                                    : isEffectiveDateRequest
                                                                                                                        ? [
                                                                                                                            _DetailItem(
                                                                                                                              'Requested By',
                                                                                                                              requestedBy.isEmpty ? '-' : requestedBy,
                                                                                                                            ),
                                                                                                                            _DetailItem(
                                                                                                                              'Request Date',
                                                                                                                              requestDate.isEmpty ? '-' : requestDate,
                                                                                                                            ),
                                                                                                                            _DetailItem(
                                                                                                                              'Joined Date',
                                                                                                                              joinedDateRequest.isEmpty ? '-' : joinedDateRequest,
                                                                                                                            ),
                                                                                                                          ]
                                                                                                                        : isClearanceRequest
                                                                                                                            ? [
                                                                                                                                _DetailItem(
                                                                                                                                  'Requested By',
                                                                                                                                  requestedBy.isEmpty ? '-' : requestedBy,
                                                                                                                                ),
                                                                                                                                _DetailItem(
                                                                                                                                  'Request Date',
                                                                                                                                  requestDate.isEmpty ? '-' : requestDate,
                                                                                                                                ),
                                                                                                                                _DetailItem(
                                                                                                                                  'Last work Date',
                                                                                                                                  lastWorkDate.isEmpty ? '-' : lastWorkDate,
                                                                                                                                ),
                                                                                                                              ]
                                                                                                                            : [
                                                                                                                                _DetailItem(
                                                                                                                                  'Requested By',
                                                                                                                                  requestedBy.isEmpty ? '-' : requestedBy,
                                                                                                                                ),
                                                                                                                                _DetailItem(
                                                                                                                                  'Company No.',
                                                                                                                                  companyNo.isEmpty ? '-' : companyNo,
                                                                                                                                ),
                                                                                                                                _DetailItem(
                                                                                                                                  'Request Date',
                                                                                                                                  requestDate.isEmpty ? '-' : requestDate,
                                                                                                                                ),
                                                                                                                              ],
                                                  ),
                                                  SizedBox(height: 6.tw),
                                                  _buildSimCommentCard(comment),
                                                  if (hasReferenceAction) ...[
                                                    SizedBox(height: 16.tw),
                                                    SizedBox(
                                                      width: 0.88.sw,
                                                      child: InkWell(
                                                        onTap: isSickLeaveRequest
                                                            ? () => _openValidationUrl(
                                                                referenceActionUrl)
                                                            : () => _openAttachmentUrl(
                                                                referenceActionUrl),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(14.tr),
                                                        child: Container(
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                                  vertical:
                                                                      13.tw),
                                                          decoration:
                                                              BoxDecoration(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        14.tr),
                                                            gradient:
                                                                const LinearGradient(
                                                              begin: Alignment
                                                                  .topCenter,
                                                              end: Alignment
                                                                  .bottomCenter,
                                                              colors: [
                                                                Color(
                                                                    0xFF777B84),
                                                                Color(
                                                                    0xFF63676F),
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
                                                                color: Colors
                                                                    .white,
                                                                size: 20.tsp,
                                                              ),
                                                              SizedBox(
                                                                  width: 6.tw),
                                                              Text(
                                                                isSickLeaveRequest
                                                                    ? 'Review Sick Leave'
                                                                    : 'View Attachments',
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  fontSize:
                                                                      14.tsp,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  SizedBox(height: 8.tw),
                                                ],
                                              )
                                            else
                                              Column(
                                                children: [
                                                  _card(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Center(
                                                            child: _label(
                                                                'Employee Details')),
                                                        SizedBox(height: 12.tw),
                                                        if (employeeDetails
                                                            .isEmpty)
                                                          _value(
                                                              'No employee details available',
                                                              size: 12.tsp,
                                                              weight: FontWeight
                                                                  .w500,
                                                              color: const Color(
                                                                  0xFF6E6E6E))
                                                        else
                                                          for (int i = 0;
                                                              i <
                                                                  employeeDetails
                                                                      .length;
                                                              i++) ...[
                                                            _detailRow(
                                                                employeeDetails[
                                                                        i]
                                                                    .label,
                                                                employeeDetails[
                                                                        i]
                                                                    .value),
                                                            if (i !=
                                                                employeeDetails
                                                                        .length -
                                                                    1)
                                                              const Divider(
                                                                color: Color(
                                                                    0xFFE0E0E0),
                                                                height: 1,
                                                              ),
                                                          ],
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(height: 6.tw),
                                                  _card(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Center(
                                                            child: _label(
                                                                'Request Details')),
                                                        SizedBox(height: 12.tw),
                                                        if (requestDetailItems
                                                            .isEmpty)
                                                          _value(
                                                              'No request-specific details available',
                                                              size: 12.tsp,
                                                              weight: FontWeight
                                                                  .w500,
                                                              color: const Color(
                                                                  0xFF6E6E6E))
                                                        else
                                                          for (int i = 0;
                                                              i <
                                                                  requestDetailItems
                                                                      .length;
                                                              i++) ...[
                                                            requestDetailItems[
                                                                            i]
                                                                        .label ==
                                                                    'Validation'
                                                                ? _validationActionBox(
                                                                    requestDetailItems[
                                                                            i]
                                                                        .value,
                                                                  )
                                                                : requestDetailItems[i].label ==
                                                                            'GM Attachment' ||
                                                                        requestDetailItems[i].label ==
                                                                            'Birth Attachment'
                                                                    ? _attachmentActionBox(
                                                                        requestDetailItems[i]
                                                                            .value,
                                                                        label: requestDetailItems[i]
                                                                            .label,
                                                                      )
                                                                    : requestDetailItems[i]
                                                                            .multiline
                                                                        ? _detailDescriptionBox(
                                                                            requestDetailItems[i].label,
                                                                            requestDetailItems[i].value,
                                                                          )
                                                                        : _detailRow(
                                                                            requestDetailItems[i].label,
                                                                            requestDetailItems[i].value,
                                                                          ),
                                                            if (i !=
                                                                requestDetailItems
                                                                        .length -
                                                                    1)
                                                              const Divider(
                                                                color: Color(
                                                                    0xFFE0E0E0),
                                                                height: 1,
                                                              ),
                                                          ],
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(height: 8.tw),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (showActions)
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

class _FieldDef {
  const _FieldDef(this.label, this.keys, {this.multiline = false});

  final String label;
  final List<String> keys;
  final bool multiline;
}

class _DetailItem {
  const _DetailItem(
    this.label,
    this.value, {
    this.multiline = false,
    this.highlight = false,
    this.fullWidth = false,
    this.pairWithEmpty = false,
    this.inlineLabelValue = false,
  });

  final String label;
  final String value;
  final bool multiline;
  final bool highlight;
  final bool fullWidth;
  final bool pairWithEmpty;
  final bool inlineLabelValue;
}
