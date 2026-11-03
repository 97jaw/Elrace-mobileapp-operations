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

  /// True when any [signZones] entry is a stamp zone.
  final bool stampNeeded;

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
    this.stampNeeded = false,
  });

  bool get isSentToOther => chatId != null && messageId != null;

  static bool zonesNeedStamp(List<SignZone> zones) =>
      zones.any((z) => z.type == SignZoneType.stamp);

  factory SignatureDocument.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final zones = data['sign_zones'] != null
        ? (data['sign_zones'] as List)
            .map((e) => SignZone.fromMap(e as Map<String, dynamic>))
            .toList()
        : const <SignZone>[];
    return SignatureDocument(
      id: doc.id,
      ownerUid: data['owner_uid'] ?? '',
      fileName: data['file_name'] ?? 'Document.pdf',
      fileUrl: data['file_url'] ?? '',
      thumbnailUrl: data['thumbnail_url'],
      pageCount: data['page_count'],
      signZones: zones,
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
      stampNeeded: data['stamp_needed'] == true || zonesNeedStamp(zones),
    );
  }

  Map<String, dynamic> toFirestore({bool isUpdate = false}) {
    final map = <String, dynamic>{
      'owner_uid': ownerUid,
      'file_name': fileName,
      'file_url': fileUrl,
      'status': status.toJson(),
      'stamp_needed': stampNeeded || zonesNeedStamp(signZones),
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
    String? recipientUid,
    String? recipientName,
    String? signedPdfUrl,
    DateTime? signedAt,
    String? signedBy,
    bool? stampNeeded,
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
      recipientUid: recipientUid ?? this.recipientUid,
      recipientName: recipientName ?? this.recipientName,
      chatId: chatId,
      messageId: messageId,
      signedPdfUrl: signedPdfUrl ?? this.signedPdfUrl,
      signedAt: signedAt ?? this.signedAt,
      signedBy: signedBy ?? this.signedBy,
      stampNeeded: stampNeeded ?? this.stampNeeded,
    );
  }
}

/// An item for the Home tab.
///
/// Usually sourced from a chat `signable_doc` message. Self-sign drafts from
/// the Documents library use [personalDoc] so they count under
/// "Needs My Signature" even with no chat thread yet.
class SignatureActionItem {
  final Message message;
  final String chatId;
  final bool isSender;
  final String peerName;
  final String currentUid;

  /// When set, this row is a personal library document (Sign Myself / mirror).
  final SignatureDocument? personalDoc;

  const SignatureActionItem({
    required this.message,
    required this.chatId,
    required this.isSender,
    required this.peerName,
    required this.currentUid,
    this.personalDoc,
  });

  /// Build a Home-tab item from a personal `signature_documents` record.
  factory SignatureActionItem.fromPersonal(
    SignatureDocument doc,
    String currentUid,
  ) {
    final isPendingSelf = doc.status == SignatureDocumentStatus.pendingSelf ||
        (doc.status == SignatureDocumentStatus.pendingOther &&
            doc.recipientUid == currentUid);
    final isSigned = doc.status == SignatureDocumentStatus.signed;
    return SignatureActionItem(
      message: Message(
        id: doc.id,
        senderId: currentUid,
        type: MessageType.signableDoc,
        mediaUrl: doc.fileUrl,
        fileName: doc.fileName,
        createdAt: doc.createdAt,
        clientMsgId: doc.id,
        signZones: doc.signZones,
        signStatus: isSigned ? SignStatus.signed : SignStatus.pending,
        signedPdfUrl: doc.signedPdfUrl,
        pageCount: doc.pageCount,
        signerUids: isPendingSelf ? [currentUid] : null,
        currentSignerUid: isPendingSelf ? currentUid : null,
        currentSignerIndex: isPendingSelf ? 0 : null,
        signatureDocumentId: doc.id,
      ),
      chatId: doc.chatId ?? '',
      isSender: doc.status == SignatureDocumentStatus.pendingOther &&
          doc.recipientUid != currentUid,
      peerName: doc.recipientName ?? 'You',
      currentUid: currentUid,
      personalDoc: doc,
    );
  }

  bool get isExpired {
    if (personalDoc?.status == SignatureDocumentStatus.expired) return true;
    final expiresAt = message.expiresAt;
    if (expiresAt == null) return false;
    return message.signStatus != SignStatus.signed &&
        expiresAt.isBefore(DateTime.now());
  }

  bool get isMyTurnToSign {
    if (personalDoc?.status == SignatureDocumentStatus.pendingSelf) {
      return true;
    }
    if (personalDoc?.status == SignatureDocumentStatus.pendingOther &&
        personalDoc?.recipientUid == currentUid) {
      return true;
    }
    final current = message.currentSignerUid;
    if (current == null || current.isEmpty) return !isSender;
    return current == currentUid;
  }

  /// Stable label for who the doc is waiting on (prefers signer_names).
  String get waitingForDisplayName {
    final names = message.signerNames;
    final idx = message.currentSignerIndex ?? 0;
    if (names != null &&
        idx >= 0 &&
        idx < names.length &&
        names[idx].trim().isNotEmpty) {
      final name = names[idx].trim();
      if (message.currentSignerUid == currentUid || name == peerName) {
        // If somehow waiting on self, callers should use needsSignature instead.
      }
      return name;
    }
    final personalName = personalDoc?.recipientName?.trim();
    if (personalName != null && personalName.isNotEmpty) return personalName;
    if (peerName.trim().isNotEmpty &&
        peerName != 'Colleague' &&
        peerName != 'Unknown') {
      return peerName;
    }
    return peerName.isNotEmpty ? peerName : 'recipient';
  }

  SignatureItemBucket get bucket {
    // Live chat message wins over a stale personal library copy.
    // (Signer B often cannot write users/{A}/signature_documents — personal
    // can remain pending_other after the chat message is already signed.)
    if (message.signStatus == SignStatus.signed) {
      return SignatureItemBucket.completed;
    }
    if (isExpired) return SignatureItemBucket.expired;

    final personal = personalDoc;
    if (personal != null) {
      switch (personal.status) {
        case SignatureDocumentStatus.pendingSelf:
          return SignatureItemBucket.needsSignature;
        case SignatureDocumentStatus.pendingOther:
          // Sent to myself (or I'm the current recipient) → needs my signature.
          if (personal.recipientUid == currentUid || isMyTurnToSign) {
            return SignatureItemBucket.needsSignature;
          }
          return SignatureItemBucket.waitingForOthers;
        case SignatureDocumentStatus.signed:
          return SignatureItemBucket.completed;
        case SignatureDocumentStatus.expired:
          return SignatureItemBucket.expired;
        case SignatureDocumentStatus.draft:
          return SignatureItemBucket.waitingForOthers;
      }
    }
    // My turn wins even when I am also the sender (request-to-self).
    if (isMyTurnToSign) return SignatureItemBucket.needsSignature;
    if (isSender) return SignatureItemBucket.waitingForOthers;
    return SignatureItemBucket.waitingForOthers;
  }
}

enum SignatureItemBucket { needsSignature, waitingForOthers, completed, expired }
