import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_documents/utils/document_attachment_opener.dart';
import 'package:el_race/ui/presentation/my_documents/utils/document_display.dart';
import 'package:el_race/ui/presentation/my_documents/widgets/my_documents_silk_background.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_glass_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

/// Document details — My Documents silk theme + reference layout.
class DocumentDetailsScreen extends StatelessWidget {
  const DocumentDetailsScreen({
    super.key,
    required this.document,
  });

  final Map<String, dynamic> document;

  @override
  Widget build(BuildContext context) {
    final typeLabel = DocumentDisplay.typeLabel(document);
    final status = DocumentDisplay.status(document);
    final docNumber = DocumentDisplay.documentNumber(document);
    final issueDate =
        DocumentDisplay.formatDate(DocumentDisplay.pickIssueRaw(document));
    final expiryDate =
        DocumentDisplay.formatDate(DocumentDisplay.pickExpiryRaw(document));
    final iconPath = (document['icon'] ?? 'assets/png/other-documetns-icon.png')
        .toString();
    final imageUrl = (document['image_url'] ??
            document['photo'] ??
            document['photo_url'] ??
            '')
        .toString()
        .trim();

    return MyDocumentsSilkBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            ProductivityGlassHeader(
              title: 'Back',
              showBack: true,
              transparentGlassBar: true,
              scrimTopOpacity: 0.08,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16.tw, 8.th, 16.tw, 20.th),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PreviewCard(iconPath: iconPath, imageUrl: imageUrl),
                    SizedBox(height: 16.th),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            typeLabel,
                            style: GoogleFonts.poppins(
                              fontSize: 24.tsp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E2365),
                            ),
                          ),
                        ),
                        _StatusBadge(status: status),
                      ],
                    ),
                    SizedBox(height: 14.th),
                    _InfoCard(
                      icon: Icons.description_outlined,
                      label: 'Document Type',
                      value: typeLabel,
                    ),
                    SizedBox(height: 8.th),
                    _InfoCard(
                      icon: Icons.badge_outlined,
                      label: 'Document Number',
                      value: docNumber,
                      trailing: docNumber == '-'
                          ? null
                          : IconButton(
                              tooltip: 'Copy',
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: docNumber),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Copied document number'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              icon: Icon(
                                Icons.copy_rounded,
                                size: 18.tsp,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                    ),
                    SizedBox(height: 8.th),
                    _InfoCard(
                      icon: Icons.calendar_today_outlined,
                      label: 'Issue Date',
                      value: issueDate,
                    ),
                    SizedBox(height: 8.th),
                    _InfoCard(
                      icon: Icons.timer_outlined,
                      label: 'Expiry Date',
                      value: expiryDate,
                    ),
                    SizedBox(height: 14.th),
                    SizedBox(
                      height: 52.th,
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => DocumentAttachmentOpener.open(
                                context,
                                document,
                              ),
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: _skyAccent
                                    .withValues(alpha: 0.18),
                                foregroundColor: const Color(0xFF1A4F6E),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.tr),
                                  side: BorderSide(
                                    color: _skyAccent.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                              icon: Icon(
                                Icons.visibility_outlined,
                                size: 18.tsp,
                              ),
                              label: Text(
                                'View File',
                                style: GoogleFonts.poppins(
                                  fontSize: 14.tsp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10.tw),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _share(context),
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: const Color(0xFF2E8B57)
                                    .withValues(alpha: 0.18),
                                foregroundColor: const Color(0xFF1B5E40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.tr),
                                  side: BorderSide(
                                    color: const Color(0xFF2E8B57)
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                              ),
                              icon: Icon(
                                Icons.ios_share_rounded,
                                size: 18.tsp,
                              ),
                              label: Text(
                                'Share',
                                style: GoogleFonts.poppins(
                                  fontSize: 14.tsp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    final typeLabel = DocumentDisplay.typeLabel(document);
    final docNumber = DocumentDisplay.documentNumber(document);
    final issueDate =
        DocumentDisplay.formatDate(DocumentDisplay.pickIssueRaw(document));
    final expiryDate =
        DocumentDisplay.formatDate(DocumentDisplay.pickExpiryRaw(document));
    final text = [
      typeLabel,
      if (docNumber != '-') 'Document Number: $docNumber',
      if (issueDate != '-') 'Issue Date: $issueDate',
      if (expiryDate != '-') 'Expiry Date: $expiryDate',
    ].join('\n');

    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? (box.localToGlobal(Offset.zero) & box.size)
        : const Rect.fromLTWH(1, 1, 1, 1);

    await Share.share(
      text,
      subject: typeLabel,
      sharePositionOrigin: origin,
    );
  }
}

const Color _skyAccent = Color(0xFF7EB6D9);

/// Frosted card with a thin uniform sky-blue border.
class _SkyAccentCard extends StatelessWidget {
  const _SkyAccentCard({
    required this.child,
    this.radius = 14,
    this.padding,
    this.height,
    this.fillAlpha = 0.72,
    this.borderWidth = 1,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final double fillAlpha;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: fillAlpha),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: _skyAccent.withValues(alpha: 0.55),
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.iconPath,
    required this.imageUrl,
  });

  final String iconPath;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - 32.tw;
    final height = (width / 1.58).clamp(200.0, 280.0);

    return _SkyAccentCard(
      radius: 18.tr,
      height: height,
      fillAlpha: 0.42,
      borderWidth: 1,
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => _iconPreview(),
            )
          : _iconPreview(),
    );
  }

  Widget _iconPreview() {
    return ColoredBox(
      color: const Color(0xFFF7FAFC).withValues(alpha: 0.55),
      child: Padding(
        padding: EdgeInsets.all(20.tw),
        child: Center(
          child: Image.asset(
            iconPath,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.badge_outlined,
              size: 96.tsp,
              color: const Color(0xFF9AA3AF),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final DocumentStatus status;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final IconData icon;
    final String label;

    switch (status) {
      case DocumentStatus.expired:
        bg = const Color(0xFFFFE5E5);
        fg = const Color(0xFFC62828);
        icon = Icons.error_outline_rounded;
        label = 'Expired';
      case DocumentStatus.expiring:
        bg = const Color(0xFFFFF1D9);
        fg = const Color(0xFFC47A12);
        icon = Icons.schedule_rounded;
        label = 'Expiring';
      case DocumentStatus.valid:
        bg = const Color(0xFFE2F3E9);
        fg = const Color(0xFF1B5E40);
        icon = Icons.check_circle_rounded;
        label = 'Valid';
      case DocumentStatus.unknown:
        bg = const Color(0xFFEEF0F3);
        fg = const Color(0xFF6B7280);
        icon = Icons.help_outline_rounded;
        label = 'Unknown';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 6.th),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.tsp, color: fg),
          SizedBox(width: 4.tw),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12.tsp,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return _SkyAccentCard(
      radius: 14.tr,
      padding: EdgeInsets.fromLTRB(12.tw, 12.th, 8.tw, 12.th),
      fillAlpha: 0.82,
      child: Row(
        children: [
          Icon(icon, size: 22.tsp, color: const Color(0xFF5A6A8A)),
          SizedBox(width: 12.tw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11.tsp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF7B8290),
                  ),
                ),
                SizedBox(height: 2.th),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14.tsp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E2365),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
