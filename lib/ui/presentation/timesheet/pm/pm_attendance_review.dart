import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class PmAttendanceReview extends ConsumerStatefulWidget {
  const PmAttendanceReview({
    super.key,
    required this.projectId,
  });

  final String projectId;

  @override
  ConsumerState<PmAttendanceReview> createState() => _PmAttendanceReviewState();
}

class _PmAttendanceReviewState extends ConsumerState<PmAttendanceReview> {
  late DateTime _selectedDate;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final attendanceAsync = ref.watch(
      timesheetAttendanceProvider(
        TimesheetAttendanceQuery(
          projectId: widget.projectId,
          date: _selectedDate,
        ),
      ),
    );

    return TmScaffold(
      appBar: AppBar(
        title: Text('Attendance Review', style: TimesheetModuleTypography.h2()),
        backgroundColor: TimesheetModuleColors.surface,
        foregroundColor: TimesheetModuleColors.text,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TmSectionHeader(
            title: 'Today',
            actionLabel: 'Change Day',
            onActionTap: () => setState(() {
              _selectedDate = _selectedDate.subtract(const Duration(days: 1));
            }),
          ),
          const SizedBox(height: TimesheetModuleLayout.cardSpacing),
          TmFilterChipRow(
            options: [
              TmFilterOption(
                  id: 'all', label: 'All', icon: PhosphorIcons.list()),
              TmFilterOption(
                id: 'outside',
                label: 'Outside Geofence',
                icon: PhosphorIcons.mapPin(),
              ),
              TmFilterOption(
                id: 'manual',
                label: 'Manual',
                icon: PhosphorIcons.handPalm(),
              ),
            ],
            selectedId: _filter,
            onChanged: (id) => setState(() => _filter = id),
          ),
          const SizedBox(height: TimesheetModuleLayout.sectionGap),
          Expanded(
            child: attendanceAsync.when(
              loading: () => const TimesheetLoadingState(
                style: TimesheetLoadingStyle.list,
                itemCount: 5,
              ),
              error: (_, __) => const TimesheetErrorState(
                message: 'Could not load attendance review',
              ),
              data: (records) {
                final filtered = records.where((record) {
                  if (_filter == 'outside') return record.outsideGeofence;
                  if (_filter == 'manual') return record.manualOverride;
                  return true;
                }).toList();
                if (filtered.isEmpty) {
                  return const TimesheetEmptyState(
                    message: 'No attendance records for this filter',
                  );
                }
                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(
                    height: TimesheetModuleLayout.cardSpacing,
                  ),
                  itemBuilder: (context, index) {
                    final record = filtered[index];
                    return Container(
                      padding: const EdgeInsets.all(
                        TimesheetModuleLayout.cardPadding,
                      ),
                      decoration: BoxDecoration(
                        color: TimesheetModuleColors.surface,
                        borderRadius: BorderRadius.circular(
                          TimesheetModuleLayout.cardRadiusMd,
                        ),
                        boxShadow: TimesheetModuleShadows.cardShadow,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: TimesheetModuleColors.navyTint,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              PhosphorIcons.camera(),
                              color: TimesheetModuleColors.navy,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Worker ${record.workerId}',
                                  style: TimesheetModuleTypography.cardTitle(),
                                ),
                                Text(
                                  '${record.event} - ${record.similarity.toStringAsFixed(1)}% similarity',
                                  style: TimesheetModuleTypography.caption(),
                                ),
                                Text(
                                  'GPS ${record.lat.toStringAsFixed(5)}, ${record.lon.toStringAsFixed(5)}',
                                  style: TimesheetModuleTypography.caption(),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              record.outsideGeofence
                                  ? PhosphorIcons.mapPin()
                                  : PhosphorIcons.checkCircle(),
                              color: record.outsideGeofence
                                  ? TimesheetModuleColors.warning
                                  : TimesheetModuleColors.navy,
                            ),
                            onPressed: () => _showRecordDetail(record),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showRecordDetail(dynamic record) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(TimesheetModuleLayout.cardPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: TimesheetModuleColors.navyTint,
                borderRadius: BorderRadius.circular(
                  TimesheetModuleLayout.cardRadiusLg,
                ),
              ),
              child: Center(
                child: Icon(
                  PhosphorIcons.userFocus(),
                  size: 78,
                  color: TimesheetModuleColors.navy,
                ),
              ),
            ),
            const SizedBox(height: TimesheetModuleLayout.sectionGap),
            Text(
              'Worker ${record.workerId}',
              style: TimesheetModuleTypography.h2(),
            ),
            const SizedBox(height: TimesheetModuleLayout.cardSpacing),
            _DetailRow(label: 'Event', value: record.event),
            _DetailRow(
              label: 'Similarity',
              value: '${record.similarity.toStringAsFixed(1)}%',
            ),
            _DetailRow(
              label: 'GPS pin',
              value:
                  '${record.lat.toStringAsFixed(5)}, ${record.lon.toStringAsFixed(5)}',
            ),
            _DetailRow(
              label: 'Accuracy',
              value: '${record.gpsAccuracyM.toStringAsFixed(0)} m',
            ),
            _DetailRow(
              label: 'Audit flags',
              value: record.outsideGeofence
                  ? 'Outside geofence'
                  : record.manualOverride
                      ? 'Manual override'
                      : 'Clean',
            ),
            const SizedBox(height: TimesheetModuleLayout.sectionGap),
            Row(
              children: [
                Expanded(
                  child: TmSecondaryButton(
                    label: 'Reject',
                    icon: PhosphorIcons.xCircle(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: TimesheetModuleLayout.cardSpacing),
                Expanded(
                  child: TmPrimaryButton(
                    label: 'Approve',
                    icon: PhosphorIcons.checkCircle(),
                    onPressed: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Approved in mock mode')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 98,
            child: Text(label, style: TimesheetModuleTypography.caption()),
          ),
          Expanded(child: Text(value, style: TimesheetModuleTypography.body())),
        ],
      ),
    );
  }
}
