import 'dart:convert';

import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/hr_management/widgets/hr_request_form_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';

class HrEncashmentRequestScreen extends ConsumerStatefulWidget {
  const HrEncashmentRequestScreen({super.key});

  static const draftKey = 'hr_draft_encashment_v1';

  @override
  ConsumerState<HrEncashmentRequestScreen> createState() =>
      _HrEncashmentRequestScreenState();
}

class _HrEncashmentRequestScreenState
    extends ConsumerState<HrEncashmentRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _start;
  final _days = TextEditingController(text: '0');
  final _description = TextEditingController();
  double? _leaveBalance;
  double? _remaining;
  String? _attachmentName;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _start = DateTime.now();
    _loadDraft();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMeta());
  }

  Future<void> _loadMeta() async {
    final env = await ref
        .read(hrApiClientProvider)
        .fetchRequestFormMeta(code: 'ENCASHMENT');
    if (!mounted || !env.success) return;
    final readonly = env.data?['readonly'];
    if (readonly is Map) {
      setState(() {
        _leaveBalance = double.tryParse('${readonly['leave_balance'] ?? ''}');
        _remaining =
            double.tryParse('${readonly['remaining_leave_days'] ?? ''}');
      });
    }
  }

  void _loadDraft() {
    final raw =
        SharedPref().getPreferenceString(HrEncashmentRequestScreen.draftKey);
    if (raw.isEmpty) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _days.text = m['days'] as String? ?? '0';
      _description.text = m['description'] as String? ?? '';
      _attachmentName = m['attachment'] as String?;
      final d = m['start'] as String?;
      if (d != null) _start = DateTime.tryParse(d);
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    await SharedPref().setPreferencesString(
      HrEncashmentRequestScreen.draftKey,
      jsonEncode({
        'days': _days.text,
        'description': _description.text,
        'attachment': _attachmentName,
        'start': _start?.toIso8601String(),
      }),
    );
    Fluttertoast.showToast(msg: 'Draft saved');
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.pickFiles();
    if (r != null && r.files.single.name.isNotEmpty) {
      setState(() => _attachmentName = r.files.single.name);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_start == null) {
      Fluttertoast.showToast(msg: 'Select start date');
      return;
    }
    setState(() => _submitting = true);
    final ok = await HrRequestFormUi.submit(
      api: ref.read(hrApiClientProvider),
      code: 'ENCASHMENT',
      fields: {
        'request_date_from': HrRequestFormUi.isoDate(_start!),
        'encashment_days': int.tryParse(_days.text.trim()) ?? 0,
        if (_attachmentName != null) 'attachment_name': _attachmentName,
      },
      description: _description.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      await SharedPref().removePreference(HrEncashmentRequestScreen.draftKey);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _days.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HrLegacyRequestFormShell(
      title: 'Leave Encashment',
      formKey: _formKey,
      submitting: _submitting,
      onSaveDraft: _saveDraft,
      onSubmit: _submit,
      children: [
        if (_leaveBalance != null)
          HrRequestFormUi.readonlyRow(
              'Leave Balance', _leaveBalance!.toStringAsFixed(2)),
        if (_remaining != null)
          HrRequestFormUi.readonlyRow(
              'Remaining Leave Days', _remaining!.toStringAsFixed(2)),
        HrRequestFormUi.dateButton(
          labelText: 'Start Date *',
          date: _start,
          onTap: () async {
            final d = await HrRequestFormUi.pickDate(context, initial: _start);
            if (d != null) setState(() => _start = d);
          },
        ),
        SizedBox(height: 14.h),
        HrRequestFormUi.label('Encashment Days *'),
        TextFormField(
          controller: _days,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: HrRequestFormUi.fieldDecoration('0'),
          validator: (v) =>
              (int.tryParse(v?.trim() ?? '') ?? 0) <= 0 ? 'Required' : null,
        ),
        SizedBox(height: 14.h),
        HrRequestFormUi.label('GM Attachment'),
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
                    _attachmentName ?? 'Upload your file',
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
