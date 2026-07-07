import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Comma / Enter adds tags — R3 required skills (Module 2 F.2).
class RecruitmentTagInputField extends StatefulWidget {
  const RecruitmentTagInputField({
    super.key,
    required this.tags,
    required this.onChanged,
    this.hint = 'Type and press comma or enter',
  });

  final List<String> tags;
  final ValueChanged<List<String>> onChanged;
  final String hint;

  @override
  State<RecruitmentTagInputField> createState() =>
      _RecruitmentTagInputFieldState();
}

class _RecruitmentTagInputFieldState extends State<RecruitmentTagInputField> {
  final _controller = TextEditingController();

  void _commit(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return;
    if (widget.tags.contains(t)) {
      _controller.clear();
      return;
    }
    widget.onChanged([...widget.tags, t]);
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            ...widget.tags.map(
              (t) => Chip(
                label: Text(t, style: TextStyle(fontSize: 12.sp)),
                onDeleted: () {
                  widget.onChanged(widget.tags.where((e) => e != t).toList());
                },
                deleteIconColor: HrModuleColors.mutedText,
                backgroundColor: HrModuleColors.surface,
                side: BorderSide(color: HrModuleColors.border),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: _controller,
          style: HrModuleTypography.body().copyWith(fontSize: 14.sp),
          decoration: InputDecoration(
            hintText: widget.hint,
            filled: true,
            fillColor: HrModuleColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.r),
            ),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'\n')),
          ],
          onSubmitted: _commit,
          onChanged: (v) {
            if (v.endsWith(',')) {
              _commit(v.substring(0, v.length - 1));
            }
          },
        ),
      ],
    );
  }
}
