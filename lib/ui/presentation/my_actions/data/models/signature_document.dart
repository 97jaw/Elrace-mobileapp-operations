import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../../chat/models/message.dart';

/// Lifecycle of a document tracked in the My Actions -> Signature -> Documents tab.
enum SignatureDocumentStatus {
  draft,
  pendingSelf,
  pendingOther,
  signed,
  expired;

  static SignatureDocumentStatus fromString(String value) {
    switch (value) {
      case 'draft':
        return SignatureDocumentStatus.draft;
      case 'pending_self':
        return SignatureDocumentStatus.pendingSelf;
      case 'pending_other':
        return SignatureDocumentStatus.pendingOther;
      case 'signed':
        return SignatureDocumentStatus.signed;
      case 'expired':
        return SignatureDocumentStatus.expired;
      default:
        return SignatureDocumentStatus.draft;
    }
  }

  String toJson() {
    switch (this) {
      case SignatureDocumentStatus.pendingSelf:
        return 'pending_self';
      case SignatureDocumentStatus.pendingOther:
        return 'pending_other';
      default:
        return name;
    }
  }
}

/// A document owned by the current user in the Signature "Documents" tab.
///
/// Stored at: users/{uid}/signature_documents/{docId}
///
/// Covers three origins:
/// - Self-signed upload (no chat involved)
/// - Sent to someone else for signature (mirrors a chat signable_doc message)
/// - Received signable docs are NOT stored here; they live only on the
///   Home tab (sourced from chat messages) until the owner signs them,
///   at which point a copy can be added here for record-keeping.
class SignatureDocument {
  final String id;
  final String ownerUid;
  final String fileName;
  final String fileUrl;
  final String? thumbnailUrl;
  final int? pageCount;
  final List<SignZone> signZones;
  final SignatureDocumentStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Present when this document was sent to someone else for signature.
  final String? recipientUid;
  final String? recipientName;
  final String? chatId;
  final String? messageId;

  // Present once signed.
  final String? signedPdfUrl;
  final DateTime? signedAt;
  final String? signedBy;

  const SignatureDocument({
    required this.id,
    required this.ownerUid,
    required this.fileName,
    required this.fileUrl,
    this.thumbnailUrl,
    this.pageCount,
    this.signZones = const [],
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.recipientUid,
    this.recipientName,
    this.chatId,
    this.messageId,
    this.signedPdfUrl,
    this.signedAt,
    this.signedBy,
  });

  bool get isSentToOther => chatId != null && messageId != null;

  factory SignatureDocument.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SignatureDocument(
      id: doc.id,
      ownerUid: data['owner_uid'] ?? '',
      fileName: data['file_name'] ?? 'Document.pdf',
      fileUrl: data['file_url'] ?? '',
      thumbnailUrl: data['thumbnail_url'],
      pageCount: data['page_count'],
      signZones: data['sign_zones'] != null
          ? (data['sign_zones'] as List)
              .map((e) => SignZone.fromMap(e as Map<String, dynamic>))
              .toList()
          : const [],
      status: SignatureDocumentStatus.fromString(data['status'] ?? 'draft'),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
      recipientUid: data['recipient_uid'],
      recipientName: data['recipient_name'],
      chatId: data['chat_id'],
      messageId: data['message_id'],
      signedPdfUrl: data['signed_pdf_url'],
      signedAt: (data['signed_at'] as Timestamp?)?.toDate(),
      signedBy: data['signed_by'],
    );
  }

  Map<String, dynamic> toFirestore({bool isUpdate = false}) {
    final map = <String, dynamic>{
      'owner_uid': ownerUid,
      'file_name': fileName,
      'file_url': fileUrl,
      'status': status.toJson(),
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (!isUpdate) map['created_at'] = FieldValue.serverTimestamp();
    if (thumbnailUrl != null) map['thumbnail_url'] = thumbnailUrl;
    if (pageCount != null) map['page_count'] = pageCount;
    if (signZones.isNotEmpty) {
      map['sign_zones'] = signZones.map((z) => z.toMap()).toList();
    }
    if (recipientUid != null) map['recipient_uid'] = recipientUid;
    if (recipientName != null) map['recipient_name'] = recipientName;
    if (chatId != null) map['chat_id'] = chatId;
    if (messageId != null) map['message_id'] = messageId;
    if (signedPdfUrl != null) map['signed_pdf_url'] = signedPdfUrl;
    if (signedAt != null) map['signed_at'] = Timestamp.fromDate(signedAt!);
    if (signedBy != null) map['signed_by'] = signedBy;
    return map;
  }

  SignatureDocument copyWith({
    String? fileUrl,
    String? thumbnailUrl,
    SignatureDocumentStatus? status,
    DateTime? updatedAt,
    String? signedPdfUrl,
    DateTime? signedAt,
    String? signedBy,
  }) {
    return SignatureDocument(
      id: id,
      ownerUid: ownerUid,
      fileName: fileName,
      fileUrl: fileUrl ?? this.fileUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      pageCount: pageCount,
      signZones: signZones,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      recipientUid: recipientUid,
      recipientName: recipientName,
      chatId: chatId,
      messageId: messageId,
      signedPdfUrl: signedPdfUrl ?? this.signedPdfUrl,
      signedAt: signedAt ?? this.signedAt,
      signedBy: signedBy ?? this.signedBy,
    );
  }
}

/// An item for the Home tab, sourced from a chat `signable_doc` message.
/// Wraps the chat [Message] with enough context to render + navigate.
class SignatureActionItem {
  final Message message;
  final String chatId;
  final bool isSender;
  final String peerName;
  final String currentUid;

  const SignatureActionItem({
    required this.message,
    required this.chatId,
    required this.isSender,
    required this.peerName,
    required this.currentUid,
  });

  bool get isExpired {
    final expiresAt = message.expiresAt;
    if (expiresAt == null) return false;
    return message.signStatus != SignStatus.signed &&
        expiresAt.isBefore(DateTime.now());
  }

  bool get isMyTurnToSign {
    final current = message.currentSignerUid;
    if (current == null || current.isEmpty) return !isSender;
    return current == currentUid;
  }

  SignatureItemBucket get bucket {
    if (message.signStatus == SignStatus.signed) {
      return SignatureItemBucket.completed;
    }
    if (isExpired) return SignatureItemBucket.expired;
    if (isSender) return SignatureItemBucket.waitingForOthers;
    if (!isMyTurnToSign) return SignatureItemBucket.waitingForOthers;
    return SignatureItemBucket.needsSignature;
  }
}

enum SignatureItemBucket { needsSignature, waitingForOthers, completed, expired }
