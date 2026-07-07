import 'dart:io';
import 'dart:typed_data';

import 'package:el_race/chat/models/chat.dart';
import 'package:el_race/chat/repositories/chat_repository.dart';
import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/ui/chat/chat_screen.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/ui/presentation/timesheet/project_chat_picker_screen.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_chat_resolve.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Share PDF: project group chat, DM, external, or download.
class TmSharePdfSheet {
  TmSharePdfSheet._();

  static Future<void> show(
    BuildContext context, {
    required Uint8List pdfBytes,
    required String fileName,
    String? projectId,
    String? projectName,
    String? dmChatId,
    String? dmTitle,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ShareBody(
        pdfBytes: pdfBytes,
        fileName: fileName,
        projectId: projectId,
        projectName: projectName,
        dmChatId: dmChatId,
        dmTitle: dmTitle,
      ),
    );
  }

  static Future<File> writeTempFile(Uint8List bytes, String fileName) async {
    return _writeTemp(bytes, fileName);
  }

  static Future<File> _writeTemp(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final safe = fileName.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    final name = safe.toLowerCase().endsWith('.pdf') ? safe : '$safe.pdf';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> shareExternal(
    BuildContext context,
    Uint8List pdfBytes,
    String fileName,
  ) async {
    final file = await _writeTemp(pdfBytes, fileName);
    final origin = _shareOrigin(context);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      sharePositionOrigin: origin,
    );
  }

  static Future<void> downloadToDevice(
    BuildContext context,
    Uint8List pdfBytes,
    String fileName,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final safe = fileName.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    final name = safe.toLowerCase().endsWith('.pdf') ? safe : '$safe.pdf';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(pdfBytes, flush: true);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to ${file.path}')),
      );
    }
  }

  static Rect _shareOrigin(BuildContext context) {
    final box = context.findRenderObject();
    if (box is RenderBox) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    return const Rect.fromLTWH(1, 1, 1, 1);
  }
}

enum _ShareSendPhase { idle, sending, sent, error }

class _ShareBody extends ConsumerStatefulWidget {
  const _ShareBody({
    required this.pdfBytes,
    required this.fileName,
    this.projectId,
    this.projectName,
    this.dmChatId,
    this.dmTitle,
  });

  final Uint8List pdfBytes;
  final String fileName;
  final String? projectId;
  final String? projectName;
  final String? dmChatId;
  final String? dmTitle;

  @override
  ConsumerState<_ShareBody> createState() => _ShareBodyState();
}

class _ShareBodyState extends ConsumerState<_ShareBody> {
  _ShareSendPhase _groupPhase = _ShareSendPhase.idle;
  String? _groupChatId;

  ChatType _chatTypeFor(String chatId) {
    if (chatId.startsWith('project_')) return ChatType.group;
    if (chatId.startsWith('dm_')) return ChatType.dm;
    return ChatType.dm;
  }

  Future<void> _sendToGroup() async {
    final projectId = widget.projectId?.trim() ?? '';
    if (projectId.isEmpty) return;
    final chatId = 'project_$projectId';
    setState(() {
      _groupPhase = _ShareSendPhase.sending;
      _groupChatId = chatId;
    });

    try {
      final projectId = widget.projectId!.trim();
      final staff = await ref
          .read(timesheetProjectStaffProvider(projectId).future);
      final memberUids = await TimesheetChatResolve.firebaseUidsForStaff(staff);

      await ChatRepository.instance.ensureProjectGroupChat(
        chatId: chatId,
        title: widget.projectName,
        memberUids: memberUids,
      );
      final file = await TmSharePdfSheet._writeTemp(
        widget.pdfBytes,
        widget.fileName,
      );
      await ChatRepository.instance.sendFile(
        chatId,
        file,
        mimeType: 'pdf',
      );
      if (!mounted) return;
      setState(() => _groupPhase = _ShareSendPhase.sent);
    } catch (e) {
      if (mounted) {
        setState(() => _groupPhase = _ShareSendPhase.error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send to group: $e')),
        );
      }
    }
  }

  Future<void> _openGroupChat() async {
    final chatId = _groupChatId;
    if (chatId == null) return;
    if (!mounted) return;
    Navigator.of(context).pop();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          title: widget.projectName ?? 'Project group',
          chatType: ChatType.group,
        ),
      ),
    );
  }

  Future<void> _sendToDm(String chatId) async {
    Navigator.of(context).pop();
    final file = await TmSharePdfSheet._writeTemp(widget.pdfBytes, widget.fileName);
    try {
      await ChatRepository.instance.sendFile(chatId, file, mimeType: 'pdf');
      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            title: widget.dmTitle ?? widget.projectName ?? 'Chat',
            chatType: _chatTypeFor(chatId),
          ),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send PDF to chat')),
        );
      }
    }
  }

  Widget? _groupTrailing() {
    switch (_groupPhase) {
      case _ShareSendPhase.idle:
        return Icon(PhosphorIcons.paperPlaneTilt());
      case _ShareSendPhase.sending:
        return const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case _ShareSendPhase.sent:
        return Icon(PhosphorIcons.checkCircle(), color: const Color(0xFF3DDC84));
      case _ShareSendPhase.error:
        return Icon(PhosphorIcons.warningCircle(), color: TimesheetModuleColors.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectId = widget.projectId?.trim() ?? '';

    return Container(
      decoration: const BoxDecoration(
        color: TimesheetModuleColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: TimesheetModuleColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Share PDF', style: TimesheetModuleTypography.h2()),
          const SizedBox(height: 16),
          if (projectId.isNotEmpty) ...[
            ListTile(
              leading: Icon(PhosphorIcons.usersThree()),
              title: const Text('Project group chat'),
              subtitle: Text(
                _groupPhase == _ShareSendPhase.sent
                    ? 'Sent to group — one message for all members'
                    : (widget.projectName ?? 'All project members'),
              ),
              trailing: _groupTrailing(),
              onTap: _groupPhase == _ShareSendPhase.sending
                  ? null
                  : (_groupPhase == _ShareSendPhase.sent
                      ? _openGroupChat
                      : _sendToGroup),
            ),
            if (_groupPhase == _ShareSendPhase.sent) ...[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _openGroupChat,
                  icon: Icon(PhosphorIcons.chatCircle()),
                  label: const Text('Open group chat'),
                ),
              ),
            ],
            ListTile(
              leading: Icon(PhosphorIcons.chatCircle()),
              title: const Text('Choose project member'),
              subtitle: const Text('Send to one person (direct message)'),
              onTap: () async {
                Navigator.of(context).pop();
                if (!context.mounted) return;
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => ProjectChatPickerScreen(
                      projectId: projectId,
                      projectName: widget.projectName,
                      pdfBytes: widget.pdfBytes,
                      fileName: widget.fileName,
                    ),
                  ),
                );
              },
            ),
          ],
          if (widget.dmChatId != null && widget.dmChatId!.trim().isNotEmpty)
            ListTile(
              leading: Icon(PhosphorIcons.paperPlaneTilt()),
              title: Text('Send to ${widget.dmTitle ?? 'chat'}'),
              onTap: () => _sendToDm(widget.dmChatId!.trim()),
            ),
          ListTile(
            leading: Icon(PhosphorIcons.shareNetwork()),
            title: const Text('Share externally'),
            subtitle: const Text('WhatsApp, Mail, Files…'),
            onTap: () async {
              Navigator.of(context).pop();
              if (!context.mounted) return;
              await TmSharePdfSheet.shareExternal(
                context,
                widget.pdfBytes,
                widget.fileName,
              );
            },
          ),
          ListTile(
            leading: Icon(PhosphorIcons.download()),
            title: const Text('Download'),
            onTap: () async {
              Navigator.of(context).pop();
              if (!context.mounted) return;
              await TmSharePdfSheet.downloadToDevice(
                context,
                widget.pdfBytes,
                widget.fileName,
              );
            },
          ),
        ],
      ),
    );
  }
}
