import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Notifies the parent chrome when folder drill changes.
typedef DocumentsDrillChanged = void Function(
  String title,
  VoidCallback? exitFolder,
);

/// Neutral frosted tile for light HR / Shared Documents surfaces
/// (Project Documents row anatomy without maroon gradient theme).
BoxDecoration documentsFrostedTileDecoration() => BoxDecoration(
      borderRadius: BorderRadius.circular(16.tr),
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0.92),
          const Color(0xFFF3F5F9).withValues(alpha: 0.88),
          const Color(0xFFE8EBF0).withValues(alpha: 0.72),
        ],
      ),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.85),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );

const Color _docsTitleColor = Color(0xFF2E3445);
const Color _docsMetaColor = Color(0xFF5A6270);

/// Single-line title with slow horizontal slide when text overflows.
class DocumentsOneLineMarquee extends StatefulWidget {
  const DocumentsOneLineMarquee({
    super.key,
    required this.text,
    this.fontSize,
    this.fontWeight = FontWeight.w500,
    this.italic = false,
    this.color,
    this.lineHeight = 1.2,
  });

  final String text;
  final double? fontSize;
  final FontWeight fontWeight;
  final bool italic;
  final Color? color;
  final double lineHeight;

  @override
  State<DocumentsOneLineMarquee> createState() =>
      _DocumentsOneLineMarqueeState();
}

class _DocumentsOneLineMarqueeState extends State<DocumentsOneLineMarquee>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  bool _marquee = false;
  double _overflow = 0;
  double _lastWidth = 0;

  TextStyle get _style => GoogleFonts.poppins(
        fontSize: widget.fontSize ?? 14.tsp,
        fontStyle: widget.italic ? FontStyle.italic : FontStyle.normal,
        fontWeight: widget.fontWeight,
        color: widget.color ?? _docsTitleColor,
        height: widget.lineHeight,
      );

  double get _lineHeightPx => (widget.fontSize ?? 14.tsp) * widget.lineHeight;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _evaluate(double maxWidth) {
    if (maxWidth <= 0 || maxWidth == _lastWidth) return;
    _lastWidth = maxWidth;

    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: _style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    final needsMarquee = painter.didExceedMaxLines;
    if (needsMarquee == _marquee && (_controller != null) == needsMarquee) {
      return;
    }

    _controller?.dispose();
    _controller = null;
    _marquee = needsMarquee;

    if (needsMarquee) {
      final full = TextPainter(
        text: TextSpan(text: widget.text, style: _style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: double.infinity);
      _overflow = (full.width - maxWidth + 24.tw).clamp(0, double.infinity);
      _controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: (9000 + _overflow * 12).round()),
      )..repeat();
    }

    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant DocumentsOneLineMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _lastWidth = 0;
      _marquee = false;
      _controller?.dispose();
      _controller = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _evaluate(constraints.maxWidth);
        });

        if (_marquee && _controller != null) {
          return SizedBox(
            height: _lineHeightPx,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ClipRect(
                child: AnimatedBuilder(
                  animation: _controller!,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(-_overflow * _controller!.value, 0),
                      child: child,
                    );
                  },
                  child: Text(widget.text, maxLines: 1, style: _style),
                ),
              ),
            ),
          );
        }

        return SizedBox(
          height: _lineHeightPx,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _style,
            ),
          ),
        );
      },
    );
  }
}

class DocumentsSectionHeader extends StatelessWidget {
  const DocumentsSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.tw, 4.th, 4.tw, 8.th),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15.tsp,
                    fontWeight: FontWeight.w600,
                    color: _docsTitleColor,
                  ),
                ),
                SizedBox(height: 2.th),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12.tsp,
                    fontWeight: FontWeight.w500,
                    color: _docsMetaColor,
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

/// Full-width folder row — Project Documents section-tile anatomy.
class DocumentsFolderTile extends StatelessWidget {
  const DocumentsFolderTile({
    super.key,
    required this.title,
    required this.onTap,
    this.fileCount,
    this.subtitle,
    this.trailingMeta,
    this.leading,
    this.showChevron = true,
  });

  final String title;
  final VoidCallback onTap;
  final int? fileCount;
  final String? subtitle;
  final String? trailingMeta;
  final Widget? leading;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final filesLine = fileCount == null
        ? null
        : '$fileCount file${fileCount == 1 ? '' : 's'}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.tr),
        child: Container(
          decoration: documentsFrostedTileDecoration(),
          padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 10.th),
          child: Row(
            children: [
              leading ??
                  Image.asset(
                    'assets/png/project_docs/sharepoint_icon.png',
                    width: 48.tw,
                    height: 48.tw,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.folder_rounded,
                      size: 36.tsp,
                      color: _docsTitleColor,
                    ),
                  ),
              SizedBox(width: 10.tw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DocumentsOneLineMarquee(
                      text: title,
                      fontSize: 15.tsp,
                      fontWeight: FontWeight.w700,
                      color: _docsTitleColor,
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      SizedBox(height: 3.th),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 10.tsp,
                          color: _docsMetaColor.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                    if (filesLine != null) ...[
                      SizedBox(height: 6.th),
                      Text(
                        filesLine,
                        style: GoogleFonts.poppins(
                          fontSize: 14.tsp,
                          fontWeight: FontWeight.w600,
                          color: _docsMetaColor.withValues(alpha: 0.92),
                          height: 1.15,
                        ),
                      ),
                    ],
                    if (trailingMeta != null &&
                        trailingMeta!.trim().isNotEmpty) ...[
                      SizedBox(height: 2.th),
                      Text(
                        trailingMeta!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11.tsp,
                          fontWeight: FontWeight.w600,
                          color: _docsMetaColor.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  color: _docsMetaColor.withValues(alpha: 0.55),
                  size: 22.tsp,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width file row — Project Documents file-row anatomy.
class DocumentsFileRow extends StatelessWidget {
  const DocumentsFileRow({
    super.key,
    required this.fileName,
    required this.onTap,
    this.subtitle,
    this.updatedLabel,
    this.showChevron = true,
  });

  final String fileName;
  final VoidCallback onTap;
  final String? subtitle;
  final String? updatedLabel;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final updated = updatedLabel?.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.tr),
        child: Container(
          decoration: documentsFrostedTileDecoration(),
          padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 10.th),
          child: Row(
            children: [
              Image.asset(
                'assets/png/project_docs/file_icon.png',
                width: 46.tw,
                height: 46.tw,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.description_outlined,
                  size: 32.tsp,
                  color: _docsTitleColor,
                ),
              ),
              SizedBox(width: 10.tw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DocumentsOneLineMarquee(
                      text: fileName,
                      fontSize: 14.tsp,
                      fontWeight: FontWeight.w500,
                      color: _docsTitleColor,
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      SizedBox(height: 3.th),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 10.tsp,
                          color: _docsMetaColor.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                    if (updated != null && updated.isNotEmpty) ...[
                      SizedBox(height: 3.th),
                      Text(
                        'Updated $updated',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 10.tsp,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                          color: _docsMetaColor,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  color: _docsMetaColor.withValues(alpha: 0.55),
                  size: 22.tsp,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
