import 'dart:async';

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
import 'signature_documents_repository.dart';

/// Aggregates signature activity for the logged-in user:
/// - Chat `signable_doc` messages (request-signature / received requests)
/// - Personal library docs (`users/{uid}/signature_documents`), especially
///   Sign Myself drafts that are still `pending_self`
class SignatureActionsRepository {
  static SignatureActionsRepository? _instance;
  static SignatureActionsRepository get instance =>
      _instance ??= SignatureActionsRepository._();

  SignatureActionsRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, String> _peerNameCache = {};
  final Set<String> _healAttempted = {};

  /// Count of documents currently waiting on the logged-in user to sign.
  /// Used by the My Actions Signature badge.
  ///
  /// Chat needs-signature and personal `pending_self` are counted separately
  /// so a Documents-library permission/index error cannot wipe the chat badge.
  Stream<int> watchNeedsMySignatureCount() {
    return FirebaseAuth.instance.authStateChanges().switchMap((user) {
      final uid = user?.uid;
      if (uid == null || uid.isEmpty) return Stream.value(0);

      final chatCount = _watchChatSignatureActions(uid)
          .map((items) => items
              .where((i) => i.bucket == SignatureItemBucket.needsSignature)
              .length)
          .startWith(0)
          .onErrorReturnWith((error, _) {
        debugPrint('SignatureActions chat count error: $error');
        return 0;
      });

      final personalCount = SignatureDocumentsRepository.instance
          .watchMyDocuments()
          .map((docs) => docs.where((d) {
                if (d.status == SignatureDocumentStatus.pendingSelf) {
                  return true;
                }
                // Request-to-self stored as pending_other before this fix.
                return d.status == SignatureDocumentStatus.pendingOther &&
                    d.recipientUid == uid;
              }).length)
          .startWith(0)
          .onErrorReturnWith((error, _) {
        debugPrint('SignatureActions personal count error: $error');
        return 0;
      });

      return Rx.combineLatest2<int, int, int>(
        chatCount,
        personalCount,
        (a, b) => a + b,
      );
    });
  }

  /// Live-updating list of signature activity for the current user.
  Stream<List<SignatureActionItem>> watchMySignatureActions() {
    return FirebaseAuth.instance.authStateChanges().switchMap((user) {
      final uid = user?.uid;
      if (uid == null || uid.isEmpty) {
        return Stream.value(const <SignatureActionItem>[]);
      }

      final chatStream = _watchChatSignatureActions(uid)
          .startWith(const <SignatureActionItem>[])
          .onErrorReturnWith((error, _) {
        debugPrint('SignatureActions chats stream error: $error');
        return const <SignatureActionItem>[];
      });

      final personalStream = SignatureDocumentsRepository.instance
          .watchMyDocuments()
          .startWith(const <SignatureDocument>[])
          .onErrorReturnWith((error, _) {
        debugPrint('SignatureActions personal stream error: $error');
        return const <SignatureDocument>[];
      });

      return Rx.combineLatest2<List<SignatureActionItem>,
          List<SignatureDocument>, List<SignatureActionItem>>(
        chatStream,
        personalStream,
        (chatItems, personalDocs) {
          final personalById = {
            for (final doc in personalDocs) doc.id: doc,
          };
          final chatLinkedDocIds = <String>{};

          final enrichedChat = <SignatureActionItem>[];
          for (final item in chatItems) {
            final linked = item.message.signatureDocumentId;
            SignatureDocument? personal;
            if (linked != null && linked.isNotEmpty) {
              chatLinkedDocIds.add(linked);
              personal = personalById[linked];
            }

            // Heal stale personal pending_* when chat is already signed.
            if (item.isSender &&
                item.message.signStatus == SignStatus.signed &&
                personal != null &&
                personal.status != SignatureDocumentStatus.signed &&
                personal.status != SignatureDocumentStatus.expired &&
                !_healAttempted.contains(personal.id)) {
              _healAttempted.add(personal.id);
              unawaited(
                SignatureDocumentsRepository.instance.healSignedFromChat(
                  docId: personal.id,
                  signedPdfUrl: item.message.signedPdfUrl ??
                      item.message.mediaUrl,
                  signedBy: item.message.signedBy,
                ),
              );
            }

            enrichedChat.add(personal == null
                ? item
                : SignatureActionItem(
                    message: item.message,
                    chatId: item.chatId,
                    isSender: item.isSender,
                    peerName: item.peerName,
                    currentUid: item.currentUid,
                    personalDoc: personal,
                  ));
          }

          final personalItems = <SignatureActionItem>[];
          for (final doc in personalDocs) {
            if (chatLinkedDocIds.contains(doc.id)) continue;
            if (doc.status == SignatureDocumentStatus.draft) continue;
            if (doc.status == SignatureDocumentStatus.signed) continue;
            if (doc.status == SignatureDocumentStatus.expired) continue;
            personalItems.add(SignatureActionItem.fromPersonal(doc, uid));
          }

          final merged = <SignatureActionItem>[...enrichedChat, ...personalItems];
          merged.sort(
              (a, b) => b.message.createdAt.compareTo(a.message.createdAt));
          return merged;
        },
      );
    });
  }

  Stream<List<SignatureActionItem>> _watchChatSignatureActions(String uid) {
    return ChatRepository.instance.subscribeToUserChats(uid).switchMap((chats) {
      if (chats.isEmpty) return Stream.value(const <SignatureActionItem>[]);

      final perChatStreams =
          chats.map((chat) => _watchSignableDocsForChat(chat, uid)).toList();

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
      final chatPeerName = await _resolvePeerName(
        chat.peerUid,
        currentUid: currentUid,
      );
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
          peerName: _peerNameForMessage(message, chatPeerName),
          currentUid: currentUid,
        ));
      }
      return items;
    }).onErrorReturnWith((error, _) {
      debugPrint('SignatureActions chat ${chat.chatId} error: $error');
      return const <SignatureActionItem>[];
    });
  }

  /// Prefer message signer_names (stable) over chat peer lookup ("Colleague").
  String _peerNameForMessage(Message message, String chatPeerName) {
    final names = message.signerNames;
    final idx = message.currentSignerIndex ?? 0;
    if (names != null &&
        idx >= 0 &&
        idx < names.length &&
        names[idx].trim().isNotEmpty) {
      return names[idx].trim();
    }
    if (names != null && names.isNotEmpty && names.first.trim().isNotEmpty) {
      return names.first.trim();
    }
    return chatPeerName;
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

  Future<String> _resolvePeerName(
    String? peerUid, {
    required String currentUid,
  }) async {
    if (peerUid == null || peerUid.isEmpty) return 'Colleague';
    final cached = _peerNameCache[peerUid];
    if (cached != null) return cached;
    if (peerUid == currentUid) {
      final self = await UserRepository.instance.getUser(peerUid);
      final name = self?.name.trim();
      final resolved =
          (name != null && name.isNotEmpty) ? name : 'You';
      _peerNameCache[peerUid] = resolved;
      return resolved;
    }
    final user = await UserRepository.instance.getUser(peerUid);
    final name = user?.name ?? 'Unknown';
    _peerNameCache[peerUid] = name;
    return name;
  }
}
