import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_documents/screens/family_document_attach_screen.dart';
import 'package:el_race/ui/presentation/my_documents/utils/family_insurance_draft_store.dart';
import 'package:el_race/ui/presentation/my_documents/widgets/my_documents_silk_background.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_glass_header.dart';
import 'package:el_race/utils/urll_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

const Color _skyAccent = Color(0xFF7EB6D9);
const Color _greenAccent = Color(0xFF1F7A4D);
const Color _navy = Color(0xFF1E2365);

/// Family document request hub (wizard-aligned).
///
/// Collects member DOB/nationality, attaches each required support doc, then
/// calls `/api/family_insurance/submit` (Odoo `action_submit_request`).
class FamilyAddDocumentScreen extends StatefulWidget {
  const FamilyAddDocumentScreen({
    super.key,
    this.initialMemberKey = 'spouse',
  });

  final String initialMemberKey;

  @override
  State<FamilyAddDocumentScreen> createState() =>
      _FamilyAddDocumentScreenState();
}

class _FamilyAddDocumentScreenState extends State<FamilyAddDocumentScreen> {
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();

  late String _memberKey;
  String? _selectedCaseKey;
  int? _selectedNationalityId;
  DateTime? _dob;

  bool _loadingInit = true;
  bool _submitting = false;
  bool _savingDraft = false;
  bool _draftRestored = false;
  String? _initError;

  final List<_FamUpdateCase> _updateCases = [];
  final List<_NationalityOption> _nationalities = [];
  final List<_FamDocReq> _requiredDocs = [];
  final Map<String, _PickedFile> _pickedFiles = {};
  final Map<String, DateTime> _docExpiryDates = {};

  String get _employeeKey {
    final data = SharedPref.getLoginData().result?.data;
    final empId = (data?.emp_id ?? '').toString().trim();
    if (empId.isNotEmpty) return empId;
    final employeeId = data?.employee_id;
    if (employeeId != null) return employeeId.toString();
    final uid = data?.odoo_user_id;
    if (uid != null) return uid.toString();
    return 'unknown';
  }

  /// Init API accepts only spouse | child.
  String get _initMemberParam =>
      _memberKey == 'spouse' || _memberKey == 'wife' ? 'spouse' : 'child';

  @override
  void initState() {
    super.initState();
    _memberKey = _normalizeMember(widget.initialMemberKey);
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  String _normalizeMember(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == 'child' ||
        v == 'child_1' ||
        v == 'child_2' ||
        v == 'child_3' ||
        v == 'children') {
      return 'child_1';
    }
    if (v == 'wife') return 'spouse';
    return 'spouse';
  }

  String _normalizeToken(dynamic value) {
    return (value ?? '')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Future<void> _bootstrap() async {
    final draft = await FamilyInsuranceDraftStore.load();
    if (!mounted) return;
    if (draft != null &&
        draft.familyMember.isNotEmpty &&
        draft.medicalRequestCase.isNotEmpty) {
      _applyDraftMeta(draft);
      _draftRestored = true;
      await _loadInit(restoreCaseKey: draft.medicalRequestCase);
      if (!mounted) return;
      _applyDraftAttachments(draft);
      setState(() {});
      return;
    }
    await _loadInit();
  }

  void _applyDraftMeta(FamilyInsuranceDraft draft) {
    _memberKey = _normalizeMember(draft.familyMember);
    _selectedCaseKey = draft.medicalRequestCase;
    _nameController.text = draft.memberName;
    _selectedNationalityId = draft.nationalityId;
    if ((draft.dobIso ?? '').isNotEmpty) {
      final parsed = DateTime.tryParse(draft.dobIso!);
      if (parsed != null) {
        _dob = parsed;
        _dobController.text = DateFormat('dd/MM/yyyy').format(parsed);
      }
    }
  }

  void _applyDraftAttachments(FamilyInsuranceDraft draft) {
    _pickedFiles.clear();
    _docExpiryDates.clear();
    draft.attachments.forEach((field, att) {
      if (att.path.isEmpty) return;
      _pickedFiles[field] = _PickedFile(path: att.path, filename: att.filename);
      if ((att.expiryIso ?? '').isNotEmpty) {
        final d = DateTime.tryParse(att.expiryIso!);
        if (d != null) _docExpiryDates[field] = d;
      }
    });
  }

  Future<void> _onMemberChanged(String key) async {
    final normalized = _normalizeMember(key);
    if (normalized == _memberKey && _updateCases.isNotEmpty) return;
    setState(() {
      _memberKey = normalized;
      _selectedCaseKey = null;
      _updateCases.clear();
      _nationalities.clear();
      _requiredDocs.clear();
      _pickedFiles.clear();
      _docExpiryDates.clear();
      _loadingInit = true;
      _initError = null;
      _draftRestored = false;
    });
    await _loadInit();
  }

  Future<void> _loadInit({String? restoreCaseKey}) async {
    setState(() {
      _loadingInit = true;
      _initError = null;
    });

    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      if (token.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loadingInit = false;
          _initError = 'Session expired. Please login again.';
        });
        return;
      }

      final response = await http.post(
        Uri.parse('${UrlUtil.baseUrl}family_insurance/init'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'params': {'family_member': _initMemberParam},
        }),
      );

      if (response.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          _loadingInit = false;
          _initError = 'Failed to load document update options.';
        });
        return;
      }

      final decoded = jsonDecode(response.body);
      final result = _extractResultMap(decoded);
      if (result == null) {
        if (!mounted) return;
        setState(() {
          _loadingInit = false;
          _initError = 'Invalid init response.';
        });
        return;
      }

      final status = _normalizeToken(result['status']);
      if (!(status == 'success' || status == 'ok' || status == 'true')) {
        if (!mounted) return;
        setState(() {
          _loadingInit = false;
          _initError =
              (result['message'] ?? 'Failed to load document update options.')
                  .toString();
        });
        return;
      }

      final data = result['data'] is Map
          ? Map<String, dynamic>.from(result['data'] as Map)
          : <String, dynamic>{};

      final cases = <_FamUpdateCase>[];
      final casesRaw = data['medical_request_cases'];
      if (casesRaw is List) {
        for (final raw in casesRaw) {
          if (raw is! Map) continue;
          final map = Map<String, dynamic>.from(raw);
          final caseKey = (map['case_key'] ?? '').toString().trim();
          final caseLabel = (map['case_label'] ?? caseKey).toString().trim();
          if (caseKey.isEmpty) continue;
          final docs = <_FamDocReq>[];
          final docsRaw = map['required_documents'];
          if (docsRaw is List) {
            for (final d in docsRaw) {
              if (d is! Map) continue;
              final dm = Map<String, dynamic>.from(d);
              final field = (dm['field'] ?? '').toString().trim();
              if (field.isEmpty) continue;
              docs.add(
                _FamDocReq(
                  field: field,
                  label: (dm['label'] ?? dm['name'] ?? field).toString().trim(),
                  type: (dm['type'] ?? '').toString().trim(),
                ),
              );
            }
          }
          cases.add(
            _FamUpdateCase(
              key: caseKey,
              label: caseLabel.isEmpty ? caseKey : caseLabel,
              documents: docs,
            ),
          );
        }
      }

      final nationalities = <_NationalityOption>[];
      final natRaw = data['nationalities'];
      if (natRaw is List) {
        for (final item in natRaw) {
          if (item is! Map) continue;
          final map = Map<String, dynamic>.from(item);
          final id = int.tryParse((map['id'] ?? '').toString());
          final name = (map['name'] ?? '').toString().trim();
          if (id == null || name.isEmpty) continue;
          nationalities.add(_NationalityOption(id: id, name: name));
        }
      }

      String? nextCase = restoreCaseKey;
      if (nextCase == null || !cases.any((c) => c.key == nextCase)) {
        nextCase = cases.isNotEmpty ? cases.first.key : null;
      }

      final keepNat = _selectedNationalityId;
      final resolvedNat = keepNat != null &&
              nationalities.any((n) => n.id == keepNat)
          ? keepNat
          : nationalities
              .where((n) => n.id == 233)
              .map((n) => n.id)
              .cast<int?>()
              .firstWhere(
                (id) => id != null,
                orElse: () =>
                    nationalities.isNotEmpty ? nationalities.first.id : null,
              );

      if (!mounted) return;
      setState(() {
        _updateCases
          ..clear()
          ..addAll(cases);
        _nationalities
          ..clear()
          ..addAll(nationalities);
        _selectedCaseKey = nextCase;
        _selectedNationalityId = resolvedNat;
        _loadingInit = false;
        _initError =
            cases.isEmpty ? 'No document update options available.' : null;
      });
      _syncRequiredDocs();
    } catch (e) {
      debugPrint('Failed to load family_insurance/init: $e');
      if (!mounted) return;
      setState(() {
        _loadingInit = false;
        _initError = 'Failed to load document update options.';
      });
    }
  }

  Map<String, dynamic>? _extractResultMap(dynamic decoded) {
    if (decoded is! Map) return null;
    if (decoded['result'] is Map) {
      return Map<String, dynamic>.from(decoded['result'] as Map);
    }
    if (decoded['status'] != null || decoded['data'] != null) {
      return Map<String, dynamic>.from(decoded);
    }
    return null;
  }

  void _syncRequiredDocs() {
    final selected =
        _updateCases.where((c) => c.key == _selectedCaseKey).toList();
    final docs = selected.isNotEmpty
        ? List<_FamDocReq>.from(selected.first.documents)
        : <_FamDocReq>[];
    final active = docs.map((d) => d.field).toSet();
    _pickedFiles.removeWhere((k, _) => !active.contains(k));
    _docExpiryDates.removeWhere((k, _) => !active.contains(k));
    setState(() {
      _requiredDocs
        ..clear()
        ..addAll(docs);
    });
  }

  _FamUpdateCase? get _selectedCase {
    for (final c in _updateCases) {
      if (c.key == _selectedCaseKey) return c;
    }
    return null;
  }

  int get _attachedCount => _requiredDocs.where((d) {
        return _pickedFiles.containsKey(d.field) &&
            _docExpiryDates[d.field] != null;
      }).length;

  bool get _allDocsAttached {
    if (_requiredDocs.isEmpty) return false;
    for (final req in _requiredDocs) {
      if (!_pickedFiles.containsKey(req.field)) return false;
      if (_docExpiryDates[req.field] == null) return false;
    }
    return true;
  }

  bool get _canSubmit {
    if (_nameController.text.trim().isEmpty) return false;
    if (_dob == null) return false;
    if (_selectedNationalityId == null) return false;
    if ((_selectedCaseKey ?? '').isEmpty) return false;
    if (_validateMemberDetails() != null) return false;
    return _allDocsAttached && _validateAllExpiries() == null;
  }

  DateTime get _todayDate {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool _allowsPastExpiry(String field) {
    final f = field.toLowerCase();
    return f.contains('birth_certificate') || f.contains('marriage_certificate');
  }

  int _ageYears(DateTime dob) {
    final today = _todayDate;
    var age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age -= 1;
    }
    return age;
  }

  String? _validateDob(DateTime dob) {
    final day = DateTime(dob.year, dob.month, dob.day);
    if (day.isAfter(_todayDate)) {
      return 'Date of birth cannot be in the future.';
    }
    final age = _ageYears(day);
    if (_memberKey == 'spouse') {
      if (age > 50) return 'Wife age must be 50 years old or below.';
      if (age < 16) return 'Spouse age looks invalid. Please check DOB.';
    } else {
      if (age > 18) return 'Children age must be 18 years old or below.';
      if (age < 0) return 'Date of birth cannot be in the future.';
    }
    return null;
  }

  String? _validateExpiryForField(String field, DateTime expiry) {
    final day = DateTime(expiry.year, expiry.month, expiry.day);
    if (_allowsPastExpiry(field)) {
      if (day.isAfter(DateTime(_todayDate.year + 40, _todayDate.month, _todayDate.day))) {
        return 'Date is too far in the future.';
      }
      return null;
    }
    if (day.isBefore(_todayDate)) {
      return 'Expiry must be today or a future date.';
    }
    return null;
  }

  String? _validateAllExpiries() {
    for (final req in _requiredDocs) {
      final expiry = _docExpiryDates[req.field];
      if (expiry == null) {
        return 'Please set expiry date for ${req.label}.';
      }
      final err = _validateExpiryForField(req.field, expiry);
      if (err != null) return '${req.label}: $err';
    }
    return null;
  }

  String? _validateMemberDetails() {
    if (_nameController.text.trim().isEmpty) {
      return 'Please enter full name.';
    }
    if (_dob == null) return 'Please select date of birth.';
    if (_selectedNationalityId == null) {
      return 'Please select nationality.';
    }
    if ((_selectedCaseKey ?? '').isEmpty) {
      return 'Please select document update type.';
    }
    return _validateDob(_dob!);
  }

  Future<void> _resetRequest() async {
    await FamilyInsuranceDraftStore.clear();
    if (!mounted) return;
    setState(() {
      _draftRestored = false;
      _nameController.clear();
      _dobController.clear();
      _dob = null;
      _selectedNationalityId = null;
      _pickedFiles.clear();
      _docExpiryDates.clear();
      _selectedCaseKey = null;
      _initError = null;
    });
    await _loadInit();
    if (!mounted) return;
    _showSnack('Request reset.');
  }

  Future<void> _openAttach(_FamDocReq req) async {
    final existing = _pickedFiles[req.field];
    final result = await Navigator.of(context).push<FamilyDocumentAttachResult>(
      MaterialPageRoute(
        builder: (_) => FamilyDocumentAttachScreen(
          field: req.field,
          label: req.label,
          allowedType: req.type,
          initialPath: existing?.path,
          initialFilename: existing?.filename,
          initialExpiry: _docExpiryDates[req.field],
        ),
      ),
    );
    if (result == null || !mounted) return;
    final err = _validateExpiryForField(result.field, result.expiry);
    if (err != null) {
      _showSnack('${req.label}: $err');
      return;
    }
    setState(() {
      _pickedFiles[result.field] = _PickedFile(
        path: result.path,
        filename: result.filename,
      );
      _docExpiryDates[result.field] = result.expiry;
    });
  }

  Future<void> _saveDraft() async {
    final caseKey = _selectedCaseKey;
    if (caseKey == null || caseKey.isEmpty) {
      _showSnack('Select a document update type first.');
      return;
    }
    if (_savingDraft) return;
    setState(() => _savingDraft = true);
    try {
      final attachments = <String, FamilyInsuranceDraftAttachment>{};
      _pickedFiles.forEach((field, file) {
        attachments[field] = FamilyInsuranceDraftAttachment(
          path: file.path,
          filename: file.filename,
          expiryIso: _docExpiryDates[field] == null
              ? null
              : DateFormat('yyyy-MM-dd').format(_docExpiryDates[field]!),
        );
      });
      final stored = await FamilyInsuranceDraftStore.save(
        FamilyInsuranceDraft(
          employeeKey: _employeeKey,
          familyMember: _memberKey,
          medicalRequestCase: caseKey,
          memberName: _nameController.text.trim(),
          dobIso: _dob == null ? null : DateFormat('yyyy-MM-dd').format(_dob!),
          nationalityId: _selectedNationalityId,
          attachments: attachments,
        ),
      );
      if (!mounted) return;
      // Point UI at durable copied paths so reopen / later save keeps files.
      _applyDraftAttachments(stored);
      setState(() => _draftRestored = true);
      _showSnack('Draft saved. You can continue later.');
    } catch (_) {
      _showSnack('Failed to save draft.');
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final err = _validateMemberDetails();
    if (err != null) {
      _showSnack(err);
      return;
    }
    for (final req in _requiredDocs) {
      if (_pickedFiles[req.field] == null) {
        _showSnack('Please attach ${req.label}.');
        return;
      }
    }
    final expiryErr = _validateAllExpiries();
    if (expiryErr != null) {
      _showSnack(expiryErr);
      return;
    }

    final token = SharedPref.getLoginData().result?.token ?? '';
    if (token.isEmpty) {
      _showSnack('Session expired. Please login again.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final params = <String, dynamic>{
        'family_member': _memberKey,
        'medical_request_case': _selectedCaseKey,
        'family_member_name': _nameController.text.trim(),
        'family_member_dob': DateFormat('yyyy-MM-dd').format(_dob!),
        'family_member_nationality_id': _selectedNationalityId,
      };

      for (final req in _requiredDocs) {
        final picked = _pickedFiles[req.field]!;
        final bytes = await File(picked.path).readAsBytes();
        params[req.field] = base64Encode(bytes);
        params[req.field.replaceFirst('_file', '_filename')] = picked.filename;
        final expiry = _docExpiryDates[req.field]!;
        params[req.field.replaceFirst('_file', '_expiry_date')] =
            DateFormat('yyyy-MM-dd').format(expiry);
      }

      final response = await http.post(
        Uri.parse('${UrlUtil.baseUrl}family_insurance/submit'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'params': params,
        }),
      );

      final decoded = jsonDecode(response.body);
      final result = _extractResultMap(decoded);
      final status = _normalizeToken(result?['status']);
      final isOk = response.statusCode == 200 &&
          (status == 'success' || status == 'ok' || status == 'true');

      if (!isOk) {
        final message = (result?['message'] ??
                (decoded is Map ? decoded['message'] : null) ??
                'Failed to submit request.')
            .toString();
        if (!mounted) return;
        _showSnack(message);
        return;
      }

      await FamilyInsuranceDraftStore.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request submitted successfully.')),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Failed to submit request.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDob() async {
    final today = _todayDate;
    final isSpouse = _memberKey == 'spouse';
    // Spouse: up to 50 years; Child: up to 18 years.
    final earliest = isSpouse
        ? DateTime(today.year - 50, today.month, today.day)
        : DateTime(today.year - 18, today.month, today.day);
    final latest = today;
    var initial = _dob ??
        (isSpouse
            ? DateTime(today.year - 25, today.month, today.day)
            : DateTime(today.year - 5, today.month, today.day));
    if (initial.isBefore(earliest)) initial = earliest;
    if (initial.isAfter(latest)) initial = latest;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: earliest,
      lastDate: latest,
      helpText: 'Date of birth',
    );
    if (picked == null || !mounted) return;
    final err = _validateDob(picked);
    if (err != null) {
      _showSnack(err);
      return;
    }
    setState(() {
      _dob = picked;
      _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
    });
  }

  Future<void> _openCaseSheet() async {
    if (_updateCases.isEmpty) return;
    final picked = await showModalBottomSheet<_FamUpdateCase>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.tw, 0, 16.tw, 16.th),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.55,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(22.tr),
                border: Border.all(color: _skyAccent.withValues(alpha: 0.35)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 10.th),
                  Container(
                    width: 42.tw,
                    height: 4.th,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0D5DD),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(18.tw, 14.th, 18.tw, 8.th),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Document Update',
                        style: GoogleFonts.poppins(
                          fontSize: 16.tsp,
                          fontWeight: FontWeight.w700,
                          color: _navy,
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.fromLTRB(12.tw, 0, 12.tw, 12.th),
                      itemCount: _updateCases.length,
                      separatorBuilder: (_, __) => SizedBox(height: 8.th),
                      itemBuilder: (context, index) {
                        final c = _updateCases[index];
                        final selected = _selectedCaseKey == c.key;
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(ctx, c),
                            borderRadius: BorderRadius.circular(14.tr),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.tw,
                                vertical: 12.th,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? _greenAccent.withValues(alpha: 0.12)
                                    : const Color(0xFFF5F8FB),
                                borderRadius: BorderRadius.circular(14.tr),
                                border: Border.all(
                                  color: selected
                                      ? _greenAccent.withValues(alpha: 0.45)
                                      : _skyAccent.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.label,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13.tsp,
                                            fontWeight: FontWeight.w700,
                                            color: _navy,
                                          ),
                                        ),
                                        Text(
                                          '${c.documents.length} document(s)',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11.tsp,
                                            color: const Color(0xFF7B8290),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (selected)
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: _greenAccent,
                                      size: 20.tsp,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedCaseKey = picked.key);
      _syncRequiredDocs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _requiredDocs.isEmpty
        ? 'Select update type'
        : '$_attachedCount / ${_requiredDocs.length} attached';

    return PopScope(
      canPop: !_submitting,
      child: MyDocumentsSilkBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              ProductivityGlassHeader(
                title: 'Family Document Request',
                showBack: true,
                transparentGlassBar: true,
                scrimTopOpacity: 0.08,
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16.tw, 4.th, 16.tw, 16.th),
                  children: [
                    if (_draftRestored) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(12.tw, 8.th, 8.tw, 8.th),
                        decoration: BoxDecoration(
                          color: _skyAccent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12.tr),
                          border: Border.all(
                            color: _skyAccent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              size: 18.tsp,
                              color: _navy,
                            ),
                            SizedBox(width: 8.tw),
                            Expanded(
                              child: Text(
                                'Continuing your saved draft.',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.tsp,
                                  fontWeight: FontWeight.w600,
                                  color: _navy,
                                ),
                              ),
                            ),
                            SizedBox(width: 6.tw),
                            Material(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(999),
                              child: InkWell(
                                onTap: _submitting || _savingDraft
                                    ? null
                                    : () => unawaited(_resetRequest()),
                                borderRadius: BorderRadius.circular(999),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12.tw,
                                    vertical: 6.th,
                                  ),
                                  child: Text(
                                    'Reset',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11.tsp,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFBA1719),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 10.th),
                    ],
                    _buildMemberChips(),
                    SizedBox(height: 14.th),
                    Text(
                      'Basic Information',
                      style: GoogleFonts.poppins(
                        fontSize: 13.tsp,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                    SizedBox(height: 8.th),
                    _labeledField(
                      'Full Name',
                      TextField(
                        controller: _nameController,
                        style: GoogleFonts.poppins(fontSize: 13.tsp),
                        decoration: _inputDecoration('Enter name'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    SizedBox(height: 10.th),
                    _labeledField(
                      'Date of Birth',
                      InkWell(
                        onTap: _pickDob,
                        borderRadius: BorderRadius.circular(14.tr),
                        child: IgnorePointer(
                          child: TextField(
                            controller: _dobController,
                            style: GoogleFonts.poppins(fontSize: 13.tsp),
                            decoration: _inputDecoration('dd/MM/yyyy'),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10.th),
                    _labeledField(
                      'Nationality',
                      _nationalityDropdown(),
                    ),
                    SizedBox(height: 14.th),
                    Text(
                      'Document Update',
                      style: GoogleFonts.poppins(
                        fontSize: 13.tsp,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                    SizedBox(height: 8.th),
                    if (_loadingInit)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: CircularProgressIndicator(color: _greenAccent),
                        ),
                      )
                    else if ((_initError ?? '').isNotEmpty)
                      Text(
                        _initError!,
                        style: GoogleFonts.poppins(
                          fontSize: 12.tsp,
                          color: const Color(0xFFC62828),
                        ),
                      )
                    else
                      _buildCaseDropdown(),
                    SizedBox(height: 14.th),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Required Documents',
                            style: GoogleFonts.poppins(
                              fontSize: 13.tsp,
                              fontWeight: FontWeight.w700,
                              color: _navy,
                            ),
                          ),
                        ),
                        Text(
                          progress,
                          style: GoogleFonts.poppins(
                            fontSize: 11.tsp,
                            fontWeight: FontWeight.w600,
                            color: _allDocsAttached
                                ? _greenAccent
                                : const Color(0xFF7B8290),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.th),
                    Text(
                      'Tap each item to Attach. Submit unlocks when all are attached.',
                      style: GoogleFonts.poppins(
                        fontSize: 11.tsp,
                        color: const Color(0xFF7B8290),
                      ),
                    ),
                    SizedBox(height: 10.th),
                    if (_requiredDocs.isEmpty && !_loadingInit)
                      Text(
                        'No documents for this update option.',
                        style: GoogleFonts.poppins(
                          fontSize: 12.tsp,
                          color: const Color(0xFF7B8290),
                        ),
                      )
                    else
                      for (final req in _requiredDocs) ...[
                        _docRow(req),
                        SizedBox(height: 8.th),
                      ],
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.tw, 8.th, 16.tw, 12.th),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52.th,
                          child: OutlinedButton(
                            onPressed:
                                _savingDraft || _submitting ? null : _saveDraft,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _navy,
                              side: BorderSide(
                                color: _skyAccent.withValues(alpha: 0.6),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: _savingDraft
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: _greenAccent,
                                    ),
                                  )
                                : Text(
                                    'Save Draft',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14.tsp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.tw),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 52.th,
                          child: ElevatedButton(
                            onPressed: (!_canSubmit || _submitting)
                                ? null
                                : _submit,
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: _greenAccent,
                              disabledBackgroundColor:
                                  const Color(0xFFD0D5DD),
                              foregroundColor: Colors.white,
                              disabledForegroundColor:
                                  const Color(0xFF7B8290),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Submit Request',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15.tsp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        fontSize: 12.tsp,
        color: const Color(0xFF9AA3AF),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.75),
      contentPadding:
          EdgeInsets.symmetric(horizontal: 14.tw, vertical: 12.th),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.tr),
        borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.tr),
        borderSide: BorderSide(color: _skyAccent.withValues(alpha: 0.4)),
      ),
    );
  }

  Widget _labeledField(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11.tsp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF7B8290),
          ),
        ),
        SizedBox(height: 4.th),
        child,
      ],
    );
  }

  Widget _buildMemberChips() {
    final options = <({String key, String label})>[
      (key: 'spouse', label: 'Spouse'),
      (key: 'child_1', label: 'Child'),
    ];
    return Row(
      children: [
        for (final opt in options) ...[
          Expanded(
            child: InkWell(
              onTap: () => unawaited(_onMemberChanged(opt.key)),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: EdgeInsets.symmetric(vertical: 10.th),
                decoration: BoxDecoration(
                  color: _memberKey == opt.key
                      ? _greenAccent.withValues(alpha: 0.14)
                      : Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _memberKey == opt.key
                        ? _greenAccent.withValues(alpha: 0.55)
                        : _skyAccent.withValues(alpha: 0.4),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  opt.label,
                  style: GoogleFonts.poppins(
                    fontSize: 13.tsp,
                    fontWeight: FontWeight.w700,
                    color: _memberKey == opt.key
                        ? const Color(0xFF1B5E40)
                        : _navy,
                  ),
                ),
              ),
            ),
          ),
          if (opt.key == 'spouse') SizedBox(width: 10.tw),
        ],
      ],
    );
  }

  Widget _nationalityDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.tw),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14.tr),
        border: Border.all(color: _skyAccent.withValues(alpha: 0.4)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedNationalityId,
          isExpanded: true,
          hint: Text(
            _loadingInit ? 'Loading...' : 'Select nationality',
            style: GoogleFonts.poppins(
              fontSize: 12.tsp,
              color: const Color(0xFF9AA3AF),
            ),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          style: GoogleFonts.poppins(fontSize: 13.tsp, color: _navy),
          items: _nationalities
              .map(
                (n) => DropdownMenuItem<int>(
                  value: n.id,
                  child: Text(n.name),
                ),
              )
              .toList(growable: false),
          onChanged: (v) => setState(() => _selectedNationalityId = v),
        ),
      ),
    );
  }

  Widget _buildCaseDropdown() {
    final selected = _selectedCase;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openCaseSheet,
        borderRadius: BorderRadius.circular(16.tr),
        child: Container(
          padding: EdgeInsets.fromLTRB(12.tw, 12.th, 10.tw, 12.th),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.tr),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.92),
                const Color(0xFFE8F4FB).withValues(alpha: 0.88),
              ],
            ),
            border: Border.all(color: _skyAccent.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 40.tw,
                height: 40.tw,
                decoration: BoxDecoration(
                  color: _greenAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.tr),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.sync_alt_rounded,
                  color: _greenAccent,
                  size: 20.tsp,
                ),
              ),
              SizedBox(width: 10.tw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected?.label ?? 'Select update type',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13.tsp,
                        fontWeight: FontWeight.w700,
                        color: selected == null
                            ? const Color(0xFF9AA3AF)
                            : _navy,
                      ),
                    ),
                    Text(
                      selected == null
                          ? 'Tap to choose'
                          : '${selected.documents.length} required document(s)',
                      style: GoogleFonts.poppins(
                        fontSize: 11.tsp,
                        color: const Color(0xFF7B8290),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _navy,
                size: 22.tsp,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _docRow(_FamDocReq req) {
    final picked = _pickedFiles[req.field];
    final expiry = _docExpiryDates[req.field];
    final attached = picked != null && expiry != null;
    final partial = picked != null && expiry == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => unawaited(_openAttach(req)),
        borderRadius: BorderRadius.circular(14.tr),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 12.th),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(14.tr),
            border: Border.all(
              color: attached
                  ? _greenAccent.withValues(alpha: 0.45)
                  : _skyAccent.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                attached
                    ? Icons.check_circle_rounded
                    : Icons.pending_outlined,
                color: attached ? _greenAccent : const Color(0xFF9AA3AF),
                size: 22.tsp,
              ),
              SizedBox(width: 10.tw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.label,
                      style: GoogleFonts.poppins(
                        fontSize: 13.tsp,
                        fontWeight: FontWeight.w600,
                        color: _navy,
                      ),
                    ),
                    Text(
                      attached
                          ? '${picked.filename} · exp ${DateFormat('dd/MM/yyyy').format(expiry)}'
                          : partial
                              ? 'File added — expiry required'
                              : 'Pending — tap to Attach',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11.tsp,
                        color: attached
                            ? _greenAccent
                            : const Color(0xFF7B8290),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 8.tw, vertical: 4.th),
                decoration: BoxDecoration(
                  color: attached
                      ? _greenAccent.withValues(alpha: 0.12)
                      : const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  attached ? 'Attached' : 'Pending',
                  style: GoogleFonts.poppins(
                    fontSize: 10.tsp,
                    fontWeight: FontWeight.w700,
                    color: attached
                        ? _greenAccent
                        : const Color(0xFF856404),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: const Color(0xFF9AA3AF),
                size: 22.tsp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FamUpdateCase {
  const _FamUpdateCase({
    required this.key,
    required this.label,
    required this.documents,
  });

  final String key;
  final String label;
  final List<_FamDocReq> documents;
}

class _FamDocReq {
  const _FamDocReq({
    required this.field,
    required this.label,
    required this.type,
  });

  final String field;
  final String label;
  final String type;
}

class _NationalityOption {
  const _NationalityOption({required this.id, required this.name});

  final int id;
  final String name;
}

class _PickedFile {
  const _PickedFile({required this.path, required this.filename});

  final String path;
  final String filename;
}
