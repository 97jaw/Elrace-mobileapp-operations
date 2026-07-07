import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/providers/timesheet_role_provider.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class At1CaptureModeScreen extends ConsumerStatefulWidget {
  const At1CaptureModeScreen({super.key});

  @override
  ConsumerState<At1CaptureModeScreen> createState() => _At1CaptureModeScreenState();
}

class _At1CaptureModeScreenState extends ConsumerState<At1CaptureModeScreen> {
  static const _prefsModeKey = 'timesheet_capture_mode_default';
  static const _prefsEventKey = 'timesheet_capture_event_default';

  String _event = 'checkIn';
  String? _defaultMode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDefaults();
  }

  Future<void> _loadDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _defaultMode = prefs.getString(_prefsModeKey);
      _event = prefs.getString(_prefsEventKey) ?? 'checkIn';
    });
  }

  Future<void> _openCamera(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsModeKey, mode);
    await prefs.setString(_prefsEventKey, _event);

    if (!mounted) return;
    final capture = timesheetCaptureArgsFromRoute(
      ModalRoute.of(context)?.settings.arguments,
    ).copyWith(mode: mode, event: _event);

    await Navigator.of(context).pushNamed(
      TimesheetRouteNames.captureCamera,
      arguments: capture,
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolution = ref.watch(tmRoleResolutionProvider);
    if (!resolution.canSubmitTimesheet) {
      return TmScaffold(
        appBar: AppBar(
          title: Text('Take Attendance', style: TimesheetModuleTypography.h2()),
          backgroundColor: TimesheetModuleColors.surface,
          foregroundColor: TimesheetModuleColors.text,
          elevation: 0,
        ),
        body: const TimesheetEmptyState(
          message:
              'Project managers can review timesheet reports only. '
              'Foremen submit attendance for their assigned labors.',
        ),
      );
    }

    final capture = timesheetCaptureArgsFromRoute(
      ModalRoute.of(context)?.settings.arguments,
    );
    final taskLabel = capture.taskName ?? capture.taskId;

    return TmScaffold(
      appBar: AppBar(
        title: Text('Take Attendance', style: TimesheetModuleTypography.h2()),
        backgroundColor: TimesheetModuleColors.surface,
        foregroundColor: TimesheetModuleColors.text,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            taskLabel,
            style: TimesheetModuleTypography.caption(),
          ),
          const SizedBox(height: TimesheetModuleLayout.cardSpacing),
          Text(
            'Event type',
            style: TimesheetModuleTypography.h2(),
          ),
          const SizedBox(height: TimesheetModuleLayout.cardSpacing),
          TmFilterChipRow(
            options: [
              TmFilterOption(
                id: 'checkIn',
                label: 'Check in',
                icon: PhosphorIcons.signIn(),
              ),
              TmFilterOption(
                id: 'checkOut',
                label: 'Check out',
                icon: PhosphorIcons.signOut(),
              ),
            ],
            selectedId: _event,
            onChanged: (id) => setState(() => _event = id),
          ),
          const SizedBox(height: TimesheetModuleLayout.sectionGap),
          Text(
            'How do you want to capture?',
            style: TimesheetModuleTypography.display(),
          ),
          if (_defaultMode != null) ...[
            const SizedBox(height: 6),
            Text(
              'Default: $_defaultMode',
              style: TimesheetModuleTypography.caption(),
            ),
          ],
          const SizedBox(height: TimesheetModuleLayout.sectionGap),
          _CaptureModeCard(
            icon: PhosphorIcons.userFocus(),
            title: 'Individual',
            subtitle: 'One worker at a time',
            onTap: () => _openCamera('individual'),
          ),
          const SizedBox(height: TimesheetModuleLayout.cardSpacing),
          _CaptureModeCard(
            icon: PhosphorIcons.usersThree(),
            title: 'Group photo',
            subtitle: 'Match multiple faces from one photo',
            onTap: () => _openCamera('group'),
          ),
          const SizedBox(height: TimesheetModuleLayout.sectionGap),
          Text(
            'After capture, confirm workers on the summary screen. '
            'Attendance is saved as a timesheet entry (/api/timesheet/submit).',
            style: TimesheetModuleTypography.caption(),
          ),
        ],
      ),
    );
  }
}

class _CaptureModeCard extends StatelessWidget {
  const _CaptureModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TmTaskRow(
      title: title,
      subtitle: subtitle,
      icon: icon,
      onTap: onTap,
    );
  }
}
