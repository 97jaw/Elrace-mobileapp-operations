import 'dart:async';

import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_fast_network_image.dart';
import 'package:flutter/material.dart';

enum TmFaceCaptureNoticeKind {
  captured,
  alreadyAttended,

  /// Recognised someone other than the labor the camera was opened for.
  mismatch,
}

/// Bottom notice — green (captured), blue (already attended) or red (wrong
/// person for this camera).
class TmFaceCaptureNoticeTile extends StatefulWidget {
  const TmFaceCaptureNoticeTile({
    super.key,
    required this.employee,
    required this.kind,
    this.matchScore,
    this.expectedName,
    this.autoDismissSeconds = 3,
    this.onDismissed,
    this.actionLabel,
    this.onAction,
  });

  final TimesheetOdooEmployee employee;
  final TmFaceCaptureNoticeKind kind;
  final double? matchScore;

  /// [TmFaceCaptureNoticeKind.mismatch]: who the camera was opened for.
  final String? expectedName;
  final int autoDismissSeconds;
  final VoidCallback? onDismissed;

  /// When set, the card stays until this button is tapped (no auto dismiss).
  final String? actionLabel;
  final VoidCallback? onAction;

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

  late final AnimationController _slide;
  Timer? _timer;

  Color get _accent => switch (widget.kind) {
        TmFaceCaptureNoticeKind.captured => _green,
        TmFaceCaptureNoticeKind.alreadyAttended => _blue,
        TmFaceCaptureNoticeKind.mismatch => _red,
      };

  String? get _headline {
    switch (widget.kind) {
      case TmFaceCaptureNoticeKind.captured:
        return null;
      case TmFaceCaptureNoticeKind.alreadyAttended:
        return 'ALREADY ATTENDED';
      case TmFaceCaptureNoticeKind.mismatch:
        return 'WRONG PERSON';
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
    final headline = _headline;
    final expected = widget.expectedName?.trim();
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
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: widget.onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    textStyle: TimesheetModuleTypography.body().copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  icon: Icon(
                    isMismatch ? Icons.refresh_rounded : Icons.arrow_forward,
                  ),
                  label: Text(widget.actionLabel!),
                ),
              ),
              const SizedBox(height: 10),
            ],
            IgnorePointer(
                child: _card(
              imageUrl: imageUrl,
              hasHrPhoto: hasHrPhoto,
              isCaptured: isCaptured,
              isMismatch: isMismatch,
              headline: headline,
              expected: expected,
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
    required bool isMismatch,
    required String? headline,
    required String? expected,
    required String? pct,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isMismatch
            ? const Color(0xFF3B0A0A).withValues(alpha: 0.82)
            : Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent, width: isMismatch ? 3 : 2.5),
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
                        if (isMismatch) ...[
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
                  if (isMismatch) ...[
                    const SizedBox(height: 6),
                    Text(
                      expected == null || expected.isEmpty
                          ? 'Not the selected labor — not added'
                          : 'Expected $expected — not added',
                      maxLines: 2,
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
