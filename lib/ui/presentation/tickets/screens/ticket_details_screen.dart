import 'package:el_race/report_module/data/models/report_model.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/ui/presentation/productivity/theme/productivity_light_theme.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_light_shell.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_searchable_picker.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/screens/task_details.dart';
import 'package:el_race/ui/presentation/tickets/data/ticket_model.dart';
import 'package:el_race/ui/presentation/tickets/providers/ticket_firebase_provider.dart';
import 'package:el_race/ui/presentation/todo_list/data/todo_model.dart';
import 'package:el_race/ui/presentation/todo_list/providers/todo_firebase_provider.dart';
import 'package:el_race/ui/presentation/todo_list/services/team_members_api_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class TicketDetailsScreen extends StatefulWidget {
  const TicketDetailsScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  State<TicketDetailsScreen> createState() => _TicketDetailsScreenState();
}

class _TicketDetailsScreenState extends State<TicketDetailsScreen> {
  static const _accent = Color(0xFF4C8BF5);

  TicketModel? _ticket;
  bool _loading = true;
  List<TeamMember> _members = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _loadMembers();
    });
  }

  Future<void> _loadMembers() async {
    try {
      final members = await TeamMembersApiService.instance.getTeamMembers();
      if (!mounted) return;
      setState(() => _members = members);
    } catch (_) {}
  }

  Future<void> _load() async {
    final provider = context.read<TicketFirebaseProvider>();
    if (provider.tickets.isEmpty) await provider.loadTickets();
    TicketModel? found;
    for (final t in provider.tickets) {
      if (t.firebaseId == widget.ticketId) {
        found = t;
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _ticket = found;
      _loading = false;
    });
  }

  Future<void> _save(TicketModel updated) async {
    final ok =
        await context.read<TicketFirebaseProvider>().updateTicket(updated);
    if (!mounted) return;
    if (ok) {
      setState(() => _ticket = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ticket updated'),
          backgroundColor: Color(0xFF4C8BF5),
        ),
      );
    }
  }

  Color _statusBg(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return ProductivityLightTheme.statusPendingBg;
      case TicketStatus.inProgress:
        return ProductivityLightTheme.statusActiveBg;
      case TicketStatus.resolved:
        return ProductivityLightTheme.statusCompletedBg;
      case TicketStatus.closed:
        return ProductivityLightTheme.statusOverdueBg;
    }
  }

  Color _priorityBg(TicketPriority priority) {
    switch (priority) {
      case TicketPriority.high:
        return ProductivityLightTheme.statusOverdueBg;
      case TicketPriority.medium:
        return ProductivityLightTheme.statusPendingBg;
      case TicketPriority.low:
        return ProductivityLightTheme.washBlue;
    }
  }

  Future<void> _pickStatus() async {
    final ticket = _ticket;
    if (ticket == null) return;
    final picked = await ProductivitySearchablePicker.show<TicketStatus>(
      context,
      title: 'Status',
      items: TicketStatus.values,
      labelOf: (s) => s.label,
      selected: ticket.status,
    );
    if (picked != null) await _save(ticket.copyWith(status: picked));
  }

  Future<void> _pickPriority() async {
    final ticket = _ticket;
    if (ticket == null) return;
    final picked = await ProductivitySearchablePicker.show<TicketPriority>(
      context,
      title: 'Priority',
      items: TicketPriority.values,
      labelOf: (p) => p.label,
      selected: ticket.priority,
    );
    if (picked != null) await _save(ticket.copyWith(priority: picked));
  }

  Future<void> _pickAssignee() async {
    final ticket = _ticket;
    if (ticket == null) return;
    TeamMember? current;
    for (final m in _members) {
      if (m.id.toString() == ticket.assigneeId ||
          m.name == ticket.assigneeName) {
        current = m;
        break;
      }
    }
    final picked = await ProductivitySearchablePicker.show<TeamMember>(
      context,
      title: 'Assignee',
      items: _members,
      labelOf: (m) => m.name,
      selected: current,
      allowClear: true,
      clearLabel: 'Unassigned',
    );
    if (!mounted) return;
    if (picked == null) {
      await _save(ticket.copyWith(clearAssignee: true));
    } else {
      await _save(
        ticket.copyWith(
          assigneeId: picked.id.toString(),
          assigneeName: picked.name,
        ),
      );
    }
  }

  Future<void> _pickParentTask() async {
    final ticket = _ticket;
    if (ticket == null) return;
    final todos = context.read<TodoFirebaseProvider>().todos;
    final options =
        todos.where((t) => t.firebaseId != null).toList(growable: false);
    final current = options
        .where((t) => t.firebaseId == ticket.parentTaskId)
        .cast<TodoModel?>()
        .firstOrNull;
    final picked = await ProductivitySearchablePicker.show<TodoModel>(
      context,
      title: 'Parent task',
      items: options,
      labelOf: (t) => t.title,
      selected: current,
      allowClear: true,
      clearLabel: 'Standalone',
    );
    if (!mounted) return;
    if (picked == null) {
      await _save(ticket.copyWith(clearParent: true));
    } else {
      await _save(
        ticket.copyWith(
          parentTaskId: picked.firebaseId,
          parentTaskTitle: picked.title,
        ),
      );
    }
  }

  Future<void> _linkReport() async {
    final ticket = _ticket;
    if (ticket?.firebaseId == null) return;
    final reports = context.read<ReportProvider>().reports;
    final linked = ticket!.reportIds.toSet();
    final available = reports.where((r) => !linked.contains(r.id)).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No reports available to link')),
      );
      return;
    }
    final picked = await ProductivitySearchablePicker.show<ReportModel>(
      context,
      title: 'Link report',
      items: available,
      labelOf: (r) => r.name,
    );
    if (picked == null || !mounted) return;
    await context
        .read<TicketFirebaseProvider>()
        .linkReport(ticket.firebaseId!, picked.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ProductivityLightShell(
        showBack: true,
        centerTitle: true,
        title: 'Ticket details',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final ticket = _ticket;
    if (ticket == null) {
      return ProductivityLightShell(
        showBack: true,
        centerTitle: true,
        title: 'Ticket details',
        body: Center(
          child: Text(
            'Ticket not found',
            style: ProductivityLightTheme.cardSubtitle,
          ),
        ),
      );
    }

    final reports = context.watch<ReportProvider>().reports;
    String reportName(String id) {
      for (final r in reports) {
        if (r.id == id) return r.name;
      }
      return 'Report $id';
    }

    return ProductivityLightShell(
      showBack: true,
      centerTitle: true,
      title: 'Ticket details',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            ticket.title,
            style: GoogleFonts.roboto(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: ProductivityLightTheme.ink,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(ticket.status.label, _statusBg(ticket.status)),
              _pill(ticket.priority.label, _priorityBg(ticket.priority)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Updated ${DateFormat('MMM d, y · HH:mm').format(ticket.updatedAt)}',
            style: GoogleFonts.roboto(
              fontSize: 12,
              color: ProductivityLightTheme.inkMuted,
            ),
          ),
          if (ticket.description?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 16),
            _sectionCard(
              title: 'Description',
              child: Text(
                ticket.description!,
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  height: 1.45,
                  color: ProductivityLightTheme.inkSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Details',
            child: Column(
              children: [
                _detailRow(
                  label: 'Status',
                  value: ticket.status.label,
                  onTap: _pickStatus,
                ),
                const SizedBox(height: 10),
                _detailRow(
                  label: 'Priority',
                  value: ticket.priority.label,
                  onTap: _pickPriority,
                ),
                const SizedBox(height: 10),
                _detailRow(
                  label: 'Assignee',
                  value: ticket.assigneeName?.isNotEmpty == true
                      ? ticket.assigneeName!
                      : 'Unassigned',
                  onTap: _pickAssignee,
                ),
                const SizedBox(height: 10),
                _detailRow(
                  label: 'Parent task',
                  value: ticket.parentTaskTitle?.isNotEmpty == true
                      ? ticket.parentTaskTitle!
                      : 'Standalone',
                  onTap: _pickParentTask,
                  onOpen: ticket.parentTaskId == null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TaskDetailsScreen(
                                taskId: ticket.parentTaskId,
                              ),
                            ),
                          );
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Reports',
            trailing: TextButton(
              onPressed: _linkReport,
              style: TextButton.styleFrom(
                foregroundColor: _accent,
                textStyle: GoogleFonts.roboto(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Link report'),
            ),
            child: ticket.reportIds.isEmpty
                ? Text(
                    'No linked reports',
                    style: GoogleFonts.roboto(
                      fontSize: 13,
                      color: ProductivityLightTheme.inkMuted,
                    ),
                  )
                : Column(
                    children: [
                      for (final id in ticket.reportIds) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: ProductivityLightTheme.iconChip,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: ProductivityLightTheme.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.description_outlined,
                                size: 18,
                                color: Color(0xFF4C8BF5),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  reportName(id),
                                  style: GoogleFonts.roboto(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: ProductivityLightTheme.ink,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  await context
                                      .read<TicketFirebaseProvider>()
                                      .unlinkReport(ticket.firebaseId!, id);
                                  await _load();
                                },
                                icon: const Icon(
                                  Icons.link_off_rounded,
                                  size: 18,
                                  color: ProductivityLightTheme.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: ProductivityLightTheme.accentEnded,
                side: const BorderSide(
                  color: ProductivityLightTheme.accentEnded,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onPressed: () async {
                final ok = await context
                    .read<TicketFirebaseProvider>()
                    .deleteTicket(ticket.firebaseId!);
                if (ok && context.mounted) Navigator.pop(context);
              },
              child: Text(
                'Delete ticket',
                style: GoogleFonts.roboto(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ProductivityLightTheme.border),
      ),
      child: Text(
        label,
        style: GoogleFonts.roboto(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: ProductivityLightTheme.ink,
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ProductivityLightTheme.card,
        borderRadius: BorderRadius.circular(ProductivityLightTheme.boxRadius),
        border: Border.all(color: ProductivityLightTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ProductivityLightTheme.ink,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _detailRow({
    required String label,
    required String value,
    required VoidCallback onTap,
    VoidCallback? onOpen,
  }) {
    return Material(
      color: ProductivityLightTheme.iconChip,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ProductivityLightTheme.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: ProductivityLightTheme.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ProductivityLightTheme.ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (onOpen != null)
                IconButton(
                  onPressed: onOpen,
                  icon: const Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: Color(0xFF4C8BF5),
                  ),
                ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: ProductivityLightTheme.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
