import 'dart:convert';

import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/hr_management/widgets/hr_request_form_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';

class HrIncrementRequestScreen extends ConsumerStatefulWidget {
  const HrIncrementRequestScreen({super.key});

  static const draftKey = 'hr_draft_increment_v1';

  @override
  ConsumerState<HrIncrementRequestScreen> createState() =>
      _HrIncrementRequestScreenState();
}

class _HrIncrementRequestScreenState
    extends ConsumerState<HrIncrementRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _incrementType = 'amount';
  DateTime? _effective;
  final _suggest = TextEditingController();
  final _description = TextEditingController();
  String? _salaryRange;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _effective = DateTime.now();
    _loadDraft();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMeta());
  }

  Future<void> _loadMeta() async {
    final env =
        await ref.read(hrApiClientProvider).fetchRequestFormMeta(code: 'INCREMENT');
    if (!mounted || !env.success) return;
    final readonly = env.data?['readonly'];
    if (readonly is Map) {
      setState(() {
        _salaryRange = readonly['salary_range_label']?.toString() ??
            (readonly['salary_min'] != null && readonly['salary_max'] != null
                ? '${readonly['salary_min']} - ${readonly['salary_max']}'
                : null);
      });
    }
  }

  void _loadDraft() {
    final raw =
        SharedPref().getPreferenceString(HrIncrementRequestScreen.draftKey);
    if (raw.isEmpty) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _incrementType = m['increment_type'] as String? ?? 'amount';
      _suggest.text = m['suggest'] as String? ?? '';
      _description.text = m['description'] as String? ?? '';
      final d = m['effective'] as String?;
      if (d != null) _effective = DateTime.tryParse(d) ?? _effective;
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    await SharedPref().setPreferencesString(
      HrIncrementRequestScreen.draftKey,
      jsonEncode({
        'increment_type': _incrementType,
        'suggest': _suggest.text,
        'description': _description.text,
        'effective': _effective?.toIso8601String(),
      }),
    );
    Fluttertoast.showToast(msg: 'Draft saved');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_effective == null) {
      Fluttertoast.showToast(msg: 'Select effective date');
      return;
    }
    setState(() => _submitting = true);
    final ok = await HrRequestFormUi.submit(
      api: ref.read(hrApiClientProvider),
      code: 'INCREMENT',
      fields: {
        'increment_effective_date': HrRequestFormUi.isoDate(_effective!),
        'increment_type': _incrementType,
        'suggested_salary_by_employee':
            double.tryParse(_suggest.text.trim()) ?? 0,
      },
      description: _description.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      await SharedPref().removePreference(HrIncrementRequestScreen.draftKey);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _suggest.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HrLegacyRequestFormShell(
      title: 'Salary Increment',
      formKey: _formKey,
      submitting: _submitting,
      onSaveDraft: _saveDraft,
      onSubmit: _submit,
      children: [
        if (_salaryRange != null)
          HrRequestFormUi.readonlyRow('Salary Range', _salaryRange!),
        HrRequestFormUi.dateButton(
          labelText: 'Effective Date *',
          date: _effective,
          onTap: () async {
            final d =
                await HrRequestFormUi.pickDate(context, initial: _effective);
            if (d != null) setState(() => _effective = d);
          },
        ),
        SizedBox(height: 14.h),
        HrRequestFormUi.label('Increment Type *'),
        HrRequestFormUi.dropdown<String>(
          value: _incrementType,
          hint: 'Select type',
          items: const [
            DropdownMenuItem(value: 'amount', child: Text('Amount')),
            DropdownMenuItem(value: 'car', child: Text('Car')),
          ],
          onChanged: (v) => setState(() => _incrementType = v),
        ),
        SizedBox(height: 14.h),
        HrRequestFormUi.label('Suggest by Employee *'),
        TextFormField(
          controller: _suggest,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: HrRequestFormUi.fieldDecoration('0'),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Required' : null,
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
