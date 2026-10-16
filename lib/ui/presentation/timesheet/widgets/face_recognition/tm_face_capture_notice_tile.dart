import 'dart:async';

import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_fast_network_image.dart';
import 'package:flutter/material.dart';

enum TmFaceCaptureNoticeKind {
  captured,
  alreadyAttended,

  /// The face did not verify as the target labor ([employee] is the target).
  mismatch,

  /// The target labor has no usable profile photo template.
  photoUnavailable,
}

class TmFaceNoticeAction {
  const TmFaceNoticeAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

/// Bottom notice — green (captured), blue (already attended), red (doesn't
/// match the target) or amber (target's photo unavailable). Always shows the
/// target labor, never another employee.
class TmFaceCaptureNoticeTile extends StatefulWidget {
  const TmFaceCaptureNoticeTile({
    super.key,
    required this.employee,
    required this.kind,
    this.matchScore,
    this.autoDismissSeconds = 3,
    this.onDismissed,
    this.actionLabel,
    this.onAction,
    this.secondaryActions = const [],
  });

  final TimesheetOdooEmployee employee;
  final TmFaceCaptureNoticeKind kind;
  final double? matchScore;
  final int autoDismissSeconds;
  final VoidCallback? onDismissed;

  /// When set, the card stays until this button is tapped (no auto dismiss).
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Extra outlined buttons, shown before [actionLabel].
  final List<TmFaceNoticeAction> secondaryActions;

  bool get _hasAction => actionLabel != null && onAction != null;

  @override
  State<TmFaceCaptureNoticeTile> createState() =>
      _TmFaceCaptureNoticeTileState();
}

class _TmFaceCaptureNoticeTileState extends State<TmFaceCaptureNoticeTile>
    with SingleTickerProviderStateMixin {
  static const Color _green = Color(0xFF3DDC84);
  static const Color _blue = Color(0xFF42A5F5);
  static const Color _red = Color(0xFFE53935);
  static const Color _amber = Color(0xFFFFB300);

  late final AnimationController _slide;
  Timer? _timer;

  Color get _accent => switch (widget.kind) {
        TmFaceCaptureNoticeKind.captured => _green,
        TmFaceCaptureNoticeKind.alreadyAttended => _blue,
        TmFaceCaptureNoticeKind.mismatch => _red,
        TmFaceCaptureNoticeKind.photoUnavailable => _amber,
      };

  String? get _headline {
    switch (widget.kind) {
      case TmFaceCaptureNoticeKind.captured:
        return null;
      case TmFaceCaptureNoticeKind.alreadyAttended:
        return 'ALREADY ATTENDED';
      case TmFaceCaptureNoticeKind.mismatch:
        return 'NOT VERIFIED';
      case TmFaceCaptureNoticeKind.photoUnavailable:
        return 'NO FACE PHOTO';
    }
  }

  /// Red / amber line under the name; null for green and blue.
  String? get _detail {
    final name = widget.employee.name;
    switch (widget.kind) {
      case TmFaceCaptureNoticeKind.mismatch:
        return "Doesn't match $name — not added";
      case TmFaceCaptureNoticeKind.photoUnavailable:
        return "$name's photo isn't available for face match. "
            'Ask HR to add a profile photo.';
      case TmFaceCaptureNoticeKind.captured:
      case TmFaceCaptureNoticeKind.alreadyAttended:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..forward();
    if (!widget._hasAction) {
      _timer = Timer(Duration(seconds: widget.autoDismissSeconds), _dismiss);
    }
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _slide.reverse();
    if (mounted) widget.onDismissed?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.employee.faceMatchImageUrl?.trim() ??
        widget.employee.imageUrl?.trim();
    final hasHrPhoto = imageUrl != null && imageUrl.isNotEmpty;
    final isCaptured = widget.kind == TmFaceCaptureNoticeKind.captured;
    final isMismatch = widget.kind == TmFaceCaptureNoticeKind.mismatch;
    final isWarning =
        isMismatch || widget.kind == TmFaceCaptureNoticeKind.photoUnavailable;
    final headline = _headline;
    final score = widget.matchScore;
    final pct =
        score != null ? (score * 100).clamp(0, 100).toStringAsFixed(0) : null;

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.2, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic),
      ),
      child: FadeTransition(
        opacity: _slide,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget._hasAction) ...[
              if (widget.secondaryActions.isNotEmpty) ...[
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    for (final extra in widget.secondaryActions)
                      OutlinedButton(
                        onPressed: extra.onPressed,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.55),
                          foregroundColor: Colors.white,
                          side: BorderSide(color: _accent, width: 2),
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          textStyle: TimesheetModuleTypography.body().copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        child: Text(extra.label),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              // Main action spans the card width.
              FilledButton.icon(
                onPressed: widget.onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  textStyle: TimesheetModuleTypography.body().copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                icon: Icon(
                  isWarning ? Icons.refresh_rounded : Icons.arrow_forward,
                ),
                label: Text(widget.actionLabel!),
              ),
              const SizedBox(height: 10),
            ],
            IgnorePointer(
                child: _card(
              imageUrl: imageUrl,
              hasHrPhoto: hasHrPhoto,
              isCaptured: isCaptured,
              isWarning: isWarning,
              headline: headline,
              detail: _detail,
              pct: pct,
            )),
          ],
        ),
      ),
    );
  }

  Widget _card({
    required String? imageUrl,
    required bool hasHrPhoto,
    required bool isCaptured,
    required bool isWarning,
    required String? headline,
    required String? detail,
    required String? pct,
  }) {
    final isMismatch = widget.kind == TmFaceCaptureNoticeKind.mismatch;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isMismatch
            ? const Color(0xFF3B0A0A).withValues(alpha: 0.82)
            : Colors.black.withValues(alpha: isWarning ? 0.7 : 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent, width: isWarning ? 3 : 2.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 84,
                height: 84,
                child: hasHrPhoto
                    ? TmFastNetworkImage(
                        url: imageUrl!,
                        width: 84,
                        height: 84,
                        memCacheWidth: 168,
                      )
                    : ColoredBox(
                        color: _accent.withValues(alpha: 0.15),
                        child: Center(
                          child: Text(
                            widget.employee.name.isNotEmpty
                                ? widget.employee.name[0]
                                : '?',
                            style: TextStyle(
                              color: _accent,
                              fontWeight: FontWeight.w800,
                              fontSize: 34,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (headline != null) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isWarning) ...[
                          Icon(
                            Icons.warning_amber_rounded,
                            color: _accent,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          headline,
                          style: TimesheetModuleTypography.body().copyWith(
                            color: _accent,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    widget.employee.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TimesheetModuleTypography.h2().copyWith(
                      color: TimesheetModuleColors.surface,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'File ID: ${widget.employee.displayFileId}',
                    style: TimesheetModuleTypography.body().copyWith(
                      color:
                          TimesheetModuleColors.surface.withValues(alpha: 0.9),
                    ),
                  ),
                  if ((widget.employee.jobPosition ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.employee.jobPosition!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TimesheetModuleTypography.body().copyWith(
                        color: TimesheetModuleColors.surface
                            .withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                  if (detail != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      detail,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TimesheetModuleTypography.body().copyWith(
                        color: _accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  if (isCaptured && pct != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Confidence $pct%',
                      style: TimesheetModuleTypography.body().copyWith(
                        color: _green,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
