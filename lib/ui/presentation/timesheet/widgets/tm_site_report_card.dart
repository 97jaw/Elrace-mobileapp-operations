import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/report_module/data/models/report_model.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_fast_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class TmSiteReportCard extends StatelessWidget {
  const TmSiteReportCard({
    super.key,
    required this.report,
    required this.onTap,
    this.previewImageUrl,
  });

  final ReportModel report;
  final VoidCallback onTap;
  final String? previewImageUrl;

  @override
  Widget build(BuildContext context) {
    final imageUrl = previewImageUrl?.trim() ?? '';
    final updated = DateFormat('dd MMM yyyy · HH:mm').format(report.updatedAt);

    return Material(
      color: TimesheetModuleColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TimesheetModuleLayout.cardRadiusLg),
        side: const BorderSide(color: TimesheetModuleColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(TimesheetModuleLayout.cardPadding),
          child: Row(
            children: [
              _Thumb(imageUrl: imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TimesheetModuleTypography.cardTitle(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      updated,
                      style: TimesheetModuleTypography.caption(),
                    ),
                    if (report.reportType != null &&
                        report.reportType!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: TimesheetModuleColors.primaryTint,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          report.reportType!,
                          style: TimesheetModuleTypography.caption().copyWith(
                            color: TimesheetModuleColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                PhosphorIcons.caretRight(),
                color: TimesheetModuleColors.mutedText,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: TimesheetModuleColors.navyTint,
        borderRadius:
            BorderRadius.circular(TimesheetModuleLayout.cardRadiusSm),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isNotEmpty
          ? TmFastNetworkImage(
              url: imageUrl,
              fit: BoxFit.cover,
              memCacheWidth: 120,
            )
          : _icon(),
    );
  }

  Widget _icon() {
    return Center(
      child: Icon(
        PhosphorIcons.images(),
        color: TimesheetModuleColors.navy,
        size: 26,
      ),
    );
  }
}
