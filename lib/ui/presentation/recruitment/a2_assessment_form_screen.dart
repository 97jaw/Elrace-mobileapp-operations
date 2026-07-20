import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/recruitment/providers/requisition_providers.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/recruitment/recruitment_gradient_scaffold.dart';
import 'package:el_race/core/widgets/recruitment/recruitment_star_rating.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// A2 — Assessment form (SRD §4.4).
class A2AssessmentFormScreen extends ConsumerStatefulWidget {
  const A2AssessmentFormScreen({
    super.key,
    required this.candidateId,
    this.existingAssessmentId,
  });

  final String candidateId;
  final String? existingAssessmentId;

  @override
  ConsumerState<A2AssessmentFormScreen> createState() =>
      _A2AssessmentFormScreenState();
}

class _A2AssessmentFormScreenState extends ConsumerState<A2AssessmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _round;
  DateTime _date = DateTime.now();
  int _tech = 3;
  int _prob = 3;
  int _comm = 3;
  int _cultural = 3;
  final _strengths = TextEditingController();
  final _concerns = TextEditingController();
  final _comments = TextEditingController();
  String _recommendation = 'Hire';

  static const _rounds = [
    'Phone Screening',
    'Technical',
    'HR',
    'Final',
    'Other',
  ];

  static const _recs = [
    'Strong Hire',
    'Hire',
    'No Hire',
    'Strong No Hire',
  ];

  @override
  void dispose() {
    _strengths.dispose();
    _concerns.dispose();
    _comments.dispose();
    super.dispose();
  }

  InputDecoration _dec(String h) => InputDecoration(
        hintText: h,
        filled: true,
        fillColor: HrModuleColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.tr),
        ),
      );

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: _date,
    );
    if (d != null) setState(() => _date = d);
  }

  void _submit({required bool draft}) {
    if (!_formKey.currentState!.validate()) return;
    if (_round == null) {
      Fluttertoast.showToast(msg: 'Select round');
      return;
    }
    // TODO(backend): POST assessment
    Fluttertoast.showToast(
      msg: draft ? 'Draft saved' : 'Assessment submitted',
    );
    ref.invalidate(recruitmentCandidateProvider(widget.candidateId));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return RecruitmentGradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: HrModuleColors.text,
        title: Text(
          widget.existingAssessmentId != null
              ? 'Edit assessment'
              : 'New assessment',
          style: HrModuleTypography.sectionHeading().copyWith(fontSize: 18.tsp),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(HrModuleLayout.screenPaddingH.tw),
          children: [
            Text('Round / stage *', style: HrModuleTypography.caption()),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _round,
              items: _rounds
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _round = v),
              decoration: _dec('Select'),
              validator: (v) => v == null ? 'Required' : null,
            ),
            SizedBox(height: HrModuleLayout.formFieldSpacingV.th),
            Text('Interview date *', style: HrModuleTypography.caption()),
            OutlinedButton(
              onPressed: _pickDate,
              child: Text(
                '${_date.day}/${_date.month}/${_date.year}',
              ),
            ),
            SizedBox(height: 16.th),
            Text(
              'Score the candidate',
              style: HrModuleTypography.sectionHeading().copyWith(fontSize: 14.tsp),
            ),
            RecruitmentStarInput(
              label: 'Technical knowledge *',
              value: _tech,
              onChanged: (n) => setState(() => _tech = n),
            ),
            RecruitmentStarInput(
              label: 'Problem solving *',
              value: _prob,
              onChanged: (n) => setState(() => _prob = n),
            ),
            RecruitmentStarInput(
              label: 'Communication *',
              value: _comm,
              onChanged: (n) => setState(() => _comm = n),
            ),
            RecruitmentStarInput(
              label: 'Cultural fit *',
              value: _cultural,
              onChanged: (n) => setState(() => _cultural = n),
            ),
            Text('Strengths', style: HrModuleTypography.caption()),
            TextFormField(
              controller: _strengths,
              maxLines: 3,
              maxLength: 1000,
              decoration: _dec('0–1000 characters'),
            ),
            Text('Concerns', style: HrModuleTypography.caption()),
            TextFormField(
              controller: _concerns,
              maxLines: 3,
              maxLength: 1000,
              decoration: _dec('0–1000 characters'),
            ),
            Text(
              'Recommendation *',
              style: HrModuleTypography.sectionHeading().copyWith(fontSize: 14.tsp),
            ),
            ..._recs.map(
              (r) => RadioListTile<String>(
                title: Text(r),
                value: r,
                groupValue: _recommendation,
                onChanged: (v) => setState(() => _recommendation = v!),
              ),
            ),
            Text('Overall comments', style: HrModuleTypography.caption()),
            TextFormField(
              controller: _comments,
              maxLines: 4,
              decoration: _dec('Optional'),
            ),
            SizedBox(height: 24.th),
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
                    child: const Text('Submit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
