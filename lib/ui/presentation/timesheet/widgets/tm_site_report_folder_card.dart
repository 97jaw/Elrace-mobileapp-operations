import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/report_module/data/models/folder_model.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_fast_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Dark gradient folder tile for Site Management site reports list.
class TmSiteReportFolderCard extends StatelessWidget {
  const TmSiteReportFolderCard({
    super.key,
    required this.folder,
    required this.onTap,
  });

  final FolderModel folder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final updated = DateFormat('dd MMM yyyy').format(folder.updatedAt);
    final count = folder.reportCount;

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: double.infinity,
        child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(TimesheetModuleLayout.cardRadiusLg),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                TimesheetModuleColors.navy,
                Color(0xFF284D7D),
                TimesheetModuleColors.primaryGradientEnd,
              ],
            ),
            borderRadius:
                BorderRadius.circular(TimesheetModuleLayout.cardRadiusLg),
            boxShadow: TimesheetModuleShadows.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(TimesheetModuleLayout.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      PhosphorIcons.folderOpen(),
                      color: TimesheetModuleColors.surface,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            folder.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TimesheetModuleTypography.cardTitle()
                                .copyWith(color: TimesheetModuleColors.surface),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Updated $updated',
                            style: TimesheetModuleTypography.caption().copyWith(
                              color: TimesheetModuleColors.surface
                                  .withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: TimesheetModuleColors.surface
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count',
                        style: TimesheetModuleTypography.caption().copyWith(
                          color: TimesheetModuleColors.surface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      PhosphorIcons.caretRight(),
                      color: TimesheetModuleColors.surface.withValues(
                        alpha: 0.85,
                      ),
                      size: 20,
                    ),
                  ],
                ),
                if (folder.latestItemImages.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: folder.latestItemImages.length.clamp(0, 6),
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        return TmFastNetworkImage(
                          url: folder.latestItemImages[index],
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          memCacheWidth: 120,
                          borderRadius: BorderRadius.circular(8),
                        );
                      },
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    count == 0
                        ? 'No reports yet — tap to add photos'
                        : '$count report${count == 1 ? '' : 's'} inside',
                    style: TimesheetModuleTypography.caption().copyWith(
                      color: TimesheetModuleColors.surface.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      width: 44,
      height: 44,
      color: TimesheetModuleColors.surface.withValues(alpha: 0.15),
      child: Icon(
        PhosphorIcons.image(),
        color: TimesheetModuleColors.surface.withValues(alpha: 0.7),
        size: 20,
      ),
    );
  }
}
