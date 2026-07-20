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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

/// Car Allowance Request — SRD §5.4 / TASKS F4.
class HrCarAllowanceRequestScreen extends ConsumerStatefulWidget {
  const HrCarAllowanceRequestScreen({super.key});

  static const draftKey = 'hr_draft_car_allowance_v1';

  @override
  ConsumerState<HrCarAllowanceRequestScreen> createState() =>
      _HrCarAllowanceRequestScreenState();
}

class _HrCarAllowanceRequestScreenState
    extends ConsumerState<HrCarAllowanceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _allowanceType;
  final _amount = TextEditingController();
  DateTime? _effectiveFrom;
  final _justification = TextEditingController();
  String? _mulkiyaName;
  String? _licenseName;

  static const _types = [
    'Monthly Fixed',
    'Per-Trip',
    'Fuel Reimbursement',
  ];

  @override
  void initState() {
    super.initState();
    _effectiveFrom = DateTime.now();
    _loadDraft();
  }

  void _loadDraft() {
    final raw =
        SharedPref().getPreferenceString(HrCarAllowanceRequestScreen.draftKey);
    if (raw.isEmpty) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _allowanceType = m['type'] as String?;
        _amount.text = m['amount'] as String? ?? '';
        _justification.text = m['justification'] as String? ?? '';
        _mulkiyaName = m['mulkiya'] as String?;
        _licenseName = m['license'] as String?;
        final d = m['effective'] as String?;
        if (d != null) _effectiveFrom = DateTime.tryParse(d) ?? _effectiveFrom;
      });
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    final payload = {
      'type': _allowanceType,
      'amount': _amount.text,
      'effective': _effectiveFrom?.toIso8601String(),
      'justification': _justification.text,
      'mulkiya': _mulkiyaName,
      'license': _licenseName,
    };
    await SharedPref().setPreferencesString(
        HrCarAllowanceRequestScreen.draftKey, jsonEncode(payload));
    if (mounted) Fluttertoast.showToast(msg: 'Draft saved');
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = now.subtract(const Duration(days: 90));
    final picked = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: now.add(const Duration(days: 365 * 2)),
      initialDate: _effectiveFrom ?? now,
    );
    if (picked != null) {
      if (picked.isBefore(first)) return;
      setState(() => _effectiveFrom = picked);
    }
  }

  Future<void> _pickMulkiya() async {
    final r = await FilePicker.pickFiles();
    if (r != null && r.files.single.name.isNotEmpty) {
      setState(() => _mulkiyaName = r.files.single.name);
    }
  }

  Future<void> _pickLicense() async {
    final r = await FilePicker.pickFiles();
    if (r != null && r.files.single.name.isNotEmpty) {
      setState(() => _licenseName = r.files.single.name);
    }
  }

  Future<void> _submit(HrApiClient api) async {
    if (!_formKey.currentState!.validate()) return;
    if (_effectiveFrom == null) {
      Fluttertoast.showToast(msg: 'Select effective date');
      return;
    }
    final now = DateTime.now();
    if (_effectiveFrom!.isBefore(now.subtract(const Duration(days: 90)))) {
      Fluttertoast.showToast(msg: 'Effective date cannot be more than 90 days past');
      return;
    }
    if (_allowanceType == 'Monthly Fixed' &&
        (_mulkiyaName == null || _mulkiyaName!.isEmpty)) {
      Fluttertoast.showToast(
          msg: 'Vehicle registration (Mulkiya) is required for Monthly Fixed');
      return;
    }
    final env = await api.submitAssetRequest(
      kind: 'car_allowance',
      payload: {
        'allowance_type': _allowanceType,
        'amount_aed': _amount.text,
        'effective_from': _effectiveFrom!.toIso8601String(),
        'justification': _justification.text,
        'mulkiya': _mulkiyaName,
        'license': _licenseName,
      },
    );
    if (!mounted) return;
    if (env.success) {
      final refNo = env.data?['reference']?.toString() ?? '';
      await SharedPref().removePreference(HrCarAllowanceRequestScreen.draftKey);
      Fluttertoast.showToast(msg: 'Request submitted — Ref: $refNo');
      Navigator.of(context).pop();
    } else {
      Fluttertoast.showToast(msg: env.error ?? 'Submit failed');
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _justification.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(hrApiClientProvider);
    final dateLabel = _effectiveFrom != null
        ? DateFormat('dd MMM yyyy').format(_effectiveFrom!)
        : 'Pick date';

    return Scaffold(
      backgroundColor: HrModuleColors.surface,
      appBar: AppBar(
        backgroundColor: HrModuleColors.surface,
        foregroundColor: HrModuleColors.text,
        title: Text(
          'Car Allowance',
          style: HrModuleTypography.sectionHeading().copyWith(fontSize: 18.tsp),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(HrModuleLayout.screenPaddingH.tw),
          children: [
            Text(
              'Request a car allowance in lieu of a company vehicle',
              style: HrModuleTypography.body().copyWith(fontSize: 14.tsp),
            ),
            SizedBox(height: 16.th),
            Text('Allowance Type *', style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp)),
            DropdownButtonFormField<String>(
              value: _allowanceType,
              items: _types
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _allowanceType = v),
              validator: (v) => v == null ? 'Required' : null,
              decoration: _decoration('Select type'),
            ),
            SizedBox(height: HrModuleLayout.formFieldSpacingV.th),
            Text('Requested Amount (AED) *', style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp)),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: _decoration('0.00'),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Required';
                final n = double.tryParse(t);
                if (n == null || n < 0) return 'Enter a valid amount';
                return null;
              },
            ),
            SizedBox(height: HrModuleLayout.formFieldSpacingV.th),
            Text('Effective From *', style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp)),
            OutlinedButton(
              onPressed: _pickDate,
              child: Text(dateLabel),
            ),
            SizedBox(height: HrModuleLayout.formFieldSpacingV.th),
            Text('Justification *', style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp)),
            TextFormField(
              controller: _justification,
              minLines: 4,
              maxLines: 8,
              decoration: _decoration('20–1000 characters'),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.length < 20) return 'At least 20 characters';
                if (t.length > 1000) return 'Max 1000 characters';
                return null;
              },
            ),
            SizedBox(height: HrModuleLayout.formFieldSpacingV.th),
            Text('Vehicle Registration (Mulkiya)', style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp)),
            OutlinedButton.icon(
              onPressed: _pickMulkiya,
              icon: const Icon(Icons.description_outlined),
              label: Text(_mulkiyaName ?? 'Attach (optional)'),
            ),
            SizedBox(height: 8.th),
            Text('Driving License', style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp)),
            OutlinedButton.icon(
              onPressed: _pickLicense,
              icon: const Icon(Icons.badge_outlined),
              label: Text(_licenseName ?? 'Attach (optional)'),
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
                    child: Text('Save Draft', style: TextStyle(color: HrModuleColors.primary, fontSize: 14.tsp)),
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
                    child: Text('Submit Request', style: TextStyle(fontSize: 14.tsp)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: HrModuleColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.tr),
      ),
    );
  }
}
