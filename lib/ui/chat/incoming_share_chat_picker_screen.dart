import 'dart:io';

import 'package:el_race/chat/models/user_chat.dart';
import 'package:el_race/chat/repositories/chat_repository.dart';
import 'package:el_race/chat/repositories/user_repository.dart';
import 'package:el_race/ui/chat/chat_screen.dart';
import 'package:el_race/ui/chat/theme/chat_glass_theme.dart';
import 'package:el_race/ui/chat/widgets/blue_geometric_background.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Pick a chat and send a file shared into the app via "Elrace Chat".
class IncomingShareChatPickerScreen extends StatefulWidget {
  const IncomingShareChatPickerScreen({
    super.key,
    required this.file,
    required this.fileName,
    this.mimeType,
  });

  final File file;
  final String fileName;
  final String? mimeType;

  @override
  State<IncomingShareChatPickerScreen> createState() =>
      _IncomingShareChatPickerScreenState();
}

class _IncomingShareChatPickerScreenState
    extends State<IncomingShareChatPickerScreen> {
  bool _sending = false;
  String? _error;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _sendToChat(UserChat userChat) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final mime = widget.mimeType ?? '';
      final isImage = mime.startsWith('image/') ||
          RegExp(r'\.(jpe?g|png|gif|webp)$', caseSensitive: false)
              .hasMatch(widget.fileName);
      if (isImage) {
        await ChatRepository.instance.sendImage(userChat.chatId, widget.file);
      } else {
        await ChatRepository.instance.sendFile(
          userChat.chatId,
          widget.file,
          mimeType: widget.mimeType,
        );
      }
      if (!mounted) return;
      final peerUid = userChat.peerUid;
      final liveName = peerUid != null
          ? UserRepository.instance.getCachedUser(peerUid)?.name
          : null;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: userChat.chatId,
            title: (liveName != null && liveName.trim().isNotEmpty)
                ? liveName
                : (userChat.title ?? 'Chat'),
            chatType: userChat.type,
            peerUid: peerUid,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'Failed to send: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BlueGeometricBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        'Send to chat',
                        style: ChatGlassTheme.title(fontSize: 22),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ChatGlassTheme.muted(),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: ChatGlassTheme.body().copyWith(color: Colors.redAccent),
                  ),
                ),
              if (_sending)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                )
              else if (uid == null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Please sign in to send this file in chat.',
                    style: ChatGlassTheme.body(),
                  ),
                )
              else
                Expanded(
                  child: StreamBuilder<List<UserChat>>(
                    stream: ChatRepository.instance.subscribeToUserChats(uid),
                    builder: (context, snapshot) {
                      final chats = (snapshot.data ?? const <UserChat>[])
                          .where((c) => !c.archived)
                          .toList();
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          chats.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (chats.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No chats yet. Open Chat and start a conversation first.',
                              textAlign: TextAlign.center,
                              style: ChatGlassTheme.muted(),
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        itemCount: chats.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final chat = chats[index];
                          return Material(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            child: ListTile(
                              title: Text(
                                chat.title?.trim().isNotEmpty == true
                                    ? chat.title!
                                    : 'Chat',
                                style: ChatGlassTheme.body(),
                              ),
                              trailing: const Icon(
                                Icons.send_rounded,
                                color: Colors.white70,
                              ),
                              onTap: () => _sendToChat(chat),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
