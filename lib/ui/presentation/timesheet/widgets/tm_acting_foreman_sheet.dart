import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_team_member.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Foreman picker for PM / HR users on the Timesheet lock screen.
///
/// Lists the login employee's own `hr.employee.x_foreman_ids` (served by
/// `/api/timesheet/my_hr_scope`). Choosing one starts a read-only acting
/// session; the server re-checks the selection on every scoped read.
abstract final class TmActingForemanSheet {
  /// Resolves to the chosen foreman, or `null` when dismissed.
  static Future<TimesheetTeamMember?> show(BuildContext context) {
    return showModalBottomSheet<TimesheetTeamMember>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TmActingForemanSheetBody(),
    );
  }
}

class _TmActingForemanSheetBody extends ConsumerWidget {
  const _TmActingForemanSheetBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foremenAsync = ref.watch(timesheetPmForemenProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            gradient: TimesheetModuleColors.warmGradient,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: TimesheetModuleColors.ink.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Access with Foreman',
                        style: TimesheetModuleTypography.h2().copyWith(
                          color: TimesheetModuleColors.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(
                        PhosphorIcons.x(),
                        color: TimesheetModuleColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Open Timesheet the way your foreman sees it. '
                  'Viewing only — submitting needs their own login.',
                  style: TimesheetModuleTypography.caption().copyWith(
                    color: TimesheetModuleColors.warmMuted,
                  ),
                ),
              ),
              Expanded(
                child: foremenAsync.when(
                  loading: () => const TimesheetLoadingState(
                    style: TimesheetLoadingStyle.list,
                    itemCount: 4,
                  ),
                  error: (_, __) => TimesheetErrorState(
                    message: 'Could not load your foremen',
                    onRetry: () => ref.invalidate(timesheetPmForemenProvider),
                  ),
                  data: (foremen) {
                    if (foremen.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: TimesheetEmptyState(
                          message:
                              'No foremen are linked to your account yet. '
                              'Ask HR to add them to your foreman list.',
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: foremen.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final foreman = foremen[index];
                        return _ForemanTile(
                          foreman: foreman,
                          onAccess: () =>
                              Navigator.of(context).pop(foreman),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ForemanTile extends StatelessWidget {
  const _ForemanTile({
    required this.foreman,
    required this.onAccess,
  });

  final TimesheetTeamMember foreman;
  final VoidCallback onAccess;

  @override
  Widget build(BuildContext context) {
    final url = foreman.imageUrl?.trim() ?? '';
    final name = foreman.name.trim();
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TimesheetModuleColors.glassSurface,
        borderRadius:
            BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
        border: Border.all(color: TimesheetModuleColors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: TimesheetModuleColors.iconSurface),
              color: TimesheetModuleColors.accentTint,
            ),
            clipBehavior: Clip.antiAlias,
            child: url.isNotEmpty
                ? Image.network(url, fit: BoxFit.cover)
                : Center(
                    child: Text(
                      initial,
                      style: TimesheetModuleTypography.h2().copyWith(
                        color: TimesheetModuleColors.accent,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Employee #${foreman.employeeId}' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TimesheetModuleTypography.cardTitle().copyWith(
                    color: TimesheetModuleColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'File ID: ${foreman.fileId}',
                  style: TimesheetModuleTypography.caption().copyWith(
                    color: TimesheetModuleColors.warmMuted,
                  ),
                ),
                if (foreman.subtitle != null &&
                    foreman.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    foreman.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TimesheetModuleTypography.caption().copyWith(
                      color: TimesheetModuleColors.warmMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _AccessPill(onTap: onAccess),
        ],
      ),
    );
  }
}

class _AccessPill extends StatelessWidget {
  const _AccessPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            gradient: TimesheetModuleColors.warmButtonGradient,
            borderRadius: BorderRadius.circular(999),
            boxShadow: TimesheetModuleShadows.cardShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                PhosphorIcons.eye(),
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Access',
                style: TimesheetModuleTypography.caption().copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
