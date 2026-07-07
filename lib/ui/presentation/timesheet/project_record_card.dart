import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_models.dart';
import 'package:el_race/core/widgets/timesheet/tm_faded_network_image.dart';
import 'package:el_race/core/widgets/timesheet/tm_progress_bar.dart';
import 'package:el_race/core/widgets/timesheet/tm_project_hero_title.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_project_location_section.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ProjectRecordCard extends StatelessWidget {
  const ProjectRecordCard({
    super.key,
    required this.project,
    this.viewportHeight,
  });

  final Project project;

  /// When set (PM overview), hero + map fill the tab height with no trailing gap.
  final double? viewportHeight;

  @override
  Widget build(BuildContext context) {
    if (viewportHeight != null) {
      return SizedBox(
        height: viewportHeight,
        width: double.infinity,
        child: _PmOverviewLayout(
          project: project,
          height: viewportHeight!,
        ),
      );
    }
    return _CardShell(
      child: _ScrollableBody(project: project),
    );
  }
}

class _PmOverviewLayout extends StatelessWidget {
  const _PmOverviewLayout({
    required this.project,
    required this.height,
  });

  final Project project;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clientImage = project.clientImageUrl.trim().isNotEmpty
        ? project.clientImageUrl
        : project.heroImageUrl;
    final heroHeight = (height * 0.36).clamp(168.0, 220.0);
    final progress = project.progressPct.clamp(0, 100);

    return ColoredBox(
      color: TimesheetModuleColors.bgGradientEnd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: heroHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                TmFadedHeroImage(
                  imageUrl: clientImage,
                  height: heroHeight,
                  borderRadius: BorderRadius.zero,
                ),
                Positioned(
                  left: TimesheetModuleLayout.cardPadding,
                  right: TimesheetModuleLayout.cardPadding,
                  bottom: TimesheetModuleLayout.cardPadding,
                  child: TmProjectHeroTitle(
                    text: project.name,
                    maxHeight: 56,
                    style: TimesheetModuleTypography.h1().copyWith(
                      color: TimesheetModuleColors.surface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: TimesheetModuleColors.surface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(TimesheetModuleLayout.cardRadiusLg),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TimesheetModuleLayout.cardPadding,
                      TimesheetModuleLayout.cardPadding,
                      TimesheetModuleLayout.cardPadding,
                      10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DetailsGrid(project: project),
                        const SizedBox(height: 12),
                        TmProgressBar(value: progress / 100),
                        const SizedBox(height: 6),
                        Text(
                          '${progress.toStringAsFixed(progress % 1 == 0 ? 0 : 1)}% complete',
                          style: TimesheetModuleTypography.caption(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        TimesheetModuleLayout.cardPadding,
                        0,
                        TimesheetModuleLayout.cardPadding,
                        TimesheetModuleLayout.cardPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Site location',
                            style: TimesheetModuleTypography.caption().copyWith(
                              fontWeight: FontWeight.w700,
                              color: TimesheetModuleColors.mutedText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: TmProjectLocationSection(
                              project: project,
                              expand: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TimesheetModuleColors.surface,
        borderRadius: BorderRadius.circular(TimesheetModuleLayout.cardRadiusLg),
        boxShadow: TimesheetModuleShadows.cardShadow,
      ),
      child: child,
    );
  }
}

class _ScrollableBody extends StatelessWidget {
  const _ScrollableBody({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final clientImage = project.clientImageUrl.trim().isNotEmpty
        ? project.clientImageUrl
        : project.heroImageUrl;
    final progress = project.progressPct.clamp(0, 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            TmFadedHeroImage(imageUrl: clientImage, height: 150),
            Positioned(
              left: TimesheetModuleLayout.cardPadding,
              right: TimesheetModuleLayout.cardPadding,
              bottom: TimesheetModuleLayout.cardPadding,
              child: TmProjectHeroTitle(
                text: project.name,
                style: TimesheetModuleTypography.h1().copyWith(
                  color: TimesheetModuleColors.surface,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(TimesheetModuleLayout.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DetailsGrid(project: project),
              const SizedBox(height: TimesheetModuleLayout.cardSpacing),
              TmProgressBar(value: progress / 100),
              const SizedBox(height: 8),
              Text(
                '${progress.toStringAsFixed(progress % 1 == 0 ? 0 : 1)}% complete',
                style: TimesheetModuleTypography.caption(),
              ),
              const SizedBox(height: TimesheetModuleLayout.sectionGap),
              Text(
                'Site location',
                style: TimesheetModuleTypography.body().copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TmProjectLocationSection(project: project),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailsGrid extends StatelessWidget {
  const _DetailsGrid({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _IconDetailTile(
              icon: PhosphorIcons.hash(),
              label: 'Work order',
              value: project.woRefNo.trim().isNotEmpty
                  ? project.woRefNo
                  : '—',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _IconDetailTile(
              icon: PhosphorIcons.calendarBlank(),
              label: 'Start',
              value: _date(project.start),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _IconDetailTile(
              icon: PhosphorIcons.calendarCheck(),
              label: 'End',
              value: _date(project.end),
            ),
          ),
        ],
      ),
    );
  }

  String _date(DateTime? value) {
    if (value == null) return '—';
    return DateFormat('dd MMM yy').format(value);
  }
}

class _IconDetailTile extends StatelessWidget {
  const _IconDetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: TimesheetModuleColors.primaryTint,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: TimesheetModuleColors.primary.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: TimesheetModuleColors.primary),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TimesheetModuleTypography.caption().copyWith(
            color: TimesheetModuleColors.mutedText,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TimesheetModuleTypography.caption().copyWith(
            color: TimesheetModuleColors.text,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
