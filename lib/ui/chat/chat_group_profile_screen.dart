import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:el_race/ui/chat/theme/chat_glass_theme.dart';
import 'package:el_race/ui/chat/widgets/blue_geometric_background.dart';
import 'package:el_race/ui/chat/widgets/chat_glass_button.dart';
import 'package:el_race/ui/chat/widgets/chat_top_glass_app_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../chat/chat.dart';
import 'widgets/chat_shared_content_tabs.dart';

/// Profile screen for group / support chats with shared content tabs
/// and (for editable groups) add / remove / leave member actions.
class ChatGroupProfileScreen extends StatefulWidget {
  final String chatId;
  final String title;
  final ChatType chatType;
  final String? supportGroupTitle;

  const ChatGroupProfileScreen({
    super.key,
    required this.chatId,
    required this.title,
    required this.chatType,
    this.supportGroupTitle,
  });

  @override
  State<ChatGroupProfileScreen> createState() => _ChatGroupProfileScreenState();
}

class _ChatGroupProfileScreenState extends State<ChatGroupProfileScreen> {
  late Future<({List<ChatMember> members, List<ChatUser> users})>
      _membersAndUsersFuture;
  final String? _currentUid = FirebaseAuth.instance.currentUser?.uid;

  bool get _canManage =>
      ChatRepository.instance.canManageMembers(widget.chatType);

  @override
  void initState() {
    super.initState();
    _reloadMembers();
  }

  void _reloadMembers() {
    _membersAndUsersFuture = _loadMembersAndUsers();
    ChatRepository.instance.ensureGroupHasAdmin(widget.chatId);
  }

  Future<({List<ChatMember> members, List<ChatUser> users})>
      _loadMembersAndUsers() async {
    final members = await ChatRepository.instance.getChatMembers(widget.chatId);
    final users = members.isNotEmpty
        ? await UserRepository.instance
            .getUsersByIds(members.map((m) => m.uid).toList())
        : <ChatUser>[];
    return (members: members, users: users);
  }

  Future<void> _addMembers() async {
    final current = await _membersAndUsersFuture;
    if (!mounted) return;
    final picked = await showModalBottomSheet<List<ChatUser>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => _AddMembersSheet(
        excludeUids: current.members.map((m) => m.uid).toSet(),
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;

    try {
      await ChatRepository.instance.addMembers(
        widget.chatId,
        picked.map((u) => u.uid).toList(),
      );
      if (!mounted) return;
      setState(_reloadMembers);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${picked.length} member(s)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add members: $e')),
      );
    }
  }

  Future<void> _removeMember(ChatMember member, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2438),
        title: Text('Remove member', style: ChatGlassTheme.title(fontSize: 18)),
        content: Text(
          'Remove $name from this group?',
          style: ChatGlassTheme.body(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: ChatGlassTheme.muted()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: ChatGlassTheme.accent()),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ChatRepository.instance.removeMember(widget.chatId, member.uid);
      if (!mounted) return;
      setState(_reloadMembers);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove: $e')),
      );
    }
  }

  Future<void> _leaveGroup() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2438),
        title: Text('Exit group', style: ChatGlassTheme.title(fontSize: 18)),
        content: Text(
          'Are you sure you want to leave this group?',
          style: ChatGlassTheme.body(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: ChatGlassTheme.muted()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Exit', style: ChatGlassTheme.accent()),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ChatRepository.instance.leaveGroup(widget.chatId);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to leave: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final chatType = widget.chatType;
    final supportGroupTitle = widget.supportGroupTitle;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BlueGeometricBackground(
        child: Column(
          children: [
            const ChatTopGlassAppBar(),
            Expanded(
              child: SafeArea(
                top: false,
                child: FutureBuilder<
                    ({List<ChatMember> members, List<ChatUser> users})>(
                  future: _membersAndUsersFuture,
                  builder: (context, snap) {
                    final members =
                        snap.data?.members ?? const <ChatMember>[];
                    final users = snap.data?.users ?? const <ChatUser>[];
                    final userMap = {for (final u in users) u.uid: u};
                    final amAdmin = members.any(
                          (m) => m.uid == _currentUid && m.isAdmin,
                        ) ||
                        members.every((m) => !m.isAdmin);

                    return StreamBuilder<List<Message>>(
                      stream: ChatRepository.instance.subscribeToMessages(
                        widget.chatId,
                        pageSize: 200,
                      ),
                      builder: (context, messageSnapshot) {
                        final messages =
                            messageSnapshot.data ?? const <Message>[];

                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 22),
                          child: Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: ChatGlassTheme.waterCardDecoration(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _GroupIdentityCard(
                                  title: title,
                                  subtitle: chatType == ChatType.support
                                      ? 'Support Group'
                                      : 'Group Chat',
                                  memberCount: members.length,
                                  chatType: chatType,
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(18, 16, 18, 6),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _InfoRow(
                                          label: 'Group Name', value: title),
                                      _InfoRow(
                                        label: 'Type',
                                        value: _chatTypeLabel(chatType),
                                      ),
                                      _InfoRow(
                                        label: 'Members',
                                        value: '${members.length} members',
                                      ),
                                      if (supportGroupTitle != null)
                                        _InfoRow(
                                          label: 'Department',
                                          value: supportGroupTitle,
                                        ),
                                    ],
                                  ),
                                ),
                                if (_canManage && amAdmin)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        18, 0, 18, 8),
                                    child: ChatGlassButton(
                                      label: 'Add members',
                                      icon: Icons.person_add_alt_1,
                                      variant: ChatGlassButtonVariant.gold,
                                      expand: true,
                                      onPressed: _addMembers,
                                    ),
                                  ),
                                _MembersSection(
                                  members: members,
                                  userMap: userMap,
                                  currentUid: _currentUid,
                                  canManage: _canManage && amAdmin,
                                  onRemove: _removeMember,
                                ),
                                ChatSharedContentTabs(
                                  chatId: widget.chatId,
                                  messages: messages,
                                ),
                                if (_canManage)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        18, 8, 18, 18),
                                    child: ChatGlassButton(
                                      label: 'Exit group',
                                      icon: Icons.logout,
                                      variant: ChatGlassButtonVariant.silver,
                                      expand: true,
                                      onPressed: _leaveGroup,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _chatTypeLabel(ChatType type) {
    switch (type) {
      case ChatType.dm:
        return 'Direct Message';
      case ChatType.role:
        return 'Role Group';
      case ChatType.group:
        return 'Group Chat';
      case ChatType.support:
        return 'Support Group';
    }
  }
}

class _AddMembersSheet extends StatefulWidget {
  const _AddMembersSheet({required this.excludeUids});

  final Set<String> excludeUids;

  @override
  State<_AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends State<_AddMembersSheet> {
  final _controller = TextEditingController();
  final _selected = <String, ChatUser>{};
  List<ChatUser> _results = [];
  bool _searching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (q.trim().length < 2) {
        setState(() {
          _results = [];
          _searching = false;
        });
        return;
      }
      setState(() => _searching = true);
      try {
        final result =
            await UserRepository.instance.searchUsers(query: q.trim());
        if (!mounted) return;
        setState(() {
          _results = result.users
              .where((u) => !widget.excludeUids.contains(u.uid))
              .toList();
          _searching = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _results = [];
          _searching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add members',
                      style: ChatGlassTheme.title(fontSize: 18),
                    ),
                  ),
                  ChatGlassButton(
                    label: 'Add (${_selected.length})',
                    variant: ChatGlassButtonVariant.gold,
                    fontSize: 13,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    onPressed: _selected.isEmpty
                        ? null
                        : () =>
                            Navigator.pop(context, _selected.values.toList()),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                onChanged: _onQueryChanged,
                style: ChatGlassTheme.body(),
                cursorColor: ChatGlassTheme.gold,
                decoration: InputDecoration(
                  hintText: 'Search users',
                  hintStyle: ChatGlassTheme.muted(),
                  prefixIcon: const Icon(Icons.search,
                      color: ChatGlassTheme.textSecondary),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (_searching)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final user = _results[index];
                  final checked = _selected.containsKey(user.uid);
                  return CheckboxListTile(
                    value: checked,
                    activeColor: ChatGlassTheme.gold,
                    checkColor: const Color(0xFF1A1A1A),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected[user.uid] = user;
                        } else {
                          _selected.remove(user.uid);
                        }
                      });
                    },
                    title: Text(user.name, style: ChatGlassTheme.body()),
                    subtitle:
                        Text(user.email ?? '', style: ChatGlassTheme.muted()),
                    secondary: CircleAvatar(
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      child: Text(
                        user.name.isNotEmpty
                            ? user.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(color: ChatGlassTheme.textPrimary),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupIdentityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int memberCount;
  final ChatType chatType;

  const _GroupIdentityCard({
    required this.title,
    required this.subtitle,
    required this.memberCount,
    required this.chatType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(1.3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ChatGlassTheme.avatarRing, width: 1.2),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              child: const Icon(Icons.groups, color: ChatGlassTheme.gold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ChatGlassTheme.title(fontSize: 20)),
                Text(
                  '$subtitle • $memberCount members',
                  style: ChatGlassTheme.muted(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: ChatGlassTheme.muted(fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: ChatGlassTheme.body(fontSize: 18, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _MembersSection extends StatelessWidget {
  final List<ChatMember> members;
  final Map<String, ChatUser> userMap;
  final String? currentUid;
  final bool canManage;
  final void Function(ChatMember member, String name) onRemove;

  const _MembersSection({
    required this.members,
    required this.userMap,
    required this.currentUid,
    required this.canManage,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Group Members',
            style: ChatGlassTheme.muted(fontSize: 12),
          ),
          const SizedBox(height: 8),
          ...members.map((member) {
            final user = userMap[member.uid];
            final name = user?.name ?? 'Unknown';
            final role = user?.jobTitle ?? user?.roleName ?? '';
            final avatarUrl = user?.avatarUrl;
            final isMe = member.uid == currentUid;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  StreamBuilder<PresenceStatus>(
                    stream: PresenceService.instance
                        .subscribeToUserPresence(member.uid),
                    builder: (context, snap) {
                      final isOnline = snap.data?.online ?? false;
                      return Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: ChatGlassTheme.gold,
                                width: 1,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.1),
                              backgroundImage:
                                  avatarUrl != null && avatarUrl.isNotEmpty
                                      ? CachedNetworkImageProvider(avatarUrl)
                                      : null,
                              child: avatarUrl == null || avatarUrl.isEmpty
                                  ? Text(
                                      _initials(name),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: ChatGlassTheme.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          if (isOnline)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2DD65B),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.black, width: 1.5),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                isMe ? '$name (You)' : name,
                                style: ChatGlassTheme.body(
                                  weight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (member.isAdmin) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ChatGlassTheme.gold
                                      .withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Admin',
                                  style: ChatGlassTheme.accent(fontSize: 10),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (role.isNotEmpty)
                          Text(
                            role,
                            style: ChatGlassTheme.muted(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  if (canManage && !isMe)
                    IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.person_remove_outlined,
                          color: Color(0xFFFF8A80)),
                      onPressed: () => onRemove(member, name),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static String _initials(String value) {
    final parts =
        value.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
