import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/labor_transfer_models.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_transport.dart';
import 'package:el_race/core/timesheet/providers/labor_transfer_providers.dart';
import 'package:el_race/core/timesheet/services/labor_transfer_roster_refresh.dart';
import 'package:el_race/core/timesheet/services/timesheet_project_access_service.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/labor_transfer/lt_person_avatar.dart';
import 'package:el_race/ui/presentation/timesheet/labor_transfer/lt_status_chip.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_fast_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class LtTransferDetailScreen extends ConsumerStatefulWidget {
  const LtTransferDetailScreen({super.key, required this.transferId});

  final int transferId;

  @override
  ConsumerState<LtTransferDetailScreen> createState() =>
      _LtTransferDetailScreenState();
}

class _LtTransferDetailScreenState
    extends ConsumerState<LtTransferDetailScreen> {
  bool _busy = false;

  Future<void> _refreshTeamIfNeeded(LaborTransferState state) async {
    if (state != LaborTransferState.approved &&
        state != LaborTransferState.rejected) {
      return;
    }
    await LaborTransferRosterRefresh.afterTeamChange(
      ProviderScope.containerOf(context),
    );
  }

  Future<void> _approve(LaborTransferRecord record) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(laborTransferApiProvider);
      final updated = await api.approve(record.id);
      await _refreshTeamIfNeeded(updated.state);
      ref.invalidate(laborTransferDetailProvider(widget.transferId));
      ref.invalidate(laborTransferCountsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.state == LaborTransferState.approved
                ? 'Transfer approved'
                : 'Partial approval recorded',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is TimesheetOdooException ? e.message : 'Approve failed',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(LaborTransferRecord record) async {
    if (_busy) return;
    final reason = await _askRejectReason();
    if (reason == null || reason.trim().isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(laborTransferApiProvider);
      final updated = await api.reject(record.id, reason: reason);
      await _refreshTeamIfNeeded(updated.state);
      ref.invalidate(laborTransferDetailProvider(widget.transferId));
      ref.invalidate(laborTransferCountsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer rejected')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is TimesheetOdooException ? e.message : 'Reject failed',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askRejectReason() {
    final controller = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TimesheetModuleColors.glassSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Reject reason',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: TimesheetModuleColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Why is this transfer rejected?',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TmPrimaryButton(
                label: 'Reject transfer',
                warm: true,
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              ),
              const SizedBox(height: 8),
              TmSecondaryButton(
                label: 'Cancel',
                warm: true,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    ).whenComplete(controller.dispose);
  }

  Future<void> _cancel(LaborTransferRecord record) async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel transfer?'),
        content: Text('Cancel ${record.name}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel transfer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(laborTransferApiProvider);
      await api.cancel(record.id);
      ref.invalidate(laborTransferDetailProvider(widget.transferId));
      ref.invalidate(laborTransferCountsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer cancelled')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is TimesheetOdooException ? e.message : 'Cancel failed',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(laborTransferDetailProvider(widget.transferId));
    final loginId = TimesheetProjectAccessService.loginEmployeeId();
    final fmt = DateFormat('dd MMM yyyy · HH:mm');
    final title = async.maybeWhen(
      data: (r) => r.name,
      orElse: () => 'Labor transfer',
    );

    return TmScaffold(
      glassTitle: title,
      padding: const EdgeInsets.fromLTRB(
        TimesheetModuleLayout.screenPaddingH,
        8,
        TimesheetModuleLayout.screenPaddingH,
        16,
      ),
      body: async.when(
        loading: () => const TimesheetLoadingState(),
        error: (e, _) => TimesheetErrorState(
          message: e is TimesheetOdooException
              ? e.message
              : 'Could not load transfer',
          onRetry: () =>
              ref.invalidate(laborTransferDetailProvider(widget.transferId)),
        ),
        data: (record) {
          final showApprove = record.canActOnApproval;
          final showCancel = record.canCancel(loginId);
          return Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: LtStatusChip(state: record.state),
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      children: [
                        _InfoRow(
                          label: 'Requester',
                          value: record.requester?.name ?? '—',
                        ),
                        _InfoRow(
                          label: 'Transfer Foreman',
                          value: record.targetForeman?.name ?? '—',
                        ),
                        if (record.city != null)
                          _InfoRow(label: 'Branch', value: record.city!.name),
                        if (record.requestDate != null)
                          _InfoRow(
                            label: 'Requested',
                            value: fmt.format(record.requestDate!.toLocal()),
                          ),
                        if (record.decisionDate != null)
                          _InfoRow(
                            label: 'Decision',
                            value: fmt.format(record.decisionDate!.toLocal()),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const _SectionTitle('Approvers'),
                    const SizedBox(height: 8),
                    if (record.sameApprover)
                      _ApproverRow(
                        title: 'Approver (both sides)',
                        person: record.fromApprover ??
                            record.toApprover ??
                            record.approver,
                        status: record.sideStatus(
                          approved: record.fromApproved || record.toApproved,
                        ),
                      )
                    else ...[
                      _ApproverRow(
                        title: 'From approver',
                        person: record.fromApprover ?? record.approver,
                        status: record.sideStatus(approved: record.fromApproved),
                      ),
                      const SizedBox(height: 8),
                      _ApproverRow(
                        title: 'To approver',
                        person: record.toApprover,
                        status: record.sideStatus(approved: record.toApproved),
                      ),
                    ],
                    if (record.note.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const _SectionTitle('Note'),
                      Text(
                        record.note,
                        style: const TextStyle(
                          color: TimesheetModuleColors.ink,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (record.rejectReason.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const _SectionTitle('Reject reason'),
                      Text(
                        record.rejectReason,
                        style: const TextStyle(
                          color: TimesheetModuleColors.danger,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _SectionTitle(
                      'Labors (${record.lines.isNotEmpty ? record.lines.length : record.laborCount})',
                    ),
                    const SizedBox(height: 8),
                    if (record.lines.isEmpty)
                      const Text(
                        'No labor lines on this transfer',
                        style: TextStyle(color: TimesheetModuleColors.warmMuted),
                      )
                    else
                      for (final line in record.lines) ...[
                        _LaborLineTile(line: line),
                        const SizedBox(height: 8),
                      ],
                    const SizedBox(height: 16),
                    const _SectionTitle('Timeline'),
                    const SizedBox(height: 8),
                    _Timeline(record: record, fmt: fmt),
                  ],
                ),
              ),
              if (showApprove || showCancel) ...[
                const SizedBox(height: 8),
                if (showApprove) ...[
                  TmPrimaryButton(
                    label: _busy ? 'Working…' : 'Approve',
                    warm: true,
                    icon: PhosphorIcons.checkCircle(),
                    onPressed: _busy ? null : () => _approve(record),
                  ),
                  const SizedBox(height: 8),
                  TmSecondaryButton(
                    label: 'Reject',
                    warm: true,
                    icon: PhosphorIcons.xCircle(),
                    onPressed: _busy ? null : () => _reject(record),
                  ),
                ],
                if (showCancel) ...[
                  if (showApprove) const SizedBox(height: 8),
                  TmSecondaryButton(
                    label: _busy ? 'Working…' : 'Cancel request',
                    warm: true,
                    icon: PhosphorIcons.prohibit(),
                    onPressed: _busy ? null : () => _cancel(record),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ApproverRow extends StatelessWidget {
  const _ApproverRow({
    required this.title,
    required this.person,
    required this.status,
  });

  final String title;
  final LaborTransferPerson? person;
  final LtApproverSideStatus status;

  @override
  Widget build(BuildContext context) {
    final name = person?.name ?? '—';
    final (icon, color, label) = switch (status) {
      LtApproverSideStatus.approved => (
          Icons.check_circle_rounded,
          TimesheetModuleColors.success,
          '✓ approved',
        ),
      LtApproverSideStatus.rejected => (
          Icons.cancel_rounded,
          TimesheetModuleColors.danger,
          '✗ rejected',
        ),
      LtApproverSideStatus.pending => (
          Icons.schedule_rounded,
          TimesheetModuleColors.warning,
          'pending',
        ),
    };

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
          LtPersonAvatar(name: name, photoUrl: person?.photo, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: TimesheetModuleColors.warmMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    color: TimesheetModuleColors.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: TimesheetModuleColors.ink,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TimesheetModuleColors.glassSurface,
        borderRadius:
            BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
        border: Border.all(color: TimesheetModuleColors.glassBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              color: TimesheetModuleColors.warmMuted,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: TimesheetModuleColors.ink,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _LaborLineTile extends StatelessWidget {
  const _LaborLineTile({required this.line});
  final LaborTransferLine line;

  @override
  Widget build(BuildContext context) {
    final labor = line.labor;
    final initial =
        labor.name.trim().isEmpty ? '?' : labor.name.trim()[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: TimesheetModuleColors.surface,
        borderRadius:
            BorderRadius.circular(TimesheetModuleLayout.cardRadiusSm),
        border: Border.all(color: TimesheetModuleColors.glassBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: TimesheetModuleColors.iconSurface,
            child: labor.photo != null && labor.photo!.isNotEmpty
                ? ClipOval(
                    child: TmFastNetworkImage(
                      url: labor.photo!,
                      width: 40,
                      height: 40,
                    ),
                  )
                : Text(
                    initial,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  labor.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: TimesheetModuleColors.ink,
                  ),
                ),
                if (labor.empId != null && labor.empId!.isNotEmpty)
                  Text(
                    labor.empId!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: TimesheetModuleColors.warmMuted,
                    ),
                  ),
                Text(
                  'Previous: ${line.previousForeman?.name ?? '—'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: TimesheetModuleColors.warmMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.record, required this.fmt});
  final LaborTransferRecord record;
  final DateFormat fmt;

  @override
  Widget build(BuildContext context) {
    final steps = <(String, String?)>[
      (
        'Submitted',
        record.requestDate != null
            ? fmt.format(record.requestDate!.toLocal())
            : null,
      ),
      if (record.state == LaborTransferState.partiallyApproved)
        ('1 of 2 approved', null),
      if (record.state == LaborTransferState.approved)
        (
          'Approved',
          record.decisionDate != null
              ? fmt.format(record.decisionDate!.toLocal())
              : null,
        ),
      if (record.state == LaborTransferState.rejected)
        (
          'Rejected',
          record.decisionDate != null
              ? fmt.format(record.decisionDate!.toLocal())
              : null,
        ),
      if (record.state == LaborTransferState.cancelled)
        (
          'Cancelled',
          record.decisionDate != null
              ? fmt.format(record.decisionDate!.toLocal())
              : null,
        ),
      if (record.isPending &&
          record.state != LaborTransferState.partiallyApproved)
        ('Awaiting approval', null),
      if (record.state == LaborTransferState.partiallyApproved)
        ('Awaiting second approval', null),
    ];

    return Column(
      children: [
        for (final step in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  PhosphorIcons.circle(PhosphorIconsStyle.fill),
                  size: 10,
                  color: TimesheetModuleColors.accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    step.$2 == null ? step.$1 : '${step.$1} · ${step.$2}',
                    style: const TextStyle(
                      color: TimesheetModuleColors.ink,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
