import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/project_document_hub_kind.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_kind_heading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reference-style DMS row: fixed height, pocket icon, 2-line italic title, dark footer.
class ProjectDocumentsRecordCard extends StatelessWidget {
  const ProjectDocumentsRecordCard({
    super.key,
    required this.title,
    required this.onTap,
    this.bodySubtitle,
    this.footer,
    this.leading,
    this.kind,
    this.isFolder = false,
    this.isFile = false,
  });

  static const double cardHeight = 118;
  static const double footerHeight = 34;

  final String title;
  final String? bodySubtitle;
  final String? footer;
  final Widget? leading;
  final VoidCallback onTap;
  final ProjectDocumentHubKind? kind;
  final bool isFolder;
  final bool isFile;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: cardHeight.th,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFEDEFF2),
            borderRadius: BorderRadius.circular(20.tr),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.85),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.tr),
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12.tw, 10.th, 12.tw, 8.th),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 56.tw,
                          height: 56.tw,
                          child: leading ??
                              ProjectDocumentsIcons.image(
                                kind: kind,
                                isFolder: isFolder,
                                isFile: isFile,
                                size: 56,
                              ),
                        ),
                        SizedBox(width: 12.tw),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ProjectDocumentsItalicTitle(text: title),
                              if (bodySubtitle != null &&
                                  bodySubtitle!.trim().isNotEmpty) ...[
                                SizedBox(height: 4.th),
                                Text(
                                  bodySubtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.tsp,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(0xFF6B7280),
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (footer != null && footer!.trim().isNotEmpty)
                  Container(
                    height: footerHeight.th,
                    width: double.infinity,
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.symmetric(horizontal: 14.tw),
                    color: const Color(0xFF3A3D46),
                    child: Text(
                      footer!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 10.5.tsp,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.94),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Italic title — up to 2 lines; slow horizontal slide when text still overflows.
class ProjectDocumentsItalicTitle extends StatefulWidget {
  const ProjectDocumentsItalicTitle({super.key, required this.text});

  final String text;

  @override
  State<ProjectDocumentsItalicTitle> createState() =>
      _ProjectDocumentsItalicTitleState();
}

class _ProjectDocumentsItalicTitleState extends State<ProjectDocumentsItalicTitle>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  bool _marquee = false;
  double _overflow = 0;
  double _lastWidth = 0;

  static const _styleColor = Color(0xFF1F2430);

  TextStyle get _style => GoogleFonts.poppins(
        fontSize: 14.tsp,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w600,
        color: _styleColor,
        height: 1.22,
      );

  static const double _twoLineHeight = 36;

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
      maxLines: 2,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    final needsMarquee = painter.didExceedMaxLines;
    if (needsMarquee == _marquee && (_controller != null) == needsMarquee) return;

    _controller?.dispose();
    _controller = null;
    _marquee = needsMarquee;

    if (needsMarquee) {
      final single = TextPainter(
        text: TextSpan(text: widget.text, style: _style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: double.infinity);
      _overflow = (single.width - maxWidth + 32.tw).clamp(0, double.infinity);
      _controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: (8000 + _overflow * 10).round()),
      )..repeat();
    }

    if (mounted) setState(() {});
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
            height: _twoLineHeight.th,
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
                  child: Text(
                    widget.text,
                    maxLines: 1,
                    style: _style,
                  ),
                ),
              ),
            ),
          );
        }

        return SizedBox(
          height: _twoLineHeight.th,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _style,
            ),
          ),
        );
      },
    );
  }

  @override
  void didUpdateWidget(covariant ProjectDocumentsItalicTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _lastWidth = 0;
      _marquee = false;
      _controller?.dispose();
      _controller = null;
    }
  }
}
