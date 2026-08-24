import 'dart:convert';

import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/hr_management/widgets/hr_request_form_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';

class HrResignationRequestScreen extends ConsumerStatefulWidget {
  const HrResignationRequestScreen({super.key});

  static const draftKey = 'hr_draft_resignation_v1';

  @override
  ConsumerState<HrResignationRequestScreen> createState() =>
      _HrResignationRequestScreenState();
}

class _HrResignationRequestScreenState
    extends ConsumerState<HrResignationRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _noticeStart;
  DateTime? _lastDay;
  String _resignationType = 'resigned';
  final _noticePeriod = TextEditingController(text: '30');
  final _reason = TextEditingController();
  final _description = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _noticeStart = DateTime.now();
    _lastDay = DateTime.now().add(const Duration(days: 30));
    _loadDraft();
  }

  void _loadDraft() {
    final raw =
        SharedPref().getPreferenceString(HrResignationRequestScreen.draftKey);
    if (raw.isEmpty) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _resignationType = m['type'] as String? ?? 'resigned';
      _noticePeriod.text = m['notice'] as String? ?? '30';
      _reason.text = m['reason'] as String? ?? '';
      _description.text = m['description'] as String? ?? '';
      final ns = m['noticeStart'] as String?;
      final ld = m['lastDay'] as String?;
      if (ns != null) _noticeStart = DateTime.tryParse(ns);
      if (ld != null) _lastDay = DateTime.tryParse(ld);
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    await SharedPref().setPreferencesString(
      HrResignationRequestScreen.draftKey,
      jsonEncode({
        'type': _resignationType,
        'notice': _noticePeriod.text,
        'reason': _reason.text,
        'description': _description.text,
        'noticeStart': _noticeStart?.toIso8601String(),
        'lastDay': _lastDay?.toIso8601String(),
      }),
    );
    Fluttertoast.showToast(msg: 'Draft saved');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_noticeStart == null || _lastDay == null) {
      Fluttertoast.showToast(msg: 'Select notice start and last day');
      return;
    }
    setState(() => _submitting = true);
    final ok = await HrRequestFormUi.submit(
      api: ref.read(hrApiClientProvider),
      code: 'RESIGNATION',
      fields: {
        'resignation_type': _resignationType,
        'notice_period_start_date': HrRequestFormUi.isoDate(_noticeStart!),
        'expected_revealing_date': HrRequestFormUi.isoDate(_lastDay!),
        'notice_period': int.tryParse(_noticePeriod.text.trim()) ?? 30,
        'reason': _reason.text.trim(),
      },
      description: _description.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      await SharedPref().removePreference(HrResignationRequestScreen.draftKey);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _noticePeriod.dispose();
    _reason.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HrLegacyRequestFormShell(
      title: 'Resignation',
      formKey: _formKey,
      submitting: _submitting,
      onSaveDraft: _saveDraft,
      onSubmit: _submit,
      children: [
        HrRequestFormUi.dateButton(
          labelText: 'Notice Period Start Date *',
          date: _noticeStart,
          onTap: () async {
            final d =
                await HrRequestFormUi.pickDate(context, initial: _noticeStart);
            if (d != null) setState(() => _noticeStart = d);
          },
        ),
        SizedBox(height: 14.h),
        HrRequestFormUi.label('Resignation Type *'),
        HrRequestFormUi.dropdown<String>(
          value: _resignationType,
          hint: 'Select type',
          items: const [
            DropdownMenuItem(
                value: 'resigned', child: Text('Normal Resignation')),
          ],
          onChanged: (v) => setState(() => _resignationType = v ?? 'resigned'),
        ),
        SizedBox(height: 14.h),
        HrRequestFormUi.dateButton(
          labelText: 'Last Day of Employee *',
          date: _lastDay,
          onTap: () async {
            final d =
                await HrRequestFormUi.pickDate(context, initial: _lastDay);
            if (d != null) setState(() => _lastDay = d);
          },
        ),
        SizedBox(height: 14.h),
        HrRequestFormUi.label('Notice Period (days) *'),
        TextFormField(
          controller: _noticePeriod,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: HrRequestFormUi.fieldDecoration('30'),
          validator: (v) =>
              (int.tryParse(v?.trim() ?? '') ?? 0) <= 0 ? 'Required' : null,
        ),
        SizedBox(height: 14.h),
        HrRequestFormUi.label('Reason'),
        TextFormField(
          controller: _reason,
          minLines: 2,
          maxLines: 4,
          decoration: HrRequestFormUi.fieldDecoration('Reason for leaving'),
        ),
        SizedBox(height: 14.h),
        HrRequestFormUi.label('Description'),
        TextFormField(
          controller: _description,
          minLines: 3,
          maxLines: 6,
          decoration: HrRequestFormUi.fieldDecoration('Write your description...'),
        ),
      ],
    );
  }
}
