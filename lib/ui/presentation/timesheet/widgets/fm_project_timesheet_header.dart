import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/timesheet_defaults.dart';
import 'package:el_race/core/widgets/timesheet/tm_faded_network_image.dart';
import 'package:el_race/core/widgets/timesheet/tm_project_hero_title.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// PM-style hero cover — name centered on two lines when long.
class FmProjectHeroHeader extends StatelessWidget {
  const FmProjectHeroHeader({
    super.key,
    required this.projectName,
    this.clientImageUrl,
    this.rangeActive = false,
    this.onBack,
  });

  final String projectName;
  final String? clientImageUrl;
  final bool rangeActive;
  final VoidCallback? onBack;

  static const double _heroHeight = 188;

  @override
  Widget build(BuildContext context) {
    final imageUrl = clientImageUrl?.trim() ?? '';

    return ColoredBox(
      color: TimesheetModuleColors.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: _heroHeight,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              TmFadedHeroImage(
                imageUrl: imageUrl,
                height: _heroHeight,
                borderRadius: BorderRadius.zero,
              ),
              if (onBack != null)
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    onPressed: onBack,
                    icon: Icon(
                      PhosphorIcons.caretLeft(),
                      color: TimesheetModuleColors.surface,
                    ),
                  ),
                ),
              Positioned(
                left: TimesheetModuleLayout.cardPadding,
                right: TimesheetModuleLayout.cardPadding,
                bottom: TimesheetModuleLayout.cardPadding,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TmProjectHeroTitle(
                        text: projectName,
                        maxHeight: 56,
                        style: TimesheetModuleTypography.h1().copyWith(
                          color: TimesheetModuleColors.surface,
                        ),
                      ),
                    ),
                    if (rangeActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF3DDC84),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TmActionBadge extends StatelessWidget {
  const _TmActionBadge({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TimesheetModuleTypography.caption().copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Task label + date range picker (actions inside the picker row).
class FmProjectDatesContextBar extends StatelessWidget {
  const FmProjectDatesContextBar({
    super.key,
    this.taskLabel,
    this.taskId,
    this.rangeStart,
    this.rangeEnd,
    this.selectedDay,
    this.onPickRange,
    this.onClearDay,
  });

  final String? taskLabel;
  final String? taskId;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final DateTime? selectedDay;
  final VoidCallback? onPickRange;
  final VoidCallback? onClearDay;

  @override
  Widget build(BuildContext context) {
    final dateLabel = _dateLabel();
    final inDayMode = selectedDay != null;
    final taskName = taskLabel ?? TimesheetDefaults.maintenanceTaskName;

    return Container(
      width: double.infinity,
      color: TimesheetModuleColors.surface,
      padding: const EdgeInsets.fromLTRB(
        TimesheetModuleLayout.screenPaddingH,
        10,
        TimesheetModuleLayout.screenPaddingH,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: TimesheetModuleColors.navyTint,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'TASK',
                  style: TimesheetModuleTypography.caption().copyWith(
                    color: TimesheetModuleColors.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      taskName,
                      style: TimesheetModuleTypography.body().copyWith(
                        fontWeight: FontWeight.w700,
                        color: TimesheetModuleColors.text,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (taskId != null && taskId!.isNotEmpty)
                      Text(
                        '#$taskId',
                        style: TimesheetModuleTypography.caption().copyWith(
                          color: TimesheetModuleColors.mutedText,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Material(
            color: TimesheetModuleColors.bgGradientEnd,
            borderRadius:
                BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    PhosphorIcons.calendarBlank(),
                    size: 18,
                    color: inDayMode
                        ? TimesheetModuleColors.primary
                        : TimesheetModuleColors.navy,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      dateLabel,
                      style: (inDayMode
                              ? TimesheetModuleTypography.h2()
                              : TimesheetModuleTypography.body())
                          .copyWith(
                        color: inDayMode
                            ? TimesheetModuleColors.primary
                            : TimesheetModuleColors.text,
                        fontWeight: inDayMode
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (inDayMode && onClearDay != null)
                    _TmActionBadge(
                      label: 'Back to range',
                      background: TimesheetModuleColors.primaryTint,
                      foreground: TimesheetModuleColors.primary,
                      icon: PhosphorIcons.arrowLeft(),
                      onTap: onClearDay!,
                    )
                  else if (onPickRange != null)
                    _TmActionBadge(
                      label: 'Change range',
                      background: TimesheetModuleColors.navyTint,
                      foreground: TimesheetModuleColors.navy,
                      icon: PhosphorIcons.arrowsLeftRight(),
                      onTap: onPickRange!,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dateLabel() {
    if (selectedDay != null) {
      return DateFormat('EEE, dd MMM yyyy').format(selectedDay!);
    }
    if (rangeStart != null && rangeEnd != null) {
      final a = DateFormat('dd MMM yyyy').format(rangeStart!);
      final b = DateFormat('dd MMM yyyy').format(rangeEnd!);
      return '$a  →  $b';
    }
    return 'Select a date range';
  }
}

/// Timesheet / Site Report tabs under project dates header.
class FmProjectDatesTabBar extends StatelessWidget {
  const FmProjectDatesTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: TimesheetModuleColors.surface,
      child: TabBar(
        controller: controller,
        labelColor: TimesheetModuleColors.primary,
        unselectedLabelColor: TimesheetModuleColors.mutedText,
        indicatorColor: TimesheetModuleColors.primary,
        indicatorWeight: 3,
        labelStyle: TimesheetModuleTypography.body().copyWith(
          fontWeight: FontWeight.w800,
        ),
        tabs: const [
          Tab(text: 'Timesheet'),
          Tab(text: 'Site Report'),
          Tab(text: 'Enroll'),
        ],
      ),
    );
  }
}
