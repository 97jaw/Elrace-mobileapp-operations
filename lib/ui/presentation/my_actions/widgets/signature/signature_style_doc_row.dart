import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';

import '../../theme/signature_theme.dart';

/// Shared document row look used by Signature Documents and Timesheet documents.
class SignatureStyleDocRow extends StatelessWidget {
  const SignatureStyleDocRow({
    super.key,
    required this.fileName,
    required this.dateLabel,
    required this.statusLabel,
    required this.statusColor,
    required this.onTap,
    this.detailLine,
    this.onShare,
    this.onDownload,
    this.onDelete,
  });

  final String fileName;
  final String dateLabel;
  final String statusLabel;
  final Color statusColor;
  final String? detailLine;
  final VoidCallback onTap;
  final VoidCallback? onShare;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
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
              _Thumbnail(color: statusColor),
              SizedBox(width: 12.tw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SignatureTheme.cardTitle,
                    ),
                    if (detailLine != null && detailLine!.trim().isNotEmpty) ...[
                      SizedBox(height: 4.th),
                      Text(
                        detailLine!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SignatureTheme.cardSubtitle,
                      ),
                    ],
                    SizedBox(height: 4.th),
                    Text(dateLabel, style: SignatureTheme.cardSubtitle),
                    SizedBox(height: 4.th),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.tw,
                        vertical: 3.th,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: SignatureTheme.cardSubtitle.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (onShare != null ||
                        onDownload != null ||
                        onDelete != null) ...[
                      SizedBox(height: 10.th),
                      Row(
                        children: [
                          _ActionButton(
                            icon: Icons.visibility_outlined,
                            label: 'View',
                            onTap: onTap,
                          ),
                          if (onShare != null) ...[
                            SizedBox(width: 14.tw),
                            _ActionButton(
                              icon: Icons.share_outlined,
                              label: 'Share',
                              onTap: onShare!,
                            ),
                          ],
                          if (onDownload != null) ...[
                            SizedBox(width: 14.tw),
                            _ActionButton(
                              icon: Icons.download_outlined,
                              label: 'Download',
                              onTap: onDownload!,
                            ),
                          ],
                          if (onDelete != null) ...[
                            SizedBox(width: 14.tw),
                            _ActionButton(
                              icon: Icons.delete_outline,
                              label: 'Delete',
                              color: SignatureTheme.expired,
                              onTap: onDelete!,
                            ),
                          ],
                        ],
                      ),
                    ],
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
  const _Thumbnail({required this.color});

  final Color color;

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
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

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
