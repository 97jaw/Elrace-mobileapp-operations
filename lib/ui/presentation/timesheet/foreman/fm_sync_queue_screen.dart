import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/services/capture_queue_service.dart';
import 'package:el_race/core/timesheet/services/timesheet_capture_flow_service.dart';
import 'package:el_race/core/timesheet/services/timesheet_offline_queue_service.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class FmSyncQueueScreen extends ConsumerStatefulWidget {
  const FmSyncQueueScreen({super.key});

  @override
  ConsumerState<FmSyncQueueScreen> createState() => _FmSyncQueueScreenState();
}

class _FmSyncQueueScreenState extends ConsumerState<FmSyncQueueScreen> {
  final _captureQueue = TimesheetCaptureQueueService();
  final _offlineQueue = TimesheetOfflineQueueService();
  final _flowService = TimesheetCaptureFlowService();
  bool _isDraining = false;

  @override
  Widget build(BuildContext context) {
    return TmScaffold(
      glassTitle: 'Pending sync',
      body: FutureBuilder(
        future: Future.wait([
          _captureQueue.pending(),
          _offlineQueue.pending(),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const TimesheetLoadingState(
              style: TimesheetLoadingStyle.list,
              itemCount: 4,
            );
          }
          final captureDrafts = snapshot.data![0] as List<AttendanceCaptureDraft>;
          final offlineItems =
              snapshot.data![1] as List<TimesheetOfflineQueueItem>;

          if (captureDrafts.isEmpty && offlineItems.isEmpty) {
            return const TimesheetEmptyState(
              message: 'All captures and uploads are synced',
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TmPrimaryButton(
                label: _isDraining ? 'Syncing...' : 'Retry all',
                icon: PhosphorIcons.arrowsClockwise(),
                onPressed: _isDraining ? null : () => _drainAll(context),
              ),
              const SizedBox(height: TimesheetModuleLayout.sectionGap),
              Expanded(
                child: ListView(
                  children: [
                    if (captureDrafts.isNotEmpty) ...[
                      TmSectionHeader(
                        title: 'Attendance captures (${captureDrafts.length})',
                      ),
                      const SizedBox(height: TimesheetModuleLayout.cardSpacing),
                      for (final draft in captureDrafts) ...[
                        TmTaskRow(
                          title: '${draft.event} · ${draft.taskId}',
                          subtitle:
                              '${draft.projectId} · ${draft.syncState.name}${draft.error == null ? '' : ' · ${draft.error}'}',
                          icon: PhosphorIcons.camera(),
                        ),
                        const SizedBox(
                          height: TimesheetModuleLayout.cardSpacing,
                        ),
                      ],
                    ],
                    if (offlineItems.isNotEmpty) ...[
                      TmSectionHeader(
                        title: 'Photos & reports (${offlineItems.length})',
                      ),
                      const SizedBox(height: TimesheetModuleLayout.cardSpacing),
                      for (final item in offlineItems) ...[
                        TmTaskRow(
                          title: item.type.name,
                          subtitle: item.projectId,
                          icon: item.type == TimesheetOfflineQueueType.siteReport
                              ? PhosphorIcons.fileText()
                              : PhosphorIcons.images(),
                        ),
                        const SizedBox(
                          height: TimesheetModuleLayout.cardSpacing,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _drainAll(BuildContext context) async {
    setState(() => _isDraining = true);
    try {
      await _captureQueue.drain(
        sync: (draft) => _flowService.matchCapture(draft),
      );
      await _offlineQueue.drain();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync queue processed')),
      );
      setState(() {});
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _isDraining = false);
    }
  }
}
