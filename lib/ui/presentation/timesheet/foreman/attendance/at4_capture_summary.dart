import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/core/timesheet/services/capture_queue_service.dart';
import 'package:el_race/core/timesheet/services/timesheet_capture_flow_service.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class At4CaptureSummaryScreen extends ConsumerStatefulWidget {
  const At4CaptureSummaryScreen({
    super.key,
    required this.args,
  });

  final TimesheetCaptureSummaryArgs args;

  @override
  ConsumerState<At4CaptureSummaryScreen> createState() =>
      _At4CaptureSummaryScreenState();
}

class _At4CaptureSummaryScreenState
    extends ConsumerState<At4CaptureSummaryScreen> {
  final _flowService = TimesheetCaptureFlowService();
  final _queueService = TimesheetCaptureQueueService();
  bool _isSubmitting = false;

  List<TimesheetCaptureSummaryRow> get _rows => widget.args.rows;

  @override
  Widget build(BuildContext context) {
    final matchedCount =
        _rows.where((row) => row.status == 'matched').length;
    final flaggedCount = _rows.where((row) => row.outsideGeofence).length;

    return TmScaffold(
      glassTitle: 'Capture summary',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$matchedCount of ${_rows.length} matched',
            style: TimesheetModuleTypography.display(),
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.args.capture.event == 'checkOut' ? 'Check out' : 'Check in'} · '
            '${widget.args.capture.taskName ?? widget.args.capture.taskId}',
            style: TimesheetModuleTypography.caption(),
          ),
          if (flaggedCount > 0) ...[
            const SizedBox(height: 6),
            Text(
              '$flaggedCount outside geofence',
              style: TimesheetModuleTypography.caption().copyWith(
                color: TimesheetModuleColors.warning,
              ),
            ),
          ],
          const SizedBox(height: TimesheetModuleLayout.sectionGap),
          Expanded(
            child: ListView(
              children: [
                for (final row in _rows) ...[
                  TmTaskRow(
                    title: row.name,
                    subtitle:
                        '${_formatStatus(row.status)} · ${row.score}'
                        '${row.outsideGeofence ? ' · outside geofence' : ''}',
                    icon: _iconForStatus(row.status, row.outsideGeofence),
                  ),
                  const SizedBox(height: TimesheetModuleLayout.cardSpacing),
                ],
              ],
            ),
          ),
          TmPrimaryButton(
            label: _isSubmitting ? 'Submitting...' : 'Confirm & submit timesheet',
            icon: PhosphorIcons.checkCircle(),
            onPressed: _isSubmitting || !_rows.any((r) => r.canSubmit)
                ? null
                : _confirmAndSubmit,
          ),
          const SizedBox(height: TimesheetModuleLayout.cardSpacing),
          TmSecondaryButton(
            label: 'Retry capture',
            onPressed: _isSubmitting
                ? null
                : () {
                    Navigator.of(context).pushReplacementNamed(
                      TimesheetRouteNames.captureCamera,
                      arguments: widget.args.capture,
                    );
                  },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndSubmit() async {
    setState(() => _isSubmitting = true);
    try {
      final workers = await ref.read(
        timesheetTaskWorkersProvider(widget.args.capture.taskId).future,
      );
      var submitted = 0;
      String? lastError;

      final pendingDrafts = await _queueService.pending();
      for (final row in _rows) {
        if (!row.canSubmit || row.draftId == null) continue;
        AttendanceCaptureDraft? draft;
        for (final item in pendingDrafts) {
          if (item.id == row.draftId) {
            draft = item;
            break;
          }
        }
        if (draft == null) continue;

        final match = await _flowService.matchCapture(draft);
        int? employeeId = row.odooEmployeeId;
        if (employeeId == null && row.workerId != null) {
          for (final worker in workers) {
            if (worker.id == row.workerId) {
              employeeId = worker.odooEmployeeId;
              break;
            }
          }
        }
        final submit = await _flowService.submitAttendance(
          draft: draft,
          match: match,
          workers: workers,
          workerNameOverride: row.name,
          employeeIdOverride: employeeId,
        );
        if (submit.success) {
          await _flowService.markDraftSynced(draft.id);
          submitted += 1;
        } else {
          lastError = submit.message;
        }
      }

      if (!mounted) return;
      if (submitted > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Submitted $submitted timesheet record(s) via /api/timesheet/submit',
            ),
          ),
        );
        Navigator.of(context).popUntil(
          (route) =>
              route.settings.name == TimesheetRouteNames.taskDetail ||
              route.settings.name == TimesheetRouteNames.projectDetail ||
              route.isFirst,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lastError ?? 'Nothing submitted')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submit failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  IconData _iconForStatus(String status, bool outsideGeofence) {
    if (outsideGeofence) return PhosphorIcons.mapPin();
    if (status == 'matched') return PhosphorIcons.checkCircle();
    return PhosphorIcons.warningCircle();
  }

  String _formatStatus(String status) => status.replaceAll('_', ' ');
}
