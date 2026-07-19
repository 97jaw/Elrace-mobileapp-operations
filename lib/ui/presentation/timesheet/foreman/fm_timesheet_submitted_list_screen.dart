import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_paginated_list_view.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_timesheet_entry_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Full submitted timesheet browse — date range + same day-list row design.
class FmTimesheetSubmittedListScreen extends ConsumerStatefulWidget {
  const FmTimesheetSubmittedListScreen({super.key});

  @override
  ConsumerState<FmTimesheetSubmittedListScreen> createState() =>
      _FmTimesheetSubmittedListScreenState();
}

class _FmTimesheetSubmittedListScreenState
    extends ConsumerState<FmTimesheetSubmittedListScreen> {
  late DateTime _from;
  late DateTime _to;
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day);
    _from = _to.subtract(const Duration(days: 7));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final buckets = await ref.read(timesheetProjectBucketsProvider.future);
      if (buckets.inProgress.isEmpty) {
        if (!mounted) return;
        setState(() {
          _rows = const [];
          _loading = false;
        });
        return;
      }
      final client = ref.read(timesheetApiClientProvider);
      final collected = <Map<String, dynamic>>[];
      for (final project in buckets.inProgress.take(5)) {
        try {
          final rows = await client.fetchProjectTimesheetRowsForRange(
            projectId: project.id,
            fromDate: _from,
            toDate: _to,
          );
          collected.addAll(rows);
        } catch (_) {}
      }
      collected.sort((a, b) {
        final da = a['date']?.toString() ?? '';
        final db = b['date']?.toString() ?? '';
        return db.compareTo(da);
      });
      if (!mounted) return;
      setState(() {
        _rows = collected;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load timesheets';
      });
    }
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020),
      lastDate: _to,
    );
    if (picked == null) return;
    setState(() => _from = DateTime(picked.year, picked.month, picked.day));
    await _load();
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: _from,
      lastDate: DateTime(2030),
    );
    if (picked == null) return;
    setState(() => _to = DateTime(picked.year, picked.month, picked.day));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    return TmScaffold(
      glassTitle: 'Timesheet records',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _RangeChip(
                  label: 'From',
                  value: fmt.format(_from),
                  onTap: _pickFrom,
                ),
              ),
              const SizedBox(width: TimesheetModuleLayout.cardSpacing),
              Expanded(
                child: _RangeChip(
                  label: 'To',
                  value: fmt.format(_to),
                  onTap: _pickTo,
                ),
              ),
            ],
          ),
          const SizedBox(height: TimesheetModuleLayout.sectionGap),
          if (_loading)
            const Expanded(
              child: TimesheetLoadingState(
                style: TimesheetLoadingStyle.list,
                itemCount: 5,
              ),
            )
          else if (_error != null)
            Expanded(
              child: TimesheetErrorState(
                message: _error!,
                onRetry: _load,
              ),
            )
          else if (_rows.isEmpty)
            const Expanded(
              child: TimesheetEmptyState(message: 'No timesheets in this range'),
            )
          else
            Expanded(
              child: TmPaginatedListView(
                itemCount: _rows.length,
                itemSpacing: 0,
                padding: const EdgeInsets.only(bottom: 24),
                itemBuilder: (context, index) => TmTimesheetEntryRow(
                  row: _rows[index],
                  index: index + 1,
                  homeLight: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(TimesheetModuleLayout.cardRadiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: TimesheetModuleColors.surface,
          borderRadius:
              BorderRadius.circular(TimesheetModuleLayout.cardRadiusSm),
          border: Border.all(color: TimesheetModuleColors.divider),
        ),
        child: Row(
          children: [
            Icon(
              PhosphorIcons.calendarBlank(),
              size: 18,
              color: TimesheetModuleColors.navy,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TimesheetModuleTypography.caption()),
                  Text(
                    value,
                    style: TimesheetModuleTypography.cardTitle(),
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
