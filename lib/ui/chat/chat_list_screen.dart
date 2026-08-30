import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:el_race/core/ui/adaptive_glass.dart';
import 'package:el_race/ui/chat/widgets/chat_glass_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../chat/chat.dart';
import 'chat_archived_list_screen.dart';
import 'chat_screen.dart';
import 'new_chat_screen.dart';
import 'starred_messages_screen.dart';
import 'theme/chat_glass_theme.dart';
import 'widgets/chat_top_glass_app_bar.dart';
import 'widgets/chat_unified_header_backdrop.dart';
import 'widgets/typing_indicator.dart';
import 'widgets/whatsapp_chat_list_header.dart';

/// Main chat list screen showing all user's conversations
class ChatListScreen extends StatefulWidget {
  /// When true, parent [ChatShellScreen] already shows the glass app bar.
  final bool embeddedInShell;

  const ChatListScreen({super.key, this.embeddedInShell = false});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  String? _currentUid;
  bool _isChatAvailable = false;
  bool _isInitializing = false;

  final TextEditingController _localSearchController = TextEditingController();
  final ValueNotifier<String> _searchNotifier = ValueNotifier('');
  Timer? _debounce;

  /// Cached chat stream — created once, reused across rebuilds
  Stream<List<UserChat>>? _userChatsStream;

  // Global user search state — ValueNotifiers so only the bottom section rebuilds
  final ValueNotifier<List<ChatUser>> _globalResultsNotifier =
      ValueNotifier([]);
  final ValueNotifier<bool> _globalSearchingNotifier = ValueNotifier(false);
  ChatUser? _currentUser;
  Timer? _globalDebounce;

  @override
  void initState() {
    super.initState();
    _initializeChat();

    _localSearchController.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), () {
        final q = _localSearchController.text.trim().toLowerCase();
        if (q != _searchNotifier.value) {
          _searchNotifier.value = q;
        }
      });

      // Also trigger global user search
      _globalDebounce?.cancel();
      _globalDebounce = Timer(const Duration(milliseconds: 500), () {
        _performGlobalSearch(_localSearchController.text.trim());
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _globalDebounce?.cancel();
    _localSearchController.dispose();
    _searchNotifier.dispose();
    _globalResultsNotifier.dispose();
    _globalSearchingNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    if (_currentUid != null) {
      _currentUser = await UserRepository.instance.getUser(_currentUid!);
    }
  }

  Future<void> _performGlobalSearch(String query) async {
    if (query.length < 2) {
      _globalResultsNotifier.value = [];
      _globalSearchingNotifier.value = false;
      return;
    }

    _globalSearchingNotifier.value = true;

    try {
      final result = await UserRepository.instance.searchUsers(query: query);
      // Include self so users can "Message yourself" (WhatsApp-style).
      if (mounted) {
        _globalResultsNotifier.value = result.users;
        _globalSearchingNotifier.value = false;
      }
    } catch (e) {
      if (mounted) {
        _globalResultsNotifier.value = [];
        _globalSearchingNotifier.value = false;
      }
    }
  }

  Future<void> _initializeChat() async {
    _currentUid = FirebaseAuth.instance.currentUser?.uid;
    _isChatAvailable = ChatModuleHelper.instance.isChatEnabled;

    // If chat is not available but user is authenticated, try to restore session
    if (!_isChatAvailable && !_isInitializing) {
      setState(() => _isInitializing = true);

      try {
        print(
            '🔷 ChatListScreen: Chat not available, attempting to restore session...');
        final result =
            await ChatModuleHelper.instance.restoreFromStoredSession();

        if (result != null && result.chatEnabled) {
          _currentUid = FirebaseAuth.instance.currentUser?.uid;
          _isChatAvailable = true;
          _loadCurrentUser();
          print('✅ ChatListScreen: Chat session restored successfully');
        } else {
          print(
              '⚠️ ChatListScreen: Failed to restore chat session: ${result?.error}');
        }
      } catch (e) {
        print('❌ ChatListScreen: Error restoring chat session: $e');
      } finally {
        if (mounted) {
          setState(() => _isInitializing = false);
        }
      }
    } else {
      _loadCurrentUser();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while initializing chat
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: _ChatListStaticBody(
          child: const Center(
            child: CircularProgressIndicator(color: ChatGlassTheme.gold),
          ),
        ),
      );
    }

    if (!_isChatAvailable || _currentUid == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: _ChatListStaticBody(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Chat not available',
                style: TextStyle(
                  fontSize: 18,
                  color: ChatGlassTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  ChatModuleHelper.instance.getStatusMessage(),
                  style: TextStyle(
                    fontSize: 14,
                    color: ChatGlassTheme.textMuted,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: 24),
              ChatGlassButton(
                label: 'Retry',
                icon: Icons.refresh,
                onPressed: _initializeChat,
              ),
              const SizedBox(height: 12),
              // Show logout button if error mentions session expired
              if (ChatModuleHelper.instance
                      .getStatusMessage()
                      .contains('expired') ||
                  ChatModuleHelper.instance
                      .getStatusMessage()
                      .contains('login again'))
                ChatGlassButton(
                  label: 'Logout & Login Again',
                  icon: Icons.logout,
                  variant: ChatGlassButtonVariant.silver,
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/signIN');
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          if (!widget.embeddedInShell)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: Stack(
                children: [
                  ChatUnifiedHeaderBackdrop.layer(),
                  const ChatTopGlassAppBar(),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<UserChat>>(
              stream: _userChatsStream ??= ChatRepository.instance
                  .subscribeToActiveUserChats(_currentUid!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: ChatGlassTheme.gold,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final allChats = (snapshot.data ?? []).where((c) {
                  if (c.type == ChatType.role || c.type == ChatType.group) {
                    return true;
                  }
                  return c.hasMessages;
                }).toList();

                final peerUids = allChats
                    .where((c) => c.type == ChatType.dm && c.peerUid != null)
                    .map((c) => c.peerUid!)
                    .toList();
                if (peerUids.isNotEmpty) {
                  UserRepository.instance.prefetchUsers(peerUids);
                  // Heal titles/avatars for existing DMs (directory fallback).
                  UserRepository.instance.healExistingDmPeerProfiles();
                }

                return CustomScrollView(
                  slivers: [
                    SliverPersistentHeader(
                      floating: true,
                      pinned: true,
                      delegate: WhatsAppChatListHeaderDelegate(
                        searchController: _localSearchController,
                        onSearchChanged: () {
                          // Trigger rebuild of suffix clear via setState on header
                          // Search filtering uses debounced notifier from listener.
                          setState(() {});
                        },
                        onNewChat: _openNewChat,
                        onOpenMenu: _openOverflowMenu,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: StreamBuilder<int>(
                        stream: ChatRepository.instance
                            .subscribeToArchivedCount(_currentUid!),
                        builder: (context, archSnap) {
                          final count = archSnap.data ?? 0;
                          if (count <= 0) return const SizedBox.shrink();
                          return _ArchivedRow(
                            count: count,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const ChatArchivedListScreen(),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    ValueListenableBuilder<String>(
                      valueListenable: _searchNotifier,
                      builder: (context, query, _) {
                        return ValueListenableBuilder<List<ChatUser>>(
                          valueListenable: _globalResultsNotifier,
                          builder: (context, globalResults, _) {
                            return ValueListenableBuilder<bool>(
                              valueListenable: _globalSearchingNotifier,
                              builder: (context, isGlobalSearching, _) {
                                final filteredChats = query.isEmpty
                                    ? allChats
                                    : allChats
                                        .where((c) => (c.title ?? '')
                                            .toLowerCase()
                                            .contains(query))
                                        .toList();

                                final bool hasQuery = query.isNotEmpty;
                                final bool hasGlobalResults =
                                    globalResults.isNotEmpty;
                                final bool showNoResults = hasQuery &&
                                    filteredChats.isEmpty &&
                                    !hasGlobalResults &&
                                    !isGlobalSearching;

                                if (showNoResults) {
                                  return SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: Center(
                                      child: Text(
                                        allChats.isEmpty
                                            ? 'No chats yet'
                                            : 'No results',
                                        style: ChatGlassTheme.muted(fontSize: 17),
                                      ),
                                    ),
                                  );
                                }

                                final List<Widget> items = [];

                                for (var i = 0;
                                    i < filteredChats.length;
                                    i++) {
                                  final userChat = filteredChats[i];
                                  items.add(
                                    Dismissible(
                                      key: ValueKey(
                                          'chat_${userChat.chatId}'),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding:
                                            const EdgeInsets.only(right: 20),
                                        color: ChatGlassTheme.gold,
                                        child: const Icon(
                                          Icons.archive,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                      confirmDismiss: (_) async {
                                        await ChatRepository.instance
                                            .toggleArchive(
                                                userChat.chatId, true);
                                        // No SnackBar — stream removes the row;
                                        // undo is available via Archived list.
                                        return true;
                                      },
                                      child: _ChatListTile(
                                        userChat: userChat,
                                        currentUid: _currentUid!,
                                        onTap: () => _openChat(userChat),
                                      ),
                                    ),
                                  );
                                }

                                if (hasQuery &&
                                    (isGlobalSearching || hasGlobalResults)) {
                                  items.add(
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 16, 16, 8),
                                      child: Row(
                                        children: [
                                          Text(
                                            'Users',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          if (isGlobalSearching) ...[
                                            const SizedBox(width: 8),
                                            const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child:
                                                  CircularProgressIndicator(
                                                      strokeWidth: 2),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );

                                  for (final user in globalResults) {
                                    items.add(
                                      _InlineUserTile(
                                        user: user,
                                        onTap: () =>
                                            _startChatWithUser(user),
                                      ),
                                    );
                                  }

                                  if (!isGlobalSearching &&
                                      globalResults.isEmpty) {
                                    items.add(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        child: Center(
                                          child: Text(
                                            'No users found',
                                            style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 13),
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                }

                                if (items.isEmpty && !hasQuery) {
                                  return SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.chat_bubble_outline,
                                              size: 70,
                                              color: Colors.grey[400]),
                                          const SizedBox(height: 12),
                                          Text(
                                            'No chats yet',
                                            style: TextStyle(
                                                fontSize: 17,
                                                color: Colors.grey[700]),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                return SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) => items[index],
                                    childCount: items.length,
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 110)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openNewChat() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NewChatScreen()),
    );
  }

  void _openOverflowMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.star_outline,
                    color: ChatGlassTheme.gold),
                title: Text('Starred messages',
                    style: ChatGlassTheme.body()),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StarredMessagesScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.archive_outlined,
                    color: ChatGlassTheme.textSecondary),
                title: Text('Archived', style: ChatGlassTheme.body()),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChatArchivedListScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_comment_outlined,
                    color: ChatGlassTheme.gold),
                title: Text('New chat', style: ChatGlassTheme.body()),
                onTap: () {
                  Navigator.pop(ctx);
                  _openNewChat();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openChat(UserChat userChat) {
    final peerUid = userChat.peerUid;
    // Prefer live Firestore name when opening so header isn't a stale title.
    final liveName = peerUid != null
        ? UserRepository.instance.getCachedUser(peerUid)?.name
        : null;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: userChat.chatId,
          title: (liveName != null && liveName.trim().isNotEmpty)
              ? liveName
              : (userChat.title ?? 'Chat'),
          chatType: userChat.type,
          peerUid: peerUid,
          supportUserUid: userChat.supportUserUid,
          supportGroupTitle: userChat.supportGroupTitle,
        ),
      ),
    );
  }

  /// Start a support chat with a department group
  Future<void> _startSupportChat(Chat group) async {
    if (_currentUid == null || _currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final chatId = await ChatRepository.instance.createOrGetSupportChat(
        userUid: _currentUid!,
        userName: _currentUser!.name,
        targetRoleId: group.roleId!,
        groupTitle: group.title ?? 'Group ${group.roleId}',
        sourceRoleChatId: group.id,
        supportGroupKey: group.id,
        userRoleId: _currentUser!.roleId,
        userBranchId: _currentUser!.branchId,
        userCompanyId: _currentUser!.companyId,
      );

      if (mounted) Navigator.of(context).pop(); // dismiss loading

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              title: group.title ?? 'Group ${group.roleId}',
              chatType: ChatType.support,
              supportUserUid: _currentUid,
              supportGroupTitle: group.title ?? 'Group ${group.roleId}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // dismiss loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start support chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startChatWithUser(ChatUser user) async {
    if (_currentUid == null) return;

    // Generate chat ID deterministically (supports self-chat / message yourself)
    final chatId = Chat.generateDmChatId(_currentUid!, user.uid);
    final isSelf = user.uid == _currentUid;
    final title = isSelf
        ? (user.name.trim().isNotEmpty ? '${user.name} (You)' : 'You')
        : user.name;

    _localSearchController.clear();

    // Just navigate to chat screen — the chat doc will be created
    // when the first message is sent via ChatRepository.sendText
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chatId,
            title: title,
            chatType: ChatType.dm,
            peerUid: user.uid,
          ),
        ),
      );
    }
  }
}

/// Chat list tile widget
class _ChatListTile extends StatefulWidget {
  final UserChat userChat;
  final String currentUid;
  final VoidCallback onTap;

  const _ChatListTile({
    required this.userChat,
    required this.currentUid,
    required this.onTap,
  });

  @override
  State<_ChatListTile> createState() => _ChatListTileState();
}

class _ChatListTileState extends State<_ChatListTile> {
  // Cached once per tile instead of re-issued inline inside build() (which
  // re-ran on every StreamBuilder tick — chat/typing/unread-count/presence
  // — for every visible row). Shared between the avatar and the title,
  // which each used to fire their own separate getUser() call for the same
  // peer. Per FIX_IMPLEMENTATION_PLAN.md Phase 5.1.
  Future<ChatUser?>? _peerUserFuture;

  UserChat get userChat => widget.userChat;

  @override
  void initState() {
    super.initState();
    _initPeerUserFuture();
  }

  @override
  void didUpdateWidget(covariant _ChatListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userChat.peerUid != widget.userChat.peerUid) {
      _initPeerUserFuture();
    }
  }

  void _initPeerUserFuture() {
    _peerUserFuture = (userChat.type == ChatType.dm && userChat.peerUid != null)
        ? UserRepository.instance.getUserWithDirectoryFallback(
            userChat.peerUid!,
            forceRefresh: true,
          )
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<Chat?>(
      stream: ChatRepository.instance.subscribeToChat(userChat.chatId),
      builder: (context, chatSnapshot) {
        final chat = chatSnapshot.data;
        final lastMessage = chat?.lastMessage;

        final hasUnread = userChat.hasUnread(lastMessage?.createdAt);

        return StreamBuilder<TypingInfo>(
          stream: PresenceService.instance
              .subscribeToTypingWithNames(userChat.chatId),
          builder: (context, typingSnapshot) {
            final typingInfo = typingSnapshot.data;
            final isTyping = typingInfo?.isTyping ?? false;

            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: AdaptiveGlassLayer(
                borderRadius: BorderRadius.circular(18),
                sigma: 20,
                fallbackColor: ChatGlassTheme.waterFillStrong,
                fallbackBorder: Border.all(
                  color: Colors.white.withValues(alpha: 0.38),
                  width: 1,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onTap,
                    onLongPress: () => _showChatActions(context),
                    borderRadius: BorderRadius.circular(18),
                    child: Ink(
                      decoration: ChatGlassTheme.waterCardDecoration(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildAvatar(),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (userChat.type == ChatType.dm &&
                                    userChat.peerUid != null)
                                  FutureBuilder<ChatUser?>(
                                    future: _peerUserFuture,
                                    builder: (context, snap) {
                                      final rawName = snap.data?.name ??
                                          userChat.title ??
                                          'Chat';
                                      final isSelf =
                                          userChat.peerUid == widget.currentUid;
                                      final displayName = _limitToTwoWords(
                                        isSelf
                                            ? (rawName.trim().isEmpty
                                                ? 'You'
                                                : '$rawName (You)')
                                            : rawName,
                                      );
                                      return Text(
                                        displayName,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          color: ChatGlassTheme.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      );
                                    },
                                  )
                                else
                                  Text(
                                    _limitToTwoWords(userChat.title ?? 'Chat'),
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      color: ChatGlassTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                const SizedBox(height: 4),
                                DefaultTextStyle.merge(
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: ChatGlassTheme.textSecondary,
                                    fontWeight: hasUnread
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                  child: isTyping
                                      ? TypingTextWidget(
                                          typingUserNames:
                                              typingInfo!.typingNames,
                                          isGroupChat:
                                              userChat.type != ChatType.dm,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: Colors.white,
                                            fontStyle: FontStyle.italic,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        )
                                      : _buildLastMessage(lastMessage),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          StreamBuilder<int>(
                            stream: ChatRepository.instance
                                .subscribeToUnreadCount(userChat.chatId),
                            builder: (context, unreadSnap) {
                              final unreadCount = unreadSnap.data ?? 0;
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    lastMessage != null
                                        ? _formatTime(lastMessage.createdAt)
                                        : '',
                                      style: TextStyle(
                                        color: unreadCount > 0
                                            ? Colors.white
                                            : ChatGlassTheme.textMuted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (userChat.pinned)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 4),
                                          child: Icon(
                                            Icons.push_pin,
                                            size: 14,
                                            color: ChatGlassTheme.textSecondary,
                                          ),
                                        ),
                                      if (userChat.muted)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 4),
                                          child: Icon(
                                            Icons.volume_off,
                                            size: 14,
                                            color: ChatGlassTheme.textSecondary,
                                          ),
                                        ),
                                      if (unreadCount > 0)
                                        Container(
                                          constraints: const BoxConstraints(
                                              minWidth: 22, minHeight: 22),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 2),
                                          alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: userChat.muted
                                                  ? Colors.white
                                                      .withValues(alpha: 0.35)
                                                  : Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              unreadCount > 99
                                                  ? '99+'
                                                  : '$unreadCount',
                                              style: TextStyle(
                                                color: userChat.muted
                                                    ? Colors.white
                                                    : const Color(0xFF1A3A5C),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                        )
                                      else
                                        const SizedBox(height: 22),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAvatar() {
    if (userChat.type == ChatType.dm && userChat.peerUid != null) {
      return StreamBuilder<PresenceStatus>(
        stream:
            PresenceService.instance.subscribeToUserPresence(userChat.peerUid!),
        builder: (context, snapshot) {
          final isOnline = snapshot.data?.online ?? false;
          return FutureBuilder<ChatUser?>(
            future: _peerUserFuture,
            builder: (context, userSnapshot) {
              final peerUser = userSnapshot.data;
              final avatarUrl = peerUser?.avatarUrl;
              return _avatarShell(
                isOnline: isOnline,
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Text(
                          _getInitials(peerUser?.name ?? userChat.title ?? '?'),
                          style: const TextStyle(
                            color: ChatGlassTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
              );
            },
          );
        },
      );
    }

    return _avatarShell(
      isOnline: true,
      child: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.white.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Image.asset(
            'assets/logo/rcc2.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _avatarShell({required Widget child, required bool isOnline}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ChatGlassTheme.avatarRing, width: 1.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: child,
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: const Color(0xFF2DD65B),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLastMessage(LastMessage? lastMessage) {
    if (lastMessage == null) {
      return const Text(
        'No messages',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    String text;

    if (lastMessage.isDeleted) {
      text = 'This message was deleted';
    } else {
      switch (lastMessage.type) {
        case 'image':
          text = '📷 Photo';
          break;
        case 'file':
          text = '📎 File';
          break;
        case 'audio':
          text = '🎵 Voice message';
          break;
        case 'video':
          text = '🎬 Video';
          break;
        case 'signable_doc':
          text = '📄 Document';
          break;
        default:
          text = lastMessage.text;
      }
    }

    final isMine = lastMessage.senderId == widget.currentUid;
    final display = isMine && !lastMessage.isDeleted ? 'You: $text' : text;

    if (!isMine || lastMessage.isDeleted) {
      return Text(
        display,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // WhatsApp-style: ticks before preview when last message is yours.
    return StreamBuilder<List<ChatMember>>(
      stream: ChatRepository.instance.subscribeToChatMembers(userChat.chatId),
      builder: (context, membersSnap) {
        final members = membersSnap.data ?? const <ChatMember>[];
        final status = Message.receiptStatusFromPeers(
          message: Message(
            id: 'list_preview',
            senderId: lastMessage.senderId,
            type: MessageType.text,
            text: lastMessage.text,
            createdAt: lastMessage.createdAt,
            clientMsgId: '',
            status: MessageStatus.sent,
          ),
          currentUid: widget.currentUid,
          members: members,
        );

        return Row(
          children: [
            _chatListReceiptTick(status),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                display,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _chatListReceiptTick(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return Icon(Icons.access_time, size: 14, color: Colors.white70);
      case MessageStatus.failed:
        return Icon(Icons.error_outline, size: 14, color: Colors.red[300]);
      case MessageStatus.sent:
        return const Icon(Icons.done, size: 16, color: Colors.white70);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 16, color: Colors.white70);
      case MessageStatus.read:
        return const Icon(
          Icons.done_all,
          size: 16,
          color: Color(0xFF25D366),
        );
      case MessageStatus.deleted:
        return const SizedBox.shrink();
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  void _showChatActions(BuildContext context) {
    HapticFeedback.mediumImpact();

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset position = box.localToGlobal(Offset.zero);
    final Size size = box.size;

    final RelativeRect menuPosition = RelativeRect.fromLTRB(
      position.dx + size.width / 2 - 100,
      position.dy + size.height,
      position.dx + size.width / 2 + 100,
      position.dy,
    );

    showMenu<String>(
      context: context,
      position: menuPosition,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF1F1F1F),
      items: [
        PopupMenuItem<String>(
          value: 'pin',
          height: 48,
          child: Row(
            children: [
              Icon(
                userChat.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: ChatGlassTheme.textSecondary,
                size: 22,
              ),
              const SizedBox(width: 14),
              Text(
                userChat.pinned ? 'Unpin' : 'Pin',
                style: const TextStyle(
                  color: ChatGlassTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'mute',
          height: 48,
          child: Row(
            children: [
              Icon(
                userChat.muted ? Icons.volume_up : Icons.volume_off,
                color: ChatGlassTheme.textSecondary,
                size: 22,
              ),
              const SizedBox(width: 14),
              Text(
                userChat.muted ? 'Unmute' : 'Mute',
                style: const TextStyle(
                  color: ChatGlassTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'archive',
          height: 48,
          child: Row(
            children: [
              Icon(
                userChat.archived ? Icons.unarchive : Icons.archive_outlined,
                color: ChatGlassTheme.textSecondary,
                size: 22,
              ),
              const SizedBox(width: 14),
              Text(
                userChat.archived ? 'Unarchive' : 'Archive',
                style: const TextStyle(
                  color: ChatGlassTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          height: 48,
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                color: Color(0xFFFF6B6B),
                size: 22,
              ),
              SizedBox(width: 14),
              Text(
                'Delete',
                style: TextStyle(
                  color: Color(0xFFFF6B6B),
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ).then((value) async {
      if (value == null) return;
      switch (value) {
        case 'pin':
          ChatRepository.instance.togglePin(
            userChat.chatId,
            !userChat.pinned,
          );
          break;
        case 'mute':
          ChatRepository.instance.toggleMute(
            userChat.chatId,
            !userChat.muted,
          );
          break;
        case 'archive':
          ScaffoldMessenger.of(context).clearSnackBars();
          ChatRepository.instance.toggleArchive(
            userChat.chatId,
            !userChat.archived,
          );
          break;
        case 'delete':
          await _confirmAndDeleteChat(context);
          break;
      }
    });
  }

  Future<void> _confirmAndDeleteChat(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text(
          'Delete chat?',
          style: TextStyle(color: ChatGlassTheme.textPrimary),
        ),
        content: const Text(
          'This removes the chat from your list only. Messages stay for other people.',
          style: TextStyle(color: ChatGlassTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF6B6B)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ChatRepository.instance.deleteChatForMe(userChat.chatId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat deleted')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes == 1) return '1 min ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours == 1) return '1 hour ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';

    return '${local.day}/${local.month}/${local.year}';
  }
}

/// Inline user tile for global search results shown in chat list
class _InlineUserTile extends StatelessWidget {
  final ChatUser user;
  final VoidCallback onTap;

  const _InlineUserTile({
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withValues(alpha: 0.14),
            backgroundImage: user.avatarUrl != null
                ? CachedNetworkImageProvider(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null
                ? Text(
                    _getInitials(user.name),
                    style: const TextStyle(
                      color: ChatGlassTheme.gold,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          StreamBuilder<PresenceStatus>(
            stream: PresenceService.instance.subscribeToUserPresence(user.uid),
            builder: (context, snapshot) {
              final isOnline = snapshot.data?.online ?? false;
              if (!isOnline) return const SizedBox.shrink();
              return Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      title: Text(
        _displayName(user),
        style: ChatGlassTheme.body(weight: FontWeight.w600),
      ),
      subtitle: Text(
        _isSelf(user)
            ? 'Message yourself'
            : (user.email ?? user.jobTitle ?? ''),
        style: ChatGlassTheme.muted(fontSize: 13),
      ),
      trailing: const Icon(Icons.message_rounded,
          color: ChatGlassTheme.gold, size: 22),
    );
  }

  bool _isSelf(ChatUser user) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    return me != null && me == user.uid;
  }

  String _displayName(ChatUser user) {
    if (!_isSelf(user)) return user.name;
    final name = user.name.trim();
    if (name.isEmpty) return 'You';
    return '$name (You)';
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

/// Top chrome only (loading / error) — no duplicate scroll header.
class _ChatListStaticBody extends StatelessWidget {
  const _ChatListStaticBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final embedded = context
            .findAncestorWidgetOfExactType<ChatListScreen>()
            ?.embeddedInShell ??
        false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!embedded)
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: Stack(
              children: [
                ChatUnifiedHeaderBackdrop.layer(),
                const ChatTopGlassAppBar(),
              ],
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}

class _ArchivedRow extends StatelessWidget {
  const _ArchivedRow({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.archive_outlined,
                color: ChatGlassTheme.textSecondary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Archived',
                style: ChatGlassTheme.body(weight: FontWeight.w500),
              ),
            ),
            Text(
              '$count',
              style: ChatGlassTheme.accent(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

/// Returns at most the first two words of [name].
String _limitToTwoWords(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return parts.take(2).join(' ');
}
