import 'dart:convert';
import 'dart:io';

import 'package:el_race/chat/models/chat.dart';
import 'package:el_race/chat/models/chat_member.dart';
import 'package:el_race/chat/models/message.dart';
import 'package:el_race/chat/models/user_chat.dart';
import 'package:el_race/ui/presentation/my_actions/data/models/signature_document.dart';
import 'package:el_race/ui/presentation/my_notes/data/note_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keys the mobile writers persist, plus the Hub web writer's keys.
///
/// App-written keys must be a subset of the keys the rules allow. The rules
/// list may be larger. Notes, signature documents, userChats, and members
/// have no key allow-list, so any key those writers send is allowed and the
/// emulator create is what proves it.
///
/// Hub keys are the Firestore fields in `docs/hub_chat_contract.md` (the
/// confirmed Hub web write schema). The Hub frontend checkout is not in this
/// workspace; `RccHub-backend` does not write these documents.
void main() {
  final fixtureFile = File('firebase/rules-tests/fixtures/write_keys.json');
  final rulesFile = File('firestore.rules');

  test('app and Hub write keys are allowed by the rules', () {
    final fixture = jsonDecode(fixtureFile.readAsStringSync()) as Map;
    final mobile = _contractKeys();
    expect(
      mobile,
      fixture['mobile'],
      reason: 'Update writers.mobile in '
          'firebase/rules-tests/fixtures/write_keys.json when a model '
          'starts persisting a new key.',
    );

    final allowedMessages = _allowedMessageKeys(rulesFile.readAsStringSync());
    for (final entry in (mobile['messages'] as Map).entries) {
      final missing = (entry.value as List)
          .where((key) => !allowedMessages.contains(key))
          .toList();
      expect(
        missing,
        isEmpty,
        reason: 'message type ${entry.key} writes keys the rules do not allow',
      );
    }

    final hubMessages = (fixture['hub'] as Map)['messages'] as List;
    final hubMissing =
        hubMessages.where((key) => !allowedMessages.contains(key)).toList();
    expect(
      hubMissing,
      isEmpty,
      reason: 'Hub message keys are not in the message allow-lists',
    );
  });
}

Set<String> _allowedMessageKeys(String rules) {
  final names = [
    'messageCreateKeysAllowed',
    'signingKeysOnly',
    'isSoftDeleteUpdate',
    'isOwnMessageNonSenderEdit',
  ];
  final keys = <String>{};
  for (final name in names) {
    final start = rules.indexOf('function $name');
    expect(start, greaterThanOrEqualTo(0), reason: 'missing $name');
    final next = rules.indexOf('\n    function ', start + 1);
    final body = rules.substring(start, next == -1 ? rules.length : next);
    keys.addAll(RegExp(r"'([A-Za-z0-9_]+)'").allMatches(body).map((m) => m.group(1)!));
  }
  return keys;
}

Map<String, dynamic> _contractKeys() {
  final now = DateTime.utc(2026, 1, 1);
  final messages = <String, List<String>>{};
  for (final type in MessageType.values) {
    messages[type.toJson()] = _keys(_fullMessage(type, now).toFirestore());
  }
  return {
    'messages': messages,
    'signature_documents': _keys(_fullSignature(now).toFirestore()),
    'notes': _keys(_fullNote(now).toFirestore()),
    'userChats': _keys(_fullUserChat(now).toFirestore()),
    'members': _keys(_fullMember(now).toFirestore()),
  };
}

List<String> _keys(Map<String, dynamic> data) {
  final keys = data.keys.map((key) => key.toString()).toList()..sort();
  return keys;
}

Message _fullMessage(MessageType type, DateTime now) {
  return Message(
    id: 'contract',
    senderId: 'odoo_100',
    type: type,
    text: 'hello',
    mediaUrl: 'https://example.com/media',
    mediaPath: 'chat_media/contract',
    fileName: 'file.bin',
    fileSize: 12,
    mimeType: 'application/octet-stream',
    durationMs: 1000,
    thumbUrl: 'https://example.com/thumb',
    replyTo: ReplyTo(
      messageId: 'm1',
      senderId: 'odoo_100',
      text: 'earlier',
      type: 'text',
    ),
    createdAt: now,
    clientMsgId: 'client-1',
    status: MessageStatus.sent,
    signZones: const [
      SignZone(page: 0, x: 0.1, y: 0.1, width: 0.2, height: 0.08),
    ],
    signStatus: SignStatus.pending,
    signedPdfUrl: 'https://example.com/signed.pdf',
    signedAt: now,
    signedBy: 'odoo_100',
    signExpiresInDays: 7,
    expiresAt: now,
    pageCount: 2,
    signerUids: const ['odoo_100', 'odoo_200'],
    signerNames: const ['Alice', 'Bob'],
    currentSignerIndex: 0,
    currentSignerUid: 'odoo_200',
    signatureDocumentId: 'doc-1',
  );
}

SignatureDocument _fullSignature(DateTime now) {
  return SignatureDocument(
    id: 'doc-1',
    ownerUid: 'odoo_100',
    fileName: 'contract.pdf',
    fileUrl: 'https://example.com/contract.pdf',
    thumbnailUrl: 'https://example.com/thumb',
    pageCount: 2,
    signZones: const [
      SignZone(page: 0, x: 0.1, y: 0.1, width: 0.2, height: 0.08),
    ],
    status: SignatureDocumentStatus.pendingOther,
    createdAt: now,
    updatedAt: now,
    recipientUid: 'odoo_200',
    recipientName: 'Bob',
    chatId: 'dm_odoo_100_odoo_200',
    messageId: 'm-sign',
    signedPdfUrl: 'https://example.com/signed.pdf',
    signedAt: now,
    signedBy: 'odoo_200',
    stampNeeded: true,
  );
}

NoteModel _fullNote(DateTime now) {
  return NoteModel(
    id: 'note-1',
    ownerId: 'odoo_100',
    title: 'Title',
    content: 'Body',
    noteType: NoteType.audio,
    tags: const ['work'],
    isImportant: true,
    isTodo: true,
    createdAt: now,
    updatedAt: now,
    aiMode: NoteAiMode.summarize,
    aiContext: 'meeting',
    aiStatus: NoteAiStatus.done,
    aiSummary: 'Short',
    aiBulletPoints: '- one',
    translatedText: 'translated',
    translatedLanguage: 'ar',
    actionItems: [
      ActionItem(
        id: 'a1',
        description: 'Follow up',
        isDone: false,
        dueDate: now,
      ),
    ],
    recording: const RecordingInfo(
      audioUrl: 'https://example.com/audio.m4a',
      durationSeconds: 3,
      language: 'en',
      transcript: 'hello',
      status: TranscriptionStatus.done,
      storagePath: 'chat_media/notes/odoo_100/note-1/audio.m4a',
    ),
    images: [
      ImageAttachment(
        id: 'img-1',
        imageUrl: 'https://example.com/image.jpg',
        thumbnailUrl: 'https://example.com/image-thumb.jpg',
        caption: 'photo',
        addedAt: now,
      ),
    ],
    sharedWithUids: const ['odoo_200'],
    sharedWith: const [
      NoteSharedMember(uid: 'odoo_200', employeeId: 2, name: 'Bob'),
    ],
  );
}

UserChat _fullUserChat(DateTime now) {
  return UserChat(
    chatId: 'dm_odoo_100_odoo_200',
    type: ChatType.dm,
    title: 'Bob',
    peerUid: 'odoo_200',
    roleId: 5,
    branchId: 1,
    companyId: 1,
    supportUserUid: 'odoo_100',
    supportGroupTitle: 'HR',
    updatedAt: now,
    pinned: true,
    muted: false,
    archived: false,
    hasMessages: true,
  );
}

ChatMember _fullMember(DateTime now) {
  return ChatMember(
    uid: 'odoo_100',
    joinedAt: now,
    roleIdSnapshot: 5,
    branchIdSnapshot: 1,
    companyIdSnapshot: 1,
    muted: false,
    isAdmin: false,
  );
}
