import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

import '../../../../../chat/models/chat_user.dart';
import '../../../../../chat/models/message.dart';
import '../../../../../chat/repositories/chat_repository.dart';
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

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _firestore.collection('users').doc(uid).collection('signature_documents');

  /// Live stream of the current user's documents, newest first.
  /// Never hangs forever on permission/index errors — emits `[]` instead.
  Stream<List<SignatureDocument>> watchMyDocuments() {
    final uid = _currentUid;
    if (uid == null) return Stream.value(const []);

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
  }

  Future<SignatureDocument> createSelfSignDraft({
    required File pdfFile,
    required List<SignZone> signZones,
    int? pageCount,
  }) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('Not authenticated');

    final docId = _uuid.v4();
    final fileName = p.basename(pdfFile.path);
    final storagePath = 'signature_documents/$uid/$docId/original_$fileName';

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
    );

    await _collection(uid).doc(docId).set(doc.toFirestore());
    return doc;
  }

  Future<void> markSelfSigned({
    required String docId,
    required Uint8List signedBytes,
    required String fileName,
  }) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('Not authenticated');

    final storagePath = 'signature_documents/$uid/$docId/signed_$fileName';
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
    final uid = _currentUid;
    if (uid == null) {
      throw Exception(
          'Not authenticated with Firebase. Open Chat once after login, then retry.');
    }
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
      if (e.code == 'permission-denied') {
        throw Exception(
          'Firestore permission denied while sending via chat '
          '(${e.message}). Confirm you are signed into Firebase Chat, '
          'then deploy firestore.rules if rules are outdated.',
        );
      }
      rethrow;
    }

    final doc = SignatureDocument(
      id: docId,
      ownerUid: uid,
      fileName: message.fileName ?? p.basename(pdfFile.path),
      fileUrl: message.mediaUrl ?? '',
      pageCount: pageCount,
      signZones: signZones,
      status: SignatureDocumentStatus.pendingOther,
      createdAt: DateTime.now(),
      recipientUid: first.uid,
      recipientName: recipients.length == 1
          ? first.name
          : '${first.name} +${recipients.length - 1}',
      chatId: chatId,
      messageId: message.id,
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

  Future<void> deleteDocument(String docId) async {
    final uid = _currentUid;
    if (uid == null) return;
    await _collection(uid).doc(docId).delete();
  }
}
