import 'package:el_race/ui/chat/theme/chat_glass_theme.dart';
import 'package:el_race/ui/chat/widgets/chat_glass_button.dart';
import 'package:el_race/ui/chat/widgets/chat_hub_glass_header.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../chat/chat.dart';
import 'chat_group_profile_screen.dart';
import 'chat_screen.dart';

/// Groups hub — Discuss-style header only; list scrolls below.
class ChatGroupsHubScreen extends StatefulWidget {
  const ChatGroupsHubScreen({super.key});

  @override
  State<ChatGroupsHubScreen> createState() => _ChatGroupsHubScreenState();
}

class _ChatGroupsHubScreenState extends State<ChatGroupsHubScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() => _query = _searchController.text.trim().toLowerCase());

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChatHubGlassHeader(
          title: 'Groups',
          subtitle: 'Manage members, media, and group info',
          searchController: _searchController,
          onSearchChanged: _onSearchChanged,
          searchHint: 'Search groups',
          trailing: ChatGlassIconButton(
            icon: Icons.person_add_alt_1,
            tooltip: 'Manage',
            iconColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Open a group to add or remove members'),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: uid == null
              ? Center(
                  child: Text('Not signed in', style: ChatGlassTheme.muted()),
                )
              : StreamBuilder<List<UserChat>>(
                  stream:
                      ChatRepository.instance.subscribeToActiveUserChats(uid),
                  builder: (context, snap) {
                    var groups = (snap.data ?? [])
                        .where((c) =>
                            c.type == ChatType.group ||
                            c.type == ChatType.role ||
                            c.type == ChatType.support)
                        .toList();

                    if (_query.isNotEmpty) {
                      groups = groups
                          .where((g) =>
                              (g.title ?? '').toLowerCase().contains(_query))
                          .toList();
                    }

                    if (snap.connectionState == ConnectionState.waiting &&
                        groups.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }

                    if (groups.isEmpty) {
                      return Center(
                        child: Text(
                          _query.isEmpty ? 'No groups yet' : 'No results',
                          style: ChatGlassTheme.muted(fontSize: 16),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 110),
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final g = groups[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      chatId: g.chatId,
                                      title: g.title ?? 'Group',
                                      chatType: g.type,
                                      peerUid: g.peerUid,
                                      supportUserUid: g.supportUserUid,
                                      supportGroupTitle: g.supportGroupTitle,
                                    ),
                                  ),
                                );
                              },
                              child: Ink(
                                decoration: ChatGlassTheme.waterCardDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  leading: Container(
                                    padding: const EdgeInsets.all(1.5),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: ChatGlassTheme.avatarRing,
                                        width: 1.8,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 22,
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.14),
                                      child: Icon(
                                        Icons.groups,
                                        color: Colors.white
                                            .withValues(alpha: 0.95),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    g.title ?? 'Group',
                                    style: ChatGlassTheme.body(
                                        weight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    _typeLabel(g.type),
                                    style: ChatGlassTheme.muted(),
                                  ),
                                  trailing: ChatGlassIconButton(
                                    icon: Icons.info_outline,
                                    size: 36,
                                    iconColor: Colors.white,
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ChatGroupProfileScreen(
                                            chatId: g.chatId,
                                            title: g.title ?? 'Group',
                                            chatType: g.type,
                                            supportGroupTitle:
                                                g.supportGroupTitle,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  static String _typeLabel(ChatType type) {
    switch (type) {
      case ChatType.group:
        return 'Group · tap info to manage members';
      case ChatType.role:
        return 'Role group';
      case ChatType.support:
        return 'Support';
      case ChatType.dm:
        return 'Chat';
    }
  }
}
