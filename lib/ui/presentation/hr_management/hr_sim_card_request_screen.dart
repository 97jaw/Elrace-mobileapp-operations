import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:convert';

import 'package:el_race/core/hr_management/network/hr_api_client.dart';
import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

/// SIM Card Request — SRD §5.2 / TASKS F2.
class HrSimCardRequestScreen extends ConsumerStatefulWidget {
  const HrSimCardRequestScreen({super.key});

  static const draftKey = 'hr_draft_sim_card_v1';

  @override
  ConsumerState<HrSimCardRequestScreen> createState() =>
      _HrSimCardRequestScreenState();
}

class _HrSimCardRequestScreenState extends ConsumerState<HrSimCardRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _reason;
  String? _planType;
  DateTime? _requiredBy;
  final _justification = TextEditingController();
  final _phone = TextEditingController();
  String? _attachmentName;

  static const _reasons = [
    'New Hire',
    'Replacement (Lost)',
    'Replacement (Damaged)',
    'Plan Upgrade',
    'Plan Downgrade',
    'Other',
  ];
  static const _plans = ['Basic', 'Standard', 'Premium', 'Custom'];

  bool _phoneRequired(String? r) {
    if (r == null) return false;
    return r.contains('Replacement') ||
        r == 'Plan Upgrade' ||
        r == 'Plan Downgrade';
  }

  bool _uaePhoneOk(String v) {
    final s = v.replaceAll(RegExp(r'\s'), '');
    return RegExp(r'^(\+971|00971|971)?[0-9]{9}$').hasMatch(s);
  }

  @override
  void initState() {
    super.initState();
    _loadDraft();
    _requiredBy = DateTime.now().add(const Duration(days: 7));
  }

  void _loadDraft() {
    final raw = SharedPref().getPreferenceString(HrSimCardRequestScreen.draftKey);
    if (raw.isEmpty) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _reason = m['reason'] as String?;
        _planType = m['plan'] as String?;
        _justification.text = m['justification'] as String? ?? '';
        _phone.text = m['phone'] as String? ?? '';
        final d = m['requiredBy'] as String?;
        if (d != null) _requiredBy = DateTime.tryParse(d) ?? _requiredBy;
        _attachmentName = m['attachment'] as String?;
      });
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    final payload = {
      'reason': _reason,
      'plan': _planType,
      'requiredBy': _requiredBy?.toIso8601String(),
      'justification': _justification.text,
      'phone': _phone.text,
      'attachment': _attachmentName,
    };
    await SharedPref()
        .setPreferencesString(HrSimCardRequestScreen.draftKey, jsonEncode(payload));
    if (mounted) {
      Fluttertoast.showToast(msg: 'Draft saved');
    }
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.pickFiles();
    if (r != null && r.files.single.name.isNotEmpty) {
      setState(() => _attachmentName = r.files.single.name);
    }
  }

  Future<void> _pickDate() async {
    final first = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: first.add(const Duration(days: 365 * 2)),
      initialDate: _requiredBy ?? first.add(const Duration(days: 7)),
    );
    if (picked != null) setState(() => _requiredBy = picked);
  }

  Future<void> _submit(HrApiClient api) async {
    if (!_formKey.currentState!.validate()) return;
    if (_requiredBy == null) {
      Fluttertoast.showToast(msg: 'Select required-by date');
      return;
    }
    final env = await api.submitAssetRequest(
      kind: 'sim',
      payload: {
        'reason': _reason,
        'plan': _planType,
        'required_by': _requiredBy?.toIso8601String(),
        'justification': _justification.text,
        'phone': _phone.text,
        'attachment': _attachmentName,
      },
    );
    if (!mounted) return;
    if (env.success) {
      final refNo = env.data?['reference']?.toString() ?? 'HR/SIM/2026/????';
      await SharedPref().removePreference(HrSimCardRequestScreen.draftKey);
      Fluttertoast.showToast(msg: 'Request submitted — Ref: $refNo');
      Navigator.of(context).pop();
    } else {
      Fluttertoast.showToast(msg: env.error ?? 'Submit failed');
    }
  }

  @override
  void dispose() {
    _justification.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(hrApiClientProvider);
    final dateLabel = _requiredBy != null
        ? DateFormat('dd MMM yyyy').format(_requiredBy!)
        : 'Pick date';

    return Scaffold(
      backgroundColor: HrModuleColors.surface,
      appBar: AppBar(
        backgroundColor: HrModuleColors.surface,
        foregroundColor: HrModuleColors.text,
        title: Text(
          'SIM Card Request',
          style: HrModuleTypography.sectionHeading().copyWith(fontSize: 18.tsp),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(HrModuleLayout.screenPaddingH.tw),
          children: [
            Text(
              'Submit a request for a corporate SIM card',
              style: HrModuleTypography.body().copyWith(fontSize: 14.tsp),
            ),
            SizedBox(height: 16.th),
            Text('Request Reason *', style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp)),
            DropdownButtonFormField<String>(
              value: _reason,
              items: _reasons
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _reason = v),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              decoration: _fieldDecoration('Select reason'),
            ),
            SizedBox(height: HrModuleLayout.formFieldSpacingV.th),
            Text('Plan Type *', style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp)),
            DropdownButtonFormField<String>(
              value: _planType,
              items: _plans
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _planType = v),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              decoration: _fieldDecoration('Select plan'),
            ),
            SizedBox(height: HrModuleLayout.formFieldSpacingV.th),
            Text('Required By Date *', style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp)),
            OutlinedButton(
              onPressed: _pickDate,
              child: Text(dateLabel),
            ),
            SizedBox(height: HrModuleLayout.formFieldSpacingV.th),
            Text('Justification *', style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp)),
            TextFormField(
              controller: _justification,
              minLines: 3,
              maxLines: 6,
              decoration: _fieldDecoration('Min 10, max 500 characters'),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.length < 10) return 'At least 10 characters';
                if (t.length > 500) return 'Max 500 characters';
                return null;
              },
            ),
            SizedBox(height: HrModuleLayout.formFieldSpacingV.th),
            Text(
              'Current Phone Number (if replacement / plan change)',
              style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp),
            ),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: _fieldDecoration('+971…'),
              validator: (v) {
                if (!_phoneRequired(_reason)) return null;
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Required for this reason';
                if (!_uaePhoneOk(t)) return 'Use UAE format (+971… 9 digits)';
                return null;
              },
            ),
            SizedBox(height: HrModuleLayout.formFieldSpacingV.th),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.attach_file),
              label: Text(_attachmentName ?? 'Attachment (optional)'),
            ),
            SizedBox(height: 24.th),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saveDraft,
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.fromHeight(HrModuleLayout.buttonHeight.th),
                    ),
                    child: Text(
                      'Save Draft',
                      style: HrModuleTypography.button().copyWith(
                            fontSize: 14.tsp,
                            color: HrModuleColors.primary,
                          ),
                    ),
                  ),
                ),
                SizedBox(width: 12.tw),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _submit(api),
                    style: FilledButton.styleFrom(
                      backgroundColor: HrModuleColors.primary,
                      minimumSize: Size.fromHeight(HrModuleLayout.buttonHeight.th),
                    ),
                    child: Text(
                      'Submit Request',
                      style: HrModuleTypography.button().copyWith(fontSize: 14.tsp),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: HrModuleColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.tr),
        borderSide: const BorderSide(color: HrModuleColors.border),
      ),
    );
  }
}
