import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../chat/chat.dart';
import '../../resources/app_colors.dart';
import 'chat_screen.dart';
import 'widgets/chat_merged_header.dart';
import 'widgets/chat_sub_app_glass_bar.dart';
import 'widgets/chat_unified_header_backdrop.dart';
import 'widgets/typing_indicator.dart';

/// Main chat list screen showing all user's conversations
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  String? _currentUid;
  bool _isChatAvailable = false;
  bool _isInitializing = false;
  final ValueNotifier<bool> _searchExpandedNotifier = ValueNotifier(false);

  final TextEditingController _localSearchController = TextEditingController();
  final ValueNotifier<String> _searchNotifier = ValueNotifier('');
  Timer? _debounce;

  // Tab state for Groups / Support — ValueNotifier so only tab section rebuilds
  final ValueNotifier<int> _topTabNotifier =
      ValueNotifier(0); // 0 = Groups, 1 = Support
  List<Chat> _supportGroups = [];

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
    _topTabNotifier.dispose();
    _searchExpandedNotifier.dispose();
    _globalResultsNotifier.dispose();
    _globalSearchingNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    if (_currentUid != null) {
      _currentUser = await UserRepository.instance.getUser(_currentUid!);
    }
    // Load support groups for the Support tab
    _loadSupportGroups();
  }

  Future<void> _loadSupportGroups() async {
    try {
      final groups = await ChatRepository.instance.getAllRoleGroups();
      if (mounted) {
        setState(() {
          _supportGroups = groups;
        });
      }
    } catch (e) {
      print('⚠️ ChatListScreen: Error loading support groups: $e');
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
      final filtered = result.users.where((u) => u.uid != _currentUid).toList();
      if (mounted) {
        _globalResultsNotifier.value = filtered;
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
        backgroundColor: Colors.white,
        body: _ChatListStaticBody(
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (!_isChatAvailable || _currentUid == null) {
      return Scaffold(
        backgroundColor: Colors.white,
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
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  ChatModuleHelper.instance.getStatusMessage(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _initializeChat,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              // Show logout button if error mentions session expired
              if (ChatModuleHelper.instance
                      .getStatusMessage()
                      .contains('expired') ||
                  ChatModuleHelper.instance
                      .getStatusMessage()
                      .contains('login again'))
                TextButton.icon(
                  onPressed: () {
                    // Navigate to logout or login screen
                    Navigator.of(context).pushReplacementNamed('/signIN');
                  },
                  icon: const Icon(Icons.logout, size: 20),
                  label: const Text('Logout & Login Again'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<List<UserChat>>(
              stream: _userChatsStream ??=
                  ChatRepository.instance.subscribeToUserChats(_currentUid!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 56, color: Colors.red[300]),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Error: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Filter out chats that have no messages sent yet
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
                }

                final groups = allChats
                    .where((c) =>
                        c.type == ChatType.role || c.type == ChatType.group)
                    .toList();

                return NestedScrollView(
                  floatHeaderSlivers: true,
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      ValueListenableBuilder<bool>(
                        valueListenable: _searchExpandedNotifier,
                        builder: (context, _, __) {
                          return SliverPersistentHeader(
                            pinned: true,
                            delegate: ChatListHeaderDelegate(
                              topBarExtent: SubAppGlassAppBar.extent(context),
                              tabIndexListenable: _topTabNotifier,
                              groups: groups,
                              supportGroups: _supportGroups,
                              searchController: _localSearchController,
                              searchExpanded: _searchExpandedNotifier,
                              onTabChanged: (i) => _topTabNotifier.value = i,
                              onGroupTap: _openChat,
                              onSupportTap: _startSupportChat,
                              onSearchClear: () {
                                _globalResultsNotifier.value = [];
                                _globalSearchingNotifier.value = false;
                              },
                            ),
                          );
                        },
                      ),
                    ];
                  },
                  body: CustomScrollView(
                    slivers: [
                      // White card header (drag handle)
                      SliverToBoxAdapter(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(30)),
                          ),
                          padding: const EdgeInsets.only(top: 9, bottom: 8),
                          alignment: Alignment.center,
                          child: Container(
                            width: 70,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                      // Chat list items — only this section rebuilds on search
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
                                      child: Container(
                                        color: Colors.white,
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
                                                allChats.isEmpty
                                                    ? 'No chats yet'
                                                    : 'No results',
                                                style: TextStyle(
                                                    fontSize: 17,
                                                    color: Colors.grey[700]),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  // Build combined list: filtered chats + global user results
                                  final List<Widget> items = [];

                                  for (var i = 0; i < filteredChats.length; i++) {
                                    final userChat = filteredChats[i];
                                    items.add(
                                      Container(
                                        color: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12),
                                        child: _ChatListTile(
                                          userChat: userChat,
                                          currentUid: _currentUid!,
                                          onTap: () => _openChat(userChat),
                                        ),
                                      ),
                                    );
                                    if (i < filteredChats.length - 1) {
                                      items.add(
                                        Container(
                                          color: Colors.white,
                                          padding:
                                              const EdgeInsets.only(left: 68),
                                          child: const Divider(
                                            height: 1,
                                            thickness: 1,
                                            color: Color(0xFFE5E5E5),
                                          ),
                                        ),
                                      );
                                    }
                                  }

                                  // Show global search results when searching
                                  if (hasQuery &&
                                      (isGlobalSearching || hasGlobalResults)) {
                                    items.add(
                                      Container(
                                        color: Colors.white,
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
                                        Container(
                                          color: Colors.white,
                                          child: _InlineUserTile(
                                            user: user,
                                            onTap: () =>
                                                _startChatWithUser(user),
                                          ),
                                        ),
                                      );
                                    }

                                    if (!isGlobalSearching &&
                                        globalResults.isEmpty) {
                                      items.add(
                                        Container(
                                          color: Colors.white,
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
                                      child: Container(
                                        color: Colors.white,
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
                      // Fill remaining space with white
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Container(color: Colors.white),
                      ),
                      // Bottom safe area padding (iOS home indicator)
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: (MediaQuery.of(context).padding.bottom / 2).clamp(0.0, 6.0),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _openChat(UserChat userChat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: userChat.chatId,
          title: userChat.title ?? 'Chat',
          chatType: userChat.type,
          peerUid: userChat.peerUid,
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

    // Generate chat ID deterministically
    final chatId = Chat.generateDmChatId(_currentUid!, user.uid);

    _localSearchController.clear();

    // Just navigate to chat screen — the chat doc will be created
    // when the first message is sent via ChatRepository.sendText
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chatId,
            title: user.name,
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
        ? UserRepository.instance.getUser(userChat.peerUid!)
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

            return InkWell(
              onTap: widget.onTap,
              onLongPress: () => _showChatActions(context),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildAvatar(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // For DM chats, always show the peer's actual name
                          // from the users collection (avoids showing role name duplicates)
                          if (userChat.type == ChatType.dm &&
                              userChat.peerUid != null)
                            FutureBuilder<ChatUser?>(
                              future: _peerUserFuture,
                              builder: (context, snap) {
                                final rawName = snap.data?.name ??
                                    userChat.title ??
                                    'Chat';
                                final displayName = _limitToTwoWords(rawName);
                                return Text(
                                  displayName,
                                  style:
                                      theme.textTheme.titleMedium?.copyWith(
                                    color: const Color(0xFF171717),
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
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: const Color(0xFF171717),
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          const SizedBox(height: 4),
                          DefaultTextStyle.merge(
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF8B8B8B),
                              fontWeight:
                                  hasUnread ? FontWeight.w600 : FontWeight.w400,
                            ),
                            child: isTyping
                                ? TypingTextWidget(
                                    typingUserNames: typingInfo!.typingNames,
                                    isGroupChat: userChat.type != ChatType.dm,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF20B051),
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
                                    ? const Color(0xFF8C8C8C)
                                    : const Color(0xFFAAAAAA),
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
                                      color: Color(0xFF8E8E93),
                                    ),
                                  ),
                                if (userChat.muted)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(
                                      Icons.volume_off,
                                      size: 14,
                                      color: Color(0xFF8E8E93),
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
                                          ? const Color(0xFFB0B0B0)
                                          : const Color(0xFFF04D57),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      unreadCount > 99 ? '99+' : '$unreadCount',
                                      style: const TextStyle(
                                        color: Colors.white,
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
                  backgroundColor: const Color(0xFFECECEC),
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Text(
                          _getInitials(peerUser?.name ?? userChat.title ?? '?'),
                          style: const TextStyle(
                            color: Color(0xFF2E2E2E),
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
        backgroundColor: Colors.white,
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
            border: Border.all(color: const Color(0xFFE9B23A), width: 1.8),
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
        maxLines: null,
        overflow: TextOverflow.visible,
      );
    }

    String text;

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
      default:
        text = lastMessage.text;
    }

    return Text(
      text,
      maxLines: null,
      overflow: TextOverflow.visible,
    );
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
      color: Colors.white,
      items: [
        PopupMenuItem<String>(
          value: 'pin',
          height: 48,
          child: Row(
            children: [
              Icon(
                userChat.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: const Color(0xFF8E8E93),
                size: 22,
              ),
              const SizedBox(width: 14),
              Text(
                userChat.pinned ? 'Unpin' : 'Pin',
                style: const TextStyle(
                  color: Color(0xFF2C2C2E),
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
                color: const Color(0xFF8E8E93),
                size: 22,
              ),
              const SizedBox(width: 14),
              Text(
                userChat.muted ? 'Unmute' : 'Mute',
                style: const TextStyle(
                  color: Color(0xFF2C2C2E),
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
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
      }
    });
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
            backgroundColor: AppColors.primaryBlackLight,
            backgroundImage: user.avatarUrl != null
                ? CachedNetworkImageProvider(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null
                ? Text(
                    _getInitials(user.name),
                    style: const TextStyle(
                      color: AppColors.primaryColor,
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
        user.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: user.email != null
          ? Text(
              user.email!,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            )
          : null,
      trailing: const Icon(Icons.message_rounded,
          color: AppColors.primaryColor, size: 22),
    );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          child: Stack(
            children: [
              ChatUnifiedHeaderBackdrop.layer(),
              const SubAppGlassAppBar(),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// Returns at most the first two words of [name].
String _limitToTwoWords(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return parts.take(2).join(' ');
}
