import 'package:el_race/core/theme/timesheet_module_theme.dart';
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
  });

  final List<TimesheetCaptureSessionEntry> captures;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final int breakHours;
  final ValueChanged<DateTime> onStartChanged;
  final ValueChanged<DateTime> onEndChanged;
  final ValueChanged<int> onBreakChanged;

  @override
  State<_TmTimesheetCaptureConfirmSheetBody> createState() =>
      _TmTimesheetCaptureConfirmSheetBodyState();
}

class _TmTimesheetCaptureConfirmSheetBodyState
    extends State<_TmTimesheetCaptureConfirmSheetBody> {
  late DateTime _start = widget.startDateTime;
  late DateTime _end = widget.endDateTime;
  late int _break = widget.breakHours;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                TimesheetModuleColors.navy,
                TimesheetModuleColors.primaryGradientEnd,
              ],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: TimesheetModuleColors.surface.withValues(alpha: 0.5),
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
                          color: TimesheetModuleColors.surface,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: Icon(
                        PhosphorIcons.x(),
                        color: TimesheetModuleColors.surface,
                      ),
                    ),
                  ],
                ),
              ),
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
                    '${widget.captures.length} captured employee${widget.captures.length == 1 ? '' : 's'}',
                    style: TimesheetModuleTypography.caption().copyWith(
                      color: TimesheetModuleColors.surface.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: widget.captures.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final entry = widget.captures[index];
                    return _CaptureRow(entry: entry);
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
                  icon: PhosphorIcons.paperPlaneTilt(),
                  onPressed: widget.captures.isEmpty
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
          color: TimesheetModuleColors.surface.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: TimesheetModuleColors.surface.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TimesheetModuleTypography.caption().copyWith(
                color: TimesheetModuleColors.surface.withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
            Text(
              DateFormat('d MMM · HH:mm').format(value),
              style: TimesheetModuleTypography.caption().copyWith(
                color: TimesheetModuleColors.surface,
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
        color: TimesheetModuleColors.surface.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: TimesheetModuleColors.surface.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Break',
            style: TimesheetModuleTypography.caption().copyWith(
              color: TimesheetModuleColors.surface.withValues(alpha: 0.7),
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
                      ? TimesheetModuleColors.surface.withValues(alpha: 0.35)
                      : TimesheetModuleColors.surface,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '$hours h',
                  style: TimesheetModuleTypography.caption().copyWith(
                    color: TimesheetModuleColors.surface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              InkWell(
                onTap: onPlus,
                child: Icon(
                  PhosphorIcons.plus(),
                  size: 14,
                  color: TimesheetModuleColors.surface,
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
  const _CaptureRow({required this.entry});

  final TimesheetCaptureSessionEntry entry;

  @override
  Widget build(BuildContext context) {
    final emp = entry.employee;
    final url = emp.imageUrl?.trim() ?? '';
    final pct =
        (entry.matchScore * 100).clamp(0, 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TimesheetModuleColors.surface.withValues(alpha: 0.12),
        borderRadius:
            BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
        border: Border.all(
          color: const Color(0xFF3DDC84).withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: TimesheetModuleColors.primaryTint,
              border: Border.all(
                color: TimesheetModuleColors.surface.withValues(alpha: 0.5),
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
                        color: TimesheetModuleColors.surface,
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
                    color: TimesheetModuleColors.surface,
                  ),
                ),
                Text(
                  'File ID: ${emp.displayFileId}',
                  style: TimesheetModuleTypography.caption().copyWith(
                    color: TimesheetModuleColors.surface.withValues(alpha: 0.8),
                  ),
                ),
                if ((emp.jobPosition ?? '').isNotEmpty)
                  Text(
                    emp.jobPosition!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TimesheetModuleTypography.caption().copyWith(
                      color:
                          TimesheetModuleColors.surface.withValues(alpha: 0.65),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '$pct%',
            style: TimesheetModuleTypography.caption().copyWith(
              color: const Color(0xFF3DDC84),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
