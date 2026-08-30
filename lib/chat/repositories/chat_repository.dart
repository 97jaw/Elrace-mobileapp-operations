import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../services/chat_notification_service.dart';
import '../services/firebase_chat_auth_service.dart';
import '../services/presence_service.dart';
import 'user_repository.dart';

/// Repository for chat-related Firestore and Storage operations.
///
/// Handles:
/// - DM creation and management
/// - Role chat setup
/// - Message sending (text, image, file, audio)
/// - Message streaming with pagination
/// - Read receipts
/// - User chat list management
class ChatRepository {
  static ChatRepository? _instance;
  static ChatRepository get instance => _instance ??= ChatRepository._();

  ChatRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  // Configuration
  static const bool groupByBranch = true; // Group role chats by branch/city
  static const int defaultPageSize = 25;

  // Collection references
  CollectionReference<Map<String, dynamic>> get _chatsCollection =>
      _firestore.collection('chats');

  CollectionReference<Map<String, dynamic>> _userChatsCollection(String uid) =>
      _firestore.collection('userChats').doc(uid).collection('chats');

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  /// Ensure Firebase Auth is ready before Storage / Firestore chat writes.
  Future<void> _ensureFirebaseAuth() async {
    final user =
        await FirebaseChatAuthService.instance.ensureAuthenticated();
    await user.getIdToken(true);
  }

  // ============== DM Chat Creation ==============

  /// Create or get an existing DM chat between two users.
  /// Returns the chat ID.
  Future<String> createOrGetDmChat({
    required String otherUid,
    required String otherName,
    required String currentUserName,
    int? otherRoleId,
    int? otherBranchId,
    int? otherCompanyId,
    int? currentUserRoleId,
    int? currentUserBranchId,
    int? currentUserCompanyId,
  }) async {
    await _ensureFirebaseAuth();
    final currentUid = _currentUid;
    if (currentUid == null) {
      throw Exception('Not authenticated');
    }

    final chatId = Chat.generateDmChatId(currentUid, otherUid);
    final dmPair = Chat.getSortedDmPair(currentUid, otherUid);
    final isSelfChat = currentUid == otherUid;

    try {
      final batch = _firestore.batch();

      // Create/update chat document
      final chatRef = _chatsCollection.doc(chatId);
      batch.set(
          chatRef,
          {
            'type': 'dm',
            'dm_pair': isSelfChat ? [currentUid, currentUid] : dmPair,
            'member_ids': FieldValue.arrayUnion(
                isSelfChat ? [currentUid] : dmPair.toSet().toList()),
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      // Create member documents for both users (one write for self-chat)
      final currentMemberRef = chatRef.collection('members').doc(currentUid);
      batch.set(
          currentMemberRef,
          {
            'joined_at': FieldValue.serverTimestamp(),
            'role_id_snapshot': currentUserRoleId,
            'branch_id_snapshot': currentUserBranchId,
            'company_id_snapshot': currentUserCompanyId,
            'muted': false,
          },
          SetOptions(merge: true));

      if (!isSelfChat) {
        final otherMemberRef = chatRef.collection('members').doc(otherUid);
        batch.set(
            otherMemberRef,
            {
              'joined_at': FieldValue.serverTimestamp(),
              'role_id_snapshot': otherRoleId,
              'branch_id_snapshot': otherBranchId,
              'company_id_snapshot': otherCompanyId,
              'muted': false,
            },
            SetOptions(merge: true));
      }

      // NOTE: userChats entries are NOT created here.
      // They will be created when the first message is sent
      // (via _ensureDmChatExists / sendText / _sendMedia).
      // This prevents empty chats from appearing in the chat list.

      await batch.commit();
      print('✅ ChatRepository: Created/updated DM chat $chatId');

      return chatId;
    } catch (e) {
      print('❌ ChatRepository: Error creating DM chat: $e');
      rethrow;
    }
  }

  // ============== Role Chat Setup ==============

  /// Ensure role chat exists and current user is a member.
  /// Called during chat setup after login.
  Future<String> ensureRoleChatMembership({
    required String uid,
    required int roleId,
    int? branchId,
    int? companyId,
    String? roleChatId, // Backend-provided chat ID
    String? title, // Optional title for the group
  }) async {
    // Determine chat ID
    final chatId = roleChatId ??
        Chat.generateRoleChatId(
          roleId: roleId,
          branchId: branchId,
          groupByBranch: groupByBranch,
        );

    // Generate default title - use provided title (role name) or fallback to role ID
    final groupTitle = title ??
        'مجموعة $roleId${groupByBranch && branchId != null ? ' - فرع $branchId' : ''}';

    try {
      final batch = _firestore.batch();

      // Create/update role chat document
      final chatRef = _chatsCollection.doc(chatId);
      batch.set(
          chatRef,
          {
            'type': 'role',
            'role_id': roleId,
            'branch_id': branchId,
            'company_id': companyId,
            'title': groupTitle,
            'member_ids': FieldValue.arrayUnion([uid]),
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      // Add current user as member
      final memberRef = chatRef.collection('members').doc(uid);
      batch.set(
          memberRef,
          {
            'joined_at': FieldValue.serverTimestamp(),
            'role_id_snapshot': roleId,
            'branch_id_snapshot': branchId,
            'company_id_snapshot': companyId,
            'muted': false,
          },
          SetOptions(merge: true));

      // Create userChats entry for current user
      final userChatRef = _userChatsCollection(uid).doc(chatId);
      batch.set(
          userChatRef,
          {
            'type': 'role',
            'role_id': roleId,
            'branch_id': branchId,
            'company_id': companyId,
            'title': groupTitle,
            'updated_at': FieldValue.serverTimestamp(),
            'pinned': false,
            'muted': false,
          },
          SetOptions(merge: true));

      await batch.commit();
      print(
          '✅ ChatRepository: Ensured role chat membership for $uid in $chatId');

      // Cleanup: remove old non-branch role chat if we switched to groupByBranch
      if (groupByBranch && branchId != null) {
        final oldChatId = 'role_$roleId';
        if (oldChatId != chatId) {
          try {
            final oldUserChatDoc =
                await _userChatsCollection(uid).doc(oldChatId).get();
            if (oldUserChatDoc.exists) {
              await _userChatsCollection(uid).doc(oldChatId).delete();
              // Also remove user from old chat members
              await _chatsCollection
                  .doc(oldChatId)
                  .collection('members')
                  .doc(uid)
                  .delete();
              await _chatsCollection.doc(oldChatId).update({
                'member_ids': FieldValue.arrayRemove([uid]),
              });
              print(
                  '🧹 ChatRepository: Cleaned up old role chat $oldChatId for $uid');
            }
          } catch (e) {
            print(
                '⚠️ ChatRepository: Could not cleanup old role chat: $e');
          }
        }
      }

      return chatId;
    } catch (e) {
      print('❌ ChatRepository: Error ensuring role chat membership: $e');
      rethrow;
    }
  }

  // ============== Chat List ==============

  // ============== Support Chat (Helpdesk) ==============

  /// Create or get a support chat between a user and a department group.
  /// The user sees it as a DM with the group name.
  /// Group members see it as individual conversations per user (ticket-style).
  /// Group members can reply anonymously (user sees group name, not individual).
  Future<String> createOrGetSupportChat({
    required String userUid,
    required String userName,
    required int targetRoleId,
    required String groupTitle, // e.g. "HR"
    String? sourceRoleChatId,
    String? supportGroupKey,
    int? userRoleId,
    int? userBranchId,
    int? userCompanyId,
  }) async {
    final normalizedGroupKey = _normalizeSupportGroupKey(supportGroupKey);
    final chatId = (normalizedGroupKey != null)
        ? 'support_${normalizedGroupKey}_$userUid'
        : Chat.generateSupportChatId(
            roleId: targetRoleId,
            userUid: userUid,
          );

    try {
      final batch = _firestore.batch();

      // Create/update support chat document
      final chatRef = _chatsCollection.doc(chatId);
      batch.set(
          chatRef,
          {
            'type': 'support',
            'role_id': targetRoleId,
            'support_user_uid': userUid,
            'title': groupTitle,
            'member_ids': FieldValue.arrayUnion([userUid]),
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      // Add the external user as member
      final userMemberRef = chatRef.collection('members').doc(userUid);
      batch.set(
          userMemberRef,
          {
            'joined_at': FieldValue.serverTimestamp(),
            'role_id_snapshot': userRoleId,
            'branch_id_snapshot': userBranchId,
            'company_id_snapshot': userCompanyId,
            'muted': false,
            'is_support_user': true, // Mark as the external user
          },
          SetOptions(merge: true));

      // Create userChats entry for the external user (sees group name)
      final userChatRef = _userChatsCollection(userUid).doc(chatId);
      batch.set(
          userChatRef,
          {
            'type': 'support',
            'role_id': targetRoleId,
            'title': groupTitle, // User sees "HR Group"
            'support_user_uid': userUid,
            'support_group_title': groupTitle,
            'updated_at': FieldValue.serverTimestamp(),
            'pinned': false,
            'muted': false,
          },
          SetOptions(merge: true));

      await batch.commit();

      // Now add all role group members to this support chat
      await _addRoleMembersToSupportChat(
        chatId: chatId,
        targetRoleId: targetRoleId,
        userName: userName,
        userUid: userUid,
        groupTitle: groupTitle,
        sourceRoleChatId: sourceRoleChatId,
      );

      print('✅ ChatRepository: Created/updated support chat $chatId');
      return chatId;
    } catch (e) {
      print('❌ ChatRepository: Error creating support chat: $e');
      rethrow;
    }
  }

  /// Add all members of a role group to a support chat.
  /// Each group member sees the chat titled with the user's name (ticket-style).
  Future<void> _addRoleMembersToSupportChat({
    required String chatId,
    required int targetRoleId,
    required String userName,
    required String userUid,
    required String groupTitle,
    String? sourceRoleChatId,
  }) async {
    try {
      // Find the role chat to get its members
      final roleChatId =
          sourceRoleChatId ?? Chat.generateRoleChatId(roleId: targetRoleId);
      final membersSnapshot =
          await _chatsCollection.doc(roleChatId).collection('members').get();

      if (membersSnapshot.docs.isEmpty) {
        print('⚠️ ChatRepository: No members found in role chat $roleChatId');
        return;
      }

      final batch = _firestore.batch();
      final memberUids = <String>[];

      for (final memberDoc in membersSnapshot.docs) {
        final memberUid = memberDoc.id;
        if (memberUid == userUid)
          continue; // Skip the external user (already added)

        memberUids.add(memberUid);
        final memberData = memberDoc.data();

        // Add as member of support chat
        final memberRef =
            _chatsCollection.doc(chatId).collection('members').doc(memberUid);
        batch.set(
            memberRef,
            {
              'joined_at': FieldValue.serverTimestamp(),
              'role_id_snapshot': memberData['role_id_snapshot'],
              'branch_id_snapshot': memberData['branch_id_snapshot'],
              'company_id_snapshot': memberData['company_id_snapshot'],
              'muted': false,
              'is_support_user': false, // Mark as group member
            },
            SetOptions(merge: true));

        // Create userChats entry for group member (sees user's name)
        final memberChatRef = _userChatsCollection(memberUid).doc(chatId);
        batch.set(
            memberChatRef,
            {
              'type': 'support',
              'role_id': targetRoleId,
              'title': userName, // Group member sees "محمد أحمد"
              'peer_uid': userUid, // To identify the external user
              'support_user_uid': userUid,
              'support_group_title': groupTitle,
              'updated_at': FieldValue.serverTimestamp(),
              'pinned': false,
              'muted': false,
            },
            SetOptions(merge: true));
      }

      // Update chat member_ids array
      if (memberUids.isNotEmpty) {
        batch.update(_chatsCollection.doc(chatId), {
          'member_ids': FieldValue.arrayUnion(memberUids),
        });
      }

      await batch.commit();
      print(
          '✅ ChatRepository: Added ${memberUids.length} role members to support chat $chatId');
    } catch (e) {
      print('❌ ChatRepository: Error adding role members to support chat: $e');
    }
  }

  /// Get all available role groups for support chat.
  /// Returns role chats that the current user is NOT a member of.
  Future<List<Chat>> getAvailableSupportGroups() async {
    final currentUid = _currentUid;
    if (currentUid == null) return [];

    try {
      // Get all role chats
      final roleChatSnapshot =
          await _chatsCollection.where('type', isEqualTo: 'role').get();

      final availableGroups = <Chat>[];

      for (final doc in roleChatSnapshot.docs) {
        // Check if current user is NOT a member of this role chat
        final memberDoc =
            await doc.reference.collection('members').doc(currentUid).get();

        if (!memberDoc.exists) {
          availableGroups.add(Chat.fromFirestore(doc));
        }
      }

      return availableGroups;
    } catch (e) {
      print('❌ ChatRepository: Error getting available support groups: $e');
      return [];
    }
  }

  /// Get ALL role groups (for support tab — show every department).
  /// Reads role chat documents directly so duplicate names with different chat IDs are preserved.
  Future<List<Chat>> getAllRoleGroups() async {
    try {
      final roleChatsSnapshot =
          await _chatsCollection.where('type', isEqualTo: 'role').get();

      final roleChats = roleChatsSnapshot.docs
          .map(Chat.fromFirestore)
          .where((chat) => chat.roleId != null)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      if (roleChats.isNotEmpty) {
        // De-duplicate by roleId — keep the most recently updated chat per role
        final Map<int, Chat> uniqueByRole = {};
        for (final chat in roleChats) {
          final rid = chat.roleId!;
          if (!uniqueByRole.containsKey(rid)) {
            uniqueByRole[rid] = chat;
          }
        }
        // Also de-duplicate by title (case-insensitive) in case different
        // roleIds resolve to the same display name
        final Map<String, Chat> uniqueByTitle = {};
        for (final chat in uniqueByRole.values) {
          final key = (chat.title ?? '').trim().toLowerCase();
          if (!uniqueByTitle.containsKey(key)) {
            uniqueByTitle[key] = chat;
          }
        }
        return uniqueByTitle.values.toList();
      }

      // Fallback for legacy data when role chat docs are not available yet.
      final usersSnapshot = await _firestore.collection('users').get();
      final Map<int, String> roleMap = {};
      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        final roleId = data['role_id'];
        if (roleId == null || roleId == 0) continue;
        if (roleMap.containsKey(roleId)) continue;
        final roleName = data['role_name']?.toString();
        roleMap[roleId as int] = roleName ?? 'Department $roleId';
      }

      return roleMap.entries
          .map((e) => Chat(
                id: Chat.generateRoleChatId(roleId: e.key),
                type: ChatType.role,
                roleId: e.key,
                title: e.value,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ))
          .toList();
    } catch (e) {
      print('❌ ChatRepository: Error getting all role groups: $e');
      return [];
    }
  }

  String? _normalizeSupportGroupKey(String? rawKey) {
    if (rawKey == null) return null;
    final trimmed = rawKey.trim();
    if (trimmed.isEmpty) return null;
    final normalized = trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return normalized.isEmpty ? null : normalized;
  }

  /// Check if the current user is the support user (external) in a support chat.
  Future<bool> isSupportUser(String chatId) async {
    final currentUid = _currentUid;
    if (currentUid == null) return false;

    try {
      final chatDoc = await _chatsCollection.doc(chatId).get();
      if (!chatDoc.exists) return false;
      final data = chatDoc.data() as Map<String, dynamic>? ?? {};
      return data['support_user_uid'] == currentUid;
    } catch (e) {
      return false;
    }
  }

  /// Get role member UIDs for a support chat (for updating all member userChats on new message)
  Future<List<String>> _getSupportChatMemberUids(String chatId) async {
    try {
      final snapshot =
          await _chatsCollection.doc(chatId).collection('members').get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get user's chat list stream.
  /// For DM/support chats without `has_messages`, checks the actual chat
  /// document for `last_message` to maintain backward compatibility.
  Stream<List<UserChat>> subscribeToUserChats(String uid) {
    return _userChatsCollection(uid)
        .orderBy('updated_at', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final chats =
          snapshot.docs.map((doc) => UserChat.fromFirestore(doc)).toList();

      // For chats missing has_messages, check the actual chat doc
      final needsCheck = chats
          .where((c) =>
              !c.hasMessages &&
              (c.type == ChatType.dm || c.type == ChatType.support))
          .toList();

      if (needsCheck.isEmpty) return chats;

      // Batch-check chat docs for last_message existence
      final updatedChatIds = <String>{};
      await Future.wait(needsCheck.map((c) async {
        try {
          final chatDoc = await _chatsCollection.doc(c.chatId).get();
          final data = chatDoc.data();
          if (data != null && data['last_message'] != null) {
            updatedChatIds.add(c.chatId);
            // Backfill has_messages flag so this check is skipped next time
            _userChatsCollection(uid)
                .doc(c.chatId)
                .set({'has_messages': true}, SetOptions(merge: true));
          }
        } catch (_) {}
      }));

      return chats.map((c) {
        if (updatedChatIds.contains(c.chatId)) {
          return c.copyWith(hasMessages: true);
        }
        return c;
      }).toList();
    }).handleError(
      (Object _) {
        // On logout the Firebase user is signed out while this listener is
        // still attached, so Firestore rejects it with `permission-denied`.
        // Swallow it here (at the source) so it never surfaces as an
        // unhandled zone error — which previously spammed logs and starved
        // the event loop during logout.
      },
      test: (error) => error.toString().contains('permission-denied'),
    );
  }

  /// Get a specific chat
  Future<Chat?> getChat(String chatId) async {
    try {
      final doc = await _chatsCollection.doc(chatId).get();
      if (!doc.exists) return null;
      return Chat.fromFirestore(doc);
    } catch (e) {
      print('❌ ChatRepository: Error getting chat: $e');
      return null;
    }
  }

  /// Get user's chat entry (for checking mute status, etc.)
  Future<UserChat?> getUserChat(String chatId) async {
    final uid = _currentUid;
    if (uid == null) return null;

    try {
      final doc = await _userChatsCollection(uid).doc(chatId).get();
      if (!doc.exists) return null;
      return UserChat.fromFirestore(doc);
    } catch (e) {
      print('❌ ChatRepository: Error getting user chat: $e');
      return null;
    }
  }

  /// Subscribe to a specific chat
  Stream<Chat?> subscribeToChat(String chatId) {
    return _chatsCollection.doc(chatId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Chat.fromFirestore(doc);
    });
  }

  // ============== Messages ==============

  /// Subscribe to messages in a chat with pagination
  Stream<List<Message>> subscribeToMessages(
    String chatId, {
    int pageSize = defaultPageSize,
    DocumentSnapshot? startAfter,
  }) {
    Query<Map<String, dynamic>> query = _chatsCollection
        .doc(chatId)
        .collection('messages')
        .orderBy('created_at', descending: true)
        .limit(pageSize);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.snapshots().map((snapshot) {
      final now = DateTime.now();
      return snapshot.docs
          .map((doc) => Message.fromFirestore(doc))
          .where((msg) {
        // Filter out expired unsigned signable docs
        if (msg.type == MessageType.signableDoc &&
            msg.signStatus != SignStatus.signed &&
            msg.expiresAt != null &&
            now.isAfter(msg.expiresAt!)) {
          return false;
        }
        return true;
      }).toList();
    }).handleError(
      (Object _) {
        // Swallow the `permission-denied` Firestore emits after sign-out while
        // this listener is still attached (see subscribeToUserChats).
      },
      test: (error) => error.toString().contains('permission-denied'),
    );
  }

  /// Load more messages (for pagination)
  Future<List<Message>> loadMoreMessages(
    String chatId, {
    required DocumentSnapshot startAfter,
    int pageSize = defaultPageSize,
  }) async {
    try {
      final snapshot = await _chatsCollection
          .doc(chatId)
          .collection('messages')
          .orderBy('created_at', descending: true)
          .startAfterDocument(startAfter)
          .limit(pageSize)
          .get();

      return snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
    } catch (e) {
      print('❌ ChatRepository: Error loading more messages: $e');
      return [];
    }
  }

  /// Get a single message by ID from a chat.
  Future<Message?> getMessageById(String chatId, String messageId) async {
    try {
      final doc = await _chatsCollection
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!doc.exists) return null;

      final message = Message.fromFirestore(doc);
      final now = DateTime.now();

      // Keep behavior consistent with subscribeToMessages filter.
      if (message.type == MessageType.signableDoc &&
          message.signStatus != SignStatus.signed &&
          message.expiresAt != null &&
          now.isAfter(message.expiresAt!)) {
        return null;
      }

      return message;
    } catch (e) {
      print('❌ ChatRepository: Error getting message by ID: $e');
      return null;
    }
  }

  /// Get a window of messages around a timestamp.
  /// Useful when direct document get is blocked or unavailable.
  Future<List<Message>> getMessagesAroundCreatedAt(
    String chatId,
    DateTime anchor, {
    int windowSize = 400,
  }) async {
    try {
      final anchorTs = Timestamp.fromDate(anchor);
      final halfWindow = (windowSize / 2).round();

      final olderOrEqualFuture = _chatsCollection
          .doc(chatId)
          .collection('messages')
          .where('created_at', isLessThanOrEqualTo: anchorTs)
          .orderBy('created_at', descending: true)
          .limit(halfWindow)
          .get();

      final newerFuture = _chatsCollection
          .doc(chatId)
          .collection('messages')
          .where('created_at', isGreaterThan: anchorTs)
          .orderBy('created_at', descending: false)
          .limit(halfWindow)
          .get();

      final results = await Future.wait([olderOrEqualFuture, newerFuture]);
      final olderOrEqual = results[0].docs;
      final newer = results[1].docs;

      final Map<String, Message> byId = {};
      final now = DateTime.now();

      for (final doc in [...olderOrEqual, ...newer]) {
        final msg = Message.fromFirestore(doc);
        if (msg.type == MessageType.signableDoc &&
            msg.signStatus != SignStatus.signed &&
            msg.expiresAt != null &&
            now.isAfter(msg.expiresAt!)) {
          continue;
        }
        byId[msg.id] = msg;
      }

      final merged = byId.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return merged;
    } catch (e) {
      print('❌ ChatRepository: Error getting messages around created_at: $e');
      return [];
    }
  }

  /// Find a message for starred navigation by scanning paginated message history.
  /// Tries exact ID first, then metadata matching as a fallback.
  Future<Message?> findMessageForStarredNavigation(
    String chatId, {
    String? messageId,
    DateTime? createdAt,
    String? senderId,
    String? type,
    String? text,
    String? fileName,
    int pageSize = 300,
    int maxPages = 80,
  }) async {
    try {
      print('🔎 STAR_JUMP[repo]: find start '
          'chatId=$chatId messageId=$messageId createdAt=$createdAt '
          'senderId=$senderId type=$type fileName=$fileName '
          'textLen=${text?.length ?? 0} pageSize=$pageSize maxPages=$maxPages');

      final normalizedMessageId = messageId?.trim();
      final expectedSender = senderId?.trim();
      final expectedTypeRaw = type?.trim();
      final expectedText = text?.trim();
      final expectedFileName = fileName?.trim();

      MessageType? expectedType;
      if (expectedTypeRaw != null && expectedTypeRaw.isNotEmpty) {
        expectedType = MessageType.fromString(expectedTypeRaw);
      }

      if (normalizedMessageId != null &&
          normalizedMessageId.isNotEmpty &&
          !normalizedMessageId.startsWith('pending_')) {
        final exact = await getMessageById(chatId, normalizedMessageId);
        if (exact != null) {
          print('✅ STAR_JUMP[repo]: exact id match found id=${exact.id}');
          return exact;
        }
        print(
            '⚠️ STAR_JUMP[repo]: exact id not found for id=$normalizedMessageId');
      }

      // For legacy starred entries where message_id may be missing/invalid,
      // anchor around created_at first for a deterministic nearby lookup.
      if (createdAt != null) {
        final around = await getMessagesAroundCreatedAt(
          chatId,
          createdAt,
          windowSize: 1200,
        );

        final aroundMatches = around.where((msg) {
          return _matchesStarredDescriptor(
            msg,
            expectedSender: expectedSender,
            expectedType: expectedType,
            expectedText: expectedText,
            expectedFileName: expectedFileName,
          );
        }).toList();

        if (aroundMatches.isNotEmpty) {
          aroundMatches.sort((a, b) {
            final da = a.createdAt.difference(createdAt).inMilliseconds.abs();
            final db = b.createdAt.difference(createdAt).inMilliseconds.abs();
            return da.compareTo(db);
          });
          print('✅ STAR_JUMP[repo]: around(created_at) matched '
              'count=${aroundMatches.length} selected=${aroundMatches.first.id}');
          return aroundMatches.first;
        }
        print('⚠️ STAR_JUMP[repo]: around(created_at) returned 0 matches');
      }

      QueryDocumentSnapshot<Map<String, dynamic>>? lastDoc;
      final now = DateTime.now();
      final candidates = <Message>[];

      for (int page = 0; page < maxPages; page++) {
        Query<Map<String, dynamic>> query = _chatsCollection
            .doc(chatId)
            .collection('messages')
            .orderBy('created_at', descending: true)
            .limit(pageSize);

        if (lastDoc != null) {
          query = query.startAfterDocument(lastDoc);
        }

        final snapshot = await query.get();
        if (snapshot.docs.isEmpty) break;

        if (page == 0 || page % 10 == 0) {
          print('🔎 STAR_JUMP[repo]: scanning page=${page + 1} '
              'docs=${snapshot.docs.length} candidates=${candidates.length}');
        }

        for (final doc in snapshot.docs) {
          final msg = Message.fromFirestore(doc);

          if (msg.type == MessageType.signableDoc &&
              msg.signStatus != SignStatus.signed &&
              msg.expiresAt != null &&
              now.isAfter(msg.expiresAt!)) {
            continue;
          }

          if (normalizedMessageId != null &&
              normalizedMessageId.isNotEmpty &&
              msg.id == normalizedMessageId) {
            return msg;
          }

          if (_matchesStarredDescriptor(
            msg,
            expectedSender: expectedSender,
            expectedType: expectedType,
            expectedText: expectedText,
            expectedFileName: expectedFileName,
          )) {
            candidates.add(msg);
          }
        }

        lastDoc = snapshot.docs.last;
        if (snapshot.docs.length < pageSize) break;
      }

      if (candidates.isEmpty) {
        // Last-resort resolver: jump to the closest message by time so starred
        // navigation always lands near the intended message instead of opening
        // chat without any jump.
        if (createdAt != null) {
          final around = await getMessagesAroundCreatedAt(
            chatId,
            createdAt,
            windowSize: 1200,
          );
          if (around.isNotEmpty) {
            around.sort((a, b) {
              final da = a.createdAt.difference(createdAt).inMilliseconds.abs();
              final db = b.createdAt.difference(createdAt).inMilliseconds.abs();
              return da.compareTo(db);
            });
            print('✅ STAR_JUMP[repo]: fallback nearest-by-time selected '
                'id=${around.first.id} totalNearby=${around.length}');
            return around.first;
          }
          print(
              '❌ STAR_JUMP[repo]: fallback nearest-by-time found no nearby messages');
        }
        print('❌ STAR_JUMP[repo]: no candidates found');
        return null;
      }
      if (createdAt == null) {
        print('✅ STAR_JUMP[repo]: candidates found without anchor date '
            'count=${candidates.length} selected=${candidates.first.id}');
        return candidates.first;
      }

      candidates.sort((a, b) {
        final da = a.createdAt.difference(createdAt).inMilliseconds.abs();
        final db = b.createdAt.difference(createdAt).inMilliseconds.abs();
        return da.compareTo(db);
      });
      print('✅ STAR_JUMP[repo]: candidates sorted by anchor date '
          'count=${candidates.length} selected=${candidates.first.id}');
      return candidates.first;
    } catch (e) {
      print('❌ ChatRepository: Error finding starred target message: $e');
      print(
          '❌ STAR_JUMP[repo]: find crashed chatId=$chatId messageId=$messageId');
      return null;
    }
  }

  bool _matchesStarredDescriptor(
    Message message, {
    String? expectedSender,
    MessageType? expectedType,
    String? expectedText,
    String? expectedFileName,
  }) {
    if (expectedSender != null &&
        expectedSender.isNotEmpty &&
        message.senderId != expectedSender) {
      final hasOtherHints = (expectedText != null && expectedText.isNotEmpty) ||
          (expectedFileName != null && expectedFileName.isNotEmpty);
      if (!hasOtherHints) {
        return false;
      }
    }

    if (expectedType != null && message.type != expectedType) {
      return false;
    }

    if (expectedType == MessageType.text &&
        expectedText != null &&
        expectedText.isNotEmpty) {
      final normalizedMessageText = _normalizeText(message.text);
      final normalizedExpectedText = _normalizeText(expectedText);

      // Text content can differ slightly after serialization/normalization.
      // Keep strict/partial checks first, then allow created_at proximity
      // (done by caller) instead of rejecting the candidate outright.
      if (normalizedMessageText.isNotEmpty &&
          normalizedExpectedText.isNotEmpty) {
        if (normalizedMessageText != normalizedExpectedText &&
            !normalizedMessageText.contains(normalizedExpectedText) &&
            !normalizedExpectedText.contains(normalizedMessageText)) {
          // Do not return false here.
        }
      }
    }

    if ((expectedType == MessageType.file ||
            expectedType == MessageType.signableDoc) &&
        expectedFileName != null &&
        expectedFileName.isNotEmpty) {
      if ((message.fileName ?? '').trim() != expectedFileName) {
        return false;
      }
    }

    return true;
  }

  String _normalizeText(String? value) {
    if (value == null) return '';
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Send a text message
  Future<Message> sendText(String chatId, String text,
      {ReplyTo? replyTo}) async {
    final currentUid = _currentUid;
    if (currentUid == null) {
      throw Exception('Not authenticated');
    }

    final clientMsgId = _uuid.v4();
    final messageRef =
        _chatsCollection.doc(chatId).collection('messages').doc();

    final message = Message(
      id: messageRef.id,
      senderId: currentUid,
      type: MessageType.text,
      text: text,
      createdAt: DateTime.now(),
      clientMsgId: clientMsgId,
      replyTo: replyTo,
      status: MessageStatus.sending,
    );

    try {
      // For DM chats: ensure chat document + both userChats entries exist
      String? _dmOtherUid;
      List<String>? _dmPair;
      if (chatId.startsWith('dm_')) {
        _dmPair = _parseDmPair(chatId, currentUid);
        if (_dmPair != null) {
          _dmOtherUid =
              _dmPair.firstWhere((u) => u != currentUid, orElse: () => '');
        }
        await _ensureDmChatExists(chatId);
      }

      final batch = _firestore.batch();

      // Add message
      batch.set(messageRef, message.toFirestore());

      // Update chat last_message and updated_at
      final chatRef = _chatsCollection.doc(chatId);
      final chatUpdate = <String, dynamic>{
        'last_message': {
          'text': text,
          'type': 'text',
          'sender_id': currentUid,
          'created_at': FieldValue.serverTimestamp(),
        },
        'updated_at': FieldValue.serverTimestamp(),
      };
      // Always include member_ids + dm_pair for DM chats so the doc is valid
      // even if _ensureDmChatExists partially failed
      if (_dmPair != null) {
        chatUpdate['type'] = 'dm';
        chatUpdate['dm_pair'] = _dmPair;
        chatUpdate['member_ids'] = FieldValue.arrayUnion(_dmPair);
      }
      batch.set(chatRef, chatUpdate, SetOptions(merge: true));

      // Update sender's userChats entry
      final senderChatUpdate = <String, dynamic>{
        'type': chatId.startsWith('dm_') ? 'dm' : 'role',
        'updated_at': FieldValue.serverTimestamp(),
        'has_messages': true,
      };
      if (_dmOtherUid != null && _dmOtherUid.isNotEmpty) {
        senderChatUpdate['peer_uid'] = _dmOtherUid;
      }
      batch.set(_userChatsCollection(currentUid).doc(chatId), senderChatUpdate,
          SetOptions(merge: true));

      await batch.commit();

      // For DM chats, also update the other user's userChats timestamp
      if (chatId.startsWith('dm_')) {
        _updateDmPeerTimestamp(chatId, currentUid);
      }

      // For support chats, update all members' userChats timestamps
      if (chatId.startsWith('support_')) {
        _updateSupportChatMemberTimestamps(chatId, currentUid);
      }

      // Clear typing status
      await PresenceService.instance.setTyping(chatId, false);

      return message.copyWith(status: MessageStatus.sent);
    } catch (e) {
      print('❌ ChatRepository: Error sending text message: $e');
      rethrow;
    }
  }

  /// Ensure group chat doc for Site Management `project_<projectId>` rooms.
  Future<void> ensureProjectGroupChat({
    required String chatId,
    String? title,
    List<String> memberUids = const [],
  }) async {
    if (!chatId.startsWith('project_')) return;
    final currentUid = _currentUid;
    if (currentUid == null) throw Exception('Not authenticated');

    final chatTitle =
        title != null && title.trim().isNotEmpty ? title.trim() : 'Project group';
    final allMembers = <String>{currentUid, ...memberUids.where((u) => u.isNotEmpty)};
    try {
      await _chatsCollection.doc(chatId).set({
        'type': 'group',
        'title': chatTitle,
        'member_ids': FieldValue.arrayUnion(allMembers.toList()),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      var isFirst = true;
      for (final uid in allMembers) {
        try {
          await _chatsCollection
              .doc(chatId)
              .collection('members')
              .doc(uid)
              .set({
            'joined_at': FieldValue.serverTimestamp(),
            'muted': false,
            'is_admin': isFirst && uid == currentUid,
          }, SetOptions(merge: true));
          isFirst = false;
        } catch (e) {
          print('⚠️ ensureProjectGroupChat member $uid: $e');
        }
      }

      try {
        await _userChatsCollection(currentUid).doc(chatId).set({
          'type': 'group',
          'title': chatTitle,
          'updated_at': FieldValue.serverTimestamp(),
          'has_messages': true,
        }, SetOptions(merge: true));
      } catch (e) {
        print('⚠️ ensureProjectGroupChat userChats: $e');
      }
    } catch (e) {
      print('⚠️ ensureProjectGroupChat: $e');
      rethrow;
    }
  }

  /// Peer UID for a DM (supports self-chat where both sides are the same uid).
  String _dmPeerUid(List<String> dmPair, String currentUid) {
    if (dmPair.isEmpty) return currentUid;
    if (dmPair.length == 1) return dmPair.first;
    if (dmPair[0] == dmPair[1]) return currentUid;
    return dmPair.firstWhere((u) => u != currentUid, orElse: () => currentUid);
  }

  /// Ensure DM chat doc, member entries, and both users' userChats entries exist.
  /// Uses set(merge) everywhere so it's idempotent and works whether docs
  /// exist or not. Individual writes so a failure on one doesn't block others.
  /// Supports WhatsApp-style self-chat (message yourself).
  Future<void> _ensureDmChatExists(String chatId) async {
    final currentUid = _currentUid;
    if (currentUid == null) return;

    final dmPair = _parseDmPair(chatId, currentUid);
    if (dmPair == null) {
      print('⚠️ _ensureDmChatExists: Cannot parse UIDs from $chatId');
      return;
    }

    final otherUid = _dmPeerUid(dmPair, currentUid);
    final isSelfChat = otherUid == currentUid;

    print(
        '🔍 _ensureDmChatExists: chatId=$chatId, currentUid=$currentUid, otherUid=$otherUid self=$isSelfChat');

    // Check if chat doc already exists — if yes, skip creation steps.
    // Permission error on read is treated as "probably doesn't exist".
    bool chatExists = false;
    try {
      final chatDoc = await _chatsCollection.doc(chatId).get();
      chatExists = chatDoc.exists;
    } catch (_) {
      // Permission denied or other error — proceed to create
    }

    final peerUser = await UserRepository.instance.getUser(otherUid);
    final currentUser = isSelfChat
        ? peerUser
        : await UserRepository.instance.getUser(currentUid);
    final peerName = isSelfChat
        ? ((peerUser?.name.trim().isNotEmpty == true)
            ? '${peerUser!.name} (You)'
            : 'You')
        : (peerUser?.name ?? 'User');
    final currentName = currentUser?.name ?? 'User';

    if (chatExists) {
      print('✅ _ensureDmChatExists: Chat $chatId already exists');
      // Still ensure the current user's userChats entry exists
      try {
        await _userChatsCollection(currentUid).doc(chatId).set({
          'type': 'dm',
          'peer_uid': otherUid,
          'title': peerName,
          'updated_at': FieldValue.serverTimestamp(),
          'pinned': false,
          'muted': false,
        }, SetOptions(merge: true));
      } catch (e) {
        print('⚠️ _ensureDmChatExists: Error ensuring own userChats: $e');
      }
      return;
    }

    // Step 1: Create/update chat document with member_ids
    print('📝 _ensureDmChatExists: Step 1 — creating chat doc');
    final memberIds = isSelfChat ? [currentUid] : dmPair.toSet().toList();
    try {
      await _chatsCollection.doc(chatId).set({
        'type': 'dm',
        'dm_pair': isSelfChat ? [currentUid, currentUid] : dmPair,
        'member_ids': FieldValue.arrayUnion(memberIds),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('✅ Step 1 succeeded');
    } catch (e) {
      print('⚠️ Step 1 failed: $e');
      // Don't return — the sendText batch will also try to create the doc
    }

    // Step 2: Create member entries (one for self-chat)
    final memberUids = isSelfChat ? [currentUid] : dmPair.toSet().toList();
    for (final uid in memberUids) {
      final user = uid == currentUid ? currentUser : peerUser;
      try {
        await _chatsCollection.doc(chatId).collection('members').doc(uid).set({
          'joined_at': FieldValue.serverTimestamp(),
          'role_id_snapshot': user?.roleId,
          'branch_id_snapshot': user?.branchId,
          'company_id_snapshot': user?.companyId,
          'muted': false,
        }, SetOptions(merge: true));
      } catch (e) {
        print('⚠️ _ensureDmChatExists: Member doc $uid: $e');
      }
    }

    // Step 3: Create userChats entries
    try {
      await _userChatsCollection(currentUid).doc(chatId).set({
        'type': 'dm',
        'peer_uid': otherUid,
        'title': peerName,
        'updated_at': FieldValue.serverTimestamp(),
        'pinned': false,
        'muted': false,
      }, SetOptions(merge: true));
    } catch (e) {
      print('⚠️ _ensureDmChatExists: Own userChats: $e');
    }

    if (!isSelfChat) {
      try {
        await _userChatsCollection(otherUid).doc(chatId).set({
          'type': 'dm',
          'peer_uid': currentUid,
          'title': currentName,
          'updated_at': FieldValue.serverTimestamp(),
          'pinned': false,
          'muted': false,
        }, SetOptions(merge: true));
      } catch (e) {
        print('⚠️ _ensureDmChatExists: Peer userChats: $e');
      }
    }

    print('✅ _ensureDmChatExists: Chat $chatId setup complete');
  }

  /// Helper: parse DM pair from chat ID.
  /// Returns [uidA, uidB] sorted, or null if parsing fails.
  /// Self-chat ids look like `dm_{uid}_{uid}`.
  List<String>? _parseDmPair(String chatId, String currentUid) {
    final withoutPrefix = chatId.replaceFirst('dm_', '');
    String otherUid;
    if (withoutPrefix.startsWith('${currentUid}_')) {
      otherUid = withoutPrefix.substring(currentUid.length + 1);
    } else if (withoutPrefix.endsWith('_$currentUid')) {
      otherUid = withoutPrefix.substring(
          0, withoutPrefix.length - currentUid.length - 1);
    } else {
      return null;
    }
    return Chat.getSortedDmPair(currentUid, otherUid);
  }

  /// Update the other user's userChats entry for a DM.
  /// Creates a FULL entry (not just updated_at) so the chat appears
  /// properly in the other user's chat list with title and peer info.
  /// No-op for self-chat (own list is already updated on send).
  Future<void> _updateDmPeerTimestamp(String chatId, String currentUid) async {
    try {
      final dmPair = _parseDmPair(chatId, currentUid);
      if (dmPair == null) return;
      final otherUid = _dmPeerUid(dmPair, currentUid);
      if (otherUid == currentUid) return;

      // Get current user's name so the other user sees it as the chat title
      final currentUser = await UserRepository.instance.getUser(currentUid);
      final currentName = currentUser?.name ?? 'User';

      await _userChatsCollection(otherUid).doc(chatId).set({
        'type': 'dm',
        'peer_uid': currentUid,
        'title': currentName,
        'updated_at': FieldValue.serverTimestamp(),
        'has_messages': true,
        'pinned': false,
        'muted': false,
      }, SetOptions(merge: true));
      print('✅ _updateDmPeerTimestamp: Updated peer $otherUid userChats entry');
    } catch (e) {
      print('⚠️ ChatRepository: Error updating DM peer timestamp: $e');
    }
  }

  /// Update all support chat members' userChats timestamps (fire-and-forget)
  Future<void> _updateSupportChatMemberTimestamps(
      String chatId, String excludeUid) async {
    try {
      final memberUids = await _getSupportChatMemberUids(chatId);
      final batch = _firestore.batch();
      for (final uid in memberUids) {
        if (uid == excludeUid) continue; // Already updated in the main batch
        batch.update(_userChatsCollection(uid).doc(chatId), {
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      print(
          '⚠️ ChatRepository: Error updating support chat member timestamps: $e');
    }
  }

  /// Send an image message
  Future<Message> sendImage(
    String chatId,
    File imageFile, {
    String? caption,
    ReplyTo? replyTo,
  }) async {
    return _sendMedia(
      chatId: chatId,
      file: imageFile,
      type: MessageType.image,
      caption: caption,
      replyTo: replyTo,
    );
  }

  /// Send a file message
  Future<Message> sendFile(
    String chatId,
    File file, {
    String? caption,
    String? mimeType,
    ReplyTo? replyTo,
  }) async {
    return _sendMedia(
      chatId: chatId,
      file: file,
      type: MessageType.file,
      caption: caption,
      mimeType: mimeType,
      replyTo: replyTo,
    );
  }

  /// Send a voice message
  Future<Message> sendVoice(
    String chatId,
    File audioFile, {
    required int durationMs,
    ReplyTo? replyTo,
  }) async {
    return _sendMedia(
      chatId: chatId,
      file: audioFile,
      type: MessageType.audio,
      durationMs: durationMs,
      mimeType: 'audio/m4a',
      replyTo: replyTo,
    );
  }

  /// Send a signable document (PDF) with sign zones
  Future<Message> sendSignableDocument(
    String chatId,
    File pdfFile, {
    required List<SignZone> signZones,
    String? caption,
    int expiresInDays = 2,
    int? pageCount,
    List<String>? signerUids,
    List<String>? signerNames,
    int currentSignerIndex = 0,
    String? signatureDocumentId,
  }) async {
    await _ensureFirebaseAuth();
    final currentUid = _currentUid;
    if (currentUid == null) throw Exception('Not authenticated');

    if (chatId.startsWith('dm_')) {
      await _ensureDmChatExists(chatId);
    }

    if (!await pdfFile.exists()) {
      throw Exception('File does not exist: ${pdfFile.path}');
    }

    final clientMsgId = _uuid.v4();
    final messageRef =
        _chatsCollection.doc(chatId).collection('messages').doc();
    final fileName = p.basename(pdfFile.path);
    final fileSize = await pdfFile.length();
    final storagePath = 'chat_media/$chatId/${messageRef.id}/$fileName';

    final resolvedSignerUids = signerUids;
    final resolvedCurrentSigner = (resolvedSignerUids != null &&
            resolvedSignerUids.isNotEmpty &&
            currentSignerIndex < resolvedSignerUids.length)
        ? resolvedSignerUids[currentSignerIndex]
        : null;

    try {
      // Upload PDF
      final ref = _storage.ref(storagePath);
      final metadata = SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {'uploadedBy': currentUid, 'chatId': chatId},
      );
      final fileBytes = await pdfFile.readAsBytes();
      try {
        await ref.putData(fileBytes, metadata);
      } on FirebaseException catch (e) {
        if (e.code == 'unauthorized' ||
            e.code == 'permission-denied' ||
            e.code == 'unauthenticated') {
          print(
              '⚠️ ChatRepository: Storage auth denied (${e.code}), refreshing…');
          await _ensureFirebaseAuth();
          await Future<void>.delayed(const Duration(milliseconds: 250));
          await ref.putData(fileBytes, metadata);
        } else {
          rethrow;
        }
      }
      final mediaUrl = await ref.getDownloadURL();

      // Create message with 24-hour expiry for unsigned docs
      final message = Message(
        id: messageRef.id,
        senderId: currentUid,
        type: MessageType.signableDoc,
        text: caption,
        mediaUrl: mediaUrl,
        mediaPath: storagePath,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: 'application/pdf',
        createdAt: DateTime.now(),
        clientMsgId: clientMsgId,
        status: MessageStatus.sent,
        signZones: signZones,
        signStatus: SignStatus.pending,
        signExpiresInDays: expiresInDays,
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        pageCount: pageCount,
        signerUids: resolvedSignerUids,
        signerNames: signerNames,
        currentSignerIndex: resolvedSignerUids != null ? currentSignerIndex : null,
        currentSignerUid: resolvedCurrentSigner,
        signatureDocumentId: signatureDocumentId,
      );

      final batch = _firestore.batch();
      batch.set(messageRef, message.toFirestore());

      // Update chat last_message
      final chatUpdate = <String, dynamic>{
        'last_message': {
          'text': '📝 $fileName',
          'type': 'signable_doc',
          'sender_id': currentUid,
          'created_at': FieldValue.serverTimestamp(),
        },
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (chatId.startsWith('dm_')) {
        final dmPair = _parseDmPair(chatId, currentUid);
        if (dmPair != null) {
          chatUpdate['type'] = 'dm';
          chatUpdate['dm_pair'] = dmPair;
          chatUpdate['member_ids'] = FieldValue.arrayUnion(dmPair);
        }
      }
      batch.set(
          _chatsCollection.doc(chatId), chatUpdate, SetOptions(merge: true));

      // Update sender's userChats
      batch.set(
          _userChatsCollection(currentUid).doc(chatId),
          {
            'type': chatId.startsWith('dm_') ? 'dm' : 'role',
            'updated_at': FieldValue.serverTimestamp(),
            'has_messages': true,
          },
          SetOptions(merge: true));

      await batch.commit();

      // Await peer userChats update so the recipient's chat list + unread
      // badge refresh immediately (fire-and-forget was dropping updates).
      if (chatId.startsWith('dm_')) {
        await _updateDmPeerTimestamp(chatId, currentUid);
      }
      if (chatId.startsWith('support_')) {
        await _updateSupportChatMemberTimestamps(chatId, currentUid);
      }

      return message;
    } catch (e) {
      print('❌ ChatRepository: Error sending signable document: $e');
      rethrow;
    }
  }

  /// Sign a document — uploads signed PDF and updates message.
  /// If this is a multi-signee chain with remaining signers, advances to the
  /// next signer by DM'ing them the latest PDF (triggers standard chat
  /// unread + notification pipeline).
  Future<void> signDocument(
    String chatId,
    String messageId,
    Uint8List signedPdfBytes,
    String originalFileName,
  ) async {
    final currentUid = _currentUid;
    if (currentUid == null) throw Exception('Not authenticated');

    try {
      final messageRef =
          _chatsCollection.doc(chatId).collection('messages').doc(messageId);
      final existing = await messageRef.get();
      final existingMessage =
          existing.exists ? Message.fromFirestore(existing) : null;

      // Upload signed PDF
      final signedFileName = 'signed_$originalFileName';
      final storagePath = 'chat_media/$chatId/$messageId/$signedFileName';
      final ref = _storage.ref(storagePath);
      final metadata = SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {'signedBy': currentUid, 'chatId': chatId},
      );
      await ref.putData(signedPdfBytes, metadata);
      final signedUrl = await ref.getDownloadURL();

      final signers = existingMessage?.signerUids;
      final index = existingMessage?.currentSignerIndex ?? 0;
      final hasMore = signers != null &&
          signers.isNotEmpty &&
          index + 1 < signers.length;

      if (hasMore) {
        final nextIndex = index + 1;
        final nextUid = signers[nextIndex];
        await messageRef.update({
          'sign_status': 'pending',
          'signed_pdf_url': signedUrl,
          'signed_at': FieldValue.serverTimestamp(),
          'signed_by': currentUid,
          'current_signer_index': nextIndex,
          'current_signer_uid': nextUid,
          'media_url': signedUrl,
        });

        // Drive next signer via DM — unread + push notifications follow
        // the standard chat message pipeline.
        final nextName = (existingMessage?.signerNames != null &&
                nextIndex < existingMessage!.signerNames!.length)
            ? existingMessage.signerNames![nextIndex]
            : 'Colleague';
        final currentUser =
            await UserRepository.instance.getUser(currentUid);
        final nextChatId = await createOrGetDmChat(
          otherUid: nextUid,
          otherName: nextName,
          currentUserName: currentUser?.name ?? 'User',
        );

        final dir = await Directory.systemTemp.createTemp('sign_next_');
        final nextFile = File(
            '${dir.path}/${existingMessage?.fileName ?? originalFileName}');
        await nextFile.writeAsBytes(signedPdfBytes);

        await sendSignableDocument(
          nextChatId,
          nextFile,
          signZones: existingMessage?.signZones ?? const [],
          pageCount: existingMessage?.pageCount,
          signerUids: signers,
          signerNames: existingMessage?.signerNames,
          currentSignerIndex: nextIndex,
          signatureDocumentId: existingMessage?.signatureDocumentId,
          caption: 'Please sign: ${existingMessage?.fileName ?? originalFileName}',
        );

        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      } else {
        await messageRef.update({
          'sign_status': 'signed',
          'signed_pdf_url': signedUrl,
          'signed_at': FieldValue.serverTimestamp(),
          'signed_by': currentUid,
        });
      }

      // Keep personal Documents library in sync when this chat doc was
      // created from Signature → Request signatures.
      final linkedDocId = existingMessage?.signatureDocumentId;
      if (linkedDocId != null && linkedDocId.isNotEmpty) {
        try {
          final ownerUid = existingMessage!.senderId;
          final personalRef = _firestore
              .collection('users')
              .doc(ownerUid)
              .collection('signature_documents')
              .doc(linkedDocId);
          if (hasMore) {
            final nextIndex = index + 1;
            final nextUid = signers![nextIndex];
            final nextName = (existingMessage.signerNames != null &&
                    nextIndex < existingMessage.signerNames!.length)
                ? existingMessage.signerNames![nextIndex]
                : 'Colleague';
            await personalRef.set({
              'status': 'pending_other',
              'file_url': signedUrl,
              'recipient_uid': nextUid,
              'recipient_name': nextName,
              'current_signer_index': nextIndex,
              'updated_at': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } else {
            await personalRef.set({
              'status': 'signed',
              'signed_pdf_url': signedUrl,
              'file_url': signedUrl,
              'signed_at': FieldValue.serverTimestamp(),
              'signed_by': currentUid,
              'updated_at': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        } catch (e) {
          print(
              '⚠️ ChatRepository: could not sync personal signature doc: $e');
        }
      }

      print('✅ Document signed successfully: $messageId');
    } catch (e) {
      print('❌ ChatRepository: Error signing document: $e');
      rethrow;
    }
  }

  /// Internal method to send media messages
  Future<Message> _sendMedia({
    required String chatId,
    required File file,
    required MessageType type,
    String? caption,
    String? mimeType,
    int? durationMs,
    ReplyTo? replyTo,
  }) async {
    final currentUid = _currentUid;
    if (currentUid == null) {
      throw Exception('Not authenticated');
    }

    // For DM / project group chats: ensure chat document exists before upload.
    if (chatId.startsWith('dm_')) {
      await _ensureDmChatExists(chatId);
    } else if (chatId.startsWith('project_')) {
      await ensureProjectGroupChat(chatId: chatId);
    }

    // Verify file exists before attempting upload
    if (!await file.exists()) {
      throw Exception('File does not exist: ${file.path}');
    }

    final clientMsgId = _uuid.v4();
    final messageRef =
        _chatsCollection.doc(chatId).collection('messages').doc();

    final fileName = p.basename(file.path);
    final fileSize = await file.length();
    final storagePath = 'chat_media/$chatId/${messageRef.id}/$fileName';

    try {
      // 1. Upload file to Storage
      print('📤 ChatRepository: Uploading to path: $storagePath');
      print('📤 ChatRepository: Storage bucket: ${_storage.bucket}');
      print('📤 ChatRepository: Current user UID: $currentUid');
      print(
          '📤 ChatRepository: File exists: ${await file.exists()}, size: $fileSize');

      // Check Firebase Auth state
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) {
        throw Exception(
            'Firebase Auth: No user signed in. Cannot upload to Storage.');
      }
      print(
          '📤 ChatRepository: Auth user email: ${authUser.email}, isAnonymous: ${authUser.isAnonymous}');

      final ref = _storage.ref(storagePath);
      final metadata = SettableMetadata(
        contentType: mimeType ?? _getMimeType(fileName),
        customMetadata: {
          'uploadedBy': currentUid,
          'chatId': chatId,
        },
      );

      // Read file bytes and use putData for better compatibility
      final fileBytes = await file.readAsBytes();
      print(
          '📤 ChatRepository: Read ${fileBytes.length} bytes, starting upload...');

      final uploadTask = ref.putData(fileBytes, metadata);

      // Listen to upload progress for debugging
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress =
            (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print(
            '📤 ChatRepository: Upload progress: ${progress.toStringAsFixed(1)}%');
      }, onError: (e) {
        print('❌ ChatRepository: Upload stream error: $e');
      });

      // Wait for upload
      final snapshot = await uploadTask;
      print('📤 ChatRepository: Upload complete, state: ${snapshot.state}');

      // Get download URL
      final mediaUrl = await ref.getDownloadURL();
      print(
          '📤 ChatRepository: Download URL obtained: ${mediaUrl.substring(0, 50)}...');

      // 2. Create message document
      final message = Message(
        id: messageRef.id,
        senderId: currentUid,
        type: type,
        text: caption,
        mediaUrl: mediaUrl,
        mediaPath: storagePath,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType ?? _getMimeType(fileName),
        durationMs: durationMs,
        createdAt: DateTime.now(),
        clientMsgId: clientMsgId,
        replyTo: replyTo,
        status: MessageStatus.sent,
      );

      final batch = _firestore.batch();

      // Add message
      batch.set(messageRef, message.toFirestore());

      // Update chat last_message
      final previewText = message.getPreviewText();
      final chatUpdate = <String, dynamic>{
        'last_message': {
          'text': previewText,
          'type': type.toJson(),
          'sender_id': currentUid,
          'created_at': FieldValue.serverTimestamp(),
        },
        'updated_at': FieldValue.serverTimestamp(),
      };
      // Always include member_ids for DM chats
      if (chatId.startsWith('dm_')) {
        final dmPair = _parseDmPair(chatId, currentUid);
        if (dmPair != null) {
          chatUpdate['type'] = 'dm';
          chatUpdate['dm_pair'] = dmPair;
          chatUpdate['member_ids'] = FieldValue.arrayUnion(dmPair);
        }
      }
      batch.set(
          _chatsCollection.doc(chatId), chatUpdate, SetOptions(merge: true));

      // Update sender's userChats
      final userChatType = chatId.startsWith('dm_')
          ? 'dm'
          : (chatId.startsWith('project_') ? 'group' : 'role');
      try {
        batch.set(
            _userChatsCollection(currentUid).doc(chatId),
            {
              'type': userChatType,
              'updated_at': FieldValue.serverTimestamp(),
              'has_messages': true,
            },
            SetOptions(merge: true));
      } catch (e) {
        print('⚠️ ChatRepository: userChats write skipped: $e');
      }

      await batch.commit();

      // For DM chats, also update the other user's userChats timestamp
      if (chatId.startsWith('dm_')) {
        _updateDmPeerTimestamp(chatId, currentUid);
      }

      if (chatId.startsWith('project_')) {
        try {
          await _chatsCollection.doc(chatId).set({
            'type': 'group',
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}
      }

      // For support chats, update all members' userChats timestamps
      if (chatId.startsWith('support_')) {
        _updateSupportChatMemberTimestamps(chatId, currentUid);
      }

      return message;
    } on FirebaseException catch (e) {
      print('❌ ChatRepository: Firebase error sending media:');
      print('   Code: ${e.code}');
      print('   Message: ${e.message}');
      print('   Plugin: ${e.plugin}');
      print('   Storage bucket: ${_storage.bucket}');
      print('   Path attempted: $storagePath');
      rethrow;
    } catch (e) {
      print('❌ ChatRepository: Error sending media: $e');
      rethrow;
    }
  }

  /// Get MIME type from file extension
  String _getMimeType(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.mp3':
        return 'audio/mpeg';
      case '.m4a':
        return 'audio/m4a';
      case '.aac':
        return 'audio/aac';
      case '.wav':
        return 'audio/wav';
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xls':
        return 'application/vnd.ms-excel';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }

  // ============== Read Receipts ==============

  /// Mark chat as **delivered** only (grey double-tick for sender).
  /// Does not clear unread / does not set `last_read_at`.
  Future<void> markChatDelivered(String chatId) async {
    final currentUid = _currentUid;
    if (currentUid == null) return;

    try {
      await _chatsCollection
          .doc(chatId)
          .collection('members')
          .doc(currentUid)
          .set({
        'last_delivered_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('❌ ChatRepository: Error marking chat delivered: $e');
    }
  }

  /// Mark a chat as read for Hub read receipts + local unread badges.
  ///
  /// Writes server timestamps to:
  /// - `chats/{chatId}/members/{uid}` → `last_delivered_at`, `last_read_at`
  /// - `userChats/{uid}/chats/{chatId}` → `last_read_at` (inbox unread)
  ///
  /// These fields are **not** shown as UI labels — they drive WhatsApp-style
  /// ticks on the sender's device (✓ / ✓✓ grey / ✓✓ green).
  Future<void> markChatRead(String chatId) async {
    final currentUid = _currentUid;
    if (currentUid == null) return;

    final serverNow = FieldValue.serverTimestamp();

    try {
      await _chatsCollection
          .doc(chatId)
          .collection('members')
          .doc(currentUid)
          .set({
        'last_delivered_at': serverNow,
        'last_read_at': serverNow,
      }, SetOptions(merge: true));
    } catch (e) {
      print('❌ ChatRepository: Error updating member read receipts: $e');
    }

    try {
      // Use update() so we don't accidentally create a userChats doc
      // for a chat where no messages have been sent yet.
      await _userChatsCollection(currentUid).doc(chatId).update({
        'last_read_at': serverNow,
      });
    } catch (e) {
      // Ignore "not-found" — the doc doesn't exist yet (no messages sent)
      if (e is FirebaseException && e.code == 'not-found') return;
      print('❌ ChatRepository: Error marking chat as read: $e');
    }
  }

  /// Subscribe to total unread message count across all chats
  Stream<int> subscribeToTotalUnreadCount() {
    final currentUid = _currentUid;
    if (currentUid == null) {
      // print('⚠️ subscribeToTotalUnreadCount: No current UID');
      return Stream.value(0);
    }

    // print('🔔 subscribeToTotalUnreadCount: Subscribing for uid=$currentUid');
    return subscribeToUserChats(currentUid).asyncMap((chats) async {
      // print('🔔 subscribeToTotalUnreadCount: Got ${chats.length} chats');
      int total = 0;
      for (final chat in chats) {
        if (chat.muted) continue;
        final lastReadAt = chat.lastReadAt;
        try {
          Query query =
              _chatsCollection.doc(chat.chatId).collection('messages');

          // Only add created_at filter if user has read the chat before
          if (lastReadAt != null) {
            query = query.where('created_at',
                isGreaterThan: Timestamp.fromDate(lastReadAt));
          }

          // Limit to avoid fetching too many docs when lastReadAt is null
          query = query.limit(100);

          // Fetch the docs and count those NOT from current user
          final snapshot = await query.get();
          final count = snapshot.docs.where((d) {
            final data = d.data() as Map<String, dynamic>?;
            return data?['sender_id'] != currentUid;
          }).length;

          // if (count > 0) {
          //   print(
          //       '🔔 Chat ${chat.chatId}: $count unread (lastReadAt=$lastReadAt)');
          // }
          total += count;
        } catch (e) {
          // print('⚠️ subscribeToTotalUnreadCount: Error for ${chat.chatId}: $e');
        }
      }
      // print('🔔 subscribeToTotalUnreadCount: Total unread = $total');
      return total;
    });
  }

  /// Get unread count for a chat based on last_read_at
  Stream<int> subscribeToUnreadCount(String chatId) {
    final currentUid = _currentUid;
    if (currentUid == null) {
      print('⚠️ subscribeToUnreadCount($chatId): No current UID');
      return Stream.value(0);
    }

    return _userChatsCollection(currentUid)
        .doc(chatId)
        .snapshots()
        .asyncMap((userChatDoc) async {
      if (!userChatDoc.exists) {
        print(
            '⚠️ subscribeToUnreadCount($chatId): userChats doc does NOT exist');
        return 0;
      }

      final data = userChatDoc.data();
      final lastReadAt = (data?['last_read_at'] as Timestamp?)?.toDate();

      try {
        Query query = _chatsCollection.doc(chatId).collection('messages');

        // Only add created_at filter if user has read the chat before
        if (lastReadAt != null) {
          query = query.where('created_at',
              isGreaterThan: Timestamp.fromDate(lastReadAt));
        }

        // Limit to avoid fetching too many docs when lastReadAt is null
        query = query.limit(100);

        // Fetch and filter out current user's messages in-memory
        final snapshot = await query.get();
        final count = snapshot.docs.where((d) {
          final data = d.data() as Map<String, dynamic>?;
          return data?['sender_id'] != currentUid;
        }).length;

        if (count > 0)
          print(
              '🔵 subscribeToUnreadCount($chatId): $count unread (lastReadAt=$lastReadAt)');
        return count;
      } catch (e) {
        print('⚠️ subscribeToUnreadCount($chatId): Error: $e');
        return 0;
      }
    });
  }

  // ============== Chat Members ==============

  /// Live members stream (includes Hub read-receipt watermarks).
  Stream<List<ChatMember>> subscribeToChatMembers(String chatId) {
    return _chatsCollection
        .doc(chatId)
        .collection('members')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ChatMember.fromFirestore(doc)).toList());
  }

  /// Soft-delete for everyone (sender only, within 10 minutes).
  /// Clears text/media fields and removes Storage object when present.
  Future<void> deleteMessageForEveryone({
    required String chatId,
    required Message message,
  }) async {
    final currentUid = _currentUid;
    if (currentUid == null) throw Exception('Not authenticated');
    if (message.senderId != currentUid) {
      throw Exception('Only the sender can delete this message');
    }
    if (message.isDeleted) return;
    if (message.type == MessageType.signableDoc) {
      throw Exception('Signed documents cannot be deleted');
    }
    if (!message.canDeleteForEveryone) {
      throw Exception('Messages can only be deleted within 10 minutes');
    }

    final messageRef =
        _chatsCollection.doc(chatId).collection('messages').doc(message.id);

    final mediaPath = message.mediaPath;
    final mediaUrl = message.mediaUrl;

    await messageRef.update({
      'status': 'deleted',
      'text': '',
      'media_url': null,
      'media_path': null,
      'thumb_url': null,
      'file_name': null,
      'file_size': null,
      'mime_type': null,
      'duration_ms': null,
      'deleted_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Refresh chat list preview if this was the latest message.
    try {
      final chatDoc = await _chatsCollection.doc(chatId).get();
      final last = chatDoc.data()?['last_message'];
      final lastCreated = last is Map ? last['created_at'] : null;
      final matchesLast = last is Map &&
          (last['sender_id'] == currentUid) &&
          (lastCreated is Timestamp) &&
          (lastCreated.toDate().difference(message.createdAt).inSeconds.abs() <=
              5);
      if (matchesLast || last == null) {
        await _chatsCollection.doc(chatId).set({
          'last_message': {
            'text': 'This message was deleted',
            'type': 'text',
            'sender_id': currentUid,
            'status': 'deleted',
            'created_at': Timestamp.fromDate(message.createdAt),
          },
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('⚠️ ChatRepository: last_message refresh after delete: $e');
    }

    Future<void> deleteRef(String path) async {
      try {
        await _storage.ref(path).delete();
      } catch (e) {
        print('⚠️ ChatRepository: Storage delete skipped ($path): $e');
      }
    }

    if (mediaPath != null && mediaPath.isNotEmpty) {
      await deleteRef(mediaPath);
    } else if (mediaUrl != null && mediaUrl.isNotEmpty) {
      try {
        await _storage.refFromURL(mediaUrl).delete();
      } catch (e) {
        print('⚠️ ChatRepository: Storage delete via URL skipped: $e');
      }
    }
  }

  /// Get members of a chat
  Future<List<ChatMember>> getChatMembers(String chatId) async {
    try {
      final snapshot =
          await _chatsCollection.doc(chatId).collection('members').get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((doc) => ChatMember.fromFirestore(doc)).toList();
      }

      final chatDoc = await _chatsCollection.doc(chatId).get();
      final rawIds = chatDoc.data()?['member_ids'];
      if (rawIds is! List || rawIds.isEmpty) return [];

      final members = <ChatMember>[];
      for (final id in rawIds) {
        final uid = id?.toString() ?? '';
        if (uid.isEmpty) continue;
        members.add(
          ChatMember(
            uid: uid,
            joinedAt: DateTime.now(),
            muted: false,
          ),
        );
      }
      return members;
    } catch (e) {
      print('❌ ChatRepository: Error getting chat members: $e');
      return [];
    }
  }

  /// Toggle mute for a chat
  Future<void> toggleMute(String chatId, bool muted) async {
    final currentUid = _currentUid;
    if (currentUid == null) return;

    try {
      final batch = _firestore.batch();

      // Update in members subcollection
      batch.update(
        _chatsCollection.doc(chatId).collection('members').doc(currentUid),
        {'muted': muted},
      );

      // Update in userChats
      batch.update(
        _userChatsCollection(currentUid).doc(chatId),
        {'muted': muted},
      );

      await batch.commit();

      // Keep in-app listener in sync so mute takes effect immediately.
      ChatNotificationService.instance.updateMuteStatus(chatId, muted);
    } catch (e) {
      print('❌ ChatRepository: Error toggling mute: $e');
    }
  }

  /// Toggle pin for a chat
  Future<void> togglePin(String chatId, bool pinned) async {
    final currentUid = _currentUid;
    if (currentUid == null) return;

    try {
      await _userChatsCollection(currentUid).doc(chatId).update({
        'pinned': pinned,
      });
    } catch (e) {
      print('❌ ChatRepository: Error toggling pin: $e');
    }
  }

  /// Archive / unarchive a chat for the current user.
  Future<void> toggleArchive(String chatId, bool archived) async {
    final currentUid = _currentUid;
    if (currentUid == null) return;

    try {
      await _userChatsCollection(currentUid).doc(chatId).set({
        'archived': archived,
        // Unarchive should surface the chat again; pinning stays as-is.
        if (archived) 'pinned': false,
      }, SetOptions(merge: true));
    } catch (e) {
      print('❌ ChatRepository: Error toggling archive: $e');
    }
  }

  /// Active (non-archived) chats for the inbox list.
  Stream<List<UserChat>> subscribeToActiveUserChats(String uid) {
    return subscribeToUserChats(uid).map((chats) {
      final active = chats.where((c) => !c.archived).toList();
      active.sort(_compareChatsForList);
      return active;
    });
  }

  /// Archived chats list.
  Stream<List<UserChat>> subscribeToArchivedUserChats(String uid) {
    return subscribeToUserChats(uid).map((chats) {
      final archived = chats.where((c) => c.archived).toList();
      archived.sort(_compareChatsForList);
      return archived;
    });
  }

  /// Count of archived chats (for the Archived row badge).
  Stream<int> subscribeToArchivedCount(String uid) {
    return subscribeToUserChats(uid)
        .map((chats) => chats.where((c) => c.archived).length);
  }

  static int _compareChatsForList(UserChat a, UserChat b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    return b.updatedAt.compareTo(a.updatedAt);
  }

  /// Whether membership can be edited (freeform / project groups only).
  bool canManageMembers(ChatType type) => type == ChatType.group;

  /// Add members to a group chat. Current user must be an admin (or sole member).
  Future<void> addMembers(String chatId, List<String> uids) async {
    final currentUid = _currentUid;
    if (currentUid == null) throw Exception('Not authenticated');

    final chat = await getChat(chatId);
    if (chat == null) throw Exception('Chat not found');
    if (!canManageMembers(chat.type)) {
      throw Exception('Members cannot be managed for this chat type');
    }

    final members = await getChatMembers(chatId);
    final isAdmin = members.any((m) => m.uid == currentUid && m.isAdmin) ||
        members.every((m) => !m.isAdmin); // bootstrap: no admins yet → allow
    if (!isAdmin) throw Exception('Only admins can add members');

    final title = chat.title ?? 'Group';
    final toAdd = uids.where((u) => u.isNotEmpty && u != currentUid).toSet();
    if (toAdd.isEmpty) return;

    for (final uid in toAdd) {
      await _chatsCollection.doc(chatId).collection('members').doc(uid).set({
        'joined_at': FieldValue.serverTimestamp(),
        'muted': false,
        'is_admin': false,
      }, SetOptions(merge: true));

      await _userChatsCollection(uid).doc(chatId).set({
        'type': chat.type.toJson(),
        'title': title,
        'updated_at': FieldValue.serverTimestamp(),
        'has_messages': chat.lastMessage != null,
        'archived': false,
      }, SetOptions(merge: true));
    }

    await _chatsCollection.doc(chatId).set({
      'member_ids': FieldValue.arrayUnion(toAdd.toList()),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Remove a member from a group. Admins can remove others; anyone can leave via [leaveGroup].
  Future<void> removeMember(String chatId, String uid) async {
    final currentUid = _currentUid;
    if (currentUid == null) throw Exception('Not authenticated');
    if (uid == currentUid) {
      await leaveGroup(chatId);
      return;
    }

    final chat = await getChat(chatId);
    if (chat == null) throw Exception('Chat not found');
    if (!canManageMembers(chat.type)) {
      throw Exception('Members cannot be managed for this chat type');
    }

    final members = await getChatMembers(chatId);
    final amAdmin = members.any((m) => m.uid == currentUid && m.isAdmin) ||
        members.every((m) => !m.isAdmin);
    if (!amAdmin) throw Exception('Only admins can remove members');

    await _chatsCollection.doc(chatId).collection('members').doc(uid).delete();
    await _userChatsCollection(uid).doc(chatId).delete();
    await _chatsCollection.doc(chatId).set({
      'member_ids': FieldValue.arrayRemove([uid]),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Remove this chat from the current user's inbox only ("Delete for me").
  /// Does not delete the shared chat or the peer's list entry.
  /// A later message may recreate the userChats row (same as WhatsApp-style hide).
  Future<void> deleteChatForMe(String chatId) async {
    final currentUid = _currentUid;
    if (currentUid == null) throw Exception('Not authenticated');
    if (chatId.trim().isEmpty) throw Exception('chatId is required');

    try {
      await _userChatsCollection(currentUid).doc(chatId).delete();
      print('✅ ChatRepository: Deleted chat $chatId for $currentUid');
    } catch (e) {
      print('❌ ChatRepository: Error deleting chat for me: $e');
      rethrow;
    }
  }

  /// Current user leaves a group chat.
  Future<void> leaveGroup(String chatId) async {
    final currentUid = _currentUid;
    if (currentUid == null) throw Exception('Not authenticated');

    final chat = await getChat(chatId);
    if (chat == null) throw Exception('Chat not found');
    if (!canManageMembers(chat.type)) {
      throw Exception('Cannot leave this chat type via leaveGroup');
    }

    await _chatsCollection
        .doc(chatId)
        .collection('members')
        .doc(currentUid)
        .delete();
    await _userChatsCollection(currentUid).doc(chatId).delete();
    await _chatsCollection.doc(chatId).set({
      'member_ids': FieldValue.arrayRemove([currentUid]),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Promote first member to admin if the group has no admins yet.
  Future<void> ensureGroupHasAdmin(String chatId) async {
    final members = await getChatMembers(chatId);
    if (members.isEmpty || members.any((m) => m.isAdmin)) return;
    final first = members.first;
    await _chatsCollection
        .doc(chatId)
        .collection('members')
        .doc(first.uid)
        .set({'is_admin': true}, SetOptions(merge: true));
  }

  // ============== Starred Messages ==============

  /// Star a message (stored per-user in userChats/{uid}/starred_messages/{messageId})
  Future<void> starMessage(String chatId, Message message) async {
    final currentUid = _currentUid;
    if (currentUid == null) return;

    try {
      await _firestore
          .collection('userChats')
          .doc(currentUid)
          .collection('starred_messages')
          .doc(message.id)
          .set({
        'chat_id': chatId,
        'message_id': message.id,
        'sender_id': message.senderId,
        'type': message.type.toJson(),
        'text': message.text,
        'media_url': message.mediaUrl,
        'file_name': message.fileName,
        'file_size': message.fileSize,
        'mime_type': message.mimeType,
        'duration_ms': message.durationMs,
        'created_at': Timestamp.fromDate(message.createdAt),
        'starred_at': FieldValue.serverTimestamp(),
      });
      print('⭐ ChatRepository: Starred message ${message.id}');
    } catch (e) {
      print('❌ ChatRepository: Error starring message: $e');
    }
  }

  /// Unstar a message
  Future<void> unstarMessage(String messageId) async {
    final currentUid = _currentUid;
    if (currentUid == null) return;

    try {
      await _firestore
          .collection('userChats')
          .doc(currentUid)
          .collection('starred_messages')
          .doc(messageId)
          .delete();
      print('⭐ ChatRepository: Unstarred message $messageId');
    } catch (e) {
      print('❌ ChatRepository: Error unstarring message: $e');
    }
  }

  /// Check if a message is starred
  Future<bool> isMessageStarred(String messageId) async {
    final currentUid = _currentUid;
    if (currentUid == null) return false;

    try {
      final doc = await _firestore
          .collection('userChats')
          .doc(currentUid)
          .collection('starred_messages')
          .doc(messageId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Subscribe to starred message IDs (returns Set of message IDs for quick lookup)
  Stream<Set<String>> subscribeToStarredMessageIds() {
    final currentUid = _currentUid;
    if (currentUid == null) return Stream.value({});

    return _firestore
        .collection('userChats')
        .doc(currentUid)
        .collection('starred_messages')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.id).toSet();
    });
  }

  /// Get all starred messages stream
  Stream<List<Map<String, dynamic>>> subscribeToStarredMessages() {
    final currentUid = _currentUid;
    if (currentUid == null) return Stream.value([]);

    return _firestore
        .collection('userChats')
        .doc(currentUid)
        .collection('starred_messages')
        .orderBy('starred_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }
}
