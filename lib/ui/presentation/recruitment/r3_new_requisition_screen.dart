import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/recruitment/recruitment_salary_visibility.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/core/widgets/recruitment/recruitment_gradient_scaffold.dart';
import 'package:el_race/core/widgets/recruitment/recruitment_tag_input_field.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// R3 — New requisition (SRD §3.3).
class R3NewRequisitionScreen extends ConsumerStatefulWidget {
  const R3NewRequisitionScreen({super.key});

  @override
  ConsumerState<R3NewRequisitionScreen> createState() =>
      _R3NewRequisitionScreenState();
}

class _R3NewRequisitionScreenState extends ConsumerState<R3NewRequisitionScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _jobTitle;
  String? _department;
  final _vacancies = TextEditingController(text: '1');
  String? _location;
  String? _employmentType;
  String? _experienceLevel;
  final _salaryMin = TextEditingController();
  final _salaryMax = TextEditingController();
  DateTime? _requiredBy;
  final _description = TextEditingController();
  final _responsibilities = TextEditingController();
  List<String> _skills = [];
  final _justification = TextEditingController();
  String? _replacement;
  String? _attachmentName;

  static const _jobs = [
    'Senior Flutter Engineer',
    'Product Designer',
    'DevOps Engineer',
    'HR Business Partner',
    'Other',
  ];
  static const _depts = [
    'Engineering',
    'Product',
    'Human Resources',
    'Marketing',
    'Finance',
  ];
  static const _locs = ['Dubai', 'Abu Dhabi', 'Sharjah', 'Riyadh'];
  static const _empTypes = [
    'Full-time',
    'Part-time',
    'Contract',
    'Internship',
  ];
  static const _exp = ['Junior', 'Mid', 'Senior', 'Lead', 'Manager'];
  static const _repl = ['— None —', 'EMP-1001 Jane', 'EMP-1002 John'];

  String? _loginName() {
    final d = SharedPref.getLoginData().result?.data;
    return d?.name ?? d?.emp_name ?? 'You';
  }

  InputDecoration _dec(String h) => InputDecoration(
        hintText: h,
        filled: true,
        fillColor: HrModuleColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.tr),
        ),
      );

  Future<void> _pickFile() async {
    final r = await FilePicker.pickFiles();
    if (r != null && r.files.isNotEmpty) {
      setState(() => _attachmentName = r.files.single.name);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
      initialDate: _requiredBy ?? DateTime.now(),
    );
    if (d != null) setState(() => _requiredBy = d);
  }

  void _submit({required bool draft}) {
    if (!draft && !_formKey.currentState!.validate()) return;
    final view = ref.read(hrEffectiveViewProvider);
    if (!draft && _jobTitle == null) {
      Fluttertoast.showToast(msg: 'Select job title');
      return;
    }
    if (!draft && _department == null) {
      Fluttertoast.showToast(msg: 'Select department');
      return;
    }
    if (!draft) {
      final v = int.tryParse(_vacancies.text.trim());
      if (v == null || v < 1 || v > 50) {
        Fluttertoast.showToast(msg: 'Vacancies 1–50');
        return;
      }
      final desc = _description.text.trim();
      if (desc.length < 50) {
        Fluttertoast.showToast(msg: 'Job description min 50 characters');
        return;
      }
      final just = _justification.text.trim();
      if (just.isEmpty) {
        Fluttertoast.showToast(msg: 'Justification required');
        return;
      }
      final smin = int.tryParse(_salaryMin.text.trim());
      final smax = int.tryParse(_salaryMax.text.trim());
      if (recruitmentShowsRequisitionSalary(
            view: view,
            raisedBy: _loginName()!,
            currentUserDisplayName: _loginName(),
          ) &&
          smin != null &&
          smax != null &&
          smax < smin) {
        Fluttertoast.showToast(msg: 'Salary max must be ≥ min');
        return;
      }
    }
    // TODO(backend): POST requisition
    final refNo =
        'REQ/2026/${(1000 + DateTime.now().millisecondsSinceEpoch % 9000)}';
    Fluttertoast.showToast(
      msg: draft ? 'Draft saved' : 'Requisition submitted — Ref: $refNo',
    );
    if (!draft) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _vacancies.dispose();
    _salaryMin.dispose();
    _salaryMax.dispose();
    _description.dispose();
    _responsibilities.dispose();
    _justification.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(hrEffectiveViewProvider);
    final showSalary = recruitmentShowsRequisitionSalary(
      view: view,
      raisedBy: _loginName()!,
      currentUserDisplayName: _loginName(),
    );

    return RecruitmentGradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: HrModuleColors.text,
        title: Text(
          'New requisition',
          style: HrModuleTypography.sectionHeading().copyWith(fontSize: 18.tsp),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(HrModuleLayout.screenPaddingH.tw),
          children: [
            _section('POSITION'),
            Text('Job title *', style: HrModuleTypography.caption()),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _jobTitle,
              items: _jobs
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _jobTitle = v),
              decoration: _dec('Search or select'),
              validator: (v) => v == null ? 'Required' : null,
            ),
            SizedBox(height: HrModuleLayout.formFieldSpacingV.th),
            Text('Department *', style: HrModuleTypography.caption()),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _department,
              items: _depts
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _department = v),
              decoration: _dec('Select'),
              validator: (v) => v == null ? 'Required' : null,
            ),
            SizedBox(height: HrModuleLayout.formFieldSpacingV.th),
            Text('Location *', style: HrModuleTypography.caption()),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _location,
              items: _locs
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _location = v),
              decoration: _dec('Select'),
              validator: (v) => v == null ? 'Required' : null,
            ),
            SizedBox(height: HrModuleLayout.formFieldSpacingV.th),
            Text('Vacancies *', style: HrModuleTypography.caption()),
            TextFormField(
              controller: _vacancies,
              keyboardType: TextInputType.number,
              decoration: _dec('1–50'),
            ),
            SizedBox(height: HrModuleLayout.formFieldSpacingV.th),
            Text('Employment type *', style: HrModuleTypography.caption()),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _employmentType,
              items: _empTypes
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _employmentType = v),
              decoration: _dec('Select'),
              validator: (v) => v == null ? 'Required' : null,
            ),
            SizedBox(height: HrModuleLayout.formFieldSpacingV.th),
            Text('Experience level', style: HrModuleTypography.caption()),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _experienceLevel,
              items: _exp
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _experienceLevel = v),
              decoration: _dec('Optional'),
            ),
            if (showSalary) ...[
              SizedBox(height: 16.th),
              _section('COMPENSATION'),
              Text('Salary min (AED)', style: HrModuleTypography.caption()),
              TextFormField(
                controller: _salaryMin,
                keyboardType: TextInputType.number,
                decoration: _dec('Optional'),
              ),
              Text('Salary max (AED)', style: HrModuleTypography.caption()),
              TextFormField(
                controller: _salaryMax,
                keyboardType: TextInputType.number,
                decoration: _dec('Optional'),
              ),
            ],
            SizedBox(height: HrModuleLayout.formFieldSpacingV.th),
            Text('Required by', style: HrModuleTypography.caption()),
            OutlinedButton(
              onPressed: _pickDate,
              child: Text(
                _requiredBy == null
                    ? 'Pick date'
                    : '${_requiredBy!.day}/${_requiredBy!.month}/${_requiredBy!.year}',
              ),
            ),
            SizedBox(height: 16.th),
            _section('POSITION DESCRIPTION'),
            Text('Job description *', style: HrModuleTypography.caption()),
            TextFormField(
              controller: _description,
              minLines: 4,
              maxLines: 8,
              decoration: _dec('Min 50 characters'),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.length < 50) return 'At least 50 characters';
                return null;
              },
            ),
            Text('Key responsibilities', style: HrModuleTypography.caption()),
            TextFormField(
              controller: _responsibilities,
              minLines: 2,
              maxLines: 5,
              decoration: _dec('Optional — one bullet per line'),
            ),
            SizedBox(height: 8.th),
            Text('Required skills', style: HrModuleTypography.caption()),
            RecruitmentTagInputField(
              tags: _skills,
              onChanged: (t) => setState(() => _skills = t),
            ),
            SizedBox(height: 16.th),
            _section('JUSTIFICATION'),
            Text('Justification *', style: HrModuleTypography.caption()),
            TextFormField(
              controller: _justification,
              minLines: 3,
              maxLines: 6,
              decoration: _dec('Why is this role needed?'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            Text('Replacement for', style: HrModuleTypography.caption()),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _replacement,
              items: _repl
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _replacement = v),
              decoration: _dec('Optional'),
            ),
            SizedBox(height: HrModuleLayout.formFieldSpacingV.th),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.attach_file),
              label: Text(_attachmentName ?? 'Attachment (optional)'),
            ),
            SizedBox(height: 28.th),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _submit(draft: true),
                    child: const Text('Save draft'),
                  ),
                ),
                SizedBox(width: 12.tw),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _submit(draft: false),
                    style: FilledButton.styleFrom(
                      backgroundColor: HrModuleColors.primary,
                    ),
                    child: const Text('Submit request'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.th, top: 4.th),
      child: Text(
        title,
        style: HrModuleTypography.sectionHeading().copyWith(fontSize: 13.tsp),
      ),
    );
  }
}
