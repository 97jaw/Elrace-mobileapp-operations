import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_foreman_summary.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/ui/presentation/timesheet/site_management/widgets/sm_common.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_fast_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Info-tab "Supervisors" (foremen) block. Header shows the summed hours in "K"
/// format; each row shows photo, name, file id, and a last-active indicator
/// derived from the foreman's most recent submit date.
class SmForemenSection extends ConsumerWidget {
  const SmForemenSection({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(timesheetProjectForemenSummaryProvider(projectId));

    return async.when(
      loading: () => _shell(
        context,
        totalLabel: '—',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: TimesheetModuleColors.accent,
              ),
            ),
          ),
        ),
      ),
      error: (_, __) => _shell(
        context,
        totalLabel: '0 hrs',
        child: _emptyState('Could not load supervisors.'),
      ),
      data: (foremen) {
        final totalHours =
            foremen.fold<double>(0, (sum, f) => sum + f.totalHours);
        return _shell(
          context,
          totalLabel: '${_formatK(totalHours)} hrs',
          child: foremen.isEmpty
              ? _emptyState('No supervisors submitted on this project yet.')
              : Column(
                  children: [
                    for (var i = 0; i < foremen.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _ForemanTile(foreman: foremen[i]),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _shell(
    BuildContext context, {
    required String totalLabel,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(TimesheetModuleLayout.cardPadding),
      decoration: smGlassCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmSectionHeader(
            title: 'Supervisors',
            subtitle: 'Foremen on this project',
            trailing: SmMetricPill(label: totalLabel),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _emptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Icon(
            PhosphorIcons.usersThree(),
            color: TimesheetModuleColors.warmMuted,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TimesheetModuleTypography.caption().copyWith(
                color: TimesheetModuleColors.warmMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatK(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
  }
}

class _ForemanTile extends StatelessWidget {
  const _ForemanTile({required this.foreman});

  final TimesheetForemanSummary foreman;

  @override
  Widget build(BuildContext context) {
    final active = _activeStatus(foreman.lastSubmitDate);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
        border: Border.all(color: TimesheetModuleColors.glassBorder),
      ),
      child: Row(
        children: [
          _avatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  foreman.name.isEmpty ? 'Unknown' : foreman.name,
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
              ],
            ),
          ),
          const SizedBox(width: 8),
          _statusChip(active),
        ],
      ),
    );
  }

  Widget _avatar() {
    const size = 46.0;
    final url = foreman.imageUrl?.trim() ?? '';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: TimesheetModuleColors.accentTint,
        border: Border.all(color: TimesheetModuleColors.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.startsWith('http')
          ? TmFastNetworkImage(url: url, width: size, height: size)
          : Icon(
              PhosphorIcons.user(),
              color: TimesheetModuleColors.accent,
              size: 22,
            ),
    );
  }

  Widget _statusChip(_ActiveStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: status.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TimesheetModuleTypography.caption().copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }

  static _ActiveStatus _activeStatus(DateTime? last) {
    if (last == null) {
      return const _ActiveStatus(
        'No submissions',
        TimesheetModuleColors.warmMuted,
      );
    }
    final now = DateTime.now();
    final days = now.difference(last).inDays;
    if (days <= 1) {
      return const _ActiveStatus('Active today', Color(0xFF2E9E5B));
    }
    if (days <= 31) {
      return const _ActiveStatus(
        'Active this month',
        TimesheetModuleColors.accent,
      );
    }
    return _ActiveStatus(
      DateFormat('dd MMM').format(last),
      TimesheetModuleColors.warmMuted,
    );
  }
}

class _ActiveStatus {
  const _ActiveStatus(this.label, this.color);
  final String label;
  final Color color;
}
