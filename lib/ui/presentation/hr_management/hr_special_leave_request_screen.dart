import 'dart:convert';
import 'dart:io';

import 'package:el_race/core/hr_management/special_leave_rules.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/hr_management/widgets/hr_request_form_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class HrSpecialLeaveRequestScreen extends StatefulWidget {
  const HrSpecialLeaveRequestScreen({super.key, required this.kind});

  final SpecialLeaveKind kind;

  @override
  State<HrSpecialLeaveRequestScreen> createState() =>
      _HrSpecialLeaveRequestScreenState();
}

class _HrSpecialLeaveRequestScreenState
    extends State<HrSpecialLeaveRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _duration = TextEditingController();
  final _description = TextEditingController();

  DateTime? _start;
  String? _relative;
  String? _attachmentName;
  String? _attachmentB64;
  bool _submitting = false;

  String get _draftKey => 'hr_draft_leave_${widget.kind.name}_v1';

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void dispose() {
    _duration.dispose();
    _description.dispose();
    super.dispose();
  }

  int? get _enteredDuration => int.tryParse(_duration.text.trim());

  int? get _durationDays => SpecialLeaveRules.durationFor(
        kind: widget.kind,
        relative: _relative,
        entered: _enteredDuration,
      );

  DateTime? get _end {
    final start = _start;
    final days = _durationDays;
    if (start == null || days == null) return null;
    return SpecialLeaveRules.endDate(start, days);
  }

  void _loadDraft() {
    final raw = SharedPref().getPreferenceString(_draftKey);
    if (raw.isEmpty) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _relative = m['relative'] as String?;
      _duration.text = m['duration'] as String? ?? '';
      _description.text = m['description'] as String? ?? '';
      final d = m['start'] as String?;
      if (d != null) _start = DateTime.tryParse(d);
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    await SharedPref().setPreferencesString(
      _draftKey,
      jsonEncode({
        'relative': _relative,
        'duration': _duration.text,
        'description': _description.text,
        'start': _start?.toIso8601String(),
      }),
    );
    Fluttertoast.showToast(msg: 'Draft saved');
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    var bytes = file.bytes;
    if (bytes == null && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null || bytes.isEmpty) {
      Fluttertoast.showToast(msg: 'Could not read that file');
      return;
    }
    setState(() {
      _attachmentName = file.name;
      _attachmentB64 = base64Encode(bytes!);
    });
  }

  Future<void> _submit() async {
    final error = SpecialLeaveRules.validate(
      kind: widget.kind,
      start: _start,
      duration: _durationDays,
      relative: _relative,
      hasAttachment: _attachmentB64 != null && _attachmentB64!.isNotEmpty,
    );
    if (error != null) {
      Fluttertoast.showToast(msg: error);
      return;
    }
    if (widget.kind != SpecialLeaveKind.death &&
        !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final token = SharedPref.getLoginData().result?.token;
      final start = _start!;
      final days = _durationDays!;
      final end = SpecialLeaveRules.endDate(start, days)!;
      final body = <String, dynamic>{
        'request_type': 'leave',
        'leave_type': SpecialLeaveRules.apiType(widget.kind),
        'start_date': DateFormat('yyyy-MM-dd').format(start),
        'end_date': DateFormat('yyyy-MM-dd').format(end),
        'duration': days,
        'duration_type': 'days',
        'description': _description.text.trim(),
        'note': _description.text.trim(),
      };
      if (widget.kind == SpecialLeaveKind.death) {
        body['relative'] = _relative;
        body['death_attachment'] = _attachmentB64;
      } else {
        body['birth_attachment'] = _attachmentB64;
      }

      final response = await http.post(
        Uri.parse('https://erp.elrace.com/api/submit_request'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'params': body,
        }),
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      final result = data is Map ? data['result'] : null;
      final ok = response.statusCode == 200 &&
          result is Map &&
          result['status'] == 'success';
      if (ok) {
        await SharedPref().removePreference(_draftKey);
        final refNo = result['data'] is Map
            ? '${(result['data'] as Map)['reference'] ?? ''}'
            : '';
        Fluttertoast.showToast(
          msg: refNo.isEmpty
              ? 'Request submitted'
              : 'Request submitted — $refNo',
        );
        if (mounted) Navigator.of(context).pop();
        return;
      }
      Fluttertoast.showToast(
        msg: _errorMessage(data),
        toastLength: Toast.LENGTH_LONG,
      );
    } catch (_) {
      if (mounted) {
        Fluttertoast.showToast(msg: 'An error occurred. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _errorMessage(dynamic data) {
    if (data is Map) {
      final result = data['result'];
      if (result is Map && result['message'] is String) {
        final message = (result['message'] as String).trim();
        if (message.isNotEmpty) return message;
      }
      final error = data['error'];
      if (error is Map && error['message'] is String) {
        final message = (error['message'] as String).trim();
        if (message.isNotEmpty) return message;
      }
    }
    return 'Request failed';
  }

  @override
  Widget build(BuildContext context) {
    final attachmentLabel = SpecialLeaveRules.attachmentLabel(widget.kind);
    final end = _end;
    return HrLegacyRequestFormShell(
      title: SpecialLeaveRules.title(widget.kind),
      formKey: _formKey,
      submitting: _submitting,
      onSaveDraft: _saveDraft,
      onSubmit: _submit,
      children: [
        Text(
          SpecialLeaveRules.notice(widget.kind),
          style: HrRequestFormUi.fieldLabelStyle(),
        ),
        SizedBox(height: 16.h),
        HrRequestFormUi.dateButton(
          labelText: 'Start date *',
          date: _start,
          onTap: () async {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final d = await HrRequestFormUi.pickDate(
              context,
              initial: _start ?? today,
              first: today.subtract(
                Duration(days: SpecialLeaveRules.pastWindowDays(widget.kind)),
              ),
            );
            if (d != null) setState(() => _start = d);
          },
        ),
        if (widget.kind == SpecialLeaveKind.death) ...[
          SizedBox(height: 14.h),
          HrRequestFormUi.label('Deceased relative *'),
          HrRequestFormUi.dropdown<String>(
            value: _relative,
            hint: 'Select relative',
            sheetTitle: 'Deceased relative',
            items: const [
              DropdownMenuItem(
                value: 'first',
                child: Text('First degree (spouse) — 5 days'),
              ),
              DropdownMenuItem(
                value: 'second',
                child: Text('Second degree — 3 days'),
              ),
            ],
            onChanged: (v) => setState(() => _relative = v),
          ),
        ],
        SizedBox(height: 14.h),
        if (widget.kind == SpecialLeaveKind.death)
          HrRequestFormUi.readonlyRow(
            'Requested duration',
            _durationDays == null ? '—' : '$_durationDays days',
          )
        else ...[
          HrRequestFormUi.label('Duration (days) *'),
          TextFormField(
            controller: _duration,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: HrRequestFormUi.fieldDecoration('0'),
            onChanged: (_) => setState(() {}),
            validator: (v) {
              final n = int.tryParse(v?.trim() ?? '') ?? 0;
              if (n < 1) return 'Enter the number of days';
              return null;
            },
          ),
          SizedBox(height: 14.h),
        ],
        HrRequestFormUi.readonlyRow(
          'End date',
          end == null ? '—' : HrRequestFormUi.formatDate(end),
        ),
        if (attachmentLabel != null) ...[
          HrRequestFormUi.label('$attachmentLabel *'),
          InkWell(
            onTap: _pickFile,
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.upload_file_outlined,
                      size: 18.w, color: HrRequestFormUi.accentGrey),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      _attachmentName ?? 'Upload PDF or image',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HrRequestFormUi.valueStyle().copyWith(
                        color: _attachmentName == null
                            ? Colors.grey
                            : HrRequestFormUi.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 14.h),
        ],
        HrRequestFormUi.label('Description'),
        TextFormField(
          controller: _description,
          minLines: 3,
          maxLines: 6,
          decoration:
              HrRequestFormUi.fieldDecoration('Write your description...'),
        ),
      ],
    );
  }
}
