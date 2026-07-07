import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_fast_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// U.3 — Yellow warning: recognized but not in foreman team (submit blocked).
class TmFaceOutOfTeamWarning extends StatelessWidget {
  const TmFaceOutOfTeamWarning({
    super.key,
    required this.employee,
    required this.matchScore,
    required this.onDismiss,
  });

  final TimesheetOdooEmployee employee;
  final double matchScore;
  final VoidCallback onDismiss;

  static const Color _amber = Color(0xFFF5B544);
  static const Color _amberDeep = Color(0xFF8A6A00);
  static const Color _amberBg = Color(0xFFFFF8E8);

  @override
  Widget build(BuildContext context) {
    final pct = (matchScore * 100).clamp(0, 100).toStringAsFixed(0);
    final imageUrl = employee.imageUrl;

    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _amberBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _amber, width: 2),
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
                          PhosphorIcons.warning(PhosphorIconsStyle.fill),
                          color: _amberDeep,
                          size: 32,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Not in your team',
                            style: TimesheetModuleTypography.h2().copyWith(
                              color: _amberDeep,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: onDismiss,
                          icon: Icon(PhosphorIcons.x(), color: _amberDeep),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This labor was recognized by face data but is not assigned '
                      'to your team. You cannot record attendance for them.',
                      style: TimesheetModuleTypography.body().copyWith(
                        color: TimesheetModuleColors.text,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: _amber.withValues(alpha: 0.35),
                          child: imageUrl != null
                              ? ClipOval(
                                  child: TmFastNetworkImage(
                                    url: imageUrl,
                                    width: 64,
                                    height: 64,
                                    memCacheWidth: 128,
                                  ),
                                )
                              : Text(
                                  employee.name.isNotEmpty ? employee.name[0] : '?',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: _amberDeep,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                employee.name,
                                style: TimesheetModuleTypography.body().copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'File ID: ${employee.displayFileId}',
                                style: TimesheetModuleTypography.caption(),
                              ),
                              Text(
                                'Match confidence $pct%',
                                style: TimesheetModuleTypography.caption().copyWith(
                                  color: _amberDeep,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TmPrimaryButton(
                      label: 'OK — capture someone else',
                      icon: PhosphorIcons.arrowLeft(),
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
