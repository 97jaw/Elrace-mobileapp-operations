import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_models.dart';
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
      ),
    ).then((v) => v ?? false);
  }
}

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
  });

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
  late Project? _project = widget.initialProject ??
      (widget.projects.isNotEmpty ? widget.projects.first : null);
  late final List<TimesheetCaptureSessionEntry> _captures =
      List.of(widget.captures);

  bool get _needsProject => widget.projects.isNotEmpty;

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
                    projects: widget.projects,
                    selected: _project,
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
                          (_needsProject && _project == null)
                      ? null
                      : () => Navigator.of(context).pop(true),
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
  });

  final List<Project> projects;
  final Project? selected;
  final ValueChanged<Project> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = selected ?? (projects.isNotEmpty ? projects.first : null);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final picked = await _ProjectSearchSheet.show(
            context,
            projects: projects,
            selected: current,
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
                        color:
                            TimesheetModuleColors.warmMuted,
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
  });

  final List<Project> projects;
  final Project? selected;

  static Future<Project?> show(
    BuildContext context, {
    required List<Project> projects,
    Project? selected,
  }) {
    return showModalBottomSheet<Project>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _ProjectSearchSheet(projects: projects, selected: selected),
    );
  }

  @override
  State<_ProjectSearchSheet> createState() => _ProjectSearchSheetState();
}

class _ProjectSearchSheetState extends State<_ProjectSearchSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Project> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.projects;
    return widget.projects.where((p) {
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
                      color:
                          TimesheetModuleColors.warmMuted,
                    ),
                    prefixIcon: Icon(
                      PhosphorIcons.magnifyingGlass(),
                      color:
                          TimesheetModuleColors.warmMuted,
                      size: 20,
                    ),
                    filled: true,
                    fillColor:
                        TimesheetModuleColors.glassSurface,
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
                          return _ProjectSearchRow(
                            project: project,
                            selected: isSelected,
                            onTap: () => Navigator.of(context).pop(project),
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
  });

  final Project project;
  final bool selected;
  final VoidCallback onTap;

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
                  : TimesheetModuleColors.glassBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      TimesheetModuleColors.iconSurface,
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
            ],
          ),
        ),
      ),
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
        borderRadius:
            BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
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
                      color:
                          TimesheetModuleColors.warmMuted,
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
