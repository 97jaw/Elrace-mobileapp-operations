import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:el_race/core/ui/adaptive_glass.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../chat/chat.dart';
import '../../chat/services/chat_notification_service.dart';
import '../../core/utils/shared_pref.dart';
import 'chat_user_profile_screen.dart';
import 'chat_group_profile_screen.dart';
import 'screens/sign_zone_picker_screen.dart';
import 'theme/chat_glass_theme.dart';
import 'widgets/blue_geometric_background.dart';
import 'widgets/chat_merged_header.dart';
import 'widgets/chat_top_glass_app_bar.dart';
import 'widgets/chat_unified_header_backdrop.dart';
import 'widgets/message_bubble.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/typing_indicator.dart';

/// Chat screen for viewing and sending messages
class ChatScreen extends StatefulWidget {
  final String chatId;
  final String title;
  final ChatType chatType;
  final String? peerUid;
  final String? supportUserUid; // For support chats: the external user's UID
  final String?
      supportGroupTitle; // For support chats: the group title (e.g. "HR")
  final String? initialMessageId;
  final DateTime? initialMessageCreatedAt;
  final String? initialMessageSenderId;
  final String? initialMessageType;
  final String? initialMessageText;
  final String? initialMessageFileName;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.title,
    required this.chatType,
    this.peerUid,
    this.supportUserUid,
    this.supportGroupTitle,
    this.initialMessageId,
    this.initialMessageCreatedAt,
    this.initialMessageSenderId,
    this.initialMessageType,
    this.initialMessageText,
    this.initialMessageFileName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  String? _currentUid;
  bool _isRecording = false;
  bool _isMuted = false;
  Timer? _typingTimer;

  /// Peer user info (cached for avatar)
  ChatUser? _peerUser;

  /// Messages stream — recreatable if the chat doc is created after first open
  late Stream<List<Message>> _messagesStream;

  /// Cached broadcast streams (header + body must not create duplicate listeners).
  Stream<PresenceStatus>? _peerPresenceStream;
  late Stream<TypingInfo> _typingStream;

  /// Whether the stream has had an error (needs reconnect after first send)
  bool _streamErrored = false;

  /// Support chat state
  bool get _isSupportChat => widget.chatType == ChatType.support;
  bool get _isExternalUser =>
      _isSupportChat && widget.supportUserUid == _currentUid;

  /// Cache of member names for support chat (uid -> name)
  final Map<String, String> _memberNames = {};

  /// Starred message IDs (live from Firestore)
  Set<String> _starredIds = {};
  StreamSubscription? _starredSub;

  /// Reply state (WhatsApp-style)
  Message? _replyingTo;

  /// Optimistic (pending) messages — shown with clock icon until Firestore confirms
  final List<Message> _pendingMessages = [];

  /// Jump/highlight target when opened from starred messages.
  String? _targetMessageId;
  String? _highlightedMessageId;
  final Map<String, GlobalKey> _messageKeys = {};
  int _jumpRetryCount = 0;
  static const int _maxJumpRetries = 24;
  bool _isJumpInProgress = false;
  bool _isResolvingTargetMessage = false;
  Message? _resolvedTargetMessage;
  List<Message> _latestFirestoreMessages = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentUid = FirebaseAuth.instance.currentUser?.uid;
    _messagesStream = ChatRepository.instance
        .subscribeToMessages(
          widget.chatId,
          pageSize: widget.initialMessageId != null
              ? 1000
              : ChatRepository.defaultPageSize,
        )
        .asBroadcastStream();
    _typingStream = PresenceService.instance
        .subscribeToTypingWithNames(widget.chatId);
    if (widget.peerUid != null) {
      _peerPresenceStream = PresenceService.instance
          .subscribeToUserPresence(widget.peerUid!);
    }
    _targetMessageId = widget.initialMessageId;
    _markAsRead();
    _loadPeerUser();
    _messageController.addListener(_onTextChanged);

    // Set this chat as active to suppress notifications
    ChatNotificationService.instance.setActiveChatId(widget.chatId);
    // Cancel any pending notifications for this chat
    ChatNotificationService.instance.cancelNotificationsForChat(widget.chatId);

    // Defer non-critical loads so messages render first
    Future.microtask(() {
      if (!mounted) return;
      _loadMuteStatus();

      // Load member names for support chats (group members see real names)
      if (_isSupportChat && !_isExternalUser) {
        _loadSupportChatMemberNames();
      }

      // Subscribe to starred message IDs
      _starredSub =
          ChatRepository.instance.subscribeToStarredMessageIds().listen((ids) {
        if (mounted) setState(() => _starredIds = ids);
      });
    });
  }

  Future<void> _loadMuteStatus() async {
    final userChat = await ChatRepository.instance.getUserChat(widget.chatId);
    if (mounted && userChat != null) {
      setState(() => _isMuted = userChat.muted);
    }
  }

  /// Pre-load peer user for fast avatar rendering
  Future<void> _loadPeerUser() async {
    if (widget.peerUid == null) return;
    final user = await UserRepository.instance.getUserWithDirectoryFallback(
      widget.peerUid!,
      forceRefresh: true,
    );
    if (mounted && user != null) {
      setState(() => _peerUser = user);
    }
  }

  String get _displayTitle {
    if (widget.chatType == ChatType.dm) {
      final live = _peerUser?.name.trim();
      if (live != null && live.isNotEmpty) return live;
    }
    return widget.title;
  }

  /// Load member names for support chat so group members see who sent what
  Future<void> _loadSupportChatMemberNames() async {
    try {
      final members =
          await ChatRepository.instance.getChatMembers(widget.chatId);
      final uids = members.map((m) => m.uid).toList();
      final users = await UserRepository.instance.getUsersByIds(uids);
      if (mounted) {
        setState(() {
          for (final user in users) {
            _memberNames[user.uid] = user.name;
          }
        });
      }
    } catch (e) {
      print('⚠️ ChatScreen: Error loading support chat member names: $e');
    }
  }

  /// Get display name for a sender in support chat
  String _getSupportSenderName(String senderId) {
    if (_isExternalUser) {
      // External user: all non-self messages show group name
      if (senderId == _currentUid) return 'You';
      return widget.supportGroupTitle ?? widget.title;
    } else {
      // Group member: show real names
      if (senderId == _currentUid) return 'You';
      if (senderId == widget.supportUserUid) {
        return widget.title; // The external user's name
      }
      return _memberNames[senderId] ?? 'Team member';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _starredSub?.cancel();
    PresenceService.instance.setTyping(widget.chatId, false);

    // Leaving mid-recording (e.g. back navigation while holding the mic
    // button) previously left VoiceRecorderService's AudioRecorder active
    // with no widget left to stop it — the mic stayed "in use" indefinitely
    // (visible as iOS's persistent orange recording indicator) since
    // nothing ever called stop()/cancel() on the underlying AVAudioSession.
    if (VoiceRecorderService.instance.isRecording) {
      // ignore: unawaited_futures
      VoiceRecorderService.instance.cancelRecording();
    }

    // Clear active chat when leaving
    ChatNotificationService.instance.setActiveChatId(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markAsRead();
      return;
    }
    // Backgrounding mid-recording (switching apps, a call coming in,
    // locking the phone) left the recorder running with nothing to stop
    // it — same underlying bug as the dispose() case above, just triggered
    // by the app losing foreground instead of the screen closing.
    if ((state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        VoiceRecorderService.instance.isRecording) {
      debugPrint('🎙️ ChatScreen: cancelling in-progress recording on background');
      _cancelRecording();
    }
  }

  void _markAsRead() {
    ChatRepository.instance.markChatRead(widget.chatId);
  }

  void _onTextChanged() {
    if (_messageController.text.isNotEmpty) {
      PresenceService.instance.setTyping(widget.chatId, true);

      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        PresenceService.instance.setTyping(widget.chatId, false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Do NOT wrap the whole scaffold in presence StreamBuilder —
    // that was rebuilding the message list in a tight loop.
    return _buildChatScaffold();
  }

  Widget _buildChatScaffold() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BlueGeometricBackground(
        child: ChatIdProvider(
        chatId: widget.chatId,
        child: Column(
          children: [
            Expanded(
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: ChatConversationHeaderDelegate(
                        topBarExtent: ChatTopGlassAppBar.extent(context),
                        title: _displayTitle,
                        onBack: () => Navigator.of(context).pop(),
                        leading: GestureDetector(
                          onTap: (widget.chatType == ChatType.dm &&
                                  widget.peerUid != null)
                              ? _openPeerProfile
                              : _openGroupProfile,
                          behavior: HitTestBehavior.opaque,
                          child: _buildPresenceAwareAvatar(),
                        ),
                        subtitle: _buildPresenceAwareSubtitle(),
                        trailing: _buildConversationMenu(),
                      ),
                    ),
                  ];
                },
                body: Container(
                  color: Colors.transparent,
                  child: Stack(
                    children: [
                      Positioned.fill(
                          child: _buildChatBackgroundPattern()),
                      _buildMessageList(),
                    ],
                  ),
                ),
              ),
            ),
            _buildTypingIndicator(),
            _buildReplyBar(),
            Container(
              color: Colors.transparent,
              padding: EdgeInsets.only(
                bottom: (MediaQuery.of(context).padding.bottom / 2)
                    .clamp(0.0, 6.0),
              ),
              child: ChatInputBar(
                controller: _messageController,
                isLoading: false,
                isRecording: _isRecording,
                onSendText: _sendTextMessage,
                onPickImage: _pickImage,
                onPickGallery: _pickImagesFromGallery,
                onPickFile: _pickFile,
                onPickSignableDoc: _pickSignableDocument,
                onStartRecording: _startRecording,
                onStopRecording: _stopRecording,
                onCancelRecording: _cancelRecording,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget? _buildPresenceAwareSubtitle() {
    if (widget.chatType == ChatType.dm &&
        widget.peerUid != null &&
        _peerPresenceStream != null) {
      return StreamBuilder<PresenceStatus>(
        stream: _peerPresenceStream,
        builder: (context, snapshot) {
          return _buildPresenceStatusText(snapshot.data);
        },
      );
    }
    return _buildConversationSubtitle(null);
  }

  Widget _buildPresenceAwareAvatar() {
    if (widget.chatType == ChatType.dm && _peerPresenceStream != null) {
      return StreamBuilder<PresenceStatus>(
        stream: _peerPresenceStream,
        builder: (context, snapshot) {
          return _buildAvatar(isOnline: snapshot.data?.online ?? false);
        },
      );
    }
    return _buildAvatar();
  }

  Widget? _buildConversationSubtitle(PresenceStatus? presence) {
    if (widget.chatType == ChatType.dm && widget.peerUid != null) {
      return _buildPresenceStatusText(presence);
    }
    if (_isSupportChat) {
      return Text(
        _isExternalUser
            ? 'Department Support'
            : 'Support Chat • ${widget.supportGroupTitle ?? ""}',
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white70,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    return null;
  }

  Widget _buildConversationMenu() {
    return PopupMenuButton<String>(
      onSelected: _onMenuAction,
      color: const Color(0xFF1A2438),
      icon: const Icon(Icons.more_vert, color: Colors.white),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'mute',
          child: Row(
            children: [
              Icon(
                _isMuted ? Icons.volume_up : Icons.volume_off,
                color: ChatGlassTheme.silverLight,
              ),
              const SizedBox(width: 8),
              Text(
                _isMuted ? 'Unmute' : 'Mute',
                style: ChatGlassTheme.body(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar({bool isOnline = false}) {
    if (widget.chatType == ChatType.dm) {
      return FutureBuilder<ChatUser?>(
        future: widget.peerUid != null
            ? UserRepository.instance.getUserWithDirectoryFallback(
                widget.peerUid!,
              )
            : null,
        builder: (context, userSnapshot) {
          final avatarUrl =
              userSnapshot.data?.avatarUrl ?? _peerUser?.avatarUrl;
          final displayName =
              userSnapshot.data?.name ?? _peerUser?.name ?? widget.title;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(1.3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: ChatGlassTheme.avatarRing, width: 1.2),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFECECEC),
                  backgroundImage:
                      avatarUrl != null && avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Text(
                          _getInitials(displayName),
                          style: const TextStyle(
                            color: Color(0xFF2E2E2E),
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
        },
      );
    }
    // Group / Role / Support chats — show the RCC logo (same as chat list)
    return Container(
      padding: const EdgeInsets.all(1.3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ChatGlassTheme.avatarRing, width: 1.2),
      ),
      child: CircleAvatar(
        radius: 22,
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

  Widget _buildPresenceStatusText(PresenceStatus? status) {
    if (status == null) return const SizedBox.shrink();

    return Text(
      status.online ? 'Active now' : status.lastSeenText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        color: status.online ? const Color(0xFF6BE483) : Colors.white70,
        fontWeight: FontWeight.w500,
        height: 1.1,
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<List<Message>>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('📨 StreamBuilder: ERROR — ${snapshot.error}');
          _streamErrored = true;
        }

        final bool isWaiting =
            snapshot.connectionState == ConnectionState.waiting;
        final bool hasPending = _pendingMessages.isNotEmpty;

        // Show loading ONLY if no Firestore data yet AND no pending messages
        if (isWaiting && !hasPending) {
          return const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: ChatGlassTheme.gold,
              ),
            ),
          );
        }

        // Merge Firestore messages with optimistic pending messages.
        final firestoreMessages = snapshot.data ?? [];
        _latestFirestoreMessages = firestoreMessages;
        _deduplicatePendingMessages(firestoreMessages);
        final bool hasResolvedTarget = _resolvedTargetMessage != null &&
            !_pendingMessages.any((m) => m.id == _resolvedTargetMessage!.id) &&
            !firestoreMessages.any((m) => m.id == _resolvedTargetMessage!.id);

        final messages = [
          if (hasResolvedTarget) _resolvedTargetMessage!,
          ..._pendingMessages,
          ...firestoreMessages,
        ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // Only show empty state AFTER we got real data (not while loading)
        if (messages.isEmpty && !isWaiting) {
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  decoration: ChatGlassTheme.waterCardDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 52,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No messages yet',
                        style: ChatGlassTheme.body(
                          fontSize: 17,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start the conversation!',
                        style: ChatGlassTheme.muted(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        if (messages.isEmpty) {
          return const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: ChatGlassTheme.gold,
              ),
            ),
          );
        }

        final children = List.generate(messages.length, (index) {
          final message = messages[index];
          final isMe = message.senderId == _currentUid;
          final key = _messageKeys.putIfAbsent(message.id, () => GlobalKey());

          // Check if we should show date header
          final showDateHeader = _shouldShowDateHeader(messages, index);

          // For support chats, determine sender display name
          String? senderDisplayName;
          if (_isSupportChat && !isMe) {
            senderDisplayName = _getSupportSenderName(message.senderId);
          }

          return Column(
            key: key,
            children: [
              if (showDateHeader) _buildDateHeader(message.createdAt),
              MessageBubble(
                message: message,
                isMe: isMe,
                isStarred: _starredIds.contains(message.id),
                isHighlighted: _highlightedMessageId == message.id,
                senderName: senderDisplayName,
                showSenderName: _isSupportChat && !isMe,
                onStar: _onStarMessage,
                onReply: _onReplyMessage,
                onForward: _onForwardMessage,
              ),
            ],
          );
        });

        _attemptInitialJumpAndHighlight(messages);

        return ListView(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          children: children,
        );
      },
    );
  }

  void _attemptInitialJumpAndHighlight(List<Message> messages) {
    final target = _targetMessageId;
    if (target == null ||
        _isJumpInProgress ||
        _jumpRetryCount >= _maxJumpRetries) {
      return;
    }

    print('🔎 STAR_JUMP[chat]: attempt initial jump '
        'chatId=${widget.chatId} target=$target '
        'messages=${messages.length} keys=${_messageKeys.length} '
        'resolved=${_resolvedTargetMessage?.id} retry=$_jumpRetryCount');

    final found = messages.any((m) => m.id == target);
    if (!found) {
      print('🔎 STAR_JUMP[chat]: target not in rendered list, resolving... '
          'target=$target chatId=${widget.chatId}');
      _resolveMissingTargetMessage(target);
      return;
    }

    _isJumpInProgress = true;
    _jumpRetryCount = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _jumpToTargetWithRetry(target);
    });
  }

  Future<void> _resolveMissingTargetMessage(String target) async {
    if (_isResolvingTargetMessage || !mounted || _targetMessageId != target) {
      return;
    }

    print('🔎 STAR_JUMP[chat]: resolve missing target start '
        'chatId=${widget.chatId} target=$target '
        'createdAt=${widget.initialMessageCreatedAt} '
        'sender=${widget.initialMessageSenderId} '
        'type=${widget.initialMessageType} '
        'file=${widget.initialMessageFileName} '
        'textLen=${widget.initialMessageText?.length ?? 0}');

    _isResolvingTargetMessage = true;
    try {
      final message =
          await ChatRepository.instance.findMessageForStarredNavigation(
        widget.chatId,
        messageId: target,
        createdAt: widget.initialMessageCreatedAt,
        senderId: widget.initialMessageSenderId,
        type: widget.initialMessageType,
        text: widget.initialMessageText,
        fileName: widget.initialMessageFileName,
      );
      if (!mounted || _targetMessageId != target) return;

      if (message == null) {
        print('❌ STAR_JUMP[chat]: resolve failed, no target found '
            'chatId=${widget.chatId} target=$target');
        setState(() {
          _targetMessageId = null;
          _resolvedTargetMessage = null;
        });
        return;
      }

      print('✅ STAR_JUMP[chat]: resolve success '
          'chatId=${widget.chatId} target=$target resolvedId=${message.id} '
          'resolvedType=${message.type.toJson()} resolvedAt=${message.createdAt}');

      setState(() {
        _resolvedTargetMessage = message;
        _targetMessageId = message.id;
      });
    } finally {
      _isResolvingTargetMessage = false;
    }
  }

  Future<void> _jumpToTargetWithRetry(String target) async {
    if (!mounted) return;

    final key = _messageKeys[target];
    final ctx = key?.currentContext;
    if (ctx == null) {
      print('⚠️ STAR_JUMP[chat]: target widget context missing '
          'chatId=${widget.chatId} target=$target retry=$_jumpRetryCount');
      await _scheduleJumpRetry(target);
      return;
    }

    print('🔎 STAR_JUMP[chat]: ensureVisible '
        'chatId=${widget.chatId} target=$target retry=$_jumpRetryCount');

    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 320),
      alignment: 0.5,
      curve: Curves.easeOutCubic,
    );

    print('✅ STAR_JUMP[chat]: jump completed '
        'chatId=${widget.chatId} target=$target');

    setState(() {
      _highlightedMessageId = target;
      _targetMessageId = null;
      _isJumpInProgress = false;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_highlightedMessageId == target) {
        setState(() => _highlightedMessageId = null);
      }
    });
  }

  Future<void> _scheduleJumpRetry(String target) async {
    _jumpRetryCount += 1;
    if (_jumpRetryCount >= _maxJumpRetries) {
      print('❌ STAR_JUMP[chat]: retries exhausted '
          'chatId=${widget.chatId} target=$target max=$_maxJumpRetries');
      if (mounted) {
        setState(() {
          _isJumpInProgress = false;
          _targetMessageId = null;
          _resolvedTargetMessage = null;
        });
      }
      return;
    }

    // If the target widget is off-screen it may not be built yet.
    // Progressively scroll toward older messages (reverse list => larger pixels)
    // so Flutter builds more children, then retry ensureVisible.
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      final current = position.pixels;
      final max = position.maxScrollExtent;
      final step = (position.viewportDimension * 0.9).clamp(280.0, 1200.0);
      final next = (current + step).clamp(0.0, max);

      if (next > current) {
        print('🔎 STAR_JUMP[chat]: prebuild scroll '
            'chatId=${widget.chatId} target=$target '
            'from=${current.toStringAsFixed(1)} to=${next.toStringAsFixed(1)} '
            'max=${max.toStringAsFixed(1)}');
        await _scrollController.animateTo(
          next,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
        );
      }
    }

    print('⚠️ STAR_JUMP[chat]: scheduling retry '
        'chatId=${widget.chatId} target=$target retry=$_jumpRetryCount/$_maxJumpRetries');

    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToTargetWithRetry(target);
    });
  }

  Widget _buildChatBackgroundPattern() {
    // Lightweight static watermark — avoid GridView under NestedScrollView
    // which was contributing to expensive rebuilds/jank.
    final token = _watermarkToken();
    return IgnorePointer(
      child: Opacity(
        opacity: 0.06,
        child: Center(
          child: Transform.rotate(
            angle: -0.35,
            child: Text(
              '$token  $token  $token\n$token  $token  $token\n$token  $token  $token',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w700,
                color: ChatSurfaceTheme.watermark,
                height: 2.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _watermarkToken() {
    final loginData = SharedPref.getLoginDataOrNull();
    final empId = loginData?.result?.data?.emp_id;
    if (empId != null && empId.isNotEmpty) return empId;
    // fallback
    final raw = (_currentUid ?? widget.peerUid ?? widget.chatId).trim();
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty) {
      return digits.length > 4 ? digits.substring(digits.length - 4) : digits;
    }
    if (raw.length <= 4) return raw.toUpperCase();
    return raw.substring(raw.length - 4).toUpperCase();
  }

  bool _shouldShowDateHeader(List<Message> messages, int index) {
    if (index == messages.length - 1) return true;

    final current = messages[index].createdAt.toLocal();
    final previous = messages[index + 1].createdAt.toLocal();

    return current.day != previous.day ||
        current.month != previous.month ||
        current.year != previous.year;
  }

  Widget _buildDateHeader(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    String text;

    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      text = 'Today';
    } else if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day - 1) {
      text = 'Yesterday';
    } else {
      text = '${local.day}/${local.month}/${local.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: ChatSurfaceTheme.dateChipFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: ChatSurfaceTheme.dateChipText,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return StreamBuilder<TypingInfo>(
      stream: _typingStream,
      builder: (context, snapshot) {
        // Silently handle errors - typing is not critical
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final typingInfo = snapshot.data;

        if (typingInfo == null || !typingInfo.isTyping) {
          return const SizedBox.shrink();
        }

        return TypingIndicatorWidget(
          typingUserNames: typingInfo.typingNames,
          isGroupChat: widget.chatType != ChatType.dm,
        );
      },
    );
  }

  /// WhatsApp-style reply preview bar above input
  Widget _buildReplyBar() {
    if (_replyingTo == null) return const SizedBox.shrink();

    final message = _replyingTo!;
    final preview = message.getPreviewText();
    final isMyMessage = message.senderId == _currentUid;

    // Determine display name for the reply header
    String replyToName;
    if (isMyMessage) {
      replyToName = 'You';
    } else if (_isSupportChat) {
      replyToName = _getSupportSenderName(message.senderId);
    } else {
      replyToName = widget.title;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: isMyMessage
                  ? ChatGlassTheme.gold
                  : ChatSurfaceTheme.accentGold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  replyToName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ChatGlassTheme.gold,
                  ),
                  maxLines: null,
                  overflow: TextOverflow.visible,
                ),
                const SizedBox(height: 2),
                Text(
                  preview,
                  style: ChatGlassTheme.muted(fontSize: 13),
                  maxLines: null,
                  overflow: TextOverflow.visible,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _replyingTo = null),
            icon: const Icon(Icons.close, size: 20, color: Color(0xFF8E8E93)),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  void _onMenuAction(String action) {
    switch (action) {
      case 'mute':
        final newMuteState = !_isMuted;
        ChatRepository.instance.toggleMute(widget.chatId, newMuteState);
        setState(() => _isMuted = newMuteState);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newMuteState ? 'Chat muted' : 'Chat unmuted')),
        );
        break;
    }
  }

  /// Remove pending messages that already appeared in Firestore (dedup).
  /// Called from the StreamBuilder builder so duplicates are never shown.
  void _deduplicatePendingMessages(List<Message> firestoreMessages) {
    if (_pendingMessages.isEmpty || firestoreMessages.isEmpty) return;
    _pendingMessages.removeWhere((pending) {
      return firestoreMessages.any((fm) {
        if (fm.senderId != pending.senderId || fm.type != pending.type)
          return false;
        // For signable docs, match on fileName since text is null
        if (pending.type == MessageType.signableDoc) {
          return fm.fileName == pending.fileName;
        }
        return fm.text == pending.text;
      });
    });
  }

  /// Reconnect the messages stream if it previously errored
  /// (e.g. chat doc didn't exist yet, now created by _ensureDmChatExists).
  void _reconnectStreamIfNeeded() {
    if (_streamErrored && mounted) {
      _streamErrored = false;
      setState(() {
        _messagesStream = ChatRepository.instance
            .subscribeToMessages(widget.chatId)
            .asBroadcastStream();
      });
    }
  }

  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Capture reply state before clearing
    final replyTo = _replyingTo != null
        ? ReplyTo(
            messageId: _replyingTo!.id,
            senderId: _replyingTo!.senderId,
            text: _replyingTo!.getPreviewText(),
            type: _replyingTo!.type.toJson(),
          )
        : null;

    _messageController.clear();
    setState(() => _replyingTo = null);
    PresenceService.instance.setTyping(widget.chatId, false);

    // Create optimistic message with 'sending' status (shows clock icon)
    final optimistic = Message(
      id: 'pending_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _currentUid ?? '',
      type: MessageType.text,
      text: text,
      createdAt: DateTime.now(),
      clientMsgId: '',
      replyTo: replyTo,
      status: MessageStatus.sending,
    );

    setState(() {
      _pendingMessages.insert(0, optimistic);
    });
    _scrollToBottom();

    try {
      await ChatRepository.instance
          .sendText(widget.chatId, text, replyTo: replyTo);
      // Don't remove optimistic here — the StreamBuilder merge
      // will auto-deduplicate once the Firestore snapshot arrives.
      _reconnectStreamIfNeeded();
    } catch (e) {
      // Mark as failed so user sees error icon
      if (mounted) {
        setState(() {
          final idx = _pendingMessages.indexWhere((m) => m.id == optimistic.id);
          if (idx >= 0) {
            _pendingMessages[idx] =
                optimistic.copyWith(status: MessageStatus.failed);
          }
        });
      }
      _showError('Failed to send message');
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );

      if (image == null) return;

      // Optimistic UI - scroll immediately
      _scrollToBottom();

      await ChatRepository.instance.sendImage(
        widget.chatId,
        File(image.path),
      );
      _reconnectStreamIfNeeded();
    } catch (e) {
      _showError('Failed to send image');
    }
  }

  Future<void> _pickImagesFromGallery() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: 70,
      );

      if (images.isEmpty) return;

      _scrollToBottom();

      for (final image in images) {
        await ChatRepository.instance.sendImage(
          widget.chatId,
          File(image.path),
        );
      }
      _reconnectStreamIfNeeded();
    } catch (e) {
      _showError('Failed to send image');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles();
      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);

      // Optimistic UI - scroll immediately
      _scrollToBottom();

      await ChatRepository.instance.sendFile(
        widget.chatId,
        file,
        mimeType: result.files.single.extension,
      );
      _reconnectStreamIfNeeded();
    } catch (e) {
      _showError('Failed to send file');
    }
  }

  Future<void> _pickSignableDocument() async {
    try {
      // Pick PDF file only
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;

      // Navigate to sign zone picker
      if (!mounted) return;
      final pickerResult = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => SignZonePickerScreen(
            pdfFile: file,
            fileName: fileName,
          ),
        ),
      );

      if (pickerResult == null) {
        debugPrint('📝 SignableDoc: User cancelled sign zone picker');
        return;
      }

      debugPrint(
          '📝 SignableDoc: Got picker result, creating optimistic message...');
      final signZones = pickerResult['signZones'] as List<SignZone>;
      final pageCount = pickerResult['pageCount'] as int?;
      final fileSize = await file.length();

      // Create optimistic message with 'sending' status (shows upload indicator)
      final optimistic = Message(
        id: 'pending_${DateTime.now().millisecondsSinceEpoch}',
        senderId: _currentUid ?? '',
        type: MessageType.signableDoc,
        text: null,
        fileName: fileName,
        fileSize: fileSize,
        signZones: signZones,
        signStatus: SignStatus.pending,
        signExpiresInDays: 2,
        pageCount: pageCount,
        createdAt: DateTime.now(),
        clientMsgId: '',
        status: MessageStatus.sending,
        isUploading: true,
      );

      setState(() {
        _pendingMessages.insert(0, optimistic);
      });
      debugPrint('📝 SignableDoc: ✅ Optimistic message added! '
          'pendingMessages=${_pendingMessages.length}, '
          'fileName=$fileName, senderId=${_currentUid}');

      // Use post-frame callback to ensure scroll happens after layout
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });

      try {
        debugPrint('📝 SignableDoc: Starting upload...');
        // Send signable document (uploads PDF + writes to Firestore)
        await ChatRepository.instance.sendSignableDocument(
          widget.chatId,
          file,
          signZones: signZones,
          pageCount: pageCount,
        );
        debugPrint('📝 SignableDoc: ✅ Upload + Firestore write complete!');
        _reconnectStreamIfNeeded();
      } catch (e) {
        debugPrint('📝 SignableDoc: ❌ Upload failed: $e');
        // Mark as failed so user sees error icon
        if (mounted) {
          setState(() {
            final idx =
                _pendingMessages.indexWhere((m) => m.id == optimistic.id);
            if (idx >= 0) {
              _pendingMessages[idx] = optimistic.copyWith(
                status: MessageStatus.failed,
                isUploading: false,
              );
            }
          });
        }
        _showError('Failed to send document');
      }
    } catch (e) {
      _showError('Failed to pick document');
    }
  }

  Future<void> _startRecording() async {
    print('🎙️ ChatScreen: _startRecording called');

    final permission = await Permission.microphone.request();
    print('🎙️ ChatScreen: Microphone permission: ${permission.isGranted}');

    if (!permission.isGranted) {
      _showError('Please allow microphone permission');
      return;
    }

    final started = await VoiceRecorderService.instance.startRecording();
    print('🎙️ ChatScreen: Recording started: $started');

    if (started) {
      setState(() => _isRecording = true);
    } else {
      _showError('Failed to start recording');
    }
  }

  Future<void> _stopRecording() async {
    setState(() => _isRecording = false);

    final result = await VoiceRecorderService.instance.stopRecording();

    if (result == null) {
      _showError('Failed to save recording');
      return;
    }

    if (result.isTooShort) {
      _showError('Recording too short');
      return;
    }

    if (result.file != null) {
      // Optimistic UI - scroll immediately
      _scrollToBottom();

      try {
        await ChatRepository.instance.sendVoice(
          widget.chatId,
          result.file!,
          durationMs: result.durationMs,
        );
      } catch (e) {
        _showError('Failed to send voice message');
      }
    }
  }

  void _cancelRecording() async {
    await VoiceRecorderService.instance.cancelRecording();
    setState(() => _isRecording = false);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ── Message long-press actions ──

  void _onStarMessage(Message message) async {
    if (_highlightedMessageId != null) {
      setState(() => _highlightedMessageId = null);
    }

    // Pending messages don't exist in Firestore yet, so starring them stores
    // a non-canonical ID and breaks future jump-to-star behavior.
    Message canonical = message;
    if (message.id.startsWith('pending_')) {
      final createdAt = message.createdAt;
      final matches = _latestFirestoreMessages.where((m) {
        if (m.senderId != message.senderId || m.type != message.type) {
          return false;
        }
        if (message.type == MessageType.text &&
            (m.text ?? '') != (message.text ?? '')) {
          return false;
        }
        if ((message.type == MessageType.file ||
                message.type == MessageType.signableDoc) &&
            (m.fileName ?? '') != (message.fileName ?? '')) {
          return false;
        }
        final delta = m.createdAt.difference(createdAt).inSeconds.abs();
        return delta <= 20;
      }).toList()
        ..sort((a, b) =>
            a.createdAt.difference(createdAt).inMilliseconds.abs().compareTo(
                  b.createdAt.difference(createdAt).inMilliseconds.abs(),
                ));

      if (matches.isNotEmpty) {
        canonical = matches.first;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait a moment, then star this message again'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
    }

    final isCurrentlyStarred = _starredIds.contains(canonical.id);
    if (isCurrentlyStarred) {
      ChatRepository.instance.unstarMessage(canonical.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message unstarred'),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      ChatRepository.instance.starMessage(widget.chatId, canonical);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message starred'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _onReplyMessage(Message message) {
    setState(() => _replyingTo = message);
    // Focus the text field
    // Delay slightly to ensure the reply bar is rendered first
    Future.delayed(const Duration(milliseconds: 100), () {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  void _onForwardMessage(Message message) {
    // Show a bottom sheet to pick a chat to forward to
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const Text(
                  'Forward to...',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<UserChat>>(
                  stream: ChatRepository.instance
                      .subscribeToUserChats(_currentUid!),
                  builder: (ctx, snap) {
                    final chats = snap.data ?? [];
                    if (chats.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No chats available'),
                      );
                    }
                    return SizedBox(
                      height: 280,
                      child: ListView.builder(
                        itemCount: chats.length,
                        itemBuilder: (_, i) {
                          final chat = chats[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFECECEC),
                              child: Text(
                                _getInitials(chat.title ?? '?'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2E2E2E),
                                ),
                              ),
                            ),
                            title: Text(
                              chat.title ?? 'Chat',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            onTap: () async {
                              Navigator.pop(sheetCtx);
                              try {
                                final text = message.getPreviewText();
                                await ChatRepository.instance.sendText(
                                  chat.chatId,
                                  text,
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Message forwarded'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted)
                                  _showError('Failed to forward message');
                              }
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openPeerProfile() {
    final peerUid = widget.peerUid;
    if (peerUid == null || widget.chatType != ChatType.dm) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatUserProfileScreen(
          chatId: widget.chatId,
          peerUid: peerUid,
          fallbackName: _displayTitle,
        ),
      ),
    );
  }

  void _openGroupProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatGroupProfileScreen(
          chatId: widget.chatId,
          title: widget.title,
          chatType: widget.chatType,
          supportGroupTitle: widget.supportGroupTitle,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
