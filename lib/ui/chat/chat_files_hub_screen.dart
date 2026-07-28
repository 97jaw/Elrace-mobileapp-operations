import 'package:el_race/ui/chat/theme/chat_glass_theme.dart';
import 'package:el_race/ui/chat/widgets/chat_hub_glass_header.dart';
import 'package:el_race/ui/chat/widgets/chat_shared_content_tabs.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../chat/chat.dart';

/// Files hub — Discuss-style header through tabs; content scrolls below.
class ChatFilesHubScreen extends StatefulWidget {
  const ChatFilesHubScreen({super.key});

  @override
  State<ChatFilesHubScreen> createState() => _ChatFilesHubScreenState();
}

class _ChatFilesHubScreenState extends State<ChatFilesHubScreen> {
  final _searchController = TextEditingController();
  String? _selectedChatId;
  String _selectedTitle = 'All chats';
  List<Message> _messages = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadLatestFromFirstChat();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLatestFromFirstChat() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _loading = true);
    try {
      final chats =
          await ChatRepository.instance.subscribeToActiveUserChats(uid).first;
      if (chats.isEmpty) {
        if (mounted) {
          setState(() {
            _messages = const [];
            _loading = false;
          });
        }
        return;
      }
      final first = chats.first;
      await _loadChat(first.chatId, first.title ?? 'Chat');
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadChat(String chatId, String title) async {
    setState(() {
      _loading = true;
      _selectedChatId = chatId;
      _selectedTitle = title;
    });
    try {
      final msgs = await ChatRepository.instance
          .subscribeToMessages(chatId, pageSize: 200)
          .first;
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages = const [];
        _loading = false;
      });
    }
  }

  Future<void> _pickChat() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final chats =
        await ChatRepository.instance.subscribeToActiveUserChats(uid).first;
    if (!mounted) return;

    final picked = await showModalBottomSheet<UserChat>(
      context: context,
      backgroundColor: const Color(0xFF1A3A5C).withValues(alpha: 0.92),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: chats.length,
            itemBuilder: (_, i) {
              final c = chats[i];
              return ListTile(
                title: Text(c.title ?? 'Chat', style: ChatGlassTheme.body()),
                subtitle: Text(c.type.name, style: ChatGlassTheme.muted()),
                onTap: () => Navigator.pop(ctx, c),
              );
            },
          ),
        );
      },
    );

    if (picked != null) {
      await _loadChat(picked.chatId, picked.title ?? 'Chat');
    }
  }

  List<Message> get _filteredMessages {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _messages;
    return _messages.where((m) {
      final name = (m.fileName ?? '').toLowerCase();
      final text = (m.text ?? '').toLowerCase();
      final url = (m.mediaUrl ?? '').toLowerCase();
      return name.contains(q) || text.contains(q) || url.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final messages = _filteredMessages;

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChatHubGlassHeader(
            title: 'Files',
            subtitle: 'Media, documents and links',
            searchController: _searchController,
            onSearchChanged: () => setState(() {}),
            searchHint: 'Search files',
            trailing: TextButton.icon(
              onPressed: _pickChat,
              icon: Icon(
                Icons.chat_bubble_outline,
                color: Colors.white.withValues(alpha: 0.9),
                size: 18,
              ),
              label: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  _selectedTitle,
                  style: ChatGlassTheme.body(
                    fontSize: 13,
                    weight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            bottom: _selectedChatId == null
                ? null
                : ChatSharedContentTabs(
                    chatId: _selectedChatId!,
                    messages: messages,
                    showTabBar: true,
                    showTabView: false,
                  ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : _selectedChatId == null
                    ? Center(
                        child: Text(
                          'No chats to show files from',
                          style: ChatGlassTheme.muted(fontSize: 16),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 110),
                        child: ChatSharedContentTabs(
                          chatId: _selectedChatId!,
                          messages: messages,
                          showTabBar: false,
                          showTabView: true,
                          expandTabView: true,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
