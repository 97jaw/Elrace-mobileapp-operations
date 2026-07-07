import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// U.4 — No embedding match (manual pick).
class TmFaceNoMatchNotice extends StatelessWidget {
  const TmFaceNoMatchNotice({
    super.key,
    required this.onDismiss,
    this.bestScore,
    this.suspectedName,
  });

  final VoidCallback onDismiss;
  final double? bestScore;
  final String? suspectedName;

  @override
  Widget build(BuildContext context) {
    final scoreLine = bestScore != null
        ? 'Best score ${(bestScore! * 100).toStringAsFixed(0)}% — below threshold.'
        : 'No enrolled face matched this capture.';

    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: TimesheetModuleColors.navyTint,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: TimesheetModuleColors.navy),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          PhosphorIcons.userCircleMinus(),
                          color: TimesheetModuleColors.navy,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No face match',
                            style: TimesheetModuleTypography.h2().copyWith(
                              color: TimesheetModuleColors.navy,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: onDismiss,
                          icon: Icon(PhosphorIcons.x(), color: TimesheetModuleColors.mutedText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(scoreLine, style: TimesheetModuleTypography.body()),
                    if (suspectedName != null && suspectedName!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Closest: $suspectedName',
                        style: TimesheetModuleTypography.caption(),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Select the labor manually from the list below.',
                      style: TimesheetModuleTypography.caption(),
                    ),
                    const SizedBox(height: 12),
                    TmSecondaryButton(
                      label: 'OK',
                      onPressed: onDismiss,
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
}
