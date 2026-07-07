import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// U.1 — Phase B status on camera (face DB + gate hint).
class TmFaceCaptureStatusChip extends StatelessWidget {
  const TmFaceCaptureStatusChip({
    super.key,
    required this.faceDbLabel,
    required this.gateLabel,
    required this.phaseBActive,
    this.canCapture = false,
  });

  final String faceDbLabel;
  final String gateLabel;
  final bool phaseBActive;
  final bool canCapture;

  static const Color _green = Color(0xFF2E7D52);
  static const Color _greenBg = Color(0xFF1A3D2E);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (phaseBActive)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _greenBg.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _green.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIcons.fingerprint(PhosphorIconsStyle.fill),
                    size: 16,
                    color: const Color(0xFF3DDC84),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Embedding match on',
                      style: TimesheetModuleTypography.caption().copyWith(
                        color: TimesheetModuleColors.surface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: _Pill(
                label: faceDbLabel,
                icon: phaseBActive
                    ? PhosphorIcons.database()
                    : (canCapture
                        ? PhosphorIcons.checkCircle()
                        : PhosphorIcons.warningCircle()),
                accent: phaseBActive ? const Color(0xFF3DDC84) : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Pill(
                label: gateLabel,
                icon: canCapture
                    ? PhosphorIcons.checkCircle()
                    : PhosphorIcons.warningCircle(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
    this.accent,
  });

  final String label;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final fg = accent ?? TimesheetModuleColors.surface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: TimesheetModuleColors.surface.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: TimesheetModuleTypography.caption().copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
