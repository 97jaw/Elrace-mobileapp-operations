import 'dart:async';

import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_fast_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// U.2 — Green confirm: in-team embedding match (Phase B pilot/production).
class TmFaceMatchConfirmCard extends StatefulWidget {
  const TmFaceMatchConfirmCard({
    super.key,
    required this.employee,
    required this.matchScore,
    required this.onConfirm,
    required this.onNotCorrect,
    this.autoContinueSeconds = 5,
    this.closeSecondCandidate = false,
    this.secondBestScore,
  });

  final TimesheetOdooEmployee employee;
  final double matchScore;
  final VoidCallback onConfirm;
  final VoidCallback onNotCorrect;
  final int autoContinueSeconds;
  final bool closeSecondCandidate;
  final double? secondBestScore;

  @override
  State<TmFaceMatchConfirmCard> createState() => _TmFaceMatchConfirmCardState();
}

class _TmFaceMatchConfirmCardState extends State<TmFaceMatchConfirmCard>
    with SingleTickerProviderStateMixin {
  static const Color _green = Color(0xFF2E7D52);
  static const Color _greenLight = Color(0xFFE8F5EE);
  static const Color _greenAccent = Color(0xFF3DDC84);

  late final AnimationController _slide;
  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.autoContinueSeconds;
    _slide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    unawaited(SystemSound.play(SystemSoundType.click));
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        widget.onConfirm();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = (widget.matchScore * 100).clamp(0, 100).toStringAsFixed(0);
    final imageUrl = widget.employee.imageUrl;

    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic)),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: TimesheetModuleColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _greenAccent, width: 2),
                  boxShadow: TimesheetModuleShadows.cardShadow,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _greenLight,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                              color: _green,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'In your team',
                                  style: TimesheetModuleTypography.caption()
                                      .copyWith(color: _green, fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  'Face match confirmed',
                                  style: TimesheetModuleTypography.h2(),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: widget.onNotCorrect,
                            icon: Icon(PhosphorIcons.x(), color: TimesheetModuleColors.mutedText),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: _greenLight,
                        child: imageUrl != null
                            ? ClipOval(
                                child: TmFastNetworkImage(
                                  url: imageUrl,
                                  width: 96,
                                  height: 96,
                                  memCacheWidth: 192,
                                ),
                              )
                            : Text(
                                widget.employee.name.isNotEmpty
                                    ? widget.employee.name[0]
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: _green,
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.employee.name,
                        textAlign: TextAlign.center,
                        style: TimesheetModuleTypography.h2(),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'File ID: ${widget.employee.displayFileId}',
                        style: TimesheetModuleTypography.caption(),
                      ),
                      if ((widget.employee.jobPosition ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.employee.jobPosition!,
                          style: TimesheetModuleTypography.caption(),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _greenLight,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Confidence $pct%',
                          style: TimesheetModuleTypography.body().copyWith(
                            color: _green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (widget.closeSecondCandidate) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Another labor is nearly as close'
                          '${widget.secondBestScore != null ? " (${(widget.secondBestScore! * 100).toStringAsFixed(0)}%)" : ""}. '
                          'Confirm identity before submit.',
                          textAlign: TextAlign.center,
                          style: TimesheetModuleTypography.caption().copyWith(
                            color: const Color(0xFFB8860B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Employee field updated. Review times, then submit.',
                        textAlign: TextAlign.center,
                        style: TimesheetModuleTypography.caption(),
                      ),
                      const SizedBox(height: 12),
                      TmPrimaryButton(
                        label: 'Confirm ($_secondsLeft s)',
                        icon: PhosphorIcons.check(),
                        onPressed: widget.onConfirm,
                      ),
                      const SizedBox(height: 8),
                      TmSecondaryButton(
                        label: 'Not correct — pick manually',
                        onPressed: widget.onNotCorrect,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
