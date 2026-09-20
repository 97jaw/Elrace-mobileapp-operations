import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_documents/widgets/my_documents_silk_background.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_glass_header.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

const Color _skyAccent = Color(0xFF7EB6D9);
const Color _greenAccent = Color(0xFF1F7A4D);
const Color _navy = Color(0xFF1E2365);

/// Result returned to the request hub after attaching one required document.
class FamilyDocumentAttachResult {
  const FamilyDocumentAttachResult({
    required this.field,
    required this.path,
    required this.filename,
    required this.expiry,
  });

  final String field;
  final String path;
  final String filename;
  final DateTime expiry;
}

/// Per-document attach step — does not call submit APIs.
class FamilyDocumentAttachScreen extends StatefulWidget {
  const FamilyDocumentAttachScreen({
    super.key,
    required this.field,
    required this.label,
    required this.allowedType,
    this.initialPath,
    this.initialFilename,
    this.initialExpiry,
  });

  final String field;
  final String label;
  final String allowedType;
  final String? initialPath;
  final String? initialFilename;
  final DateTime? initialExpiry;

  @override
  State<FamilyDocumentAttachScreen> createState() =>
      _FamilyDocumentAttachScreenState();
}

class _FamilyDocumentAttachScreenState extends State<FamilyDocumentAttachScreen> {
  String? _path;
  String? _filename;
  DateTime? _expiry;

  bool get _imageOnly => widget.allowedType.toLowerCase() == 'image';

  /// Birth/marriage certificates: date may be historical.
  /// Identity / travel / photo: must still be valid (today or later).
  bool get _allowsPastExpiry {
    final f = widget.field.toLowerCase();
    return f.contains('birth_certificate') || f.contains('marriage_certificate');
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _path = widget.initialPath;
    _filename = widget.initialFilename;
    _expiry = widget.initialExpiry;
  }

  Future<void> _pickFile() async {
    final extensions = _imageOnly
        ? const ['jpg', 'jpeg', 'png']
        : const ['pdf', 'jpg', 'jpeg', 'png'];
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    if (picked.path == null) return;
    setState(() {
      _path = picked.path;
      _filename = picked.name;
    });
  }

  Future<void> _pickExpiry() async {
    final today = _today;
    final first = _allowsPastExpiry ? DateTime(1970) : today;
    final last = DateTime(today.year + 40);
    var initial = _expiry ??
        (_allowsPastExpiry ? today : today.add(const Duration(days: 365)));
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: _allowsPastExpiry ? 'Document date / expiry' : 'Expiry date',
    );
    if (picked == null || !mounted) return;

    final err = _validateExpiry(picked);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    setState(() => _expiry = picked);
  }

  String? _validateExpiry(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    if (_allowsPastExpiry) {
      if (day.isAfter(DateTime(_today.year + 40, _today.month, _today.day))) {
        return 'Date is too far in the future.';
      }
      return null;
    }
    if (day.isBefore(_today)) {
      return 'Expiry date must be today or a future date.';
    }
    return null;
  }

  void _onAttach() {
    final path = (_path ?? '').trim();
    final name = (_filename ?? '').trim();
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a file.')),
      );
      return;
    }
    if (_expiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the expiry date.')),
      );
      return;
    }
    final err = _validateExpiry(_expiry!);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    Navigator.of(context).pop(
      FamilyDocumentAttachResult(
        field: widget.field,
        path: path,
        filename: name.isEmpty ? 'document' : name,
        expiry: _expiry!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = (_path ?? '').isNotEmpty;
    return MyDocumentsSilkBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            ProductivityGlassHeader(
              title: widget.label,
              showBack: true,
              transparentGlassBar: true,
              scrimTopOpacity: 0.08,
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16.tw, 8.th, 16.tw, 16.th),
                children: [
                  Text(
                    'Attach document',
                    style: GoogleFonts.poppins(
                      fontSize: 15.tsp,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                  SizedBox(height: 4.th),
                  Text(
                    'Attaches this file to your request only. Submit happens on the request screen when all documents are ready.',
                    style: GoogleFonts.poppins(
                      fontSize: 12.tsp,
                      color: const Color(0xFF7B8290),
                    ),
                  ),
                  SizedBox(height: 16.th),
                  InkWell(
                    onTap: _pickFile,
                    borderRadius: BorderRadius.circular(16.tr),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 28.th),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(16.tr),
                        border: Border.all(
                          color: hasFile
                              ? _greenAccent.withValues(alpha: 0.5)
                              : _skyAccent.withValues(alpha: 0.5),
                        ),
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
                            hasFile
                                ? (_filename ?? 'Selected file')
                                : 'Tap to choose a file',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 13.tsp,
                              fontWeight: FontWeight.w600,
                              color: _navy,
                            ),
                          ),
                          SizedBox(height: 4.th),
                          Text(
                            _imageOnly ? 'JPG / PNG' : 'PDF, JPG or PNG',
                            style: GoogleFonts.poppins(
                              fontSize: 11.tsp,
                              color: const Color(0xFF8D8D8D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 12.th),
                  InkWell(
                    onTap: _pickExpiry,
                    borderRadius: BorderRadius.circular(14.tr),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.tw,
                        vertical: 14.th,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(14.tr),
                        border: Border.all(color: const Color(0xFFE4E7EC)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Expiry date (mandatory)',
                            style: GoogleFonts.poppins(
                              fontSize: 11.tsp,
                              color: const Color(0xFF7B8290),
                            ),
                          ),
                          SizedBox(height: 4.th),
                          Text(
                            _expiry == null
                                ? 'Select expiry date'
                                : DateFormat('dd/MM/yyyy').format(_expiry!),
                            style: GoogleFonts.poppins(
                              fontSize: 13.tsp,
                              fontWeight: FontWeight.w600,
                              color: _navy,
                            ),
                          ),
                          if (_allowsPastExpiry) ...[
                            SizedBox(height: 4.th),
                            Text(
                              'Certificates may use a past document date.',
                              style: GoogleFonts.poppins(
                                fontSize: 10.tsp,
                                color: const Color(0xFF9AA3AF),
                              ),
                            ),
                          ] else ...[
                            SizedBox(height: 4.th),
                            Text(
                              'Must be today or a future date.',
                              style: GoogleFonts.poppins(
                                fontSize: 10.tsp,
                                color: const Color(0xFF9AA3AF),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.tw, 8.th, 16.tw, 12.th),
                child: SizedBox(
                  width: double.infinity,
                  height: 52.th,
                  child: ElevatedButton(
                    onPressed: _onAttach,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: _greenAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(
                      'Attach',
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
    );
  }
}
