import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/signature_document.dart';
import '../../theme/signature_theme.dart';

/// A single row in the Home tab "Recent Documents" list.
class SignatureActionTile extends StatelessWidget {
  final SignatureActionItem item;
  final VoidCallback onTap;

  const SignatureActionTile({
    super.key,
    required this.item,
    required this.onTap,
  });

  ({IconData icon, Color color, String label}) _statusMeta() {
    switch (item.bucket) {
      case SignatureItemBucket.needsSignature:
        return (
          icon: Icons.edit_note_rounded,
          color: SignatureTheme.pending,
          label: 'Needs your signature',
        );
      case SignatureItemBucket.waitingForOthers:
        return (
          icon: Icons.hourglass_top_rounded,
          color: SignatureTheme.waiting,
          label: 'Waiting for ${item.waitingForDisplayName}',
        );
      case SignatureItemBucket.completed:
        return (
          icon: Icons.check_circle_rounded,
          color: SignatureTheme.signed,
          label: item.isSender
              ? 'Signed by ${item.peerName}'
              : 'Completed by you',
        );
      case SignatureItemBucket.expired:
        return (
          icon: Icons.timer_off_rounded,
          color: SignatureTheme.expired,
          label: 'Expired',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _statusMeta();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.tr),
      child: Container(
        margin: EdgeInsets.only(bottom: 10.th),
        padding: EdgeInsets.all(12.tr),
        decoration: SignatureTheme.card(radius: 16),
        child: Row(
          children: [
            Container(
              width: 42.tr,
              height: 42.tr,
              decoration: BoxDecoration(
                color: meta.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12.tr),
              ),
              child: Icon(meta.icon, color: meta.color, size: 22.tsp),
            ),
            SizedBox(width: 12.tw),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.message.fileName ?? 'Document',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SignatureTheme.cardTitle,
                  ),
                  SizedBox(height: 3.th),
                  Text(
                    meta.label,
                    style: SignatureTheme.cardSubtitle.copyWith(
                      color: meta.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.tw),
            Text(
              DateFormat('dd MMM').format(item.message.createdAt),
              style: SignatureTheme.cardSubtitle,
            ),
          ],
        ),
      ),
    );
  }
}
