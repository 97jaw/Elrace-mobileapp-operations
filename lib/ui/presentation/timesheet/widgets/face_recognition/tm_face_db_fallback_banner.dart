import 'package:el_race/core/site_management/face_recognition/face_recognition_availability.dart';
import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// P.2 — Non-blocking banner when embedding match is unavailable.
class TmFaceDbFallbackBanner extends StatelessWidget {
  const TmFaceDbFallbackBanner({
    super.key,
    required this.availability,
    this.phaseAFallback = false,
  });

  final FaceRecognitionAvailability availability;
  final bool phaseAFallback;

  @override
  Widget build(BuildContext context) {
    if (availability == FaceRecognitionAvailability.ready) {
      return const SizedBox.shrink();
    }

    final (Color bg, Color fg, IconData icon) = switch (availability) {
      FaceRecognitionAvailability.offlineCache => (
          const Color(0xFFE8F0FA),
          TimesheetModuleColors.navy,
          PhosphorIcons.wifiSlash(),
        ),
      FaceRecognitionAvailability.noEmbeddings => (
          const Color(0xFFFFF8E8),
          const Color(0xFF8A6A00),
          PhosphorIcons.userMinus(),
        ),
      FaceRecognitionAvailability.engineFailed ||
      FaceRecognitionAvailability.syncFailed => (
          const Color(0xFFFDECEC),
          TimesheetModuleColors.danger,
          PhosphorIcons.warning(),
        ),
      _ => (
          TimesheetModuleColors.navyTint,
          TimesheetModuleColors.navy,
          PhosphorIcons.info(),
        ),
    };

    var message = availability.userMessage;
    if (phaseAFallback) {
      message = '$message · HR photo match fallback';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: fg.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TimesheetModuleTypography.caption().copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
