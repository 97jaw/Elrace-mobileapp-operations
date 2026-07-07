import 'dart:async';

import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_fast_network_image.dart';
import 'package:flutter/material.dart';

enum TmFaceCaptureNoticeKind {
  captured,
  alreadyAttended,
}

/// Bottom notice — green (captured) or blue (already attended).
class TmFaceCaptureNoticeTile extends StatefulWidget {
  const TmFaceCaptureNoticeTile({
    super.key,
    required this.employee,
    required this.kind,
    this.matchScore,
    this.autoDismissSeconds = 3,
    this.onDismissed,
  });

  final TimesheetOdooEmployee employee;
  final TmFaceCaptureNoticeKind kind;
  final double? matchScore;
  final int autoDismissSeconds;
  final VoidCallback? onDismissed;

  @override
  State<TmFaceCaptureNoticeTile> createState() => _TmFaceCaptureNoticeTileState();
}

class _TmFaceCaptureNoticeTileState extends State<TmFaceCaptureNoticeTile>
    with SingleTickerProviderStateMixin {
  static const Color _green = Color(0xFF3DDC84);
  static const Color _blue = Color(0xFF42A5F5);

  late final AnimationController _slide;
  Timer? _timer;

  Color get _accent =>
      widget.kind == TmFaceCaptureNoticeKind.alreadyAttended ? _blue : _green;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..forward();
    _timer = Timer(Duration(seconds: widget.autoDismissSeconds), _dismiss);
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
    final isAttended = widget.kind == TmFaceCaptureNoticeKind.alreadyAttended;
    final score = widget.matchScore;
    final pct = score != null
        ? (score * 100).clamp(0, 100).toStringAsFixed(0)
        : null;

    return IgnorePointer(
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.2, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic),
        ),
        child: FadeTransition(
          opacity: _slide,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _accent, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: hasHrPhoto
                          ? TmFastNetworkImage(
                              url: imageUrl,
                              width: 52,
                              height: 52,
                              memCacheWidth: 104,
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
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isAttended)
                          Text(
                            'ALREADY ATTENDED',
                            style: TimesheetModuleTypography.caption().copyWith(
                              color: _blue,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        if (isAttended) const SizedBox(height: 4),
                        Text(
                          widget.employee.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TimesheetModuleTypography.cardTitle().copyWith(
                            color: TimesheetModuleColors.surface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'File ID: ${widget.employee.displayFileId}',
                          style: TimesheetModuleTypography.caption().copyWith(
                            color: TimesheetModuleColors.surface
                                .withValues(alpha: 0.9),
                          ),
                        ),
                        if ((widget.employee.jobPosition ?? '').isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.employee.jobPosition!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TimesheetModuleTypography.caption().copyWith(
                              color: TimesheetModuleColors.surface
                                  .withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                        if (!isAttended && pct != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Confidence $pct%',
                            style: TimesheetModuleTypography.caption().copyWith(
                              color: _green,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
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
