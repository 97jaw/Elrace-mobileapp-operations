import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_models.dart';
import 'package:el_race/core/widgets/timesheet/tm_faded_network_image.dart';
import 'package:el_race/core/widgets/timesheet/tm_marquee_text.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class TmProjectCard extends StatelessWidget {
  const TmProjectCard({
    super.key,
    required this.name,
    required this.taskCountLabel,
    this.clientImageUrl,
    this.woRefNo,
    this.lastUpdate,
    this.onTap,
  });

  final String name;
  final String taskCountLabel;
  final String? clientImageUrl;
  final String? woRefNo;
  final DateTime? lastUpdate;
  final VoidCallback? onTap;

  static const double _logoWidth = 86;
  static const double _logoHeight = 92;
  static const double _logoGap = 10;

  factory TmProjectCard.fromProject(
    Project project, {
    VoidCallback? onTap,
    String? statusLabel,
  }) {
    return TmProjectCard(
      name: project.name,
      taskCountLabel: statusLabel ?? _statusLabel(project.status),
      clientImageUrl: project.clientImageUrl,
      woRefNo: project.woRefNo,
      lastUpdate: project.lastUpdate,
      onTap: onTap,
    );
  }

  static String _statusLabel(String status) {
    final s = status.toLowerCase();
    if (s.contains('complete') || s.contains('done')) return 'Completed';
    return 'In progress';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = clientImageUrl?.trim() ?? '';
    final wo = woRefNo?.trim() ?? '';
    final updatedLabel = lastUpdate != null
        ? 'Updated ${DateFormat('dd MMM yyyy · HH:mm').format(lastUpdate!)}'
        : null;

    return InkWell(
      borderRadius: BorderRadius.circular(TimesheetModuleLayout.cardRadiusLg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(TimesheetModuleLayout.cardPadding),
        decoration: BoxDecoration(
          color: TimesheetModuleColors.surface,
          borderRadius:
              BorderRadius.circular(TimesheetModuleLayout.cardRadiusLg),
          boxShadow: TimesheetModuleShadows.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: _logoHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: _logoGap),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TmMarqueeText(
                            text: name,
                            height: wo.isEmpty ? 40 : 20,
                            style: TimesheetModuleTypography.cardTitle(),
                          ),
                          if (wo.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            _WoBadge(label: wo),
                          ],
                        ],
                      ),
                    ),
                  ),
                  TmFadedNetworkImage(
                    imageUrl: imageUrl,
                    width: _logoWidth,
                    height: _logoHeight,
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                right: _logoWidth + _logoGap,
                bottom: 4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _LightRedSeparator(),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (updatedLabel != null)
                        Expanded(
                          child: Text(
                            updatedLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TimesheetModuleTypography.caption().copyWith(
                              color: TimesheetModuleColors.mutedText,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      if (taskCountLabel.trim().isNotEmpty)
                        _StatusChip(label: taskCountLabel),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LightRedSeparator extends StatelessWidget {
  const _LightRedSeparator();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        color: TimesheetModuleColors.primary.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final completed = label.toLowerCase().contains('complete');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: completed
            ? TimesheetModuleColors.primaryTint
            : TimesheetModuleColors.navyTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TimesheetModuleTypography.caption().copyWith(
          color: completed
              ? TimesheetModuleColors.primary
              : TimesheetModuleColors.navy,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _WoBadge extends StatelessWidget {
  const _WoBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: TimesheetModuleColors.navy.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIcons.hash(),
            size: 11,
            color: TimesheetModuleColors.navy.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TimesheetModuleTypography.caption().copyWith(
                color: TimesheetModuleColors.navy.withValues(alpha: 0.85),
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
