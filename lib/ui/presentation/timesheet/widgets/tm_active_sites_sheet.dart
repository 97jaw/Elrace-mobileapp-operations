import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_models.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_fast_network_image.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_paginated_list_view.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Readonly Active Sites list — search + client-side pagination.
abstract final class TmActiveSitesSheet {
  static Future<void> show(
    BuildContext context, {
    required List<Project> projects,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TmActiveSitesSheetBody(projects: projects),
    );
  }
}

class _TmActiveSitesSheetBody extends StatefulWidget {
  const _TmActiveSitesSheetBody({required this.projects});

  final List<Project> projects;

  @override
  State<_TmActiveSitesSheetBody> createState() =>
      _TmActiveSitesSheetBodyState();
}

class _TmActiveSitesSheetBodyState extends State<_TmActiveSitesSheetBody> {
  String _query = '';

  List<Project> get _filtered {
    final q = _query.toLowerCase();
    if (q.isEmpty) return widget.projects;
    return widget.projects.where((project) {
      return project.name.toLowerCase().contains(q) ||
          project.woRefNo.toLowerCase().contains(q) ||
          project.code.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            gradient: TimesheetModuleColors.warmGradient,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: TimesheetModuleColors.ink.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Active Sites',
                        style: TimesheetModuleTypography.h2().copyWith(
                          color: TimesheetModuleColors.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        PhosphorIcons.x(),
                        color: TimesheetModuleColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TmSearchField(
                  hintText: 'Search projects',
                  onDebouncedChanged: (value) =>
                      setState(() => _query = value.trim()),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const TimesheetEmptyState(message: 'No active sites')
                    : TmPaginatedListView(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemSpacing: 10,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemBuilder: (context, index) {
                          final project = filtered[index];
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 20,
                            ),
                            decoration: BoxDecoration(
                              color: TimesheetModuleColors.glassSurface,
                              borderRadius: BorderRadius.circular(
                                TimesheetModuleLayout.cardRadiusMd,
                              ),
                              border: Border.all(
                                color: TimesheetModuleColors.glassBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                _ClientLogoBadge(url: project.clientImageUrl),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        project.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TimesheetModuleTypography
                                            .cardTitle()
                                            .copyWith(
                                          color: TimesheetModuleColors.ink,
                                        ),
                                      ),
                                      if (project.woRefNo.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          project.woRefNo,
                                          style: TimesheetModuleTypography
                                              .caption()
                                              .copyWith(
                                            color:
                                                TimesheetModuleColors.warmMuted,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Circular client-logo badge with a briefcase fallback.
class _ClientLogoBadge extends StatelessWidget {
  const _ClientLogoBadge({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    const double size = 48;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: TimesheetModuleColors.iconSurface,
        shape: BoxShape.circle,
        border: Border.all(color: TimesheetModuleColors.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.trim().isNotEmpty
          ? TmFastNetworkImage(
              url: url,
              width: size,
              height: size,
              memCacheWidth: 96,
            )
          : Center(
              child: Icon(
                PhosphorIcons.briefcase(),
                color: TimesheetModuleColors.accent,
                size: 22,
              ),
            ),
    );
  }
}
