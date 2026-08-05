import 'dart:async';

import 'package:el_race/core/ui/adaptive_glass.dart';
import 'package:el_race/ui/chat/theme/chat_glass_theme.dart';
import 'package:el_race/ui/chat/widgets/blue_geometric_background.dart';
import 'package:el_race/ui/chat/widgets/chat_glass_button.dart';
import 'package:el_race/ui/chat/widgets/chat_top_glass_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../chat/models/chat.dart';
import '../../chat/models/chat_user.dart';
import '../../chat/repositories/chat_repository.dart';
import '../../chat/repositories/user_repository.dart';
import '../../chat/services/presence_service.dart';
import 'chat_screen.dart';

/// Screen for searching users and starting a new DM chat
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<ChatUser> _searchResults = [];
  List<Chat> _availableGroups = []; // Role groups available for support chat
  List<Chat> _filteredGroups = []; // Filtered by search query
  bool _isSearching = false;
  String _errorMessage = '';
  Timer? _debounce;

  String? _currentUid;
  ChatUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid;
    _loadCurrentUser();
    _searchController.addListener(_onSearchChanged);

    // Auto-focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  Future<void> _loadCurrentUser() async {
    if (_currentUid != null) {
      _currentUser = await UserRepository.instance.getUser(_currentUid!);
    }
    // Load available groups for support chat
    _loadAvailableGroups();
  }

  Future<void> _loadAvailableGroups() async {
    try {
      final groups = await ChatRepository.instance.getAvailableSupportGroups();
      if (mounted) {
        setState(() {
          _availableGroups = groups;
          _filteredGroups = groups;
        });
      }
    } catch (e) {
      print('⚠️ NewChatScreen: Error loading available groups: $e');
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch();
    });
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _filteredGroups = _availableGroups;
        _errorMessage = '';
      });
      return;
    }

    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _filteredGroups = _availableGroups
            .where((g) => (g.title ?? '').toLowerCase().contains(query))
            .toList();
        _errorMessage = 'أدخل حرفين على الأقل للبحث';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = '';
    });

    try {
      final result = await UserRepository.instance.searchUsers(query: query);

      // Include self so users can "Message yourself" (WhatsApp-style).
      final filteredResults = result.users;

      // Filter groups by search query
      final matchingGroups = _availableGroups
          .where((g) => (g.title ?? '').toLowerCase().contains(query))
          .toList();

      setState(() {
        _searchResults = filteredResults;
        _filteredGroups = matchingGroups;
        _isSearching = false;
        if (filteredResults.isEmpty && matchingGroups.isEmpty) {
          _errorMessage = 'No results found';
        }
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _errorMessage = 'Search error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BlueGeometricBackground(
        child: Column(
          children: [
            const ChatTopGlassAppBar(),
            Expanded(
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
                      child: Row(
                        children: [
                          ChatGlassIconButton(
                            icon: Icons.arrow_back_ios_new,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'New chat',
                              style: ChatGlassTheme.title(fontSize: 22),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: AdaptiveGlassLayer(
                        borderRadius: BorderRadius.circular(22),
                        sigma: 12,
                        fallbackColor: ChatGlassTheme.waterFillStrong,
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          style: ChatGlassTheme.body(),
                          cursorColor: Colors.white,
                          decoration: InputDecoration(
                            hintText: 'Search for a user...',
                            hintStyle: ChatGlassTheme.muted(),
                            prefixIcon: const Icon(Icons.search,
                                color: Colors.white),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear,
                                        color: Colors.white),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchResults = [];
                                        _errorMessage = '';
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: ChatGlassTheme.waterFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: _buildBody()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_searchController.text.isEmpty) {
      // Show available groups when not searching
      if (_availableGroups.isNotEmpty) {
        return _buildGroupsAndEmptyState();
      }
      return _buildEmptyState();
    }

    if (_errorMessage.isNotEmpty &&
        _searchResults.isEmpty &&
        _filteredGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off,
                size: 60, color: Colors.white.withValues(alpha: 0.85)),
            const SizedBox(height: 16),
            Text(_errorMessage, style: ChatGlassTheme.muted()),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (_filteredGroups.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Departments', style: ChatGlassTheme.accent()),
          ),
          ..._filteredGroups.map((group) => _GroupSupportTile(
                group: group,
                onTap: () => _startSupportChat(group),
              )),
          if (_searchResults.isNotEmpty)
            Divider(
                height: 16,
                indent: 16,
                endIndent: 16,
                color: Colors.white.withValues(alpha: 0.1)),
        ],
        if (_searchResults.isNotEmpty) ...[
          if (_filteredGroups.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text('Users', style: ChatGlassTheme.accent()),
            ),
          ..._searchResults.map((user) => _UserListTile(
                user: user,
                onTap: () => _startChat(user),
              )),
        ],
      ],
    );
  }

  Widget _buildGroupsAndEmptyState() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('Contact Department', style: ChatGlassTheme.accent()),
        ),
        ..._availableGroups.map((group) => _GroupSupportTile(
              group: group,
              onTap: () => _startSupportChat(group),
            )),
        const SizedBox(height: 24),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: AdaptiveGlassLayer(
              borderRadius: BorderRadius.circular(18),
              sigma: 16,
              fallbackColor: ChatGlassTheme.waterFillStrong,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                decoration: ChatGlassTheme.waterCardDecoration(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.person_search,
                      size: 48,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Or search for a user',
                      style: ChatGlassTheme.body(weight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: AdaptiveGlassLayer(
          borderRadius: BorderRadius.circular(20),
          sigma: 18,
          fallbackColor: ChatGlassTheme.waterFillStrong,
          fallbackBorder: Border.all(
            color: Colors.white.withValues(alpha: 0.38),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: ChatGlassTheme.waterCardDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_search,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
                const SizedBox(height: 20),
                Text(
                  'Search for a user',
                  style: ChatGlassTheme.body(
                    fontSize: 18,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You can search by name or email',
                  textAlign: TextAlign.center,
                  style: ChatGlassTheme.muted(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

      // Pop loading dialog
      if (mounted) Navigator.of(context).pop();

      // Navigate to chat screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              title: group.title ?? 'Group ${group.roleId}',
              chatType: ChatType.support,
            ),
          ),
        );
      }
    } catch (e) {
      // Pop loading dialog
      if (mounted) Navigator.of(context).pop();

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

  Future<void> _startChat(ChatUser user) async {
    if (_currentUid == null) {
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
      // Create or get DM chat
      final chatId = await ChatRepository.instance.createOrGetDmChat(
        otherUid: user.uid,
        otherName: user.name,
        currentUserName: _currentUser?.name ?? 'User',
        otherRoleId: user.roleId,
        otherBranchId: user.branchId,
        otherCompanyId: user.companyId,
        currentUserRoleId: _currentUser?.roleId,
        currentUserBranchId: _currentUser?.branchId,
        currentUserCompanyId: _currentUser?.companyId,
      );

      // Pop loading dialog
      if (mounted) Navigator.of(context).pop();

      // Navigate to chat screen
      if (mounted) {
        final isSelf = user.uid == _currentUid;
        final title = isSelf
            ? (user.name.trim().isNotEmpty ? '${user.name} (You)' : 'You')
            : user.name;
        Navigator.of(context).pushReplacement(
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
    } catch (e) {
      // Pop loading dialog
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _UserListTile extends StatelessWidget {
  final ChatUser user;
  final VoidCallback onTap;

  const _UserListTile({
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: AdaptiveGlassLayer(
        borderRadius: BorderRadius.circular(16),
        sigma: 16,
        fallbackColor: ChatGlassTheme.waterFillStrong,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: ChatGlassTheme.waterCardDecoration(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      backgroundImage: user.avatarUrl != null
                          ? NetworkImage(user.avatarUrl!)
                          : null,
                      child: user.avatarUrl == null
                          ? Text(
                              _getInitials(user.name),
                              style: ChatGlassTheme.body(
                                weight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    StreamBuilder<PresenceStatus>(
                      stream: PresenceService.instance
                          .subscribeToUserPresence(user.uid),
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
                              border:
                                  Border.all(color: Colors.white, width: 2),
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
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isSelf(user)
                          ? 'Message yourself'
                          : (user.email ?? ''),
                      style: ChatGlassTheme.muted(fontSize: 13),
                    ),
                    if (!_isSelf(user))
                      Row(
                        children: [
                          Icon(Icons.work_outline,
                              size: 12,
                              color: Colors.white.withValues(alpha: 0.7)),
                          const SizedBox(width: 4),
                          Text(
                            'Role: ${user.roleId}',
                            style: ChatGlassTheme.muted(fontSize: 12),
                          ),
                        ],
                      ),
                  ],
                ),
                isThreeLine: !_isSelf(user),
                trailing: Icon(
                  Icons.message,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
        ),
      ),
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

/// Tile for department groups available for support chat
class _GroupSupportTile extends StatelessWidget {
  final Chat group;
  final VoidCallback onTap;

  const _GroupSupportTile({
    required this.group,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: AdaptiveGlassLayer(
        borderRadius: BorderRadius.circular(16),
        sigma: 16,
        fallbackColor: ChatGlassTheme.waterFillStrong,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: ChatGlassTheme.waterCardDecoration(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(1.3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: ChatGlassTheme.avatarRing, width: 1.2),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    child: Icon(
                      Icons.support_agent_rounded,
                      color: Colors.white.withValues(alpha: 0.95),
                      size: 26,
                    ),
                  ),
                ),
                title: Text(
                  group.title ?? 'Group ${group.roleId}',
                  style: ChatGlassTheme.body(weight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Contact department',
                  style: ChatGlassTheme.muted(fontSize: 13),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
