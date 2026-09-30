import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_models.dart';
import 'package:el_race/core/timesheet/services/tm_project_location_notify_service.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/models/timesheet_capture_session_entry.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_fast_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Slide-up confirm sheet before submitting captured timesheets.
abstract final class TmTimesheetCaptureConfirmSheet {
  static Future<bool> show(
    BuildContext context, {
    required List<TimesheetCaptureSessionEntry> captures,
    required DateTime startDateTime,
    required DateTime endDateTime,
    required int breakHours,
    required ValueChanged<DateTime> onStartChanged,
    required ValueChanged<DateTime> onEndChanged,
    required ValueChanged<int> onBreakChanged,
    List<Project> projects = const [],
    Project? initialProject,
    ValueChanged<Project>? onProjectChanged,
    ValueChanged<TimesheetCaptureSessionEntry>? onRemoveCapture,
    Future<List<Project>> Function()? onReloadProjects,
    TmNotifyMissingLocation? onNotifyMissingLocation,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TmTimesheetCaptureConfirmSheetBody(
        captures: captures,
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        breakHours: breakHours,
        onStartChanged: onStartChanged,
        onEndChanged: onEndChanged,
        onBreakChanged: onBreakChanged,
        projects: projects,
        initialProject: initialProject,
        onProjectChanged: onProjectChanged,
        onRemoveCapture: onRemoveCapture,
        onReloadProjects: onReloadProjects,
        onNotifyMissingLocation: onNotifyMissingLocation,
      ),
    ).then((v) => v ?? false);
  }
}

/// Background "tell staff the location is missing"; resolves to the number
/// of staff reached (0 = failed, the Notify button comes back).
typedef TmNotifyMissingLocation = Future<int> Function(Project project);

class _TmTimesheetCaptureConfirmSheetBody extends StatefulWidget {
  const _TmTimesheetCaptureConfirmSheetBody({
    required this.captures,
    required this.startDateTime,
    required this.endDateTime,
    required this.breakHours,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onBreakChanged,
    this.projects = const [],
    this.initialProject,
    this.onProjectChanged,
    this.onRemoveCapture,
    this.onReloadProjects,
    this.onNotifyMissingLocation,
  });

  final Future<List<Project>> Function()? onReloadProjects;
  final TmNotifyMissingLocation? onNotifyMissingLocation;
  final List<TimesheetCaptureSessionEntry> captures;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final int breakHours;
  final ValueChanged<DateTime> onStartChanged;
  final ValueChanged<DateTime> onEndChanged;
  final ValueChanged<int> onBreakChanged;
  final List<Project> projects;
  final Project? initialProject;
  final ValueChanged<Project>? onProjectChanged;
  final ValueChanged<TimesheetCaptureSessionEntry>? onRemoveCapture;

  @override
  State<_TmTimesheetCaptureConfirmSheetBody> createState() =>
      _TmTimesheetCaptureConfirmSheetBodyState();
}

class _TmTimesheetCaptureConfirmSheetBodyState
    extends State<_TmTimesheetCaptureConfirmSheetBody> {
  late DateTime _start = widget.startDateTime;
  late DateTime _end = widget.endDateTime;
  late int _break = widget.breakHours;
  late List<Project> _projects = widget.projects;
  late Project? _project = _initialLocatedProject();
  late final List<TimesheetCaptureSessionEntry> _captures =
      List.of(widget.captures);

  bool get _needsProject => _projects.isNotEmpty;

  /// Only projects with site coordinates can be submitted against; an
  /// unlocated default is left unselected so the foreman picks consciously.
  Project? _initialLocatedProject() {
    final initial = widget.initialProject;
    if (initial != null) return initial.hasSiteCoordinates ? initial : null;
    for (final p in widget.projects) {
      if (p.hasSiteCoordinates) return p;
    }
    return null;
  }

  Future<List<Project>> _reloadProjects() async {
    final reload = widget.onReloadProjects;
    if (reload == null) return _projects;
    final fresh = await reload();
    if (!mounted) return fresh;
    setState(() {
      _projects = fresh;
      final current = _project;
      if (current != null) {
        final match = fresh.where((p) => p.id == current.id);
        _project = match.isNotEmpty && match.first.hasSiteCoordinates
            ? match.first
            : null;
      } else {
        final initial = widget.initialProject;
        final match = initial == null
            ? const <Project>[]
            : fresh.where((p) => p.id == initial.id).toList();
        if (match.isNotEmpty && match.first.hasSiteCoordinates) {
          _project = match.first;
          widget.onProjectChanged?.call(match.first);
        }
      }
    });
    return fresh;
  }

  void _removeCapture(TimesheetCaptureSessionEntry entry) {
    setState(() => _captures.remove(entry));
    widget.onRemoveCapture?.call(entry);
    // Removing the last captured employee clears the whole submission.
    if (_captures.isEmpty) {
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
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
                  color: TimesheetModuleColors.ink.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Confirm timesheet',
                        style: TimesheetModuleTypography.h2().copyWith(
                          color: TimesheetModuleColors.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: Icon(
                        PhosphorIcons.x(),
                        color: TimesheetModuleColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (_needsProject) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _ProjectPickerField(
                    projects: _projects,
                    selected: _project,
                    unlocatedDefault: _project == null &&
                            widget.initialProject != null &&
                            !widget.initialProject!.hasSiteCoordinates
                        ? widget.initialProject
                        : null,
                    onReload: widget.onReloadProjects == null
                        ? null
                        : _reloadProjects,
                    onNotify: widget.onNotifyMissingLocation,
                    onChanged: (project) {
                      setState(() => _project = project);
                      widget.onProjectChanged?.call(project);
                    },
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _DateTimeChip(
                        label: 'Start',
                        value: _start,
                        onTap: () => _pickDateTime(
                          context,
                          _start,
                          (v) => setState(() {
                            _start = v;
                            widget.onStartChanged(v);
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DateTimeChip(
                        label: 'End',
                        value: _end,
                        onTap: () => _pickDateTime(
                          context,
                          _end,
                          (v) => setState(() {
                            _end = v;
                            widget.onEndChanged(v);
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BreakChip(
                        hours: _break,
                        onMinus: _break > 0
                            ? () => setState(() {
                                  _break--;
                                  widget.onBreakChanged(_break);
                                })
                            : null,
                        onPlus: () => setState(() {
                          _break++;
                          widget.onBreakChanged(_break);
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_captures.length} captured employee${_captures.length == 1 ? '' : 's'}',
                    style: TimesheetModuleTypography.caption().copyWith(
                      color: TimesheetModuleColors.warmMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: _captures.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final entry = _captures[index];
                    return _CaptureRow(
                      entry: entry,
                      onRemove: () => _removeCapture(entry),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  16 + MediaQuery.paddingOf(context).bottom,
                ),
                child: TmPrimaryButton(
                  label: 'Confirm & submit',
                  warm: true,
                  icon: PhosphorIcons.paperPlaneTilt(),
                  onPressed: _captures.isEmpty ||
                          (_needsProject &&
                              (_project == null ||
                                  !_project!.hasSiteCoordinates))
                      ? null
                      : () {
                          // Hosts fall back to their own default project, so
                          // always hand back the located pick explicitly.
                          final picked = _project;
                          if (picked != null) {
                            widget.onProjectChanged?.call(picked);
                          }
                          Navigator.of(context).pop(true);
                        },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<void> _pickDateTime(
    BuildContext context,
    DateTime value,
    ValueChanged<DateTime> onPick,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
    );
    if (time == null || !context.mounted) return;
    onPick(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }
}

/// Tappable field that opens a searchable project picker sheet.
class _ProjectPickerField extends StatelessWidget {
  const _ProjectPickerField({
    required this.projects,
    required this.selected,
    required this.onChanged,
    this.unlocatedDefault,
    this.onReload,
    this.onNotify,
  });

  final List<Project> projects;
  final Project? selected;
  final ValueChanged<Project> onChanged;

  /// Host's default project when it has no coordinates (not selectable).
  final Project? unlocatedDefault;
  final Future<List<Project>> Function()? onReload;
  final TmNotifyMissingLocation? onNotify;

  @override
  Widget build(BuildContext context) {
    final current = selected;
    final warn = unlocatedDefault;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(context, current),
        if (warn != null) ...[
          const SizedBox(height: 6),
          _MissingLocationStrip(
            project: warn,
            onNotify: onNotify,
            label: 'Location is not set for ${warn.name}',
          ),
        ],
      ],
    );
  }

  Widget _field(BuildContext context, Project? current) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final picked = await _ProjectSearchSheet.show(
            context,
            projects: projects,
            selected: current,
            onReload: onReload,
            onNotify: onNotify,
          );
          if (picked != null) onChanged(picked);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: TimesheetModuleColors.glassSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: TimesheetModuleColors.glassBorder,
            ),
          ),
          child: Row(
            children: [
              Icon(
                PhosphorIcons.buildings(),
                size: 18,
                color: TimesheetModuleColors.warmMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Project',
                      style: TimesheetModuleTypography.caption().copyWith(
                        color: TimesheetModuleColors.warmMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      current?.name ?? 'Select project',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TimesheetModuleTypography.caption().copyWith(
                        color: TimesheetModuleColors.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                PhosphorIcons.caretRight(),
                color: TimesheetModuleColors.warmMuted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Searchable, smart project list shown as a themed dragger.
class _ProjectSearchSheet extends StatefulWidget {
  const _ProjectSearchSheet({
    required this.projects,
    required this.selected,
    this.onReload,
    this.onNotify,
  });

  final List<Project> projects;
  final Project? selected;
  final Future<List<Project>> Function()? onReload;
  final TmNotifyMissingLocation? onNotify;

  static Future<Project?> show(
    BuildContext context, {
    required List<Project> projects,
    Project? selected,
    Future<List<Project>> Function()? onReload,
    TmNotifyMissingLocation? onNotify,
  }) {
    return showModalBottomSheet<Project>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProjectSearchSheet(
        projects: projects,
        selected: selected,
        onReload: onReload,
        onNotify: onNotify,
      ),
    );
  }

  @override
  State<_ProjectSearchSheet> createState() => _ProjectSearchSheetState();
}

class _ProjectSearchSheetState extends State<_ProjectSearchSheet> {
  final _controller = TextEditingController();
  String _query = '';
  late List<Project> _projects = widget.projects;
  bool _reloading = false;

  /// Unlocated rows the foreman tapped — shows the inline warning strip.
  final Set<String> _expanded = {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final reload = widget.onReload;
    if (reload == null || _reloading) return;
    setState(() => _reloading = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final fresh = await reload();
      if (!mounted) return;
      final nowLocated = fresh
          .where((p) => _expanded.contains(p.id) && p.hasSiteCoordinates)
          .length;
      setState(() {
        _projects = fresh;
        _expanded.removeWhere(
          (id) => fresh.any((p) => p.id == id && p.hasSiteCoordinates),
        );
      });
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            nowLocated > 0
                ? 'Projects updated — $nowLocated now available'
                : 'Projects updated',
          ),
          duration: const Duration(seconds: 2),
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

  List<Project> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _projects;
    return _projects.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.code.toLowerCase().contains(q) ||
          p.client.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        final results = _filtered;
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
                  color: TimesheetModuleColors.ink.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Select project',
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
                child: TextField(
                  controller: _controller,
                  onChanged: (v) => setState(() => _query = v),
                  style: TimesheetModuleTypography.body().copyWith(
                    color: TimesheetModuleColors.ink,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search projects',
                    hintStyle: TimesheetModuleTypography.body().copyWith(
                      color: TimesheetModuleColors.warmMuted,
                    ),
                    prefixIcon: Icon(
                      PhosphorIcons.magnifyingGlass(),
                      color: TimesheetModuleColors.warmMuted,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: TimesheetModuleColors.glassSurface,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Text(
                          'No projects found',
                          style: TimesheetModuleTypography.body().copyWith(
                            color: TimesheetModuleColors.warmMuted,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final project = results[index];
                          final isSelected = widget.selected?.id == project.id;
                          final located = project.hasSiteCoordinates;
                          return _ProjectSearchRow(
                            project: project,
                            selected: isSelected && located,
                            enabled: located,
                            showMissingLocation:
                                !located && _expanded.contains(project.id),
                            onNotify: widget.onNotify,
                            onTap: located
                                ? () => Navigator.of(context).pop(project)
                                : () => setState(() {
                                      if (!_expanded.remove(project.id)) {
                                        _expanded.add(project.id);
                                      }
                                    }),
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

class _ProjectSearchRow extends StatelessWidget {
  const _ProjectSearchRow({
    required this.project,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.showMissingLocation = false,
    this.onNotify,
  });

  final Project project;
  final bool selected;
  final VoidCallback onTap;

  /// False when the project has no site coordinates (can't be submitted).
  final bool enabled;
  final bool showMissingLocation;
  final TmNotifyMissingLocation? onNotify;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if (project.code.trim().isNotEmpty) project.code.trim(),
      if (project.client.trim().isNotEmpty) project.client.trim(),
    ];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? TimesheetModuleColors.accentTint
                : TimesheetModuleColors.glassSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? TimesheetModuleColors.accent
                  : showMissingLocation
                      ? TimesheetModuleColors.danger.withValues(alpha: 0.45)
                      : TimesheetModuleColors.glassBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Opacity(
                opacity: enabled ? 1 : 0.45,
                child: _rowContent(subtitleParts),
              ),
              if (showMissingLocation) ...[
                const SizedBox(height: 10),
                _MissingLocationStrip(project: project, onNotify: onNotify),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _rowContent(List<String> subtitleParts) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: TimesheetModuleColors.iconSurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            PhosphorIcons.buildings(),
            color: TimesheetModuleColors.ink,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                project.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TimesheetModuleTypography.cardTitle().copyWith(
                  color: TimesheetModuleColors.ink,
                ),
              ),
              if (subtitleParts.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitleParts.join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TimesheetModuleTypography.caption().copyWith(
                    color: TimesheetModuleColors.warmMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (selected)
          Icon(
            PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
            color: TimesheetModuleColors.ink,
            size: 22,
          ),
        if (!enabled)
          Icon(
            PhosphorIcons.mapPinLine(),
            color: TimesheetModuleColors.danger,
            size: 20,
          ),
      ],
    );
  }
}

/// ⚠ Location is not set  ·  [Notify] → ✓ Notified (delivery runs behind).
class _MissingLocationStrip extends StatefulWidget {
  const _MissingLocationStrip({
    required this.project,
    this.onNotify,
    this.label = 'Location is not set',
  });

  final Project project;
  final TmNotifyMissingLocation? onNotify;
  final String label;

  @override
  State<_MissingLocationStrip> createState() => _MissingLocationStripState();
}

class _MissingLocationStripState extends State<_MissingLocationStrip> {
  late bool _notified =
      TmProjectLocationNotifyService.wasNotified(widget.project.id);

  void _notify() {
    final notify = widget.onNotify;
    if (notify == null || _notified) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final name = widget.project.name;
    setState(() => _notified = true);
    notify(widget.project).then((delivered) {
      if (delivered > 0) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              'Staff notified about $name ($delivered '
              '${delivered == 1 ? 'person' : 'people'})',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
      if (mounted) setState(() => _notified = false);
      messenger?.showSnackBar(
        SnackBar(content: Text("Couldn't notify staff for $name — try again")),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          PhosphorIcons.warning(PhosphorIconsStyle.fill),
          size: 16,
          color: TimesheetModuleColors.danger,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            widget.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TimesheetModuleTypography.caption().copyWith(
              color: TimesheetModuleColors.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (widget.onNotify != null) ...[
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _notified
                ? Row(
                    key: const ValueKey('notified'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                        size: 16,
                        color: const Color(0xFF2E9E5B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Notified',
                        style: TimesheetModuleTypography.caption().copyWith(
                          color: const Color(0xFF2E9E5B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    key: const ValueKey('notify'),
                    height: 28,
                    child: OutlinedButton.icon(
                      onPressed: _notify,
                      icon: Icon(PhosphorIcons.bellRinging(), size: 14),
                      label: const Text('Notify'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: TimesheetModuleColors.ink,
                        side: const BorderSide(
                          color: TimesheetModuleColors.ink,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ],
    );
  }
}

class _DateTimeChip extends StatelessWidget {
  const _DateTimeChip({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: TimesheetModuleColors.glassSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: TimesheetModuleColors.glassBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TimesheetModuleTypography.caption().copyWith(
                color: TimesheetModuleColors.warmMuted,
                fontSize: 10,
              ),
            ),
            Text(
              DateFormat('d MMM · HH:mm').format(value),
              style: TimesheetModuleTypography.caption().copyWith(
                color: TimesheetModuleColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakChip extends StatelessWidget {
  const _BreakChip({
    required this.hours,
    required this.onMinus,
    required this.onPlus,
  });

  final int hours;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: TimesheetModuleColors.glassSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: TimesheetModuleColors.glassBorder,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Break',
            style: TimesheetModuleTypography.caption().copyWith(
              color: TimesheetModuleColors.warmMuted,
              fontSize: 10,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onTap: onMinus,
                child: Icon(
                  PhosphorIcons.minus(),
                  size: 14,
                  color: onMinus == null
                      ? TimesheetModuleColors.warmMuted.withValues(alpha: 0.5)
                      : TimesheetModuleColors.ink,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '$hours h',
                  style: TimesheetModuleTypography.caption().copyWith(
                    color: TimesheetModuleColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              InkWell(
                onTap: onPlus,
                child: Icon(
                  PhosphorIcons.plus(),
                  size: 14,
                  color: TimesheetModuleColors.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CaptureRow extends StatelessWidget {
  const _CaptureRow({required this.entry, required this.onRemove});

  final TimesheetCaptureSessionEntry entry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final emp = entry.employee;
    final url = emp.imageUrl?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TimesheetModuleColors.glassSurface,
        borderRadius: BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
        border: Border.all(
          color: TimesheetModuleColors.glassBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: TimesheetModuleColors.accentTint,
              border: Border.all(
                color: TimesheetModuleColors.iconSurface,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: url.isNotEmpty
                ? TmFastNetworkImage(
                    url: url,
                    width: 44,
                    height: 44,
                    memCacheWidth: 88,
                  )
                : Center(
                    child: Text(
                      emp.name.isNotEmpty ? emp.name[0] : '?',
                      style: TimesheetModuleTypography.h2().copyWith(
                        color: TimesheetModuleColors.ink,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emp.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TimesheetModuleTypography.cardTitle().copyWith(
                    color: TimesheetModuleColors.ink,
                  ),
                ),
                Text(
                  'File ID: ${emp.displayFileId}',
                  style: TimesheetModuleTypography.caption().copyWith(
                    color: TimesheetModuleColors.warmMuted,
                  ),
                ),
                if ((emp.jobPosition ?? '').isNotEmpty)
                  Text(
                    emp.jobPosition!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TimesheetModuleTypography.caption().copyWith(
                      color: TimesheetModuleColors.warmMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              onPressed: onRemove,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Remove',
              icon: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: TimesheetModuleColors.danger.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIcons.x(PhosphorIconsStyle.bold),
                  size: 14,
                  color: TimesheetModuleColors.danger,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
