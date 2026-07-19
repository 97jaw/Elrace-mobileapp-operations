import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_team_member.dart';
import 'package:el_race/core/timesheet/providers/timesheet_enrollment_status_provider.dart';
import 'package:el_race/ui/presentation/timesheet/models/timesheet_capture_session_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Colors aligned with Add-timesheet camera status chrome.
abstract final class _TmLaborActionColors {
  static const ok = Color(0xFF3DDC84);
  static const warn = Color(0xFFFFB74D);
  static const idle = Color(0xFFB0BEC5);
}

/// Signature for opening the camera to capture one labor's attendance.
/// Returns the captured session entries (empty if none captured).
typedef TmCaptureAttendance = Future<List<TimesheetCaptureSessionEntry>>
    Function(TimesheetTeamMember member);

/// Signature to run the confirm + submit flow for accumulated captures.
/// Returns `true` when submission succeeded.
typedef TmSubmitCaptures = Future<bool> Function(
  List<TimesheetCaptureSessionEntry> captures,
);

/// Signature to open the enroll flow for one labor. Awaited so the tile can
/// show a spinner while enrollment is in progress.
typedef TmEnrollMember = Future<void> Function(TimesheetTeamMember member);

abstract final class TmTeamMembersSheet {
  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<TimesheetTeamMember> members,
    Map<int, bool>? enrollmentByEmployeeId,
    bool watchForemanEnrollment = false,
    List<TimesheetCaptureSessionEntry> initialCaptures = const [],
    TmEnrollMember? onEnroll,
    TmCaptureAttendance? onCaptureAttendance,
    ValueChanged<List<TimesheetCaptureSessionEntry>>? onPendingChanged,
    TmSubmitCaptures? onSubmitCaptures,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TmTeamMembersSheetBody(
        title: title,
        members: members,
        enrollmentByEmployeeId: enrollmentByEmployeeId ?? const {},
        watchForemanEnrollment: watchForemanEnrollment,
        initialCaptures: initialCaptures,
        onEnroll: onEnroll,
        onCaptureAttendance: onCaptureAttendance,
        onPendingChanged: onPendingChanged,
        onSubmitCaptures: onSubmitCaptures,
      ),
    );
  }
}

class _TmTeamMembersSheetBody extends ConsumerStatefulWidget {
  const _TmTeamMembersSheetBody({
    required this.title,
    required this.members,
    required this.enrollmentByEmployeeId,
    required this.watchForemanEnrollment,
    required this.initialCaptures,
    this.onEnroll,
    this.onCaptureAttendance,
    this.onPendingChanged,
    this.onSubmitCaptures,
  });

  final String title;
  final List<TimesheetTeamMember> members;
  final Map<int, bool> enrollmentByEmployeeId;
  final bool watchForemanEnrollment;
  final List<TimesheetCaptureSessionEntry> initialCaptures;
  final TmEnrollMember? onEnroll;
  final TmCaptureAttendance? onCaptureAttendance;
  final ValueChanged<List<TimesheetCaptureSessionEntry>>? onPendingChanged;
  final TmSubmitCaptures? onSubmitCaptures;

  @override
  ConsumerState<_TmTeamMembersSheetBody> createState() =>
      _TmTeamMembersSheetBodyState();
}

class _TmTeamMembersSheetBodyState
    extends ConsumerState<_TmTeamMembersSheetBody> {
  late final List<TimesheetCaptureSessionEntry> _pending =
      List<TimesheetCaptureSessionEntry>.from(widget.initialCaptures);
  bool _busy = false;

  /// Employee ids whose enroll flow is currently running (shows a spinner).
  final Set<int> _enrolling = <int>{};

  Future<void> _handleEnroll(
    TimesheetTeamMember member,
    bool alreadyEnrolled,
  ) async {
    final handler = widget.onEnroll;
    if (handler == null || _enrolling.contains(member.employeeId)) return;

    if (alreadyEnrolled) {
      final replace = await _confirmReplaceEnrollment(member);
      if (replace != true || !mounted) return;
    }

    setState(() => _enrolling.add(member.employeeId));
    try {
      await handler(member);
    } finally {
      if (mounted) {
        setState(() => _enrolling.remove(member.employeeId));
      }
    }
  }

  Future<bool?> _confirmReplaceEnrollment(TimesheetTeamMember member) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: TimesheetModuleColors.warmGradientStart,
        title: Text(
          'Already enrolled',
          style: TimesheetModuleTypography.cardTitle().copyWith(
            color: TimesheetModuleColors.ink,
          ),
        ),
        content: Text(
          '${member.name} is already enrolled. Do you want to replace the '
          'existing face enrollment?',
          style: TimesheetModuleTypography.body().copyWith(
            color: TimesheetModuleColors.warmMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: TimesheetModuleColors.warmMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Replace',
              style: TextStyle(
                color: TimesheetModuleColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _showActions =>
      widget.onEnroll != null || widget.onCaptureAttendance != null;

  Set<int> get _pendingIds => _pending.map((e) => e.employeeId).toSet();

  void _notifyPending() =>
      widget.onPendingChanged?.call(List.of(_pending));

  Future<void> _capture(TimesheetTeamMember member) async {
    final handler = widget.onCaptureAttendance;
    if (handler == null || _busy) return;
    final entries = await handler(member);
    if (!mounted || entries.isEmpty) return;
    setState(() {
      final existing = _pendingIds;
      for (final entry in entries) {
        if (!existing.contains(entry.employeeId)) {
          _pending.add(entry);
        }
      }
    });
    _notifyPending();
  }

  /// Runs confirm + submit for the accumulated captures.
  /// Returns true when submitted (and pending cleared).
  Future<bool> _submitPending() async {
    final handler = widget.onSubmitCaptures;
    if (handler == null || _pending.isEmpty || _busy) return false;
    setState(() => _busy = true);
    try {
      final ok = await handler(List.unmodifiable(_pending));
      if (ok && mounted) {
        setState(() => _pending.clear());
        _notifyPending();
      }
      return ok;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onSubmitButtonPressed() async {
    final navigator = Navigator.of(context);
    final ok = await _submitPending();
    if (!mounted) return;
    if (ok) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final liveEnrollment = widget.watchForemanEnrollment
        ? ref.watch(timesheetForemanEnrollmentMapProvider).maybeWhen(
              data: (value) => value,
              orElse: () => null,
            )
        : null;
    final enrollment = liveEnrollment ?? widget.enrollmentByEmployeeId;
    final pendingCount = _pending.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
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
                    color: TimesheetModuleColors.ink.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                if (pendingCount > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _SubmitCounterButton(
                      count: pendingCount,
                      busy: _busy,
                      onPressed: _onSubmitButtonPressed,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: TimesheetModuleTypography.h2().copyWith(
                            color: TimesheetModuleColors.ink,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(
                          PhosphorIcons.x(),
                          color: TimesheetModuleColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: widget.members.isEmpty
                      ? Center(
                          child: Text(
                            'No records',
                            style: TimesheetModuleTypography.body().copyWith(
                              color: TimesheetModuleColors.warmMuted,
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: widget.members.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final member = widget.members[index];
                            final enrolled =
                                enrollment[member.employeeId] == true;
                            final captured =
                                _pendingIds.contains(member.employeeId);
                            final enrolling =
                                _enrolling.contains(member.employeeId);
                            return _MemberTile(
                              member: member,
                              isEnrolled: enrolled,
                              isCaptured: captured,
                              isEnrolling: enrolling,
                              showActions: _showActions,
                              onEnroll: widget.onEnroll == null || enrolling
                                  ? null
                                  : () => _handleEnroll(member, enrolled),
                              onSubmit: widget.onCaptureAttendance == null ||
                                      !enrolled ||
                                      captured ||
                                      enrolling
                                  ? null
                                  : () => _capture(member),
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

class _SubmitCounterButton extends StatelessWidget {
  const _SubmitCounterButton({
    required this.count,
    required this.busy,
    required this.onPressed,
  });

  final int count;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: busy ? null : onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: TimesheetModuleColors.warmButtonGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: TimesheetModuleShadows.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$count',
                  style: TimesheetModuleTypography.cardTitle().copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  busy ? 'Submitting…' : 'Submit timesheet',
                  style: TimesheetModuleTypography.cardTitle().copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.2,
                  ),
                )
              else
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

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isEnrolled,
    required this.isCaptured,
    required this.isEnrolling,
    required this.showActions,
    this.onEnroll,
    this.onSubmit,
  });

  final TimesheetTeamMember member;
  final bool isEnrolled;
  final bool isCaptured;
  final bool isEnrolling;
  final bool showActions;
  final VoidCallback? onEnroll;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final url = member.imageUrl?.trim() ?? '';
    final initial = member.name.trim().isEmpty
        ? '?'
        : member.name.trim().characters.first.toUpperCase();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TimesheetModuleColors.glassSurface,
        borderRadius:
            BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
        border: Border.all(
          color: isCaptured
              ? _TmLaborActionColors.ok.withValues(alpha: 0.6)
              : TimesheetModuleColors.glassBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: TimesheetModuleColors.iconSurface),
              color: TimesheetModuleColors.accentTint,
            ),
            clipBehavior: Clip.antiAlias,
            child: url.isNotEmpty
                ? Image.network(url, fit: BoxFit.cover)
                : Center(
                    child: Text(
                      initial,
                      style: TimesheetModuleTypography.h2().copyWith(
                        color: TimesheetModuleColors.accent,
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
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TimesheetModuleTypography.cardTitle().copyWith(
                    color: TimesheetModuleColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'File ID: ${member.fileId}',
                  style: TimesheetModuleTypography.caption().copyWith(
                    color: TimesheetModuleColors.warmMuted,
                  ),
                ),
                if (member.subtitle != null && member.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    member.subtitle!,
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
          if (showActions) ...[
            const SizedBox(width: 4),
            if (isEnrolling)
              const SizedBox(
                width: 36,
                height: 36,
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: _TmLaborActionColors.ok,
                  ),
                ),
              )
            else
              _ActionIcon(
                tooltip: isCaptured
                    ? 'Captured'
                    : isEnrolled
                        ? 'Enrolled'
                        : 'Not enrolled',
                icon: isCaptured || isEnrolled
                    ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                    : PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
                color: isCaptured || isEnrolled
                    ? _TmLaborActionColors.ok
                    : _TmLaborActionColors.warn,
              ),
            _ActionIcon(
              tooltip: 'Enroll face',
              icon: PhosphorIcons.userFocus(),
              color: TimesheetModuleColors.ink,
              onTap: onEnroll,
            ),
            _ActionIcon(
              tooltip: isCaptured
                  ? 'Already captured'
                  : isEnrolled
                      ? 'Capture attendance'
                      : 'Enroll before submitting',
              icon: PhosphorIcons.paperPlaneTilt(),
              color: onSubmit != null
                  ? _TmLaborActionColors.ok
                  : _TmLaborActionColors.idle,
              onTap: onSubmit,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.tooltip,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 22),
    );
  }
}
