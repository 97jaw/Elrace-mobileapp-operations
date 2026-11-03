import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/signature_document.dart';
import '../../theme/signature_theme.dart';
import 'signature_style_doc_row.dart';

/// iScanner-style document card for the Signature -> Documents tab:
/// PDF glyph thumbnail, file name, date and status, with
/// View / Share / Download quick actions.
class SignatureDocumentCard extends StatelessWidget {
  final SignatureDocument document;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onDownload;
  final VoidCallback? onDelete;

  const SignatureDocumentCard({
    super.key,
    required this.document,
    required this.onTap,
    required this.onShare,
    required this.onDownload,
    this.onDelete,
  });

  ({String label, Color color}) _statusMeta() {
    switch (document.status) {
      case SignatureDocumentStatus.draft:
        return (label: 'Draft', color: SignatureTheme.textMuted);
      case SignatureDocumentStatus.pendingSelf:
        return (label: 'Awaiting your signature', color: SignatureTheme.pending);
      case SignatureDocumentStatus.pendingOther:
        return (
          label: 'Waiting for ${document.recipientName ?? 'recipient'}',
          color: SignatureTheme.waiting,
        );
      case SignatureDocumentStatus.signed:
        return (label: 'Signed', color: SignatureTheme.signed);
      case SignatureDocumentStatus.expired:
        return (label: 'Expired', color: SignatureTheme.expired);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _statusMeta();
    return SignatureStyleDocRow(
      fileName: document.fileName,
      dateLabel: DateFormat('dd-MMM-yy  HH:mm').format(document.createdAt),
      statusLabel: meta.label,
      statusColor: meta.color,
      onTap: onTap,
      onShare: onShare,
      onDownload: onDownload,
      onDelete: onDelete,
    );
  }
}
