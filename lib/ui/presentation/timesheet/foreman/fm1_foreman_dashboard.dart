import 'dart:async';

import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_models.dart';
import 'package:el_race/core/timesheet/models/timesheet_submit_request.dart';
import 'package:el_race/core/timesheet/models/timesheet_team_member.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/timesheet/providers/timesheet_enrollment_status_provider.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/core/timesheet/services/timesheet_capture_session_store.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/foreman/fm_timesheet_capture_submit_screen.dart';
import 'package:el_race/ui/presentation/timesheet/foreman/fm_timesheet_submitted_list_screen.dart';
import 'package:el_race/ui/presentation/timesheet/models/timesheet_capture_session_entry.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/tm_site_reports_list_screen.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_chat_launcher.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/face_recognition/tm_timesheet_capture_confirm_sheet.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_active_sites_sheet.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_team_members_sheet.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_timesheet_entry_row.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Foreman home — warm parchment glass tokens.
abstract final class _FmHomeTheme {
  static const Color canvas = TimesheetModuleColors.warmGradientStart;
  static const Color card = TimesheetModuleColors.glassSurface;
  static const Color cardBorder = Color(0xFFE4DCCB);
  static const Color divider = Color(0xFFE0D6C4);
  static const Color ink = Color(0xFF2A2A2A);
  static const Color mutedSlate = Color(0xFF7A7062);
  static const Color mutedGray = Color(0xFF9A8F7E);
  static const Color orange = Color(0xFFF97316);
  static const Color iconBadge = TimesheetModuleColors.iconSurface;
  static const Color emptyPlot = Color(0xFFEFE7D6);
  static const double cardRadius = 12;
}

class Fm1ForemanDashboard extends ConsumerWidget {
  const Fm1ForemanDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bucketsAsync = ref.watch(timesheetProjectBucketsProvider);
    final laborsAsync = ref.watch(timesheetForemanLaborsProvider);
    final recentAsync = ref.watch(timesheetForemanRecentRowsProvider);
    final pendingCaptures =
        ref.watch(timesheetPendingCaptureProvider).maybeWhen(
              data: (value) => value,
              orElse: () => const <TimesheetCaptureSessionEntry>[],
            );
    ref.watch(timesheetForemanEnrollmentMapProvider);

    final laborCount = laborsAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );
    final labors = laborsAsync.maybeWhen(
      data: (list) => list,
      orElse: () => const <TimesheetTeamMember>[],
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: _FmHomeTheme.canvas,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: TimesheetModuleColors.warmGradientEnd,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: TimesheetModuleColors.warmGradientEnd,
        bottomNavigationBar: TmBottomNavBar(
          homeLight: true,
          fabIcon: PhosphorIcons.chatCircleText(),
          items: [
            TmBottomNavItem(label: 'Home', icon: PhosphorIcons.house()),
            TmBottomNavItem(
              label: 'Report',
              icon: PhosphorIcons.clipboardText(),
              color: _FmHomeTheme.orange,
            ),
          ],
          currentIndex: 0,
          onItemTap: (index) {
            if (index == 1) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TmSiteReportsListScreen(),
                ),
              );
            }
          },
          onFabTap: () => TimesheetChatLauncher.open(context, ref),
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: TimesheetModuleColors.warmGradient,
          ),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _FmHomeHeader(),
            Expanded(
              child: SafeArea(
                top: false,
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TimesheetModuleLayout.screenPaddingH,
                    vertical: 12,
                  ),
                  child: bucketsAsync.when(
                    loading: () => const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: _FmHomeTheme.orange,
                        ),
                      ),
                    ),
                    error: (_, __) => TimesheetErrorState(
                      message: 'Could not load projects',
                      warm: true,
                      onRetry: () =>
                          ref.invalidate(timesheetProjectBucketsProvider),
                    ),
                    data: (buckets) {
                      final assignedCount = buckets.inProgress.length +
                          buckets.completedTotal;
                      if (assignedCount == 0 && laborCount == 0) {
                        return const Center(
                          child: Text(
                            'No projects assigned',
                            style: TextStyle(
                              color: _FmHomeTheme.mutedGray,
                              fontSize: 14,
                            ),
                          ),
                        );
                      }

                      final content = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _HomeStatCard(
                                    value: '$assignedCount',
                                    label: 'Assigned Projects',
                                    icon: PhosphorIcons.buildings(),
                                  ),
                                ),
                                const SizedBox(
                                  width: TimesheetModuleLayout.cardSpacing,
                                ),
                                Expanded(
                                  child: _HomeStatCard(
                                    value: '${buckets.inProgress.length}',
                                    label: 'Active Sites',
                                    icon: PhosphorIcons.briefcase(),
                                    onTap: () => TmActiveSitesSheet.show(
                                      context,
                                      projects: buckets.inProgress,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            height: TimesheetModuleLayout.sectionGap,
                          ),
                          _YourTeamBox(
                            laborCount: laborCount,
                            labors: labors,
                            onTap: () => _showLabors(context, ref, buckets),
                          ),
                          const SizedBox(
                            height: TimesheetModuleLayout.sectionGap,
                          ),
                          _PrintTimesheetButton(
                            onPressed: () => Navigator.of(context).pushNamed(
                              TimesheetRouteNames.foremanTimesheetRecords,
                            ),
                          ),
                          const SizedBox(
                            height: TimesheetModuleLayout.sectionGap,
                          ),
                          // Recent list keeps its own internal scroll and fills
                          // the remaining space instead of scrolling the page.
                          Expanded(
                            child: _RecentTimesheetsSection(
                              recentAsync: recentAsync,
                            ),
                          ),
                          if (pendingCaptures.isNotEmpty)
                            const SizedBox(height: 72),
                        ],
                      );

                      if (pendingCaptures.isEmpty) return content;
                      return Stack(
                        children: [
                          content,
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 12,
                            child: _FloatingSubmitButton(
                              count: pendingCaptures.length,
                              onPressed: () => _submitFromStore(
                                context,
                                ref,
                                buckets,
                                pendingCaptures,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLabors(
    BuildContext context,
    WidgetRef ref,
    TimesheetProjectBuckets buckets,
  ) async {
    final members = ref.read(timesheetForemanLaborsProvider).maybeWhen(
          data: (value) => value,
          orElse: () => <TimesheetTeamMember>[],
        );
    final enrollment =
        ref.read(timesheetForemanEnrollmentMapProvider).maybeWhen(
              data: (value) => value,
              orElse: () => const <int, bool>{},
            );

    final pending = ref.read(timesheetPendingCaptureProvider).maybeWhen(
          data: (value) => value,
          orElse: () => const <TimesheetCaptureSessionEntry>[],
        );
    final defaultArgs = await _resolveDefaultArgs(ref, buckets);
    if (!context.mounted) return;

    await TmTeamMembersSheet.show(
      context,
      title: 'Your Team',
      members: members,
      enrollmentByEmployeeId: enrollment,
      watchForemanEnrollment: true,
      initialCaptures: pending,
      onEnroll: (member) => _openEnroll(context, ref, member),
      onCaptureAttendance: (member) =>
          _captureForMember(context, ref, buckets, member),
      onPendingChanged: (captures) =>
          _persistPending(ref, defaultArgs, captures),
      onSubmitCaptures: (captures) =>
          _submitCaptures(context, ref, buckets, captures),
    );

    if (context.mounted) {
      ref.invalidate(timesheetForemanEnrollmentMapProvider);
      ref.invalidate(timesheetForemanRecentRowsProvider);
      ref.invalidate(timesheetPendingCaptureProvider);
    }
  }

  Future<TimesheetProjectDayArgs?> _resolveDefaultArgs(
    WidgetRef ref,
    TimesheetProjectBuckets buckets,
  ) async {
    if (buckets.inProgress.isEmpty) return null;
    final project = buckets.inProgress.first;
    try {
      final task =
          await ref.read(timesheetMaintenanceTaskProvider(project.id).future);
      final today = DateTime.now();
      return TimesheetProjectDayArgs(
        projectId: project.id,
        projectName: project.name,
        taskId: task.id,
        taskName: task.name,
        date: DateTime(today.year, today.month, today.day),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistPending(
    WidgetRef ref,
    TimesheetProjectDayArgs? args,
    List<TimesheetCaptureSessionEntry> captures,
  ) async {
    if (captures.isEmpty) {
      await TimesheetCaptureSessionStore.clear();
    } else if (args != null) {
      await TimesheetCaptureSessionStore.save(args: args, captures: captures);
    }
    ref.invalidate(timesheetPendingCaptureProvider);
  }

  Future<void> _submitFromStore(
    BuildContext context,
    WidgetRef ref,
    TimesheetProjectBuckets buckets,
    List<TimesheetCaptureSessionEntry> captures,
  ) async {
    await _submitCaptures(context, ref, buckets, captures);
  }

  Future<void> _openEnroll(
    BuildContext context,
    WidgetRef ref,
    TimesheetTeamMember member,
  ) async {
    // Employee is already known from the team list — skip the file-ID step and
    // go straight to pose capture.
    await Navigator.of(context).pushNamed(
      TimesheetRouteNames.faceEnrollCapture,
      arguments: TimesheetFaceEnrollCaptureArgs(
        projectId: '',
        employee: member.toOdooEmployee(),
      ),
    );
    if (context.mounted) {
      ref.invalidate(timesheetForemanEnrollmentMapProvider);
    }
  }

  /// Opens the camera to capture a single labor and returns the captured
  /// entries so the Your Team sheet can accumulate them.
  Future<List<TimesheetCaptureSessionEntry>> _captureForMember(
    BuildContext context,
    WidgetRef ref,
    TimesheetProjectBuckets buckets,
    TimesheetTeamMember member,
  ) async {
    if (buckets.inProgress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active sites available')),
      );
      return const [];
    }

    final project = buckets.inProgress.first;
    try {
      final task =
          await ref.read(timesheetMaintenanceTaskProvider(project.id).future);
      if (!context.mounted) return const [];
      final today = DateTime.now();
      final result =
          await Navigator.of(context).push<List<TimesheetCaptureSessionEntry>>(
        MaterialPageRoute(
          builder: (_) => FmTimesheetCaptureSubmitScreen(
            returnCaptures: true,
            args: TimesheetProjectDayArgs(
              projectId: project.id,
              projectName: project.name,
              taskId: task.id,
              taskName: task.name,
              date: DateTime(today.year, today.month, today.day),
            ),
          ),
        ),
      );
      return result ?? const [];
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open timesheet capture')),
        );
      }
      return const [];
    }
  }

  /// Confirm + submit accumulated captures. Returns true on success.
  Future<bool> _submitCaptures(
    BuildContext context,
    WidgetRef ref,
    TimesheetProjectBuckets buckets,
    List<TimesheetCaptureSessionEntry> captures,
  ) async {
    if (captures.isEmpty) return false;

    final projects = buckets.inProgress;
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active sites available')),
      );
      return false;
    }

    // Mutable working copy so the confirm sheet can drop captured labors, with
    // removals persisted live so the floating submit counter updates too.
    final working = List.of(captures);
    final pendingArgs = await _resolveDefaultArgs(ref, buckets);
    if (!context.mounted) return false;

    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    var start =
        DateTime(day.year, day.month, day.day, today.hour, today.minute)
            .subtract(const Duration(hours: 9));
    var end = DateTime(day.year, day.month, day.day, today.hour, today.minute);
    var breakHours = 1;
    Project? selectedProject = projects.first;

    final confirmed = await TmTimesheetCaptureConfirmSheet.show(
      context,
      captures: List.unmodifiable(working),
      startDateTime: start,
      endDateTime: end,
      breakHours: breakHours,
      onStartChanged: (v) => start = v,
      onEndChanged: (v) => end = v,
      onBreakChanged: (v) => breakHours = v,
      projects: projects,
      initialProject: selectedProject,
      onProjectChanged: (project) => selectedProject = project,
      onRemoveCapture: (entry) {
        working.remove(entry);
        unawaited(_persistPending(ref, pendingArgs, List.of(working)));
      },
    );
    if (!confirmed || !context.mounted) return false;
    if (working.isEmpty) return false;

    var submitProjectId = selectedProject?.id ?? projects.first.id;
    String submitTaskId;
    try {
      final task = await ref.read(
        timesheetMaintenanceTaskProvider(submitProjectId).future,
      );
      submitTaskId = task.id;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not resolve task for selected project'),
          ),
        );
      }
      return false;
    }

    try {
      final client = ref.read(timesheetApiClientProvider);
      final ids = working.map((e) => e.employeeId).toList(growable: false);
      final names = working.map((e) => e.employee.name).join(', ');
      final coords = working
          .map(
            (e) => TimesheetSubmitCoord(
              employeeId: e.employeeId,
              lat: e.draft.lat,
              lon: e.draft.lon,
            ),
          )
          .toList(growable: false);
      final result = await client.submitTimesheet(
        TimesheetSubmitRequest(
          projectId: submitProjectId,
          taskId: submitTaskId,
          employeeIds: ids,
          employeeName: names,
          date: day,
          dateTime: start,
          dateTimeEnd: end,
          breakTimeHours: breakHours,
          coords: coords,
        ),
      );
      if (!context.mounted) return result.success;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? (result.message ?? 'Timesheet submitted')
                : (result.message ?? 'Submission failed'),
          ),
        ),
      );
      if (result.success) {
        await TimesheetCaptureSessionStore.clear();
        ref.invalidate(timesheetForemanRecentRowsProvider);
        ref.invalidate(timesheetPendingCaptureProvider);
      }
      return result.success;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submission failed')),
        );
      }
      return false;
    }
  }
}

class _FmHomeHeader extends StatelessWidget {
  const _FmHomeHeader();

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ContextualGlassChromeHeader(
            onLightSurface: true,
            scrimColor: _FmHomeTheme.canvas,
            scrimTopOpacity: 0.28,
            logoOpacity: 1,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TimesheetModuleLayout.screenPaddingH,
              4,
              TimesheetModuleLayout.screenPaddingH,
              14,
            ),
            child: Row(
              children: [
                if (canPop) ...[
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: _FmHomeTheme.ink,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: ShaderMask(
                    shaderCallback: (bounds) => TimesheetModuleColors
                        .warmButtonGradient
                        .createShader(bounds),
                    blendMode: BlendMode.srcIn,
                    child: const Text(
                      'Timesheet Dashboard',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: _FmHomeTheme.divider,
          ),
        ],
      ),
    );
  }
}

/// Persistent home-screen submit button for captured-but-unsubmitted labors.
class _FloatingSubmitButton extends StatelessWidget {
  const _FloatingSubmitButton({
    required this.count,
    required this.onPressed,
  });

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(25),
        onTap: onPressed,
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            gradient: TimesheetModuleColors.warmButtonGradient,
            borderRadius: BorderRadius.circular(25),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Submit timesheet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Icon(
                PhosphorIcons.paperPlaneTilt(PhosphorIconsStyle.fill),
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrintTimesheetButton extends StatelessWidget {
  const _PrintTimesheetButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            gradient: TimesheetModuleColors.warmButtonGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.print_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Print Timesheet',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = 5.0;
      const gap = 4.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _RecentTimesheetsSection extends StatelessWidget {
  const _RecentTimesheetsSection({required this.recentAsync});

  final AsyncValue<List<Map<String, dynamic>>> recentAsync;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _FmHomeTheme.card,
        borderRadius: BorderRadius.circular(_FmHomeTheme.cardRadius),
        border: Border.all(color: _FmHomeTheme.cardBorder),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent timesheets',
                  style: TextStyle(
                    color: _FmHomeTheme.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const FmTimesheetSubmittedListScreen(),
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: _FmHomeTheme.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Show all',
                  style: TextStyle(
                    color: _FmHomeTheme.orange,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: recentAsync.when(
              data: (rows) {
                if (rows.isEmpty) {
                  return const Align(
                    alignment: Alignment.topCenter,
                    child: _RecentEmpty(
                      message: 'No recent timesheet submissions',
                    ),
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: rows.length,
                  itemBuilder: (context, i) => TmTimesheetEntryRow(
                    row: rows[i],
                    index: i + 1,
                    homeLight: true,
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _FmHomeTheme.orange,
                    ),
                  ),
                ),
              ),
              error: (_, __) => const Align(
                alignment: Alignment.topCenter,
                child: _RecentEmpty(
                  message: 'Could not load recent timesheets',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentEmpty extends StatelessWidget {
  const _RecentEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _DashedRRectPainter(
        color: _FmHomeTheme.cardBorder,
        radius: 10,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: _FmHomeTheme.emptyPlot,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _FmHomeTheme.mutedGray,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _HomeStatCard extends StatelessWidget {
  const _HomeStatCard({
    required this.value,
    required this.label,
    required this.icon,
    this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_FmHomeTheme.cardRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: _FmHomeTheme.card,
            borderRadius: BorderRadius.circular(_FmHomeTheme.cardRadius),
            border: Border.all(color: _FmHomeTheme.cardBorder),
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 118),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _FmHomeTheme.iconBadge,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _FmHomeTheme.cardBorder),
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: _FmHomeTheme.orange,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  value,
                  style: const TextStyle(
                    color: _FmHomeTheme.orange,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _FmHomeTheme.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _YourTeamBox extends StatelessWidget {
  const _YourTeamBox({
    required this.laborCount,
    required this.labors,
    required this.onTap,
  });

  final int laborCount;
  final List<TimesheetTeamMember> labors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = labors.take(5).toList();
    final labels = preview
        .map((m) => m.name.trim().isEmpty ? '?' : m.name.trim())
        .toList();
    final images = preview.map((m) => m.imageUrl).toList();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_FmHomeTheme.cardRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: _FmHomeTheme.card,
            borderRadius: BorderRadius.circular(_FmHomeTheme.cardRadius),
            border: Border.all(color: _FmHomeTheme.cardBorder),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _FmHomeTheme.iconBadge,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _FmHomeTheme.cardBorder),
                ),
                child: Icon(
                  PhosphorIcons.usersThree(),
                  size: 26,
                  color: _FmHomeTheme.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Team',
                      style: TextStyle(
                        color: _FmHomeTheme.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$laborCount labors',
                      style: const TextStyle(
                        color: _FmHomeTheme.orange,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (preview.isNotEmpty)
                TmAvatarStack(
                  labels: labels,
                  imageUrls: images,
                  maxVisible: 5,
                  size: 36,
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _FmHomeTheme.mutedSlate,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
