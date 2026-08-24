import 'dart:convert';

import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/hr_management/widgets/hr_request_form_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';

class HrTerminationRequestScreen extends ConsumerStatefulWidget {
  const HrTerminationRequestScreen({super.key});

  static const draftKey = 'hr_draft_termination_v1';

  @override
  ConsumerState<HrTerminationRequestScreen> createState() =>
      _HrTerminationRequestScreenState();
}

class _HrTerminationRequestScreenState
    extends ConsumerState<HrTerminationRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _type;
  DateTime? _lastDay;
  bool _immediate = false;
  final _description = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  void _loadDraft() {
    final raw =
        SharedPref().getPreferenceString(HrTerminationRequestScreen.draftKey);
    if (raw.isEmpty) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _type = m['type'] as String?;
      _immediate = m['immediate'] == true;
      _description.text = m['description'] as String? ?? '';
      final d = m['lastDay'] as String?;
      if (d != null) _lastDay = DateTime.tryParse(d);
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    await SharedPref().setPreferencesString(
      HrTerminationRequestScreen.draftKey,
      jsonEncode({
        'type': _type,
        'immediate': _immediate,
        'description': _description.text,
        'lastDay': _lastDay?.toIso8601String(),
      }),
    );
    Fluttertoast.showToast(msg: 'Draft saved');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lastDay == null) {
      Fluttertoast.showToast(msg: 'Select expected last day');
      return;
    }
    setState(() => _submitting = true);
    final ok = await HrRequestFormUi.submit(
      api: ref.read(hrApiClientProvider),
      code: 'TERMINATION',
      fields: {
        'termination_type': _type,
        'emp_last_day': HrRequestFormUi.isoDate(_lastDay!),
        'immediate_terminate': _immediate,
      },
      description: _description.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      await SharedPref().removePreference(HrTerminationRequestScreen.draftKey);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HrLegacyRequestFormShell(
      title: 'Termination',
      formKey: _formKey,
      submitting: _submitting,
      onSaveDraft: _saveDraft,
      onSubmit: _submit,
      children: [
        HrRequestFormUi.label('Termination Type *'),
        HrRequestFormUi.dropdown<String>(
          value: _type,
          hint: 'Select type',
          items: const [
            DropdownMenuItem(value: 'performance', child: Text('Performance')),
            DropdownMenuItem(value: 'redundancy', child: Text('Redundancy')),
            DropdownMenuItem(value: 'disciplinary', child: Text('Disciplinary')),
          ],
          onChanged: (v) => setState(() => _type = v),
          validator: (v) => v == null ? 'Required' : null,
        ),
        SizedBox(height: 14.h),
        HrRequestFormUi.dateButton(
          labelText: 'Expected Last Day *',
          date: _lastDay,
          onTap: () async {
            final d =
                await HrRequestFormUi.pickDate(context, initial: _lastDay);
            if (d != null) setState(() => _lastDay = d);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Immediate Terminate',
            style: HrRequestFormUi.valueStyle().copyWith(fontSize: 13.sp),
          ),
          value: _immediate,
          activeColor: HrRequestFormUi.accentGrey,
          onChanged: (v) => setState(() => _immediate = v),
        ),
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
