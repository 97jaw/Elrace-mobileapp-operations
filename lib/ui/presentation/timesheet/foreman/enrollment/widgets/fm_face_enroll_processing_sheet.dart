import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

enum FmFaceEnrollProcessStep {
  validating,
  uploading,
  submitted,
  syncing,
  done,
}

/// Full-screen blocking progress during enrollment upload + face DB refresh.
class FmFaceEnrollProcessingSheet extends StatelessWidget {
  const FmFaceEnrollProcessingSheet({
    super.key,
    required this.step,
    this.errorMessage,
  });

  final FmFaceEnrollProcessStep step;
  final String? errorMessage;

  String get _label => switch (step) {
        FmFaceEnrollProcessStep.validating => 'Checking face poses…',
        FmFaceEnrollProcessStep.uploading => 'Uploading face images…',
        FmFaceEnrollProcessStep.submitted =>
          'Enrollment submitted — you will be notified when verification completes',
        FmFaceEnrollProcessStep.syncing => 'Syncing face database…',
        FmFaceEnrollProcessStep.done => 'Enrollment submitted',
      };

  @override
  Widget build(BuildContext context) {
    final failed = errorMessage != null && errorMessage!.isNotEmpty;
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!failed && step != FmFaceEnrollProcessStep.done)
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Lottie.asset(
                      'assets/json/face_detecting.json',
                      fit: BoxFit.contain,
                    ),
                  )
                else if (!failed && step == FmFaceEnrollProcessStep.done)
                  Icon(
                    Icons.notifications_active_outlined,
                    size: 72,
                    color: TimesheetModuleColors.primary,
                  )
                else
                  Icon(
                    Icons.error_outline_rounded,
                    size: 72,
                    color: const Color(0xFFE53935),
                  ),
                const SizedBox(height: 20),
                Text(
                  failed ? 'Enrollment failed' : _label,
                  textAlign: TextAlign.center,
                  style: TimesheetModuleTypography.h2().copyWith(
                    color: TimesheetModuleColors.surface,
                  ),
                ),
                if (failed) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: TimesheetModuleTypography.body().copyWith(
                      color: TimesheetModuleColors.surface.withValues(alpha: 0.85),
                    ),
                  ),
                ] else if (step != FmFaceEnrollProcessStep.done) ...[
                  const SizedBox(height: 16),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: TimesheetModuleColors.surface,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
