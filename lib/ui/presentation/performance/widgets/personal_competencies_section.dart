import 'package:el_race/core/performance/models/performance_evaluation.dart';
import 'package:el_race/core/performance/performance_rating.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Personal competencies — card layout for employee and manager (read-only).
class PersonalCompetenciesSection extends StatelessWidget {
  const PersonalCompetenciesSection({
    super.key,
    required this.rows,
    this.title = 'Personal Competencies',
  });

  final List<PersonalCompetencyRow> rows;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: const Color(0xFFE8EEF5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.workspace_premium_outlined,
                size: 20.sp,
                color: HrModuleColors.primary,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                title,
                style: HrModuleTypography.sectionHeading().copyWith(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          'Criteria, weight, and qualitative rating',
          style: HrModuleTypography.caption().copyWith(fontSize: 12.sp),
        ),
        SizedBox(height: 14.h),
        for (final r in rows) ...[
          _CompetencyReadOnlyCard(row: r),
          SizedBox(height: 10.h),
        ],
      ],
    );
  }
}

class _CompetencyReadOnlyCard extends StatelessWidget {
  const _CompetencyReadOnlyCard({required this.row});

  final PersonalCompetencyRow row;

  @override
  Widget build(BuildContext context) {
    return _CompetencyCardShell(
      index: row.index,
      descriptionEn: row.descriptionEn,
      descriptionAr: row.descriptionAr,
      maxScore: row.maxScore,
      ratio: row.maxScore > 0
          ? (row.userScore / row.maxScore).clamp(0.0, 1.0)
          : 0.0,
      scoreRow: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Text(
              '${row.userScore} / ${row.maxScore}',
              style: HrModuleTypography.sectionHeading().copyWith(
                    fontSize: 14.sp,
                    color: HrModuleColors.success,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              row.scorePercentLabel,
              style: HrModuleTypography.caption().copyWith(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
      footer: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          row.ratingValueEnAr,
          style: HrModuleTypography.body().copyWith(
                fontSize: 12.sp,
                height: 1.35,
              ),
        ),
      ),
    );
  }
}

/// Same visual system; only the numeric score fields are editable — rest derived.
class PersonalCompetenciesScoreEditor extends StatefulWidget {
  const PersonalCompetenciesScoreEditor({
    super.key,
    required this.templateRows,
    this.title = 'Personal Competencies',
    this.onScoresChanged,
  });

  final List<PersonalCompetencyRow> templateRows;
  final String title;
  final void Function(List<int> scores)? onScoresChanged;

  @override
  State<PersonalCompetenciesScoreEditor> createState() =>
      _PersonalCompetenciesScoreEditorState();
}

class _PersonalCompetenciesScoreEditorState
    extends State<PersonalCompetenciesScoreEditor> {
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = widget.templateRows
        .map((r) => TextEditingController(text: '${r.userScore}'))
        .toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onScoresChanged?.call(_parsedScores());
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  List<int> _parsedScores() {
    final out = <int>[];
    for (var i = 0; i < _controllers.length; i++) {
      final raw = int.tryParse(_controllers[i].text.trim());
      final max = widget.templateRows[i].maxScore;
      if (raw == null) {
        out.add(0);
      } else {
        out.add(raw.clamp(0, max));
      }
    }
    return out;
  }

  void _notify() {
    widget.onScoresChanged?.call(_parsedScores());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4D6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.edit_note_rounded,
                size: 20.sp,
                color: HrModuleColors.warning,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                widget.title,
                style: HrModuleTypography.sectionHeading().copyWith(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          'Enter scores only — rating updates from your input',
          style: HrModuleTypography.caption().copyWith(fontSize: 12.sp),
        ),
        SizedBox(height: 14.h),
        for (var i = 0; i < widget.templateRows.length; i++) ...[
          _CompetencyEditCard(
            row: widget.templateRows[i],
            controller: _controllers[i],
            onChanged: _notify,
          ),
          SizedBox(height: 10.h),
        ],
      ],
    );
  }
}

class _CompetencyEditCard extends StatelessWidget {
  const _CompetencyEditCard({
    required this.row,
    required this.controller,
    required this.onChanged,
  });

  final PersonalCompetencyRow row;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final score = int.tryParse(controller.text.trim());
    final safe = score == null
        ? 0
        : score.clamp(0, row.maxScore);
    final ratio =
        row.maxScore > 0 ? (safe / row.maxScore).clamp(0.0, 1.0) : 0.0;

    return _CompetencyCardShell(
      index: row.index,
      descriptionEn: row.descriptionEn,
      descriptionAr: row.descriptionAr,
      maxScore: row.maxScore,
      ratio: ratio,
      scoreRow: Row(
        children: [
          SizedBox(
            width: 56.w,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: HrModuleTypography.sectionHeading().copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
                filled: true,
                fillColor: HrModuleColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: HrModuleColors.primary),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: HrModuleColors.border),
                ),
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            '/ ${row.maxScore}',
            style: HrModuleTypography.body().copyWith(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              safe > 0 ? '$safe/${row.maxScore}%' : '0/${row.maxScore}%',
              style: HrModuleTypography.caption().copyWith(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
      footer: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          ratingEnArForScore(safe, row.maxScore),
          style: HrModuleTypography.body().copyWith(
                fontSize: 12.sp,
                height: 1.35,
              ),
        ),
      ),
    );
  }
}

class _CompetencyCardShell extends StatelessWidget {
  const _CompetencyCardShell({
    required this.index,
    required this.descriptionEn,
    required this.descriptionAr,
    required this.maxScore,
    required this.ratio,
    required this.scoreRow,
    required this.footer,
  });

  final int index;
  final String descriptionEn;
  final String descriptionAr;
  final int maxScore;
  final double ratio;
  final Widget scoreRow;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HrModuleColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4.w,
                color: HrModuleColors.primary,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 30.w,
                            height: 30.w,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8EEF5),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$index',
                              style: HrModuleTypography.sectionHeading()
                                  .copyWith(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  descriptionEn,
                                  style: HrModuleTypography.body().copyWith(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w600,
                                        height: 1.3,
                                      ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  descriptionAr,
                                  textAlign: TextAlign.right,
                                  textDirection: TextDirection.rtl,
                                  style: HrModuleTypography.caption()
                                      .copyWith(
                                        fontSize: 11.sp,
                                        height: 1.35,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 7.h,
                          backgroundColor: const Color(0xFFE5E7EB),
                          color: HrModuleColors.primary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Weight: $maxScore pts',
                        style: HrModuleTypography.caption().copyWith(
                              fontSize: 10.sp,
                            ),
                      ),
                      SizedBox(height: 10.h),
                      scoreRow,
                      SizedBox(height: 10.h),
                      footer,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
