import 'dart:async';

import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_fast_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// After face match — card, 5s countdown, Next → back to camera.
class TmFaceMatchConfirmOverlay extends StatefulWidget {
  const TmFaceMatchConfirmOverlay({
    super.key,
    required this.employee,
    required this.onNext,
    required this.onDismiss,
  });

  final TimesheetOdooEmployee employee;
  final VoidCallback onNext;
  final VoidCallback onDismiss;

  @override
  State<TmFaceMatchConfirmOverlay> createState() =>
      _TmFaceMatchConfirmOverlayState();
}

class _TmFaceMatchConfirmOverlayState extends State<TmFaceMatchConfirmOverlay>
    with SingleTickerProviderStateMixin {
  static const int _countdownStart = 5;

  late final AnimationController _slide;
  int _secondsLeft = _countdownStart;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    unawaited(SystemSound.play(SystemSoundType.click));
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        widget.onNext();
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
    final imageUrl = widget.employee.imageUrl;

    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic)),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      TimesheetModuleColors.navy,
                      TimesheetModuleColors.primaryGradientEnd,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: TimesheetModuleShadows.cardShadow,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            PhosphorIcons.checkCircle(),
                            color: const Color(0xFF3DDC84),
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Employee recognized',
                              style: TimesheetModuleTypography.h2().copyWith(
                                color: TimesheetModuleColors.surface,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: widget.onDismiss,
                            icon: Icon(
                              PhosphorIcons.x(),
                              color: TimesheetModuleColors.surface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      CircleAvatar(
                        radius: 48,
                        backgroundColor:
                            TimesheetModuleColors.surface.withValues(alpha: 0.2),
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
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: TimesheetModuleColors.surface,
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.employee.name,
                        textAlign: TextAlign.center,
                        style: TimesheetModuleTypography.h2().copyWith(
                          color: TimesheetModuleColors.surface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'File ID: ${widget.employee.displayFileId}',
                        style: TimesheetModuleTypography.caption().copyWith(
                          color: TimesheetModuleColors.surface
                              .withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: TimesheetModuleColors.surface
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Auto-continue in $_secondsLeft s',
                          style: TimesheetModuleTypography.body().copyWith(
                            color: TimesheetModuleColors.surface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TmPrimaryButton(
                        label: 'Next — capture another',
                        icon: PhosphorIcons.arrowRight(),
                        onPressed: widget.onNext,
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
