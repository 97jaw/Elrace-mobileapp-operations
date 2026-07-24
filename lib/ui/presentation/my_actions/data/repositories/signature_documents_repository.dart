import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

import '../../../../../chat/models/chat_user.dart';
import '../../../../../chat/models/message.dart';
import '../../../../../chat/repositories/chat_repository.dart';
import '../../../../../chat/services/firebase_chat_auth_service.dart';
import '../models/signature_document.dart';

/// Owns the `users/{uid}/signature_documents` collection: the personal
/// document library backing the Signature -> Documents tab.
class SignatureDocumentsRepository {
  static SignatureDocumentsRepository? _instance;
  static SignatureDocumentsRepository get instance =>
      _instance ??= SignatureDocumentsRepository._();

  SignatureDocumentsRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  /// Storage path under `chat_media/` so existing Storage rules that already
  /// allow chat uploads also cover Signature self-sign / library files.
  String _storagePath(String uid, String docId, String fileName) =>
      'chat_media/signature_docs/$uid/$docId/$fileName';

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _firestore.collection('users').doc(uid).collection('signature_documents');

  /// Refresh / restore Firebase Auth via chat auth + `/api/firebase/refresh_token`.
  Future<String> _ensureUid() async {
    final user =
        await FirebaseChatAuthService.instance.ensureAuthenticated();
    return user.uid;
  }

  /// Live stream of the current user's documents, newest first.
  /// Never hangs forever on permission/index errors — emits `[]` instead.
  Stream<List<SignatureDocument>> watchMyDocuments() {
    return FirebaseAuth.instance.authStateChanges().switchMap((user) {
      final uid = user?.uid;
      if (uid == null || uid.isEmpty) {
        return Stream.value(const <SignatureDocument>[]);
      }

      // Prefer ordered query; fall back without orderBy if index is missing.
      final ordered = _collection(uid)
          .orderBy('created_at', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map(SignatureDocument.fromFirestore).toList());

      return ordered.onErrorResumeNext(
        _collection(uid).snapshots().map((snap) {
          final list =
              snap.docs.map(SignatureDocument.fromFirestore).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        }).onErrorReturnWith((error, _) {
          debugPrint('SignatureDocuments watch error: $error');
          return const <SignatureDocument>[];
        }),
      );
    });
  }

  Future<SignatureDocument> createSelfSignDraft({
    required File pdfFile,
    required List<SignZone> signZones,
    int? pageCount,
  }) async {
    final uid = await _ensureUid();

    final docId = _uuid.v4();
    final fileName = p.basename(pdfFile.path);
    final storagePath = _storagePath(uid, docId, 'original_$fileName');

    try {
      final ref = _storage.ref(storagePath);
      final bytes = await pdfFile.readAsBytes();
      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {'ownerUid': uid},
        ),
      );
      final fileUrl = await ref.getDownloadURL();

      final doc = SignatureDocument(
        id: docId,
        ownerUid: uid,
        fileName: fileName,
        fileUrl: fileUrl,
        pageCount: pageCount,
        signZones: signZones,
        status: SignatureDocumentStatus.pendingSelf,
        createdAt: DateTime.now(),
        stampNeeded: SignatureDocument.zonesNeedStamp(signZones),
      );

      await _collection(uid).doc(docId).set(doc.toFirestore());
      return doc;
    } on FirebaseException catch (e) {
      if (e.code == 'unauthorized' || e.code == 'permission-denied') {
        throw Exception(
          'Firebase Storage denied upload (${e.code}). '
          'Auth was refreshed; if this persists, Storage rules must allow '
          'chat_media/signature_docs/{uid}/**. ${e.message ?? ''}',
        );
      }
      rethrow;
    }
  }

  Future<void> markSelfSigned({
    required String docId,
    required Uint8List signedBytes,
    required String fileName,
  }) async {
    final uid = await _ensureUid();

    final storagePath = _storagePath(uid, docId, 'signed_$fileName');
    try {
      final ref = _storage.ref(storagePath);
      await ref.putData(
        signedBytes,
        SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {'signedBy': uid},
        ),
      );
      final signedUrl = await ref.getDownloadURL();

      await _collection(uid).doc(docId).update({
        'status': SignatureDocumentStatus.signed.toJson(),
        'signed_pdf_url': signedUrl,
        'signed_at': FieldValue.serverTimestamp(),
        'signed_by': uid,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'unauthorized' || e.code == 'permission-denied') {
        throw Exception(
          'Firebase Storage denied signed upload (${e.code}). '
          '${e.message ?? ''}',
        );
      }
      rethrow;
    }
  }

  /// Send a PDF to one or more signees sequentially.
  ///
  /// Only the first signee receives a chat `signable_doc` immediately
  /// (unread + notification). When they sign, [ChatRepository.signDocument]
  /// advances to the next signee automatically.
  Future<SignatureDocument> createSendForSignature({
    required File pdfFile,
    required List<SignZone> signZones,
    required List<ChatUser> recipients,
    required String currentUserName,
    int? pageCount,
  }) async {
    final uid = await _ensureUid();
    if (recipients.isEmpty) throw Exception('Select at least one signee');

    final signerUids = recipients.map((r) => r.uid).toList();
    final signerNames = recipients.map((r) => r.name).toList();
    final first = recipients.first;

    final docId = _uuid.v4();

    late final String chatId;
    late final Message message;
    try {
      chatId = await ChatRepository.instance.createOrGetDmChat(
        otherUid: first.uid,
        otherName: first.name,
        currentUserName: currentUserName,
      );

      message = await ChatRepository.instance.sendSignableDocument(
        chatId,
        pdfFile,
        signZones: signZones,
        pageCount: pageCount,
        signerUids: signerUids,
        signerNames: signerNames,
        currentSignerIndex: 0,
        signatureDocumentId: docId,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'unauthorized') {
        throw Exception(
          'Firebase permission denied while sending via chat '
          '(${e.code}: ${e.message}). Confirm Chat Firebase auth is active.',
        );
      }
      rethrow;
    }

    final sendingToSelf = first.uid == uid;
    final doc = SignatureDocument(
      id: docId,
      ownerUid: uid,
      fileName: message.fileName ?? p.basename(pdfFile.path),
      fileUrl: message.mediaUrl ?? '',
      pageCount: pageCount,
      signZones: signZones,
      // Request-to-self is my turn immediately → Needs My Signature.
      status: sendingToSelf
          ? SignatureDocumentStatus.pendingSelf
          : SignatureDocumentStatus.pendingOther,
      createdAt: DateTime.now(),
      recipientUid: first.uid,
      recipientName: recipients.length == 1
          ? first.name
          : '${first.name} +${recipients.length - 1}',
      chatId: chatId,
      messageId: message.id,
      stampNeeded: SignatureDocument.zonesNeedStamp(signZones),
    );

    final payload = doc.toFirestore();
    payload['signer_uids'] = signerUids;
    payload['signer_names'] = signerNames;
    payload['current_signer_index'] = 0;

    try {
      await _collection(uid).doc(docId).set(payload);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // Chat message already sent — Documents mirror is blocked by rules.
        throw Exception(
          'Document was sent in chat, but saving to Documents failed: '
          'Firestore rules for users/{uid}/signature_documents are missing. '
          'Deploy firestore.rules to Firebase (project elrace-new), then retry.',
        );
      }
      rethrow;
    }
    return doc;
  }

  /// Removes the personal library row and, when present, the linked chat
  /// `signable_doc` so it disappears from Documents / Home entirely.
  Future<void> deleteDocument(String docId, {SignatureDocument? doc}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    SignatureDocument? existing = doc;
    if (existing == null) {
      try {
        final snap = await _collection(uid).doc(docId).get();
        if (snap.exists) {
          existing = SignatureDocument.fromFirestore(snap);
        }
      } catch (_) {}
    }

    final chatId = existing?.chatId;
    final messageId = existing?.messageId;

    try {
      await _collection(uid).doc(docId).delete();
    } catch (e) {
      debugPrint('SignatureDocuments delete personal failed: $e');
      rethrow;
    }

    if (chatId != null &&
        chatId.isNotEmpty &&
        messageId != null &&
        messageId.isNotEmpty) {
      try {
        await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(messageId)
            .delete();
      } catch (e) {
        debugPrint(
            'SignatureDocuments: chat message delete skipped ($chatId/$messageId): $e');
      }
    }
  }

  /// Hide a chat-only signature row (no personal mirror) from Documents.
  Future<void> deleteChatSignable({
    required String chatId,
    required String messageId,
  }) async {
    if (chatId.isEmpty || messageId.isEmpty) return;
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }
}
