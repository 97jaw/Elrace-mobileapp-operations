import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/signature_document.dart';
import '../../theme/signature_theme.dart';

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
    return Container(
      margin: EdgeInsets.only(bottom: 12.th),
      decoration: SignatureTheme.card(radius: 18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.tr),
        child: Padding(
          padding: EdgeInsets.all(12.tr),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(color: meta.color),
              SizedBox(width: 12.tw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SignatureTheme.cardTitle,
                    ),
                    SizedBox(height: 4.th),
                    Text(
                      DateFormat('dd-MMM-yy  HH:mm')
                          .format(document.createdAt),
                      style: SignatureTheme.cardSubtitle,
                    ),
                    SizedBox(height: 4.th),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 8.tw, vertical: 3.th),
                      decoration: BoxDecoration(
                        color: meta.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        meta.label,
                        style: SignatureTheme.cardSubtitle.copyWith(
                          color: meta.color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(height: 10.th),
                    Row(
                      children: [
                        _ActionButton(
                            icon: Icons.visibility_outlined,
                            label: 'View',
                            onTap: onTap),
                        SizedBox(width: 14.tw),
                        _ActionButton(
                            icon: Icons.share_outlined,
                            label: 'Share',
                            onTap: onShare),
                        SizedBox(width: 14.tw),
                        _ActionButton(
                            icon: Icons.download_outlined,
                            label: 'Download',
                            onTap: onDownload),
                        if (onDelete != null) ...[
                          SizedBox(width: 14.tw),
                          _ActionButton(
                              icon: Icons.delete_outline,
                              label: 'Delete',
                              color: SignatureTheme.expired,
                              onTap: onDelete!),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final Color color;
  const _Thumbnail({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52.tr,
      height: 64.tr,
      decoration: BoxDecoration(
        color: SignatureTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(10.tr),
        border: Border.all(color: SignatureTheme.divider),
      ),
      child: Icon(Icons.picture_as_pdf_rounded, color: color, size: 26.tsp),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? SignatureTheme.brown;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15.tsp, color: c),
          SizedBox(width: 3.tw),
          Text(
            label,
            style: SignatureTheme.cardSubtitle
                .copyWith(color: c, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
