import 'dart:convert';

import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/hr_management/widgets/hr_request_form_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';

class HrPromotionRequestScreen extends ConsumerStatefulWidget {
  const HrPromotionRequestScreen({super.key});

  static const draftKey = 'hr_draft_promotion_v1';

  @override
  ConsumerState<HrPromotionRequestScreen> createState() =>
      _HrPromotionRequestScreenState();
}

class _HrPromotionRequestScreenState
    extends ConsumerState<HrPromotionRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _effective;
  int? _jobId;
  int? _managerId;
  String? _currentManager;
  final _description = TextEditingController();
  List<Map<String, dynamic>> _jobs = const [];
  List<Map<String, dynamic>> _managers = const [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadDraft();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMeta());
  }

  Future<void> _loadMeta() async {
    final env =
        await ref.read(hrApiClientProvider).fetchRequestFormMeta(code: 'PROMOTION');
    if (!mounted || !env.success) return;
    final options = env.data?['options'];
    final readonly = env.data?['readonly'];
    setState(() {
      if (options is Map) {
        final jobs = options['jobs'];
        final managers = options['managers'];
        if (jobs is List) {
          _jobs = jobs
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        if (managers is List) {
          _managers = managers
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
      if (readonly is Map) {
        _currentManager = readonly['current_manager']?.toString();
      }
    });
  }

  void _loadDraft() {
    final raw =
        SharedPref().getPreferenceString(HrPromotionRequestScreen.draftKey);
    if (raw.isEmpty) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _jobId = m['jobId'] as int?;
      _managerId = m['managerId'] as int?;
      _description.text = m['description'] as String? ?? '';
      final d = m['effective'] as String?;
      if (d != null) _effective = DateTime.tryParse(d);
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    await SharedPref().setPreferencesString(
      HrPromotionRequestScreen.draftKey,
      jsonEncode({
        'jobId': _jobId,
        'managerId': _managerId,
        'description': _description.text,
        'effective': _effective?.toIso8601String(),
      }),
    );
    Fluttertoast.showToast(msg: 'Draft saved');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_jobId == null) {
      Fluttertoast.showToast(msg: 'Select new job position');
      return;
    }
    setState(() => _submitting = true);
    final ok = await HrRequestFormUi.submit(
      api: ref.read(hrApiClientProvider),
      code: 'PROMOTION',
      fields: {
        'new_job_id': _jobId,
        if (_managerId != null) 'new_pro_manager': _managerId,
        if (_effective != null)
          'effective_date': HrRequestFormUi.isoDate(_effective!),
      },
      description: _description.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      await SharedPref().removePreference(HrPromotionRequestScreen.draftKey);
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
      title: 'Promotion',
      formKey: _formKey,
      submitting: _submitting,
      onSaveDraft: _saveDraft,
      onSubmit: _submit,
      children: [
        if (_currentManager != null)
          HrRequestFormUi.readonlyRow('Current Manager', _currentManager!),
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
        HrRequestFormUi.label('New Job Position *'),
        HrRequestFormUi.dropdown<int>(
          value: _jobId,
          hint: 'Select position',
          items: _jobs
              .map((j) {
                final id = int.tryParse('${j['id']}');
                if (id == null) return null;
                return DropdownMenuItem<int>(
                  value: id,
                  child: Text('${j['name'] ?? ''}'),
                );
              })
              .whereType<DropdownMenuItem<int>>()
              .toList(),
          onChanged: (v) => setState(() => _jobId = v),
          validator: (v) => v == null ? 'Required' : null,
        ),
        SizedBox(height: 14.h),
        HrRequestFormUi.label('New Manager'),
        HrRequestFormUi.dropdown<int>(
          value: _managerId,
          hint: 'Select manager',
          items: _managers
              .map((m) {
                final id = int.tryParse('${m['id']}');
                if (id == null) return null;
                return DropdownMenuItem<int>(
                  value: id,
                  child: Text('${m['name'] ?? ''}'),
                );
              })
              .whereType<DropdownMenuItem<int>>()
              .toList(),
          onChanged: (v) => setState(() => _managerId = v),
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
