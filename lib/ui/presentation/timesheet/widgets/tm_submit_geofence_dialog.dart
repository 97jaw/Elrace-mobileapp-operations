import 'dart:async';

import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_submit_request.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Default site threshold (m) when Odoo `x_threshold` is missing — used by
/// camera project resolution ([TmForemanSiteLocation]), not by submit.
const double kTmDefaultSubmitThresholdM = 50;

/// Confirm & submit result popup (same visual language as the old geofence
/// dialog). Location is enforced when opening the camera, not at submit —
/// this dialog only runs the submit and shows success / server messages.
abstract final class TmTimesheetSubmitDialog {
  /// Resolves true only when the timesheet was actually created.
  static Future<bool> run(
    BuildContext context, {
    required Future<TimesheetSubmitResult> Function() submit,
    String? projectName,
  }) async {
    final ok = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Submission',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => _TmTimesheetSubmitDialog(
        submit: submit,
        projectName: projectName,
      ),
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
    return ok ?? false;
  }
}

enum _Stage { submitting, success, failed }

class _TmTimesheetSubmitDialog extends StatefulWidget {
  const _TmTimesheetSubmitDialog({
    required this.submit,
    this.projectName,
  });

  final Future<TimesheetSubmitResult> Function() submit;
  final String? projectName;

  @override
  State<_TmTimesheetSubmitDialog> createState() =>
      _TmTimesheetSubmitDialogState();
}

class _TmTimesheetSubmitDialogState extends State<_TmTimesheetSubmitDialog> {
  static const _green = Color(0xFF2E9E5B);

  _Stage _stage = _Stage.submitting;
  String? _serverMessage;
  Timer? _autoClose;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    TimesheetSubmitResult result;
    try {
      result = await widget.submit();
    } catch (e) {
      result = TimesheetSubmitResult(success: false, message: '$e');
    }
    if (!mounted) return;
    setState(() {
      _serverMessage = result.message;
      _stage = result.success ? _Stage.success : _Stage.failed;
    });
    if (result.success) {
      _autoClose = Timer(const Duration(milliseconds: 2200), _close);
    }
  }

  void _close() {
    if (!mounted) return;
    _autoClose?.cancel();
    Navigator.of(context).pop(_stage == _Stage.success);
  }

  bool get _busy => _stage == _Stage.submitting;
  bool get _failed => _stage == _Stage.failed;

  String get _title => switch (_stage) {
        _Stage.submitting => 'Submitting…',
        _Stage.success => 'Submission success',
        _Stage.failed => 'Submission failed',
      };

  String get _detail {
    final msg = _serverMessage?.trim();
    final project = widget.projectName?.trim();
    return switch (_stage) {
      _Stage.submitting => project != null && project.isNotEmpty
          ? 'Recording timesheet for $project'
          : 'Recording timesheet…',
      _Stage.success => msg != null && msg.isNotEmpty
          ? msg
          : project != null && project.isNotEmpty
              ? 'Timesheet recorded for $project'
              : 'Timesheet recorded',
      _Stage.failed =>
        msg != null && msg.isNotEmpty ? msg : 'The server rejected the submission.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final accent = _failed
        ? TimesheetModuleColors.danger
        : _stage == _Stage.success
            ? _green
            : TimesheetModuleColors.accent;
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: width > 560 ? 440 : width - 32),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  gradient: TimesheetModuleColors.warmGradient,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _header(accent),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _close,
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              _failed ? TimesheetModuleColors.ink : _green,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _busy
                              ? 'Please wait…'
                              : _failed
                                  ? 'Close'
                                  : 'Done',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(Color accent) {
    final icon = _busy
        ? SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.6, color: accent),
          )
        : Icon(
            _failed
                ? PhosphorIcons.xCircle(PhosphorIconsStyle.fill)
                : PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
            color: accent,
            size: 30,
          );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: icon,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _title,
                style: TimesheetModuleTypography.h2().copyWith(
                  color: _failed
                      ? TimesheetModuleColors.danger
                      : TimesheetModuleColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _detail,
                style: TimesheetModuleTypography.caption().copyWith(
                  color: TimesheetModuleColors.warmMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
