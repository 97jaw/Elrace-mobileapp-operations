import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/network/timesheet_functions_client.dart';
import 'package:el_race/core/timesheet/services/capture_queue_service.dart';
import 'package:el_race/core/timesheet/services/geofence_service.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/face_capture_sandbox.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class TimesheetWidgetsSandbox extends StatefulWidget {
  const TimesheetWidgetsSandbox({super.key});

  @override
  State<TimesheetWidgetsSandbox> createState() =>
      _TimesheetWidgetsSandboxState();
}

class _TimesheetWidgetsSandboxState extends State<TimesheetWidgetsSandbox> {
  String _chipId = 'all';
  String _lastQuery = '';
  String _mockMatchLabel = 'Not run';
  String _queueLabel = 'Queue not run';
  String _geofenceLabel = 'Geofence not run';
  int _navIndex = 0;

  static final _chips = [
    TmFilterOption(
      id: 'all',
      label: 'All',
      icon: PhosphorIcons.circlesThreePlus(),
    ),
    TmFilterOption(
      id: 'progress',
      label: 'Progress',
      icon: PhosphorIcons.chartLineUp(),
    ),
    TmFilterOption(
      id: 'tasks',
      label: 'Tasks',
      icon: PhosphorIcons.clipboardText(),
    ),
    TmFilterOption(
      id: 'teams',
      label: 'Teams',
      icon: PhosphorIcons.usersThree(),
    ),
  ];

  static final _navItems = [
    TmBottomNavItem(label: 'Home', icon: PhosphorIcons.house()),
    TmBottomNavItem(label: 'Tasks', icon: PhosphorIcons.clipboardText()),
  ];

  @override
  Widget build(BuildContext context) {
    return TmScaffold(
      appBar: AppBar(
        title: Text(
          'Timesheet widgets (F.2)',
          style: TimesheetModuleTypography.h2(),
        ),
        backgroundColor: TimesheetModuleColors.surface,
        foregroundColor: TimesheetModuleColors.text,
        elevation: 0,
      ),
      bottomNavigationBar: TmBottomNavBar(
        items: _navItems,
        currentIndex: _navIndex,
        onItemTap: (index) => setState(() => _navIndex = index),
        onFabTap: () {},
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TmGreetingHeader(name: 'Shanta Mariya'),
            const SizedBox(height: TimesheetModuleLayout.sectionGap),
            TmSearchField(
              hintText: 'Find your match',
              onDebouncedChanged: (query) => setState(() => _lastQuery = query),
            ),
            const SizedBox(height: 8),
            Text(
              'Last query: ${_lastQuery.isEmpty ? '-' : _lastQuery}',
              style: TimesheetModuleTypography.caption(),
            ),
            const SizedBox(height: TimesheetModuleLayout.cardSpacing),
            TmFilterChipRow(
              options: _chips,
              selectedId: _chipId,
              onChanged: (id) => setState(() => _chipId = id),
            ),
            const SizedBox(height: TimesheetModuleLayout.sectionGap),
            Row(
              children: [
                Expanded(
                  child: TmStatTile(
                    value: '12',
                    label: 'Projects',
                    icon: PhosphorIcons.briefcase(),
                  ),
                ),
                const SizedBox(width: TimesheetModuleLayout.cardSpacing),
                Expanded(
                  child: TmStatTile(
                    value: '34',
                    label: 'Tasks',
                    icon: PhosphorIcons.clipboardText(),
                  ),
                ),
                const SizedBox(width: TimesheetModuleLayout.cardSpacing),
                Expanded(
                  child: TmStatTile(
                    value: '05',
                    label: 'Teams',
                    icon: PhosphorIcons.usersThree(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: TimesheetModuleLayout.sectionGap),
            const TmSectionHeader(
                title: 'Active Project', actionLabel: 'See All'),
            const SizedBox(height: TimesheetModuleLayout.cardSpacing),
            const TmProjectCard(
              name: 'Midtown Tower Project',
              taskCountLabel: '8 Tasks',
            ),
            const SizedBox(height: TimesheetModuleLayout.sectionGap),
            const TmSectionHeader(
                title: "Today's Tasks", actionLabel: 'See All'),
            const SizedBox(height: TimesheetModuleLayout.cardSpacing),
            TmTaskRow(
              title: "Site's Inspection",
              subtitle: '10:00 AM',
              icon: PhosphorIcons.hardHat(),
              trailing: const TmAvatarStack(
                labels: ['Ahmed', 'Bilal', 'Carlos', 'Dinesh'],
              ),
            ),
            const SizedBox(height: TimesheetModuleLayout.cardSpacing),
            TmTaskRow(
              title: 'Concrete Pouring',
              subtitle: 'Midtown Tower Delivery Area',
              icon: PhosphorIcons.truck(),
              trailing: const TmAvatarStack(labels: ['Sara', 'Omar']),
            ),
            const SizedBox(height: TimesheetModuleLayout.sectionGap),
            TmPrimaryButton(
              label: 'Take Attendance',
              icon: PhosphorIcons.play(),
              onPressed: () {},
            ),
            const SizedBox(height: TimesheetModuleLayout.cardSpacing),
            TmSecondaryButton(
              label: 'Open Project Chat',
              icon: PhosphorIcons.chatsCircle(),
              onPressed: () {},
            ),
            const SizedBox(height: TimesheetModuleLayout.cardSpacing),
            TmSecondaryButton(
              label: 'F.4 mock match',
              icon: PhosphorIcons.cloudCheck(),
              onPressed: _runMockMatch,
            ),
            const SizedBox(height: TimesheetModuleLayout.cardSpacing),
            TmSecondaryButton(
              label: 'F.7 face capture',
              icon: PhosphorIcons.userFocus(),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const FaceCaptureSandbox(),
                ),
              ),
            ),
            const SizedBox(height: TimesheetModuleLayout.cardSpacing),
            TmSecondaryButton(
              label: 'F.8 queue drain',
              icon: PhosphorIcons.arrowsClockwise(),
              onPressed: _runQueueDrain,
            ),
            const SizedBox(height: TimesheetModuleLayout.cardSpacing),
            TmSecondaryButton(
              label: 'F.9 geofence preview',
              icon: PhosphorIcons.mapPin(),
              onPressed: _runGeofencePreview,
            ),
            const SizedBox(height: 8),
            Text(
              'Mock match: $_mockMatchLabel',
              style: TimesheetModuleTypography.caption(),
            ),
            const SizedBox(height: 4),
            Text(
              'Capture queue: $_queueLabel',
              style: TimesheetModuleTypography.caption(),
            ),
            const SizedBox(height: 4),
            Text(
              'Geofence: $_geofenceLabel',
              style: TimesheetModuleTypography.caption(),
            ),
            const SizedBox(height: TimesheetModuleLayout.sectionGap),
          ],
        ),
      ),
    );
  }

  Future<void> _runMockMatch() async {
    setState(() => _mockMatchLabel = 'Running...');
    final result = await TimesheetFunctionsClient().matchAttendance(
      projectId: 'p_midtown',
      taskId: 't_inspection',
      cropUrl: 'mock_crop_${DateTime.now().millisecondsSinceEpoch}',
      lat: 25.2048,
      lon: 55.2708,
      event: 'checkIn',
    );
    if (!mounted) return;
    setState(() {
      _mockMatchLabel =
          '${result.result} (${result.similarity.toStringAsFixed(1)}%)';
    });
  }

  Future<void> _runQueueDrain() async {
    setState(() => _queueLabel = 'Enqueueing...');
    final service = TimesheetCaptureQueueService();
    await service.enqueue(timesheetMockCaptureDraft());
    final before = await service.pendingCount();
    final result = await service.drain();
    if (!mounted) return;
    setState(() {
      _queueLabel =
          'before=$before synced=${result.synced} failed=${result.failed} remaining=${result.remaining}';
    });
  }

  void _runGeofencePreview() {
    const service = TimesheetGeofenceService();
    final preview = service.preview(
      point: const TimesheetGeoPoint(lat: 25.2051, lon: 55.271),
      center: const TimesheetGeoPoint(lat: 25.2048, lon: 55.2708),
      radiusM: 120,
    );
    setState(() => _geofenceLabel = preview.label);
  }
}
