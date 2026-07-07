import 'package:el_race/core/recruitment/models/requisition.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/recruitment/recruitment_gradient_scaffold.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// Employee referral for an open requisition — name, phone, relation, optional CV.
///
/// // TODO(backend): POST referral + multipart CV to recruitment API.
class RecruitmentReferralScreen extends StatefulWidget {
  const RecruitmentReferralScreen({super.key, required this.requisition});

  final Requisition requisition;

  @override
  State<RecruitmentReferralScreen> createState() =>
      _RecruitmentReferralScreenState();
}

class _RecruitmentReferralScreenState extends State<RecruitmentReferralScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _relation;
  String? _cvFileName;

  static const _relations = [
    'Friend',
    'Former colleague',
    'Family member',
    'Professional contact',
    'Other',
  ];

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: HrModuleColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.r),
      ),
    );
  }

  Future<void> _pickCv() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.single;
    if (f.name.isEmpty) return;
    setState(() => _cvFileName = f.name);
  }

  void _clearCv() => setState(() => _cvFileName = null);

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    // TODO(backend): Upload referral for requisition id + optional file path.
    Fluttertoast.showToast(
      msg: 'Referral sent for ${widget.requisition.jobTitle}',
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.requisition;
    return RecruitmentGradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: HrModuleColors.text,
        title: Text(
          'Refer a candidate',
          style: HrModuleTypography.sectionHeading().copyWith(
                fontSize: 18.sp,
                color: HrModuleColors.text,
              ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(HrModuleLayout.screenPaddingH.w),
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.r),
              decoration: BoxDecoration(
                color: HrModuleColors.surface,
                borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.r),
                boxShadow: HrModuleColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.jobTitle,
                    style: HrModuleTypography.cardTitle().copyWith(fontSize: 16.sp),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${r.referenceNumber} · ${r.department} · ${r.location}',
                    style: HrModuleTypography.caption().copyWith(fontSize: 12.sp),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Your referral',
              style: HrModuleTypography.sectionHeading().copyWith(fontSize: 15.sp),
            ),
            SizedBox(height: 4.h),
            Text(
              'We will contact them using the details below. CV is optional if they already have a profile.',
              style: HrModuleTypography.body().copyWith(fontSize: 13.sp),
            ),
            SizedBox(height: 16.h),
            Text(
              'Full name *',
              style: HrModuleTypography.caption().copyWith(fontSize: 12.sp),
            ),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              maxLength: 120,
              decoration: _decoration('Candidate full name'),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.length < 2) return 'Enter a valid name';
                return null;
              },
            ),
            Text(
              'Phone *',
              style: HrModuleTypography.caption().copyWith(fontSize: 12.sp),
            ),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 32,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d+\s\-()]+')),
              ],
              decoration: _decoration('Mobile number'),
              validator: (v) {
                final digits = RegExp(r'\d').allMatches(v ?? '').length;
                if (digits < 8) return 'Enter a valid phone number';
                return null;
              },
            ),
            Text(
              'Relation to you *',
              style: HrModuleTypography.caption().copyWith(fontSize: 12.sp),
            ),
            DropdownButtonFormField<String>(
              // `value` is correct for a controlled selection; `initialValue` does not track updates.
              // ignore: deprecated_member_use
              value: _relation,
              items: _relations
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _relation = v),
              validator: (v) => v == null ? 'Required' : null,
              decoration: _decoration('How do you know them?'),
            ),
            SizedBox(height: HrModuleLayout.formFieldSpacingV.h),
            Text(
              'CV (optional)',
              style: HrModuleTypography.caption().copyWith(fontSize: 12.sp),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickCv,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(
                      _cvFileName ?? 'PDF, DOC, DOCX',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (_cvFileName != null) ...[
                  SizedBox(width: 8.w),
                  IconButton(
                    onPressed: _clearCv,
                    icon: const Icon(Icons.clear),
                    tooltip: 'Remove file',
                  ),
                ],
              ],
            ),
            SizedBox(height: 28.h),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: HrModuleColors.success,
                foregroundColor: Colors.white,
                minimumSize: Size.fromHeight(HrModuleLayout.buttonHeight.h),
              ),
              child: Text('Submit referral', style: TextStyle(fontSize: 14.sp)),
            ),
          ],
        ),
      ),
    );
  }
}
