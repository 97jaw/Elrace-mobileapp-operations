import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_documents/widgets/my_documents_silk_background.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_glass_header.dart';
import 'package:el_race/utils/urll_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

const Color _skyAccent = Color(0xFF7EB6D9);
const Color _greenAccent = Color(0xFF1F7A4D);
const Color _navy = Color(0xFF1E2365);

/// Family add/update: Spouse|Child + document types + upload.
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
  static const _fallbackTypes = <String>[
    'Emirates ID',
    'Passport',
    'Labor Card',
    'Medical Insurance',
    'Contract',
    'Visa',
    'Photo',
    'Others',
  ];

  static const _knownTypeIdsByNormalizedName = <String, int>{
    'passport': 1,
    'emiratesid': 2,
    'laborcard': 3,
    'medicalinsurance': 4,
    'drivinglicense': 6,
    'visa': 10,
    'noc': 11,
    'contract': 89,
    'cv': 94,
    'residence': 147,
    'photo': 172,
  };

  final _numberController = TextEditingController();
  final _pageController = PageController();

  late String _memberKey;
  int _step = 0;
  bool _loadingTypes = true;
  bool _loadingInit = true;
  String? _initError;
  bool _submitting = false;

  /// Catalog from `/document_types` (for id resolution).
  final List<_FamDocType> _catalogTypes = [];

  /// Cases from `/family_insurance/init`.
  final List<_FamUpdateCase> _updateCases = [];
  _FamUpdateCase? _selectedCase;

  /// Types shown in the list — driven by selected init case.
  final List<_FamDocType> _types = [];
  _FamDocType? _selectedType;

  /// typeId → existing doc id for the selected member
  final Map<int, int> _existingDocIdByTypeId = {};
  final Map<String, int> _existingDocIdByTypeName = {};

  DateTime? _issueDate;
  DateTime? _expiryDate;
  String? _fileName;
  String? _filePath;

  bool get _isUpdateMode {
    final type = _selectedType;
    if (type == null) return false;
    return _existingDocumentIdFor(type) != null;
  }

  /// Init API expects `spouse` | `child`.
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
    _numberController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String _normalizeMember(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == 'child' || v == 'child_1' || v == 'children') return 'child_1';
    if (v == 'wife') return 'spouse';
    if (v == 'child_2' || v == 'child_3') return v;
    return 'spouse';
  }

  String _memberLabel(String key) {
    switch (key) {
      case 'child_1':
        return 'Child';
      case 'child_2':
        return 'Child 2';
      case 'child_3':
        return 'Child 3';
      default:
        return 'Spouse';
    }
  }

  String _normalizeToken(dynamic value) {
    return (value ?? '')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  int? _existingDocumentIdFor(_FamDocType type) {
    final id = type.id ??
        _knownTypeIdsByNormalizedName[_normalizeToken(type.name)];
    if (id != null && _existingDocIdByTypeId.containsKey(id)) {
      return _existingDocIdByTypeId[id];
    }
    return _existingDocIdByTypeName[_normalizeToken(type.name)];
  }

  int? _resolveTypeId(_FamDocType type) {
    if (type.id != null && type.id! > 0) return type.id;
    final byKnown =
        _knownTypeIdsByNormalizedName[_normalizeToken(type.name)];
    if (byKnown != null) return byKnown;
    for (final c in _catalogTypes) {
      if (_normalizeToken(c.name) == _normalizeToken(type.name) &&
          c.id != null) {
        return c.id;
      }
    }
    // Fuzzy: label contains catalog name or vice versa.
    final token = _normalizeToken(type.name);
    for (final c in _catalogTypes) {
      final ct = _normalizeToken(c.name);
      if (ct.isEmpty || c.id == null) continue;
      if (token.contains(ct) || ct.contains(token)) return c.id;
    }
    return null;
  }

  Future<void> _bootstrap() async {
    await _loadDocumentTypesCatalog();
    await Future.wait([
      _loadExistingForMember(),
      _loadInitCases(),
    ]);
  }

  Future<void> _onMemberChanged(String key) async {
    final normalized = _normalizeMember(key);
    if (normalized == _memberKey) return;
    setState(() {
      _memberKey = normalized;
      _existingDocIdByTypeId.clear();
      _existingDocIdByTypeName.clear();
      _updateCases.clear();
      _selectedCase = null;
      _types.clear();
      _selectedType = null;
      _loadingInit = true;
      _initError = null;
    });
    await Future.wait([
      _loadExistingForMember(),
      _loadInitCases(),
    ]);
  }

  Future<void> _loadInitCases() async {
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
      if (decoded is! Map) {
        if (!mounted) return;
        setState(() {
          _loadingInit = false;
          _initError = 'Invalid init response.';
        });
        return;
      }

      final result = (decoded['result'] is Map)
          ? Map<String, dynamic>.from(decoded['result'] as Map)
          : (decoded['status'] != null)
              ? Map<String, dynamic>.from(decoded)
              : <String, dynamic>{};
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

      final data = result['data'];
      final dataMap = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final casesRaw = dataMap['medical_request_cases'];
      final cases = <_FamUpdateCase>[];
      if (casesRaw is List) {
        for (final raw in casesRaw) {
          if (raw is! Map) continue;
          final map = Map<String, dynamic>.from(raw);
          final caseKey = (map['case_key'] ?? '').toString().trim();
          final caseLabel = (map['case_label'] ?? caseKey).toString().trim();
          if (caseKey.isEmpty) continue;
          final docs = <_FamDocType>[];
          final docsRaw = map['required_documents'];
          if (docsRaw is List) {
            for (final d in docsRaw) {
              if (d is! Map) continue;
              final dm = Map<String, dynamic>.from(d);
              final label =
                  (dm['label'] ?? dm['name'] ?? dm['field'] ?? '')
                      .toString()
                      .trim();
              final field = (dm['field'] ?? '').toString().trim();
              if (label.isEmpty) continue;
              docs.add(
                _FamDocType(
                  name: label,
                  id: _resolveTypeIdFromCatalog(label),
                  field: field.isEmpty ? null : field,
                  familyDocType: _familyDocTypeFromField(field),
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

      if (!mounted) return;
      setState(() {
        _updateCases
          ..clear()
          ..addAll(cases);
        _loadingInit = false;
        _initError = cases.isEmpty ? 'No document update options available.' : null;
      });
      if (cases.isNotEmpty) {
        _applyUpdateCase(cases.first);
      }
    } catch (e) {
      debugPrint('Failed to load family_insurance/init: $e');
      if (!mounted) return;
      setState(() {
        _loadingInit = false;
        _initError = 'Failed to load document update options.';
      });
    }
  }

  int? _resolveTypeIdFromCatalog(String label) {
    final token = _normalizeToken(label);
    final known = _knownTypeIdsByNormalizedName[token];
    if (known != null) return known;
    for (final c in _catalogTypes) {
      final ct = _normalizeToken(c.name);
      if (ct == token && c.id != null) return c.id;
    }
    for (final c in _catalogTypes) {
      final ct = _normalizeToken(c.name);
      if (ct.isEmpty || c.id == null) continue;
      if (token.contains(ct) || ct.contains(token)) return c.id;
    }
    return null;
  }

  String? _familyDocTypeFromField(String field) {
    final f = field.toLowerCase().replaceAll('_file', '').trim();
    if (f.isEmpty) return null;
    const allowed = {
      'passport',
      'visa',
      'eid',
      'photo',
      'health_insurance',
      'birth_certificate',
      'marriage_certificate',
      'previous_visa',
      'passport_copy',
      'resident_cancellation',
      'coc',
      'e_visa',
      'changed_status',
      'entry_stamp',
      'visit_visa',
    };
    if (allowed.contains(f)) return f;
    if (f.contains('passport')) return 'passport';
    if (f.contains('visa')) return 'visa';
    if (f.contains('eid') || f.contains('emirates')) return 'eid';
    if (f.contains('photo')) return 'photo';
    if (f.contains('birth')) return 'birth_certificate';
    if (f.contains('marriage')) return 'marriage_certificate';
    if (f.contains('insurance') || f.contains('medical')) {
      return 'health_insurance';
    }
    return null;
  }

  void _applyUpdateCase(_FamUpdateCase updateCase) {
    final docs = updateCase.documents.map((d) {
      return _FamDocType(
        name: d.name,
        id: d.id ?? _resolveTypeIdFromCatalog(d.name),
        field: d.field,
        familyDocType: d.familyDocType ?? _familyDocTypeFromField(d.field ?? ''),
      );
    }).toList(growable: false);

    setState(() {
      _selectedCase = updateCase;
      _types
        ..clear()
        ..addAll(docs);
      _selectedType = docs.isNotEmpty ? docs.first : null;
    });
  }

  Future<void> _loadDocumentTypesCatalog() async {
    setState(() => _loadingTypes = true);
    final names = <String>[];
    final idsByName = <String, int>{};

    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      if (token.isNotEmpty) {
        final response = await http.post(
          Uri.parse('${UrlUtil.baseUrl}document_types'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'jsonrpc': '2.0',
            'params': {'family_only': true},
          }),
        );

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map) {
            final result = (decoded['result'] is Map)
                ? Map<String, dynamic>.from(decoded['result'] as Map)
                : (decoded['status'] != null)
                    ? Map<String, dynamic>.from(decoded)
                    : <String, dynamic>{};
            final status = _normalizeToken(result['status']);
            if (status == 'success' || status == 'ok' || status == 'true') {
              final data = result['data'];
              if (data is List) {
                for (final item in data) {
                  _parseTypeRaw(item, names, idsByName);
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load family document types: $e');
    }

    if (!mounted) return;
    if (names.isEmpty) names.addAll(_fallbackTypes);

    final options = names.map((name) {
      final id = idsByName[name] ??
          _knownTypeIdsByNormalizedName[_normalizeToken(name)];
      return _FamDocType(id: id, name: name);
    }).toList()
      ..sort((a, b) {
        final rank = _famDocumentTypeImportance(a.name)
            .compareTo(_famDocumentTypeImportance(b.name));
        if (rank != 0) return rank;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    setState(() {
      _catalogTypes
        ..clear()
        ..addAll(options);
      _loadingTypes = false;
    });
  }

  void _parseTypeRaw(
    dynamic raw,
    List<String> names,
    Map<String, int> idsByName,
  ) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final name = (map['name'] ?? map['document_type'] ?? map['label'] ?? '')
          .toString()
          .trim();
      final id = int.tryParse((map['id'] ?? map['document_type_id'] ?? '')
          .toString());
      if (name.isEmpty) return;
      if (!names.contains(name)) names.add(name);
      if (id != null && id > 0) idsByName[name] = id;
      return;
    }
    final name = (raw ?? '').toString().trim();
    if (name.isNotEmpty && !names.contains(name)) names.add(name);
  }

  Future<void> _loadExistingForMember() async {
    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      if (token.isEmpty) return;

      final response = await http.post(
        Uri.parse('${UrlUtil.baseUrl}get_employee_documents'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'params': {'family_only': true},
        }),
      );
      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return;
      final result = (decoded['result'] is Map)
          ? Map<String, dynamic>.from(decoded['result'] as Map)
          : (decoded['status'] != null)
              ? Map<String, dynamic>.from(decoded)
              : <String, dynamic>{};
      final status = _normalizeToken(result['status']);
      if (!(status == 'success' || status == 'ok' || status == 'true')) {
        return;
      }

      final byTypeId = <int, int>{};
      final byTypeName = <String, int>{};
      final data = result['data'];
      final groups = data is List ? data : const [];

      void ingestDoc(Map<String, dynamic> doc) {
        final rawMember = (doc['family_member'] ?? '').toString().trim();
        final member = rawMember.isEmpty
            ? ''
            : _normalizeMember(rawMember);
        final matches = member == _memberKey ||
            (member.isEmpty && _memberKey == 'spouse');
        if (!matches) return;

        final docId = int.tryParse((doc['id'] ?? '').toString());
        if (docId == null || docId <= 0) return;

        final typeId = int.tryParse(
          (doc['document_type_id'] ?? '').toString(),
        );
        if (typeId != null && typeId > 0) byTypeId[typeId] = docId;

        final typeName =
            (doc['document_type'] ?? doc['type'] ?? doc['title'] ?? '')
                .toString()
                .trim();
        final tokenName = _normalizeToken(typeName);
        if (tokenName.isNotEmpty) byTypeName[tokenName] = docId;
      }

      for (final raw in groups) {
        if (raw is! Map) continue;
        final group = Map<String, dynamic>.from(raw);
        final docs = group['documents'];
        if (docs is List && docs.isNotEmpty) {
          for (final d in docs) {
            if (d is Map) ingestDoc(Map<String, dynamic>.from(d));
          }
        } else {
          ingestDoc(group);
        }
      }

      if (!mounted) return;
      setState(() {
        _existingDocIdByTypeId
          ..clear()
          ..addAll(byTypeId);
        _existingDocIdByTypeName
          ..clear()
          ..addAll(byTypeName);
      });
    } catch (e) {
      debugPrint('Failed to load existing family docs: $e');
    }
  }

  void _onBack() {
    if (_submitting) return;
    if (_step > 0) {
      setState(() => _step -= 1);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _onPrimary() async {
    if (_step == 0) {
      if (_selectedType == null) {
        _showSnack('Please select a document type.');
        return;
      }
      setState(() => _step = 1);
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      return;
    }
    if (_step == 1) {
      if ((_filePath ?? '').isEmpty) {
        _showSnack('Please attach a file.');
        return;
      }
      if (_issueDate == null) {
        _showSnack('Please select the issue date.');
        return;
      }
      if (_expiryDate == null) {
        _showSnack('Please select the expiry date.');
        return;
      }
      setState(() => _step = 2);
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      return;
    }
    await _submit();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (!mounted) return;
    setState(() {
      _fileName = file.name;
      _filePath = file.path;
    });
  }

  Future<void> _pickDate({required bool issue}) async {
    final now = DateTime.now();
    final initial = issue
        ? (_issueDate ?? now)
        : (_expiryDate ?? now.add(const Duration(days: 365)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year + 40),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (issue) {
        _issueDate = picked;
      } else {
        _expiryDate = picked;
      }
    });
  }

  String _safeAttachmentFilename() {
    final name = (_fileName ?? 'document.pdf').trim();
    if (name.isEmpty) return 'document.pdf';
    return name;
  }

  bool _isUploadSuccess(dynamic decodedBody) {
    if (decodedBody is! Map) return false;
    final result = decodedBody['result'];
    if (result is Map) {
      final status = _normalizeToken(result['status']);
      if (status == 'success' || status == 'ok' || status == 'true') {
        return true;
      }
      if (result['document_id'] != null) return true;
    }
    return false;
  }

  String _extractUploadMessage(dynamic decodedBody) {
    if (decodedBody is! Map) return 'Upload failed';
    final result = decodedBody['result'];
    if (result is Map) {
      final message = result['message']?.toString();
      if (message != null && message.trim().isNotEmpty) return message.trim();
    }
    final error = decodedBody['error'];
    if (error is Map) {
      final message = error['message']?.toString();
      if (message != null && message.trim().isNotEmpty) return message.trim();
    }
    return 'Upload failed';
  }

  Future<void> _submit() async {
    final type = _selectedType;
    final path = (_filePath ?? '').trim();
    if (type == null || path.isEmpty) return;

    final typeId = _resolveTypeId(type);
    if (typeId == null) {
      _showSnack('document_type_id is missing for "${type.name}".');
      return;
    }

    final token = SharedPref.getLoginData().result?.token ?? '';
    if (token.isEmpty) {
      _showSnack('Session expired. Please login again.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final bytes = await File(path).readAsBytes();
      final number = _numberController.text.trim();
      final params = <String, dynamic>{
        'name': number.isNotEmpty ? number : type.name,
        'description': 'Uploaded from mobile app (family)',
        'attachment': base64Encode(bytes),
        'attachment_filename': _safeAttachmentFilename(),
        'family_only': true,
        'family_member': _memberKey,
        'document_type_id': typeId,
        'issue_date': DateFormat('yyyy-MM-dd').format(_issueDate!),
        'expiry_date': DateFormat('yyyy-MM-dd').format(_expiryDate!),
      };
      final familyDocType = type.familyDocType;
      if (familyDocType != null && familyDocType.isNotEmpty) {
        params['family_doc_type'] = familyDocType;
      }

      final existingId = _existingDocumentIdFor(type);
      if (existingId != null && existingId > 0) {
        params['document_id'] = existingId;
      }

      final response = await http.post(
        Uri.parse('${UrlUtil.baseUrl}upload_employee_document'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': null,
          'params': params,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode != 200 || !_isUploadSuccess(data)) {
        if (!mounted) return;
        _showSnack(_extractUploadMessage(data));
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_extractUploadMessage(data))),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('An error occurred while uploading the document.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0 && !_submitting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onBack();
      },
      child: MyDocumentsSilkBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              ProductivityGlassHeader(
                title: 'Add Family Document',
                showBack: true,
                onBack: _onBack,
                transparentGlassBar: true,
                scrimTopOpacity: 0.08,
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16.tw, 4.th, 16.tw, 8.th),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMemberChips(),
                    SizedBox(height: 10.th),
                    _buildStepper(),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildTypeStep(),
                    _buildUploadStep(),
                    _buildReviewStep(),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.tw, 8.th, 16.tw, 12.th),
                  child: SizedBox(
                    height: 52.th,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _onPrimary,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: _greenAccent,
                        foregroundColor: Colors.white,
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
                              _step == 2
                                  ? (_isUpdateMode ? 'Update' : 'Submit')
                                  : (_isUpdateMode
                                      ? 'Next (Update)'
                                      : 'Next'),
                              style: GoogleFonts.poppins(
                                fontSize: 16.tsp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

  Widget _buildStepper() {
    return Row(
      children: List.generate(3, (i) {
        final active = i <= _step;
        return Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 3.tw),
            height: 4.th,
            decoration: BoxDecoration(
              color: active ? _greenAccent : const Color(0xFFD0D5DD),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTypeStep() {
    return ListView(
      padding: EdgeInsets.fromLTRB(16.tw, 4.th, 16.tw, 16.th),
      children: [
        Text(
          'Document Update',
          style: GoogleFonts.poppins(
            fontSize: 13.tsp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF7B8290),
          ),
        ),
        SizedBox(height: 6.th),
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
          _buildDocumentUpdateDropdown(),
        SizedBox(height: 16.th),
        Text(
          'Select Document Type',
          style: GoogleFonts.poppins(
            fontSize: 15.tsp,
            fontWeight: FontWeight.w700,
            color: _navy,
          ),
        ),
        SizedBox(height: 4.th),
        Text(
          _selectedCase == null
              ? 'Choose a document update option above.'
              : 'Documents required for ${_selectedCase!.label}.',
          style: GoogleFonts.poppins(
            fontSize: 12.tsp,
            color: const Color(0xFF7B8290),
          ),
        ),
        SizedBox(height: 12.th),
        if (_loadingInit || _loadingTypes)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: CircularProgressIndicator(color: _greenAccent),
            ),
          )
        else if (_types.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24.th),
            child: Text(
              'No document types for this update option.',
              style: GoogleFonts.poppins(
                fontSize: 13.tsp,
                color: const Color(0xFF7B8290),
              ),
            ),
          )
        else
          for (final type in _types) ...[
            _FamTypeRow(
              name: type.name,
              field: type.field,
              selected: _selectedType?.name == type.name,
              isUpdate: _existingDocumentIdFor(type) != null,
              onTap: () => setState(() => _selectedType = type),
            ),
            SizedBox(height: 10.th),
          ],
      ],
    );
  }

  Widget _buildDocumentUpdateDropdown() {
    final selected = _selectedCase;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openDocumentUpdateSheet,
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
            border: Border.all(
              color: _skyAccent.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: _skyAccent.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40.tw,
                height: 40.tw,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F7A4D).withValues(alpha: 0.12),
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
                    SizedBox(height: 2.th),
                    Text(
                      selected == null
                          ? 'Tap to choose from available cases'
                          : '${selected.documents.length} document type(s)',
                      style: GoogleFonts.poppins(
                        fontSize: 11.tsp,
                        color: const Color(0xFF7B8290),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 30.tw,
                height: 30.tw,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.85),
                  border: Border.all(
                    color: _skyAccent.withValues(alpha: 0.45),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _navy,
                  size: 20.tsp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDocumentUpdateSheet() async {
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
                border: Border.all(
                  color: _skyAccent.withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
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
                        final selected = _selectedCase?.key == c.key;
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
                                  Container(
                                    width: 36.tw,
                                    height: 36.tw,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? _greenAccent.withValues(alpha: 0.18)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(10.tr),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.folder_special_rounded,
                                      size: 18.tsp,
                                      color: selected
                                          ? _greenAccent
                                          : const Color(0xFF5A6A5E),
                                    ),
                                  ),
                                  SizedBox(width: 10.tw),
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
                                          '${c.documents.length} document type(s)',
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
      _applyUpdateCase(picked);
    }
  }

  Widget _buildUploadStep() {
    final hasFile = (_filePath ?? '').isNotEmpty;
    return ListView(
      padding: EdgeInsets.fromLTRB(16.tw, 4.th, 16.tw, 16.th),
      children: [
        Text(
          'Upload & Details',
          style: GoogleFonts.poppins(
            fontSize: 15.tsp,
            fontWeight: FontWeight.w700,
            color: _navy,
          ),
        ),
        SizedBox(height: 12.th),
        InkWell(
          onTap: _pickFile,
          borderRadius: BorderRadius.circular(16.tr),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 28.th),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16.tr),
              border: Border.all(color: _skyAccent.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Icon(
                  hasFile
                      ? Icons.insert_drive_file_rounded
                      : Icons.cloud_upload_outlined,
                  color: _greenAccent,
                  size: 36.tsp,
                ),
                SizedBox(height: 8.th),
                Text(
                  hasFile ? (_fileName ?? 'Selected file') : 'Tap to choose a file',
                  style: GoogleFonts.poppins(
                    fontSize: 13.tsp,
                    fontWeight: FontWeight.w600,
                    color: _navy,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 12.th),
        TextField(
          controller: _numberController,
          decoration: InputDecoration(
            labelText: 'Document number (optional)',
            labelStyle: GoogleFonts.poppins(fontSize: 12.tsp),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.75),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.tr),
              borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
            ),
          ),
        ),
        SizedBox(height: 10.th),
        _dateTile(
          label: 'Issue date (mandatory)',
          value: _issueDate == null
              ? 'Select issue date'
              : DateFormat('dd/MM/yyyy').format(_issueDate!),
          onTap: () => _pickDate(issue: true),
        ),
        SizedBox(height: 8.th),
        _dateTile(
          label: 'Expiry date (mandatory)',
          value: _expiryDate == null
              ? 'Select expiry date'
              : DateFormat('dd/MM/yyyy').format(_expiryDate!),
          onTap: () => _pickDate(issue: false),
        ),
      ],
    );
  }

  Widget _dateTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.tr),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 14.tw, vertical: 14.th),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(14.tr),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11.tsp,
                color: const Color(0xFF7B8290),
              ),
            ),
            SizedBox(height: 4.th),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13.tsp,
                fontWeight: FontWeight.w600,
                color: _navy,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewStep() {
    final type = _selectedType?.name ?? '-';
    return ListView(
      padding: EdgeInsets.fromLTRB(16.tw, 4.th, 16.tw, 16.th),
      children: [
        Text(
          'Review & Submit',
          style: GoogleFonts.poppins(
            fontSize: 15.tsp,
            fontWeight: FontWeight.w700,
            color: _navy,
          ),
        ),
        SizedBox(height: 12.th),
        _reviewRow('Member', _memberLabel(_memberKey)),
        _reviewRow('Document update', _selectedCase?.label ?? '-'),
        _reviewRow('Document type', type),
        _reviewRow(
          'Number',
          _numberController.text.trim().isEmpty
              ? '-'
              : _numberController.text.trim(),
        ),
        _reviewRow('File', _fileName ?? '-'),
        _reviewRow(
          'Issue',
          _issueDate == null
              ? '-'
              : DateFormat('dd/MM/yyyy').format(_issueDate!),
        ),
        _reviewRow(
          'Expiry',
          _expiryDate == null
              ? '-'
              : DateFormat('dd/MM/yyyy').format(_expiryDate!),
        ),
        _reviewRow('Mode', _isUpdateMode ? 'Update' : 'Add'),
      ],
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.th),
      child: Row(
        children: [
          SizedBox(
            width: 110.tw,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12.tsp,
                color: const Color(0xFF7B8290),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13.tsp,
                fontWeight: FontWeight.w600,
                color: _navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FamDocType {
  const _FamDocType({
    required this.name,
    this.id,
    this.field,
    this.familyDocType,
  });

  final String name;
  final int? id;
  final String? field;
  final String? familyDocType;
}

class _FamUpdateCase {
  const _FamUpdateCase({
    required this.key,
    required this.label,
    required this.documents,
  });

  final String key;
  final String label;
  final List<_FamDocType> documents;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _FamUpdateCase && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

class _FamTypeRow extends StatelessWidget {
  const _FamTypeRow({
    required this.name,
    required this.selected,
    required this.isUpdate,
    required this.onTap,
    this.field,
  });

  final String name;
  final String? field;
  final bool selected;
  final bool isUpdate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = _famTypeVisual(name, field: field);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.tr),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 12.th),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: selected ? 0.92 : 0.62),
            borderRadius: BorderRadius.circular(14.tr),
            border: Border.all(
              color: selected
                  ? _greenAccent.withValues(alpha: 0.55)
                  : _skyAccent.withValues(alpha: 0.55),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44.tw,
                height: 44.tw,
                decoration: BoxDecoration(
                  color: visual.bg,
                  borderRadius: BorderRadius.circular(12.tr),
                ),
                alignment: Alignment.center,
                child: Icon(visual.icon, color: visual.fg, size: 22.tsp),
              ),
              SizedBox(width: 12.tw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 15.tsp,
                        fontWeight: FontWeight.w600,
                        color: _navy,
                      ),
                    ),
                    if (isUpdate) ...[
                      SizedBox(height: 2.th),
                      Text(
                        'Already uploaded — will update',
                        style: GoogleFonts.poppins(
                          fontSize: 11.tsp,
                          color: const Color(0xFF2F6AD8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color: selected ? _greenAccent : const Color(0xFF9AA3AF),
                size: 22.tsp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FamTypeVisual {
  const _FamTypeVisual({
    required this.bg,
    required this.fg,
    required this.icon,
  });

  final Color bg;
  final Color fg;
  final IconData icon;
}

int _famDocumentTypeImportance(String name) {
  final t = name.toLowerCase().trim();
  const ranked = <String>[
    'emirates id',
    'passport',
    'residence',
    'visa',
    'labor card',
    'labour card',
    'driving license',
    'driving licence',
    'medical insurance',
    'photo',
    'contract',
  ];
  for (var i = 0; i < ranked.length; i++) {
    if (t.contains(ranked[i])) return i;
  }
  return 1000;
}

_FamTypeVisual _famTypeVisual(String name, {String? field}) {
  final t = name.toLowerCase().trim();
  final f = (field ?? '').toLowerCase().replaceAll('_file', '').trim();
  final key = '$t $f';

  if (key.contains('emirates') ||
      key.contains('eid') ||
      RegExp(r'\beid\b').hasMatch(f)) {
    return const _FamTypeVisual(
      bg: Color(0xFFE3F0FF),
      fg: Color(0xFF1565C0),
      icon: Icons.badge_rounded,
    );
  }
  if (key.contains('passport_copy') || key.contains('passport copy')) {
    return const _FamTypeVisual(
      bg: Color(0xFFE8EEF8),
      fg: Color(0xFF3949AB),
      icon: Icons.copy_all_rounded,
    );
  }
  if (key.contains('passport')) {
    return const _FamTypeVisual(
      bg: Color(0xFF1E4F8A),
      fg: Colors.white,
      icon: Icons.menu_book_rounded,
    );
  }
  if (key.contains('residence') || key.contains('resident_cancellation')) {
    return const _FamTypeVisual(
      bg: Color(0xFFE0F2F1),
      fg: Color(0xFF00796B),
      icon: Icons.home_work_rounded,
    );
  }
  if (key.contains('e_visa') || key.contains('e-visa')) {
    return const _FamTypeVisual(
      bg: Color(0xFFF3E5F5),
      fg: Color(0xFF7B1FA2),
      icon: Icons.airplane_ticket_rounded,
    );
  }
  if (key.contains('visit_visa') || key.contains('visit visa')) {
    return const _FamTypeVisual(
      bg: Color(0xFFEDE7F6),
      fg: Color(0xFF5E35B1),
      icon: Icons.luggage_rounded,
    );
  }
  if (key.contains('previous_visa') || key.contains('previous visa')) {
    return const _FamTypeVisual(
      bg: Color(0xFFE8EAF6),
      fg: Color(0xFF3F51B5),
      icon: Icons.history_rounded,
    );
  }
  if (key.contains('visa')) {
    return const _FamTypeVisual(
      bg: Color(0xFFEDE7F6),
      fg: Color(0xFF5E35B1),
      icon: Icons.flight_takeoff_rounded,
    );
  }
  if (key.contains('entry_stamp') || key.contains('entry stamp')) {
    return const _FamTypeVisual(
      bg: Color(0xFFFFF3E0),
      fg: Color(0xFFEF6C00),
      icon: Icons.approval_rounded,
    );
  }
  if (key.contains('changed_status') || key.contains('status')) {
    return const _FamTypeVisual(
      bg: Color(0xFFE0F7FA),
      fg: Color(0xFF00838F),
      icon: Icons.swap_horiz_rounded,
    );
  }
  if (key.contains('labor') || key.contains('labour')) {
    return const _FamTypeVisual(
      bg: Color(0xFFFFF1D9),
      fg: Color(0xFFC47A12),
      icon: Icons.engineering_rounded,
    );
  }
  if (key.contains('driving') || key.contains('license') || key.contains('licence')) {
    return const _FamTypeVisual(
      bg: Color(0xFFFFEBEE),
      fg: Color(0xFFD84315),
      icon: Icons.directions_car_filled_rounded,
    );
  }
  if (key.contains('marriage')) {
    return const _FamTypeVisual(
      bg: Color(0xFFFCE4EC),
      fg: Color(0xFFC2185B),
      icon: Icons.favorite_rounded,
    );
  }
  if (key.contains('birth')) {
    return const _FamTypeVisual(
      bg: Color(0xFFE8F5E9),
      fg: Color(0xFF2E7D32),
      icon: Icons.child_care_rounded,
    );
  }
  if (key.contains('insurance') ||
      key.contains('medical') ||
      key.contains('health')) {
    return const _FamTypeVisual(
      bg: Color(0xFFFFE5E5),
      fg: Color(0xFFC62828),
      icon: Icons.medical_services_rounded,
    );
  }
  if (key.contains('photo') || key.contains('picture') || key.contains('image')) {
    return const _FamTypeVisual(
      bg: Color(0xFFF3E5F5),
      fg: Color(0xFF8E24AA),
      icon: Icons.photo_camera_rounded,
    );
  }
  if (key.contains('coc')) {
    return const _FamTypeVisual(
      bg: Color(0xFFFFF8E1),
      fg: Color(0xFFF9A825),
      icon: Icons.verified_rounded,
    );
  }
  if (key.contains('contract')) {
    return const _FamTypeVisual(
      bg: Color(0xFFE3F2FD),
      fg: Color(0xFF1565C0),
      icon: Icons.handshake_rounded,
    );
  }
  if (key.contains('certificate')) {
    return const _FamTypeVisual(
      bg: Color(0xFFE8F5E9),
      fg: Color(0xFF43A047),
      icon: Icons.workspace_premium_rounded,
    );
  }
  // Stable unique fallback from name hash so rows don't all look the same.
  const palette = <_FamTypeVisual>[
    _FamTypeVisual(
      bg: Color(0xFFE3F2FD),
      fg: Color(0xFF1976D2),
      icon: Icons.description_rounded,
    ),
    _FamTypeVisual(
      bg: Color(0xFFE8F5E9),
      fg: Color(0xFF388E3C),
      icon: Icons.article_rounded,
    ),
    _FamTypeVisual(
      bg: Color(0xFFFFF3E0),
      fg: Color(0xFFF57C00),
      icon: Icons.folder_rounded,
    ),
    _FamTypeVisual(
      bg: Color(0xFFF3E5F5),
      fg: Color(0xFF8E24AA),
      icon: Icons.note_alt_rounded,
    ),
    _FamTypeVisual(
      bg: Color(0xFFE0F7FA),
      fg: Color(0xFF0097A7),
      icon: Icons.assignment_rounded,
    ),
    _FamTypeVisual(
      bg: Color(0xFFFFEBEE),
      fg: Color(0xFFE53935),
      icon: Icons.task_rounded,
    ),
  ];
  final hash = key.codeUnits.fold<int>(0, (a, b) => a + b);
  return palette[hash % palette.length];
}
