import 'dart:convert';

import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/hr_management/widgets/hr_request_form_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';

class HrCertificateRequestScreen extends ConsumerStatefulWidget {
  const HrCertificateRequestScreen({super.key});

  static const draftKey = 'hr_draft_certificate_v1';

  @override
  ConsumerState<HrCertificateRequestScreen> createState() =>
      _HrCertificateRequestScreenState();
}

class _HrCertificateRequestScreenState
    extends ConsumerState<HrCertificateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _certType;
  String _language = 'en';
  final _description = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  void _loadDraft() {
    final raw =
        SharedPref().getPreferenceString(HrCertificateRequestScreen.draftKey);
    if (raw.isEmpty) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _certType = m['type'] as String?;
      _language = m['language'] as String? ?? 'en';
      _description.text = m['description'] as String? ?? '';
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    await SharedPref().setPreferencesString(
      HrCertificateRequestScreen.draftKey,
      jsonEncode({
        'type': _certType,
        'language': _language,
        'description': _description.text,
      }),
    );
    Fluttertoast.showToast(msg: 'Draft saved');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final ok = await HrRequestFormUi.submit(
      api: ref.read(hrApiClientProvider),
      code: 'CERTIFICATE',
      fields: {
        'certificate_type': _certType,
        'language': _language,
      },
      description: _description.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      await SharedPref().removePreference(HrCertificateRequestScreen.draftKey);
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
      title: 'Certificate',
      formKey: _formKey,
      submitting: _submitting,
      onSaveDraft: _saveDraft,
      onSubmit: _submit,
      children: [
        HrRequestFormUi.label('Certificate Type *'),
        HrRequestFormUi.dropdown<String>(
          value: _certType,
          hint: 'Select type',
          items: const [
            DropdownMenuItem(value: 'salary', child: Text('Salary Certificate')),
            DropdownMenuItem(
                value: 'no_opjection',
                child: Text('No Objection Certificate [NOC]')),
            DropdownMenuItem(
                value: 'experience', child: Text('Experience Certificate')),
            DropdownMenuItem(
                value: 'whom', child: Text('To Whom It May Concern')),
          ],
          onChanged: (v) => setState(() => _certType = v),
          validator: (v) => v == null ? 'Required' : null,
        ),
        SizedBox(height: 14.h),
        HrRequestFormUi.label('Language *'),
        HrRequestFormUi.dropdown<String>(
          value: _language,
          hint: 'Language',
          items: const [
            DropdownMenuItem(value: 'en', child: Text('English')),
            DropdownMenuItem(value: 'ar', child: Text('Arabic')),
          ],
          onChanged: (v) => setState(() => _language = v ?? 'en'),
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
