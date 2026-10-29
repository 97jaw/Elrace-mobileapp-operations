import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/labor_transfer_models.dart';
import 'package:el_race/core/timesheet/providers/labor_transfer_providers.dart';
import 'package:el_race/core/timesheet/providers/timesheet_acting_session_provider.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_acting_foreman_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Shown when a non-foreman opens the Timesheet module.
///
/// Timesheet is a foreman-only product (labor hours capture). PM / HR review
/// flows live under the Site Management module instead. From here a PM / HR
/// user may open the module as one of their own foremen to see exactly what
/// that foreman sees — reads only, never writes.
///
/// Managers / PMs also get a Labor Transfers entry for dual-approval requests.
class TimesheetRoleRestrictedScreen extends ConsumerStatefulWidget {
  const TimesheetRoleRestrictedScreen({
    super.key,
    this.roleLabel,
    this.canActAsForeman = true,
  });

  /// The user's currently resolved role, shown for support context.
  final String? roleLabel;
  final bool canActAsForeman;

  @override
  ConsumerState<TimesheetRoleRestrictedScreen> createState() =>
      _TimesheetRoleRestrictedScreenState();
}

class _TimesheetRoleRestrictedScreenState
    extends ConsumerState<TimesheetRoleRestrictedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(laborTransferCountsProvider);
    });
  }

  Future<void> _pickForeman(BuildContext context, WidgetRef ref) async {
    final foreman = await TmActingForemanSheet.show(context);
    if (foreman == null) return;
    ref.read(tmActingSessionProvider.notifier).enter(foreman);
  }

  @override
  Widget build(BuildContext context) {
    final counts = ref.watch(laborTransferCountsProvider).asData?.value ??
        LaborTransferCounts.empty;

    return TmScaffold(
      glassTitle: 'Timesheet',
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _LaborTransferManagerEntry(
            toApproveCount: counts.toApprove,
            onTap: () => Navigator.of(context).pushNamed(
              TimesheetRouteNames.laborTransferList,
              arguments: LtListAudience.manager,
            ),
          ),
          const SizedBox(height: TimesheetModuleLayout.sectionGap),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: TimesheetModuleColors.primaryTint,
                    borderRadius: BorderRadius.circular(
                      TimesheetModuleLayout.cardRadiusMd,
                    ),
                  ),
                  child: Icon(
                    PhosphorIcons.lockKey(),
                    color: TimesheetModuleColors.primary,
                    size: 42,
                  ),
                ),
                const SizedBox(height: TimesheetModuleLayout.sectionGap),
                Text(
                  'Access restricted',
                  textAlign: TextAlign.center,
                  style: TimesheetModuleTypography.display(),
                ),
                const SizedBox(height: 10),
                Text(
                  'The Timesheet module is available to foreman accounts only. '
                  'Please contact IT to have the correct role assigned to your '
                  'account.',
                  textAlign: TextAlign.center,
                  style: TimesheetModuleTypography.body(),
                ),
                if (widget.roleLabel != null &&
                    widget.roleLabel!.isNotEmpty) ...[
                  const SizedBox(height: TimesheetModuleLayout.sectionGap),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: TimesheetModuleColors.surface,
                      borderRadius: BorderRadius.circular(
                        TimesheetModuleLayout.cardRadiusSm,
                      ),
                      border: Border.all(color: TimesheetModuleColors.divider),
                    ),
                    child: Text(
                      'Current role: ${widget.roleLabel}',
                      style: TimesheetModuleTypography.caption(),
                    ),
                  ),
                ],
                if (widget.canActAsForeman) ...[
                  const SizedBox(height: TimesheetModuleLayout.sectionGap),
                  TmPrimaryButton(
                    warm: true,
                    icon: PhosphorIcons.usersThree(),
                    label: 'Access with Foreman',
                    onPressed: () => _pickForeman(context, ref),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Open Timesheet as one of your foremen to see their sites, '
                    'labors and submitted hours.',
                    textAlign: TextAlign.center,
                    style: TimesheetModuleTypography.caption(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LaborTransferManagerEntry extends StatelessWidget {
  const _LaborTransferManagerEntry({
    required this.toApproveCount,
    required this.onTap,
  });

  final int toApproveCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
        child: Ink(
          decoration: BoxDecoration(
            color: TimesheetModuleColors.glassSurface,
            borderRadius:
                BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
            border: Border.all(color: TimesheetModuleColors.glassBorder),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: TimesheetModuleColors.iconSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TimesheetModuleColors.glassBorder),
                ),
                child: Icon(
                  PhosphorIcons.arrowsLeftRight(),
                  size: 26,
                  color: TimesheetModuleColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Labor Transfers',
                      style: TextStyle(
                        color: TimesheetModuleColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Requests and approvals',
                      style: TextStyle(
                        color: TimesheetModuleColors.mutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (toApproveCount > 0) ...[
                _EntryBadge(count: toApproveCount),
                const SizedBox(width: 8),
              ],
              const Icon(
                Icons.chevron_right_rounded,
                color: TimesheetModuleColors.mutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryBadge extends StatelessWidget {
  const _EntryBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        color: TimesheetModuleColors.danger,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
