import 'dart:typed_data';

import 'package:el_race/chat/models/chat.dart';
import 'package:el_race/chat/repositories/chat_repository.dart';
import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_team_member.dart';
import 'package:el_race/core/timesheet/providers/timesheet_role_provider.dart';
import 'package:el_race/core/widgets/timesheet/tm_module_glass_header.dart';
import 'package:el_race/ui/chat/chat_screen.dart';
import 'package:el_race/ui/presentation/timesheet/project_chat_contacts.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_chat_resolve.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_fast_network_image.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_share_pdf_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

enum _MemberSendPhase { idle, sending, sent, error }

/// Project chat hub — FM: supervisors only; PM: groups, PM, supervisors, all staff.
class ProjectChatPickerScreen extends ConsumerStatefulWidget {
  const ProjectChatPickerScreen({
    super.key,
    required this.projectId,
    this.projectName,
    this.pdfBytes,
    this.fileName,
  });

  final String projectId;
  final String? projectName;
  final Uint8List? pdfBytes;
  final String? fileName;

  @override
  ConsumerState<ProjectChatPickerScreen> createState() =>
      _ProjectChatPickerScreenState();
}

class _ProjectChatPickerScreenState extends ConsumerState<ProjectChatPickerScreen> {
  final Map<int, _MemberSendPhase> _phases = {};
  _MemberSendPhase _projectGroupPhase = _MemberSendPhase.idle;
  _MemberSendPhase _foremenGroupPhase = _MemberSendPhase.idle;

  bool get _shareMode =>
      widget.pdfBytes != null && widget.fileName != null;

  bool get _isPm =>
      ref.watch(tmRoleResolutionProvider).role == TimesheetEffectiveRole.pm;

  Future<void> _ensureAndMaybeSendGroup({
    required String chatId,
    required String title,
    required List<TimesheetTeamMember> members,
    required void Function(_MemberSendPhase) setPhase,
  }) async {
    setPhase(_MemberSendPhase.sending);
    try {
      final memberUids =
          await TimesheetChatResolve.firebaseUidsForStaff(members);
      await ChatRepository.instance.ensureProjectGroupChat(
        chatId: chatId,
        title: title,
        memberUids: memberUids,
      );
      if (_shareMode) {
        final file = await TmSharePdfSheet.writeTempFile(
          widget.pdfBytes!,
          widget.fileName!,
        );
        await ChatRepository.instance.sendFile(chatId, file, mimeType: 'pdf');
      }
      if (mounted) setPhase(_MemberSendPhase.sent);
    } catch (e) {
      if (mounted) {
        setPhase(_MemberSendPhase.error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Send failed: $e')),
        );
      }
    }
  }

  Future<void> _sendToProjectGroup(ProjectChatContacts contacts) {
    return _ensureAndMaybeSendGroup(
      chatId: ProjectChatContacts.projectGroupChatId(widget.projectId),
      title: widget.projectName ?? 'Project group',
      members: contacts.all,
      setPhase: (p) => setState(() => _projectGroupPhase = p),
    );
  }

  Future<void> _sendToForemenGroup(ProjectChatContacts contacts) {
    return _ensureAndMaybeSendGroup(
      chatId: ProjectChatContacts.foremenGroupChatId(widget.projectId),
      title: '${widget.projectName ?? 'Project'} — Foremen',
      members: contacts.supervisors,
      setPhase: (p) => setState(() => _foremenGroupPhase = p),
    );
  }

  void _openGroupChat(String chatId, String title) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          title: title,
          chatType: ChatType.group,
        ),
      ),
    );
  }

  Future<void> _sendToMember(TimesheetTeamMember member) async {
    setState(() => _phases[member.employeeId] = _MemberSendPhase.sending);
    try {
      final chatId = await TimesheetChatResolve.ensureDmForMember(member);
      if (_shareMode) {
        final file = await TmSharePdfSheet.writeTempFile(
          widget.pdfBytes!,
          widget.fileName!,
        );
        await ChatRepository.instance.sendFile(chatId, file, mimeType: 'pdf');
      }
      if (mounted) {
        setState(() => _phases[member.employeeId] = _MemberSendPhase.sent);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _phases[member.employeeId] = _MemberSendPhase.error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _openDm(TimesheetTeamMember member) async {
    try {
      final chatId = await TimesheetChatResolve.ensureDmForMember(member);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            title: member.name,
            chatType: ChatType.dm,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Widget _statusIcon(_MemberSendPhase phase) {
    switch (phase) {
      case _MemberSendPhase.idle:
        return const SizedBox.shrink();
      case _MemberSendPhase.sending:
        return const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case _MemberSendPhase.sent:
        return Icon(PhosphorIcons.checkCircle(), color: const Color(0xFF3DDC84));
      case _MemberSendPhase.error:
        return Icon(
          PhosphorIcons.warningCircle(),
          color: TimesheetModuleColors.danger,
        );
    }
  }

  Widget _sectionTitle(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TimesheetModuleLayout.screenPaddingH,
        16,
        TimesheetModuleLayout.screenPaddingH,
        8,
      ),
      child: Text(
        label,
        style: TimesheetModuleTypography.caption().copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _memberList(
    List<TimesheetTeamMember> members, {
    String emptyMessage = 'No contacts',
  }) {
    if (members.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TimesheetModuleLayout.screenPaddingH,
        ),
        child: TimesheetEmptyState(message: emptyMessage),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        TimesheetModuleLayout.screenPaddingH,
        0,
        TimesheetModuleLayout.screenPaddingH,
        8,
      ),
      itemCount: members.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: TimesheetModuleLayout.cardSpacing),
      itemBuilder: (context, index) {
        final member = members[index];
        final phase = _phases[member.employeeId] ?? _MemberSendPhase.idle;
        return _StaffTile(
          member: member,
          shareMode: _shareMode,
          phase: phase,
          statusIcon: _statusIcon(phase),
          onSend: phase == _MemberSendPhase.sending
              ? null
              : () => _sendToMember(member),
          onOpenChat: () => _openDm(member),
        );
      },
    );
  }

  Widget _buildFmBody(ProjectChatContacts contacts) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (contacts.supervisors.isNotEmpty) ...[
          _sectionTitle('Supervisors'),
          _memberList(contacts.supervisors),
        ],
        if (contacts.projectManagers.isNotEmpty) ...[
          _sectionTitle('Project manager'),
          _memberList(contacts.projectManagers),
        ],
        if (contacts.otherStaff.isNotEmpty) ...[
          _sectionTitle('Staff'),
          _memberList(contacts.otherStaff),
        ],
        if (contacts.all.isEmpty)
          const Padding(
            padding: EdgeInsets.all(TimesheetModuleLayout.screenPaddingH),
            child: TimesheetEmptyState(
              message: 'No staff linked to this project yet.',
            ),
          ),
      ],
    );
  }

  Widget _buildPmBody(ProjectChatContacts contacts) {
    final projectGroupId =
        ProjectChatContacts.projectGroupChatId(widget.projectId);
    final foremenGroupId =
        ProjectChatContacts.foremenGroupChatId(widget.projectId);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.all(TimesheetModuleLayout.screenPaddingH),
          child: Column(
            children: [
              _GroupChatTile(
                title: 'Project group',
                subtitle: widget.projectName ?? projectGroupId,
                icon: PhosphorIcons.usersThree(),
                shareMode: _shareMode,
                phase: _projectGroupPhase,
                onSend: _projectGroupPhase == _MemberSendPhase.sending
                    ? null
                    : () => _sendToProjectGroup(contacts),
                onOpen: () => _openGroupChat(
                  projectGroupId,
                  widget.projectName ?? 'Project group',
                ),
              ),
              const SizedBox(height: TimesheetModuleLayout.cardSpacing),
              _GroupChatTile(
                title: 'Foremen group',
                subtitle: '${contacts.supervisors.length} supervisor(s)',
                icon: PhosphorIcons.hardHat(),
                shareMode: _shareMode,
                phase: _foremenGroupPhase,
                onSend: _foremenGroupPhase == _MemberSendPhase.sending
                    ? null
                    : () => _sendToForemenGroup(contacts),
                onOpen: () => _openGroupChat(
                  foremenGroupId,
                  '${widget.projectName ?? 'Project'} — Foremen',
                ),
              ),
            ],
          ),
        ),
        if (contacts.projectManagers.isNotEmpty) ...[
          _sectionTitle('Project manager'),
          _memberList(contacts.projectManagers),
        ],
        if (contacts.supervisors.isNotEmpty) ...[
          _sectionTitle('Supervisors'),
          _memberList(contacts.supervisors),
        ],
        if (contacts.otherStaff.isNotEmpty) ...[
          _sectionTitle('All staff'),
          _memberList(contacts.otherStaff),
        ],
        if (contacts.all.isEmpty)
          const Padding(
            padding: EdgeInsets.all(TimesheetModuleLayout.screenPaddingH),
            child: TimesheetEmptyState(
              message: 'No staff linked to this project yet.',
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync =
        ref.watch(projectChatContactsProvider(widget.projectId));
    final isPm = _isPm;

    return Scaffold(
      backgroundColor: TimesheetModuleColors.bgGradientEnd,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TmModuleGlassHeader(title: 'Available chat'),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TimesheetModuleLayout.screenPaddingH,
              0,
              TimesheetModuleLayout.screenPaddingH,
              8,
            ),
            child: Text(
              _shareMode
                  ? 'Send PDF or open chat'
                  : (isPm
                      ? 'Groups, PM, supervisors & staff'
                      : 'Supervisors, PM & staff on this project'),
              style: TimesheetModuleTypography.caption(),
            ),
          ),
          Expanded(
            child: contactsAsync.when(
              loading: () => const TimesheetLoadingState(
                style: TimesheetLoadingStyle.list,
                itemCount: 6,
              ),
              error: (_, __) => TimesheetErrorState(
                message: 'Could not load contacts',
                onRetry: () => ref.invalidate(
                  projectChatContactsProvider(widget.projectId),
                ),
              ),
              data: (contacts) =>
                  isPm ? _buildPmBody(contacts) : _buildFmBody(contacts),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupChatTile extends StatelessWidget {
  const _GroupChatTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.shareMode,
    required this.phase,
    required this.onOpen,
    this.onSend,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool shareMode;
  final _MemberSendPhase phase;
  final VoidCallback onOpen;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TimesheetModuleColors.surface,
      borderRadius:
          BorderRadius.circular(TimesheetModuleLayout.cardRadiusLg),
      child: InkWell(
        onTap: shareMode ? null : onOpen,
        borderRadius:
            BorderRadius.circular(TimesheetModuleLayout.cardRadiusLg),
        child: Padding(
          padding: const EdgeInsets.all(TimesheetModuleLayout.cardPadding),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: TimesheetModuleColors.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: TimesheetModuleColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TimesheetModuleTypography.cardTitle()),
                    Text(subtitle, style: TimesheetModuleTypography.caption()),
                  ],
                ),
              ),
              if (shareMode) ...[
                if (phase == _MemberSendPhase.sent)
                  IconButton(
                    onPressed: onOpen,
                    icon: Icon(PhosphorIcons.chatCircle()),
                    tooltip: 'Open group chat',
                  ),
                TextButton(
                  onPressed: onSend,
                  child: Text(
                    phase == _MemberSendPhase.sent ? 'Sent' : 'Send',
                  ),
                ),
                if (phase == _MemberSendPhase.sending)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (phase == _MemberSendPhase.sent)
                  Icon(
                    PhosphorIcons.checkCircle(),
                    color: const Color(0xFF3DDC84),
                  )
                else if (phase == _MemberSendPhase.error)
                  Icon(
                    PhosphorIcons.warningCircle(),
                    color: TimesheetModuleColors.danger,
                  ),
              ] else
                Icon(
                  PhosphorIcons.caretRight(),
                  color: TimesheetModuleColors.mutedText,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  const _StaffTile({
    required this.member,
    required this.shareMode,
    required this.phase,
    required this.statusIcon,
    required this.onOpenChat,
    this.onSend,
  });

  final TimesheetTeamMember member;
  final bool shareMode;
  final _MemberSendPhase phase;
  final Widget statusIcon;
  final VoidCallback? onSend;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final imageUrl = member.imageUrl?.trim() ?? '';
    final roleLabel = member.isSupervisor
        ? 'Supervisor'
        : member.isProjectManager
            ? 'Project manager'
            : member.subtitle;

    return Material(
      color: TimesheetModuleColors.surface,
      borderRadius:
          BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
      child: ListTile(
        onTap: shareMode ? null : onOpenChat,
        leading: CircleAvatar(
          backgroundColor: TimesheetModuleColors.navyTint,
          child: imageUrl.isNotEmpty
              ? ClipOval(
                  child: TmFastNetworkImage(
                    url: imageUrl,
                    width: 40,
                    height: 40,
                    memCacheWidth: 80,
                  ),
                )
              : Text(
                  member.name.isNotEmpty ? member.name[0] : '?',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
        ),
        title: Text(member.name, style: TimesheetModuleTypography.body()),
        subtitle: roleLabel != null && roleLabel.isNotEmpty
            ? Text(roleLabel, style: TimesheetModuleTypography.caption())
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (shareMode) ...[
              if (phase == _MemberSendPhase.sent)
                IconButton(
                  onPressed: onOpenChat,
                  icon: Icon(PhosphorIcons.chatCircle()),
                  tooltip: 'Open chat',
                ),
              TextButton(
                onPressed: onSend,
                child: Text(phase == _MemberSendPhase.sent ? 'Sent' : 'Send'),
              ),
            ],
            statusIcon,
          ],
        ),
      ),
    );
  }
}
