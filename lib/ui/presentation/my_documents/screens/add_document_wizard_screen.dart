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

/// Full-screen Add New Document wizard (type → upload+details → review).
class AddDocumentWizardScreen extends StatefulWidget {
  const AddDocumentWizardScreen({super.key});

  @override
  State<AddDocumentWizardScreen> createState() =>
      _AddDocumentWizardScreenState();
}

class _AddDocumentWizardScreenState extends State<AddDocumentWizardScreen> {
  static const _fallbackTypes = <String>[
    'Emirates ID',
    'Passport',
    'Labor Card',
    'Medical Insurance',
    'Contract',
    'CV',
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
    'universitycertificate': 93,
    'cv': 94,
    'residence': 147,
    'photo': 172,
    'pension': 175,
  };

  final _numberController = TextEditingController();
  final _pageController = PageController();

  int _step = 0;
  bool _loadingTypes = true;
  bool _submitting = false;

  final List<_DocTypeOption> _types = [];
  _DocTypeOption? _selectedType;

  /// document_type_id → existing hr.employee.document id (personal).
  final Map<int, int> _existingDocIdByTypeId = {};
  /// normalized type name → existing document id (fallback).
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

  int? _existingDocumentIdFor(_DocTypeOption type) {
    final id = type.id ?? _knownTypeIdsByNormalizedName[_normalizeToken(type.name)];
    if (id != null && _existingDocIdByTypeId.containsKey(id)) {
      return _existingDocIdByTypeId[id];
    }
    return _existingDocIdByTypeName[_normalizeToken(type.name)];
  }

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _loadDocumentTypes(),
      _loadExistingPersonalDocuments(),
    ]);
  }

  @override
  void dispose() {
    _numberController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String _normalizeToken(dynamic value) {
    return (value ?? '')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Future<void> _loadDocumentTypes() async {
    setState(() => _loadingTypes = true);
    final names = <String>[];
    final idsByName = <String, int>{};

    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      if (token.isNotEmpty) {
        final url = Uri.parse('${UrlUtil.baseUrl}document_types');
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'jsonrpc': '2.0',
            'params': {'family_only': false},
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
              } else if (data is Map) {
                for (final entry in data.entries) {
                  final key = entry.key.toString().trim();
                  final value = entry.value;
                  if (value is Map || value is String) {
                    _parseTypeRaw(value, names, idsByName);
                    continue;
                  }
                  final keyAsId = int.tryParse(key);
                  final valueText = (value ?? '').toString().trim();
                  final valueAsId = int.tryParse(valueText);
                  if (keyAsId != null && valueText.isNotEmpty) {
                    if (!names.contains(valueText)) names.add(valueText);
                    idsByName[valueText] = keyAsId;
                  } else if (valueAsId != null && key.isNotEmpty) {
                    if (!names.contains(key)) names.add(key);
                    idsByName[key] = valueAsId;
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load document types: $e');
    }

    if (!mounted) return;

    if (names.isEmpty) {
      names.addAll(_fallbackTypes);
    }

    final options = names.map((name) {
      final id = idsByName[name] ??
          _knownTypeIdsByNormalizedName[_normalizeToken(name)];
      return _DocTypeOption(id: id, name: name);
    }).toList()
      ..sort((a, b) {
        final rank = _documentTypeImportance(a.name)
            .compareTo(_documentTypeImportance(b.name));
        if (rank != 0) return rank;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    setState(() {
      _types
        ..clear()
        ..addAll(options);
      _loadingTypes = false;
    });
  }

  Future<void> _loadExistingPersonalDocuments() async {
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
          'params': {'family_only': false},
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
        final docId = int.tryParse((doc['id'] ?? '').toString());
        if (docId == null || docId <= 0) return;

        final typeIdRaw = doc['document_type_id'] ??
            doc['type_id'] ??
            (doc['document_type'] is Map
                ? (doc['document_type'] as Map)['id']
                : null);
        final typeId = int.tryParse((typeIdRaw ?? '').toString());
        if (typeId != null && typeId > 0) {
          byTypeId[typeId] = docId;
        }

        final typeName = (doc['document_type'] is Map
                ? (doc['document_type'] as Map)['name']
                : doc['document_type'] ?? doc['type'] ?? doc['title'] ?? '')
            .toString()
            .trim();
        final tokenName = _normalizeToken(typeName);
        if (tokenName.isNotEmpty) {
          byTypeName[tokenName] = docId;
        }
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
      debugPrint('Failed to load existing documents: $e');
    }
  }

  void _parseTypeRaw(
    dynamic raw,
    List<String> names,
    Map<String, int> idsByName,
  ) {
    if (raw is String) {
      final name = raw.trim();
      if (name.isNotEmpty && !names.contains(name)) names.add(name);
      return;
    }
    if (raw is! Map) return;
    final map = Map<String, dynamic>.from(raw);
    final name = (map['name'] ??
            map['document_type'] ??
            map['type'] ??
            map['label'] ??
            '')
        .toString()
        .trim();
    if (name.isEmpty) return;
    if (!names.contains(name)) names.add(name);
    final idRaw = map['id'] ?? map['document_type_id'] ?? map['type_id'];
    final id = int.tryParse((idRaw ?? '').toString());
    if (id != null) idsByName[name] = id;
  }

  void _onBack() {
    if (_submitting) return;
    if (_step == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    _goToStep(_step - 1);
  }

  void _goToStep(int index) {
    setState(() => _step = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  bool get _canProceed {
    switch (_step) {
      case 0:
        return _selectedType != null;
      case 1:
        return (_filePath ?? '').trim().isNotEmpty &&
            _issueDate != null &&
            _expiryDate != null;
      case 2:
        return !_submitting;
      default:
        return false;
    }
  }

  void _onPrimary() {
    if (!_canProceed) {
      _showSnack(_stepValidationMessage());
      return;
    }
    if (_step < 2) {
      _goToStep(_step + 1);
      return;
    }
    unawaited(_submit());
  }

  String _stepValidationMessage() {
    switch (_step) {
      case 0:
        return 'Please select a document type.';
      case 1:
        if ((_filePath ?? '').trim().isEmpty) {
          return 'Please attach a file.';
        }
        if (_issueDate == null) {
          return 'Please select the issue date.';
        }
        if (_expiryDate == null) {
          return 'Please select the expiry date.';
        }
        return 'Please complete the required fields.';
      default:
        return 'Please complete the required fields.';
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _pickDate({required bool issue}) async {
    final now = DateTime.now();
    final initial = issue
        ? (_issueDate ?? now)
        : (_expiryDate ?? now.add(const Duration(days: 365)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime(now.year + 40),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _greenAccent,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _navy,
            ),
          ),
          child: child!,
        );
      },
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

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      setState(() {
        _fileName = file.name;
        _filePath = file.path;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error selecting file: $e');
    }
  }

  int? _resolveTypeId(_DocTypeOption type) {
    if (type.id != null) return type.id;
    return _knownTypeIdsByNormalizedName[_normalizeToken(type.name)];
  }

  String _safeAttachmentFilename() {
    final direct = (_fileName ?? '').trim();
    if (direct.isNotEmpty) return direct;
    final path = (_filePath ?? '').trim();
    if (path.isNotEmpty) {
      final fromPath = path.split(Platform.pathSeparator).last;
      if (fromPath.isNotEmpty) return fromPath;
    }
    final type = (_selectedType?.name ?? 'document')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
    return '$type.pdf';
  }

  bool _isUploadSuccess(dynamic decodedBody) {
    if (decodedBody is! Map) return false;
    final result = decodedBody['result'];
    if (result is! Map) return false;
    final statusToken = _normalizeToken(result['status']);
    if (statusToken == 'success' ||
        statusToken == 'ok' ||
        statusToken == 'true') {
      return true;
    }
    final successRaw = result['success'];
    if (successRaw is bool) return successRaw;
    final successToken = _normalizeToken(successRaw);
    return successToken == '1' ||
        successToken == 'true' ||
        successToken == 'success';
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
    final number = _numberController.text.trim();
    final path = (_filePath ?? '').trim();

    if (type == null) {
      _showSnack('Please select a document type.');
      return;
    }
    if (path.isEmpty) {
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

    final typeId = _resolveTypeId(type);
    if (typeId == null) {
      _showSnack(
        'document_type_id is missing for "${type.name}". Please refresh and try again.',
      );
      return;
    }

    final token = SharedPref.getLoginData().result?.token ?? '';
    if (token.isEmpty) {
      _showSnack('Session expired. Please login again.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      final base64File = base64Encode(bytes);

      // API requires `name`; use document number when provided, else type label.
      final params = <String, dynamic>{
        'name': number.isNotEmpty ? number : type.name,
        'description': 'Uploaded from mobile app',
        'attachment': base64File,
        'attachment_filename': _safeAttachmentFilename(),
        'family_only': false,
        'document_type_id': typeId,
        'issue_date': DateFormat('yyyy-MM-dd').format(_issueDate!),
        'expiry_date': DateFormat('yyyy-MM-dd').format(_expiryDate!),
      };

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
        await _showResultDialog(
          title: 'Upload Failed',
          message: _extractUploadMessage(data),
          success: false,
        );
        return;
      }

      if (!mounted) return;
      await _showResultDialog(
        title: 'Success',
        message: _extractUploadMessage(data),
        success: true,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      await _showResultDialog(
        title: 'Upload Failed',
        message: 'An error occurred while uploading the document.',
        success: false,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showResultDialog({
    required String title,
    required String message,
    required bool success,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !success,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          message.trim().isEmpty
              ? (success
                  ? 'Document uploaded successfully!'
                  : 'Upload failed')
              : message,
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: _greenAccent,
              ),
            ),
          ),
        ],
      ),
    );
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
                title: 'Back',
                showBack: true,
                onBack: _onBack,
                transparentGlassBar: true,
                scrimTopOpacity: 0.08,
              ),
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(20.tw, 4.th, 20.tw, 8.th),
                      child: Column(
                        children: [
                          Text(
                            'Add New Document',
                            style: GoogleFonts.poppins(
                              fontSize: 20.tsp,
                              fontWeight: FontWeight.w700,
                              color: _navy,
                            ),
                          ),
                          SizedBox(height: 14.th),
                          _WizardStepper(currentStep: _step, totalSteps: 3),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildTypeStep(),
                          _buildUploadAndDetailsStep(),
                          _buildReviewStep(),
                        ],
                      ),
                    ),
                    _buildBottomBar(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final isLast = _step == 2;
    final primaryLabel = isLast
        ? (_isUpdateMode ? 'Update' : 'Submit')
        : (_isUpdateMode ? 'Next (Update)' : 'Next');
    return SafeArea(
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
              disabledBackgroundColor: _greenAccent.withValues(alpha: 0.45),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: _submitting
                ? SizedBox(
                    width: 22.tw,
                    height: 22.tw,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        primaryLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 16.tsp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!isLast) ...[
                        SizedBox(width: 8.tw),
                        Icon(Icons.arrow_forward_rounded, size: 20.tsp),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeStep() {
    return _StepScroll(
      title: 'Select Document Type',
      subtitle: 'Choose the type of document you want to add.',
      child: _loadingTypes
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(color: _greenAccent),
              ),
            )
          : Column(
              children: [
                for (final type in _types) ...[
                  _TypeRow(
                    option: type,
                    selected: identical(_selectedType, type) ||
                        _selectedType?.name == type.name,
                    onTap: () {
                      setState(() => _selectedType = type);
                    },
                  ),
                  SizedBox(height: 10.th),
                ],
              ],
            ),
    );
  }

  Widget _buildUploadAndDetailsStep() {
    final hasFile = (_filePath ?? '').isNotEmpty;
    final issueText = _issueDate == null
        ? 'Select issue date'
        : DateFormat('dd/MM/yyyy').format(_issueDate!);
    final expiryText = _expiryDate == null
        ? 'Select expiry date'
        : DateFormat('dd/MM/yyyy').format(_expiryDate!);

    return _StepScroll(
      title: 'Upload & Details',
      subtitle: 'Attach the file, then enter dates. Document number is optional.',
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(16.tr),
              child: Container(
                width: double.infinity,
                padding:
                    EdgeInsets.symmetric(horizontal: 16.tw, vertical: 28.th),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(16.tr),
                  border: Border.all(
                    color: _skyAccent.withValues(alpha: 0.55),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      hasFile
                          ? Icons.insert_drive_file_rounded
                          : Icons.cloud_upload_outlined,
                      size: 40.tsp,
                      color: _greenAccent,
                    ),
                    SizedBox(height: 10.th),
                    Text(
                      hasFile
                          ? (_fileName ?? 'Selected file')
                          : 'Tap to choose a file',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14.tsp,
                        fontWeight: FontWeight.w600,
                        color: _navy,
                      ),
                    ),
                    if (!hasFile) ...[
                      SizedBox(height: 6.th),
                      const _FieldLabelTag.mandatory(),
                    ],
                    SizedBox(height: 4.th),
                    Text(
                      'PDF, DOC, DOCX, JPG, PNG',
                      style: GoogleFonts.poppins(
                        fontSize: 12.tsp,
                        color: const Color(0xFF7B8290),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (hasFile) ...[
            SizedBox(height: 8.th),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _fileName = null;
                  _filePath = null;
                });
              },
              icon: const Icon(Icons.close_rounded, size: 18),
              label: Text(
                'Remove file',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFC62828),
              ),
            ),
          ],
          SizedBox(height: 14.th),
          _FieldCard(
            label: 'Document Number',
            labelTag: 'Optional',
            child: TextField(
              controller: _numberController,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.poppins(
                fontSize: 15.tsp,
                fontWeight: FontWeight.w600,
                color: _navy,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. 784-XXXX-XXXXXXX-X',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 14.tsp,
                  color: const Color(0xFF9AA3AF),
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          SizedBox(height: 10.th),
          _FieldCard(
            label: 'Issue Date',
            isRequired: true,
            onTap: () => _pickDate(issue: true),
            trailing: Icon(
              Icons.calendar_today_outlined,
              size: 18.tsp,
              color: const Color(0xFF7B8290),
            ),
            child: Text(
              issueText,
              style: GoogleFonts.poppins(
                fontSize: 14.tsp,
                fontWeight: FontWeight.w600,
                color: _issueDate == null ? const Color(0xFF9AA3AF) : _navy,
              ),
            ),
          ),
          SizedBox(height: 10.th),
          _FieldCard(
            label: 'Expiry Date',
            isRequired: true,
            onTap: () => _pickDate(issue: false),
            trailing: Icon(
              Icons.event_outlined,
              size: 18.tsp,
              color: const Color(0xFF7B8290),
            ),
            child: Text(
              expiryText,
              style: GoogleFonts.poppins(
                fontSize: 14.tsp,
                fontWeight: FontWeight.w600,
                color: _expiryDate == null ? const Color(0xFF9AA3AF) : _navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    String fmt(DateTime? d) =>
        d == null ? '—' : DateFormat('dd/MM/yyyy').format(d);
    final number = _numberController.text.trim();

    return _StepScroll(
      title: 'Review & Submit',
      subtitle: 'Confirm the details before uploading.',
      child: Column(
        children: [
          _ReviewRow(label: 'Document Type', value: _selectedType?.name ?? '—'),
          SizedBox(height: 10.th),
          _ReviewRow(
            label: 'Document Number',
            value: number.isEmpty ? '—' : number,
          ),
          SizedBox(height: 10.th),
          _ReviewRow(label: 'Issue Date', value: fmt(_issueDate)),
          SizedBox(height: 10.th),
          _ReviewRow(label: 'Expiry Date', value: fmt(_expiryDate)),
          SizedBox(height: 10.th),
          _ReviewRow(label: 'File', value: _fileName ?? '—'),
        ],
      ),
    );
  }
}

class _DocTypeOption {
  const _DocTypeOption({required this.name, this.id});

  final String name;
  final int? id;
}

class _WizardStepper extends StatelessWidget {
  const _WizardStepper({
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < totalSteps; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: i <= currentStep
                    ? _greenAccent.withValues(alpha: 0.55)
                    : const Color(0xFFD9DEE5),
              ),
            ),
          _StepDot(index: i, active: i <= currentStep, current: i == currentStep),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.active,
    required this.current,
  });

  final int index;
  final bool active;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final bg = current || active ? _greenAccent : const Color(0xFFE8ECF0);
    final fg = current || active ? Colors.white : const Color(0xFF7B8290);

    return Container(
      width: 30.tw,
      height: 30.tw,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: current
            ? [
                BoxShadow(
                  color: _greenAccent.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Text(
        '${index + 1}',
        style: GoogleFonts.poppins(
          fontSize: 13.tsp,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _StepScroll extends StatelessWidget {
  const _StepScroll({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.tw, 8.th, 16.tw, 16.th),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 22.tsp,
              fontWeight: FontWeight.w700,
              color: _navy,
            ),
          ),
          SizedBox(height: 4.th),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 13.tsp,
              color: const Color(0xFF7B8290),
            ),
          ),
          SizedBox(height: 16.th),
          child,
        ],
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _DocTypeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = _typeVisual(option.name);
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
                child: Icon(
                  visual.icon,
                  color: visual.fg,
                  size: 22.tsp,
                ),
              ),
              SizedBox(width: 12.tw),
              Expanded(
                child: Text(
                  option.name,
                  style: GoogleFonts.poppins(
                    fontSize: 15.tsp,
                    fontWeight: FontWeight.w600,
                    color: _navy,
                  ),
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

class _TypeVisual {
  const _TypeVisual({
    required this.bg,
    required this.fg,
    required this.icon,
  });

  final Color bg;
  final Color fg;
  final IconData icon;
}

/// Lower = shown first (UAE employee docs importance).
int _documentTypeImportance(String name) {
  final t = name.toLowerCase().trim();
  // More specific phrases first so "Birth Certificate" ≠ generic certificate.
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
    'job offer',
    'offer letter',
    'university certificate',
    'birth certificate',
    'birth certificates',
    'emirates',
    'labor',
    'labour',
    'driving',
    'insurance',
    'medical',
    'photo',
    'cv',
    'resume',
    'offer',
    'contract',
    'university',
    'birth',
    'certificate',
    'certification',
    'noc',
    'pension',
  ];
  for (var i = 0; i < ranked.length; i++) {
    if (t.contains(ranked[i])) return i;
  }
  return 1000;
}

_TypeVisual _typeVisual(String name) {
  final t = name.toLowerCase().trim();

  if (t.contains('emirates') || t.contains('eid')) {
    return const _TypeVisual(
      bg: Color(0xFFE3F0FF),
      fg: Color(0xFF1565C0),
      icon: Icons.badge_rounded,
    );
  }
  if (t.contains('passport')) {
    return const _TypeVisual(
      bg: Color(0xFF1E4F8A),
      fg: Colors.white,
      icon: Icons.menu_book_rounded,
    );
  }
  if (t.contains('residence') || t.contains('resident')) {
    return const _TypeVisual(
      bg: Color(0xFFE0F2F1),
      fg: Color(0xFF00796B),
      icon: Icons.home_work_rounded,
    );
  }
  if (t.contains('visa')) {
    return const _TypeVisual(
      bg: Color(0xFFEDE7F6),
      fg: Color(0xFF5E35B1),
      icon: Icons.flight_takeoff_rounded,
    );
  }
  if (t.contains('labor') || t.contains('labour')) {
    return const _TypeVisual(
      bg: Color(0xFFFFF1D9),
      fg: Color(0xFFC47A12),
      icon: Icons.engineering_rounded,
    );
  }
  if (t.contains('driving') || t.contains('license') || t.contains('licence')) {
    return const _TypeVisual(
      bg: Color(0xFFFFEBEE),
      fg: Color(0xFFD84315),
      icon: Icons.directions_car_filled_rounded,
    );
  }
  if (t.contains('insurance') || t.contains('medical')) {
    return const _TypeVisual(
      bg: Color(0xFFFFE5E5),
      fg: Color(0xFFC62828),
      icon: Icons.medical_services_rounded,
    );
  }
  if (t.contains('photo') || t.contains('picture') || t.contains('image')) {
    return const _TypeVisual(
      bg: Color(0xFFF3E5F5),
      fg: Color(0xFF8E24AA),
      icon: Icons.photo_camera_rounded,
    );
  }
  if (t == 'cv' || t.contains('cv') || t.contains('resume')) {
    return const _TypeVisual(
      bg: Color(0xFF37474F),
      fg: Colors.white,
      icon: Icons.work_rounded,
    );
  }
  if (t.contains('job offer') || t.contains('offer letter') || t.contains('offer')) {
    return const _TypeVisual(
      bg: Color(0xFFE8F5E9),
      fg: Color(0xFF2E7D32),
      icon: Icons.handshake_rounded,
    );
  }
  if (t.contains('contract')) {
    return const _TypeVisual(
      bg: Color(0xFFE3F2FD),
      fg: Color(0xFF0277BD),
      icon: Icons.article_rounded,
    );
  }
  if (t.contains('university') || t.contains('degree') || t.contains('diploma')) {
    return const _TypeVisual(
      bg: Color(0xFFE8EAF6),
      fg: Color(0xFF3949AB),
      icon: Icons.school_rounded,
    );
  }
  if (t.contains('birth')) {
    return const _TypeVisual(
      bg: Color(0xFFFCE4EC),
      fg: Color(0xFFC2185B),
      icon: Icons.child_care_rounded,
    );
  }
  if (t.contains('cert')) {
    return const _TypeVisual(
      bg: Color(0xFFE2F3E9),
      fg: Color(0xFF1F7A4D),
      icon: Icons.workspace_premium_rounded,
    );
  }
  if (t.contains('noc')) {
    return const _TypeVisual(
      bg: Color(0xFFFFF8E1),
      fg: Color(0xFFF9A825),
      icon: Icons.verified_user_rounded,
    );
  }
  if (t.contains('pension')) {
    return const _TypeVisual(
      bg: Color(0xFFE0F7FA),
      fg: Color(0xFF00838F),
      icon: Icons.account_balance_rounded,
    );
  }
  // Stable unique color/icon for unknown types (hash of name).
  final palette = <(Color, Color, IconData)>[
    (Color(0xFFE8EEF7), Color(0xFF3F51B5), Icons.folder_rounded),
    (Color(0xFFFFF3E0), Color(0xFFEF6C00), Icons.insert_drive_file_rounded),
    (Color(0xFFE0F2F1), Color(0xFF00695C), Icons.topic_rounded),
    (Color(0xFFF3E5F5), Color(0xFF6A1B9A), Icons.note_rounded),
    (Color(0xFFFFEBEE), Color(0xFFAD1457), Icons.description_rounded),
  ];
  final idx = name.hashCode.abs() % palette.length;
  final pick = palette[idx];
  return _TypeVisual(bg: pick.$1, fg: pick.$2, icon: pick.$3);
}

class _FieldLabelTag extends StatelessWidget {
  const _FieldLabelTag.optional()
      : label = 'Optional',
        bg = const Color(0xFF7EB6D9),
        fg = const Color(0xFF1A4F6E);

  const _FieldLabelTag.mandatory()
      : label = 'Mandatory',
        bg = const Color(0xFFC62828),
        fg = const Color(0xFF8E1B1B);

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.tw, vertical: 2.th),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bg.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10.tsp,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.label,
    required this.child,
    this.onTap,
    this.trailing,
    this.isRequired = false,
    this.labelTag,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isRequired;
  final String? labelTag;

  @override
  Widget build(BuildContext context) {
    final Widget? tag;
    if (isRequired) {
      tag = const _FieldLabelTag.mandatory();
    } else if ((labelTag ?? '').toLowerCase() == 'optional') {
      tag = const _FieldLabelTag.optional();
    } else {
      tag = null;
    }

    final content = Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14.tw, 12.th, 12.tw, 12.th),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14.tr),
        border: Border.all(
          color: _skyAccent.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 11.tsp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF7B8290),
                        ),
                      ),
                    ),
                    if (tag != null) ...[
                      SizedBox(width: 8.tw),
                      tag,
                    ],
                  ],
                ),
                SizedBox(height: 4.th),
                child,
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.tr),
        child: content,
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14.tw, 12.th, 14.tw, 12.th),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14.tr),
        border: Border.all(
          color: _skyAccent.withValues(alpha: 0.55),
          width: 1,
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
              color: const Color(0xFF7B8290),
            ),
          ),
          SizedBox(height: 4.th),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14.tsp,
              fontWeight: FontWeight.w700,
              color: _navy,
            ),
          ),
        ],
      ),
    );
  }
}
