import 'dart:io';

import 'package:el_race/chat/models/chat_user.dart';
import 'package:el_race/chat/models/message.dart';
import 'package:el_race/chat/repositories/user_repository.dart';
import 'package:el_race/ui/chat/screens/sign_document_screen.dart';
import 'package:el_race/ui/chat/screens/sign_zone_picker_screen.dart';
import 'package:el_race/ui/presentation/my_actions/data/models/signature_document.dart';
import 'package:el_race/ui/presentation/my_actions/data/repositories/signature_documents_repository.dart';
import 'package:el_race/ui/presentation/my_actions/data/user_stamp_assets.dart';
import 'package:el_race/ui/presentation/my_actions/screens/signature/recipient_picker_screen.dart';
import 'package:el_race/ui/presentation/my_actions/theme/signature_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Opens the existing signature upload flow for a file shared via "Elrace Sign".
class IncomingShareSignFlow {
  IncomingShareSignFlow._();

  static Future<void> open(
    BuildContext context, {
    required File file,
    required String fileName,
  }) async {
    final lower = fileName.toLowerCase();
    if (!lower.endsWith('.pdf')) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Elrace Sign accepts PDF files only.'),
        ),
      );
      return;
    }

    final pickerResult = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => SignZonePickerScreen(pdfFile: file, fileName: fileName),
      ),
    );
    if (pickerResult == null || !context.mounted) return;

    final signZones = pickerResult['signZones'] as List<SignZone>;
    final pageCount = pickerResult['pageCount'] as int?;
    final stampNeeded = pickerResult['stampNeeded'] == true ||
        SignatureDocument.zonesNeedStamp(signZones);

    final choice = await _askUploadPurpose(context, stampNeeded: stampNeeded);
    if (choice == null || !context.mounted) return;

    if (choice == _UploadPurpose.signMyself) {
      await _selfSign(context, file, signZones, pageCount);
    } else {
      await _requestSignature(
        context,
        file,
        signZones,
        pageCount,
        stampNeeded: stampNeeded,
      );
    }
  }

  static Future<_UploadPurpose?> _askUploadPurpose(
    BuildContext context, {
    required bool stampNeeded,
  }) {
    final canSelfSign = !stampNeeded || UserStampAssets.isStampUser;
    return showModalBottomSheet<_UploadPurpose>(
      context: context,
      backgroundColor: SignatureTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What would you like to do?',
                    style: SignatureTheme.sectionTitle),
                const SizedBox(height: 4),
                Text(
                  stampNeeded
                      ? 'This document includes stamp zones.'
                      : 'Choose how this document should be signed.',
                  style: SignatureTheme.cardSubtitle,
                ),
                const SizedBox(height: 16),
                ListTile(
                  enabled: canSelfSign,
                  leading: const Icon(Icons.edit_rounded),
                  title: const Text('Sign it myself'),
                  subtitle: Text(
                    canSelfSign
                        ? 'Draw your signature and apply stamp zones you set.'
                        : 'Disabled — stamp required and you are not a stamp user.',
                  ),
                  onTap: canSelfSign
                      ? () => Navigator.pop(
                            sheetContext,
                            _UploadPurpose.signMyself,
                          )
                      : null,
                ),
                ListTile(
                  leading: const Icon(Icons.send_rounded),
                  title: const Text('Request signatures'),
                  subtitle: Text(
                    stampNeeded
                        ? 'Pick stamp-authorized signees — they sign and stamp one by one.'
                        : 'Pick one or more signees — they sign one by one with chat notifications.',
                  ),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    _UploadPurpose.requestSignature,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> _selfSign(
    BuildContext context,
    File file,
    List<SignZone> signZones,
    int? pageCount,
  ) async {
    try {
      final draft =
          await SignatureDocumentsRepository.instance.createSelfSignDraft(
        pdfFile: file,
        signZones: signZones,
        pageCount: pageCount,
      );
      if (!context.mounted) return;
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final message = Message(
        id: draft.id,
        senderId: currentUid,
        type: MessageType.signableDoc,
        mediaUrl: draft.fileUrl,
        fileName: draft.fileName,
        createdAt: draft.createdAt,
        clientMsgId: draft.id,
        signZones: draft.signZones,
        signStatus: SignStatus.pending,
        pageCount: draft.pageCount,
      );
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SignDocumentScreen(
            message: message,
            chatId: '',
            onSigned: (bytes) =>
                SignatureDocumentsRepository.instance.markSelfSigned(
              docId: draft.id,
              signedBytes: bytes,
              fileName: draft.fileName,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  static Future<void> _requestSignature(
    BuildContext context,
    File file,
    List<SignZone> signZones,
    int? pageCount, {
    required bool stampNeeded,
  }) async {
    final recipients = await Navigator.of(context).push<List<ChatUser>>(
      MaterialPageRoute(
        builder: (_) => RecipientPickerScreen(stampNeeded: stampNeeded),
      ),
    );
    if (recipients == null || recipients.isEmpty || !context.mounted) return;

    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final currentUser = currentUid != null
          ? await UserRepository.instance.getUser(currentUid)
          : null;

      await SignatureDocumentsRepository.instance.createSendForSignature(
        pdfFile: file,
        signZones: signZones,
        recipients: recipients,
        currentUserName: currentUser?.name ?? 'User',
        pageCount: pageCount,
      );
      if (!context.mounted) return;
      final label = recipients.length == 1
          ? recipients.first.name
          : '${recipients.first.name} +${recipients.length - 1} others';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sent to $label for signature')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    }
  }
}

enum _UploadPurpose { signMyself, requestSignature }
