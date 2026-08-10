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
  /// Forces a fresh ID token so Storage / Firestore see a valid auth context.
  Future<String> _ensureUid({bool forceRefresh = false}) async {
    if (forceRefresh) {
      // Drop stale Auth session so ensureAuthenticated must re-sign with a
      // fresh custom token (Storage "unauthorized" after long Documents use).
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }

    final user =
        await FirebaseChatAuthService.instance.ensureAuthenticated();
    await user.getIdToken(true);
    return user.uid;
  }

  bool _isAuthDenied(FirebaseException e) =>
      e.code == 'unauthorized' ||
      e.code == 'permission-denied' ||
      e.code == 'unauthenticated';

  /// Run [action] after auth; on Storage/Firestore auth denial, force refresh once and retry.
  Future<T> _withFirebaseAuthRetry<T>(Future<T> Function() action) async {
    await _ensureUid();
    try {
      return await action();
    } on FirebaseException catch (e) {
      if (!_isAuthDenied(e)) rethrow;
      debugPrint(
          '⚠️ SignatureDocuments: auth denied (${e.code}), refreshing and retrying…');
      await _ensureUid(forceRefresh: true);
      // Brief yield so Auth/Storage clients pick up the new token.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return await action();
    }
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
    return _withFirebaseAuthRetry(() async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        throw Exception('Firebase auth required');
      }

      final docId = _uuid.v4();
      final fileName = p.basename(pdfFile.path);
      final storagePath = _storagePath(uid, docId, 'original_$fileName');

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
    });
  }

  Future<void> markSelfSigned({
    required String docId,
    required Uint8List signedBytes,
    required String fileName,
  }) async {
    await _withFirebaseAuthRetry(() async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        throw Exception('Firebase auth required');
      }

      final storagePath = _storagePath(uid, docId, 'signed_$fileName');
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
    });
  }

  /// Owner-side heal when chat message is already signed but personal library
  /// copy is still pending (sync from signer failed previously).
  Future<void> healSignedFromChat({
    required String docId,
    required String? signedPdfUrl,
    required String? signedBy,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) return;
      final ref = _collection(uid).doc(docId);
      final snap = await ref.get();
      if (!snap.exists) return;
      final status = snap.data()?['status']?.toString() ?? '';
      if (status == 'signed' || status == 'expired') return;
      await ref.set({
        'status': 'signed',
        if (signedPdfUrl != null && signedPdfUrl.isNotEmpty) ...{
          'signed_pdf_url': signedPdfUrl,
          'file_url': signedPdfUrl,
        },
        if (signedBy != null && signedBy.isNotEmpty) 'signed_by': signedBy,
        'signed_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ SignatureDocuments: healed $docId → signed');
    } catch (e) {
      debugPrint('⚠️ SignatureDocuments: healSignedFromChat failed: $e');
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
    if (recipients.isEmpty) throw Exception('Select at least one signee');

    try {
      return await _withFirebaseAuthRetry(() async {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null || uid.isEmpty) {
          throw Exception('Firebase auth required');
        }

        final signerUids = recipients.map((r) => r.uid).toList();
        final signerNames = recipients.map((r) => r.name).toList();
        final first = recipients.first;
        final docId = _uuid.v4();

        await FirebaseChatAuthService.instance.ensureAuthenticated();

        final chatId = await ChatRepository.instance.createOrGetDmChat(
          otherUid: first.uid,
          otherName: first.name,
          currentUserName: currentUserName,
        );

        final message = await ChatRepository.instance.sendSignableDocument(
          chatId,
          pdfFile,
          signZones: signZones,
          pageCount: pageCount,
          signerUids: signerUids,
          signerNames: signerNames,
          currentSignerIndex: 0,
          signatureDocumentId: docId,
        );

        final sendingToSelf = first.uid == uid;
        final doc = SignatureDocument(
          id: docId,
          ownerUid: uid,
          fileName: message.fileName ?? p.basename(pdfFile.path),
          fileUrl: message.mediaUrl ?? '',
          pageCount: pageCount,
          signZones: signZones,
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

        await _collection(uid).doc(docId).set(payload);
        return doc;
      });
    } on FirebaseException catch (e) {
      if (_isAuthDenied(e)) {
        throw Exception(
          'Firebase permission denied while sending via chat '
          '(${e.code}: ${e.message}). Auth was refreshed and retried — '
          'confirm Storage rules allow chat_media/** and Chat Firebase login works.',
        );
      }
      if (e.code == 'permission-denied') {
        throw Exception(
          'Document chat send or Documents save failed (${e.code}). '
          'Confirm firestore.rules include signature_documents and chats access.',
        );
      }
      rethrow;
    }
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
