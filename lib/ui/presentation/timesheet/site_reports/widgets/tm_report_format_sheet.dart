import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/report_module/data/report_pdf_templates.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

enum TmReportFormatMode { generate, view }

class TmReportFormatChoice {
  const TmReportFormatChoice({
    required this.templateId,
    this.openSavedPdf = false,
  });

  final String templateId;
  final bool openSavedPdf;
}

/// Slide-up picker for PDF layout (template1–4).
class TmReportFormatSheet {
  TmReportFormatSheet._();

  static Future<TmReportFormatChoice?> show(
    BuildContext context, {
    required int photoCount,
    String initialTemplateId = ReportPdfTemplates.defaultId,
    TmReportFormatMode mode = TmReportFormatMode.generate,
    bool hasSavedPdf = false,
  }) {
    return showModalBottomSheet<TmReportFormatChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TmReportFormatSheetBody(
        photoCount: photoCount,
        initialTemplateId: initialTemplateId,
        mode: mode,
        hasSavedPdf: hasSavedPdf,
      ),
    );
  }
}

class _TmReportFormatSheetBody extends StatefulWidget {
  const _TmReportFormatSheetBody({
    required this.photoCount,
    required this.initialTemplateId,
    required this.mode,
    required this.hasSavedPdf,
  });

  final int photoCount;
  final String initialTemplateId;
  final TmReportFormatMode mode;
  final bool hasSavedPdf;

  @override
  State<_TmReportFormatSheetBody> createState() =>
      _TmReportFormatSheetBodyState();
}

class _TmReportFormatSheetBodyState extends State<_TmReportFormatSheetBody> {
  late String _selected = widget.initialTemplateId;

  @override
  Widget build(BuildContext context) {
    final isView = widget.mode == TmReportFormatMode.view;

    return Container(
      decoration: const BoxDecoration(
        color: TimesheetModuleColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: TimesheetModuleLayout.screenPaddingH,
        right: TimesheetModuleLayout.screenPaddingH,
        top: 12,
        bottom: MediaQuery.paddingOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: TimesheetModuleColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  isView ? 'View report format' : 'Type of report',
                  style: TimesheetModuleTypography.h2(),
                ),
              ),
              Icon(PhosphorIcons.images(),
                  color: TimesheetModuleColors.mutedText, size: 18),
              const SizedBox(width: 4),
              Text(
                '${widget.photoCount}',
                style: TimesheetModuleTypography.caption().copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (isView) ...[
            const SizedBox(height: 6),
            Text(
              'Default format is pre-selected. Preview any layout or open the saved PDF.',
              style: TimesheetModuleTypography.caption(),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ReportPdfTemplates.options.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final option = ReportPdfTemplates.options[index];
                final selected = _selected == option.id;
                return GestureDetector(
                  onTap: () => setState(() => _selected = option.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: option.isTall ? 72 : 96,
                    height: option.isTall ? 96 : 72,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: TimesheetModuleColors.bgGradientEnd,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: selected
                            ? TimesheetModuleColors.navy
                            : TimesheetModuleColors.divider,
                        width: selected ? 2 : 1,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.asset(
                        option.asset,
                        fit: BoxFit.fill,
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(
                            PhosphorIcons.layout(),
                            color: TimesheetModuleColors.mutedText,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          if (isView && widget.hasSavedPdf) ...[
            TmSecondaryButton(
              label: 'Open saved PDF',
              icon: PhosphorIcons.cloud(),
              onPressed: () => Navigator.of(context).pop(
                TmReportFormatChoice(
                  templateId: _selected,
                  openSavedPdf: true,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          TmPrimaryButton(
            label: isView ? 'Preview this format' : 'Generate report',
            icon: PhosphorIcons.filePdf(),
            onPressed: () => Navigator.of(context).pop(
              TmReportFormatChoice(templateId: _selected),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TimesheetModuleTypography.body().copyWith(
                color: TimesheetModuleColors.mutedText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
