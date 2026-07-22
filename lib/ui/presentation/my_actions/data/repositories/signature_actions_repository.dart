import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../../chat/models/chat.dart';
import '../../../../../chat/models/message.dart';
import '../../../../../chat/models/user_chat.dart';
import '../../../../../chat/repositories/chat_repository.dart';
import '../../../../../chat/repositories/user_repository.dart';
import '../models/signature_document.dart';

/// Aggregates chat `signable_doc` messages that are **related to the
/// logged-in user only** (sender, listed signee, or DM peer on legacy docs).
class SignatureActionsRepository {
  static SignatureActionsRepository? _instance;
  static SignatureActionsRepository get instance =>
      _instance ??= SignatureActionsRepository._();

  SignatureActionsRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, String> _peerNameCache = {};

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  /// Count of documents currently waiting on the logged-in user to sign.
  /// Used by the My Actions Signature badge.
  Stream<int> watchNeedsMySignatureCount() {
    return watchMySignatureActions().map(
      (items) => items
          .where((i) => i.bucket == SignatureItemBucket.needsSignature)
          .length,
    );
  }

  /// Live-updating list of signable-doc activity for the current user.
  Stream<List<SignatureActionItem>> watchMySignatureActions() {
    final uid = _currentUid;
    if (uid == null) return Stream.value(const []);

    return ChatRepository.instance.subscribeToUserChats(uid).switchMap((chats) {
      if (chats.isEmpty) return Stream.value(const <SignatureActionItem>[]);

      final perChatStreams = chats
          .map((chat) => _watchSignableDocsForChat(chat, uid))
          .toList();

      return Rx.combineLatestList<List<SignatureActionItem>>(perChatStreams)
          .map((lists) {
        final items = lists.expand((e) => e).toList();
        items.sort((a, b) => b.message.createdAt.compareTo(a.message.createdAt));
        return items;
      }).onErrorReturnWith((error, _) {
        debugPrint('SignatureActions combine error: $error');
        return const <SignatureActionItem>[];
      });
    }).onErrorReturnWith((error, _) {
      debugPrint('SignatureActions chats error: $error');
      return const <SignatureActionItem>[];
    });
  }

  Stream<List<SignatureActionItem>> _watchSignableDocsForChat(
    UserChat chat,
    String currentUid,
  ) {
    final isDm = chat.type == ChatType.dm || chat.chatId.startsWith('dm_');

    return _firestore
        .collection('chats')
        .doc(chat.chatId)
        .collection('messages')
        .where('type', isEqualTo: 'signable_doc')
        .snapshots()
        .asyncMap((snapshot) async {
      final peerName = await _resolvePeerName(chat.peerUid);
      final items = <SignatureActionItem>[];
      for (final doc in snapshot.docs) {
        final message = Message.fromFirestore(doc);
        if (!_isRelatedToUser(message, currentUid, isDm: isDm)) continue;

        final signers = message.signerUids;
        final currentSigner = message.currentSignerUid;
        final mySignerIndex =
            signers != null ? signers.indexOf(currentUid) : -1;
        final curIndex = message.currentSignerIndex ?? 0;

        // Already signed my turn in a multi-signee chain — skip from recent.
        if (mySignerIndex >= 0 &&
            message.signStatus != SignStatus.signed &&
            mySignerIndex < curIndex) {
          continue;
        }

        // Later signees wait their turn — hide until current_signer matches.
        if (signers != null &&
            signers.isNotEmpty &&
            message.senderId != currentUid &&
            currentSigner != null &&
            currentSigner != currentUid &&
            message.signStatus != SignStatus.signed) {
          continue;
        }

        items.add(SignatureActionItem(
          message: message,
          chatId: chat.chatId,
          isSender: message.senderId == currentUid,
          peerName: peerName,
          currentUid: currentUid,
        ));
      }
      return items;
    }).onErrorReturnWith((error, _) {
      debugPrint('SignatureActions chat ${chat.chatId} error: $error');
      return const <SignatureActionItem>[];
    });
  }

  /// Related if user sent it, is listed as a signee, or (legacy) is DM peer.
  bool _isRelatedToUser(Message message, String uid, {required bool isDm}) {
    if (message.senderId == uid) return true;
    final signers = message.signerUids;
    if (signers != null && signers.isNotEmpty) {
      return signers.contains(uid);
    }
    // Legacy chat signable docs without signer list: only DMs.
    return isDm;
  }

  Future<String> _resolvePeerName(String? peerUid) async {
    if (peerUid == null || peerUid.isEmpty) return 'Colleague';
    final cached = _peerNameCache[peerUid];
    if (cached != null) return cached;
    final user = await UserRepository.instance.getUser(peerUid);
    final name = user?.name ?? 'Unknown';
    _peerNameCache[peerUid] = name;
    return name;
  }
}
