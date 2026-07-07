import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/report_module/data/models/report_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class TmSiteReportRow extends StatelessWidget {
  const TmSiteReportRow({
    super.key,
    required this.report,
    required this.onGallery,
    required this.onPdf,
    this.onMore,
    this.pdfCount,
    this.busy = false,
  });

  final ReportModel report;
  final VoidCallback onGallery;
  final VoidCallback onPdf;
  final VoidCallback? onMore;
  final int? pdfCount;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final updated = DateFormat('dd MMM yyyy · HH:mm').format(report.updatedAt);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: TimesheetModuleColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(TimesheetModuleLayout.cardRadiusLg),
        border: Border.all(
          color: TimesheetModuleColors.divider.withValues(alpha: 0.65),
        ),
        boxShadow: [
          BoxShadow(
            color: TimesheetModuleColors.navy.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(TimesheetModuleLayout.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: TimesheetModuleColors.primaryTint.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'ID ${report.id}',
                  style: TimesheetModuleTypography.caption().copyWith(
                    color: TimesheetModuleColors.primary,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const Spacer(),
              if (onMore != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: busy ? null : onMore,
                  icon: Icon(
                    PhosphorIcons.dotsThreeVertical(),
                    color: TimesheetModuleColors.mutedText,
                    size: 20,
                  ),
                ),
              if (!report.hasGeneratedPdf)
                Tooltip(
                  message: 'PDF not generated yet',
                  child: Icon(
                    PhosphorIcons.warningCircle(),
                    color: const Color(0xFFE6A700),
                    size: 22,
                  ),
                )
              else
                Icon(
                  PhosphorIcons.checkCircle(),
                  color: const Color(0xFF3DDC84),
                  size: 20,
                ),
              if (busy) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: TimesheetModuleColors.primary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            report.name,
            style: TimesheetModuleTypography.cardTitle(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(updated, style: TimesheetModuleTypography.caption()),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionChip(
                  label: 'Gallery',
                  icon: PhosphorIcons.images(),
                  onTap: busy ? null : onGallery,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionChip(
                  label: pdfCount != null ? 'PDF ($pdfCount)' : 'View PDF',
                  icon: PhosphorIcons.filePdf(),
                  primary: true,
                  onTap: busy ? null : onPdf,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final bg = primary
        ? TimesheetModuleColors.primaryTint.withValues(alpha: 0.45)
        : TimesheetModuleColors.navyTint.withValues(alpha: 0.35);
    final fg =
        primary ? TimesheetModuleColors.primary : TimesheetModuleColors.navy;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(TimesheetModuleLayout.cardRadiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TimesheetModuleLayout.cardRadiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TimesheetModuleTypography.caption().copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
