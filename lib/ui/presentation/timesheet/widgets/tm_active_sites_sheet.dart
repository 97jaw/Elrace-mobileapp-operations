import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_models.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_fast_network_image.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_missing_location_notify_row.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_paginated_list_view.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Readonly Active Sites list — search + client-side pagination.
abstract final class TmActiveSitesSheet {
  static Future<void> show(
    BuildContext context, {
    required List<Project> projects,
    Future<List<Project>> Function()? onReload,
    TmNotifyMissingLocation? onNotify,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TmActiveSitesSheetBody(
        projects: projects,
        onReload: onReload,
        onNotify: onNotify,
      ),
    );
  }
}

class _TmActiveSitesSheetBody extends StatefulWidget {
  const _TmActiveSitesSheetBody({
    required this.projects,
    this.onReload,
    this.onNotify,
  });

  final List<Project> projects;
  final Future<List<Project>> Function()? onReload;
  final TmNotifyMissingLocation? onNotify;

  @override
  State<_TmActiveSitesSheetBody> createState() =>
      _TmActiveSitesSheetBodyState();
}

class _TmActiveSitesSheetBodyState extends State<_TmActiveSitesSheetBody> {
  String _query = '';
  late List<Project> _projects = List.of(widget.projects);
  bool _reloading = false;

  /// Unlocated projects first (same [hasSiteCoordinates] as confirm sheet).
  List<Project> get _ordered {
    return [
      for (final p in _projects)
        if (!p.hasSiteCoordinates) p,
      for (final p in _projects)
        if (p.hasSiteCoordinates) p,
    ];
  }

  List<Project> get _filtered {
    final q = _query.toLowerCase();
    final ordered = _ordered;
    if (q.isEmpty) return ordered;
    return ordered.where((project) {
      return project.name.toLowerCase().contains(q) ||
          project.woRefNo.toLowerCase().contains(q) ||
          project.code.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _reload() async {
    final reload = widget.onReload;
    if (reload == null || _reloading) return;
    setState(() => _reloading = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final fresh = await reload();
      if (!mounted) return;
      setState(() => _projects = List.of(fresh));
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Projects updated'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(content: Text("Couldn't reload projects")),
      );
    } finally {
      if (mounted) setState(() => _reloading = false);
    }
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
                    if (widget.onReload != null)
                      IconButton(
                        tooltip: 'Reload projects',
                        onPressed: _reloading ? null : _reload,
                        icon: _reloading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: TimesheetModuleColors.ink,
                                ),
                              )
                            : Icon(
                                PhosphorIcons.arrowClockwise(),
                                color: TimesheetModuleColors.ink,
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
                          final located = project.hasSiteCoordinates;
                          return Container(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                            decoration: BoxDecoration(
                              color: TimesheetModuleColors.glassSurface,
                              borderRadius: BorderRadius.circular(
                                TimesheetModuleLayout.cardRadiusMd,
                              ),
                              border: Border.all(
                                color: located
                                    ? TimesheetModuleColors.glassBorder
                                    : TmMissingLocationNotifyRow.danger
                                        .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _ClientLogoBadge(
                                      url: project.clientImageUrl,
                                    ),
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
                                                color: TimesheetModuleColors
                                                    .warmMuted,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (located)
                                      Icon(
                                        PhosphorIcons.mapPin(
                                          PhosphorIconsStyle.fill,
                                        ),
                                        size: 22,
                                        color: const Color(0xFF2E9E5B),
                                      ),
                                  ],
                                ),
                                if (!located) ...[
                                  const SizedBox(height: 12),
                                  TmMissingLocationNotifyRow(
                                    project: project,
                                    onNotify: widget.onNotify,
                                  ),
                                ],
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
