import 'dart:convert';

import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/hr_management/widgets/hr_request_form_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';

class HrLoanRequestScreen extends ConsumerStatefulWidget {
  const HrLoanRequestScreen({super.key});

  static const draftKey = 'hr_draft_loan_v1';

  @override
  ConsumerState<HrLoanRequestScreen> createState() => _HrLoanRequestScreenState();
}

class _HrLoanRequestScreenState extends ConsumerState<HrLoanRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _effective;
  String _loanType = 'graduity';
  final _amount = TextEditingController(text: '0.00');
  final _description = TextEditingController();
  int? _netWorkedDays;
  double? _totalGratuity;
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
        await ref.read(hrApiClientProvider).fetchRequestFormMeta(code: 'LOAN');
    if (!mounted || !env.success) return;
    final readonly = env.data?['readonly'];
    if (readonly is Map) {
      setState(() {
        _netWorkedDays = int.tryParse('${readonly['net_worked_days'] ?? ''}');
        _totalGratuity = double.tryParse('${readonly['total_gratuity'] ?? ''}');
      });
    }
  }

  void _loadDraft() {
    final raw = SharedPref().getPreferenceString(HrLoanRequestScreen.draftKey);
    if (raw.isEmpty) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _loanType = m['type'] as String? ?? 'graduity';
      _amount.text = m['amount'] as String? ?? '0.00';
      _description.text = m['description'] as String? ?? '';
      final d = m['effective'] as String?;
      if (d != null) _effective = DateTime.tryParse(d);
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    await SharedPref().setPreferencesString(
      HrLoanRequestScreen.draftKey,
      jsonEncode({
        'type': _loanType,
        'amount': _amount.text,
        'description': _description.text,
        'effective': _effective?.toIso8601String(),
      }),
    );
    Fluttertoast.showToast(msg: 'Draft saved');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final ok = await HrRequestFormUi.submit(
      api: ref.read(hrApiClientProvider),
      code: 'LOAN',
      fields: {
        'loan_type': _loanType,
        'loan_amount': double.tryParse(_amount.text.trim()) ?? 0,
        if (_effective != null)
          'effective_date': HrRequestFormUi.isoDate(_effective!),
      },
      description: _description.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      await SharedPref().removePreference(HrLoanRequestScreen.draftKey);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HrLegacyRequestFormShell(
      title: 'Loan',
      formKey: _formKey,
      submitting: _submitting,
      onSaveDraft: _saveDraft,
      onSubmit: _submit,
      children: [
        if (_netWorkedDays != null)
          HrRequestFormUi.readonlyRow('Net Worked Days', '$_netWorkedDays'),
        if (_totalGratuity != null)
          HrRequestFormUi.readonlyRow(
              'Total Gratuity', _totalGratuity!.toStringAsFixed(2)),
        HrRequestFormUi.dateButton(
          labelText: 'Effective Date',
          date: _effective,
          onTap: () async {
            final d =
                await HrRequestFormUi.pickDate(context, initial: _effective);
            if (d != null) setState(() => _effective = d);
          },
        ),
        SizedBox(height: 14.h),
        HrRequestFormUi.label('Loan Type *'),
        HrRequestFormUi.dropdown<String>(
          value: _loanType,
          hint: 'Select type',
          items: const [
            DropdownMenuItem(value: 'graduity', child: Text('Gratuity')),
            DropdownMenuItem(value: 'normal', child: Text('Normal')),
          ],
          onChanged: (v) => setState(() => _loanType = v ?? 'graduity'),
        ),
        SizedBox(height: 14.h),
        HrRequestFormUi.label('Loan Amount *'),
        TextFormField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: HrRequestFormUi.fieldDecoration('0.00'),
          validator: (v) {
            final n = double.tryParse(v?.trim() ?? '');
            if (n == null || n < 0) return 'Enter a valid amount';
            return null;
          },
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
