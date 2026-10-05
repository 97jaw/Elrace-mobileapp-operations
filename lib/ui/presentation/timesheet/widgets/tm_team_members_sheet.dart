import 'dart:async';

import 'package:el_race/core/site_management/face_recognition/profile_photo_face_db.dart';
import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_team_member.dart';
import 'package:el_race/core/timesheet/providers/timesheet_enrollment_status_provider.dart';
import 'package:el_race/core/widgets/timesheet/tm_search_field.dart';
import 'package:el_race/ui/presentation/timesheet/models/timesheet_capture_session_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Colors aligned with Add-timesheet camera status chrome.
abstract final class _TmLaborActionColors {
  static const ok = Color(0xFF3DDC84);
  static const warn = Color(0xFFFFB74D);
}

/// Signature for opening the camera to capture one labor's attendance.
/// Returns the captured session entries (empty if none captured).
typedef TmCaptureAttendance = Future<List<TimesheetCaptureSessionEntry>>
    Function(TimesheetTeamMember member, Set<int> alreadyCapturedIds);

/// Signature to run the confirm + submit flow for accumulated captures.
/// Returns `true` when submission succeeded.
typedef TmSubmitCaptures = Future<bool> Function(
  List<TimesheetCaptureSessionEntry> captures,
);

/// Signature to open the enroll flow for one labor. Awaited so the tile can
/// show a spinner while enrollment is in progress.
typedef TmEnrollMember = Future<void> Function(TimesheetTeamMember member);

/// Signature to fetch the latest team from the server (bypassing caches).
typedef TmReloadMembers = Future<List<TimesheetTeamMember>> Function();

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
    TmReloadMembers? onReload,
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
        onReload: onReload,
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
    this.onReload,
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
  final TmReloadMembers? onReload;

  @override
  ConsumerState<_TmTeamMembersSheetBody> createState() =>
      _TmTeamMembersSheetBodyState();
}

class _TmTeamMembersSheetBodyState
    extends ConsumerState<_TmTeamMembersSheetBody> {
  late final List<TimesheetCaptureSessionEntry> _pending =
      List<TimesheetCaptureSessionEntry>.from(widget.initialCaptures);
  bool _busy = false;
  late List<TimesheetTeamMember> _members = widget.members;
  bool _reloading = false;

  static const int _pageSize = 20;
  String _query = '';
  int _visibleCount = _pageSize;

  /// Employee ids whose enroll flow is currently running (shows a spinner).
  final Set<int> _enrolling = <int>{};

  bool get _gateOnProfileTemplates =>
      ProfilePhotoMatchTest.enabled && widget.onCaptureAttendance != null;

  @override
  void initState() {
    super.initState();
    if (_gateOnProfileTemplates) {
      ProfilePhotoFaceDb.instance.setTeam(widget.members);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _onFacePending(TimesheetTeamMember member) {
    ProfilePhotoFaceDb.instance.prioritize(member.employeeId);
    _showSnack('Preparing face for ${member.name}…');
  }

  void _onFaceFailed(TimesheetTeamMember member) {
    _showSnack(
      'No usable profile photo for ${member.name}. Ask HR to update it.',
    );
  }

  Future<void> _reload() async {
    final handler = widget.onReload;
    if (handler == null || _reloading) return;
    setState(() => _reloading = true);
    try {
      final members = await handler();
      if (!mounted) return;
      setState(() {
        _members = members;
        _visibleCount = _pageSize;
      });
      if (_gateOnProfileTemplates) {
        ProfilePhotoFaceDb.instance.setTeam(members);
        unawaited(ProfilePhotoFaceDb.instance.retryFailed());
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Team updated (${members.length})'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Could not reload the team. Check your connection.'),
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _reloading = false);
    }
  }

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

  List<TimesheetTeamMember> get _filteredMembers {
    final q = _query.toLowerCase();
    if (q.isEmpty) return _members;
    return _members.where((m) {
      return m.name.toLowerCase().contains(q) ||
          m.fileId.toLowerCase().contains(q) ||
          (m.subtitle?.toLowerCase().contains(q) ?? false);
    }).toList(growable: false);
  }

  void _onQueryChanged(String value) {
    setState(() {
      _query = value.trim();
      _visibleCount = _pageSize;
    });
  }

  bool _onListScroll(ScrollNotification notification, int total) {
    if (_visibleCount < total && notification.metrics.extentAfter < 300) {
      setState(() => _visibleCount += _pageSize);
    }
    return false;
  }

  Set<int> get _pendingIds => _pending.map((e) => e.employeeId).toSet();

  void _notifyPending() => widget.onPendingChanged?.call(List.of(_pending));

  Future<void> _capture(TimesheetTeamMember member) async {
    final handler = widget.onCaptureAttendance;
    if (handler == null || _busy) return;
    final entries = await handler(member, _pendingIds);
    if (!mounted || entries.isEmpty) return;
    final existing = _pendingIds;
    final duplicates = entries
        .where((e) => existing.contains(e.employeeId))
        .map((e) => e.employee.name)
        .toSet();
    setState(() {
      for (final entry in entries) {
        if (!existing.contains(entry.employeeId)) {
          _pending.add(entry);
        }
      }
    });
    _notifyPending();
    if (duplicates.isNotEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content:
              Text('${duplicates.join(', ')} already added — not added again'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
    if (!_gateOnProfileTemplates) return _buildSheet(enrollment, null);
    return ValueListenableBuilder<Map<int, ProfileTemplateState>>(
      valueListenable: ProfilePhotoFaceDb.instance.states,
      builder: (context, faceStates, _) => _buildSheet(enrollment, faceStates),
    );
  }

  Widget _buildSheet(
    Map<int, bool> enrollment,
    Map<int, ProfileTemplateState>? faceStates,
  ) {
    final pendingCount = _pending.length;
    ProfileTemplateState? faceStateOf(TimesheetTeamMember m) =>
        faceStates == null
            ? null
            : faceStates[m.employeeId] ?? ProfileTemplateState.pending;
    final facesDone = faceStates == null
        ? 0
        : _members
            .where((m) => faceStateOf(m) != ProfileTemplateState.pending)
            .length;
    final showFaceProgress = faceStates != null &&
        _members.isNotEmpty &&
        facesDone < _members.length;
    final filtered = _filteredMembers;
    final shownCount =
        filtered.length < _visibleCount ? filtered.length : _visibleCount;
    final hasMore = shownCount < filtered.length;

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
                    if (widget.onReload != null)
                      _ReloadButton(
                        loading: _reloading,
                        onPressed: _busy ? null : _reload,
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
              if (showFaceProgress)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: TimesheetModuleColors.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Preparing faces $facesDone/${_members.length}',
                        style: TimesheetModuleTypography.caption().copyWith(
                          color: TimesheetModuleColors.warmMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_members.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TmSearchField(
                    hintText: 'Search name or file ID',
                    onDebouncedChanged: _onQueryChanged,
                  ),
                ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          _members.isEmpty
                              ? 'No records'
                              : 'No match for "$_query"',
                          style: TimesheetModuleTypography.body().copyWith(
                            color: TimesheetModuleColors.warmMuted,
                          ),
                        ),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (n) =>
                            _onListScroll(n, filtered.length),
                        child: ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: shownCount + 1,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            if (index == shownCount) {
                              return _ListFooter(
                                shown: shownCount,
                                total: filtered.length,
                                hasMore: hasMore,
                                onShowMore: () => setState(
                                  () => _visibleCount += _pageSize,
                                ),
                              );
                            }
                            final member = filtered[index];
                            final enrolled =
                                enrollment[member.employeeId] == true;
                            final captured =
                                _pendingIds.contains(member.employeeId);
                            final enrolling =
                                _enrolling.contains(member.employeeId);
                            final faceState = faceStateOf(member);
                            return _MemberTile(
                              member: member,
                              isEnrolled: enrolled,
                              isCaptured: captured,
                              isEnrolling: enrolling,
                              showActions: _showActions,
                              faceState: faceState,
                              onEnroll: widget.onEnroll == null || enrolling
                                  ? null
                                  : () => _handleEnroll(member, enrolled),
                              onSubmit: widget.onCaptureAttendance == null ||
                                      captured ||
                                      enrolling
                                  ? null
                                  : switch (faceState) {
                                      ProfileTemplateState.pending => () =>
                                          _onFacePending(member),
                                      ProfileTemplateState.failed => () =>
                                          _onFaceFailed(member),
                                      _ => () => _capture(member),
                                    },
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({
    required this.shown,
    required this.total,
    required this.hasMore,
    required this.onShowMore,
  });

  final int shown;
  final int total;
  final bool hasMore;
  final VoidCallback onShowMore;

  @override
  Widget build(BuildContext context) {
    final caption = TimesheetModuleTypography.caption().copyWith(
      color: TimesheetModuleColors.warmMuted,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Text('Showing $shown of $total', style: caption),
          if (hasMore)
            TextButton(
              onPressed: onShowMore,
              child: const Text(
                'Show more',
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
    this.faceState,
    this.onEnroll,
    this.onSubmit,
  });

  final TimesheetTeamMember member;
  final bool isEnrolled;
  final bool isCaptured;
  final bool isEnrolling;
  final bool showActions;

  /// Profile-photo template status; null when capture isn't gated on it.
  final ProfileTemplateState? faceState;
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
        borderRadius: BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
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
            if (!ProfilePhotoMatchTest.enabled) ...[
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
            ],
            _CaptureButton(
              tooltip: isCaptured
                  ? 'Already captured'
                  : switch (faceState) {
                      ProfileTemplateState.pending => 'Preparing face…',
                      ProfileTemplateState.failed => 'No usable profile photo',
                      _ => isEnrolled || ProfilePhotoMatchTest.enabled
                          ? 'Capture attendance'
                          : 'Capture attendance (not enrolled yet)',
                    },
              captured: isCaptured,
              dimmed: !isCaptured &&
                  (onSubmit == null ||
                      faceState == ProfileTemplateState.pending ||
                      faceState == ProfileTemplateState.failed),
              noPhoto: !isCaptured && faceState == ProfileTemplateState.failed,
              onTap: isCaptured ? null : onSubmit,
            ),
          ],
        ],
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    required this.tooltip,
    required this.captured,
    required this.dimmed,
    required this.noPhoto,
    this.onTap,
  });

  final String tooltip;
  final bool captured;

  /// Dimmed icons may still be tappable (e.g. to prioritize a pending face).
  final bool dimmed;
  final bool noPhoto;
  final VoidCallback? onTap;

  static const double _iconSize = 30;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: SizedBox(
              width: _iconSize,
              height: _iconSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Opacity(
                    opacity: dimmed ? 0.4 : 1,
                    child: Image.asset(
                      'assets/png/capture_attendance.png',
                      width: _iconSize,
                      height: _iconSize,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  if (captured)
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _TmLaborActionColors.ok,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 9,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (noPhoto)
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _TmLaborActionColors.warn,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.priority_high_rounded,
                          size: 9,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReloadButton extends StatelessWidget {
  const _ReloadButton({required this.loading, this.onPressed});

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Material(
        color: TimesheetModuleColors.accentTint,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: loading ? null : onPressed,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: TimesheetModuleColors.accent,
                      ),
                    )
                  : Icon(
                      PhosphorIcons.arrowClockwise(PhosphorIconsStyle.bold),
                      color: TimesheetModuleColors.accent,
                      size: 18,
                      semanticLabel: 'Reload team',
                    ),
            ),
          ),
        ),
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
